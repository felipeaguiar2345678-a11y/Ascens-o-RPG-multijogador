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
	# Terrenos naturais são exploráveis; apenas troncos e construções bloqueiam.
	for i in range(46):
		var x := 90.0 + float((i * 83) % 690)
		var y := 110.0 + float((i * 137) % 1120)
		if Vector2(x, y).distance_to(Vector2(1260.0, 610.0)) < 330.0:
			continue
		if ponto.distance_to(Vector2(x, y + 12.5)) <= 18.0:
			return true
	for i in range(12):
		var angulo := TAU * float(i) / 12.0
		var centro := Vector2(1260.0, 610.0) + Vector2(cos(angulo), sin(angulo)) * 112.0
		if ponto.distance_to(centro) <= 33.0:
			return true
	return false

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
