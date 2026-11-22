extends RefCounted
class_name SistemaCombate

## Regras puras do combate. A instância autoritativa deve existir no servidor.
const Equipamentos = preload("res://scripts/sistema_equipamentos.gd")
const ACAO_ATAQUE := "ataque"
const ACAO_MAGIA := "magia"
const ACAO_DEFENDER := "defender"
const ACAO_ESQUIVAR := "esquivar"
const STATUS_EM_ANDAMENTO := "em_andamento"
const STATUS_VITORIA := "vitoria"
const STATUS_DERROTA := "derrota"

static func criar_estado(perfil: Dictionary, criatura: Dictionary, contexto_ciclo: Dictionary = {}) -> Dictionary:
	if not bool(perfil.get("personagemCriado", false)) or criatura.is_empty():
		return {}
	var periodo := str(contexto_ciclo.get("periodo", "dia"))
	var criatura_com_ajustes: Dictionary = preload("res://scripts/sistema_ciclo_noturno.gd").preparar_criatura_para_periodo(criatura, periodo)
	if criatura_com_ajustes.is_empty():
		return {}
	criatura = criatura_com_ajustes
	var base := {
		"forca": int(perfil.get("forca", 5)), "inteligencia": int(perfil.get("inteligencia", 5)),
		"agilidade": int(perfil.get("agilidade", 5)), "vitalidade": int(perfil.get("vitalidade", 5)),
		"espirito": int(perfil.get("espirito", 5)), "vidaMaxima": int(perfil.get("vidaMaxima", 100)),
		"manaMaxima": int(perfil.get("manaMaxima", 50))
	}
	var efetivos := Equipamentos.calcular_atributos_efetivos(base, perfil.get("equipamentos", {}))
	var vida_jogador := clampi(int(perfil.get("vida", efetivos["vidaMaxima"])), 0, int(efetivos["vidaMaxima"]))
	var mana_jogador := clampi(int(perfil.get("mana", efetivos["manaMaxima"])), 0, int(efetivos["manaMaxima"]))
	var arma := Equipamentos.obter(str(perfil.get("equipamentos", {}).get("mao_principal", "")))
	var criatura_vida := maxi(1, int(criatura.get("vidaMaxima", criatura.get("vida", 50))))
	return {
		"status": STATUS_EM_ANDAMENTO, "turno": "jogador",
		"jogador": {
			"nome": str(perfil.get("nome", "Aventureiro")), "vida": vida_jogador,
			"vidaMaxima": int(efetivos["vidaMaxima"]), "mana": mana_jogador,
			"manaMaxima": int(efetivos["manaMaxima"]), "forca": int(efetivos["forca"]),
			"inteligencia": int(efetivos["inteligencia"]), "agilidade": int(efetivos["agilidade"]),
			"espirito": int(efetivos["espirito"]),
			"defesa": int(efetivos["defesaEquipamento"]) + int(efetivos["vitalidade"]) / 3,
			"armaDano": int(arma.get("dano", 5)), "armaAtributo": str(arma.get("atributo", "forca")),
			"armaCategoria": str(arma.get("categoria", "fisica")),
			"defendendo": false, "esquivando": false
		},
		"inimigo": {
			"id": str(criatura.get("id", "criatura_desconhecida")),
			"nome": str(criatura.get("nome", "Criatura desconhecida")), "vida": criatura_vida,
			"vidaMaxima": criatura_vida, "mana": maxi(0, int(criatura.get("manaMaxima", 0))),
			"ataque": maxi(1, int(criatura.get("ataque", 5))),
			"poderMagico": maxi(0, int(criatura.get("poderMagico", 0))),
			"defesa": maxi(0, int(criatura.get("defesa", 0))),
			"agilidade": maxi(0, int(criatura.get("agilidade", 0))),
			"defendendo": false, "esquivando": false
		},
		"periodo": periodo, "multiplicadorExperiencia": (1.5 if preload("res://scripts/sistema_ciclo_noturno.gd").esta_no_periodo_noturno(periodo) else 1.0),
		"experienciaBase": maxi(0, int(criatura.get("experienciaBase", 0))),
		"historico": ["O combate começou contra %s." % str(criatura.get("nome", "uma criatura"))]
	}

