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

static func criar_estado(perfil: Dictionary, criatura: Dictionary) -> Dictionary:
	if not bool(perfil.get("personagemCriado", false)) or criatura.is_empty():
		return {}
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
		"historico": ["O combate começou contra %s." % str(criatura.get("nome", "uma criatura"))]
	}

## Executa uma rodada: ação escolhida pelo jogador e resposta da criatura.
## A semente deve ser gerada no servidor e nunca recebida do cliente.
static func executar_rodada(estado_original: Dictionary, acao: String, semente_servidor: int) -> Dictionary:
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
		var resultado_dano := _calcular_dano(dano_base, int(inimigo["defesa"]), int(jogador["agilidade"]), rng)
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
	var resultado_inimigo := _calcular_dano(ataque_inimigo, defesa_alvo, int(inimigo["agilidade"]), rng, esquiva_bonus)
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

static func _calcular_dano(dano_base: int, defesa: int, agilidade_atacante: int, rng: RandomNumberGenerator, bonus_esquiva: float = 0.0) -> Dictionary:
	var chance_esquiva := clampf(0.05 + float(agilidade_atacante) * 0.002 + bonus_esquiva, 0.0, 0.35)
	if rng.randf() < chance_esquiva:
		return {"dano":0,"esquivou":true,"critico":false}
	var chance_critico := clampf(0.05 + float(agilidade_atacante) * 0.002, 0.05, 0.25)
	var critico := rng.randf() < chance_critico
	var dano := maxi(1, int(round(float(dano_base) * (1.75 if critico else 1.0) - float(defesa) * 0.45)))
	return {"dano":dano,"esquivou":false,"critico":critico}
