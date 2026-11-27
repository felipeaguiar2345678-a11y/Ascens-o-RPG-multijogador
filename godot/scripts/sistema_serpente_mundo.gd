extends RefCounted
class_name SistemaSerpenteMundo

## Regras puras da incursão mundial. O chamador deve ser exclusivamente o servidor.
## A cabeça é o único alvo; o corpo permanece como cenário e perigo ambiental.
const ID_CHEFE := "serpente_do_mundo"
const MULTIPLICADOR_VIDA_CHEFE_SERPENTE := 25
const VIDA_BASE_NORMAL_REFERENCIA := 80000
const VIDA_TOTAL_PADRAO := VIDA_BASE_NORMAL_REFERENCIA * MULTIPLICADOR_VIDA_CHEFE_SERPENTE
const RAIO_ARENA := 190.0
const LIMITE_PARTICIPANTES := 40
const INTERVALO_ACAO_MS := 1200
const INTERVALO_ATAQUE_MS := 12000
const TEMPO_RENASCIMENTO_SEGUNDOS := 1800
const TEMPO_RECUPERACAO_CENARIO_SEGUNDOS := 1800
const LIMITE_MARCAS_DESTRUICAO := 100
const TEMPO_DESAPARECIMENTO_MARCA_SEGUNDOS := 1800
const TEMPO_FADE_MARCA_SEGUNDOS := 300
const MAX_TENTATIVAS_FILHOTE := 3
const STATUS_DISPONIVEL := "disponivel"
const STATUS_EM_COMBATE := "em_combate"
const STATUS_DERROTADA := "derrotada"

## Normaliza serpentes geradas e atribui padrões de ataque coerentes com o habitat.
## Chefes serpentes recebem 25x a vida-base normal; a marca evita multiplicação duplicada.
static func preparar_criatura_gerada(criatura_original: Dictionary) -> Dictionary:
	var criatura := criatura_original.duplicate(true)
	var nome := str(criatura.get("nome", "")).to_lower()
	var familia := str(criatura.get("familiaCriatura", criatura.get("familia", criatura.get("tipoCriatura", criatura.get("tipo", ""))))).to_lower()
	var tags: Array = criatura.get("tags", []) if criatura.get("tags", []) is Array else []
	var eh_serpente := familia in ["serpente", "cobra", "víbora", "vibora", "naga"] or nome.contains("serpente") or nome.contains("cobra") or nome.contains("víbora") or nome.contains("vibora") or nome.contains("jormungandr") or tags.any(func(tag): return str(tag).to_lower() in ["serpente", "cobra", "naga"])
	if not eh_serpente:
		return criatura
	criatura["familiaCriatura"] = "serpente"
	var habitat := str(criatura.get("habitat", "")).to_lower()
	var bioma := str(criatura.get("bioma", "")).to_lower()
	var ataques: Array = criatura.get("padroesAtaque", []) if criatura.get("padroesAtaque", []) is Array else []
	var modelos := [
		{"id":"bote_serpentino","nome":"Bote serpentino","aviso":"A serpente recua e prepara uma investida veloz.","efeito":"investida","danoMultiplicador":1.35,"janelaReacaoSegundos":2.0},
		{"id":"constricao","nome":"Constrição","aviso":"A serpente ergue o corpo e tenta prender o alvo.","efeito":"imobilizacao","danoMultiplicador":1.15,"janelaReacaoSegundos":2.5},
		{"id":"golpe_cauda","nome":"Golpe de cauda","aviso":"A cauda começa a varrer a área.","efeito":"area","danoMultiplicador":1.25,"janelaReacaoSegundos":2.0}
	]
	if habitat.contains("mar") or habitat.contains("agua") or habitat.contains("água") or bioma.contains("oceano") or bioma.contains("mar"):
		modelos.append({"id":"onda_abissal","nome":"Onda abissal","aviso":"A serpente agita as águas antes de uma onda devastadora.","efeito":"onda_area","danoMultiplicador":1.6,"janelaReacaoSegundos":3.0})
	elif habitat.contains("subterr") or bioma.contains("caverna") or bioma.contains("montanha"):
		modelos.append({"id":"tremor_tectonico","nome":"Tremor tectônico","aviso":"O solo vibra; um impacto subterrâneo está chegando.","efeito":"tremor_area","danoMultiplicador":1.55,"janelaReacaoSegundos":3.0})
	else:
		modelos.append({"id":"sopro_elemental","nome":"Sopro elemental","aviso":"A serpente concentra uma energia devastadora. Saia da trajetória do sopro!","efeito":"sopro_area","danoMultiplicador":3.2,"janelaReacaoSegundos":3.5,"alcance":"area"})
	for modelo in modelos:
		var existe := false
		for ataque in ataques:
			if ataque is Dictionary and str(ataque.get("id", "")) == str(modelo.id):
				existe = true
				break
		if not existe:
			ataques.append(modelo)
	criatura["padroesAtaque"] = ataques.slice(0, 12)
	var eh_chefe := bool(criatura.get("chefe", false)) or bool(criatura.get("chefeMundial", false)) or str(criatura.get("categoria", "")).to_lower() == "chefe_mundial"
	if eh_chefe and not bool(criatura.get("escalaVidaSerpenteAplicada", false)):
		var vida_base := maxi(1, int(criatura.get("vidaBaseNormal", criatura.get("vidaMaxima", VIDA_BASE_NORMAL_REFERENCIA))))
		criatura["vidaBaseNormal"] = vida_base
		criatura["vidaMaxima"] = mini(2000000000, vida_base * MULTIPLICADOR_VIDA_CHEFE_SERPENTE)
		criatura["escalaVidaSerpente"] = MULTIPLICADOR_VIDA_CHEFE_SERPENTE
		criatura["escalaVidaSerpenteAplicada"] = true
		criatura["ataque"] = mini(2000000000, maxi(1, int(criatura.get("ataque", 1))) * 2)
		criatura["defesa"] = mini(2000000000, maxi(1, int(criatura.get("defesa", 1))) * 2)
	return criatura


