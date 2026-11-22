extends RefCounted
## Classifica o terreno no servidor para orientar encontros e ecologia.
const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")
const LAGO_AURELIA := Vector2(1530.0, 420.0)

static func obter_contexto(posicao: Vector2) -> Dictionary:
	if not is_finite(posicao.x) or not is_finite(posicao.y):
		return {}
	if posicao.x < 0.0 or posicao.y < 400.0 or posicao.x > 2400.0 or posicao.y > 2000.0:
		return {}
	# A migração centraliza o mapa antigo 400 px para baixo.
	# Até a nova arte ser redesenhada, classificamos usando a coordenada antiga equivalente.
	var terreno := Geometria.restaurar_posicao_legada(posicao)
	if terreno.x < 0.0:
		return {}
	if terreno.distance_to(LAGO_AURELIA) <= 155.0:
		return _contexto("central", "lago_agua_doce", "agua_doce", 0, "aquatico", 0)
	if _esta_em_lagoa_pantano(terreno):
		return _contexto("sombras", "pantano", "agua_pantanosa", 1, "aquatico", 15)
	if _esta_nas_montanhas(terreno):
		var altitude := clampi(roundi((310.0 - terreno.y) / 3.1), 1, 100)
		return _contexto("montanhas_gelidas", "montanha", "altitude", altitude, "terrestre", 35)
	if terreno.x <= 820.0 and terreno.y <= 1230.0:
		return _contexto("floresta_arcana", "bosque", "floresta", 0, "terrestre", 20)
	if terreno.x <= 1000.0 and terreno.y >= 1180.0:
		return _contexto("deserto_ancestral", "dunas", "areia", 0, "terrestre", 25)
	if terreno.x >= 1800.0 and terreno.y >= 980.0:
		return _contexto("sombras", "pantano", "lama", 0, "terrestre", 25)
	return _contexto("central", "planicie", "terra", 0, "terrestre", 5)

static func _contexto(ecossistema: String, bioma: String, habitat: String, altitude: int, terreno: String, perigo: int) -> Dictionary:
	return {
		"ecossistemaId":ecossistema, "bioma":bioma, "habitat":habitat,
		"altitude":altitude, "terreno":terreno, "perigoBase":perigo,
		"agua":terreno == "aquatico"
	}

static func _esta_nas_montanhas(posicao: Vector2) -> bool:
	var picos := [
		PackedVector2Array([Vector2(1660, 40), Vector2(1780, 260), Vector2(1900, 40)]),
		PackedVector2Array([Vector2(1810, 20), Vector2(1970, 310), Vector2(2130, 20)]),
		PackedVector2Array([Vector2(2030, 60), Vector2(2180, 270), Vector2(2320, 60)])
	]
	for pico in picos:
		if Geometry2D.is_point_in_polygon(posicao, pico):
			return true
	return false

static func _esta_em_lagoa_pantano(posicao: Vector2) -> bool:
	for i in range(13):
		var lagoa := Vector2(1870.0 + float((i * 71) % 430), 1040.0 + float((i * 97) % 430))
		var relativo := posicao - lagoa
		if pow(relativo.x / 40.6, 2.0) + pow(relativo.y / 25.3, 2.0) <= 1.0:
			return true
	return false
