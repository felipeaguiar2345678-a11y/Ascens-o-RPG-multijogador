extends RefCounted
## Classifica o terreno no servidor para orientar encontros e ecologia.
## As áreas usam as coordenadas migradas do mapa circular, mas respeitam
## os mesmos marcos visuais desenhados no cliente.
const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")
const LAGO_AURELIA := Vector2(1530.0, 420.0)

static func obter_contexto(posicao: Vector2) -> Dictionary:
	if not is_finite(posicao.x) or not is_finite(posicao.y):
		return {}
	if not Geometria.dentro_do_continente(posicao):
		return {}
	var terreno := Geometria.restaurar_posicao_legada(posicao)
	if terreno.x < 0.0:
		return {}
	if terreno.distance_to(LAGO_AURELIA) <= 155.0:
		return _contexto("central", "lago_agua_doce", "agua_doce", 0, "aquatico", 0)
	if _esta_em_lagoa_pantano(terreno):
		return _contexto("sombras", "pantano", "agua_pantanosa", 1, "aquatico", 15)
	if _esta_nas_montanhas(terreno):
		var altitude := clampi(roundi((330.0 - terreno.y) / 3.0), 1, 100)
		return _contexto("montanhas_gelidas", "cordilheira", "altitude", altitude, "terrestre", 35)
	if terreno.x >= 250.0 and terreno.x <= 900.0 and terreno.y >= 100.0 and terreno.y <= 1235.0:
		return _contexto("floresta_arcana", "bosque", "floresta", 0, "terrestre", 20)
	if terreno.x >= 300.0 and terreno.x <= 900.0 and terreno.y >= 1240.0 and terreno.y <= 1395.0:
		return _contexto("deserto_ancestral", "dunas", "areia", 0, "terrestre", 25)
	if terreno.x >= 1690.0 and terreno.y >= 980.0 and terreno.y <= 1390.0:
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
		PackedVector2Array([Vector2(1480, 70), Vector2(1630, 285), Vector2(1780, 70)]),
		PackedVector2Array([Vector2(1660, 30), Vector2(1840, 330), Vector2(2020, 30)]),
		PackedVector2Array([Vector2(1870, 75), Vector2(2010, 270), Vector2(2150, 75)])
	]
	for pico in picos:
		if Geometry2D.is_point_in_polygon(posicao, pico):
			return true
	return false

static func _esta_em_lagoa_pantano(posicao: Vector2) -> bool:
	for i in range(13):
		var lagoa := Vector2(1870.0 + float((i * 37) % 200), 1040.0 + float((i * 47) % 320))
		var relativo := posicao - lagoa
		if pow(relativo.x / 40.6, 2.0) + pow(relativo.y / 25.3, 2.0) <= 1.0:
			return true
	return false