const PADROES_ATAQUE_MUNDIAL := [
	{"id":"mordida_colossal","nome":"Mordida colossal","aviso":"JÖRMUNGANDR abre as mandíbulas! Prepare-se para a mordida!","danoMultiplicador":1.7,"janelaReacaoSegundos":3},
	{"id":"onda_marinha","nome":"Onda marinha","aviso":"O mar recua violentamente. Uma onda gigantesca está vindo!","danoMultiplicador":1.35,"janelaReacaoSegundos":3},
	{"id":"tremor_corporal","nome":"Tremor corporal","aviso":"O corpo colossal se move e o chão começa a rachar!","danoMultiplicador":1.5,"janelaReacaoSegundos":3},
	{"id":"sopro_primordial","nome":"Sopro primordial","aviso":"JÖRMUNGANDR concentra energia primordial! O sopro devastará toda a arena!","efeito":"sopro_elemental","danoMultiplicador":5.0,"janelaReacaoSegundos":4,"alcance":"area","destruirCenario":true}
]
static func iniciar_ataque_telegrafado(estado_original: Dictionary, indice: int) -> Dictionary:
	if str(estado_original.get("status", "")) != STATUS_EM_COMBATE or estado_original.has("ataquePreparando"):
		return estado_original.duplicate(true)
	var ataque: Dictionary = PADROES_ATAQUE_MUNDIAL[posmod(indice, PADROES_ATAQUE_MUNDIAL.size())].duplicate(true)
	var estado := estado_original.duplicate(true)
	ataque["impactoUnix"] = int(Time.get_unix_time_from_system()) + int(ataque.get("janelaReacaoSegundos", 3))
	estado["ataquePreparando"] = ataque
	estado["ultimoAtaque"] = str(ataque.get("aviso", "A serpente prepara um ataque!"))
	return estado
static func calcular_dano_ataque(perfil: Dictionary, ataque: Dictionary, defesa: String) -> int:
	var base := calcular_dano_serpente(perfil)
	var multiplicador := maxf(1.0, float(ataque.get("danoMultiplicador", 1.0)))
	var reducao := 1.0
	if defesa == "defender":
		reducao = 0.35
	elif defesa == "esquivar":
		reducao = 0.15
	return maxi(1, roundi(float(base) * multiplicador * reducao))

static func criar_estado(vida_total: int = VIDA_TOTAL_PADRAO) -> Dictionary:
	if vida_total < 1 or vida_total > 2000000000:
		return {}
	return {
		"versao": 2, "chefeId": ID_CHEFE, "status": STATUS_DISPONIVEL,
		"vida": vida_total, "vidaMaxima": vida_total, "participantes": {},
		"tentativasDomesticacao": {}, "criadaUnix": int(Time.get_unix_time_from_system()),
		"derrotadaUnix": 0, "proximoRenascimentoUnix": 0, "ciclos": 1,
		"totalDerrotas": 0, "ultimoAtaque": "A Serpente observa a arena.",
		"ultimoAtaqueUnix": 0, "serpenteOriginalPreservada": true, "indiceAtaque": 0, "defesasPreparadas": {}, "cenarioDevastado": false, "ultimaDevastacaoUnix": 0, "zonaDevastada": {}
	}

