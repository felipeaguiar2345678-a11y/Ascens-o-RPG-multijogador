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
		"rotasMigracao":ecologia.get("rotasMigracao", []).duplicate(true),
		"ciclosEscassezAlimentar":0,
		"ultimaMigracaoUnix":0,
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
		individuo_morto["carcaca"] = _criar_carcarca(individuo_morto, criatura, agora_unix)
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
			var forca_invasor := _calcular_forca_territorial(grupo)
			var forca_defensor := _calcular_forca_territorial(defensor) * 1.15
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
			if forca_invasor <= forca_defensor or not pode_recuar or _territorio_tem_conflito(grupos, grupo_id, grupo_ocupante_id, ecossistema_novo, centro_recuo, raio_defensor):
				var registro_defesa := {"grupoDesafiante":grupo_id,"grupoDefensor":grupo_ocupante_id,"resultado":"defensor_manteve_territorio","forcaDesafiante":forca_invasor,"forcaDefensora":forca_defensor,"horarioUnix":agora_unix}
				var historico_defensor: Array = defensor.get("disputasTerritoriais", [])
				historico_defensor.append(registro_defesa)
				defensor["disputasTerritoriais"] = historico_defensor.slice(maxi(0, historico_defensor.size() - 20))
				grupo["ultimaDisputaTerritorial"] = registro_defesa
				grupo["ciclosEscassezAlimentar"] = 0
				grupos[grupo_ocupante_id] = defensor
				grupos[grupo_id] = grupo
				banco["grupos"] = grupos
				if not _gravar_banco(banco):
					return {"ok":false,"erro":"Não foi possível salvar a disputa territorial."}
				return {"ok":true,"migrou":false,"disputaTerritorial":true,"vencedor":grupo_ocupante_id,"resultado":"defensor_manteve_territorio","grupo":grupo.duplicate(true)}
			var deslocamento_recuo := centro_recuo - centro_defensor
			var individuos_defensor: Array = defensor.get("individuos", [])
			for indice_defensor in range(individuos_defensor.size()):
				var membro: Dictionary = individuos_defensor[indice_defensor].duplicate(true)
				var pos_membro: Dictionary = membro.get("posicaoMundo", {})
				var pos_nova := Vector2(float(pos_membro.get("x", centro_defensor.x)), float(pos_membro.get("y", centro_defensor.y))) + deslocamento_recuo
				membro["posicaoMundo"] = {"x":pos_nova.x,"y":pos_nova.y}
				membro["estadoMundo"] = "recuando_apos_disputa"
				individuos_defensor[indice_defensor] = membro
			defensor["individuos"] = individuos_defensor
			var territorio_defensor: Dictionary = defensor.get("territorio", {}).duplicate(true)
			territorio_defensor["centro"] = {"x":centro_recuo.x,"y":centro_recuo.y}
			defensor["territorio"] = territorio_defensor
			var registro_vitoria := {"grupoDesafiante":grupo_id,"grupoDefensor":grupo_ocupante_id,"resultado":"invasor_conquistou_territorio","forcaDesafiante":forca_invasor,"forcaDefensora":forca_defensor,"horarioUnix":agora_unix}
			var historico_defensor: Array = defensor.get("disputasTerritoriais", [])
			historico_defensor.append(registro_vitoria)
			defensor["disputasTerritoriais"] = historico_defensor.slice(maxi(0, historico_defensor.size() - 20))
			defensor["ultimaDisputaTerritorial"] = registro_vitoria
			grupo["ultimaDisputaTerritorial"] = registro_vitoria
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
	var posicao: Dictionary = individuo.get("posicaoMundo", {})
	return {
		"especieId":str(criatura.get("id", "")),
		"quantidade":unidades,
		"quantidadeInicial":unidades,
		"decomposicaoPorDia":decomposicao,
		"criadaUnix":agora_unix,
		"ultimaAtualizacaoUnix":agora_unix,
		"posicaoMundo":posicao.duplicate(true)
	}

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
		"vidaAtual":int(atributos.get("vidaMaxima", 1)),
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
