extends RefCounted
## Seleção determinística de criaturas já geradas e registradas.
## Não cria inimigos nem decide sozinha o local do encontro.
const RARIDADES_PESO := {
	"comum": 1000, "incomum": 650, "raro": 350, "epico": 180,
	"lendario": 80, "mitico": 35, "divino": 12,
	"transcendente": 3, "unico": 1
}

static func selecionar(catalogo: Array, ecossistema_id: String, bioma: String, perigo: int, permitir_chefe: bool, semente: int, periodo: String = "dia") -> Dictionary:
	if ecossistema_id.strip_edges().is_empty() or bioma.strip_edges().is_empty():
		return {}
	if perigo < 0 or perigo > 100 or catalogo.is_empty():
		return {}
	var candidatas: Array = []
	var peso_total := 0
	for criatura in catalogo:
		if not (criatura is Dictionary):
			continue
		if not preload("res://scripts/sistema_ciclo_noturno.gd").criatura_disponivel(criatura, periodo):
			continue
		if str(criatura.get("ecossistemaId", "")) != ecossistema_id:
			continue
		if str(criatura.get("bioma", "")) != bioma:
			continue
		var nivel_perigo := int(criatura.get("perigo", -1))
		if nivel_perigo < 0 or nivel_perigo > perigo:
			continue
		var chefe := bool(criatura.get("chefe", false))
		if chefe and not permitir_chefe:
			continue
		var raridade := str(criatura.get("raridade", "comum")).to_lower()
		var peso := int(RARIDADES_PESO.get(raridade, 0))
		if peso <= 0:
			continue
		candidatas.append({"criatura":criatura,"peso":peso})
		peso_total += peso
	if candidatas.is_empty() or peso_total <= 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var sorteio := rng.randi_range(1, peso_total)
	for candidata in candidatas:
		sorteio -= int(candidata["peso"])
		if sorteio <= 0:
			return candidata["criatura"].duplicate(true)
	return {}
