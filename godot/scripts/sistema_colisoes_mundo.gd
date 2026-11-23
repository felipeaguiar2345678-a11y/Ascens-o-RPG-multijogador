extends RefCounted
## Obstáculos estáticos calculados pelo servidor a partir da geometria do mapa.
const LIMITES_MUNDO := Vector2(2400.0, 2400.0)
const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")
const RAIO_JOGADOR := 10.0
const PASSO_AMOSTRAGEM := 5.0
const AURELIA_CENTRO_MUNDO := Vector2(1260.0, 1010.0)
const RAIO_PROTECAO_AURELIA := 230.0
const ROCHAS_DESTRUTIVEIS := [
	Vector2(1040.0, 490.0), Vector2(1115.0, 545.0), Vector2(1290.0, 560.0), Vector2(1380.0, 630.0),
	Vector2(1030.0, 740.0), Vector2(1400.0, 790.0), Vector2(950.0, 650.0), Vector2(1500.0, 700.0)
]

static func trajeto_valido(inicio: Vector2, destino: Vector2, limite_circular: bool = false, zona_destruida: Dictionary = {}) -> bool:
	if not _vetor_finito(inicio) or not _vetor_finito(destino):
		return false
	if not _dentro_do_mundo(inicio, limite_circular) or not _dentro_do_mundo(destino, limite_circular):
		return false
	var distancia := inicio.distance_to(destino)
	var etapas := maxi(1, int(ceil(distancia / PASSO_AMOSTRAGEM)))
	for etapa in range(1, etapas + 1):
		var ponto := inicio.lerp(destino, float(etapa) / float(etapas))
		if _ponto_bloqueado(ponto, zona_destruida):
			return false
	return true

static func _ponto_bloqueado(ponto: Vector2, zona_destruida: Dictionary = {}) -> bool:
	# Terrenos naturais são exploráveis; apenas troncos e construções bloqueiam.
	for i in range(46):
		var x := 90.0 + float((i * 83) % 690)
		var y := 510.0 + float((i * 137) % 1120)
		if Vector2(x, y).distance_to(Vector2(1260.0, 1010.0)) < 330.0:
			continue
		var centro_obstaculo := Vector2(x, y + 12.5)
		if _esta_dentro_da_zona_destruida(centro_obstaculo, zona_destruida):
			continue
		if ponto.distance_to(centro_obstaculo) <= 18.0:
			return true
	for rocha in ROCHAS_DESTRUTIVEIS:
		if _esta_dentro_da_zona_destruida(rocha, zona_destruida):
			continue
		if ponto.distance_to(rocha) <= 22.0:
			return true
	for i in range(12):
		var angulo := TAU * float(i) / 12.0
		var centro := Vector2(1260.0, 1010.0) + Vector2(cos(angulo), sin(angulo)) * 112.0
		if ponto.distance_to(centro) <= 33.0:
			return true
	return false

static func _esta_dentro_da_zona_destruida(ponto: Vector2, zona: Dictionary) -> bool:
	if zona.is_empty():
		return false
	if ponto.distance_to(AURELIA_CENTRO_MUNDO) <= RAIO_PROTECAO_AURELIA:
		return false
	var centro := Vector2(float(zona.get("x", 0.0)), float(zona.get("y", 0.0)))
	var raio := clampf(float(zona.get("raio", 0.0)), 0.0, 2000.0)
	return raio > 0.0 and ponto.distance_squared_to(centro) <= raio * raio

static func _distancia_ponto_segmento(ponto: Vector2, a: Vector2, b: Vector2) -> float:
	var segmento := b - a
	var comprimento_quadrado := segmento.length_squared()
	if comprimento_quadrado <= 0.0001:
		return ponto.distance_to(a)
	var proporcao := clampf((ponto - a).dot(segmento) / comprimento_quadrado, 0.0, 1.0)
	return ponto.distance_to(a + segmento * proporcao)

static func _dentro_do_mundo(ponto: Vector2, limite_circular: bool = false) -> bool:
	var dentro_retangulo := ponto.x >= 0.0 and ponto.y >= 0.0 and ponto.x <= LIMITES_MUNDO.x and ponto.y <= LIMITES_MUNDO.y
	return dentro_retangulo and (not limite_circular or Geometria.dentro_do_limite_circular(ponto))

static func _vetor_finito(ponto: Vector2) -> bool:
	return is_finite(ponto.x) and is_finite(ponto.y)
