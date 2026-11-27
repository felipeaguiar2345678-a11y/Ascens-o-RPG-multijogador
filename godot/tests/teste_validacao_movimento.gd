extends SceneTree

const Validacao = preload("res://scripts/sistema_validacao_movimento.gd")

func _initialize() -> void:
	var inicio := Vector2(1200.0, 1200.0)

	if not Validacao.posicao_valida(inicio, Vector2(1210.0, 1200.0), 100, 165.0):
		_falhar("Movimento curto e legítimo foi rejeitado.")
		return
	if Validacao.posicao_valida(inicio, Vector2(1300.0, 1200.0), 100, 165.0):
		_falhar("Movimento incompatível com a velocidade foi aceito.")
		return
	if Validacao.posicao_valida(inicio, Vector2(1255.0, 1200.0), 10000, 165.0):
		_falhar("Tempo ocioso foi convertido em crédito ilimitado de movimento.")
		return
	if Validacao.posicao_valida(inicio, Vector2(1210.0, 1200.0), -1, 165.0):
		_falhar("Intervalo negativo foi aceito.")
		return
	if Validacao.posicao_valida(inicio, Vector2(1210.0, 1200.0), 100, 0.0):
		_falhar("Velocidade autorizada nula foi aceita.")
		return
	if Validacao.posicao_valida(inicio, Vector2(INF, 1200.0), 100, 165.0):
		_falhar("Coordenada infinita foi aceita.")
		return
	if Validacao.posicao_inicial_valida(Vector2(-1.0, 1200.0)):
		_falhar("Posição inicial fora dos limites retangulares foi aceita.")
		return
	if Validacao.posicao_inicial_valida(Vector2(2400.0, 1200.0), Vector2(2400.0, 2400.0), true):
		_falhar("Posição inicial fora do limite circular foi aceita.")
		return
	if not Validacao.posicao_inicial_valida(Vector2(1200.0, 1200.0), Vector2(2400.0, 2400.0), true):
		_falhar("Centro do mapa foi rejeitado no modo circular.")
		return

	print("TESTE DE VALIDAÇÃO DE MOVIMENTO: limites, velocidade, tempo e coordenadas aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE VALIDAÇÃO DE MOVIMENTO: " + mensagem)
	quit(1)
