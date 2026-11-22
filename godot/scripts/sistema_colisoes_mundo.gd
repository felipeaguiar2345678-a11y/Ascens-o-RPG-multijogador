extends RefCounted
## Obstáculos estáticos calculados pelo servidor a partir da geometria do mapa.
const LIMITES_MUNDO := Vector2(2400.0, 1600.0)
const RAIO_JOGADOR := 10.0
const PASSO_AMOSTRAGEM := 5.0

static func trajeto_valido(inicio: Vector2, destino: Vector2) -> bool:
	if not _vetor_finito(inicio) or not _vetor_finito(destino):
		return false
	if not _dentro_do_mundo(inicio) or not _dentro_do_mundo(destino):
		return false
	var distancia := inicio.distance_to(destino)
	var etapas := maxi(1, int(ceil(distancia / PASSO_AMOSTRAGEM)))
	for etapa in range(1, etapas + 1):
		var ponto := inicio.lerp(destino, float(etapa) / float(etapas))
		if _ponto_bloqueado(ponto):
			return false
	return true

static func _ponto_bloqueado(ponto: Vector2) -> bool:
	if ponto.distance_to(Vector2(1530.0, 420.0)) <= 147.0:
		return true
	for i in range(46):
		var x := 90.0 + float((i * 83) % 690)
		var y := 110.0 + float((i * 137) % 1120)
		if Vector2(x, y).distance_to(Vector2(1260.0, 610.0)) < 330.0:
			continue
		if ponto.distance_to(Vector2(x, y + 12.5)) <= 18.0:
			return true
	for i in range(13):
		var lagoa := Vector2(1870.0 + float((i * 71) % 430), 1040.0 + float((i * 97) % 430))
		var relativo := ponto - lagoa
		if pow(relativo.x / 40.6, 2.0) + pow(relativo.y / 25.3, 2.0) <= 1.0:
			return true
	for i in range(12):
		var angulo := TAU * float(i) / 12.0
		var centro := Vector2(1260.0, 610.0) + Vector2(cos(angulo), sin(angulo)) * 112.0
		if ponto.distance_to(centro) <= 33.0:
			return true
	for montanha in _poligonos_montanhas():
		if Geometry2D.is_point_in_polygon(ponto, montanha):
			return true
		for aresta in range(montanha.size()):
			if _distancia_ponto_segmento(ponto, montanha[aresta], montanha[(aresta + 1) % montanha.size()]) <= RAIO_JOGADOR:
				return true
	return false

static func _poligonos_montanhas() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([Vector2(1660, 40), Vector2(1780, 260), Vector2(1900, 40)]),
		PackedVector2Array([Vector2(1810, 20), Vector2(1970, 310), Vector2(2130, 20)]),
		PackedVector2Array([Vector2(2030, 60), Vector2(2180, 270), Vector2(2320, 60)])
	]

static func _distancia_ponto_segmento(ponto: Vector2, a: Vector2, b: Vector2) -> float:
	var segmento := b - a
	var comprimento_quadrado := segmento.length_squared()
	if comprimento_quadrado <= 0.0001:
		return ponto.distance_to(a)
	var proporcao := clampf((ponto - a).dot(segmento) / comprimento_quadrado, 0.0, 1.0)
	return ponto.distance_to(a + segmento * proporcao)

static func _dentro_do_mundo(ponto: Vector2) -> bool:
	return ponto.x >= 0.0 and ponto.y >= 0.0 and ponto.x <= LIMITES_MUNDO.x and ponto.y <= LIMITES_MUNDO.y

static func _vetor_finito(ponto: Vector2) -> bool:
	return is_finite(ponto.x) and is_finite(ponto.y)
