extends RefCounted
## Persistência local no servidor para grupos selvagens derivados de criaturas já catalogadas.
## Cada indivíduo é uma instância independente; não gera novas espécies nem usa dados do cliente.
const REPOSITORIO_CRIATURAS = preload("res://scripts/repositorio_criaturas_servidor.gd")
const SISTEMA_POPULACAO = preload("res://scripts/sistema_populacao_criaturas.gd")
const SISTEMA_LIDERES = preload("res://scripts/sistema_lideres_criaturas.gd")
const SISTEMA_EQUIPAMENTOS = preload("res://scripts/sistema_equipamentos.gd")
const SISTEMA_COMPORTAMENTO = preload("res://scripts/sistema_comportamento_criaturas.gd")
const SISTEMA_CUIDADO_PARENTAL = preload("res://scripts/sistema_cuidado_parental.gd")
const SISTEMA_LIDER_NATO = preload("res://scripts/sistema_lider_nato.gd")
const SISTEMA_MIGRACAO = preload("res://scripts/sistema_migracao_coordenadas.gd")
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
		"rotasMigracao":ecologia.get("rotasMigracao", []).duplicate(true),
		"ciclosEscassezAlimentar":0,
		"ultimaMigracaoUnix":0,
		"populacaoEstado":estado,
		"idadeMaturidadeDias":clampf(float(ecologia.get("idadeMaturidadeDias", 7.0)), 1.0, 3650.0),
		"populacaoMinimaParaLider":int(ecologia.get("populacaoMinimaParaLider", 3)),
		"equipamentosLiderDisponiveis":_equipamentos_lider_validos(ecologia.get("equipamentosLider", [])),
		"individuos":[],
		"proximoNumeroIndividuo":1,
		"liderAtual":{},
		"personalidade":_gerar_personalidade_grupo(grupo_id),
		"relacoesGrupos":{},
		"historicoSocial":[],
		"criadoUnix":agora,
		"atualizadoUnix":agora
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(grupo_id + ":" + str(agora))
	for i in range(int(estado.get("quantidade", 0))):
		grupo["individuos"].append(_criar_individuo(grupo, criatura, rng, false))
	grupo["liderAtual"] = SISTEMA_LIDERES.avaliar_grupo(grupo, rng.randi()).get("lider", {})
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar o novo grupo no servidor."}
	return {"ok":true,"grupo":grupo.duplicate(true)}

## Avança o relógio ecológico e cria/remove indivíduos reais para refletir o resultado.
## alimento_disponivel precisa vir de uma avaliação confiável do mundo.
func avancar_grupo(grupo_id: String, agora_unix: int, alimento_disponivel: float = 1.0, protecao_fome: float = 0.0) -> Dictionary:
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var criatura: Dictionary = repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
	if criatura.is_empty():
		return {"ok":false,"erro":"A espécie de origem não está mais disponível no catálogo."}
	var cuidado_parental := SISTEMA_CUIDADO_PARENTAL.avaliar(grupo, agora_unix)
	var protecao_cuidado := float(cuidado_parental.get("protecaoFome", 0.0))
	var protecao_combinada := 1.0 - (1.0 - protecao_fome) * (1.0 - protecao_cuidado)
	var simulacao := SISTEMA_POPULACAO.avancar(grupo.get("populacaoEstado", {}), agora_unix, alimento_disponivel, protecao_combinada)
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
		individuo_morto["carcaca"] = _criar_carcarca(individuo_morto, criatura, agora_unix)
		individuos[indice_morto] = individuo_morto
	grupo["atualizadoUnix"] = agora_unix
	for i in range(int(simulacao.get("nascimentos", 0))):
		individuos.append(_criar_individuo(grupo, criatura, rng, true))
	for indice_fase in range(individuos.size()):
		var membro_fase: Dictionary = individuos[indice_fase].duplicate(true)
		if bool(membro_fase.get("vivo", true)):
			var nascimento_fase := int(membro_fase.get("nascimentoUnix", agora_unix))
			var maturidade_segundos := float(grupo.get("idadeMaturidadeDias", 7.0)) * 86400.0
			membro_fase["faseVida"] = "adulto" if agora_unix - nascimento_fase >= maturidade_segundos else "filhote"
		individuos[indice_fase] = membro_fase
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
		"cuidadoParental":cuidado_parental,
		"quantidade":int(grupo["populacaoEstado"].get("quantidade", 0)),
		"lider":grupo["liderAtual"].duplicate(true),
		"grupo":grupo.duplicate(true)
	}

