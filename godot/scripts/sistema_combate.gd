extends RefCounted
class_name SistemaCombate

## Regras puras do combate. A instância autoritativa deve existir no servidor.
const Equipamentos = preload("res://scripts/sistema_equipamentos.gd")
const CatalogoArmasOnePiece = preload("res://scripts/catalogo_armas_one_piece.gd")
const ACAO_ATAQUE := "ataque"
const ACAO_MAGIA := "magia"
const ACAO_HABILIDADE := "habilidade"
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
	var invocacao_estado: Dictionary = {}
	var id_ativa := str(perfil.get("invocacaoAtivaId", perfil.get("invocacaoInicialId", "")))
	for candidata in perfil.get("invocacoes", []):
		if candidata is Dictionary and str(candidata.get("id", "")) == id_ativa:
			invocacao_estado = candidata.duplicate(true)
			invocacao_estado["vidaMaxima"] = maxi(1, int(invocacao_estado.get("vidaMaxima", invocacao_estado.get("vida", 20))))
			invocacao_estado["vida"] = invocacao_estado["vidaMaxima"]
			invocacao_estado["manaMaxima"] = maxi(0, int(invocacao_estado.get("manaMaxima", int(invocacao_estado.get("poderMagico", 0)) * 3)))
			invocacao_estado["mana"] = invocacao_estado["manaMaxima"]
			invocacao_estado["ativa"] = true
			invocacao_estado["protegendoMestre"] = false
			break
	return {
		"status": STATUS_EM_ANDAMENTO, "turno": "jogador",
		"jogador": {
			"nome": str(perfil.get("nome", "Aventureiro")), "vida": vida_jogador,
			"vidaMaxima": int(efetivos["vidaMaxima"]), "mana": mana_jogador,
			"manaMaxima": int(efetivos["manaMaxima"]), "forca": int(efetivos["forca"]),
			"inteligencia": int(efetivos["inteligencia"]), "agilidade": int(efetivos["agilidade"]),
			"espirito": int(efetivos["espirito"]),
			"habilidades": perfil.get("habilidades", []).duplicate(true),
			"defesa": int(round((int(efetivos["defesaEquipamento"]) + int(efetivos["vitalidade"]) / 3.0) * float(perfil.get("defesaPercentual", 100)) / 100.0)),
			"armaDano": int(arma.get("dano", 5)), "armaAtributo": str(arma.get("atributo", "forca")),
			"armaCategoria": str(arma.get("categoria", "fisica")), "armaOnePieceId": str(perfil.get("equipamentos", {}).get("mao_principal", "")) if not CatalogoArmasOnePiece.obter(str(perfil.get("equipamentos", {}).get("mao_principal", ""))).is_empty() else "",
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
			"rank": str(criatura.get("rank", "E")),
			"padroesAtaque": (criatura.get("padroesAtaque", []) if criatura.get("padroesAtaque", []) is Array else []).duplicate(true),
			"turnoAtaqueEspecial": 0,
			"defendendo": false, "esquivando": false
		},
		"invocacao": invocacao_estado,
		"modoCompanheiro": "equilibrado",
		"contadorTurnosCompanheiro": 0,
		"cargaCombo": 0,
		"combosExecutados": 0,
		"ordemCompanheiro": "",
		"alvoCompanheiroId": "",
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

## Define a assinatura do combo a partir dos dados gerados da própria criatura.
## Não depende de uma lista fechada de espécies: criaturas novas recebem um estilo coerente.
static func _assinatura_combo_companheiro(invocacao: Dictionary, habilidade: Dictionary = {}) -> Dictionary:
	var especie := str(invocacao.get("especie", invocacao.get("especieId", invocacao.get("familia", "")))).to_lower()
	var corpo := str(invocacao.get("tipoCorpo", invocacao.get("categoriaCorpo", ""))).to_lower()
	var elemento_habilidade := str(habilidade.get("elemento", "")).to_lower()
	var elemento_invocacao := str(invocacao.get("elemento", "")).to_lower()
	var elemento := elemento_invocacao if not elemento_invocacao.is_empty() and elemento_invocacao != "arcano" else elemento_habilidade if not elemento_habilidade.is_empty() else "arcano"
	var estilo := "sincronia"
	var nome := "Investida Sincronizada"
	var descricao := "ataque combinado"
	if (especie.contains("lobo") or especie.contains("canideo") or especie.contains("raposa")) and elemento not in ["fogo", "chama", "lava", "gelo", "neve", "frio", "raio", "eletrico", "eletricidade", "trovao", "agua", "mar", "correnteza", "sombra", "trevas", "abismo"]:
		estilo = "cacada"
		nome = "Caçada em Dupla"
		descricao = "uma caçada coordenada"
	elif especie.contains("serpente") or especie.contains("cobra") or especie.contains("draco"):
		estilo = "constricao"
		nome = "Espiral Constritora"
		descricao = "uma espiral constritora"
	elif (especie.contains("ave") or especie.contains("passaro") or corpo in ["ave", "voador", "alado"]) and elemento not in ["fogo", "chama", "lava", "gelo", "neve", "frio", "raio", "eletrico", "eletricidade", "trovao", "agua", "mar", "correnteza", "sombra", "trevas", "abismo"]:
		estilo = "mergulho"
		nome = "Mergulho Vinculado"
		descricao = "um mergulho combinado"
	elif (especie.contains("golem") or corpo in ["constructo", "quadrupede_pesado"]) and elemento not in ["fogo", "chama", "lava", "gelo", "neve", "frio", "raio", "eletrico", "eletricidade", "trovao", "agua", "mar", "correnteza", "sombra", "trevas", "abismo"]:
		estilo = "impacto"
		nome = "Impacto de Ressonância"
		descricao = "um impacto conjunto"
	elif (especie.contains("limo") or especie.contains("slime") or corpo == "gelatinoso") and elemento not in ["fogo", "chama", "lava", "gelo", "neve", "frio", "raio", "eletrico", "eletricidade", "trovao", "agua", "mar", "correnteza", "sombra", "trevas", "abismo"]:
		estilo = "onda"
		nome = "Onda Convergente"
		descricao = "uma onda convergente"
	elif elemento in ["fogo", "chama", "lava"]:
		estilo = "explosao_elemental"
		nome = "Ruptura Ígnea"
		descricao = "uma ruptura de fogo"
	elif elemento in ["gelo", "neve", "frio"]:
		estilo = "estilhaco"
		nome = "Estilhaço Glacial"
		descricao = "uma descarga glacial"
	elif elemento in ["raio", "eletrico", "eletricidade", "trovao"]:
		estilo = "descarga"
		nome = "Descarga Relampejante"
		descricao = "uma descarga elétrica"
	elif elemento in ["agua", "mar", "correnteza"]:
		estilo = "mare"
		nome = "Maré Vinculada"
		descricao = "uma maré concentrada"
	elif elemento in ["sombra", "trevas", "abismo"]:
		estilo = "abismo"
		nome = "Ruptura do Abismo"
		descricao = "uma ruptura sombria"
	return {"estiloCombo":estilo,"nomeCombo":nome,"descricaoCombo":descricao,"elementoCombo":elemento,"especieCombo":especie}

## Aplica uma condição real ao inimigo quando um combo elemental é concluído.
static func _aplicar_status_combo(alvo: Dictionary, assinatura: Dictionary, dano_combo: int, historico: Array) -> void:
	var elemento := str(assinatura.get("elementoCombo", "")).to_lower()
	var estilo := str(assinatura.get("estiloCombo", ""))
	var status_id := ""
	var nome_status := ""
	var duracao := 2
	var dano_turno := 0
	if estilo == "constricao":
		status_id = "lentidao"
		nome_status = "Lento"
	elif elemento in ["veneno", "toxina", "peçonha"]:
		status_id = "veneno"
		nome_status = "Envenenado"
		dano_turno = maxi(1, int(round(float(dano_combo) * 0.12)))
	elif elemento in ["fogo", "chama", "lava"]:
		status_id = "queimadura"
		nome_status = "Queimando"
		dano_turno = maxi(1, int(round(float(dano_combo) * 0.10)))
	elif elemento in ["gelo", "neve", "frio"]:
		status_id = "lentidao"
		nome_status = "Lento"
	elif elemento in ["raio", "eletrico", "eletricidade", "trovao"]:
		status_id = "atordoamento"
		nome_status = "Atordoado"
		duracao = 1
	elif elemento in ["agua", "mar", "correnteza"]:
		status_id = "lentidao"
		nome_status = "Encharcado e lento"
	elif elemento in ["sombra", "trevas", "abismo"]:
		status_id = "vulnerabilidade"
		nome_status = "Vulnerável"
	elif estilo in ["cacada", "mergulho"]:
		status_id = "sangramento"
		nome_status = "Sangrando"
		dano_turno = maxi(1, int(round(float(dano_combo) * 0.08)))
	if status_id.is_empty():
		return
	var efeitos: Array = alvo.get("efeitosStatus", []) if alvo.get("efeitosStatus", []) is Array else []
	var encontrado := false
	for efeito in efeitos:
		if efeito is Dictionary and str(efeito.get("id", "")) == status_id:
			efeito["turnos"] = maxi(int(efeito.get("turnos", 0)), duracao)
			efeito["danoPorTurno"] = maxi(int(efeito.get("danoPorTurno", 0)), dano_turno)
			encontrado = true
			break
	if not encontrado:
		efeitos.append({"id":status_id,"nome":nome_status,"turnos":duracao,"danoPorTurno":dano_turno})
	alvo["efeitosStatus"] = efeitos
	historico.append("%s ficou %s por causa do combo!" % [alvo.get("nome", "O inimigo"), nome_status.to_lower()])

## Resolve condições no início da resposta inimiga. Retorna true se ela perder a ação.
static func _processar_status_inimigo(alvo: Dictionary, historico: Array) -> bool:
	var efeitos: Array = alvo.get("efeitosStatus", []) if alvo.get("efeitosStatus", []) is Array else []
	var restantes: Array = []
	var perdeu_acao := false
	for efeito in efeitos:
		if not efeito is Dictionary:
			continue
		var id := str(efeito.get("id", ""))
		var turnos := int(efeito.get("turnos", 0))
		if turnos <= 0:
			continue
		var dano := maxi(0, int(efeito.get("danoPorTurno", 0)))
		if dano > 0:
			alvo["vida"] = maxi(0, int(alvo.get("vida", 0)) - dano)
			historico.append("%s sofreu %d de dano por %s." % [alvo.get("nome", "O inimigo"), dano, str(efeito.get("nome", id)).to_lower()])
		if id == "atordoamento":
			perdeu_acao = true
		turnos -= 1
		if turnos > 0:
			var atualizado: Dictionary = efeito.duplicate(true)
			atualizado["turnos"] = turnos
			restantes.append(atualizado)
	alvo["efeitosStatus"] = restantes
	return perdeu_acao

## A IA do companheiro age no servidor. Ordens pontuais prevalecem sobre o modo automático.
static func _ataque_automatico_invocacao(estado: Dictionary, alvo: Dictionary, historico: Array) -> Dictionary:
	var invocacao: Dictionary = estado.get("invocacao", {}).duplicate(true)
	if invocacao.is_empty() or not bool(invocacao.get("ativa", false)) or int(invocacao.get("vida", 0)) <= 0:
		return alvo
	var jogador: Dictionary = estado.get("jogador", {}).duplicate(true)
	var modo := str(estado.get("modoCompanheiro", "equilibrado"))
	var ordem := str(estado.get("ordemCompanheiro", ""))
	var turno_pet := int(estado.get("contadorTurnosCompanheiro", 0)) + 1
	estado["contadorTurnosCompanheiro"] = turno_pet
	var habilidades: Array = invocacao.get("habilidades", []) if invocacao.get("habilidades", []) is Array else []
	var habilidade_escolhida: Dictionary = {}
	var vida_jogador_pct := float(jogador.get("vida", 0)) / float(maxi(1, int(jogador.get("vidaMaxima", 1))))
	if ordem == "proteger" or (ordem.is_empty() and modo == "defensivo"):
		invocacao["protegendoMestre"] = true
		historico.append("%s se posicionou à frente de seu mestre, preparando-se para protegê-lo." % invocacao.get("nome", "O companheiro"))
		estado["ordemCompanheiro"] = ""
	else:
		var carga_combo := int(estado.get("cargaCombo", 0))
		var combo_pronto := carga_combo >= 3
		var pode_usar_habilidade := ordem == "habilidade" or modo == "agressivo" or (modo == "equilibrado" and turno_pet % 2 == 0) or combo_pronto
		if pode_usar_habilidade:
			for habilidade in habilidades:
				if not habilidade is Dictionary:
					continue
				var custo := maxi(0, int(habilidade.get("custoMana", 0)))
				if custo > int(invocacao.get("mana", 0)):
					continue
				var categoria := str(habilidade.get("categoria", "fisica")).to_lower()
				if combo_pronto and categoria in ["suporte", "cura", "defesa", "protecao"]:
					continue
				if categoria in ["suporte", "cura"] and vida_jogador_pct >= 0.70:
					continue
				if categoria in ["defesa", "protecao"] and modo != "defensivo" and ordem != "habilidade":
					continue
				habilidade_escolhida = habilidade.duplicate(true)
				break
		if not habilidade_escolhida.is_empty() and int(alvo.get("vida", 0)) > 0:
			var custo_habilidade := maxi(0, int(habilidade_escolhida.get("custoMana", 0)))
			invocacao["mana"] = maxi(0, int(invocacao.get("mana", 0)) - custo_habilidade)
			var categoria_habilidade := str(habilidade_escolhida.get("categoria", "fisica")).to_lower()
			if categoria_habilidade in ["suporte", "cura"]:
				var cura := mini(int(jogador.get("vidaMaxima", 1)) - int(jogador.get("vida", 0)), maxi(1, int(round(float(jogador.get("vidaMaxima", 1)) * 0.18))))
				jogador["vida"] = mini(int(jogador.get("vidaMaxima", 1)), int(jogador.get("vida", 0)) + cura)
				estado["efeitoHabilidade"] = habilidade_escolhida.duplicate(true)
				estado["efeitoHabilidade"]["tipoEfeito"] = "cura"
				historico.append("%s usou %s e restaurou %d de vida de seu mestre." % [invocacao.get("nome", "O companheiro"), habilidade_escolhida.get("nome", "uma habilidade"), cura])
			elif categoria_habilidade in ["defesa", "protecao"]:
				invocacao["protegendoMestre"] = true
				estado["efeitoHabilidade"] = habilidade_escolhida.duplicate(true)
				estado["efeitoHabilidade"]["tipoEfeito"] = "defesa"
				historico.append("%s usou %s e protegeu seu mestre." % [invocacao.get("nome", "O companheiro"), habilidade_escolhida.get("nome", "uma habilidade")])
			else:
				var nivel_habilidade := maxf(0.5, float(habilidade_escolhida.get("multiplicadorDano", 1.0)))
				var poder_hibrido := float(invocacao.get("ataque", 3)) + float(invocacao.get("poderMagico", 0)) * 0.45 + float(invocacao.get("nivel", 1)) * 1.5
				var dano_bruto := (poder_hibrido * nivel_habilidade) - float(alvo.get("defesa", 0)) * 0.45
				if combo_pronto:
					dano_bruto *= 1.75
				var dano_habilidade := maxi(1, int(round(dano_bruto)))
				alvo["vida"] = maxi(0, int(alvo.get("vida", 0)) - dano_habilidade)
				estado["efeitoHabilidade"] = habilidade_escolhida.duplicate(true)
				estado["efeitoHabilidade"]["tipoEfeito"] = "combo_companheiro" if combo_pronto else "invocacao"
				if combo_pronto:
					var assinatura := _assinatura_combo_companheiro(invocacao, habilidade_escolhida)
					for chave in assinatura.keys():
						estado["efeitoHabilidade"][chave] = assinatura[chave]
					estado["cargaCombo"] = 0
					estado["combosExecutados"] = int(estado.get("combosExecutados", 0)) + 1
					_aplicar_status_combo(alvo, assinatura, dano_habilidade, historico)
					historico.append("COMBO DE VÍNCULO — %s! %s e seu mestre executaram %s com %s: %s causou %d de dano!" % [assinatura["nomeCombo"], invocacao.get("nome", "O companheiro"), assinatura["descricaoCombo"], habilidade_escolhida.get("nome", "uma habilidade"), alvo.get("nome", "o inimigo"), dano_habilidade])
				else:
					historico.append("%s liberou %s contra %s e causou %d de dano." % [invocacao.get("nome", "O companheiro"), habilidade_escolhida.get("nome", "uma habilidade"), alvo.get("nome", "o inimigo"), dano_habilidade])
		elif int(alvo.get("vida", 0)) > 0:
			var nivel := maxi(1, int(invocacao.get("nivel", 1)))
			var poder := maxi(1, int(invocacao.get("ataque", 3)) + int(nivel / 2))
			var dano_base := maxi(1, poder - int(round(float(alvo.get("defesa", 0)) * 0.5)))
			var dano := maxi(1, int(round(float(dano_base) * (1.6 if combo_pronto else 1.0))))
			alvo["vida"] = maxi(0, int(alvo.get("vida", 0)) - dano)
			if combo_pronto:
				estado["cargaCombo"] = 0
				estado["combosExecutados"] = int(estado.get("combosExecutados", 0)) + 1
				var assinatura := _assinatura_combo_companheiro(invocacao)
				estado["efeitoHabilidade"] = {"nome":assinatura["nomeCombo"],"tipoEfeito":"combo_companheiro"}
				for chave in assinatura.keys():
					estado["efeitoHabilidade"][chave] = assinatura[chave]
				_aplicar_status_combo(alvo, assinatura, dano, historico)
				historico.append("COMBO DE VÍNCULO — %s! %s e seu mestre executaram %s e causaram %d de dano!" % [assinatura["nomeCombo"], invocacao.get("nome", "O companheiro"), assinatura["descricaoCombo"], dano])
			else:
				historico.append("%s atacou por conta própria e causou %d de dano em %s." % [invocacao.get("nome", "O companheiro"), dano, alvo.get("nome", "o inimigo")])
		estado["ordemCompanheiro"] = ""
	estado["jogador"] = jogador
	estado["invocacao"] = invocacao
	return alvo

static func aplicar_comando_companheiro(estado_original: Dictionary, modo: String, ordem: String, alvo_id: String = "") -> Dictionary:
	if estado_original.is_empty() or str(estado_original.get("status", "")) != STATUS_EM_ANDAMENTO:
		return {"ok":false,"erro":"Não existe combate ativo para comandar o companheiro."}
	if not ["agressivo", "defensivo", "equilibrado"].has(modo):
		return {"ok":false,"erro":"Modo de comportamento inválido."}
	if not ["", "atacar", "proteger", "habilidade"].has(ordem):
		return {"ok":false,"erro":"Ordem do companheiro inválida."}
	var estado := estado_original.duplicate(true)
	if estado.get("invocacao", {}).is_empty():
		return {"ok":false,"erro":"Você não possui um companheiro ativo nesta batalha."}
	if not alvo_id.is_empty():
		var alvo_valido := false
		for inimigo in estado.get("inimigos", [estado.get("inimigo", {})]):
			if str(inimigo.get("id", "")) == alvo_id and int(inimigo.get("vida", 0)) > 0:
				alvo_valido = true
				break
		if not alvo_valido and str(estado.get("inimigo", {}).get("id", "")) != alvo_id:
			return {"ok":false,"erro":"O alvo escolhido não está disponível."}
	estado["modoCompanheiro"] = modo
	estado["ordemCompanheiro"] = ordem
	estado["alvoCompanheiroId"] = alvo_id
	var invocacao: Dictionary = estado["invocacao"]
	invocacao["modoComportamento"] = modo
	estado["invocacao"] = invocacao
	return {"ok":true,"estado":estado}

## Executa uma rodada: ação escolhida pelo jogador e resposta da criatura.
## A semente deve ser gerada no servidor e nunca recebida do cliente.

static func executar_rodada(estado_original: Dictionary, acao: String, semente_servidor: int, alvo_selecionado_id: String = "", habilidade_id: String = "") -> Dictionary:
	if estado_original.has("inimigos") and estado_original.get("inimigos", []) is Array and not estado_original.get("inimigos", []).is_empty():
		return _executar_rodada_grupo(estado_original, acao, semente_servidor, alvo_selecionado_id, habilidade_id)
	if estado_original.is_empty() or str(estado_original.get("status", "")) != STATUS_EM_ANDAMENTO:
		return {"ok":false,"erro":"Não existe combate ativo."}
	if str(estado_original.get("turno", "")) != "jogador":
		return {"ok":false,"erro":"Ainda não é o turno do jogador."}
	if not [ACAO_ATAQUE, ACAO_MAGIA, ACAO_HABILIDADE, ACAO_DEFENDER, ACAO_ESQUIVAR].has(acao):
		return {"ok":false,"erro":"Ação de combate inválida."}
	var estado := estado_original.duplicate(true)
	estado.erase("efeitoHabilidade")
	var habilidade_usada: Dictionary = _buscar_habilidade(estado.get("jogador", {}), habilidade_id) if acao == ACAO_HABILIDADE else {}
	if acao == ACAO_HABILIDADE and habilidade_usada.is_empty():
		return {"ok":false,"erro":"Você não possui essa habilidade."}
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
		var categoria_habilidade := str(habilidade_usada.get("categoria", "")) if acao == ACAO_HABILIDADE else ""
		if categoria_habilidade == "suporte":
			var custo_suporte := int(habilidade_usada.get("custoMana", 0))
			if int(jogador["mana"]) < custo_suporte:
				return {"ok":false,"erro":"Mana insuficiente para usar essa habilidade."}
			var cura := mini(int(jogador["vidaMaxima"]) - int(jogador["vida"]), maxi(0, int(round(float(jogador["vidaMaxima"]) * 0.20)) + int(jogador["espirito"])))
			jogador["mana"] = int(jogador["mana"]) - custo_suporte
			jogador["vida"] = mini(int(jogador["vidaMaxima"]), int(jogador["vida"]) + cura)
			estado["efeitoHabilidade"] = habilidade_usada.duplicate(true)
			estado["efeitoHabilidade"]["tipoEfeito"] = "cura"
			historico.append("%s restaurou %d pontos de vida com %s." % [jogador["nome"], cura, habilidade_usada.get("nome", "uma habilidade")])
		elif categoria_habilidade == "defesa":
			var custo_defesa := int(habilidade_usada.get("custoMana", 0))
			if int(jogador["mana"]) < custo_defesa:
				return {"ok":false,"erro":"Mana insuficiente para usar essa habilidade."}
			jogador["mana"] = int(jogador["mana"]) - custo_defesa
			jogador["defendendo"] = true
			estado["efeitoHabilidade"] = habilidade_usada.duplicate(true)
			estado["efeitoHabilidade"]["tipoEfeito"] = "defesa"
			historico.append("%s ergueu %s e reforçou sua defesa." % [jogador["nome"], habilidade_usada.get("nome", "uma barreira")])
		elif categoria_habilidade == "invocacao":
			var custo_invocacao := int(habilidade_usada.get("custoMana", 5))
			var invocacao: Dictionary = estado.get("invocacao", {})
			if bool(estado.get("habilidadeInvocacaoUsada", false)):
				return {"ok":false,"erro":"Sua invocação já recebeu esse comando nesta batalha."}
			if invocacao.is_empty() or str(habilidade_usada.get("invocacaoId", "")) != str(invocacao.get("id", "")):
				return {"ok":false,"erro":"Sua invocação vinculada não está disponível."}
			if int(jogador["mana"]) < custo_invocacao:
				return {"ok":false,"erro":"Mana insuficiente para comandar sua criatura."}
			jogador["mana"] = int(jogador["mana"]) - custo_invocacao
			estado["habilidadeInvocacaoUsada"] = true
			invocacao["ativa"] = true
			estado["invocacao"] = invocacao
			estado["modoCompanheiro"] = "agressivo"
			estado["ordemCompanheiro"] = "habilidade"
			estado["efeitoHabilidade"] = habilidade_usada.duplicate(true)
			estado["efeitoHabilidade"]["tipoEfeito"] = "invocacao"
			historico.append("%s comandou %s a liberar uma habilidade especial por %d PM." % [jogador["nome"], invocacao.get("nome", "sua criatura"), custo_invocacao])
		else:
			var magico := acao == ACAO_MAGIA or (acao == ACAO_HABILIDADE and str(habilidade_usada.get("categoria", "magica")) != "fisica")
			var custo_mana := int(habilidade_usada.get("custoMana", 0)) if acao == ACAO_HABILIDADE else 8
			if magico and int(jogador["mana"]) < custo_mana:
				return {"ok":false,"erro":"Mana insuficiente para usar essa habilidade."}
			if magico:
				jogador["mana"] = int(jogador["mana"]) - custo_mana
			var atributo := "inteligencia" if magico else str(jogador["armaAtributo"])
			var poder := int(jogador.get(atributo, jogador["forca"]))
			var dano_base := int(jogador["armaDano"]) + int(round(float(poder) * 0.8))
			if magico:
				dano_base += int(round(float(jogador["espirito"]) * 0.35))
			if acao == ACAO_HABILIDADE:
				var multiplicador := float(habilidade_usada.get("multiplicadorDano", 1.0))
				if categoria_habilidade == "invocacao":
					multiplicador = maxf(multiplicador, 1.15)
				dano_base = maxi(1, int(round(float(dano_base) * multiplicador)))
				estado["efeitoHabilidade"] = habilidade_usada.duplicate(true)
				if categoria_habilidade == "invocacao":
					estado["efeitoHabilidade"]["tipoEfeito"] = "invocacao"
			var resultado_dano := _calcular_dano(dano_base, int(inimigo["defesa"]), int(inimigo["agilidade"]), int(jogador["agilidade"]), rng)
			if bool(resultado_dano["esquivou"]):
				historico.append("%s evitou o ataque!" % inimigo["nome"])
			else:
				inimigo["vida"] = maxi(0, int(inimigo["vida"]) - int(resultado_dano["dano"]))
				if bool(estado.get("invocacao", {}).get("ativa", false)):
					estado["cargaCombo"] = mini(3, int(estado.get("cargaCombo", 0)) + 1)
				var texto_critico := " CRÍTICO!" if bool(resultado_dano["critico"]) else ""
				historico.append("%s causou %d de dano em %s.%s" % [jogador["nome"], resultado_dano["dano"], inimigo["nome"], texto_critico])
				if acao == ACAO_HABILIDADE:
					historico.append("%s liberou %s, afinidade %s." % [jogador["nome"], habilidade_usada.get("nome", "habilidade"), habilidade_usada.get("elemento", "arcano")])
			if int(inimigo["vida"]) <= 0:
				estado["status"] = STATUS_VITORIA
				historico.append("%s foi derrotado." % inimigo["nome"])
				estado["jogador"] = jogador
				estado["inimigo"] = inimigo
				estado["historico"] = historico
				var invocacao_fim_ataque: Dictionary = estado.get("invocacao", {})
				invocacao_fim_ataque["ativa"] = false
				estado["invocacao"] = invocacao_fim_ataque
				return {"ok":true,"estado":estado}
	if bool(estado.get("invocacao", {}).get("ativa", false)):
		inimigo = _ataque_automatico_invocacao(estado, inimigo, historico)
		jogador = estado.get("jogador", jogador)
		if int(inimigo["vida"]) <= 0:
			estado["status"] = STATUS_VITORIA
			historico.append("%s foi derrotado." % inimigo["nome"])
			estado["jogador"] = jogador
			estado["inimigo"] = inimigo
			estado["historico"] = historico
			var invocacao_final: Dictionary = estado.get("invocacao", {})
			invocacao_final["ativa"] = false
			estado["invocacao"] = invocacao_final
			return {"ok":true,"estado":estado}
	var inimigo_perdeu_acao := _processar_status_inimigo(inimigo, historico)
	if int(inimigo.get("vida", 0)) <= 0:
		estado["status"] = STATUS_VITORIA
		historico.append("%s foi derrotado pelos efeitos do combo." % inimigo.get("nome", "O inimigo"))
		estado["jogador"] = jogador
		estado["inimigo"] = inimigo
		estado["historico"] = historico
		var invocacao_por_status: Dictionary = estado.get("invocacao", {})
		invocacao_por_status["ativa"] = false
		estado["invocacao"] = invocacao_por_status
		return {"ok":true,"estado":estado}
	var inimigo_magico := int(inimigo["poderMagico"]) > int(inimigo["ataque"]) and int(inimigo["mana"]) >= 5
	var ataque_inimigo := int(inimigo["poderMagico"]) if inimigo_magico else int(inimigo["ataque"])
	var especial := _obter_ataque_especial_para_impacto(inimigo, historico)
	if inimigo_perdeu_acao:
		historico.append("%s perdeu a vez, atordoado pelo combo!" % inimigo.get("nome", "O inimigo"))
	elif bool(especial.get("preparando", false)):
		inimigo["ataqueEspecialPreparando"] = especial.duplicate(true)
		historico.append("%s prepara %s! Você terá uma ação para defender ou esquivar." % [inimigo["nome"], especial.get("nome", "um ataque especial")])
	else:
		ataque_inimigo = maxi(1, int(round(float(ataque_inimigo) * float(especial.get("multiplicador", 1.0)))))
		var protecao_pet := bool(estado.get("invocacao", {}).get("protegendoMestre", false))
		var defesa_alvo := int(round(float(jogador["defesa"]) * (0.5 if bool(jogador["defendendo"]) else 1.0)))
		var esquiva_bonus := 0.35 if bool(jogador["esquivando"]) else 0.0
		var resultado_inimigo := _calcular_dano(ataque_inimigo, defesa_alvo, int(jogador["agilidade"]), int(inimigo["agilidade"]), rng, esquiva_bonus)
		if protecao_pet:
			resultado_inimigo["dano"] = int(round(float(resultado_inimigo["dano"]) * 0.70))
			var invocacao_protetora: Dictionary = estado.get("invocacao", {})
			invocacao_protetora["protegendoMestre"] = false
			estado["invocacao"] = invocacao_protetora
			historico.append("O companheiro interceptou parte do golpe e reduziu o dano recebido.")
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
static func _executar_rodada_grupo(estado_original: Dictionary, acao: String, semente_servidor: int, alvo_solicitado_id: String = "", habilidade_id: String = "") -> Dictionary:
	if str(estado_original.get("status", "")) != STATUS_EM_ANDAMENTO or str(estado_original.get("turno", "")) != "jogador":
		return {"ok":false,"erro":"Não existe turno de combate válido."}
	if not [ACAO_ATAQUE, ACAO_MAGIA, ACAO_HABILIDADE, ACAO_DEFENDER, ACAO_ESQUIVAR].has(acao):
		return {"ok":false,"erro":"Ação de combate inválida."}
	var estado := estado_original.duplicate(true)
	estado.erase("efeitoHabilidade")
	var habilidade_usada: Dictionary = _buscar_habilidade(estado.get("jogador", {}), habilidade_id) if acao == ACAO_HABILIDADE else {}
	if acao == ACAO_HABILIDADE and habilidade_usada.is_empty():
		return {"ok":false,"erro":"Você não possui essa habilidade."}
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
		var categoria_habilidade := str(habilidade_usada.get("categoria", "")) if acao == ACAO_HABILIDADE else ""
		if categoria_habilidade == "suporte":
			var custo_suporte := int(habilidade_usada.get("custoMana", 0))
			if int(jogador["mana"]) < custo_suporte:
				return {"ok":false,"erro":"Mana insuficiente para usar essa habilidade."}
			var cura := mini(int(jogador["vidaMaxima"]) - int(jogador["vida"]), maxi(0, int(round(float(jogador["vidaMaxima"]) * 0.20)) + int(jogador["espirito"])))
			jogador["mana"] = int(jogador["mana"]) - custo_suporte
			jogador["vida"] = mini(int(jogador["vidaMaxima"]), int(jogador["vida"]) + cura)
			estado["efeitoHabilidade"] = habilidade_usada.duplicate(true)
			estado["efeitoHabilidade"]["tipoEfeito"] = "cura"
			historico.append("%s restaurou %d pontos de vida com %s." % [jogador["nome"], cura, habilidade_usada.get("nome", "uma habilidade")])
		elif categoria_habilidade == "defesa":
			var custo_defesa := int(habilidade_usada.get("custoMana", 0))
			if int(jogador["mana"]) < custo_defesa:
				return {"ok":false,"erro":"Mana insuficiente para usar essa habilidade."}
			jogador["mana"] = int(jogador["mana"]) - custo_defesa
			jogador["defendendo"] = true
			estado["efeitoHabilidade"] = habilidade_usada.duplicate(true)
			estado["efeitoHabilidade"]["tipoEfeito"] = "defesa"
			historico.append("%s ergueu %s e reforçou sua defesa." % [jogador["nome"], habilidade_usada.get("nome", "uma barreira")])
		elif categoria_habilidade == "invocacao":
			var custo_invocacao := int(habilidade_usada.get("custoMana", 5))
			var invocacao: Dictionary = estado.get("invocacao", {})
			if invocacao.is_empty() or str(habilidade_usada.get("invocacaoId", "")) != str(invocacao.get("id", "")):
				return {"ok":false,"erro":"Sua invocação vinculada não está disponível."}
			if int(jogador["mana"]) < custo_invocacao:
				return {"ok":false,"erro":"Mana insuficiente para comandar sua criatura."}
			jogador["mana"] = int(jogador["mana"]) - custo_invocacao
			invocacao["ativa"] = true
			estado["invocacao"] = invocacao
			estado["modoCompanheiro"] = "agressivo"
			estado["ordemCompanheiro"] = "habilidade"
			estado["efeitoHabilidade"] = habilidade_usada.duplicate(true)
			estado["efeitoHabilidade"]["tipoEfeito"] = "invocacao"
			historico.append("%s comandou %s a liberar uma habilidade especial por %d PM." % [jogador["nome"], invocacao.get("nome", "sua criatura"), custo_invocacao])
		else:
			var magico := acao == ACAO_MAGIA or (acao == ACAO_HABILIDADE and str(habilidade_usada.get("categoria", "magica")) != "fisica")
			var custo_mana := int(habilidade_usada.get("custoMana", 0)) if acao == ACAO_HABILIDADE else 8
			if magico and int(jogador["mana"]) < custo_mana:
				return {"ok":false,"erro":"Mana insuficiente para usar essa habilidade."}
			if magico:
				jogador["mana"] = int(jogador["mana"]) - custo_mana
			var alvo: Dictionary = inimigos[indice_alvo]
			var atributo := "inteligencia" if magico else str(jogador["armaAtributo"])
			var poder := int(jogador.get(atributo, jogador["forca"]))
			var dano_base := int(jogador["armaDano"]) + int(round(float(poder) * 0.8))
			if magico:
				dano_base += int(round(float(jogador["espirito"]) * 0.35))
			if acao == ACAO_HABILIDADE:
				var multiplicador := float(habilidade_usada.get("multiplicadorDano", 1.0))
				if categoria_habilidade == "invocacao":
					multiplicador = maxf(multiplicador, 1.15)
				dano_base = maxi(1, int(round(float(dano_base) * multiplicador)))
				estado["efeitoHabilidade"] = habilidade_usada.duplicate(true)
				if categoria_habilidade == "invocacao":
					estado["efeitoHabilidade"]["tipoEfeito"] = "invocacao"
			var dano := _calcular_dano(dano_base, int(alvo["defesa"]), int(alvo["agilidade"]), int(jogador["agilidade"]), rng)
			if bool(dano["esquivou"]):
				historico.append("%s evitou o ataque!" % alvo["nome"])
			else:
				alvo["vida"] = maxi(0, int(alvo["vida"]) - int(dano["dano"]))
				if bool(estado.get("invocacao", {}).get("ativa", false)):
					estado["cargaCombo"] = mini(3, int(estado.get("cargaCombo", 0)) + 1)
				var critico := " CRÍTICO!" if bool(dano["critico"]) else ""
				historico.append("%s causou %d de dano em %s.%s" % [jogador["nome"], dano["dano"], alvo["nome"], critico])
				if acao == ACAO_HABILIDADE:
					historico.append("%s liberou %s, afinidade %s." % [jogador["nome"], habilidade_usada.get("nome", "habilidade"), habilidade_usada.get("elemento", "arcano")])
			if int(alvo["vida"]) <= 0:
				historico.append("%s foi derrotado." % alvo["nome"])
			inimigos[indice_alvo] = alvo
	if bool(estado.get("invocacao", {}).get("ativa", false)):
		var indice_alvo_pet := indice_alvo
		var alvo_pet_id := str(estado.get("alvoCompanheiroId", ""))
		if not alvo_pet_id.is_empty():
			for indice_escolhido in range(inimigos.size()):
				if str(inimigos[indice_escolhido].get("id", "")) == alvo_pet_id and int(inimigos[indice_escolhido].get("vida", 0)) > 0:
					indice_alvo_pet = indice_escolhido
					break
		if int(inimigos[indice_alvo_pet].get("vida", 0)) <= 0:
			for indice_pet in range(inimigos.size()):
				if int(inimigos[indice_pet].get("vida", 0)) > 0:
					indice_alvo_pet = indice_pet
					break
		if int(inimigos[indice_alvo_pet].get("vida", 0)) > 0:
			var alvo_invocacao: Dictionary = inimigos[indice_alvo_pet]
			alvo_invocacao = _ataque_automatico_invocacao(estado, alvo_invocacao, historico)
			inimigos[indice_alvo_pet] = alvo_invocacao
			estado["alvoCompanheiroId"] = ""
			jogador = estado.get("jogador", jogador)
	var vivos := 0
	for inimigo in inimigos:
		if int(inimigo.get("vida", 0)) > 0:
			vivos += 1
	if vivos == 0:
		estado["status"] = STATUS_VITORIA
		historico.append("Todas as criaturas foram derrotadas!")
		var invocacao_fim: Dictionary = estado.get("invocacao", {})
		invocacao_fim["ativa"] = false
		estado["invocacao"] = invocacao_fim
	else:
		var quantidade_vivos := vivos
		var protecao_pet_disponivel := bool(estado.get("invocacao", {}).get("protegendoMestre", false))
		for i in range(inimigos.size()):
			var inimigo: Dictionary = inimigos[i]
			if int(inimigo.get("vida", 0)) <= 0:
				continue
			var magico_inimigo := int(inimigo["poderMagico"]) > int(inimigo["ataque"]) and int(inimigo["mana"]) >= 5
			var ataque := int(inimigo["poderMagico"]) if magico_inimigo else int(inimigo["ataque"])
			var especial_grupo := _obter_ataque_especial_para_impacto(inimigo, historico)
			if bool(especial_grupo.get("preparando", false)):
				inimigo["ataqueEspecialPreparando"] = especial_grupo.duplicate(true)
				historico.append("%s prepara %s! Prepare-se para defender ou esquivar." % [inimigo["nome"], especial_grupo.get("nome", "um ataque especial")])
				inimigos[i] = inimigo
				continue
			ataque = maxi(1, int(round(float(ataque) * float(especial_grupo.get("multiplicador", 1.0)))))
			var defesa := int(round(float(jogador["defesa"]) * (0.5 if bool(jogador["defendendo"]) else 1.0)))
			var bonus_esquiva := 0.35 if bool(jogador["esquivando"]) else 0.0
			var resposta := _calcular_dano(ataque, defesa, int(jogador["agilidade"]), int(inimigo["agilidade"]), rng, bonus_esquiva)
			if protecao_pet_disponivel:
				resposta["dano"] = int(round(float(resposta["dano"]) * 0.70))
				protecao_pet_disponivel = false
				var invocacao_protetora_grupo: Dictionary = estado.get("invocacao", {})
				invocacao_protetora_grupo["protegendoMestre"] = false
				estado["invocacao"] = invocacao_protetora_grupo
				historico.append("O companheiro interceptou parte do golpe e reduziu o dano recebido.")
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
			var invocacao_fim_derrota: Dictionary = estado.get("invocacao", {})
			invocacao_fim_derrota["ativa"] = false
			estado["invocacao"] = invocacao_fim_derrota
	var alvo_atual_vivo := false
	for inimigo in inimigos:
		if int(inimigo.get("vida", 0)) > 0 and str(inimigo.get("id", "")) == str(estado.get("alvoSelecionadoId", "")):
			alvo_atual_vivo = true
			break
	if not alvo_atual_vivo:
		for inimigo in inimigos:
			if int(inimigo.get("vida", 0)) > 0:
				estado["alvoSelecionadoId"] = str(inimigo.get("id", ""))
				break
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

## Executa um padrão especial de criaturas geradas a cada segundo turno de resposta.
## O dano combina o multiplicador do golpe com a escala do rank, sem alterar a vida do chefe.
static func _obter_ataque_especial_para_impacto(inimigo: Dictionary, historico: Array) -> Dictionary:
	## Um ataque anunciado na rodada anterior chega agora, após a ação defensiva do jogador.
	if inimigo.has("ataqueEspecialPreparando"):
		var pendente: Dictionary = inimigo.get("ataqueEspecialPreparando", {}).duplicate(true)
		inimigo.erase("ataqueEspecialPreparando")
		historico.append("%s executa %s!" % [inimigo.get("nome", "A criatura"), pendente.get("nome", "o ataque especial")])
		return {"preparando": false, "multiplicador": float(pendente.get("multiplicador", 1.0)), "nome": str(pendente.get("nome", "ataque especial"))}
	var padroes: Array = inimigo.get("padroesAtaque", []) if inimigo.get("padroesAtaque", []) is Array else []
	if padroes.is_empty():
		return {"preparando": false, "multiplicador": 1.0}
	var turno := int(inimigo.get("turnoAtaqueEspecial", 0)) + 1
	inimigo["turnoAtaqueEspecial"] = turno
	if turno % 2 != 0:
		return {"preparando": false, "multiplicador": 1.0}
	var validos: Array = []
	for padrao in padroes:
		if padrao is Dictionary and not str(padrao.get("id", "")).is_empty():
			validos.append(padrao)
	if validos.is_empty():
		return {"preparando": false, "multiplicador": 1.0}
	var indice := posmod(int(inimigo.get("indicePadraoAtaque", 0)), validos.size())
	var padrao: Dictionary = validos[indice].duplicate(true)
	inimigo["indicePadraoAtaque"] = indice + 1
	var escala_rank := {"E":0.85,"D":0.95,"C":1.0,"B":1.08,"A":1.18,"S":1.32,"SS":1.5,"SSS":1.75}
	var rank := str(inimigo.get("rank", "E")).to_upper()
	var multiplicador := maxf(1.0, float(padrao.get("danoMultiplicador", 1.0))) * float(escala_rank.get(rank, 1.0))
	var aviso := str(padrao.get("aviso", ""))
	if not aviso.is_empty():
		historico.append(aviso)
	return {"preparando": true, "multiplicador": multiplicador, "nome": str(padrao.get("nome", "ataque especial")), "aviso": aviso, "id": str(padrao.get("id", ""))}

static func _calcular_dano(dano_base: int, defesa: int, agilidade_alvo: int, agilidade_atacante: int, rng: RandomNumberGenerator, bonus_esquiva: float = 0.0) -> Dictionary:
	var chance_esquiva := clampf(0.05 + float(agilidade_alvo) * 0.002 + bonus_esquiva, 0.0, 0.35)
	if rng.randf() < chance_esquiva:
		return {"dano":0,"esquivou":true,"critico":false}
	var chance_critico := clampf(0.05 + float(agilidade_atacante) * 0.002, 0.05, 0.25)
	var critico := rng.randf() < chance_critico
	var dano := maxi(1, int(round(float(dano_base) * (1.75 if critico else 1.0) - float(defesa) * 0.45)))
	return {"dano":dano,"esquivou":false,"critico":critico}


## Efeito curto do ataque normal, enviado somente após acerto confirmado pelo servidor.
static func _obter_efeito_ataque_arma(arma_id: String) -> Dictionary:
	var arma: Dictionary = CatalogoArmasOnePiece.obter(arma_id)
	if arma.is_empty():
		return {}
	var efeito := ""
	match arma_id:
		"gryphon", "ace":
			efeito = "haki_do_rei"
		"murakumogiri":
			efeito = "tremor"
		"yoru":
			efeito = "corte_negro"
		"kikoku":
			efeito = "energia_espacial"
		"enma":
			efeito = "haki_roxo"
		"shodai_kitetsu":
			efeito = "energia_carmesim"
		"tripla_katana":
			efeito = "corte_triplo"
		_:
			efeito = "corte"
	return {"armaId":arma_id,"nome":str(arma.get("nome", "Arma")),"efeito":efeito,"raridade":str(arma.get("raridade", "comum"))}
static func _buscar_habilidade(jogador: Dictionary, habilidade_id: String) -> Dictionary:
	if habilidade_id.is_empty():
		return {}
	var habilidades: Array = jogador.get("habilidades", [])
	for habilidade in habilidades:
		if habilidade is Dictionary and str(habilidade.get("id", "")) == habilidade_id:
			return habilidade.duplicate(true)
	return {}
