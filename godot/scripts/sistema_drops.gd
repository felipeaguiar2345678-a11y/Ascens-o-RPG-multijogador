extends RefCounted
class_name SistemaDrops

const MULTIPLICADOR_CHANCE_DROP_NOTURNO := 1.5
const MULTIPLICADOR_QUANTIDADE_DROP_NOTURNO := 1.25

## Motor genérico de recompensas. Não contém inimigos prontos:
## cada criatura gerada pela IA fornece sua própria tabelaDrops.
const RARIDADES := ["comum", "incomum", "raro", "epico", "lendario", "mitico", "divino", "transcendente", "unico"]
const SISTEMA_LIDER_NATO = preload("res://scripts/sistema_lider_nato.gd")
const MULTIPLICADOR_RARIDADE := {
	"comum": 1.0, "incomum": 0.72, "raro": 0.42, "epico": 0.20,
	"lendario": 0.085, "mitico": 0.035, "divino": 0.012,
	"transcendente": 0.003, "unico": 0.0005
}

static func resolver_tabela(tabela: Array, origem_id: String, contexto: Dictionary = {}) -> Array:
	if tabela.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	var semente := int(contexto.get("semente", -1))
	if semente >= 0:
		rng.seed = semente
	else:
		rng.randomize()
	var resultados: Array = []
	var lider_nato := bool(contexto.get("liderNato", false))
	var multiplicador_chance := SISTEMA_LIDER_NATO.MULTIPLICADOR_CHANCE_DROPS if lider_nato else 1.0
	var multiplicador_quantidade := SISTEMA_LIDER_NATO.MULTIPLICADOR_QUANTIDADE_DROPS if lider_nato else 1.0
	var periodo := str(contexto.get("periodo", "dia"))
	var noturno := preload("res://scripts/sistema_ciclo_noturno.gd").esta_no_periodo_noturno(periodo)
	for entrada in tabela:
		if not (entrada is Dictionary):
			continue
		var disponibilidade := str(entrada.get("periodoDisponibilidade", "qualquer")).to_lower()
		if disponibilidade in ["noturno", "noite"] and not noturno:
			continue
		if disponibilidade in ["diurno", "dia"] and not noturno:
			pass
		elif disponibilidade in ["diurno", "dia"] and noturno:
			continue
		var item_id := str(entrada.get("itemId", "")).strip_edges()
		if item_id.is_empty():
			continue
		var chance := clampf(float(entrada.get("chance", 0.0)), 0.0, 1.0)
		var raridade := str(entrada.get("raridade", "comum")).to_lower()
		if not RARIDADES.has(raridade):
			continue
		var chance_final := chance
		if not bool(entrada.get("ignorarMultiplicadorRaridade", false)):
			chance_final *= float(MULTIPLICADOR_RARIDADE[raridade])
		chance_final *= _multiplicador_condicao(entrada, contexto)
		if noturno:
			chance_final *= MULTIPLICADOR_CHANCE_DROP_NOTURNO
		chance_final *= multiplicador_chance
		chance_final = clampf(chance_final, 0.0, 1.0)
		var obtido := rng.randf() < chance_final
		var quantidade := 0
		if obtido:
			var minimo := maxi(1, int(entrada.get("quantidadeMinima", 1)))
			var maximo := clampi(int(entrada.get("quantidadeMaxima", minimo)), minimo, 999)
			quantidade = rng.randi_range(minimo, maximo)
			quantidade = maxi(1, roundi(float(quantidade) * multiplicador_quantidade * (MULTIPLICADOR_QUANTIDADE_DROP_NOTURNO if noturno else 1.0)))
		resultados.append({
			"itemId": item_id,
			"nome": str(entrada.get("nome", item_id)),
			"categoria": str(entrada.get("categoria", "material")),
			"raridade": raridade,
			"quantidade": quantidade,
			"chanceFinal": chance_final,
			"obtido": obtido,
			"resultadoVisual": "sucesso" if obtido else "falha",
			"origemCriaturaId": origem_id,
			"descoberta": bool(entrada.get("descoberta", false)),
			"origemLiderNato": lider_nato,
			"modeloCompanheiro": entrada.get("modeloCompanheiro", {}),
			"denominacaoMoeda": str(entrada.get("denominacaoMoeda", ""))
		})
	return resultados


