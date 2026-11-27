extends RefCounted
## Geometria compartilhada do futuro mundo circular.
## O mapa antigo permanece ativo até a migração de posições e biomas ser concluída.

const TAMANHO_MUNDO := Vector2(2400.0, 2400.0)
const VERSAO_COORDENADAS := 2
const TAMANHO_MUNDO_LEGADO := Vector2(2400.0, 1600.0)
const DESLOCAMENTO_VERTICAL_LEGADO := 400.0
const CENTRO_MUNDO := Vector2(1200.0, 1200.0)
const RAIO_TERRA := 1040.0
const RAIO_CORPO_SERPENTE := 1120.0
const RAIO_LIMITE_MUNDO := 1190.0

## Converte coordenadas do mapa retangular antigo para o novo plano quadrado.
## A translação preserva distâncias, rotas e posições relativas entre entidades.
static func migrar_posicao_legada(posicao: Vector2) -> Vector2:
	if not _vetor_finito(posicao):
		return Vector2(-1.0, -1.0)
	if posicao.x < 0.0 or posicao.y < 0.0 or posicao.x > TAMANHO_MUNDO_LEGADO.x or posicao.y > TAMANHO_MUNDO_LEGADO.y:
		return Vector2(-1.0, -1.0)
	return posicao + Vector2(0.0, DESLOCAMENTO_VERTICAL_LEGADO)

static func restaurar_posicao_legada(posicao: Vector2) -> Vector2:
	if not _vetor_finito(posicao):
		return Vector2(-1.0, -1.0)
	var restaurada := posicao - Vector2(0.0, DESLOCAMENTO_VERTICAL_LEGADO)
	if restaurada.x < 0.0 or restaurada.y < 0.0 or restaurada.x > TAMANHO_MUNDO_LEGADO.x or restaurada.y > TAMANHO_MUNDO_LEGADO.y:
		return Vector2(-1.0, -1.0)
	return restaurada

static func dentro_do_continente(posicao: Vector2, margem: float = 0.0) -> bool:
	if not _vetor_finito(posicao) or not is_finite(margem) or margem < 0.0:
		return false
	var raio_permitido := RAIO_TERRA - margem
	if raio_permitido < 0.0:
		return false
	return posicao.distance_squared_to(CENTRO_MUNDO) <= raio_permitido * raio_permitido

static func dentro_do_limite_circular(posicao: Vector2, margem: float = 0.0) -> bool:
	if not _vetor_finito(posicao) or not is_finite(margem) or margem < 0.0:
		return false
	var raio_permitido := RAIO_LIMITE_MUNDO - margem
	if raio_permitido < 0.0:
		return false
	return posicao.distance_squared_to(CENTRO_MUNDO) <= raio_permitido * raio_permitido

static func posicao_na_circunferencia(angulo: float, raio: float = RAIO_CORPO_SERPENTE) -> Vector2:
	if not is_finite(angulo) or not is_finite(raio) or raio < 0.0:
		return Vector2.ZERO
	return CENTRO_MUNDO + Vector2(cos(angulo), sin(angulo)) * raio

static func angulo_da_posicao(posicao: Vector2) -> float:
	if not _vetor_finito(posicao):
		return 0.0
	return (posicao - CENTRO_MUNDO).angle()

static func _vetor_finito(valor: Vector2) -> bool:
	return is_finite(valor.x) and is_finite(valor.y)
