extends RefCounted
class_name SistemaCombateCooperativo

## Motor determinístico por semente, executado exclusivamente no servidor.
const ACAO_ATAQUE := "ataque"
const ACAO_DEFENDER := "defender"
const ACAO_ESQUIVAR := "esquivar"
const EM_ANDAMENTO := "em_andamento"
const VITORIA := "vitoria"
const DERROTA := "derrota"

static func criar_estado(criatura: Dictionary, participantes: Array) -> Dictionary:
	if criatura.is_empty() or participantes.size() < 2 or participantes.size() > 4:
		return {}
	var vida_criatura := int(criatura.get("vidaMaxima", criatura.get("vida", 0)))
	if vida_criatura < 1 or vida_criatura > 100000000:
		return {}
	var membros: Array = []
	var uids: Dictionary = {}
	for membro in participantes:
		if not (membro is Dictionary):
			return {}
		var uid := str(membro.get("uid", "")).strip_edges()
		var nome := str(membro.get("nome", "Aventureiro")).strip_edges()
		if uid.is_empty() or uid.length() > 256 or uids.has(uid) or nome.is_empty() or nome.length() > 40:
			return {}
		var vida_maxima := clampi(int(membro.get("vidaMaxima", 100)), 1, 1000000)
		var vida := clampi(int(membro.get("vida", vida_maxima)), 0, vida_maxima)
		uids[uid] = true
		membros.append({
			"uid": uid,
			"nome": nome,
			"vida": vida,
			"vidaMaxima": vida_maxima,
			"estadoCombate": "vivo" if vida > 0 else "derrotado",
			"conectado": true,
			"elegivelRecompensas": false,
			"danoCausado": 0,
			"ataque": clampi(int(membro.get("ataque", 5)), 1, 1000000),
			"defesa": clampi(int(membro.get("defesa", 0)), 0, 1000000),
			"agilidade": clampi(int(membro.get("agilidade", 5)), 0, 1000000),
			"defendendo": false,
			"esquivando": false
		})
	if membros.size() < 2:
		return {}
	var primeiro := _proximo_vivo(membros, -1)
	if primeiro < 0:
		return {}
	return {
		"status": EM_ANDAMENTO,
		"criatura": {
			"id": str(criatura.get("id", "")),
			"nome": str(criatura.get("nome", "Criatura")),
			"rank": str(criatura.get("rank", "E")),
			"nivel": int(criatura.get("nivel", 1)),
			"vida": vida_criatura,
			"vidaMaxima": vida_criatura,
			"ataque": clampi(int(criatura.get("ataque", 5)), 1, 1000000),
			"defesa": clampi(int(criatura.get("defesa", 0)), 0, 1000000),
			"imagemId": str(criatura.get("imagemId", "")),
			"iconePath": str(criatura.get("iconePath", "")),
			"detalhePath": str(criatura.get("detalhePath", ""))
		},
		"participantes": membros,
		"indiceTurno": primeiro,
		"rodada": 1,
		"historico": ["A equipe encontrou %s." % str(criatura.get("nome", "uma criatura"))]
	}

## Marca uma desconexão sem remover o integrante nem sua contribuição.
static func marcar_desconectado(estado_original: Dictionary, uid: String) -> Dictionary:
	var estado: Dictionary = estado_original.duplicate(true)
	if str(estado.get("status", "")) != EM_ANDAMENTO:
		return estado
	var membros: Array = estado.get("participantes", [])
	for i in range(membros.size()):
		if str(membros[i].get("uid", "")) == uid:
			membros[i]["conectado"] = false
			if int(estado.get("indiceTurno", -1)) == i:
				var proximo := _proximo_vivo(membros, i)
				estado["indiceTurno"] = proximo
				estado["aguardandoReconexao"] = proximo < 0
			var historico: Array = estado.get("historico", []).duplicate()
			historico.append("%s desconectou; sua participação e seu dano foram preservados." % str(membros[i].get("nome", "Aventureiro")))
			while historico.size() > 60:
				historico.pop_front()
			estado["historico"] = historico
			break
	estado["participantes"] = membros
	return estado

