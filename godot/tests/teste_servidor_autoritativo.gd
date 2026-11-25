extends SceneTree

const Rede = preload("res://scripts/rede_multiplayer.gd")
const Ciclo = preload("res://scripts/sistema_ciclo_noturno.gd")
const Movimento = preload("res://scripts/sistema_validacao_movimento.gd")
const Colisoes = preload("res://scripts/sistema_colisoes_mundo.gd")
const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")

func _initialize() -> void:
	var servidor := Rede.new()
	var caminho_teste := "user://teste_semente_mundo_%d.json" % Time.get_ticks_usec()
	var primeira_semente := servidor._carregar_ou_criar_semente_mundo_celeste(caminho_teste)
	if primeira_semente <= 0:
		_falhar("O servidor não criou uma semente celeste válida.")
		return
	var segunda_semente := servidor._carregar_ou_criar_semente_mundo_celeste(caminho_teste)
	if primeira_semente != segunda_semente:
		_falhar("A semente celeste mudou após recarregar o estado persistido.")
		return

	servidor._semente_mundo_celeste = primeira_semente
	var contexto := servidor._obter_contexto_celeste_servidor()
	var evento_esperado := Ciclo.evento_celeste_por_dia(int(contexto.get("dia", 0)), primeira_semente)
	if contexto.get("eventoCeleste", {}) != evento_esperado:
		_falhar("O servidor não calculou o fenômeno com a semente persistente do mundo.")
		return
	if not contexto.has("segundoNoCiclo") or not contexto.has("duracaoCicloSegundos"):
		_falhar("O contexto autoritativo não contém o relógio acelerado compartilhado.")
		return

	_testar_validacao_movimento()
	_testar_colisoes_mundo()
	if not servidor._registrar_acao_combate_se_permitida(7, 1000):
		_falhar("A primeira ação válida de combate foi bloqueada.")
		return
	if servidor._registrar_acao_combate_se_permitida(7, 1200):
		_falhar("O servidor aceitou ações de combate repetidas antes do intervalo mínimo.")
		return
	if not servidor._registrar_acao_combate_se_permitida(7, 1350):
		_falhar("O servidor não liberou a ação após o intervalo mínimo.")
		return

	var caminho_absoluto := ProjectSettings.globalize_path(caminho_teste)
	if FileAccess.file_exists(caminho_teste):
		DirAccess.remove_absolute(caminho_absoluto)
	servidor.free()
	print("TESTE DO SERVIDOR AUTORITATIVO: relógio persistente, limites de movimento e intervalo de combate aprovados.")
	quit(0)

func _testar_validacao_movimento() -> void:
	if not Movimento.posicao_valida(Vector2(100, 100), Vector2(112, 100), 50, 165.0):
		_falhar("Um deslocamento normal foi rejeitado.")
		return
	if Movimento.posicao_valida(Vector2(100, 100), Vector2(900, 100), 5000, 165.0):
		_falhar("Foi aceito teletransporte após longo período sem pacotes.")
		return
	if Movimento.posicao_valida(Vector2(100, 100), Vector2(2401, 100), 100, 165.0):
		_falhar("Foi aceita posição além do limite do mundo.")
		return
	if Movimento.posicao_valida(Vector2(-1, 100), Vector2(0, 100), 100, 165.0):
		_falhar("Uma posição anterior corrompida fora do mundo foi aceita.")
		return
	if Movimento.posicao_valida(Vector2(100, 100), Vector2(INF, 100), 100, 165.0):
		_falhar("Foi aceita coordenada infinita.")
		return
	if Movimento.posicao_valida(Vector2(100, 100), Vector2(100, 100), -1, 165.0):
		_falhar("Foi aceito intervalo de tempo negativo.")
		return
	if Movimento.posicao_valida(Vector2(100, 100), Vector2(100, 100), 100, NAN):
		_falhar("Foi aceita velocidade não numérica.")
		return
	if Movimento.posicao_valida(Vector2(100, 100), Vector2(100, 100), 100, 165.0, Vector2(INF, 1600)):
		_falhar("Foi aceito limite de mundo infinito.")
		return
	if not Movimento.posicao_valida(Vector2(0, 0), Vector2(0, 0), 0, 165.0):
		_falhar("Uma posição válida no limite inicial foi rejeitada.")
		return
	if not Movimento.posicao_inicial_valida(Vector2(1190, 1520)):
		_falhar("A posição inicial migrada foi rejeitada.")
		return
	if not Movimento.posicao_inicial_valida(Geometria.CENTRO_MUNDO, Vector2(2400, 2400), true):
		_falhar("O centro do continente circular foi rejeitado.")
		return
	if Movimento.posicao_inicial_valida(Vector2(0, 0), Vector2(2400, 2400), true):
		_falhar("Um canto fora do limite circular foi aceito.")
		return
	if Movimento.posicao_valida(Vector2(1200, 1200), Vector2(1250, 1200), 100, 165.0, Vector2(2400, 2400), true):
		_falhar("Foi aceito deslocamento incompatível com o tempo no limite circular.")
		return
	if Movimento.posicao_inicial_valida(Vector2(-0.1, 1120)):
		_falhar("Uma posição persistida negativa foi aceita.")
		return
	if Movimento.posicao_inicial_valida(Vector2(2400.1, 1120)):
		_falhar("Uma posição persistida além do mapa foi aceita.")
		return
	if Movimento.posicao_inicial_valida(Vector2(NAN, 1120)):
		_falhar("Uma posição persistida não numérica foi aceita.")
		return
	if Movimento.posicao_inicial_valida(Vector2(100, 100), Vector2(0, 1600)):
		_falhar("Limites de mundo inválidos foram aceitos para a posição inicial.")
		return

func _testar_colisoes_mundo() -> void:
	if not Colisoes.trajeto_valido(Vector2(1190, 1520), Vector2(1200, 1520)):
		_falhar("Um trajeto livre próximo ao ponto inicial foi bloqueado.")
		return
	if Colisoes.trajeto_valido(Vector2(789.0, 1172.5), Vector2(789.0, 1172.5)):
		_falhar("Foi permitido atravessar um tronco da Floresta Arcana.")
		return
	if not Colisoes.trajeto_valido(Vector2(1400, 820), Vector2(1660, 820)):
		_falhar("A travessia do lago de Aurelia foi bloqueada.")
		return
	if not Colisoes.trajeto_valido(Vector2(1830, 1440), Vector2(1910, 1440)):
		_falhar("A travessia das águas do pântano foi bloqueada.")
		return
	if not Colisoes.trajeto_valido(Vector2(1700, 500), Vector2(1850, 500)):
		_falhar("A exploração da cordilheira foi bloqueada.")
		return
	if Colisoes.trajeto_valido(Vector2(1340, 1010), Vector2(1400, 1010)):
		_falhar("Foi permitido atravessar um edifício de Aurelia.")
		return
	if Colisoes.trajeto_valido(Vector2(-1, 100), Vector2(10, 100)):
		_falhar("Foi aceita origem fora do mundo.")
		return
	if Colisoes.trajeto_valido(Vector2(0, 0), Vector2(20, 20), true):
		_falhar("Foi aceito trajeto no canto externo do círculo.")
		return
	if not Colisoes.trajeto_valido(Vector2(1200, 1200), Vector2(1210, 1200), true):
		_falhar("Um trajeto no interior do continente circular foi bloqueado.")
		return

func _falhar(mensagem: String) -> void:
	push_error("TESTE DO SERVIDOR AUTORITATIVO: " + mensagem)
	quit(1)
