extends RefCounted
## Validação independente de pedidos de movimento recebidos pelo servidor.

const TEMPO_MAXIMO_CREDITADO_MS := 250
const MULTIPLICADOR_TOLERANCIA := 1.35
const TOLERANCIA_FIXA_PIXELS := 5.0

static func posicao_valida(
	anterior: Vector2,
	solicitada: Vector2,
	decorrido_ms: int,
	velocidade_autorizada: float,
	limites: Vector2 = Vector2(2400.0, 1600.0)
) -> bool:
	if not _vetor_finito(anterior) or not _vetor_finito(solicitada):
		return false
	if not _vetor_finito(limites) or not is_finite(velocidade_autorizada):
		return false
	if velocidade_autorizada <= 0.0 or decorrido_ms < 0:
		return false
	if limites.x <= 0.0 or limites.y <= 0.0:
		return false
	if solicitada.x < 0.0 or solicitada.y < 0.0:
		return false
	if solicitada.x > limites.x or solicitada.y > limites.y:
		return false

	# Tempo ocioso não vira crédito para atravessar o mapa de uma vez.
	var tempo_creditado := min(decorrido_ms, TEMPO_MAXIMO_CREDITADO_MS)
	var distancia_maxima := velocidade_autorizada * (float(tempo_creditado) / 1000.0) * MULTIPLICADOR_TOLERANCIA + TOLERANCIA_FIXA_PIXELS
	return anterior.distance_squared_to(solicitada) <= distancia_maxima * distancia_maxima

static func _vetor_finito(valor: Vector2) -> bool:
	return is_finite(valor.x) and is_finite(valor.y)
