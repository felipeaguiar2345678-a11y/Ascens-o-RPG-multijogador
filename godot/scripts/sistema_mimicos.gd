extends RefCounted
class_name SistemaMimicos

## Regras puras dos mímicos. Chamadas de sorteio/recompensa devem ocorrer no servidor.
const CHANCES_APARICAO := {
	"comum": 0.05,
	"raro": 0.03,
	"lendario": 0.01,
	"mitico": 0.01
}
const RARIDADES_ARMAS := ["comum", "rara", "lendaria", "mitica", "suprema"]
const LIMITES_PIEDADE := {"lendaria": 50, "mitica": 100, "suprema": 200}
const CHANCES_DROP := {
	"comum": {"comum": 0.55, "rara": 0.30, "lendaria": 0.13, "mitica": 0.018, "suprema": 0.002},
	"raro": {"comum": 0.30, "rara": 0.35, "lendaria": 0.25, "mitica": 0.08, "suprema": 0.02},
	"lendario": {"comum": 0.15, "rara": 0.30, "lendaria": 0.35, "mitica": 0.17, "suprema": 0.03},
	"mitico": {"comum": 0.05, "rara": 0.20, "lendaria": 0.35, "mitica": 0.25, "suprema": 0.15}
}
const PERFIS_MIMICO := {
	"comum": {"vida": 90, "ataque": 12, "defesa": 4, "agilidade": 5, "perigo": 15, "fases": 1, "armadilha": false, "invoca": false},
	"raro": {"vida": 220, "ataque": 24, "defesa": 12, "agilidade": 12, "perigo": 35, "fases": 1, "armadilha": true, "invoca": false},
	"lendario": {"vida": 650, "ataque": 48, "defesa": 30, "agilidade": 24, "perigo": 70, "fases": 2, "armadilha": true, "invoca": true},
	"mitico": {"vida": 1800, "ataque": 85, "defesa": 55, "agilidade": 40, "perigo": 100, "fases": 3, "armadilha": true, "invoca": true}
}