## Chances-base de ovos por rank: E 5%, D 4%, C 3%, B/A 2%, S+ 1%.
## O ovo herda aparência, habilidades e atributos da criatura de origem.
static func criar_entrada_ovo(criatura: Dictionary) -> Dictionary:
	var ranks := ["E", "D", "C", "B", "A", "S", "SS", "SSS"]
	var rank := str(criatura.get("rank", "E")).to_upper()
	if not ranks.has(rank):
		return {}
	var chances := {"E":0.05, "D":0.04, "C":0.03, "B":0.02, "A":0.02, "S":0.01, "SS":0.01, "SSS":0.01}
	var criatura_id := str(criatura.get("id", "")).strip_edges()
	var nome := str(criatura.get("nome", "Criatura desconhecida")).strip_edges()
	if criatura_id.is_empty() or nome.is_empty():
		return {}
	var raridade := str(criatura.get("raridade", "comum")).to_lower()
	if not RARIDADES.has(raridade):
		raridade = "comum"
	var vida := maxi(10, int(criatura.get("vidaMaxima", 30)) / 4)
	var modelo := {
		"nome":nome, "especieId":str(criatura.get("especieId", criatura.get("familia", criatura_id))),
		"criaturaOrigemId":criatura_id, "vida":vida, "vidaMaxima":vida,
		"ataque":maxi(1, int(criatura.get("ataque", 5)) / 4),
		"defesa":maxi(1, int(criatura.get("defesa", 3)) / 4),
		"agilidade":maxi(1, int(criatura.get("agilidade", 3)) / 4),
		"poderMagico":maxi(0, int(criatura.get("poderMagico", 0)) / 4),
		"rank":rank, "raridade":raridade,
		"imagemId":str(criatura.get("imagemId", "")),
		"iconePath":str(criatura.get("iconePath", "")),
		"detalhePath":str(criatura.get("detalhePath", "")),
		"habilidades":criatura.get("habilidades", []).duplicate(true) if criatura.get("habilidades", []) is Array else []
	}
	return {
		"itemId":"ovo_" + criatura_id, "nome":"Ovo de " + nome, "categoria":"ovo",
		"raridade":raridade, "chance":float(chances[rank]),
		"quantidadeMinima":1, "quantidadeMaxima":1,
		"ignorarMultiplicadorRaridade":true, "modeloCompanheiro":modelo
	}


## Moedas de criaturas: o rank define a denominação; nível, perigo e chefia
## definem a quantidade. Sorte aumenta a chance, nunca altera o resultado após a rolagem.
static func criar_entrada_moeda_criatura(criatura: Dictionary, contexto: Dictionary = {}) -> Dictionary:
	var rank := str(criatura.get("rank", "E")).to_upper()
	var denominacao_por_rank := {"E":"bronze","D":"bronze","C":"ferro","B":"ferro","A":"ouro","S":"ouro","SS":"diamante","SSS":"jade"}
	if not denominacao_por_rank.has(rank):
		return {}
	var multiplicador_rank := {"E":1.0,"D":1.5,"C":2.0,"B":3.0,"A":4.0,"S":6.0,"SS":8.0,"SSS":12.0}
	var nivel := clampi(int(criatura.get("nivel", 1)), 1, 10000)
	var perigo := clampf(float(contexto.get("nivelPerigo", criatura.get("perigo", 0))), 0.0, 100.0)
	var quantidade_base := maxi(1, roundi(float(nivel) * float(multiplicador_rank[rank]) * (1.0 + perigo / 100.0)))
	if bool(criatura.get("chefe", false)):
		quantidade_base = mini(999, quantidade_base * 5)
	var sorte := clampf(float(contexto.get("sorte", 0.0)), 0.0, 100.0)
	var chance := clampf(0.12 + float(["E","D","C","B","A","S","SS","SSS"].find(rank)) * 0.035 + sorte * 0.002, 0.05, 0.75)
	var denominacao := str(denominacao_por_rank[rank])
	return {
		"itemId":"moeda_" + denominacao,
		"nome":"Moedas de " + preload("res://scripts/sistema_moedas.gd").nome_com_simbolo(denominacao),
		"categoria":"moeda",
		"raridade":"comum",
		"chance":chance,
		"quantidadeMinima":maxi(1, quantidade_base),
		"quantidadeMaxima":mini(999, maxi(1, quantidade_base + maxi(1, nivel / 3))),
		"ignorarMultiplicadorRaridade":true,
		"denominacaoMoeda":denominacao
	}