static func entrar(estado_original: Dictionary, uid: String, peer_id: int, posicao: Vector2, posicao_cabeca: Vector2, nome: String = "Aventureiro") -> Dictionary:
	if estado_original.is_empty() or str(estado_original.get("status", "")) not in [STATUS_DISPONIVEL, STATUS_EM_COMBATE]:
		return {"ok": false, "erro": "A incursão não está aceitando participantes."}
	if uid.strip_edges().is_empty() or uid.length() > 128 or peer_id <= 0:
		return {"ok": false, "erro": "Identidade de participante inválida."}
	if posicao.distance_to(posicao_cabeca) > RAIO_ARENA:
		return {"ok": false, "erro": "Aproxime-se da cabeça da Serpente do Mundo para entrar na arena."}
	var estado := estado_original.duplicate(true)
	var participantes: Dictionary = estado.get("participantes", {})
	if participantes.has(uid):
		var existente: Dictionary = participantes[uid]
		if int(existente.get("peerId", -1)) != peer_id and bool(existente.get("ativo", true)):
			return {"ok": false, "erro": "Esta conta já está participando da incursão."}
		existente["peerId"] = peer_id
		existente["nome"] = nome.strip_edges().substr(0, 40) if not nome.strip_edges().is_empty() else "Aventureiro"
		existente["ativo"] = true
		participantes[uid] = existente
		estado["participantes"] = participantes
		return {"ok": true, "estado": estado, "jaParticipava": true}
	if participantes.size() >= LIMITE_PARTICIPANTES:
		return {"ok": false, "erro": "A arena atingiu o limite de participantes."}
	participantes[uid] = {"peerId": peer_id, "nome": nome.strip_edges().substr(0, 40) if not nome.strip_edges().is_empty() else "Aventureiro", "danoTotal": 0, "percentualDano": 0.0, "nomeVerde": false, "entrouUnix": int(Time.get_unix_time_from_system()), "ultimaAcaoMs": -INTERVALO_ACAO_MS, "ativo": true}
	estado["participantes"] = participantes
	estado["status"] = STATUS_EM_COMBATE
	return {"ok": true, "estado": estado, "jaParticipava": false}

static func calcular_dano_jogador(perfil: Dictionary, acao: String) -> int:
	if acao == "ataque":
		return clampi(12 + int(perfil.get("forca", 5)) * 3, 1, 250000)
	if acao == "magia":
		return clampi(10 + int(perfil.get("inteligencia", 5)) * 3 + int(perfil.get("espirito", 5)), 1, 250000)
	return 0

static func calcular_dano_serpente(perfil: Dictionary) -> int:
	var vida_maxima := maxi(1, int(perfil.get("vidaMaxima", 100)))
	var vitalidade := maxi(0, int(perfil.get("vitalidade", 5)))
	var dano_bruto := maxi(8, int(round(float(vida_maxima) * 0.12)))
	return maxi(5, dano_bruto - mini(dano_bruto - 5, vitalidade))

