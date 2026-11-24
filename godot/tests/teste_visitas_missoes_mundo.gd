extends SceneTree

const SistemaLocais = preload("res://scripts/sistema_locais_missoes_mundo.gd")

func _initialize() -> void:
	_verificar(Vector2(1190.0, 1520.0), "clareira_inicial", "O ponto inicial não foi reconhecido.")
	_verificar(Vector2(1190.0, 1543.0), "fogueira_clareira", "A fogueira não foi reconhecida.")
	_verificar(Vector2(1322.0, 1558.0), "placa_clareira", "A placa não foi reconhecida.")
	_verificar(Vector2(1096.0, 1485.0), "abrigo_viajante", "O abrigo do viajante não foi reconhecido.")
	_verificar(Vector2(1278.0, 1464.0), "abrigo_vigia", "O abrigo do vigia não foi reconhecido.")
	_verificar(Vector2(1198.0, 1608.0), "abrigo_materiais", "O abrigo dos materiais não foi reconhecido.")
	_verificar(Vector2(1370.0, 1510.0), "iren_viajante", "A área de Iren não foi reconhecida.")
	_verificar(Vector2(2401.0, 2401.0), "", "Uma posição fora do mundo foi aceita.")
	_verificar(Vector2(INF, 0.0), "", "Uma posição não finita foi aceita.")
	print("TESTE DE VISITAS DE MISSÃO: pontos reais, limites e posições inválidas aprovados.")
	quit(0)

func _verificar(posicao: Vector2, esperado: String, erro: String) -> void:
	var obtido := SistemaLocais.obter_local_visitado(posicao)
	if obtido != esperado:
		push_error("TESTE DE VISITAS DE MISSÃO: " + erro + " Obtido: " + obtido)
		quit(1)