## Recompensa monetária de missão: valores modestos e garantidos,
## definidos pelo servidor conforme a dificuldade concluída.
static func criar_entrada_moeda_missao(dificuldade: String) -> Dictionary:
	var faixas := {
		"facil":{"min":4,"max":7},
		"fácil":{"min":4,"max":7},
		"media":{"min":8,"max":12},
		"média":{"min":8,"max":12},
		"dificil":{"min":13,"max":18},
		"difícil":{"min":13,"max":18},
		"extrema":{"min":19,"max":25}
	}
	var chave := dificuldade.strip_edges().to_lower()
	if not faixas.has(chave):
		return {}
	var faixa: Dictionary = faixas[chave]
	return {
		"itemId":"recompensa_missao_bronze",
		"nome":"Recompensa de missão: " + preload("res://scripts/sistema_moedas.gd").nome_com_simbolo("bronze"),
		"categoria":"moeda",
		"raridade":"comum",
		"chance":1.0,
		"quantidadeMinima":int(faixa["min"]),
		"quantidadeMaxima":int(faixa["max"]),
		"ignorarMultiplicadorRaridade":true,
		"denominacaoMoeda":"bronze"
	}


static func resolver_tentativas(criatura: Dictionary, contexto: Dictionary = {}) -> Array:
	var tabela: Array = criatura.get("tabelaDrops", []).duplicate(true)
	var contexto_drops := contexto.duplicate(true)
	# O traço pertence à criatura; propaga-o para o cálculo central de chances e quantidades.
	contexto_drops["liderNato"] = bool(contexto_drops.get("liderNato", criatura.get("liderNato", false)))
	if str(contexto_drops.get("classeId", "")) != "invocador":
		var ovo := criar_entrada_ovo(criatura)
		if not ovo.is_empty():
			tabela.append(ovo)
	return resolver_tabela(tabela, str(criatura.get("id", "")), contexto_drops)


## Compatibilidade: retorna apenas os itens efetivamente obtidos.
static func gerar_drops(criatura: Dictionary, contexto: Dictionary = {}) -> Array:
	var obtidos: Array = []
	for tentativa in resolver_tentativas(criatura, contexto):
		if bool(tentativa.get("obtido", false)):
			obtidos.append(tentativa)
	return obtidos

static func _multiplicador_condicao(entrada: Dictionary, contexto: Dictionary) -> float:
	var parte := str(entrada.get("parteCorporal", ""))
	if parte.is_empty():
		return 1.0
	var danificadas: Array = contexto.get("partesDanificadas", [])
	if danificadas.has(parte):
		return 0.0
	var intactas: Array = contexto.get("partesIntactas", [])
	if intactas.has(parte):
		return 1.5
	return 1.0

static func validar_tabela(tabela: Array) -> bool:
	for entrada in tabela:
		if not (entrada is Dictionary):
			return false
		if str(entrada.get("itemId", "")).strip_edges().is_empty():
			return false
		if not RARIDADES.has(str(entrada.get("raridade", "comum")).to_lower()):
			return false
		var chance := float(entrada.get("chance", -1.0))
		if chance < 0.0 or chance > 1.0:
			return false
		if int(entrada.get("quantidadeMinima", 1)) < 1:
			return false
		if int(entrada.get("quantidadeMaxima", entrada.get("quantidadeMinima", 1))) < int(entrada.get("quantidadeMinima", 1)):
			return false
	return true
