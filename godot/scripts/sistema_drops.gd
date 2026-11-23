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
	var lider_nato := bool(contexto.get("liderNato", criatura.get("liderNato", false)))
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
		var chance_final := chance * float(MULTIPLICADOR_RARIDADE[raridade])
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
			"origemLiderNato": lider_nato
		})
	return resultados


static func resolver_tentativas(criatura: Dictionary, contexto: Dictionary = {}) -> Array:
	return resolver_tabela(criatura.get("tabelaDrops", []), str(criatura.get("id", "")), contexto)


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
