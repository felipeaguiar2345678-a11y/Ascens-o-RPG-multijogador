extends Control

const TEMA_VISUAL = preload("res://scripts/tema_visual.gd")
const AVATAR_SCRIPT = preload("res://scripts/avatar_personagem.gd")
const PALCO_SCRIPT = preload("res://scripts/palco_aventura_compartilhada.gd")

var lista: RichTextLabel
var campo: LineEdit
var estado: Label
var sala: Label
var botao_enviar: Button
var area_conversa: VBoxContainer
var grupo_participantes: HBoxContainer
var membros_ativos := 0
var conversa_aberta := false

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
	fundo.color = Color("#10151d")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for chave in ["margin_left", "margin_right"]:
		margem.add_theme_constant_override(chave, 10)
	margem.add_theme_constant_override("margin_top", 8)
	margem.add_theme_constant_override("margin_bottom", 8)
	add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	margem.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "AVENTURA COOPERATIVA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 19)
	coluna.add_child(titulo)
	sala = Label.new()
	sala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(sala)
	var palco := PALCO_SCRIPT.new()
	palco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(palco)
	var titulo_grupo := Label.new()
	titulo_grupo.text = "GRUPO DE AVENTUREIROS"
	titulo_grupo.add_theme_font_size_override("font_size", 12)
	coluna.add_child(titulo_grupo)
	var rolagem_grupo := ScrollContainer.new()
	rolagem_grupo.custom_minimum_size = Vector2(0, 112)
	coluna.add_child(rolagem_grupo)
	grupo_participantes = HBoxContainer.new()
	grupo_participantes.add_theme_constant_override("separation", 8)
	rolagem_grupo.add_child(grupo_participantes)
	var titulo_eventos := Label.new()
	titulo_eventos.text = "DIÁRIO DA AVENTURA"
	titulo_eventos.add_theme_font_size_override("font_size", 12)
	coluna.add_child(titulo_eventos)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.custom_minimum_size = Vector2(0, 54)
	coluna.add_child(rolagem)
	lista = RichTextLabel.new()
	lista.bbcode_enabled = true
	lista.fit_content = true
	lista.scroll_following = true
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.custom_minimum_size = Vector2(300, 50)
	rolagem.add_child(lista)
	var abrir_conversa := Button.new()
	abrir_conversa.text = "Abrir conversa do grupo"
	abrir_conversa.pressed.connect(_alternar_conversa)
	coluna.add_child(abrir_conversa)
	area_conversa = VBoxContainer.new()
	area_conversa.visible = false
	coluna.add_child(area_conversa)
	campo = LineEdit.new()
	campo.placeholder_text = "Converse com o grupo (até 300 caracteres)"
	campo.max_length = 300
	campo.text_submitted.connect(_enviar)
	area_conversa.add_child(campo)
	botao_enviar = Button.new()
	botao_enviar.text = "Enviar mensagem"
	botao_enviar.pressed.connect(_enviar)
	area_conversa.add_child(botao_enviar)
	estado = Label.new()
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(estado)
	var sair := Button.new()
	sair.text = "Sair da sala"
	sair.pressed.connect(_desconectar)
	coluna.add_child(sair)

func _alternar_conversa() -> void:
	conversa_aberta = not conversa_aberta
	area_conversa.visible = conversa_aberta

func _atualizar_sala(dados: Dictionary) -> void:
	if not is_instance_valid(sala):
		return
	membros_ativos = int(dados.get("jogadores", 0))
	sala.text = "Sala %s • %d/%d participantes" % [str(dados.get("codigo", "------")), membros_ativos, int(dados.get("limite", 4))]
	for filho in grupo_participantes.get_children():
		filho.queue_free()
	var participantes: Array = dados.get("participantes", [])
	for participante in participantes:
		if participante is Dictionary:
			_adicionar_cartao_participante(participante)
	if participantes.is_empty():
		var aguardando := Label.new()
		aguardando.text = "Aguardando aventureiros..."
		grupo_participantes.add_child(aguardando)
	if is_instance_valid(botao_enviar):
		botao_enviar.disabled = membros_ativos < 2
	if is_instance_valid(estado) and membros_ativos < 2:
		estado.text = "A aventura compartilhada começa quando pelo menos dois jogadores estiverem na sala."

func _adicionar_cartao_participante(participante: Dictionary) -> void:
	var cartao := PanelContainer.new()
	cartao.custom_minimum_size = Vector2(108, 0)
	grupo_participantes.add_child(cartao)
	var coluna_cartao := VBoxContainer.new()
	coluna_cartao.add_theme_constant_override("separation", 2)
	cartao.add_child(coluna_cartao)
	var visual: Dictionary = participante.get("visual", {}) if participante.get("visual", {}) is Dictionary else {}
	var moldura := SubViewportContainer.new()
	moldura.custom_minimum_size = Vector2(88, 68)
	moldura.stretch = true
	coluna_cartao.add_child(moldura)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 76)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	moldura.add_child(viewport)
	var avatar := Node2D.new()
	avatar.set_script(AVATAR_SCRIPT)
	viewport.add_child(avatar)
	avatar.position = Vector2(48, 55)
	avatar.configurar(visual)
	avatar.scale = Vector2(2.1, 2.1)
	var nome := Label.new()
	nome.text = str(participante.get("nome", "Aventureiro")) + (" ★" if bool(participante.get("anfitriao", false)) else "")
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.add_theme_font_size_override("font_size", 10)
	coluna_cartao.add_child(nome)
	var nivel := Label.new()
	nivel.text = "Nível %d" % int(visual.get("nivel", 1))
	nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nivel.add_theme_font_size_override("font_size", 9)
	coluna_cartao.add_child(nivel)
	_adicionar_barra(coluna_cartao, int(visual.get("vida", 0)), int(visual.get("vidaMaxima", 1)), Color("#a94c4c"))
	_adicionar_barra(coluna_cartao, int(visual.get("mana", 0)), int(visual.get("manaMaxima", 1)), Color("#4e83b5"))

func _adicionar_barra(pai: VBoxContainer, atual: int, maximo: int, cor: Color) -> void:
	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(0, 7)
	barra.show_percentage = false
	barra.max_value = maxi(1, maximo)
	barra.value = clampi(atual, 0, maxi(1, maximo))
	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = cor
	preenchimento.set_corner_radius_all(2)
	barra.add_theme_stylebox_override("fill", preenchimento)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("#252832")
	fundo.set_corner_radius_all(2)
	barra.add_theme_stylebox_override("background", fundo)
	pai.add_child(barra)

func _atualizar_aventura(dados: Dictionary) -> void:
	if not is_instance_valid(lista):
		return
	var estado_aventura: Dictionary = dados.get("estado", {})
	var mensagens: Array = estado_aventura.get("mensagens", [])
	lista.clear()
	if mensagens.is_empty():
		lista.append_text("[color=#c8b994]O diário está vazio. Os acontecimentos da aventura aparecerão aqui.[/color]")
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

func _resultado_envio(_sucesso: bool, mensagem: String) -> void:
	if not is_instance_valid(estado):
		return
	estado.text = mensagem
	if is_instance_valid(botao_enviar):
		botao_enviar.disabled = membros_ativos < 2

func _desconectar() -> void:
	RedeMultiplayer.desconectar()
	get_tree().change_scene_to_file("res://scenes/conexao_multiplayer.tscn")
