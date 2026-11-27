extends SceneTree
## Verifica que as cenas centrais da mini versão possam ser carregadas e instanciadas
## sem depender de uma sessão de servidor ou de credenciais Firebase.

const CENAS_CENTRAIS := [
	"res://scenes/conexao_multiplayer.tscn",
	"res://scenes/criacao_personagem.tscn",
	"res://scenes/mundo_principal.tscn",
	"res://scenes/aventura_cooperativa.tscn",
	"res://scenes/jogador.tscn",
	"res://scenes/controle_joystick.tscn",
	"res://scenes/companheiro.tscn",
	"res://scenes/guardiao_jormungandr.tscn"
]

func _initialize() -> void:
	var falhas: Array[String] = []
	var projeto := FileAccess.open("res://project.godot", FileAccess.READ)
	if projeto == null:
		_falhar(["Não foi possível abrir project.godot."])
		return
	var configuracao := projeto.get_as_text()
	if not configuracao.contains('run/main_scene="res://scenes/conexao_multiplayer.tscn"'):
		falhas.append("A cena inicial não aponta para a conexão multiplayer obrigatória.")

	for caminho in CENAS_CENTRAIS:
		if not ResourceLoader.exists(caminho):
			falhas.append("Cena central ausente: " + caminho)
			continue
		var recurso = ResourceLoader.load(caminho)
		if not (recurso is PackedScene):
			falhas.append("O recurso não é uma PackedScene válida: " + caminho)
			continue
		var instancia := (recurso as PackedScene).instantiate()
		if instancia == null:
			falhas.append("Não foi possível instanciar: " + caminho)
			continue
		if instancia.get_script() == null:
			falhas.append("A cena não possui script de comportamento: " + caminho)
		instancia.free()

	if not falhas.is_empty():
		_falhar(falhas)
		return
	print("TESTE DE INTEGRAÇÃO DE CENAS: inicialização, mundo, personagem, joystick, companheiro e aventura cooperativa carregáveis.")
	quit(0)

func _falhar(falhas: Array[String]) -> void:
	for falha in falhas:
		push_error("TESTE DE INTEGRAÇÃO DE CENAS: " + falha)
	quit(1)
