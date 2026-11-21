extends SceneTree

const Repositorio = preload("res://scripts/repositorio_personagem_servidor.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var repositorio = Repositorio.new()
	var uid := "ci_persistencia_%s" % str(Time.get_ticks_usec())
	var perfil: Dictionary = repositorio.carregar_ou_criar(uid)
	if perfil.is_empty():
		_falhar("Não criou o perfil inicial.")
		return
	var revisao_inicial := int(perfil.get("revisaoServidor", 0))
	var snapshot_antigo := perfil.duplicate(true)
	perfil["x"] = 1200.0
	if not repositorio.salvar(uid, perfil):
		_falhar("Não salvou a primeira atualização.")
		return
	if repositorio.salvar(uid, snapshot_antigo):
		_falhar("Aceitou snapshot com revisão antiga.")
		return
	perfil["x"] = 1300.0
	if not repositorio.salvar(uid, perfil):
		_falhar("Não salvou a segunda atualização.")
		return
	var caminho := ProjectSettings.globalize_path("user://dados/personagens_online.json")
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		_falhar("Não conseguiu preparar o teste de recuperação.")
		return
	arquivo.store_string("arquivo propositalmente corrompido")
	arquivo.close()
	var recuperado: Dictionary = repositorio.carregar_ou_criar(uid)
	if recuperado.is_empty() or not is_equal_approx(float(recuperado.get("x", -1.0)), 1200.0):
		_falhar("Não recuperou a última versão válida do backup.")
		return
	if int(recuperado.get("revisaoServidor", 0)) != revisao_inicial + 1:
		_falhar("A revisão recuperada não corresponde ao backup esperado.")
		return
	var uid_novo := "ci_criacao_%s" % str(Time.get_ticks_usec())
	var perfil_novo: Dictionary = repositorio.carregar_ou_criar(uid_novo)
	if perfil_novo.is_empty() or bool(perfil_novo.get("personagemCriado", true)):
		_falhar("Perfil novo não aguardou a criação do personagem.")
		return
	var criado: Dictionary = repositorio.criar_personagem(uid_novo, "Teste Heroi", "aventureiro_01")
	if criado.is_empty() or not bool(criado.get("personagemCriado", false)) or str(criado.get("nome", "")) != "Teste Heroi":
		_falhar("Não criou o personagem com os dados permitidos.")
		return
	if not repositorio.criar_personagem(uid_novo, "Outro Nome", "aventureira_01").is_empty():
		_falhar("Permitiu criar um segundo personagem na mesma conta.")
		return
	if not repositorio.criar_personagem("uid_invalido", "X", "aparencia_invalida").is_empty():
		_falhar("Aceitou dados inválidos de criação.")
		return
	print("TESTE DE PERSISTÊNCIA: aprovado (criação, revisão, backup e criação única de personagem).")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE PERSISTÊNCIA: " + mensagem)
	quit(1)
