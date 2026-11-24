extends RefCounted
## Pontos de interesse reais da Clareira Inicial usados para objetivos de visita.
## A confirmação final é feita pela posição já validada pelo servidor ENet.

const LOCAIS := [
	{"id":"clareira_inicial","posicao":Vector2(1190.0, 1520.0),"raio":20.0},
	{"id":"fogueira_clareira","posicao":Vector2(1190.0, 1543.0),"raio":20.0},
	{"id":"placa_clareira","posicao":Vector2(1322.0, 1558.0),"raio":48.0},
	{"id":"abrigo_viajante","posicao":Vector2(1096.0, 1485.0),"raio":48.0},
	{"id":"abrigo_vigia","posicao":Vector2(1278.0, 1464.0),"raio":48.0},
	{"id":"abrigo_materiais","posicao":Vector2(1198.0, 1608.0),"raio":48.0},
	{"id":"iren_viajante","posicao":Vector2(1370.0, 1510.0),"raio":58.0}
]

static func obter_local_visitado(posicao: Vector2) -> String:
	if not is_finite(posicao.x) or not is_finite(posicao.y):
		return ""
	if posicao.x < 0.0 or posicao.y < 0.0 or posicao.x > 2400.0 or posicao.y > 2400.0:
		return ""
	var melhor_id := ""
	var menor_distancia := INF
	for local in LOCAIS:
		var distancia: float = posicao.distance_to(local["posicao"])
		if distancia <= float(local["raio"]) and distancia < menor_distancia:
			melhor_id = str(local["id"])
			menor_distancia = distancia
	return melhor_id