static func aplicar_ataque(estado_original: Dictionary, uid: String, peer_id: int, perfil_servidor: Dictionary, acao: String, agora_ms: int) -> Dictionary:
	if estado_original.is_empty() or str(estado_original.get("status", "")) != STATUS_EM_COMBATE:
		return {"ok": false, "erro": "A Serpente do Mundo não está em combate."}
	var estado := estado_original.duplicate(true)
	var participantes: Dictionary = estado.get("participantes", {})
	if not participantes.has(uid):
		return {"ok": false, "erro": "Você não está participando desta incursão."}
	var participante: Dictionary = participantes[uid]
	if int(participante.get("peerId", -1)) != peer_id or not bool(participante.get("ativo", false)):
		return {"ok": false, "erro": "Participante não autorizado."}
	var ultima_acao := int(participante.get("ultimaAcaoMs", -INTERVALO_ACAO_MS))
	if agora_ms - ultima_acao < INTERVALO_ACAO_MS:
		return {"ok": false, "erro": "Aguarde antes de atacar novamente."}
	var dano := calcular_dano_jogador(perfil_servidor, acao)
	if dano <= 0:
		return {"ok": false, "erro": "Ação inválida contra a Serpente do Mundo."}
	var vida_anterior := int(estado.get("vida", 0))
	var dano_aplicado := mini(vida_anterior, dano)
	estado["vida"] = maxi(0, vida_anterior - dano_aplicado)
	participante["danoTotal"] = int(participante.get("danoTotal", 0)) + dano_aplicado
	var vida_maxima_chefe := maxi(1, int(estado.get("vidaMaxima", 1)))
	participante["percentualDano"] = snappedf(float(participante["danoTotal"]) * 100.0 / float(vida_maxima_chefe), 0.01)
	participante["nomeVerde"] = int(participante["danoTotal"]) * 10 >= vida_maxima_chefe
	participante["ultimaAcaoMs"] = agora_ms
	participantes[uid] = participante
	estado["participantes"] = participantes
	if int(estado["vida"]) <= 0:
		estado["status"] = STATUS_DERROTADA
		estado["derrotadaUnix"] = int(Time.get_unix_time_from_system())
		estado["proximoRenascimentoUnix"] = int(estado["derrotadaUnix"]) + TEMPO_RENASCIMENTO_SEGUNDOS
		estado["totalDerrotas"] = int(estado.get("totalDerrotas", 0)) + 1
		estado["ultimoAtaque"] = "A Serpente do Mundo foi derrotada. Seu corpo permanece no mundo."
		estado["serpenteOriginalPreservada"] = true
	return {"ok": true, "estado": estado, "dano": dano_aplicado, "derrotada": str(estado.get("status", "")) == STATUS_DERROTADA}

static func marcar_desconectado(estado_original: Dictionary, uid: String, peer_id: int) -> Dictionary:
	if estado_original.is_empty():
		return estado_original
	var estado := estado_original.duplicate(true)
	var participantes: Dictionary = estado.get("participantes", {})
	if not participantes.has(uid):
		return estado
	var participante: Dictionary = participantes[uid]
	if int(participante.get("peerId", -1)) == peer_id:
		participante["ativo"] = false
		participantes[uid] = participante
		estado["participantes"] = participantes
	return estado

static func registrar_tentativa_filhote(estado_original: Dictionary, uid: String) -> Dictionary:
	if estado_original.is_empty() or str(estado_original.get("status", "")) != STATUS_DERROTADA:
		return {"ok": false, "erro": "A Serpente do Mundo precisa ser derrotada primeiro."}
	var participantes: Dictionary = estado_original.get("participantes", {})
	if not participantes.has(uid) or int(participantes[uid].get("danoTotal", 0)) <= 0:
		return {"ok": false, "erro": "Somente quem participou da batalha e causou dano pode tentar obter o filhote."}
	var estado := estado_original.duplicate(true)
	var tentativas: Dictionary = estado.get("tentativasDomesticacao", {})
	var usadas := int(tentativas.get(uid, 0))
	if usadas >= MAX_TENTATIVAS_FILHOTE:
		return {"ok": false, "erro": "Você já usou as três tentativas para este ciclo da Serpente do Mundo.", "restantes": 0}
	usadas += 1
	tentativas[uid] = usadas
	estado["tentativasDomesticacao"] = tentativas
	return {"ok": true, "estado": estado, "tentativa": usadas, "restantes": MAX_TENTATIVAS_FILHOTE - usadas}

static func verificar_renascimento(estado_original: Dictionary, agora_unix: int) -> Dictionary:
	if estado_original.is_empty() or str(estado_original.get("status", "")) != STATUS_DERROTADA:
		return estado_original
	var renascimento := int(estado_original.get("proximoRenascimentoUnix", 0))
	if renascimento <= 0 or agora_unix < renascimento:
		return estado_original
	var novo := criar_estado(int(estado_original.get("vidaMaxima", VIDA_TOTAL_PADRAO)))
	novo["ciclos"] = int(estado_original.get("ciclos", 1)) + 1
	novo["totalDerrotas"] = int(estado_original.get("totalDerrotas", 1))
	novo["ultimaDerrotaUnix"] = int(estado_original.get("derrotadaUnix", 0))
	novo["ultimoAtaque"] = "A Serpente do Mundo retornou. A cabeça voltou a ameaçar a arena."
	return novo

