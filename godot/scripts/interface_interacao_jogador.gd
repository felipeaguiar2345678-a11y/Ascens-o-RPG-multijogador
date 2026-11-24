extends CanvasLayer
## Menu contextual de jogadores próximos, com convites Ally validados pelo servidor.

var painel: PanelContainer
var titulo: Label
var aviso: Label
var botao_ally: Button
var jogador_selecionado_peer_id := 0
var convite_recebido_id := ""
var dialogo_convite: ConfirmationDialog

func _ready() -> void:
	layer = 30
	_criar_interface()
	if not RedeMultiplayer.resultado_convite_ally.is_connected(_ao_resultado_convite_ally):
		RedeMultiplayer.resultado_convite_ally.connect(_ao_resultado_convite_ally)
	if not RedeMultiplayer.convite_ally_recebido.is_connected(_ao_receber_convite_ally):
		RedeMultiplayer.convite_ally_recebido.connect(_ao_receber_convite_ally)

func _criar_interface() -> void:
	painel = PanelContainer.new()
	painel.name = "PainelInteracaoJogador"
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.offset_left = -132.0
	painel.offset_right = 132.0
	painel.offset_top = -112.0
	painel.offset_bottom = 112.0
	painel.visible = false
	add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	painel.add_child(coluna)

	titulo = Label.new()
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 17)
	coluna.add_child(titulo)

	var descricao := Label.new()
	descricao.text = "Interações sociais"
	descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(descricao)

	botao_ally = Button.new()
	botao_ally.text = "Convidar para Ally"
	botao_ally.pressed.connect(_convidar_para_ally)
	coluna.add_child(botao_ally)

	_adicionar_acao_bloqueada(coluna, "Trocar itens")
	_adicionar_acao_bloqueada(coluna, "Chamar pro pau (PvP)")

	aviso = Label.new()
	aviso.text = "Convites exigem proximidade e a mesma sala."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", 10)
	coluna.add_child(aviso)

	var fechar := Button.new()
	fechar.text = "Fechar"
	fechar.pressed.connect(fechar_menu)
	coluna.add_child(fechar)

	dialogo_convite = ConfirmationDialog.new()
	dialogo_convite.title = "Convite para Ally"
	dialogo_convite.confirmed.connect(_aceitar_convite_recebido)
	dialogo_convite.canceled.connect(_recusar_convite_recebido)
	add_child(dialogo_convite)

func _adicionar_acao_bloqueada(coluna: VBoxContainer, texto: String) -> void:
	var botao := Button.new()
	botao.text = texto
	botao.disabled = true
	coluna.add_child(botao)

func abrir(peer_id: int, nome: String) -> void:
	if peer_id <= 0:
		return
	jogador_selecionado_peer_id = peer_id
	titulo.text = nome
	aviso.text = "Convites exigem proximidade e a mesma sala."
	botao_ally.disabled = false
	painel.visible = true

func _convidar_para_ally() -> void:
	if jogador_selecionado_peer_id <= 0:
		return
	botao_ally.disabled = true
	RedeMultiplayer.solicitar_convidar_para_ally(jogador_selecionado_peer_id)
	aviso.text = "Enviando convite..."

func _ao_resultado_convite_ally(sucesso: bool, mensagem: String) -> void:
	aviso.text = mensagem
	if is_instance_valid(botao_ally):
		botao_ally.disabled = false
	if not sucesso:
		push_warning(mensagem)

func _ao_receber_convite_ally(convite: Dictionary) -> void:
	convite_recebido_id = str(convite.get("id", ""))
	if convite_recebido_id.is_empty():
		return
	dialogo_convite.dialog_text = "%s convidou você para entrar na Ally. Deseja aceitar?" % str(convite.get("nome", "Um aventureiro"))
	dialogo_convite.popup_centered()

func _aceitar_convite_recebido() -> void:
	if not convite_recebido_id.is_empty():
		RedeMultiplayer.responder_convite_ally(convite_recebido_id, true)
	convite_recebido_id = ""

func _recusar_convite_recebido() -> void:
	if not convite_recebido_id.is_empty():
		RedeMultiplayer.responder_convite_ally(convite_recebido_id, false)
	convite_recebido_id = ""

func fechar_menu() -> void:
	jogador_selecionado_peer_id = 0
	painel.visible = false