## Faz a fauna abandonar uma área devastada, usando somente rotas de migração declaradas pela espécie.
func fugir_da_devastacao(grupo_id: String, centro_zona: Vector2, raio_zona: float, agora_unix: int) -> Dictionary:
	if grupo_id.is_empty() or raio_zona <= 0.0 or raio_zona > 2000.0:
		return {"ok":false,"erro":"Zona de devastação inválida."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var territorio_atual: Dictionary = grupo.get("territorio", {})
	var centro_atual_dados: Dictionary = territorio_atual.get("centro", {})
	var centro_atual := Vector2(float(centro_atual_dados.get("x", -1.0)), float(centro_atual_dados.get("y", -1.0)))
	var raio_atual := float(territorio_atual.get("raio", 0.0))
	if centro_atual.x < 0.0 or centro_atual.y < 0.0 or centro_atual.distance_to(centro_zona) > raio_zona + raio_atual:
		return {"ok":true,"fugiu":false,"motivo":"fora_da_area"}
	for rota in grupo.get("rotasMigracao", []):
		if not (rota is Dictionary):
			continue
		var destino: Dictionary = rota.get("territorio", {})
		var centro_dados: Dictionary = destino.get("centro", {})
		var centro_novo := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
		var raio_novo := float(destino.get("raio", 0.0))
		var ecossistema_novo := str(rota.get("ecossistemaId", ""))
		var bioma_novo := str(rota.get("bioma", ""))
		var habitat_novo := str(rota.get("habitat", ""))
		var rota_id := str(rota.get("id", ""))
		if rota_id.is_empty() or ecossistema_novo.is_empty() or bioma_novo.is_empty() or habitat_novo.is_empty():
			continue
		if centro_novo.x < 0.0 or centro_novo.x > 2400.0 or centro_novo.y < 0.0 or centro_novo.y > 1600.0 or raio_novo < 20.0 or raio_novo > 1000.0:
			continue
		if centro_novo.distance_to(centro_zona) <= raio_zona + raio_novo:
			continue
		var ocupado := false
		for outro_id in grupos:
			if str(outro_id) == grupo_id:
				continue
			var outro: Dictionary = grupos[outro_id]
			if str(outro.get("ecossistemaId", "")) != ecossistema_novo:
				continue
			var outro_territorio: Dictionary = outro.get("territorio", {})
			var outro_centro_dados: Dictionary = outro_territorio.get("centro", {})
			var outro_centro := Vector2(float(outro_centro_dados.get("x", -10000.0)), float(outro_centro_dados.get("y", -10000.0)))
			if outro_centro.distance_to(centro_novo) < float(outro_territorio.get("raio", 0.0)) + raio_novo:
				ocupado = true
				break
		if ocupado:
			continue
		var individuos: Array = grupo.get("individuos", [])
		for indice in range(individuos.size()):
			var individuo: Dictionary = individuos[indice].duplicate(true)
			var posicao: Dictionary = individuo.get("posicaoMundo", {})
			var deslocamento := Vector2(float(posicao.get("x", centro_atual.x)), float(posicao.get("y", centro_atual.y))) - centro_atual
			if deslocamento.length() > raio_novo - 5.0:
				deslocamento = deslocamento.normalized() * (raio_novo - 5.0)
			var nova_posicao := centro_novo + deslocamento
			individuo["posicaoMundo"] = {"x":nova_posicao.x,"y":nova_posicao.y}
			if bool(individuo.get("vivo", true)):
				individuo["estadoMundo"] = "fugindo_da_devastacao"
			individuos[indice] = individuo
		grupo["individuos"] = individuos
		grupo["territorio"] = destino.duplicate(true)
		var ecossistema_anterior := str(grupo.get("ecossistemaId", ""))
		grupo["ecossistemaId"] = ecossistema_novo
		grupo["bioma"] = bioma_novo
		grupo["habitat"] = habitat_novo
		grupo["ultimaMigracaoUnix"] = agora_unix
		grupo["atualizadoUnix"] = agora_unix
		grupo["ultimaMigracao"] = {"rotaId":rota_id,"motivo":"sopro_primordial","ecossistemaAnterior":ecossistema_anterior,"horarioUnix":agora_unix}
		grupos[grupo_id] = grupo
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível persistir a fuga da fauna."}
		return {"ok":true,"fugiu":true,"rotaId":rota_id,"grupo":grupo.duplicate(true)}
	return {"ok":true,"fugiu":false,"motivo":"sem_rota_segura"}


## Predadores só perseguem grupos deslocados quando a relação presa/predador foi
## declarada pela espécie no catálogo. A perseguição fica registrada no servidor;
## este método não teletransporta grupos nem inicia combate automaticamente.
func registrar_perseguicao_de_fauna_migrante(grupo_presa_id: String, agora_unix: int) -> Dictionary:
	if grupo_presa_id.is_empty() or agora_unix < 0:
		return {"ok":false,"erro":"Alvo ou horário de perseguição inválido."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_presa_id):
		return {"ok":false,"erro":"Grupo deslocado não encontrado."}
	var presa: Dictionary = grupos[grupo_presa_id].duplicate(true)
	var especie_presa: Dictionary = repositorio_criaturas.obter_criatura(str(presa.get("especieId", "")))
	if especie_presa.is_empty() or presa.get("ultimaMigracao", {}).is_empty():
		return {"ok":true,"perseguidores":[]}
	var ecossistema_origem := str(presa.get("ultimaMigracao", {}).get("ecossistemaAnterior", ""))
	var centro_destino_dados: Dictionary = presa.get("territorio", {}).get("centro", {})
	var centro_destino := Vector2(float(centro_destino_dados.get("x", -1.0)), float(centro_destino_dados.get("y", -1.0)))
	if ecossistema_origem.is_empty() or centro_destino.x < 0.0 or centro_destino.y < 0.0:
		return {"ok":true,"perseguidores":[]}
	var ids_perseguidores: Array = []
	for predador_id_var in grupos.keys():
		var predador_id := str(predador_id_var)
		if predador_id == grupo_presa_id:
			continue
		var predador: Dictionary = grupos[predador_id].duplicate(true)
		if str(predador.get("ecossistemaId", "")) != ecossistema_origem:
			continue
		var especie_predadora: Dictionary = repositorio_criaturas.obter_criatura(str(predador.get("especieId", "")))
		if especie_predadora.is_empty():
			continue
		var ecologia_predador: Dictionary = especie_predadora.get("ecologia", {})
		var ecologia_presa: Dictionary = especie_presa.get("ecologia", {})
		var dieta: Array = ecologia_predador.get("especiesPresas", [])
		var declaracao_reversa: Array = ecologia_presa.get("especiesPredadoras", [])
		var relacao_declarada := dieta.has(str(especie_presa.get("id", ""))) or declaracao_reversa.has(str(especie_predadora.get("id", "")))
		if not relacao_declarada:
			continue
		var perseguicao_atual: Dictionary = predador.get("perseguicaoAtual", {})
		if str(perseguicao_atual.get("grupoAlvoId", "")) == grupo_presa_id:
			continue
		var centro_predador_dados: Dictionary = predador.get("territorio", {}).get("centro", {})
		var centro_predador := Vector2(float(centro_predador_dados.get("x", -10000.0)), float(centro_predador_dados.get("y", -10000.0)))
		if centro_predador.distance_to(centro_destino) > 1800.0:
			continue
		predador["perseguicaoAtual"] = {
			"grupoAlvoId":grupo_presa_id,
			"especieAlvoId":str(especie_presa.get("id", "")),
			"centroAlvo":{"x":centro_destino.x,"y":centro_destino.y},
			"motivo":"presa_deslocada_pela_devastacao",
			"iniciadaUnix":agora_unix,
			"estado":"rastreando"
		}
		predador["atualizadoUnix"] = agora_unix
		grupos[predador_id] = predador
		ids_perseguidores.append(predador_id)
	if not ids_perseguidores.is_empty():
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível persistir a perseguição dos predadores."}
	var atualizados: Array = []
	for id in ids_perseguidores:
		atualizados.append(grupos[id].duplicate(true))
	return {"ok":true,"perseguidores":atualizados}


## Move predadores em direção a presas deslocadas. O deslocamento é gradual,
## limitado por velocidade ecológica e persistido pelo servidor.
func avancar_perseguicoes(delta_segundos: float, agora_unix: int) -> Dictionary:
	if delta_segundos <= 0.0 or delta_segundos > 5.0 or agora_unix < 0:
		return {"ok":false,"erro":"Intervalo de perseguição inválido."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	var atualizados: Array = []
	var houve_mudanca := false
	for predador_id_var in grupos.keys():
		var predador_id := str(predador_id_var)
		var predador: Dictionary = grupos[predador_id].duplicate(true)
		var perseguicao: Dictionary = predador.get("perseguicaoAtual", {})
		if str(perseguicao.get("estado", "")) not in ["rastreando", "seguindo"]:
			continue
		var alvo_id := str(perseguicao.get("grupoAlvoId", ""))
		if alvo_id.is_empty() or not grupos.has(alvo_id):
			perseguicao["estado"] = "perdeu_rastro"
			perseguicao["encerradaUnix"] = agora_unix
			predador["perseguicaoAtual"] = perseguicao
			if grupos.has(alvo_id):
				_registrar_aprendizado_cacada(predador, grupos[alvo_id], "perdeu_rastro", agora_unix)
			grupos[predador_id] = predador
			houve_mudanca = true
			continue
		var presa: Dictionary = grupos[alvo_id]
		if str(presa.get("ecossistemaId", "")) != str(predador.get("ecossistemaId", "")):
			perseguicao["estado"] = "presa_escapou_de_ecossistema"
			perseguicao["encerradaUnix"] = agora_unix
			predador["perseguicaoAtual"] = perseguicao
			_registrar_aprendizado_cacada(predador, presa, "presa_escapou_de_ecossistema", agora_unix)
			grupos[predador_id] = predador
			houve_mudanca = true
			continue
		var presa_viva := false
		for individuo_presa in presa.get("individuos", []):
			if bool(individuo_presa.get("vivo", true)):
				presa_viva = true
				break
		if not presa_viva:
			perseguicao["estado"] = "presa_indisponivel"
			perseguicao["encerradaUnix"] = agora_unix
			predador["perseguicaoAtual"] = perseguicao
			grupos[predador_id] = predador
			houve_mudanca = true
			continue
		var centro_alvo_dados: Dictionary = presa.get("territorio", {}).get("centro", {})
		var centro_alvo := Vector2(float(centro_alvo_dados.get("x", -1.0)), float(centro_alvo_dados.get("y", -1.0)))
		var territorio: Dictionary = predador.get("territorio", {}).duplicate(true)
		var centro_dados: Dictionary = territorio.get("centro", {})
		var centro_atual := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
		var raio := float(territorio.get("raio", 0.0))
		if centro_alvo.x < 0.0 or centro_alvo.x > 2400.0 or centro_alvo.y < 0.0 or centro_alvo.y > 1600.0 or centro_atual.x < 0.0 or raio < 20.0:
			continue
		var distancia := centro_atual.distance_to(centro_alvo)
		var distancia_alcance := raio + float(presa.get("territorio", {}).get("raio", 0.0)) + 20.0
		if distancia <= distancia_alcance:
			perseguicao["estado"] = "alcancou_alvo"
			perseguicao["centroAlvo"] = {"x":centro_alvo.x,"y":centro_alvo.y}
			perseguicao["alcancouUnix"] = int(perseguicao.get("alcancouUnix", agora_unix))
			predador["perseguicaoAtual"] = perseguicao
			grupos[predador_id] = predador
			houve_mudanca = true
			atualizados.append(predador.duplicate(true))
			continue
		var especie: Dictionary = repositorio_criaturas.obter_criatura(str(predador.get("especieId", "")))
		var velocidade := clampf(float(especie.get("ecologia", {}).get("velocidadePerseguicao", 48.0)), 8.0, 120.0)
		var passo := minf(distancia - distancia_alcance, velocidade * delta_segundos)
		var deslocamento := (centro_alvo - centro_atual).normalized() * passo
		var novo_centro := centro_atual + deslocamento
		territorio["centro"] = {"x":novo_centro.x,"y":novo_centro.y}
		predador["territorio"] = territorio
		var individuos: Array = predador.get("individuos", [])
		for indice in range(individuos.size()):
			var individuo: Dictionary = individuos[indice].duplicate(true)
			var posicao_dados: Dictionary = individuo.get("posicaoMundo", {})
			var posicao := Vector2(float(posicao_dados.get("x", centro_atual.x)), float(posicao_dados.get("y", centro_atual.y))) + deslocamento
			individuo["posicaoMundo"] = {"x":posicao.x,"y":posicao.y}
			if bool(individuo.get("vivo", true)):
				individuo["estadoMundo"] = "perseguindo_presa"
			individuos[indice] = individuo
		predador["individuos"] = individuos
		perseguicao["estado"] = "seguindo"
		perseguicao["centroAlvo"] = {"x":centro_alvo.x,"y":centro_alvo.y}
		perseguicao["ultimaAtualizacaoUnix"] = agora_unix
		predador["perseguicaoAtual"] = perseguicao
		predador["atualizadoUnix"] = agora_unix
		grupos[predador_id] = predador
		houve_mudanca = true
		atualizados.append(predador.duplicate(true))
	if houve_mudanca:
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível persistir o avanço das perseguições."}
	return {"ok":true,"grupos":atualizados}

## Registra o primeiro ataque de uma perseguição que já alcançou a presa.
## A relação alimentar e o estado de alcance são revalidados no servidor.
func registrar_confronto_ecologico(grupo_predador_id: String, grupo_presa_id: String, individuo_alvo_id: String, agora_unix: int) -> Dictionary:
	if grupo_predador_id.is_empty() or grupo_presa_id.is_empty() or individuo_alvo_id.is_empty() or agora_unix < 0:
		return {"ok":false,"erro":"Dados do confronto ecológico inválidos."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_predador_id) or not grupos.has(grupo_presa_id):
		return {"ok":false,"erro":"Um dos grupos do confronto não existe."}
	var predador: Dictionary = grupos[grupo_predador_id].duplicate(true)
	var presa: Dictionary = grupos[grupo_presa_id].duplicate(true)
	var perseguicao: Dictionary = predador.get("perseguicaoAtual", {})
	if str(perseguicao.get("grupoAlvoId", "")) != grupo_presa_id or str(perseguicao.get("estado", "")) != "alcancou_alvo":
		return {"ok":false,"erro":"O predador ainda não alcançou esta presa."}
	var especie_predadora: Dictionary = repositorio_criaturas.obter_criatura(str(predador.get("especieId", "")))
	var especie_presa: Dictionary = repositorio_criaturas.obter_criatura(str(presa.get("especieId", "")))
	if especie_predadora.is_empty() or especie_presa.is_empty():
		return {"ok":false,"erro":"Espécie do confronto não encontrada no catálogo."}
	var ecologia_predador: Dictionary = especie_predadora.get("ecologia", {})
	var ecologia_presa: Dictionary = especie_presa.get("ecologia", {})
	var relacao_declarada: bool = ecologia_predador.get("especiesPresas", []).has(str(especie_presa.get("id", ""))) or ecologia_presa.get("especiesPredadoras", []).has(str(especie_predadora.get("id", "")))
	if not relacao_declarada or str(predador.get("ecossistemaId", "")) != str(presa.get("ecossistemaId", "")):
		return {"ok":false,"erro":"A relação predador-presa não autoriza este confronto."}
	var alvo_encontrado := false
	for individuo in presa.get("individuos", []):
		if str(individuo.get("individuoId", "")) == individuo_alvo_id:
			alvo_encontrado = true
			break
	if not alvo_encontrado:
		return {"ok":false,"erro":"O alvo não pertence ao grupo da presa."}
	perseguicao["estado"] = "confronto_iniciado"
	perseguicao["confrontoUnix"] = agora_unix
	perseguicao["ultimoAlvoIndividuoId"] = individuo_alvo_id
	perseguicao["ultimoAtaqueUnix"] = agora_unix
	predador["perseguicaoAtual"] = perseguicao
	predador["atualizadoUnix"] = agora_unix
	presa["ultimoConfrontoEcologico"] = {"grupoPredadorId":grupo_predador_id,"individuoAlvoId":individuo_alvo_id,"horarioUnix":agora_unix}
	presa["atualizadoUnix"] = agora_unix
	grupos[grupo_predador_id] = predador
	grupos[grupo_presa_id] = presa
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir o confronto ecológico."}
	return {"ok":true,"predador":predador.duplicate(true),"presa":presa.duplicate(true)}

## Aplica a decisão coletiva da presa ao encontrar um predador declarado.
## A migração só usa rotas seguras presentes no registro persistido da espécie.
func reagir_ameaca_ecologica(grupo_presa_id: String, grupo_predador_id: String, tem_aliado_proximo: bool, agora_unix: int) -> Dictionary:
	if grupo_presa_id.is_empty() or grupo_predador_id.is_empty() or grupo_presa_id == grupo_predador_id or agora_unix < 0:
		return {"ok":false,"erro":"Dados da ameaça ecológica inválidos."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_presa_id) or not grupos.has(grupo_predador_id):
		return {"ok":false,"erro":"Grupo ameaçado ou predador não encontrado."}
	var presa: Dictionary = grupos[grupo_presa_id].duplicate(true)
	var predador: Dictionary = grupos[grupo_predador_id]
	if str(presa.get("ecossistemaId", "")) != str(predador.get("ecossistemaId", "")):
		return {"ok":false,"erro":"Grupos de ecossistemas diferentes não podem se enfrentar."}
	var especie_presa: Dictionary = repositorio_criaturas.obter_criatura(str(presa.get("especieId", "")))
	var especie_predadora: Dictionary = repositorio_criaturas.obter_criatura(str(predador.get("especieId", "")))
	if especie_presa.is_empty() or especie_predadora.is_empty():
		return {"ok":false,"erro":"Espécie não encontrada no catálogo."}
	var ecologia_presa: Dictionary = especie_presa.get("ecologia", {})
	var ecologia_predadora: Dictionary = especie_predadora.get("ecologia", {})
	var dieta_valida: bool = ecologia_predadora.get("especiesPresas", []).has(str(especie_presa.get("id", ""))) or ecologia_presa.get("especiesPredadoras", []).has(str(especie_predadora.get("id", "")))
	if not dieta_valida:
		return {"ok":false,"erro":"A relação predador-presa não está declarada."}
	var reacao_anterior: Dictionary = presa.get("reacaoAmeacaAtual", {})
	if str(reacao_anterior.get("grupoPredadorId", "")) == grupo_predador_id and agora_unix - int(reacao_anterior.get("horarioUnix", 0)) < 30:
		return {"ok":true,"acao":str(reacao_anterior.get("acao", "defender")),"grupo":presa.duplicate(true),"repetida":true}
	var rotas: Array = presa.get("rotasMigracao", ecologia_presa.get("rotasMigracao", []))
	var tem_rota := not rotas.is_empty()
	var forca_presa := _calcular_forca_territorial(presa)
	var forca_predador := _calcular_forca_territorial(predador)
	var personalidade: Dictionary = presa.get("personalidade", {})
	var vida_total := 0.0
	var vida_maxima_total := 0.0
	var vivos := 0
	for individuo in presa.get("individuos", []):
		if not bool(individuo.get("vivo", false)):
			continue
		var atributos: Dictionary = individuo.get("atributos", {})
		var vida_maxima := maxf(1.0, float(atributos.get("vidaMaxima", 1)))
		vida_total += clampf(float(individuo.get("vidaAtual", vida_maxima)), 0.0, vida_maxima)
		vida_maxima_total += vida_maxima
		vivos += 1
	if vivos == 0:
		return {"ok":false,"erro":"O grupo ameaçado não possui sobreviventes."}
	var vida_media := vida_total / maxf(1.0, vida_maxima_total)
	var memoria_ecologica := _limpar_memoria_ecologica(presa.get("memoriaEcologica", []), agora_unix)
	var estrategia_predador: Dictionary = predador.get("estrategiaCacaAtual", {})
	var assinatura_tatica := str(estrategia_predador.get("estrategia", ""))
	var memoria_reconhecida := _memoria_reconhece_ameaca(memoria_ecologica, str(especie_predadora.get("id", "")), str(presa.get("ecossistemaId", "")), str(presa.get("bioma", "")))
	var decisao := SISTEMA_COMPORTAMENTO_CRIATURAS.decidir_reacao_presa(
		forca_presa, forca_predador,
		float(personalidade.get("coragem", 1.0)),
		float(personalidade.get("agressividade", 1.0)),
		vida_media, tem_rota, tem_aliado_proximo
	)
	if memoria_reconhecida:
		decisao = SISTEMA_COMPORTAMENTO_CRIATURAS.ajustar_reacao_com_memoria(decisao, tem_rota, tem_aliado_proximo)
	var acao := str(decisao.get("acao", "defender"))
	if acao == "fugir":
		var centro_atual_dados: Dictionary = presa.get("territorio", {}).get("centro", {})
		var centro_atual := Vector2(float(centro_atual_dados.get("x", -1.0)), float(centro_atual_dados.get("y", -1.0)))
		for rota in rotas:
			if not (rota is Dictionary):
				continue
			var destino: Dictionary = rota.get("territorio", {})
			var centro_dados: Dictionary = destino.get("centro", {})
			var centro_novo := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
			var raio_novo := float(destino.get("raio", 0.0))
			var novo_ecossistema := str(rota.get("ecossistemaId", ""))
			if str(rota.get("id", "")).is_empty() or novo_ecossistema.is_empty() or str(rota.get("bioma", "")).is_empty() or str(rota.get("habitat", "")).is_empty():
				continue
			if centro_novo.x < 0.0 or centro_novo.x > 2400.0 or centro_novo.y < 0.0 or centro_novo.y > 1600.0 or raio_novo < 20.0 or raio_novo > 1000.0:
				continue
			var ocupado := false
			for outro_id in grupos:
				if str(outro_id) == grupo_presa_id:
					continue
				var outro: Dictionary = grupos[outro_id]
				if str(outro.get("ecossistemaId", "")) != novo_ecossistema:
					continue
				var t: Dictionary = outro.get("territorio", {})
				var c: Dictionary = t.get("centro", {})
				if Vector2(float(c.get("x", -10000.0)), float(c.get("y", -10000.0))).distance_to(centro_novo) < float(t.get("raio", 0.0)) + raio_novo:
					ocupado = true
					break
			if ocupado:
				continue
			var individuos: Array = presa.get("individuos", [])
			for i in range(individuos.size()):
				var membro: Dictionary = individuos[i].duplicate(true)
				var p: Dictionary = membro.get("posicaoMundo", {})
				var deslocamento := Vector2(float(p.get("x", centro_atual.x)), float(p.get("y", centro_atual.y))) - centro_atual
				if deslocamento.length() > raio_novo - 5.0:
					deslocamento = deslocamento.normalized() * (raio_novo - 5.0)
				var nova_posicao := centro_novo + deslocamento
				membro["posicaoMundo"] = {"x":nova_posicao.x,"y":nova_posicao.y}
				if bool(membro.get("vivo", false)):
					membro["estadoMundo"] = "fugindo_de_predador"
				individuos[i] = membro
			presa["individuos"] = individuos
			presa["territorio"] = destino.duplicate(true)
			presa["ecossistemaId"] = novo_ecossistema
			presa["bioma"] = str(rota.get("bioma", ""))
			presa["habitat"] = str(rota.get("habitat", ""))
			presa["ultimaMigracaoUnix"] = agora_unix
			presa["ultimaMigracao"] = {"rotaId":str(rota.get("id", "")),"motivo":"ameaca_predador","ecossistemaAnterior":str(grupos[grupo_presa_id].get("ecossistemaId", "")),"horarioUnix":agora_unix}
			break
		if str(presa.get("ecossistemaId", "")) == str(predador.get("ecossistemaId", "")):
			acao = "defender"
			for i in range(presa.get("individuos", []).size()):
				var membro: Dictionary = presa["individuos"][i].duplicate(true)
				if bool(membro.get("vivo", false)):
					membro["estadoMundo"] = "defendendo_grupo"
				presa["individuos"][i] = membro
	else:
		for i in range(presa.get("individuos", []).size()):
			var membro: Dictionary = presa["individuos"][i].duplicate(true)
			if bool(membro.get("vivo", false)):
				membro["estadoMundo"] = "defendendo_com_aliados" if acao == "defender_com_aliados" else "defendendo_grupo"
			presa["individuos"][i] = membro
	if acao in ["defender", "defender_com_aliados"]:
		var centro_predador_dados: Dictionary = predador.get("territorio", {}).get("centro", {})
		var individuo_vulneravel: Dictionary = {}
		for membro in presa.get("individuos", []):
			if not bool(membro.get("vivo", false)):
				continue
			var atributos_membro: Dictionary = membro.get("atributos", {})
			var vida_max_membro := maxf(1.0, float(atributos_membro.get("vidaMaxima", 1.0)))
			var vida_relativa := float(membro.get("vidaAtual", vida_max_membro)) / vida_max_membro
			if str(membro.get("faseVida", "")) == "filhote" or vida_relativa <= 0.55:
				individuo_vulneravel = membro
				break
		if not individuo_vulneravel.is_empty():
			var centro_protegido: Dictionary = individuo_vulneravel.get("posicaoMundo", {})
			presa["formacaoTatica"] = {
				"tipo":"proteger_vulneraveis",
				"centroProtegido":{"x":float(centro_protegido.get("x", -1.0)),"y":float(centro_protegido.get("y", -1.0))},
				"individuoProtegidoId":str(individuo_vulneravel.get("individuoId", "")),
				"centroAmeaca":{"x":float(centro_predador_dados.get("x", -1.0)),"y":float(centro_predador_dados.get("y", -1.0))},
				"raio":24.0,"expiraUnix":agora_unix + 45
			}
		else:
			presa["formacaoTatica"] = {
				"tipo":"defesa",
				"centroAmeaca":{"x":float(centro_predador_dados.get("x", -1.0)),"y":float(centro_predador_dados.get("y", -1.0))},
				"raio":26.0,"expiraUnix":agora_unix + 45
			}
	else:
		presa.erase("formacaoTatica")
	memoria_ecologica.append({
		"especiePredadoraId":str(especie_predadora.get("id", "")),
		"ecossistemaId":str(grupos[grupo_presa_id].get("ecossistemaId", "")),
		"bioma":str(grupos[grupo_presa_id].get("bioma", "")),
		"estrategiaObservada":assinatura_tatica if not assinatura_tatica.is_empty() else "tática_nao_identificada",
		"respostaAprendida":acao,
		"horarioUnix":agora_unix
	})
	while memoria_ecologica.size() > 10:
		memoria_ecologica.pop_front()
	presa["memoriaEcologica"] = memoria_ecologica
	presa["reacaoAmeacaAtual"] = {"grupoPredadorId":grupo_predador_id,"acao":acao,"motivo":str(decisao.get("motivo", "")),"horarioUnix":agora_unix,"forcaRelativa":snappedf(forca_presa / maxf(1.0, forca_predador), 0.01),"ameacaReconhecida":memoria_reconhecida}
	presa["atualizadoUnix"] = agora_unix
	grupos[grupo_presa_id] = presa
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir a reação da presa."}
	return {"ok":true,"acao":acao,"grupo":presa.duplicate(true),"reacao":decisao}


## Registra aprendizado somente após uma caçada real que terminou em fuga ou perda de rastro.
func _registrar_aprendizado_cacada(predador: Dictionary, presa: Dictionary, resultado: String, agora_unix: int) -> void:
	var memoria: Array = []
	for registro in predador.get("memoriaCacada", []):
		if not (registro is Dictionary):
			continue
		var horario_memoria := int(registro.get("horarioUnix", 0))
		if horario_memoria <= 0 or horario_memoria > agora_unix or agora_unix - horario_memoria > 604800:
			continue
		if str(registro.get("especiePresaId", "")).is_empty():
			continue
		memoria.append(registro.duplicate(true))
	memoria.append({
		"especiePresaId":str(presa.get("especieId", "")),
		"ecossistemaId":str(predador.get("ecossistemaId", "")),
		"bioma":str(predador.get("bioma", "")),
		"estrategiaAnterior":str(predador.get("estrategiaCacaAtual", {}).get("estrategia", "perseguir")),
		"resultado":resultado,
		"horarioUnix":agora_unix
	})
	while memoria.size() > 10:
		memoria.pop_front()
	predador["memoriaCacada"] = memoria

## Mantém apenas lembranças recentes e válidas; o grupo não conhece ameaças que nunca encontrou.
func _limpar_memoria_ecologica(memoria: Array, agora_unix: int) -> Array:
	var limpa: Array = []
	for registro in memoria:
		if not (registro is Dictionary):
			continue
		var horario := int(registro.get("horarioUnix", 0))
		if horario <= 0 or horario > agora_unix or agora_unix - horario > 604800:
			continue
		if str(registro.get("especiePredadoraId", "")).is_empty() or str(registro.get("ecossistemaId", "")).is_empty():
			continue
		limpa.append(registro.duplicate(true))
	while limpa.size() > 10:
		limpa.pop_front()
	return limpa

func _memoria_reconhece_ameaca(memoria: Array, especie_predadora_id: String, ecossistema_id: String, bioma: String) -> bool:
	for registro in memoria:
		if str(registro.get("especiePredadoraId", "")) == especie_predadora_id and str(registro.get("ecossistemaId", "")) == ecossistema_id and str(registro.get("bioma", "")) == bioma:
			return true
	return false

## Persiste posições calculadas pelo servidor sem aceitar criação, remoção ou alteração de vida dos indivíduos.
func salvar_movimento_grupo(grupo_id: String, individuos_atualizados: Array, agora_unix: int = -1) -> bool:
	if individuos_atualizados.size() > 500:
		return false
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return false
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var existentes: Dictionary = {}
	for individuo in grupo.get("individuos", []):
		existentes[str(individuo.get("individuoId", ""))] = individuo
	if individuos_atualizados.size() != existentes.size():
		return false
	var novos: Array = []
	for individuo_novo in individuos_atualizados:
		if not (individuo_novo is Dictionary):
			return false
		var id := str(individuo_novo.get("individuoId", ""))
		if not existentes.has(id):
			return false
		var original: Dictionary = existentes[id]
		if bool(individuo_novo.get("vivo", true)) != bool(original.get("vivo", true)):
			return false
		var posicao: Dictionary = individuo_novo.get("posicaoMundo", {})
		if not (posicao is Dictionary):
			return false
		var ponto := Vector2(float(posicao.get("x", -1.0)), float(posicao.get("y", -1.0)))
		if ponto.x < 0.0 or ponto.x > 2400.0 or ponto.y < 0.0 or ponto.y > 1600.0:
			return false
		var territorio: Dictionary = grupo.get("territorio", {})
		var centro_dados: Dictionary = territorio.get("centro", {})
		var centro := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
		if ponto.distance_to(centro) > float(territorio.get("raio", 0.0)) + 0.01:
			return false
		var atualizado: Dictionary = original.duplicate(true)
		atualizado["posicaoMundo"] = {"x":ponto.x,"y":ponto.y}
		atualizado["estadoMundo"] = str(individuo_novo.get("estadoMundo", "acompanhando_grupo"))
		novos.append(atualizado)
	grupo["individuos"] = novos
	grupo["atualizadoUnix"] = agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	return _gravar_banco(banco)

## Retira um indivíduo domesticado do grupo, preservando o registro histórico.
func registrar_domesticacao_individuo(grupo_id: String, individuo_id: String, agora_unix: int = -1) -> Dictionary:
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo selvagem não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var individuos: Array = grupo.get("individuos", [])
	var indice_alvo := -1
	for indice in range(individuos.size()):
		if str(individuos[indice].get("individuoId", "")) == individuo_id:
			indice_alvo = indice
			break
	if indice_alvo < 0:
		return {"ok":false,"erro":"A criatura não está mais no grupo."}
	var alvo: Dictionary = individuos[indice_alvo].duplicate(true)
	var derrotado_em_combate := bool(alvo.get("derrotadoEmCombate", false))
	if (not bool(alvo.get("vivo", false)) and not derrotado_em_combate) or bool(alvo.get("domesticado", false)):
		return {"ok":false,"erro":"Essa criatura não está mais disponível para domesticação."}
	alvo["vivo"] = false
	alvo["domesticado"] = true
	alvo["causaSaida"] = "domesticacao"
	alvo["domesticadoUnix"] = agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	individuos[indice_alvo] = alvo
	grupo["individuos"] = individuos
	if not derrotado_em_combate:
		var populacao: Dictionary = grupo.get("populacaoEstado", {})
		populacao["quantidade"] = maxi(0, int(populacao.get("quantidade", individuos.size())) - 1)
		grupo["populacaoEstado"] = populacao
	if str(grupo.get("liderAtual", {}).get("individuoId", "")) == individuo_id:
		var sucessao := SISTEMA_LIDERES.suceder_lider(grupo, individuo_id, hash(grupo_id + ":" + individuo_id + ":domesticado"))
		grupo["liderAtual"] = sucessao.get("lider", {}) if bool(sucessao.get("temLider", false)) else {}
	grupo["atualizadoUnix"] = int(alvo["domesticadoUnix"])
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a saída da criatura do grupo."}
	return {"ok":true,"grupo":grupo.duplicate(true),"individuo":alvo.duplicate(true)}

## Registra a derrota de um indivíduo por jogador e mantém o corpo para domesticação.
func registrar_derrota_em_combate(grupo_id: String, individuo_id: String, uid_vencedor: String, agora_unix: int = -1) -> Dictionary:
	if grupo_id.is_empty() or individuo_id.is_empty() or uid_vencedor.is_empty() or uid_vencedor.length() > 128:
		return {"ok":false,"erro":"Identificação da derrota inválida."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo da criatura derrotada não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var individuos: Array = grupo.get("individuos", [])
	var indice_alvo := -1
	for i in range(individuos.size()):
		if str(individuos[i].get("individuoId", "")) == individuo_id:
			indice_alvo = i
			break
	if indice_alvo < 0:
		return {"ok":false,"erro":"Indivíduo derrotado não pertence ao grupo."}
	var alvo: Dictionary = individuos[indice_alvo].duplicate(true)
	if bool(alvo.get("domesticado", false)):
		return {"ok":false,"erro":"Esse indivíduo já foi domesticado."}
	if bool(alvo.get("derrotadoEmCombate", false)):
		return {"ok":true,"grupo":grupo.duplicate(true),"individuo":alvo.duplicate(true),"duplicado":true}
	if not bool(alvo.get("vivo", true)):
		return {"ok":false,"erro":"O indivíduo já estava morto antes do combate."}
	var instante := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	alvo["vivo"] = false
	alvo["vidaAtual"] = 0
	alvo["derrotadoEmCombate"] = true
	alvo["derrotadoPorUid"] = uid_vencedor
	alvo["derrotadoEmCombateUnix"] = instante
	alvo["causaMorte"] = "combate_jogador"
	var especie: Dictionary = repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
	alvo["carcaca"] = _criar_carcarca(alvo, especie, instante)
	individuos[indice_alvo] = alvo
	grupo["individuos"] = individuos
	var populacao: Dictionary = grupo.get("populacaoEstado", {})
	populacao["quantidade"] = maxi(0, int(populacao.get("quantidade", 0)) - 1)
	grupo["populacaoEstado"] = populacao
	if str(grupo.get("liderAtual", {}).get("individuoId", "")) == individuo_id:
		var sucessao := SISTEMA_LIDERES.suceder_lider(grupo, individuo_id, hash(individuo_id + ":derrotado:" + str(instante)))
		grupo["liderAtual"] = sucessao.get("lider", {}) if bool(sucessao.get("temLider", false)) else {}
	grupo["atualizadoUnix"] = instante
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a criatura derrotada."}
	return {"ok":true,"grupo":grupo.duplicate(true),"individuo":alvo.duplicate(true)}

## Aplica dano calculado pelo servidor; morte ecológica reduz a população e pode trocar o líder.
func aplicar_dano_ecologico(grupo_id: String, individuo_id: String, dano: int, agora_unix: int = -1) -> Dictionary:
	if dano <= 0 or dano > 100000000:
		return {"ok":false,"erro":"Dano ecológico inválido."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo da presa não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var individuos: Array = grupo.get("individuos", [])
	var indice_alvo := -1
	for i in range(individuos.size()):
		if str(individuos[i].get("individuoId", "")) == individuo_id:
			indice_alvo = i
			break
	if indice_alvo < 0:
		return {"ok":false,"erro":"Indivíduo alvo não pertence ao grupo."}
	var alvo: Dictionary = individuos[indice_alvo].duplicate(true)
	if not bool(alvo.get("vivo", false)):
		return {"ok":false,"erro":"Indivíduo já está morto."}
	var atributos: Dictionary = alvo.get("atributos", {})
	var vida_maxima := maxi(1, int(atributos.get("vidaMaxima", 1)))
	var vida_atual := clampi(int(alvo.get("vidaAtual", vida_maxima)), 1, vida_maxima)
	var vida_restante := maxi(0, vida_atual - dano)
	alvo["vidaAtual"] = vida_restante
	alvo["ultimoDanoEcologicoUnix"] = agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	if vida_restante <= 0:
		alvo["vivo"] = false
		alvo["causaMorte"] = "combate_ecologico"
		alvo["morteUnix"] = int(alvo["ultimoDanoEcologicoUnix"])
		var especie_morta: Dictionary = repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
		alvo["carcaca"] = _criar_carcarca(alvo, especie_morta, int(alvo["morteUnix"]))
		var estado: Dictionary = grupo.get("populacaoEstado", {})
		estado["quantidade"] = maxi(0, int(estado.get("quantidade", 0)) - 1)
		estado["minima"] = mini(int(estado.get("minima", 0)), int(estado["quantidade"]))
		estado["totalMortesEcologicas"] = int(estado.get("totalMortesEcologicas", 0)) + 1
		grupo["populacaoEstado"] = estado
	individuos[indice_alvo] = alvo
	grupo["individuos"] = individuos
	var lider_anterior := str(grupo.get("liderAtual", {}).get("individuoId", ""))
	if vida_restante <= 0 and lider_anterior == individuo_id:
		var sucessao := SISTEMA_LIDERES.suceder_lider(grupo, individuo_id, hash(individuo_id + ":" + str(alvo["morteUnix"])))
		grupo["liderAtual"] = sucessao.get("lider", {}) if bool(sucessao.get("temLider", false)) else {}
	elif vida_restante <= 0 and lider_anterior.is_empty():
		var avaliacao := SISTEMA_LIDERES.avaliar_grupo(grupo, hash(grupo_id + ":" + str(alvo["morteUnix"])))
		grupo["liderAtual"] = avaliacao.get("lider", {})
	grupo["atualizadoUnix"] = int(alvo.get("ultimoDanoEcologicoUnix", 0))
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Falha ao persistir dano ecológico."}
	return {"ok":true,"morreu":vida_restante <= 0,"vidaRestante":vida_restante,"grupo":grupo.duplicate(true),"individuo":alvo.duplicate(true)}

## Conta ciclos de escassez e migra o grupo inteiro para um habitat alternativo declarado pela espécie.
func avaliar_migracao_por_escassez(grupo_id: String, alimento_disponivel: float, agora_unix: int) -> Dictionary:
	if alimento_disponivel < 0.0 or alimento_disponivel > 1.0:
		return {"ok":false,"erro":"Índice alimentar inválido."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	if alimento_disponivel <= 0.25:
		grupo["ciclosEscassezAlimentar"] = int(grupo.get("ciclosEscassezAlimentar", 0)) + 1
	else:
		grupo["ciclosEscassezAlimentar"] = 0
	if int(grupo["ciclosEscassezAlimentar"]) < 3:
		grupos[grupo_id] = grupo
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível salvar o estado de escassez."}
		return {"ok":true,"migrou":false,"grupo":grupo}
	if int(grupo.get("ultimaMigracaoUnix", 0)) > 0 and agora_unix < int(grupo.get("ultimaMigracaoUnix", 0)) + 86400:
		grupos[grupo_id] = grupo
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível salvar o intervalo de migração."}
		return {"ok":true,"migrou":false,"grupo":grupo}
	var rotas: Array = grupo.get("rotasMigracao", [])
	var territorio_atual: Dictionary = grupo.get("territorio", {})
	var centro_atual_dados: Dictionary = territorio_atual.get("centro", {})
	var centro_atual := Vector2(float(centro_atual_dados.get("x", -1.0)), float(centro_atual_dados.get("y", -1.0)))
	for rota in rotas:
		if not (rota is Dictionary):
			continue
		var destino: Dictionary = rota.get("territorio", {})
		var centro_dados: Dictionary = destino.get("centro", {})
		var centro_novo := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
		var raio_novo := float(destino.get("raio", 0.0))
		var ecossistema_novo := str(rota.get("ecossistemaId", ""))
		var bioma_novo := str(rota.get("bioma", ""))
		var habitat_novo := str(rota.get("habitat", ""))
		var rota_id := str(rota.get("id", ""))
		if rota_id.is_empty() or ecossistema_novo.is_empty() or bioma_novo.is_empty() or habitat_novo.is_empty():
			continue
		if centro_novo.x < 0.0 or centro_novo.x > 2400.0 or centro_novo.y < 0.0 or centro_novo.y > 1600.0 or raio_novo < 20.0 or raio_novo > 1000.0:
			continue
		if centro_novo.distance_to(centro_atual) < 1.0:
			continue
		var grupo_ocupante_id := ""
		for outro_id in grupos:
			if str(outro_id) == grupo_id:
				continue
			var outro: Dictionary = grupos[outro_id]
			if str(outro.get("ecossistemaId", "")) != ecossistema_novo:
				continue
			var t: Dictionary = outro.get("territorio", {})
			var c: Dictionary = t.get("centro", {})
			var centro_outro := Vector2(float(c.get("x", -10000.0)), float(c.get("y", -10000.0)))
			if centro_outro.distance_to(centro_novo) < float(t.get("raio", 0.0)) + raio_novo:
				grupo_ocupante_id = str(outro_id)
				break
		if not grupo_ocupante_id.is_empty():
			var defensor: Dictionary = grupos[grupo_ocupante_id].duplicate(true)
			var disputa := _resolver_disputa_territorial(grupo, defensor, agora_unix)
			if not bool(disputa.get("ok", false)):
				return disputa
			grupo = disputa.get("grupoDesafiante", grupo)
			defensor = disputa.get("grupoDefensor", defensor)
			var vencedor_id := str(disputa.get("vencedorGrupoId", ""))
			var registro_disputa := {
				"grupoDesafiante":grupo_id,
				"grupoDefensor":grupo_ocupante_id,
				"resultado":str(disputa.get("resultado", "")),
				"representantes":disputa.get("representantes", {}),
				"turnosDuelo":disputa.get("turnosDuelo", []),
				"decisaoDerrotado":str(disputa.get("decisaoDerrotado", "")),
				"turnosConfrontoColetivo":disputa.get("turnosConfrontoColetivo", []),
				"moralVencedorAposDuelo":float(disputa.get("moralVencedorAposDuelo", 1.0)),
				"horarioUnix":agora_unix
			}
			_registrar_relacao_conflito(grupo, defensor, agora_unix, vencedor_id)
			var historico_defensor: Array = defensor.get("disputasTerritoriais", [])
			historico_defensor.append(registro_disputa)
			defensor["disputasTerritoriais"] = historico_defensor.slice(maxi(0, historico_defensor.size() - 20))
			defensor["ultimaDisputaTerritorial"] = registro_disputa
			grupo["ultimaDisputaTerritorial"] = registro_disputa
			grupo["ciclosEscassezAlimentar"] = 0
			if vencedor_id != grupo_id:
				grupos[grupo_ocupante_id] = defensor
				grupos[grupo_id] = grupo
				banco["grupos"] = grupos
				if not _gravar_banco(banco):
					return {"ok":false,"erro":"Não foi possível salvar a disputa territorial."}
				return {"ok":true,"migrou":false,"disputaTerritorial":true,"vencedor":vencedor_id,"resultado":str(disputa.get("resultado", "defensor_manteve_territorio")),"decisaoDerrotado":str(disputa.get("decisaoDerrotado", "")),"grupo":grupo.duplicate(true)}
			var centro_defensor_dados: Dictionary = defensor.get("territorio", {}).get("centro", {})
			var centro_defensor := Vector2(float(centro_defensor_dados.get("x", -1.0)), float(centro_defensor_dados.get("y", -1.0)))
			var direcao := centro_defensor - centro_novo
			if direcao.length() < 0.01:
				var angulo := float(abs(hash(grupo_id + "|" + grupo_ocupante_id)) % 6283) / 1000.0
				direcao = Vector2(cos(angulo), sin(angulo))
			else:
				direcao = direcao.normalized()
			var raio_defensor := float(defensor.get("territorio", {}).get("raio", 0.0))
			var centro_recuo := centro_novo + direcao * (raio_novo + raio_defensor + 12.0)
			var pode_recuar := centro_recuo.x >= raio_defensor and centro_recuo.x <= 2400.0 - raio_defensor and centro_recuo.y >= raio_defensor and centro_recuo.y <= 1600.0 - raio_defensor
			if not pode_recuar or _territorio_tem_conflito(grupos, grupo_id, grupo_ocupante_id, ecossistema_novo, centro_recuo, raio_defensor):
				grupos[grupo_ocupante_id] = defensor
				grupos[grupo_id] = grupo
				banco["grupos"] = grupos
				if not _gravar_banco(banco):
					return {"ok":false,"erro":"Não foi possível salvar a disputa territorial."}
				return {"ok":true,"migrou":false,"disputaTerritorial":true,"vencedor":grupo_id,"resultado":"invasor_venceu_mas_sem_recuo_seguro","grupo":grupo.duplicate(true)}
			var deslocamento_recuo := centro_recuo - centro_defensor
			var individuos_defensor: Array = defensor.get("individuos", [])
			for indice_defensor in range(individuos_defensor.size()):
				var membro: Dictionary = individuos_defensor[indice_defensor].duplicate(true)
				var pos_membro: Dictionary = membro.get("posicaoMundo", {})
				var pos_nova := Vector2(float(pos_membro.get("x", centro_defensor.x)), float(pos_membro.get("y", centro_defensor.y)) + 0.0) + deslocamento_recuo
				membro["posicaoMundo"] = {"x":pos_nova.x,"y":pos_nova.y}
				if bool(membro.get("vivo", false)):
					membro["estadoMundo"] = "recuando_apos_disputa"
				individuos_defensor[indice_defensor] = membro
			defensor["individuos"] = individuos_defensor
			var territorio_defensor: Dictionary = defensor.get("territorio", {}).duplicate(true)
			territorio_defensor["centro"] = {"x":centro_recuo.x,"y":centro_recuo.y}
			defensor["territorio"] = territorio_defensor
			grupos[grupo_ocupante_id] = defensor
		var individuos: Array = grupo.get("individuos", [])
		for indice in range(individuos.size()):
			var individuo: Dictionary = individuos[indice].duplicate(true)
			var p: Dictionary = individuo.get("posicaoMundo", {})
			var deslocamento := Vector2(float(p.get("x", centro_atual.x)), float(p.get("y", centro_atual.y))) - centro_atual
			if deslocamento.length() > raio_novo - 5.0:
				deslocamento = deslocamento.normalized() * (raio_novo - 5.0)
			var nova_posicao := centro_novo + deslocamento
			individuo["posicaoMundo"] = {"x":nova_posicao.x,"y":nova_posicao.y}
			individuo["estadoMundo"] = "migrando"
			individuos[indice] = individuo
		grupo["individuos"] = individuos
		var ecossistema_anterior := str(grupo.get("ecossistemaId", ""))
		grupo["territorio"] = destino.duplicate(true)
		grupo["ecossistemaId"] = ecossistema_novo
		grupo["bioma"] = bioma_novo
		grupo["habitat"] = habitat_novo
		grupo["ultimaMigracaoUnix"] = agora_unix
		grupo["ciclosEscassezAlimentar"] = 0
		grupo["atualizadoUnix"] = agora_unix
		grupo["ultimaMigracao"] = {"rotaId":rota_id,"ecossistemaAnterior":ecossistema_anterior,"horarioUnix":agora_unix}
		grupos[grupo_id] = grupo
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível persistir a migração."}
		return {"ok":true,"migrou":true,"rotaId":rota_id,"disputaTerritorial":not grupo_ocupante_id.is_empty(),"resultadoDisputa":"invasor_conquistou_territorio" if not grupo_ocupante_id.is_empty() else "sem_disputa","grupo":grupo.duplicate(true)}
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a tentativa de migração."}
	return {"ok":true,"migrou":false,"semDestinoDisponivel":true,"grupo":grupo}



## Resolve primeiro um duelo entre representantes; depois permite ao derrotado optar por guerra coletiva.
## Toda a resolução é determinística e executada pelo repositório autoritativo do servidor.
func _resolver_disputa_territorial(desafiante_in: Dictionary, defensor_in: Dictionary, agora_unix: int) -> Dictionary:
	var desafiante: Dictionary = desafiante_in.duplicate(true)
	var defensor: Dictionary = defensor_in.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(desafiante.get("grupoId", "")) + "|" + str(defensor.get("grupoId", "")) + "|" + str(agora_unix))
	var fila_a := _ordenar_representantes(desafiante)
	var fila_d := _ordenar_representantes(defensor)
	if fila_a.is_empty() or fila_d.is_empty():
		var vencedor_sem_duelo := str(defensor.get("grupoId", "")) if fila_a.is_empty() else str(desafiante.get("grupoId", ""))
		return {"ok":true,"grupoDesafiante":desafiante,"grupoDefensor":defensor,"vencedorGrupoId":vencedor_sem_duelo,"resultado":"grupo_sem_combatentes_vivos","representantes":{},"turnosDuelo":[],"decisaoDerrotado":"sem_combatentes"}
	var representante_a_id := str(fila_a[0].get("individuoId", ""))
	var representante_d_id := str(fila_d[0].get("individuoId", ""))
	var turnos_duelo: Array = []
	var indice_a := 0
	var indice_d := 0
	var turnos := 0
	while indice_a < fila_a.size() and indice_d < fila_d.size() and turnos < 500:
		var id_a := str(fila_a[indice_a].get("individuoId", ""))
		var id_d := str(fila_d[indice_d].get("individuoId", ""))
		var membro_a := _obter_individuo(desafiante, id_a)
		var membro_d := _obter_individuo(defensor, id_d)
		if membro_a.is_empty() or not bool(membro_a.get("vivo", false)):
			indice_a += 1
			continue
		if membro_d.is_empty() or not bool(membro_d.get("vivo", false)):
			indice_d += 1
			continue
		var agilidade_a := _atributo_com_equipamento(membro_a, "agilidade")
		var agilidade_d := _atributo_com_equipamento(membro_d, "agilidade")
		var a_comeca := agilidade_a > agilidade_d or (is_equal_approx(agilidade_a, agilidade_d) and str(desafiante.get("grupoId", "")) < str(defensor.get("grupoId", "")))
		for atacante_lado in (["a", "d"] if a_comeca else ["d", "a"]):
			var atacante_grupo: Dictionary = desafiante if atacante_lado == "a" else defensor
			var alvo_grupo: Dictionary = defensor if atacante_lado == "a" else desafiante
			var atacante_id := id_a if atacante_lado == "a" else id_d
			var alvo_id := id_d if atacante_lado == "a" else id_a
			var atacante := _obter_individuo(atacante_grupo, atacante_id)
			var alvo := _obter_individuo(alvo_grupo, alvo_id)
			if atacante.is_empty() or alvo.is_empty() or not bool(atacante.get("vivo", false)) or not bool(alvo.get("vivo", false)):
				continue
			var ataque := _atributo_com_equipamento(atacante, "ataque")
			var defesa := _atributo_com_equipamento(alvo, "defesa")
			if atacante_lado == "a":
				defesa *= 1.15
			var moral := float(atacante_grupo.get("moralMultiplicador", 1.0))
			var dano := maxi(1, roundi(maxf(1.0, ataque * moral * rng.randf_range(0.82, 1.12) - defesa * 0.30)))
			var dano_aplicado := _aplicar_dano_local(alvo_grupo, alvo_id, dano, agora_unix)
			turnos_duelo.append({"atacante":atacante_id,"alvo":alvo_id,"dano":dano_aplicado,"morreu":not bool(_obter_individuo(alvo_grupo, alvo_id).get("vivo", false))})
			if atacante_lado == "a":
				desafiante = atacante_grupo
				defensor = alvo_grupo
			else:
				defensor = atacante_grupo
				desafiante = alvo_grupo
			if not bool(_obter_individuo(alvo_grupo, alvo_id).get("vivo", false)):
				if atacante_lado == "a":
					indice_d += 1
				else:
					indice_a += 1
			turnos += 1
			if turnos >= 500:
				break
		if indice_a >= fila_a.size() or indice_d >= fila_d.size():
			break
	var vencedor_duelo_id := str(desafiante.get("grupoId", "")) if indice_d >= fila_d.size() else str(defensor.get("grupoId", ""))
	var vencedor_duelo: Dictionary = desafiante if vencedor_duelo_id == str(desafiante.get("grupoId", "")) else defensor
	var perdedor_duelo: Dictionary = defensor if vencedor_duelo_id == str(desafiante.get("grupoId", "")) else desafiante
	_aplicar_bonus_moral(vencedor_duelo, agora_unix)
	var moral_pos_duelo := float(vencedor_duelo.get("moralMultiplicador", 1.0))
	var continuar := _decidir_guerra_coletiva(perdedor_duelo, vencedor_duelo, rng)
	var decisao := "continuar_com_todo_o_grupo" if continuar else "aceitar_derrota_e_recuar"
	var turnos_coletivos: Array = []
	var vencedor_final_id := vencedor_duelo_id
	if continuar:
		var guerra := _resolver_confronto_coletivo(desafiante, defensor, agora_unix, rng)
		desafiante = guerra.get("grupoDesafiante", desafiante)
		defensor = guerra.get("grupoDefensor", defensor)
		vencedor_final_id = str(guerra.get("vencedorGrupoId", ""))
		turnos_coletivos = guerra.get("turnos", [])
		if vencedor_final_id.is_empty():
			vencedor_final_id = vencedor_duelo_id
	_reavaliar_lideranca(desafiante, agora_unix)
	_reavaliar_lideranca(defensor, agora_unix)
	var vencedor_nome := "invasor_conquistou_territorio" if vencedor_final_id == str(desafiante.get("grupoId", "")) else "defensor_manteve_territorio"
	return {"ok":true,"grupoDesafiante":desafiante,"grupoDefensor":defensor,"vencedorGrupoId":vencedor_final_id,"resultado":vencedor_nome,"representantes":{"desafiante":representante_a_id,"defensor":representante_d_id},"turnosDuelo":turnos_duelo.slice(0, 1000),"decisaoDerrotado":decisao,"turnosConfrontoColetivo":turnos_coletivos.slice(0, 1000),"moralVencedorAposDuelo":moral_pos_duelo}

func _ordenar_representantes(grupo: Dictionary) -> Array:
	var vivos: Array = []
	for individuo in grupo.get("individuos", []):
		if bool(individuo.get("vivo", false)):
			vivos.append(individuo.duplicate(true))
	vivos.sort_custom(func(a, b):
		var id_a := str(a.get("individuoId", ""))
		var id_b := str(b.get("individuoId", ""))
		var lider_id := str(grupo.get("liderAtual", {}).get("individuoId", ""))
		if id_a == lider_id:
			return true
		if id_b == lider_id:
			return false
		var poder_a := _poder_individual(a)
		var poder_b := _poder_individual(b)
		if is_equal_approx(poder_a, poder_b):
			return id_a < id_b
		return poder_a > poder_b
	)
	return vivos

func _poder_individual(individuo: Dictionary) -> float:
	var ataque := _atributo_com_equipamento(individuo, "ataque")
	var defesa := _atributo_com_equipamento(individuo, "defesa")
	var vida := float(individuo.get("vidaAtual", individuo.get("atributos", {}).get("vidaMaxima", 1)))
	var agilidade := _atributo_com_equipamento(individuo, "agilidade")
	var magia := float(individuo.get("atributos", {}).get("poderMagico", 0))
	return ataque * 1.5 + defesa + vida * 0.1 + agilidade * 0.5 + magia

func _atributo_com_equipamento(individuo: Dictionary, atributo: String) -> float:
	var atributos: Dictionary = individuo.get("_atributosCombate", individuo.get("atributos", {}))
	var valor := float(atributos.get(atributo, 1 if atributo == "ataque" else 0))
	var equipamentos: Array = individuo.get("_equipamentosCombate", individuo.get("equipamentoIds", []))
	for item_id in equipamentos:
		var item := SISTEMA_EQUIPAMENTOS.obter(str(item_id))
		if atributo == "ataque":
			valor += float(item.get("dano", 0)) * 0.25
		elif atributo == "defesa":
			valor += float(item.get("defesa", 0))
	return valor

func _obter_individuo(grupo: Dictionary, individuo_id: String) -> Dictionary:
	for individuo in grupo.get("individuos", []):
		if str(individuo.get("individuoId", "")) == individuo_id:
			var copia: Dictionary = individuo.duplicate(true)
			var lider: Dictionary = grupo.get("liderAtual", {})
			if str(lider.get("individuoId", "")) == individuo_id:
				copia["_atributosCombate"] = lider.get("atributosLider", copia.get("atributos", {})).duplicate(true)
				copia["_equipamentosCombate"] = lider.get("equipamentoIds", copia.get("equipamentoIds", [])).duplicate(true)
			return copia
	return {}

func _aplicar_dano_local(grupo: Dictionary, individuo_id: String, dano: int, agora_unix: int) -> int:
	var individuos: Array = grupo.get("individuos", [])
	for indice in range(individuos.size()):
		if str(individuos[indice].get("individuoId", "")) != individuo_id:
			continue
		var alvo: Dictionary = individuos[indice].duplicate(true)
		if not bool(alvo.get("vivo", false)):
			return 0
		var vida_maxima := maxi(1, int(alvo.get("atributos", {}).get("vidaMaxima", 1)))
		var vida := clampi(int(alvo.get("vidaAtual", vida_maxima)), 0, vida_maxima)
		var restante := maxi(0, vida - maxi(1, dano))
		alvo["vidaAtual"] = restante
		alvo["ultimoDanoEcologicoUnix"] = agora_unix
		if restante == 0:
			alvo["vivo"] = false
			alvo["causaMorte"] = "disputa_territorial"
			alvo["morteUnix"] = agora_unix
			var especie: Dictionary = repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
			alvo["carcaca"] = _criar_carcarca(alvo, especie, agora_unix)
			var estado: Dictionary = grupo.get("populacaoEstado", {})
			estado["quantidade"] = maxi(0, int(estado.get("quantidade", 0)) - 1)
			estado["minima"] = mini(int(estado.get("minima", 0)), int(estado["quantidade"]))
			estado["totalMortesEcologicas"] = int(estado.get("totalMortesEcologicas", 0)) + 1
			grupo["populacaoEstado"] = estado
		individuos[indice] = alvo
		grupo["individuos"] = individuos
		return mini(maxi(1, dano), vida)
	return 0

func _reavaliar_lideranca(grupo: Dictionary, agora_unix: int) -> void:
	var avaliacao := SISTEMA_LIDERES.avaliar_grupo(grupo, hash(str(grupo.get("grupoId", "")) + ":" + str(agora_unix)))
	grupo["liderAtual"] = avaliacao.get("lider", {}) if bool(avaliacao.get("temLider", false)) else {}

func _aplicar_bonus_moral(grupo: Dictionary, agora_unix: int) -> void:
	var moral_anterior := clampf(float(grupo.get("moralMultiplicador", 1.0)), 0.25, 2.0)
	var moral_nova := minf(2.0, moral_anterior * 1.20)
	grupo["moralMultiplicador"] = moral_nova
	grupo["moralAtualizadaUnix"] = agora_unix
	var individuos: Array = grupo.get("individuos", [])
	for indice in range(individuos.size()):
		var membro: Dictionary = individuos[indice].duplicate(true)
		if bool(membro.get("vivo", false)):
			membro["moralMultiplicador"] = minf(2.0, float(membro.get("moralMultiplicador", moral_anterior)) * 1.20)
		individuos[indice] = membro
	grupo["individuos"] = individuos

func _decidir_guerra_coletiva(perdedor: Dictionary, vencedor: Dictionary, rng: RandomNumberGenerator) -> bool:
	var poder_perdedor := 0.0
	var poder_vencedor := 0.0
	var vivos_perdedor := 0
	var vivos_vencedor := 0
	var saude_perdedor := 0.0
	var saude_vencedor := 0.0
	for membro in perdedor.get("individuos", []):
		if bool(membro.get("vivo", false)):
			vivos_perdedor += 1
			poder_perdedor += _poder_individual(membro) * float(perdedor.get("moralMultiplicador", 1.0))
			saude_perdedor += float(membro.get("vidaAtual", 1)) / maxf(1.0, float(membro.get("atributos", {}).get("vidaMaxima", 1)))
	for membro in vencedor.get("individuos", []):
		if bool(membro.get("vivo", false)):
			vivos_vencedor += 1
			poder_vencedor += _poder_individual(membro) * float(vencedor.get("moralMultiplicador", 1.0))
			saude_vencedor += float(membro.get("vidaAtual", 1)) / maxf(1.0, float(membro.get("atributos", {}).get("vidaMaxima", 1)))
	if vivos_perdedor <= 0:
		return false
	if vivos_vencedor <= 0:
		return true
	var razao := (poder_perdedor + saude_perdedor * 10.0) / maxf(1.0, poder_vencedor + saude_vencedor * 10.0)
	var coragem := rng.randf_range(0.0, 0.20)
	return SISTEMA_COMPORTAMENTO.grupo_deve_continuar_confronto_razao(razao, float(perdedor.get("moralMultiplicador", 1.0)), coragem)

func _resolver_confronto_coletivo(desafiante_in: Dictionary, defensor_in: Dictionary, agora_unix: int, rng: RandomNumberGenerator) -> Dictionary:
	var desafiante: Dictionary = desafiante_in.duplicate(true)
	var defensor: Dictionary = defensor_in.duplicate(true)
	var registros: Array = []
	var rodada := 0
	while rodada < 30:
		var ataques_a: Array = []
		var ataques_d: Array = []
		for membro in desafiante.get("individuos", []):
			if bool(membro.get("vivo", false)):
				var alvos := _listar_vivos(defensor)
				if not alvos.is_empty():
					alvos.sort_custom(func(a, b): return float(a.get("vidaAtual", 1)) < float(b.get("vidaAtual", 1)))
					ataques_a.append({"atacante":str(membro.get("individuoId", "")),"alvo":str(alvos[0].get("individuoId", "")),"dano":_calcular_dano(membro, alvos[0], desafiante, rng, true)})
		for membro in defensor.get("individuos", []):
			if bool(membro.get("vivo", false)):
				var alvos_d := _listar_vivos(desafiante)
				if not alvos_d.is_empty():
					alvos_d.sort_custom(func(a, b): return float(a.get("vidaAtual", 1)) < float(b.get("vidaAtual", 1)))
					ataques_d.append({"atacante":str(membro.get("individuoId", "")),"alvo":str(alvos_d[0].get("individuoId", "")),"dano":_calcular_dano(membro, alvos_d[0], defensor, rng, false)})
		for ataque in ataques_a:
			_aplicar_dano_local(defensor, str(ataque["alvo"]), int(ataque["dano"]), agora_unix)
		for ataque in ataques_d:
			_aplicar_dano_local(desafiante, str(ataque["alvo"]), int(ataque["dano"]), agora_unix)
		registros.append({"rodada":rodada + 1,"ataquesDesafiante":ataques_a.size(),"ataquesDefensor":ataques_d.size(),"sobreviventesDesafiante":_listar_vivos(desafiante).size(),"sobreviventesDefensor":_listar_vivos(defensor).size()})
		rodada += 1
		if _listar_vivos(desafiante).is_empty() or _listar_vivos(defensor).is_empty():
			break
	var vivos_a := _listar_vivos(desafiante).size()
	var vivos_d := _listar_vivos(defensor).size()
	var vencedor_id := str(desafiante.get("grupoId", "")) if vivos_a > vivos_d else str(defensor.get("grupoId", "")) if vivos_d > vivos_a else ""
	if vencedor_id.is_empty():
		var poder_a := _calcular_forca_territorial(desafiante)
		var poder_d := _calcular_forca_territorial(defensor)
		vencedor_id = str(desafiante.get("grupoId", "")) if poder_a > poder_d else str(defensor.get("grupoId", "")) if poder_d > poder_a else ""
	return {"grupoDesafiante":desafiante,"grupoDefensor":defensor,"vencedorGrupoId":vencedor_id,"turnos":registros}

func _calcular_dano(atacante: Dictionary, alvo: Dictionary, grupo_atacante: Dictionary, rng: RandomNumberGenerator, alvo_defende_territorio: bool = false) -> int:
	var ataque := _atributo_com_equipamento(atacante, "ataque")
	var defesa := _atributo_com_equipamento(alvo, "defesa")
	if alvo_defende_territorio:
		defesa *= 1.15
	var moral := float(grupo_atacante.get("moralMultiplicador", 1.0))
	return maxi(1, roundi(maxf(1.0, ataque * moral * rng.randf_range(0.75, 1.08) - defesa * 0.30)))

func _listar_vivos(grupo: Dictionary) -> Array:
	var vivos: Array = []
	for membro in grupo.get("individuos", []):
		if bool(membro.get("vivo", false)):
			vivos.append(membro.duplicate(true))
	return vivos

## A força considera apenas indivíduos vivos e dá vantagem defensiva a quem já ocupa o território.
func _calcular_forca_territorial(grupo: Dictionary) -> float:
	var total := 0.0
	var lider_id := str(grupo.get("liderAtual", {}).get("individuoId", ""))
	for individuo in grupo.get("individuos", []):
		if not bool(individuo.get("vivo", false)):
			continue
		var atributos: Dictionary = individuo.get("atributos", {})
		var forca := float(atributos.get("ataque", 1)) * 1.5
		forca += float(atributos.get("defesa", 0)) + float(atributos.get("vidaMaxima", 1)) * 0.1
		forca += float(atributos.get("agilidade", 0)) * 0.5 + float(atributos.get("poderMagico", 0))
		if str(individuo.get("individuoId", "")) == lider_id:
			forca *= 1.15
		total += forca
	return total

## Verifica se o recuo do grupo derrotado não invade um terceiro território.
func _territorio_tem_conflito(grupos: Dictionary, ignorar_a: String, ignorar_b: String, ecossistema_id: String, centro: Vector2, raio: float) -> bool:
	for outro_id in grupos:
		var id_texto := str(outro_id)
		if id_texto == ignorar_a or id_texto == ignorar_b:
			continue
		var outro: Dictionary = grupos[outro_id]
		if str(outro.get("ecossistemaId", "")) != ecossistema_id:
			continue
		var territorio: Dictionary = outro.get("territorio", {})
		var dados_centro: Dictionary = territorio.get("centro", {})
		var centro_outro := Vector2(float(dados_centro.get("x", -10000.0)), float(dados_centro.get("y", -10000.0)))
		if centro.distance_to(centro_outro) < raio + float(territorio.get("raio", 0.0)):
			return true
	return false


## Personalidade estável por grupo: mesma semente sempre produz o mesmo temperamento.
func _gerar_personalidade_grupo(grupo_id: String) -> Dictionary:
	return {
		"agressividade":_valor_personalidade(grupo_id, "agressividade"),
		"sociabilidade":_valor_personalidade(grupo_id, "sociabilidade"),
		"territorialidade":_valor_personalidade(grupo_id, "territorialidade"),
		"coragem":_valor_personalidade(grupo_id, "coragem")
	}

func _valor_personalidade(grupo_id: String, atributo: String) -> float:
	var semente: int = absi(hash(grupo_id + "|" + atributo))
	return snappedf(0.70 + float(posmod(semente, 601)) / 1000.0, 0.001)

## Registra memória social recíproca. Cooperação explícita pode construir aliança; conflito gera rivalidade.
func registrar_interacao_social(grupo_a_id: String, grupo_b_id: String, tipo: String, agora_unix: int = -1) -> Dictionary:
	if grupo_a_id == grupo_b_id or not ["cooperacao", "conflito"].has(tipo):
		return {"ok":false,"erro":"Interação social inválida."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_a_id) or not grupos.has(grupo_b_id):
		return {"ok":false,"erro":"Um dos grupos não existe."}
	var a: Dictionary = grupos[grupo_a_id].duplicate(true)
	var b: Dictionary = grupos[grupo_b_id].duplicate(true)
	if str(a.get("ecossistemaId", "")) != str(b.get("ecossistemaId", "")):
		return {"ok":false,"erro":"Grupos de ecossistemas diferentes não podem registrar interação direta."}
	_atualizar_relacao_social(a, b, tipo, agora_unix)
	grupos[grupo_a_id] = a
	grupos[grupo_b_id] = b
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a memória social."}
	return {"ok":true,"grupoA":a.duplicate(true),"grupoB":b.duplicate(true)}

func _registrar_relacao_conflito(a: Dictionary, b: Dictionary, agora_unix: int, vencedor_id: String) -> void:
	_atualizar_relacao_social(a, b, "conflito", agora_unix, vencedor_id)

func _atualizar_relacao_social(a: Dictionary, b: Dictionary, tipo: String, agora_unix: int, vencedor_id: String = "") -> void:
	var id_a := str(a.get("grupoId", ""))
	var id_b := str(b.get("grupoId", ""))
	var horario := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	_atualizar_relacao_unilateral(a, id_b, tipo, horario, vencedor_id)
	_atualizar_relacao_unilateral(b, id_a, tipo, horario, vencedor_id)

func _atualizar_relacao_unilateral(grupo: Dictionary, outro_id: String, tipo: String, horario: int, vencedor_id: String) -> void:
	var relacoes: Dictionary = grupo.get("relacoesGrupos", {}).duplicate(true)
	var relacao: Dictionary = relacoes.get(outro_id, {"confianca":0.0,"rivalidade":0.0,"interacoes":0,"historico":[]})
	if tipo == "cooperacao":
		relacao["confianca"] = minf(1.0, float(relacao.get("confianca", 0.0)) + 0.25)
		relacao["rivalidade"] = maxf(0.0, float(relacao.get("rivalidade", 0.0)) - 0.10)
	else:
		relacao["rivalidade"] = minf(1.0, float(relacao.get("rivalidade", 0.0)) + 0.25)
		relacao["confianca"] = maxf(0.0, float(relacao.get("confianca", 0.0)) - 0.10)
	relacao["estado"] = "aliado" if float(relacao.get("confianca", 0.0)) >= 0.50 else "rival" if float(relacao.get("rivalidade", 0.0)) >= 0.35 else "neutro"
	relacao["interacoes"] = int(relacao.get("interacoes", 0)) + 1
	relacao["ultimaInteracaoUnix"] = horario
	relacao["ultimoTipoInteracao"] = tipo
	if not vencedor_id.is_empty():
		relacao["ultimoVencedorGrupoId"] = vencedor_id
	var historico: Array = relacao.get("historico", [])
	historico.append({"tipo":tipo,"horarioUnix":horario,"vencedorGrupoId":vencedor_id})
	relacao["historico"] = historico.slice(maxi(0, historico.size() - 20))
	relacoes[outro_id] = relacao
	grupo["relacoesGrupos"] = relacoes
	var memoria: Array = grupo.get("historicoSocial", [])
	memoria.append({"grupoRelacionadoId":outro_id,"tipo":tipo,"horarioUnix":horario,"vencedorGrupoId":vencedor_id})
	grupo["historicoSocial"] = memoria.slice(maxi(0, memoria.size() - 50))

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

## Decompõe carcaças e distribui o alimento entre necrófagos com dieta explicitamente declarada.
func processar_carcacas_ecologicas(agora_unix: int) -> Dictionary:
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if grupos.is_empty():
		return {"ok":true,"disponibilidadePorEspecie":{},"grupos":[]}
	var especies: Dictionary = {}
	for criatura in repositorio_criaturas.listar_todas_as_criaturas_catalogadas():
		especies[str(criatura.get("id", ""))] = criatura
	var consumidores_por_ecossistema := {}
	for grupo in grupos.values():
		var especie_id := str(grupo.get("especieId", ""))
		var especie: Dictionary = especies.get(especie_id, {})
		var ecologia: Dictionary = especie.get("ecologia", {})
		var dieta: Array = ecologia.get("especiesNecrófagas", [])
		var vivos := 0
		for individuo in grupo.get("individuos", []):
			if bool(individuo.get("vivo", false)):
				vivos += 1
		if vivos <= 0 or dieta.is_empty():
			continue
		var ecossistema := str(grupo.get("ecossistemaId", ""))
		if not consumidores_por_ecossistema.has(ecossistema):
			consumidores_por_ecossistema[ecossistema] = []
		consumidores_por_ecossistema[ecossistema].append({
			"especieId":especie_id,
			"quantidade":vivos,
			"dieta":dieta,
			"consumoDia":maxf(0.0, float(ecologia.get("consumoCarcacaPorIndividuoDia", 0.0)))
		})
	var quantidade_carcacas_por_consumidor := {}
	for grupo in grupos.values():
		var ecossistema := str(grupo.get("ecossistemaId", ""))
		for individuo in grupo.get("individuos", []):
			var carcaca: Dictionary = individuo.get("carcaca", {})
			if carcaca.is_empty() or float(carcaca.get("quantidade", 0.0)) <= 0.0:
				continue
			var especie_presa := str(carcaca.get("especieId", individuo.get("especieId", "")))
			for consumidor in consumidores_por_ecossistema.get(ecossistema, []):
				if consumidor["dieta"].has(especie_presa):
					var chave := ecossistema + "|" + str(consumidor["especieId"])
					quantidade_carcacas_por_consumidor[chave] = int(quantidade_carcacas_por_consumidor.get(chave, 0)) + 1
	var disponibilidade := {}
	var encontrou_carcaca := {}
	for consumidores in consumidores_por_ecossistema.values():
		for consumidor in consumidores:
			disponibilidade[str(consumidor["especieId"])] = 1.0
			encontrou_carcaca[str(consumidor["especieId"])] = false
	var alterou := false
	for grupo_id in grupos.keys():
		var grupo: Dictionary = grupos[grupo_id].duplicate(true)
		var individuos: Array = grupo.get("individuos", [])
		var ecossistema := str(grupo.get("ecossistemaId", ""))
		for indice in range(individuos.size()):
			var individuo: Dictionary = individuos[indice].duplicate(true)
			var carcaca: Dictionary = individuo.get("carcaca", {})
			if carcaca.is_empty() or float(carcaca.get("quantidade", 0.0)) <= 0.0:
				continue
			var ultima := int(carcaca.get("ultimaAtualizacaoUnix", -1))
			if ultima < 0 or agora_unix < ultima:
				return {"ok":false,"erro":"Relógio de decomposição das carcaças retrocedeu."}
			var dias := minf(float(agora_unix - ultima) / 86400.0, 3650.0)
			var quantidade := maxf(0.0, float(carcaca.get("quantidade", 0.0)) - float(carcaca.get("decomposicaoPorDia", 0.0)) * dias)
			var especie_presa := str(carcaca.get("especieId", individuo.get("especieId", "")))
			var consumidores: Array = []
			var demanda_total := 0.0
			for consumidor in consumidores_por_ecossistema.get(ecossistema, []):
				if consumidor["dieta"].has(especie_presa) and float(consumidor["consumoDia"]) > 0.0:
					var chave_consumidor := ecossistema + "|" + str(consumidor["especieId"])
					var total_carcacas := maxi(1, int(quantidade_carcacas_por_consumidor.get(chave_consumidor, 1)))
					var demanda := float(consumidor["quantidade"]) * float(consumidor["consumoDia"]) * dias / float(total_carcacas)
					demanda_total += demanda
					consumidores.append({"especieId":consumidor["especieId"],"demanda":demanda})
			var indice_alimento := 1.0 if demanda_total <= 0.0 else clampf(quantidade / demanda_total, 0.0, 1.0)
			for consumidor in consumidores:
				var id_consumidor := str(consumidor["especieId"])
				if bool(encontrou_carcaca.get(id_consumidor, false)):
					disponibilidade[id_consumidor] = minf(float(disponibilidade.get(id_consumidor, 1.0)), indice_alimento)
				else:
					disponibilidade[id_consumidor] = indice_alimento
					encontrou_carcaca[id_consumidor] = true
			var consumido := minf(quantidade, demanda_total)
			carcaca["quantidade"] = maxf(0.0, quantidade - consumido)
			carcaca["ultimaAtualizacaoUnix"] = agora_unix
			individuo["carcaca"] = carcaca
			individuos[indice] = individuo
			alterou = true
		grupo["individuos"] = individuos
		grupos[grupo_id] = grupo
	for id_consumidor in disponibilidade.keys():
		if not bool(encontrou_carcaca.get(id_consumidor, false)):
			disponibilidade[id_consumidor] = 0.0
	if alterou:
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível salvar a decomposição e o consumo das carcaças."}
	var lista: Array = []
	for grupo in grupos.values():
		lista.append(grupo.duplicate(true))
	return {"ok":true,"disponibilidadePorEspecie":disponibilidade,"grupos":lista}

func _criar_carcarca(individuo: Dictionary, criatura: Dictionary, agora_unix: int) -> Dictionary:
	if criatura.is_empty():
		return {}
	var ecologia: Dictionary = criatura.get("ecologia", {})
	var config: Dictionary = ecologia.get("carcaca", {})
	var atributos: Dictionary = individuo.get("atributos", {})
	var vida := maxf(1.0, float(atributos.get("vidaMaxima", criatura.get("vidaMaxima", 1))))
	var unidades := clampf(float(config.get("unidades", vida * 0.5)), 1.0, 1000000.0)
	var decomposicao := clampf(float(config.get("decomposicaoPorDia", unidades * 0.1)), 0.0, unidades)
	var rendimento := SISTEMA_LIDER_NATO.calcular_rendimento_carcaca(unidades, decomposicao, bool(individuo.get("liderNato", false)))
	unidades = float(rendimento["quantidade"])
	decomposicao = float(rendimento["decomposicaoPorDia"])
	var posicao: Dictionary = individuo.get("posicaoMundo", {})
	return {
		"especieId":str(criatura.get("id", "")),
		"quantidade":unidades,
		"quantidadeInicial":unidades,
		"qualidade":str(rendimento["qualidade"]),
		"origemLiderNato":bool(rendimento["origemLiderNato"]),
		"decomposicaoPorDia":decomposicao,
		"criadaUnix":agora_unix,
		"ultimaAtualizacaoUnix":agora_unix,
		"posicaoMundo":posicao.duplicate(true)
	}

func _criar_individuo(grupo: Dictionary, criatura: Dictionary, rng: RandomNumberGenerator, filhote: bool = true) -> Dictionary:
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
	var lider_nato := filhote and SISTEMA_LIDER_NATO.sortear(rng)
	if lider_nato:
		atributos = SISTEMA_LIDER_NATO.aprimorar(atributos)
	var agora_heranca := int(grupo.get("atualizadoUnix", grupo.get("criadoUnix", 0)))
	var aprendizado_herdado := SISTEMA_COMPORTAMENTO.selecionar_aprendizado_herdado(
		grupo.get("memoriaCacada", []), agora_heranca
	) if filhote else []
	return {
		"individuoId":str(grupo.get("grupoId", "grupo")) + "_ind_" + str(numero),
		"especieId":str(criatura.get("id", "")),
		"atributos":atributos,
		"liderNato":lider_nato,
		"vidaAtual":int(atributos.get("vidaMaxima", 1)),
		"equipamentoIds":[],
		"vivo":true,
		"posicaoMundo":{
			"x":clampf(float(centro.get("x", 0.0)) + cos(angulo) * distancia, 0.0, 2400.0),
			"y":clampf(float(centro.get("y", 0.0)) + sin(angulo) * distancia, 0.0, 1600.0)
		},
		"nascimentoUnix":int(grupo.get("atualizadoUnix", grupo.get("criadoUnix", 0))) if filhote else int(grupo.get("criadoUnix", 0)) - int(float(grupo.get("idadeMaturidadeDias", 7.0)) * 86400.0),
		"faseVida":"filhote" if filhote else "adulto",
		"aprendizadoHerdado":aprendizado_herdado
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
		return {"versao":1,"versaoCoordenadas":SISTEMA_MIGRACAO.VERSAO_COORDENADAS,"grupos":{}}
	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.READ)
	if arquivo == null or arquivo.get_length() > LIMITE_ARQUIVO:
		return {}
	var texto := arquivo.get_as_text()
	arquivo.close()
	var dados = JSON.parse_string(texto)
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1 or not (dados.get("grupos", {}) is Dictionary):
		return {}
	return _migrar_coordenadas_banco(dados)

func _migrar_coordenadas_banco(banco: Dictionary) -> Dictionary:
	if int(banco.get("versaoCoordenadas", 0)) >= SISTEMA_MIGRACAO.VERSAO_COORDENADAS:
		return banco
	var grupos: Dictionary = banco.get("grupos", {})
	for grupo_id in grupos.keys():
		if not (grupos[grupo_id] is Dictionary):
			return {}
		var migrado := SISTEMA_MIGRACAO.migrar_grupo_legado(grupos[grupo_id])
		if migrado.is_empty():
			return {}
		grupos[grupo_id] = migrado
	banco["grupos"] = grupos
	banco["versaoCoordenadas"] = SISTEMA_MIGRACAO.VERSAO_COORDENADAS
	if not _gravar_banco(banco):
		push_error("Migração de coordenadas dos grupos não foi persistida; grupos bloqueados.")
		return {}
	return banco

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