## Registra cicatriz visual no estado autoritativo compartilhado. Não altera atributos nem colisões.
## Converte um especial destrutivo de qualquer chefe em uma cicatriz visual do mundo.
static func obter_configuracao_marca_chefe(criatura: Dictionary, evento: String) -> Dictionary:
	var eh_chefe := bool(criatura.get("chefe", false)) or bool(criatura.get("chefeMundial", false)) or str(criatura.get("categoria", "")).to_lower() == "chefe_mundial"
	if not eh_chefe:
		return {}
	var texto := evento.to_lower()
	if not texto.contains(" executa "):
		return {}
	var nome_chefe := str(criatura.get("nome", "")).to_lower()
	if nome_chefe.is_empty() or not texto.begins_with(nome_chefe + " executa "):
		return {}
	var padrao_encontrado: Dictionary = {}
	var padroes: Array = criatura.get("padroesAtaque", []) if criatura.get("padroesAtaque", []) is Array else []
	for padrao in padroes:
		if not (padrao is Dictionary):
			continue
		var nome_ataque := str(padrao.get("nome", "")).to_lower()
		if not nome_ataque.is_empty() and texto.contains(nome_ataque):
			padrao_encontrado = padrao
			break
	var efeito := str(padrao_encontrado.get("efeito", "")).to_lower()
	var id_ataque := str(padrao_encontrado.get("id", "")).to_lower()
	var palavras_destrutivas := ["sopro", "tremor", "onda", "terremoto", "avalanche", "meteoro", "explos", "tsunami", "furacao", "furacão", "lava", "impacto_colossal"]
	var destrutivo := bool(padrao_encontrado.get("destruirCenario", false)) or bool(padrao_encontrado.get("destruirAmbiente", false))
	destrutivo = destrutivo or efeito in ["sopro_area", "tremor_area", "onda_area", "explosao_area", "impacto_area", "devastacao"]
	for palavra in palavras_destrutivas:
		if id_ataque.contains(palavra) or str(padrao_encontrado.get("nome", "")).to_lower().contains(palavra):
			destrutivo = true
			break
	if not destrutivo:
		return {}
	var elemento := str(padrao_encontrado.get("elemento", criatura.get("elemento", criatura.get("elementoDominante", "terra")))).to_lower()
	var tipo := "cratera"
	if efeito.contains("sopro") or id_ataque.contains("sopro"):
		tipo = "cratera_queimada" if elemento in ["fogo", "lava", "primordial"] else "cratera_elemental"
	elif efeito.contains("tremor") or id_ataque.contains("tremor") or id_ataque.contains("terremoto"):
		tipo = "fissura_tectonica"
	elif efeito.contains("onda") or id_ataque.contains("onda") or id_ataque.contains("tsunami"):
		tipo = "cicatriz_alagada"
	elif elemento == "gelo":
		tipo = "solo_congelado"
	elif elemento == "raio":
		tipo = "solo_eletrificado"
	var rank := str(criatura.get("rank", "E")).to_upper()
	var escala_rank := {"E":0.75,"D":0.82,"C":0.9,"B":1.0,"A":1.1,"S":1.2,"SS":1.35,"SSS":1.5}
	var intensidade := float(escala_rank.get(rank, 1.0))
	return {
		"tipo": tipo, "elemento": elemento,
		"raio": 90.0 + 70.0 * intensidade,
		"intensidade": clampf(intensidade, 0.1, 1.0),
		"origem": str(criatura.get("id", "chefe"))
	}

static func registrar_marca_destruicao(estado_original: Dictionary, dados: Dictionary, agora_unix: int) -> Dictionary:
	if estado_original.is_empty() or agora_unix <= 0:
		return estado_original.duplicate(true)
	var x := float(dados.get("x", -1.0))
	var y := float(dados.get("y", -1.0))
	var raio := clampf(float(dados.get("raio", 0.0)), 12.0, 900.0)
	var tipo := str(dados.get("tipo", "cratera")).strip_edges()
	if x < 0.0 or y < 0.0 or x > 2400.0 or y > 2400.0 or tipo.is_empty():
		return estado_original.duplicate(true)
	var estado := estado_original.duplicate(true)
	var marcas: Array = estado.get("marcasDestruicao", []) if estado.get("marcasDestruicao", []) is Array else []
	var ativas: Array = []
	for marca in marcas:
		if marca is Dictionary and int(marca.get("expiraUnix", 0)) > agora_unix:
			ativas.append(marca.duplicate(true))
	var id := "%s_%d_%d" % [str(dados.get("origem", "chefe")), agora_unix, ativas.size()]
	ativas.append({
		"id": id, "x": x, "y": y, "raio": raio, "tipo": tipo,
		"elemento": str(dados.get("elemento", "terra")),
		"intensidade": clampf(float(dados.get("intensidade", 1.0)), 0.1, 1.0),
		"criadoUnix": agora_unix,
		"expiraUnix": agora_unix + TEMPO_DESAPARECIMENTO_MARCA_SEGUNDOS,
		"origem": str(dados.get("origem", "chefe"))
	})
	while ativas.size() > LIMITE_MARCAS_DESTRUICAO:
		ativas.pop_front()
	estado["marcasDestruicao"] = ativas
	return estado

