extends RefCounted
## Validação independente de pedidos de movimento recebidos pelo servidor.

const TEMPO_MAXIMO_CREDITADO_MS := 250
const MULTIPLICADOR_TOLERANCIA := 1.35
const TOLERANCIA_FIXA_PIXELS := 5.0
const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")

static func posicao_valida(
	anterior: Vector2,
	solicitada: Vector2,
	decorrido_ms: int,
	velocidade_autorizada: float,
	limites: Vector2 = Vector2(2400.0, 2400.0),
	limite_circular: bool = false
) -> bool:
	if not _vetor_finito(anterior) or not _vetor_finito(solicitada):
		return false
	if not _vetor_finito(limites) or not is_finite(velocidade_autorizada):
		return false
	if velocidade_autorizada <= 0.0 or decorrido_ms < 0:
		return false
	if limites.x <= 0.0 or limites.y <= 0.0:
		return false

	# Tanto a posição armazenada quanto o destino precisam estar no mundo.
	if not _dentro_dos_limites(anterior, limites, limite_circular):
		return false
	if not _dentro_dos_limites(solicitada, limites, limite_circular):
		return false

	# Tempo ocioso não vira crédito para atravessar o mapa de uma vez.
	var tempo_creditado := min(decorrido_ms, TEMPO_MAXIMO_CREDITADO_MS)
	var distancia_maxima := (
		velocidade_autorizada
		* (float(tempo_creditado) / 1000.0)
		* MULTIPLICADOR_TOLERANCIA
		+ TOLERANCIA_FIXA_PIXELS
	)
	return anterior.distance_squared_to(solicitada) <= distancia_maxima * distancia_maxima

static func posicao_inicial_valida(posicao: Vector2, limites: Vector2 = Vector2(2400.0, 2400.0), limite_circular: bool = false) -> bool:
	if not _vetor_finito(posicao) or not _vetor_finito(limites):
		return false
	if limites.x <= 0.0 or limites.y <= 0.0:
		return false
	return _dentro_dos_limites(posicao, limites, limite_circular)

static func _dentro_dos_limites(posicao: Vector2, limites: Vector2, limite_circular: bool = false) -> bool:
	var dentro_retangulo := (
		posicao.x >= 0.0
		and posicao.y >= 0.0
		and posicao.x <= limites.x
		and posicao.y <= limites.y
	)
	return dentro_retangulo and (not limite_circular or Geometria.dentro_do_limite_circular(posicao))

static func _vetor_finito(valor: Vector2) -> bool:
	return is_finite(valor.x) and is_finite(valor.y)