## Cria uma batalha contra até três indivíduos reais de um mesmo grupo selvagem.
## A primeira criatura mantém o campo legado "inimigo" para compatibilidade visual.
static func criar_estado_grupo(perfil: Dictionary, criaturas: Array, contexto_ciclo: Dictionary = {}) -> Dictionary:
	if criaturas.is_empty() or criaturas.size() > 3:
		return {}
	var inimigos_estado: Array = []
	var estado_base: Dictionary = {}
	for criatura in criaturas:
		if not (criatura is Dictionary) or criatura.is_empty():
			continue
		var parcial := criar_estado(perfil, criatura, contexto_ciclo)
		if parcial.is_empty():
			return {}
		if estado_base.is_empty():
			estado_base = parcial
		var inimigo_estado: Dictionary = parcial["inimigo"].duplicate(true)
		inimigo_estado["id"] = str(criatura.get("individuoId", inimigo_estado.get("id", "")))
		inimigo_estado["especieId"] = str(criatura.get("id", ""))
		inimigos_estado.append(inimigo_estado)
	if inimigos_estado.is_empty() or estado_base.is_empty():
		return {}
	estado_base["inimigos"] = inimigos_estado
	estado_base["alvoSelecionadoId"] = str(inimigos_estado[0].get("id", ""))
	estado_base["inimigo"] = inimigos_estado[0].duplicate(true)
	estado_base["experienciaBase"] = 0
	for criatura in criaturas:
		if criatura is Dictionary:
			estado_base["experienciaBase"] = int(estado_base["experienciaBase"]) + maxi(0, int(criatura.get("experienciaBase", 0)))
	estado_base["historico"] = ["O combate começou contra %d criaturas selvagens." % inimigos_estado.size()]
	return estado_base

## Executa uma rodada: ação escolhida pelo jogador e resposta da criatura.
## A semente deve ser gerada no servidor e nunca recebida do cliente.
static func executar_rodada(estado_original: Dictionary, acao: String, semente_servidor: int, alvo_selecionado_id: String = "") -> Dictionary:
	if estado_original.has("inimigos") and estado_original.get("inimigos", []) is Array and estado_original.get("inimigos", []).size() > 1:
		return _executar_rodada_grupo(estado_original, acao, semente_servidor, alvo_selecionado_id)
	if estado_original.is_empty() or str(estado_original.get("status", "")) != STATUS_EM_ANDAMENTO:
		return {"ok":false,"erro":"Não existe combate ativo."}
	if str(estado_original.get("turno", "")) != "jogador":
		return {"ok":false,"erro":"Ainda não é o turno do jogador."}
	if not [ACAO_ATAQUE, ACAO_MAGIA, ACAO_DEFENDER, ACAO_ESQUIVAR].has(acao):
		return {"ok":false,"erro":"Ação de combate inválida."}
	var estado := estado_original.duplicate(true)
	var jogador: Dictionary = estado["jogador"]
	var inimigo: Dictionary = estado["inimigo"]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(semente_servidor) + 1
	var historico: Array = estado.get("historico", [])
	if acao == ACAO_DEFENDER:
		jogador["defendendo"] = true
		historico.append("%s assumiu uma postura defensiva." % jogador["nome"])
	elif acao == ACAO_ESQUIVAR:
		jogador["esquivando"] = true
		historico.append("%s se preparou para esquivar." % jogador["nome"])
	else:
		var magico := acao == ACAO_MAGIA
		if magico and int(jogador["mana"]) < 8:
			return {"ok":false,"erro":"Mana insuficiente para conjurar."}
		if magico:
			jogador["mana"] = int(jogador["mana"]) - 8
		var atributo := "inteligencia" if magico else str(jogador["armaAtributo"])
		var poder := int(jogador.get(atributo, jogador["forca"]))
		var dano_base := int(jogador["armaDano"]) + int(round(float(poder) * 0.8))
		if magico:
			dano_base += int(round(float(jogador["espirito"]) * 0.35))
		var resultado_dano := _calcular_dano(dano_base, int(inimigo["defesa"]), int(inimigo["agilidade"]), int(jogador["agilidade"]), rng)
		if bool(resultado_dano["esquivou"]):
			historico.append("%s evitou o ataque!" % inimigo["nome"])
		else:
			inimigo["vida"] = maxi(0, int(inimigo["vida"]) - int(resultado_dano["dano"]))
			var texto_critico := " CRÍTICO!" if bool(resultado_dano["critico"]) else ""
			historico.append("%s causou %d de dano em %s.%s" % [jogador["nome"], resultado_dano["dano"], inimigo["nome"], texto_critico])
		if int(inimigo["vida"]) <= 0:
			estado["status"] = STATUS_VITORIA
			historico.append("%s foi derrotado." % inimigo["nome"])
			estado["jogador"] = jogador
			estado["inimigo"] = inimigo
			estado["historico"] = historico
			return {"ok":true,"estado":estado}
	var inimigo_magico := int(inimigo["poderMagico"]) > int(inimigo["ataque"]) and int(inimigo["mana"]) >= 5
	var ataque_inimigo := int(inimigo["poderMagico"]) if inimigo_magico else int(inimigo["ataque"])
	var defesa_alvo := int(round(float(jogador["defesa"]) * (0.5 if bool(jogador["defendendo"]) else 1.0)))
	var esquiva_bonus := 0.35 if bool(jogador["esquivando"]) else 0.0
	var resultado_inimigo := _calcular_dano(ataque_inimigo, defesa_alvo, int(jogador["agilidade"]), int(inimigo["agilidade"]), rng, esquiva_bonus)
	if inimigo_magico:
		inimigo["mana"] = int(inimigo["mana"]) - 5
	if bool(resultado_inimigo["esquivou"]):
		historico.append("%s esquivou do ataque de %s." % [jogador["nome"], inimigo["nome"]])
	else:
		jogador["vida"] = maxi(0, int(jogador["vida"]) - int(resultado_inimigo["dano"]))
		historico.append("%s recebeu %d de dano." % [jogador["nome"], resultado_inimigo["dano"]])
	jogador["defendendo"] = false
	jogador["esquivando"] = false
	if int(jogador["vida"]) <= 0:
		estado["status"] = STATUS_DERROTA
		historico.append("%s foi derrotado." % jogador["nome"])
	estado["turno"] = "jogador"
	estado["jogador"] = jogador
	estado["inimigo"] = inimigo
	estado["historico"] = historico.slice(maxi(0, historico.size() - 30))
	return {"ok":true,"estado":estado}