static func sortear_aparicao(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente if semente != 0 else 1
	var rolagem := rng.randf()
	var acumulado := 0.0
	for tipo in ["comum", "raro", "lendario", "mitico"]:
		acumulado += float(CHANCES_APARICAO[tipo])
		if rolagem < acumulado:
			return {"aparece": true, "tipo": tipo, "rolagem": rolagem}
	return {"aparece": false, "tipo": "", "rolagem": rolagem}

static func validar_tipo(tipo: String) -> bool:
	return PERFIS_MIMICO.has(tipo.strip_edges().to_lower())

static func criar_mimico(tipo: String, id_encontro: String, bioma: String, semente: int) -> Dictionary:
	var chave := tipo.strip_edges().to_lower()
	if not validar_tipo(chave) or id_encontro.strip_edges().is_empty() or bioma.strip_edges().is_empty():
		return {}
	var dados: Dictionary = PERFIS_MIMICO[chave].duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente if semente != 0 else 1
	var pistas := rng.randf() < 0.55
	var criatura := {
		"id": "mimico_" + chave,
		"individuoId": id_encontro,
		"nome": "Mímico " + chave.capitalize(),
		"raridade": chave,
		"rank": "SSS" if chave == "mitico" else "SS" if chave == "lendario" else "A" if chave == "raro" else "C",
		"bioma": bioma,
		"chefe": chave in ["lendario", "mitico"],
		"vida": int(dados["vida"]),
		"vidaMaxima": int(dados["vida"]),
		"ataque": int(dados["ataque"]),
		"defesa": int(dados["defesa"]),
		"agilidade": int(dados["agilidade"]),
		"perigo": int(dados["perigo"]),
		"fases": int(dados["fases"]),
		"armadilha": bool(dados["armadilha"]),
		"invoca": bool(dados["invoca"]),
		"pistasVisuais": pistas,
		"estadoInicial": "disfarcado",
		"encontroId": id_encontro,
		"servidorAutoritativo": true,
		"tabelaDrops": []
	}
	return criatura

## Define se o baú dá pistas, aguarda, embosca ou persegue. Sem estado do jogador não há ataque automático.
static func decidir_comportamento(mimico: Dictionary, contexto: Dictionary, semente: int) -> Dictionary:
	var tipo := str(mimico.get("raridade", "comum")).to_lower()
	if not validar_tipo(tipo):
		return {}
	var interagiu := bool(contexto.get("jogadorInteragiu", false))
	var detectou := bool(contexto.get("jogadorDetectouSinais", false))
	var distancia := maxf(0.0, float(contexto.get("distanciaJogador", INF)))
	var vida_percentual := clampf(float(contexto.get("vidaPercentual", 1.0)), 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente if semente != 0 else 1
	if not interagiu and not detectou:
		return {"acao": "disfarcar", "estado": "disfarcado", "pistas": bool(mimico.get("pistasVisuais", false))}
	if detectou and not interagiu:
		return {"acao": "observar", "estado": "alerta", "pistas": true}
	if interagiu and distancia <= 90.0:
		return {"acao": "emboscar" if rng.randf() < 0.7 else "revelar", "estado": "revelado", "iniciaCombate": true}
	if vida_percentual <= 0.25 and tipo in ["lendario", "mitico"]:
		return {"acao": "fugir", "estado": "fugindo", "iniciaCombate": false}
	return {"acao": "perseguir", "estado": "agressivo", "iniciaCombate": true}

## Adapta o mímico ao motor de combate existente; ataques especiais são dados, não novos botões.
static func preparar_inimigo_combate(mimico: Dictionary) -> Dictionary:
	if mimico.is_empty() or not validar_tipo(str(mimico.get("raridade", ""))):
		return {}
	var inimigo := mimico.duplicate(true)
	var tipo := str(mimico.get("raridade", "comum"))
	var padroes := [{"id": "mordida", "nome": "Mordida de Baú", "multiplicadorDano": 1.0, "status": "sangramento", "chanceStatus": 0.08}]
	if tipo == "raro":
		padroes.append({"id": "lingua_aco", "nome": "Língua de Aço", "multiplicadorDano": 1.25, "status": "lentidao", "chanceStatus": 0.15})
	elif tipo == "lendario":
		padroes.append({"id": "mandibula_esmagadora", "nome": "Mandíbula Esmagadora", "multiplicadorDano": 1.55, "status": "atordoamento", "chanceStatus": 0.18})
		padroes.append({"id": "armadilha", "nome": "Armadilha de Tesouro", "multiplicadorDano": 0.8, "status": "imobilizado", "chanceStatus": 0.25})
	elif tipo == "mitico":
		padroes.append({"id": "devorar", "nome": "Devorar", "multiplicadorDano": 1.8, "status": "sangramento", "chanceStatus": 0.25})
		padroes.append({"id": "chuva_de_ouro", "nome": "Chuva de Fragmentos", "multiplicadorDano": 1.35, "status": "atordoamento", "chanceStatus": 0.20})
		padroes.append({"id": "invocar_mimicos", "nome": "Ninhada Faminta", "multiplicadorDano": 0.7, "status": "pressao", "chanceStatus": 0.0})
	inimigo["padroesAtaque"] = padroes
	inimigo["fasesCombate"] = int(mimico.get("fases", 1))
	inimigo["faseAtual"] = 1
	inimigo["trocaFaseVidaPercentual"] = 0.5
	inimigo["estiloCombate"] = "chefe_mimico" if tipo in ["lendario", "mitico"] else "emboscador"
	return inimigo

static func criar_piedade_vazia() -> Dictionary:
	return {"contadores": {"lendaria": 0, "mitica": 0, "suprema": 0}, "encontrosProcessados": []}

## Cada vitória incrementa os três contadores. Uma recompensa reseta somente a raridade obtida.
## Se mais de um marco estiver pendente, a prioridade é Suprema > Mítica > Lendária (uma arma por encontro).
static func resolver_recompensa(tipo_mimico: String, catalogo_armas: Array, piedade_original: Dictionary, id_encontro: String, semente: int) -> Dictionary:
	var tipo := tipo_mimico.strip_edges().to_lower()
	if not validar_tipo(tipo) or catalogo_armas.is_empty() or id_encontro.strip_edges().is_empty():
		return {"ok": false, "erro": "Dados de recompensa do mímico inválidos."}
	var piedade := piedade_original.duplicate(true) if not piedade_original.is_empty() else criar_piedade_vazia()
	var processados: Array = piedade.get("encontrosProcessados", [])
	if processados.has(id_encontro):
		var pendentes: Dictionary = piedade.get("recompensasPendentes", {})
		var arma_pendente: Dictionary = pendentes.get(id_encontro, {})
		return {"ok": true, "duplicado": true, "entregaPendente": not arma_pendente.is_empty(), "arma": arma_pendente.duplicate(true), "piedade": piedade}
	var contadores: Dictionary = piedade.get("contadores", {}).duplicate(true)
	for raridade in LIMITES_PIEDADE.keys():
		contadores[raridade] = maxi(0, int(contadores.get(raridade, 0))) + 1
	var pesos: Dictionary = CHANCES_DROP[tipo].duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente if semente != 0 else 1
	var raridade_garantida := ""
	for raridade in ["suprema", "mitica", "lendaria"]:
		if int(contadores.get(raridade, 0)) >= int(LIMITES_PIEDADE[raridade]):
			raridade_garantida = raridade
			break
	var raridade_escolhida := raridade_garantida
	if raridade_escolhida.is_empty():
		raridade_escolhida = _sortear_raridade_disponivel(pesos, catalogo_armas, rng)
	if raridade_escolhida.is_empty():
		return {"ok": false, "erro": "Não há armas válidas no catálogo para este drop."}
	var candidatas: Array = []
	for arma in catalogo_armas:
		if not (arma is Dictionary):
			continue
		var id_arma := str(arma.get("id", "")).strip_edges().to_lower()
		var raridade_arma := str(arma.get("raridade", "")).strip_edges().to_lower()
		if raridade_arma == raridade_escolhida and not _eh_tripla_katana(id_arma, arma):
			candidatas.append(arma)
	if candidatas.is_empty():
		return {"ok": false, "erro": "Não há armas %s disponíveis; piedade preservada." % raridade_escolhida}
	var arma_escolhida: Dictionary = candidatas[rng.randi_range(0, candidatas.size() - 1)].duplicate(true)
	contadores[raridade_escolhida] = 0
	piedade["contadores"] = contadores
	processados.append(id_encontro)
	while processados.size() > 2000:
		processados.pop_front()
	piedade["encontrosProcessados"] = processados
	var pendentes: Dictionary = piedade.get("recompensasPendentes", {}).duplicate(true)
	pendentes[id_encontro] = arma_escolhida.duplicate(true)
	piedade["recompensasPendentes"] = pendentes
	return {
		"ok": true, "duplicado": false, "arma": arma_escolhida,
		"raridade": raridade_escolhida, "garantida": not raridade_garantida.is_empty(),
		"contadorPiedade": contadores.duplicate(true), "piedade": piedade,
		"tipoMimico": tipo, "quantidadeArmas": 1
	}

static func _sortear_raridade_disponivel(pesos: Dictionary, catalogo: Array, rng: RandomNumberGenerator) -> String:
	var disponiveis: Array = []
	var peso_total := 0.0
	for raridade in RARIDADES_ARMAS:
		var tem_arma := false
		for arma in catalogo:
			if arma is Dictionary and str(arma.get("raridade", "")).to_lower() == raridade and not _eh_tripla_katana(str(arma.get("id", "")).to_lower(), arma):
				tem_arma = true
				break
		var peso := float(pesos.get(raridade, 0.0))
		if tem_arma and peso > 0.0:
			disponiveis.append({"raridade": raridade, "peso": peso})
			peso_total += peso
	if peso_total <= 0.0:
		return ""
	var rolagem := rng.randf() * peso_total
	for entrada in disponiveis:
		rolagem -= float(entrada["peso"])
		if rolagem < 0.0:
			return str(entrada["raridade"])
	return str(disponiveis.back()["raridade"])

static func _eh_tripla_katana(id_arma: String, arma: Dictionary) -> bool:
	var id := id_arma.to_lower()
	var nome := str(arma.get("nome", "")).to_lower()
	return id.contains("tripla_katana") or nome.contains("tripla katana")

static func validar_piedade(piedade: Dictionary) -> bool:
	var contadores: Dictionary = piedade.get("contadores", {})
	for raridade in LIMITES_PIEDADE:
		var valor := int(contadores.get(raridade, 0))
		if valor < 0 or valor >= int(LIMITES_PIEDADE[raridade]):
			return false
	return true
