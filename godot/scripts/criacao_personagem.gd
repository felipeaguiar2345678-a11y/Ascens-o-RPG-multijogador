extends Control

var campo_nome: LineEdit
var seletor_aparencia: OptionButton
var botao_criar: Button
var texto_estado: Label
var perfil_recebido := false

func _ready() -> void:
	RedeMultiplayer.perfil_personagem_recebido.connect(_ao_receber_perfil)
	RedeMultiplayer.erro_conexao.connect(_ao_erro)
	_criar_interface()
	if not RedeMultiplayer.perfil_personagem_atual.is_empty():
		_ao_receber_perfil(RedeMultiplayer.perfil_personagem_atual)

func _criar_interface() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color("#101b20")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(340, 280)
	centro.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	painel.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "CRIE SEU PERSONAGEM"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	coluna.add_child(titulo)
	var descricao := Label.new()
	descricao.text = "Sua jornada começa na Clareira Inicial."
	descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(descricao)
	var rotulo_nome := Label.new()
	rotulo_nome.text = "Nome (3 a 20 caracteres)"
	coluna.add_child(rotulo_nome)
	campo_nome = LineEdit.new()
	campo_nome.placeholder_text = "Nome do aventureiro"
	campo_nome.max_length = 20
	coluna.add_child(campo_nome)
	var rotulo_aparencia := Label.new()
	rotulo_aparencia.text = "Aparência inicial"
	coluna.add_child(rotulo_aparencia)
	seletor_aparencia = OptionButton.new()
	seletor_aparencia.add_item("Aventureiro", 0)
	seletor_aparencia.add_item("Aventureira", 1)
	seletor_aparencia.add_item("Aventureiro alternativo", 2)
	coluna.add_child(seletor_aparencia)
	botao_criar = Button.new()
	botao_criar.text = "Criar personagem e entrar no mundo"
	botao_criar.pressed.connect(_criar_personagem)
	coluna.add_child(botao_criar)
	texto_estado = Label.new()
	texto_estado.text = "Escolha seu nome e aparência."
	texto_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(texto_estado)

func _criar_personagem() -> void:
	var nome := campo_nome.text.strip_edges()
	if nome.length() < 3 or nome.length() > 20:
		texto_estado.text = "O nome precisa ter entre 3 e 20 caracteres."
		return
	var aparencias := ["aventureiro_01", "aventureira_01", "aventureiro_02"]
	botao_criar.disabled = true
	texto_estado.text = "Criando seu personagem no servidor..."
	RedeMultiplayer.solicitar_criacao_personagem(nome, aparencias[seletor_aparencia.selected])

func _ao_receber_perfil(dados: Dictionary) -> void:
	if str(dados.get("uid", "")) != RedeMultiplayer.uid_autenticado:
		return
	perfil_recebido = true
	if bool(dados.get("personagemCriado", false)):
		get_tree().change_scene_to_file("res://scenes/mundo_principal.tscn")
	else:
		botao_criar.disabled = false
		texto_estado.text = "Personagem ainda não criado. Escolha suas opções."

func _ao_erro(mensagem: String) -> void:
	if is_instance_valid(texto_estado):
		texto_estado.text = mensagem
		botao_criar.disabled = false
