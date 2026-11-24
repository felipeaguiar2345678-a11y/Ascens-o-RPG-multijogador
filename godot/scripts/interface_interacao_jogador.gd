extends CanvasLayer
## Menu contextual de jogadores próximos. Ações ficam bloqueadas até haver
## validação autoritativa correspondente no servidor.

var painel: PanelContainer
var titulo: Label
var jogador_selecionado_peer_id := 0

func _ready() -> void:
	layer = 30
	_criar_interface()

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

	_adicionar_acao_bloqueada(coluna, "Convidar para Ally")
	_adicionar_acao_bloqueada(coluna, "Trocar itens")
	_adicionar_acao_bloqueada(coluna, "Chamar pro pau (PvP)")

	var aviso := Label.new()
	aviso.text = "Ações aguardando validação segura do servidor."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", 10)
	coluna.add_child(aviso)

	var fechar := Button.new()
	fechar.text = "Fechar"
	fechar.pressed.connect(fechar_menu)
	coluna.add_child(fechar)

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
	painel.visible = true

func fechar_menu() -> void:
	jogador_selecionado_peer_id = 0
	painel.visible = false
