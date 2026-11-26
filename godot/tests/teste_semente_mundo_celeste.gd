extends SceneTree

const REDE = preload("res://scripts/rede_multiplayer.gd")
const CAMINHO_TESTE := "user://teste_semente_mundo_celeste.json"

func _initialize() -> void:
	_remover_arquivos_teste()
	var primeira_instancia = REDE.new()
	var semente_criada := int(primeira_instancia._carregar_ou_criar_semente_mundo_celeste(CAMINHO_TESTE))
	primeira_instancia.free()
	if semente_criada <= 0:
		_falhar("A primeira inicialização não persistiu uma semente válida.")
		return
	var segunda_instancia = REDE.new()
	var semente_recuperada := int(segunda_instancia._carregar_ou_criar_semente_mundo_celeste(CAMINHO_TESTE))
	segunda_instancia.free()
	if semente_recuperada != semente_criada:
		_falhar("A semente mudou após recriar a instância do servidor.")
		return
	var arquivo_corrompido := FileAccess.open(CAMINHO_TESTE, FileAccess.WRITE)
	if arquivo_corrompido == null:
		_falhar("Não foi possível preparar o cenário de corrupção.")
		return
	arquivo_corrompido.store_string("{arquivo inválido")
	arquivo_corrompido.close()
	var terceira_instancia = REDE.new()
	var semente_apos_corrupcao := int(terceira_instancia._carregar_ou_criar_semente_mundo_celeste(CAMINHO_TESTE))
	terceira_instancia.free()
	if semente_apos_corrupcao != 0:
		_falhar("Uma semente corrompida foi substituída silenciosamente.")
		return
	_remover_arquivos_teste()
	print("TESTE DE PERSISTÊNCIA DA SEMENTE CELESTE: aprovado.")
	quit(0)

func _remover_arquivos_teste() -> void:
	for caminho in [CAMINHO_TESTE, CAMINHO_TESTE + ".tmp"]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))

func _falhar(mensagem: String) -> void:
	_remover_arquivos_teste()
	push_error("TESTE DA SEMENTE CELESTE: " + mensagem)
	quit(1)
