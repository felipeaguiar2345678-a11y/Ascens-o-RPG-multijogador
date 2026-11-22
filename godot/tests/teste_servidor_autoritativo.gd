extends SceneTree

const Rede = preload("res://scripts/rede_multiplayer.gd")
const Ciclo = preload("res://scripts/sistema_ciclo_noturno.gd")

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
	print("TESTE DO SERVIDOR AUTORITATIVO: semente persistente, relógio compartilhado e limite de ações aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DO SERVIDOR AUTORITATIVO: " + mensagem)
	quit(1)