## Reativa o integrante quando a mesma conta retorna à sala.
static func marcar_reconectado(estado_original: Dictionary, uid: String) -> Dictionary:
	var estado: Dictionary = estado_original.duplicate(true)
	if str(estado.get("status", "")) != EM_ANDAMENTO:
		return estado
	var membros: Array = estado.get("participantes", [])
	for i in range(membros.size()):
		if str(membros[i].get("uid", "")) == uid and int(membros[i].get("vida", 0)) > 0:
			membros[i]["conectado"] = true
			if int(estado.get("indiceTurno", -1)) < 0:
				estado["indiceTurno"] = i
				estado["aguardandoReconexao"] = false
			var historico: Array = estado.get("historico", []).duplicate()
			historico.append("%s retornou à batalha." % str(membros[i].get("nome", "Aventureiro")))
			while historico.size() > 60:
				historico.pop_front()
			estado["historico"] = historico
			break
	estado["participantes"] = membros
	return estado

static func executar_acao(estado_original: Dictionary, uid: String, acao: String, semente: int) -> Dictionary:
	if str(estado_original.get("status", "")) != EM_ANDAMENTO:
		return {"ok": false, "erro": "Este combate já foi encerrado."}
	if not [ACAO_ATAQUE, ACAO_DEFENDER, ACAO_ESQUIVAR].has(acao):
		return {"ok": false, "erro": "Ação cooperativa inválida."}
	var estado: Dictionary = estado_original.duplicate(true)
	var membros: Array = estado.get("participantes", [])
	var indice := int(estado.get("indiceTurno", -1))
	if indice < 0 or indice >= membros.size() or str(membros[indice].get("uid", "")) != uid:
		return {"ok": false, "erro": "Ainda não é o turno deste participante."}
	var criatura: Dictionary = estado.get("criatura", {})
	var membro: Dictionary = membros[indice]
	if int(membro.get("vida", 0)) <= 0:
		return {"ok": false, "erro": "Este participante está fora de combate."}
	var historico: Array = estado.get("historico", []).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = semente if semente != 0 else 1
	if acao == ACAO_ATAQUE:
		var dano := maxi(1, int(membro.get("ataque", 1)) + rng.randi_range(0, 5) - int(criatura.get("defesa", 0)))
		criatura["vida"] = maxi(0, int(criatura.get("vida", 0)) - dano)
		membro["danoCausado"] = int(membro.get("danoCausado", 0)) + dano
		historico.append("%s causou %d de dano em %s." % [membro.get("nome", "Aventureiro"), dano, criatura.get("nome", "a criatura")])
	elif acao == ACAO_DEFENDER:
		membro["defendendo"] = true
		historico.append("%s assumiu uma postura defensiva." % membro.get("nome", "Aventureiro"))
	else:
		membro["esquivando"] = true
		historico.append("%s preparou uma esquiva." % membro.get("nome", "Aventureiro"))
	if int(criatura.get("vida", 0)) <= 0:
		estado["status"] = VITORIA
		estado["retornoGrupo"] = "aventura_compartilhada"
		var maior_dano := -1
		var uid_maior_dano := ""
		for participante_dano in membros:
			var dano_total := int(participante_dano.get("danoCausado", 0))
			if dano_total > maior_dano:
				maior_dano = dano_total
				uid_maior_dano = str(participante_dano.get("uid", ""))
		estado["uidMaiorDano"] = uid_maior_dano
		estado["maiorDano"] = maxi(0, maior_dano)
		for participante_final in membros:
			participante_final["elegivelRecompensas"] = true
			if int(participante_final.get("vida", 0)) <= 0:
				participante_final["vida"] = 1
				participante_final["estadoCombate"] = "retornando_com_1_hp"
			else:
				participante_final["estadoCombate"] = "vivo"
		historico.append("%s foi derrotada! Todos os participantes recebem direito às recompensas." % criatura.get("nome", "A criatura"))
	else:
		var dano_inimigo := maxi(1, int(criatura.get("ataque", 1)) + rng.randi_range(0, 4) - int(membro.get("defesa", 0)))
		if bool(membro.get("defendendo", false)):
			dano_inimigo = maxi(1, int(ceil(float(dano_inimigo) * 0.5)))
		elif bool(membro.get("esquivando", false)):
			var chance := clampf(float(membro.get("agilidade", 0)) / 100.0, 0.05, 0.65)
			if rng.randf() < chance:
				dano_inimigo = 0
		membro["vida"] = maxi(0, int(membro.get("vida", 0)) - dano_inimigo)
		if int(membro.get("vida", 0)) <= 0:
			membro["estadoCombate"] = "derrotado"
		membro["defendendo"] = false
		membro["esquivando"] = false
		if dano_inimigo > 0:
			historico.append("%s recebeu %d de dano." % [membro.get("nome", "Aventureiro"), dano_inimigo])
		else:
			historico.append("%s esquivou do ataque." % membro.get("nome", "Aventureiro"))
		var proximo := _proximo_vivo(membros, indice)
		if proximo < 0:
			var existe_vivo := false
			for participante_restante in membros:
				if int(participante_restante.get("vida", 0)) > 0:
					existe_vivo = true
					break
			if existe_vivo:
				estado["indiceTurno"] = -1
				estado["aguardandoReconexao"] = true
				historico.append("Todos os aventureiros vivos estão desconectados. O combate aguarda o retorno de alguém.")
			else:
				estado["status"] = DERROTA
				estado["retornoGrupo"] = "ponto_renascimento"
				for participante_final in membros:
					participante_final["estadoCombate"] = "derrotado"
					participante_final["elegivelRecompensas"] = false
				historico.append("Toda a equipe foi derrotada. O grupo retornará ao último ponto de renascimento.")
		else:
			if proximo <= indice:
				estado["rodada"] = int(estado.get("rodada", 1)) + 1
			estado["indiceTurno"] = proximo
			estado["aguardandoReconexao"] = false
	estado["criatura"] = criatura
	estado["participantes"] = membros
	while historico.size() > 60:
		historico.pop_front()
	estado["historico"] = historico
	return {"ok": true, "estado": estado}


