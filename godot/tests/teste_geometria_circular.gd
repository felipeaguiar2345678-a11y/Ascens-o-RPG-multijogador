extends SceneTree

const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")

func _initialize() -> void:
	var antiga := Vector2(1190.0, 1120.0)
	var migrada := Geometria.migrar_posicao_legada(antiga)
	if migrada != Vector2(1190.0, 1520.0):
		_falhar("A migração não preservou a posição antiga com deslocamento vertical.")
		return
	if Geometria.restaurar_posicao_legada(migrada) != antiga:
		_falhar("A conversão de coordenadas não é reversível.")
		return
	if Geometria.migrar_posicao_legada(Vector2(100.0, 1601.0)) != Vector2(-1.0, -1.0):
		_falhar("Uma posição antiga fora do mapa foi migrada.")
		return
	if not Geometria.dentro_do_continente(Geometria.CENTRO_MUNDO):
		_falhar("O centro do continente circular deveria ser explorável.")
		return
	if not Geometria.dentro_do_continente(Geometria.CENTRO_MUNDO + Vector2(Geometria.RAIO_TERRA, 0.0)):
		_falhar("A borda válida do continente foi rejeitada.")
		return
	if Geometria.dentro_do_continente(Geometria.CENTRO_MUNDO + Vector2(Geometria.RAIO_TERRA + 1.0, 0.0)):
		_falhar("Uma posição além da costa circular foi aceita como continente.")
		return
	if not Geometria.dentro_do_limite_circular(Geometria.CENTRO_MUNDO + Vector2(Geometria.RAIO_LIMITE_MUNDO, 0.0)):
		_falhar("A borda de segurança circular foi rejeitada.")
		return
	if Geometria.dentro_do_limite_circular(Vector2(0.0, 0.0)):
		_falhar("Um canto externo ao mundo circular foi aceito.")
		return
	var ponto := Geometria.posicao_na_circunferencia(PI / 2.0)
	if absf(ponto.x - Geometria.CENTRO_MUNDO.x) > 0.01 or absf(ponto.y - (Geometria.CENTRO_MUNDO.y + Geometria.RAIO_CORPO_SERPENTE)) > 0.01:
		_falhar("A posição calculada para a circunferência da Serpente está incorreta.")
		return
	var angulo := Geometria.angulo_da_posicao(ponto)
	if absf(angulo - PI / 2.0) > 0.01:
		_falhar("A conversão de posição para ângulo está incorreta.")
		return
	if Geometria.dentro_do_continente(Vector2(NAN, 10.0)) or Geometria.dentro_do_limite_circular(Vector2(INF, 10.0)):
		_falhar("A geometria aceitou coordenadas não finitas.")
		return
	print("TESTE DE GEOMETRIA CIRCULAR: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE GEOMETRIA CIRCULAR: " + mensagem)
	quit(1)
