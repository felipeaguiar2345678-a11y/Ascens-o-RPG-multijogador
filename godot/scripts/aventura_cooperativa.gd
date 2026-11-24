extends Control

const TEMA_VISUAL = preload("res://scripts/tema_visual.gd")

var lista: RichTextLabel
var campo: LineEdit
var estado: Label
var sala: Label
var botao_enviar: Button
var membros_ativos := 0

func _ready() -> void:
	TEMA_VISUAL.aplicar(self)
	_montar_interface()
	RedeMultiplayer.aventura_sala_atualizada.connect(_atualizar_aventura)
	RedeMultiplayer.sala_atualizada.connect(_atualizar_sala)
	RedeMultiplayer.resultado_mensagem_aventura.connect(_resultado_envio)
	_atualizar_sala({"codigo": RedeMultiplayer.codigo_sala_cliente, "jogadores": 1, "limite": 4})
	_atualizar_aventura(RedeMultiplayer.estado_aventura_sala_atual)

func _montar_interface() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color("#101b20")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margem.add_theme_constant_override("margin_left", 12)
	margem.add_theme_constant_override("margin_right", 12)
	margem.add_theme_constant_override("margin_top", 12)
	margem.add_theme_constant_override("margin_bottom", 12)
	add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	margem.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "AVENTURA COMPARTILHADA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 20)
	coluna.add_child(titulo)
	sala = Label.new()
	sala.text = "Sala cooperativa • aguardando sincronização"
	sala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(sala)
	var explicacao := Label.new()
	explicacao.text = "A história é compartilhada por texto. Conte suas ações e combine os próximos passos com o grupo."
	explicacao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(explicacao)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(rolagem)
	lista = RichTextLabel.new()
	lista.bbcode_enabled = true
	lista.fit_content = true
	lista.scroll_following = true
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.custom_minimum_size = Vector2(300, 180)
	rolagem.add_child(lista)
	campo = LineEdit.new()
	campo.placeholder_text = "Escreva uma ação ou fala (até 300 caracteres)"
	campo.max_length = 300
	campo.text_submitted.connect(_enviar)
	coluna.add_child(campo)
	botao_enviar = Button.new()
	botao_enviar.text = "Enviar para o grupo"
	botao_enviar.pressed.connect(_enviar)
	coluna.add_child(botao_enviar)
	estado = Label.new()
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(estado)
	var sair := Button.new()
	sair.text = "Desconectar"
	sair.pressed.connect(_desconectar)
	coluna.add_child(sair)

func _atualizar_sala(dados: Dictionary) -> void:
	if not is_instance_valid(sala):
		return
	membros_ativos = int(dados.get("jogadores", 0))
	sala.text = "Sala %s • %d/%d aventureiros" % [str(dados.get("codigo", "------")), membros_ativos, int(dados.get("limite", 4))]
	if is_instance_valid(botao_enviar):
		botao_enviar.disabled = membros_ativos < 2
	if is_instance_valid(estado) and membros_ativos < 2:
		estado.text = "Aguardando pelo menos mais um aventureiro para começar."

func _atualizar_aventura(dados: Dictionary) -> void:
	if not is_instance_valid(lista):
		return
	var estado_aventura: Dictionary = dados.get("estado", {})
	var mensagens: Array = estado_aventura.get("mensagens", [])
	lista.clear()
	if mensagens.is_empty():
		lista.append_text("[color=#c8b994]A aventura começa aqui. O grupo ainda não registrou nenhuma fala.[/color]")
		return
	for mensagem in mensagens:
		if not mensagem is Dictionary:
			continue
		var autor := str(mensagem.get("autor", "Aventureiro")).replace("[", "(").replace("]", ")")
		var texto := str(mensagem.get("texto", "")).replace("[", "(").replace("]", ")")
		lista.append_text("[color=#e5c98e]%s:[/color] %s\n" % [autor, texto])

func _enviar(_texto: String = "") -> void:
	if not is_instance_valid(campo) or not is_instance_valid(botao_enviar):
		return
	var mensagem := campo.text.strip_edges()
	if mensagem.is_empty():
		estado.text = "Escreva uma mensagem antes de enviar."
		return
	botao_enviar.disabled = true
	RedeMultiplayer.enviar_mensagem_aventura_sala(mensagem)
	campo.clear()

func _resultado_envio(sucesso: bool, mensagem: String) -> void:
	if not is_instance_valid(estado):
		return
	estado.text = mensagem
	if is_instance_valid(botao_enviar):
		botao_enviar.disabled = membros_ativos < 2

func _desconectar() -> void:
	RedeMultiplayer.desconectar()
	get_tree().change_scene_to_file("res://scenes/conexao_multiplayer.tscn")
