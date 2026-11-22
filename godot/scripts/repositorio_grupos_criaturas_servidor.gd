extends RefCounted
## Persistência local no servidor para grupos selvagens derivados de criaturas já catalogadas.
## Cada indivíduo é uma instância independente; não gera novas espécies nem usa dados do cliente.
const REPOSITORIO_CRIATURAS = preload("res://scripts/repositorio_criaturas_servidor.gd")
const SISTEMA_POPULACAO = preload("res://scripts/sistema_populacao_criaturas.gd")
const SISTEMA_LIDERES = preload("res://scripts/sistema_lideres_criaturas.gd")
const SISTEMA_EQUIPAMENTOS = preload("res://scripts/sistema_equipamentos.gd")
const CAMINHO_PADRAO := "user://dados/grupos_criaturas.json"
const LIMITE_ARQUIVO := 32 * 1024 * 1024
const CAMPOS_ATRIBUTOS := ["vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"]

var caminho_arquivo: String
var repositorio_criaturas: Object

func _init(caminho: String = CAMINHO_PADRAO, repositorio: Object = null) -> void:
	caminho_arquivo = caminho
	repositorio_criaturas = repositorio if repositorio != null else REPOSITORIO_CRIATURAS.new()

## Cria um grupo somente a partir de criatura já registrada e com ecologia populacional/território.
func criar_grupo_para_criatura(criatura_id: String, agora_unix: int = -1) -> Dictionary:
	var criatura: Dictionary = repositorio_criaturas.obter_criatura(criatura_id)
	if criatura.is_empty():
		return {"ok":false,"erro":"A espécie ainda não existe no catálogo global."}
	var ecologia: Dictionary = criatura.get("ecologia", {})
	var config = ecologia.get("populacao", null)
	var territorio = ecologia.get("territorio", {})
	if not (config is Dictionary) or not SISTEMA_POPULACAO.validar_configuracao(config):
		return {"ok":false,"erro":"A espécie não declarou uma configuração populacional válida."}
	if not _territorio_valido(territorio):
		return {"ok":false,"erro":"A espécie precisa declarar um território válido antes de formar um grupo."}
	var grupo_id := str(territorio.get("grupoId", criatura_id + "_" + str(criatura.get("bioma", "")))).strip_edges()
	if grupo_id.is_empty() or grupo_id.length() > 160:
		return {"ok":false,"erro":"Identificador de grupo inválido."}
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(caminho_arquivo):
		return {"ok":false,"erro":"Arquivo de grupos inválido; criação bloqueada para proteger os dados."}
	var grupos: Dictionary = banco.get("grupos", {})
	if grupos.has(grupo_id):
		return {"ok":false,"erro":"Este grupo já foi criado.","duplicado":true}
	var agora := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	var estado := SISTEMA_POPULACAO.criar_estado(config, agora)
	if estado.is_empty():
		return {"ok":false,"erro":"Não foi possível iniciar a população."}
	var grupo := {
		"grupoId":grupo_id,
		"especieId":criatura_id,
		"ecossistemaId":str(criatura.get("ecossistemaId", "")),
		"bioma":str(criatura.get("bioma", "")),
		"habitat":str(criatura.get("habitat", "")),
		"territorio":territorio.duplicate(true),
		"populacaoEstado":estado,
		"populacaoMinimaParaLider":int(ecologia.get("populacaoMinimaParaLider", 3)),
		"equipamentosLiderDisponiveis":_equipamentos_lider_validos(ecologia.get("equipamentosLider", [])),
		"individuos":[],
		"proximoNumeroIndividuo":1,
		"liderAtual":{},
		"criadoUnix":agora,
		"atualizadoUnix":agora
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(grupo_id + ":" + str(agora))
	for i in range(int(estado.get("quantidade", 0))):
		grupo["individuos"].append(_criar_individuo(grupo, criatura, rng))
	grupo["liderAtual"] = SISTEMA_LIDERES.avaliar_grupo(grupo, rng.randi()).get("lider", {})
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar o novo grupo no servidor."}
	return {"ok":true,"grupo":grupo.duplicate(true)}

## Avança o relógio ecológico e cria/remove indivíduos reais para refletir o resultado.
## alimento_disponivel precisa vir de uma avaliação confiável do mundo.
func avancar_grupo(grupo_id: String, agora_unix: int, alimento_disponivel: float = 1.0) -> Dictionary:
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var criatura: Dictionary = repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
	if criatura.is_empty():
		return {"ok":false,"erro":"A espécie de origem não está mais disponível no catálogo."}
	var simulacao := SISTEMA_POPULACAO.avancar(grupo.get("populacaoEstado", {}), agora_unix, alimento_disponivel)
	if not bool(simulacao.get("ok", false)):
		return simulacao
	if not bool(simulacao.get("alterou", false)):
		return {"ok":true,"alterou":false,"grupo":grupo}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(grupo_id + ":" + str(agora_unix))
	var individuos: Array = grupo.get("individuos", [])
	var lider_anterior := str(grupo.get("liderAtual", {}).get("individuoId", ""))
	for i in range(int(simulacao.get("mortesNaturais", 0))):
		var vivos: Array = []
		for indice in range(individuos.size()):
			if bool(individuos[indice].get("vivo", true)):
				vivos.append(indice)
		if vivos.is_empty():
			break
		var indice_morto: int = vivos[rng.randi_range(0, vivos.size() - 1)]
		var individuo_morto: Dictionary = individuos[indice_morto]
		individuo_morto["vivo"] = false
		individuo_morto["morteNaturalUnix"] = agora_unix
		individuos[indice_morto] = individuo_morto
	for i in range(int(simulacao.get("nascimentos", 0))):
		individuos.append(_criar_individuo(grupo, criatura, rng))
	grupo["individuos"] = individuos
	grupo["populacaoEstado"] = simulacao["estado"]
	grupo["atualizadoUnix"] = agora_unix
	var lider_resultado: Dictionary = {}
	if not lider_anterior.is_empty():
		var ainda_vivo := false
		for individuo in individuos:
			if str(individuo.get("individuoId", "")) == lider_anterior and bool(individuo.get("vivo", true)):
				ainda_vivo = true
				break
		if not ainda_vivo:
			lider_resultado = SISTEMA_LIDERES.suceder_lider(grupo, lider_anterior, rng.randi())
	if lider_resultado.is_empty() or not bool(lider_resultado.get("temLider", false)):
		lider_resultado = SISTEMA_LIDERES.avaliar_grupo(grupo, rng.randi())
	grupo["liderAtual"] = lider_resultado.get("lider", {})
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir a atualização do grupo."}
	return {
		"ok":true,
		"alterou":true,
		"nascimentos":int(simulacao.get("nascimentos", 0)),
		"mortesNaturais":int(simulacao.get("mortesNaturais", 0)),
		"quantidade":int(grupo["populacaoEstado"].get("quantidade", 0)),
		"lider":grupo["liderAtual"].duplicate(true),
		"grupo":grupo.duplicate(true)
	}

func obter_grupo(grupo_id: String) -> Dictionary:
	var banco := _ler_banco()
	return banco.get("grupos", {}).get(grupo_id, {}).duplicate(true)

func listar_grupos_do_ecossistema(ecossistema_id: String) -> Array:
	var resultado: Array = []
	var banco := _ler_banco()
	for grupo in banco.get("grupos", {}).values():
		if str(grupo.get("ecossistemaId", "")) == ecossistema_id:
			resultado.append(grupo.duplicate(true))
	return resultado

func listar_todos_grupos() -> Array:
	var resultado: Array = []
	for grupo in _ler_banco().get("grupos", {}).values():
		resultado.append(grupo.duplicate(true))
	return resultado

func _criar_individuo(grupo: Dictionary, criatura: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var territorio: Dictionary = grupo.get("territorio", {})
	var centro: Dictionary = territorio.get("centro", {})
	var raio := float(territorio.get("raio", 1.0))
	var angulo := rng.randf_range(0.0, TAU)
	var distancia := sqrt(rng.randf()) * raio
	var numero := int(grupo.get("proximoNumeroIndividuo", 1))
	grupo["proximoNumeroIndividuo"] = numero + 1
	var atributos := {}
	for campo in CAMPOS_ATRIBUTOS:
		atributos[campo] = int(criatura.get(campo, 0))
	return {
		"individuoId":str(grupo.get("grupoId", "grupo")) + "_ind_" + str(numero),
		"especieId":str(criatura.get("id", "")),
		"atributos":atributos,
		"equipamentoIds":[],
		"vivo":true,
		"posicaoMundo":{
			"x":clampf(float(centro.get("x", 0.0)) + cos(angulo) * distancia, 0.0, 2400.0),
			"y":clampf(float(centro.get("y", 0.0)) + sin(angulo) * distancia, 0.0, 1600.0)
		},
		"nascimentoUnix":int(grupo.get("atualizadoUnix", grupo.get("criadoUnix", 0)))
	}

func _equipamentos_lider_validos(valor: Variant) -> Array:
	if not (valor is Array):
		return []
	var resultado: Array = []
	var catalogo := SISTEMA_EQUIPAMENTOS.CATALOGO
	for item_id in valor:
		var id := str(item_id)
		if catalogo.has(id) and not resultado.has(id):
			resultado.append(id)
		if resultado.size() >= 6:
			break
	return resultado

func _territorio_valido(territorio: Variant) -> bool:
	if not (territorio is Dictionary):
		return false
	var centro = territorio.get("centro", {})
	if not (centro is Dictionary):
		return false
	var x := float(centro.get("x", -1.0))
	var y := float(centro.get("y", -1.0))
	var raio := float(territorio.get("raio", 0.0))
	return x >= 0.0 and x <= 2400.0 and y >= 0.0 and y <= 1600.0 and raio > 0.0 and raio <= 1000.0

func _ler_banco() -> Dictionary:
	if not FileAccess.file_exists(caminho_arquivo):
		return {"versao":1,"grupos":{}}
	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.READ)
	if arquivo == null or arquivo.get_length() > LIMITE_ARQUIVO:
		return {}
	var texto := arquivo.get_as_text()
	arquivo.close()
	var dados = JSON.parse_string(texto)
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1 or not (dados.get("grupos", {}) is Dictionary):
		return {}
	return dados

func _gravar_banco(banco: Dictionary) -> bool:
	var diretorio := caminho_arquivo.get_base_dir()
	var caminho_absoluto := ProjectSettings.globalize_path(diretorio)
	if DirAccess.make_dir_recursive_absolute(caminho_absoluto) != OK:
		return false
	var temporario := caminho_arquivo + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(banco))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporario))
		return false
	if FileAccess.file_exists(caminho_arquivo):
		var backup := caminho_arquivo + ".bak"
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho_arquivo), ProjectSettings.globalize_path(backup)) != OK:
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporario), ProjectSettings.globalize_path(caminho_arquivo)) != OK:
		return false
	return true