static func obter_marcas_destruicao_ativas(estado: Dictionary, agora_unix: int) -> Array:
	var resultado: Array = []
	var marcas: Array = estado.get("marcasDestruicao", []) if estado.get("marcasDestruicao", []) is Array else []
	for marca in marcas:
		if marca is Dictionary and int(marca.get("expiraUnix", 0)) > agora_unix:
			resultado.append(marca.duplicate(true))
	return resultado

## Conclui a recuperação ambiental usando o prazo absoluto persistido.
## Também remove marcas expiradas do estado, para que o snapshot global não preserve
## a indicação visual de devastação depois que a colisão já foi restaurada.
static func recuperar_cenario(estado_original: Dictionary, agora_unix: int) -> Dictionary:
	if estado_original.is_empty() or agora_unix <= 0:
		return estado_original
	var zona: Dictionary = estado_original.get("zonaDevastada", {})
	var recuperacao_unix := int(zona.get("recuperacaoUnix", 0))
	var zona_expirada := not zona.is_empty() and recuperacao_unix > 0 and agora_unix >= recuperacao_unix
	var marcas_ativas := obter_marcas_destruicao_ativas(estado_original, agora_unix)
	var marcas_originais: Array = estado_original.get("marcasDestruicao", []) if estado_original.get("marcasDestruicao", []) is Array else []
	var marcas_expiraram := marcas_ativas.size() != marcas_originais.size()
	if not zona_expirada and not marcas_expiraram:
		return estado_original
	var estado := estado_original.duplicate(true)
	if zona_expirada:
		estado["zonaDevastada"] = {}
		estado["cenarioDevastado"] = false
	estado["marcasDestruicao"] = marcas_ativas
	estado["atualizadoUnix"] = agora_unix
	return estado

## Única representação pública da Serpente no mundo compartilhado.
## Salas diferentes recebem o mesmo estado autoritativo, sem IDs privados.
static func obter_snapshot_global(estado: Dictionary, mundo_id: String) -> Dictionary:
	if estado.is_empty() or mundo_id.strip_edges().is_empty():
		return {}
	var snapshot := obter_estado_publico(estado)
	snapshot["mundoId"] = mundo_id.strip_edges()
	snapshot["escopo"] = "global"
	return snapshot

static func obter_estado_publico(estado: Dictionary) -> Dictionary:
	var agora := int(Time.get_unix_time_from_system())
	var renascimento := int(estado.get("proximoRenascimentoUnix", 0))
	return {
		"chefeId": str(estado.get("chefeId", ID_CHEFE)),
		"status": str(estado.get("status", STATUS_DISPONIVEL)),
		"revisaoSincronizacao": int(estado.get("revisaoSincronizacao", 0)),
		"atualizadoUnix": int(estado.get("atualizadoUnix", 0)),
		"vida": int(estado.get("vida", 0)),
		"vidaMaxima": int(estado.get("vidaMaxima", 0)),
		"participantes": int(estado.get("participantes", {}).size()),
		"serpenteOriginalPreservada": bool(estado.get("serpenteOriginalPreservada", true)),
		"ultimoAtaque": str(estado.get("ultimoAtaque", "")),
		"ciclos": int(estado.get("ciclos", 1)),
		"totalDerrotas": int(estado.get("totalDerrotas", 0)),
		"renascimentoRestante": maxi(0, renascimento - agora) if str(estado.get("status", "")) == STATUS_DERROTADA else 0,
		"renascimentoUnix": renascimento,
		"ataquePreparando": estado.get("ataquePreparando", {}).duplicate(true),
		"cenarioDevastado": bool(estado.get("cenarioDevastado", false)),
		"ultimaDevastacaoUnix": int(estado.get("ultimaDevastacaoUnix", 0)),
		"zonaDevastada": estado.get("zonaDevastada", {}).duplicate(true),
		"marcasDestruicao": obter_marcas_destruicao_ativas(estado, agora)
	}