## Resolve uma rodada contra até três inimigos; cada sobrevivente pode responder.
static func _executar_rodada_grupo(estado_original: Dictionary, acao: String, semente_servidor: int, alvo_solicitado_id: String = "") -> Dictionary:
	if str(estado_original.get("status", "")) != STATUS_EM_ANDAMENTO or str(estado_original.get("turno", "")) != "jogador":
		return {"ok":false,"erro":"Não existe turno de combate válido."}
	if not [ACAO_ATAQUE, ACAO_MAGIA, ACAO_DEFENDER, ACAO_ESQUIVAR].has(acao):
		return {"ok":false,"erro":"Ação de combate inválida."}
	var estado := estado_original.duplicate(true)
	var inimigos: Array = estado.get("inimigos", []).duplicate(true)
	var jogador: Dictionary = estado.get("jogador", {}).duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(semente_servidor) + 1
	var historico: Array = estado.get("historico", []).duplicate()
	var alvo_id := alvo_solicitado_id if not alvo_solicitado_id.is_empty() else str(estado.get("alvoSelecionadoId", ""))
	var indice_alvo := -1
	for i in range(inimigos.size()):
		if int(inimigos[i].get("vida", 0)) > 0 and (alvo_id.is_empty() or str(inimigos[i].get("id", "")) == alvo_id):
			indice_alvo = i
			break
	if not alvo_solicitado_id.is_empty() and indice_alvo < 0:
		return {"ok":false,"erro":"O alvo selecionado não está mais disponível."}
	if indice_alvo < 0:
		for i in range(inimigos.size()):
			if int(inimigos[i].get("vida", 0)) > 0:
				indice_alvo = i
				break
	if indice_alvo < 0:
		return {"ok":false,"erro":"Não há inimigos vivos neste combate."}
	estado["alvoSelecionadoId"] = str(inimigos[indice_alvo].get("id", ""))
	if acao == ACAO_DEFENDER:
		jogador["defendendo"] = true
		historico.append("%s assumiu uma postura defensiva." % jogador["nome"])
	elif acao == ACAO_ESQUIVAR:
		jogador["esquivando"] = true
		historico.append("%s se preparou para esquivar." % jogador["nome"])
	else:
		var magico := acao == ACAO_MAGIA
		if magico and int(jogador["mana"]) < 8:
			return {"ok":false,"erro":"Mana insuficiente para conjurar."}
		if magico:
			jogador["mana"] = int(jogador["mana"]) - 8
		var alvo: Dictionary = inimigos[indice_alvo]
		var atributo := "inteligencia" if magico else str(jogador["armaAtributo"])
		var poder := int(jogador.get(atributo, jogador["forca"]))
		var dano_base := int(jogador["armaDano"]) + int(round(float(poder) * 0.8))
		if magico:
			dano_base += int(round(float(jogador["espirito"]) * 0.35))
		var dano := _calcular_dano(dano_base, int(alvo["defesa"]), int(alvo["agilidade"]), int(jogador["agilidade"]), rng)
		if bool(dano["esquivou"]):
			historico.append("%s evitou o ataque!" % alvo["nome"])
		else:
			alvo["vida"] = maxi(0, int(alvo["vida"]) - int(dano["dano"]))
			var critico := " CRÍTICO!" if bool(dano["critico"]) else ""
			historico.append("%s causou %d de dano em %s.%s" % [jogador["nome"], dano["dano"], alvo["nome"], critico])
		if int(alvo["vida"]) <= 0:
			historico.append("%s foi derrotado." % alvo["nome"])
		inimigos[indice_alvo] = alvo
	var vivos := 0
	for inimigo in inimigos:
		if int(inimigo.get("vida", 0)) > 0:
			vivos += 1
	if vivos == 0:
		estado["status"] = STATUS_VITORIA
		historico.append("Todas as criaturas foram derrotadas!")
	else:
		var quantidade_vivos := vivos
		for i in range(inimigos.size()):
			var inimigo: Dictionary = inimigos[i]
			if int(inimigo.get("vida", 0)) <= 0:
				continue
			var magico_inimigo := int(inimigo["poderMagico"]) > int(inimigo["ataque"]) and int(inimigo["mana"]) >= 5
			var ataque := int(inimigo["poderMagico"]) if magico_inimigo else int(inimigo["ataque"])
			var defesa := int(round(float(jogador["defesa"]) * (0.5 if bool(jogador["defendendo"]) else 1.0)))
			var bonus_esquiva := 0.35 if bool(jogador["esquivando"]) else 0.0
			var resposta := _calcular_dano(ataque, defesa, int(jogador["agilidade"]), int(inimigo["agilidade"]), rng, bonus_esquiva)
			if magico_inimigo:
				inimigo["mana"] = int(inimigo["mana"]) - 5
			if bool(resposta["esquivou"]):
				historico.append("%s esquivou do ataque de %s." % [jogador["nome"], inimigo["nome"]])
			else:
				var fator_grupo := 1.0 if quantidade_vivos == 1 else 0.72
				var dano_recebido := maxi(1, int(round(float(resposta["dano"]) * fator_grupo)))
				jogador["vida"] = maxi(0, int(jogador["vida"]) - dano_recebido)
				historico.append("%s recebeu %d de dano de %s." % [jogador["nome"], dano_recebido, inimigo["nome"]])
			inimigos[i] = inimigo
			if int(jogador["vida"]) <= 0:
				break
		jogador["defendendo"] = false
		jogador["esquivando"] = false
		if int(jogador["vida"]) <= 0:
			estado["status"] = STATUS_DERROTA
			historico.append("%s foi derrotado." % jogador["nome"])
	estado["inimigos"] = inimigos
	for inimigo in inimigos:
		if int(inimigo.get("vida", 0)) > 0:
			estado["inimigo"] = inimigo.duplicate(true)
			break
	if not estado.has("inimigo") or vivos == 0:
		estado["inimigo"] = inimigos[0].duplicate(true)
	estado["jogador"] = jogador
	estado["historico"] = historico.slice(maxi(0, historico.size() - 30))
	return {"ok":true,"estado":estado}

static func _calcular_dano(dano_base: int, defesa: int, agilidade_alvo: int, agilidade_atacante: int, rng: RandomNumberGenerator, bonus_esquiva: float = 0.0) -> Dictionary:
	var chance_esquiva := clampf(0.05 + float(agilidade_alvo) * 0.002 + bonus_esquiva, 0.0, 0.35)
	if rng.randf() < chance_esquiva:
		return {"dano":0,"esquivou":true,"critico":false}
	var chance_critico := clampf(0.05 + float(agilidade_atacante) * 0.002, 0.05, 0.25)
	var critico := rng.randf() < chance_critico
	var dano := maxi(1, int(round(float(dano_base) * (1.75 if critico else 1.0) - float(defesa) * 0.45)))
	return {"dano":dano,"esquivou":false,"critico":critico}