## Divide a experiência entre todos os participantes originais e marca o maior dano
## como único destinatário dos drops. O desempate mantém a ordem original da equipe.
static func calcular_distribuicao_recompensas(estado: Dictionary, experiencia_total: int) -> Array:
	if str(estado.get("status", "")) != VITORIA or experiencia_total < 0 or experiencia_total > 100000000:
		return []
	var membros: Array = estado.get("participantes", [])
	if membros.size() < 2 or membros.size() > 4:
		return []
	var maior_dano := -1
	var uid_destaque := ""
	var uids: Dictionary = {}
	for membro in membros:
		if not (membro is Dictionary):
			return []
		var uid := str(membro.get("uid", "")).strip_edges()
		var dano := int(membro.get("danoCausado", 0))
		if uid.is_empty() or uids.has(uid) or dano < 0:
			return []
		uids[uid] = true
		if dano > maior_dano:
			maior_dano = dano
			uid_destaque = uid
	if uid_destaque.is_empty():
		return []
	var base := int(experiencia_total / membros.size())
	var resto := experiencia_total % membros.size()
	var resultado: Array = []
	for indice in range(membros.size()):
		var uid := str(membros[indice].get("uid", ""))
		resultado.append({
			"uid": uid,
			"experiencia": base + (1 if indice < resto else 0),
			"receberDrops": uid == uid_destaque
		})
	return resultado

static func _proximo_vivo(membros: Array, indice_atual: int) -> int:
	if membros.is_empty():
		return -1
	for passo in range(1, membros.size() + 1):
		var candidato := (indice_atual + passo) % membros.size()
		if int(membros[candidato].get("vida", 0)) > 0 and bool(membros[candidato].get("conectado", true)):
			return candidato
	return -1
