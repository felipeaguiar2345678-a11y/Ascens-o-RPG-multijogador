extends CanvasLayer
## Menu contextual de jogadores próximos, com convites Ally validados pelo servidor.

var painel: PanelContainer
var titulo: Label
var aviso: Label
var botao_ally: Button
var jogador_selecionado_peer_id := 0
var convite_recebido_id := ""
var dialogo_convite: ConfirmationDialog
var painel_ally: PanelContainer
var lista_membros_ally: VBoxContainer
var estado_ally: Dictionary = {}
var botao_sair_ally: Button
var dialogo_saida_ally: ConfirmationDialog

var botao_troca: Button
var dialogo_proposta_troca: AcceptDialog
var dialogo_recebida_troca: ConfirmationDialog
var campo_item_oferecido: LineEdit
var campo_qtd_oferecida: SpinBox
var campo_item_pedido: LineEdit
var campo_qtd_pedida: SpinBox
var proposta_troca_recebida_id := ""

func _ready() -> void:
	layer = 30
	_criar_interface()
	if not RedeMultiplayer.resultado_convite_ally.is_connected(_ao_resultado_convite_ally):
		RedeMultiplayer.resultado_convite_ally.connect(_ao_resultado_convite_ally)
	if not RedeMultiplayer.convite_ally_recebido.is_connected(_ao_receber_convite_ally):
		RedeMultiplayer.convite_ally_recebido.connect(_ao_receber_convite_ally)
	if not RedeMultiplayer.ally_atualizada.is_connected(_ao_atualizar_ally):
		RedeMultiplayer.ally_atualizada.connect(_ao_atualizar_ally)
	_criar_painel_ally()

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

	botao_troca = Button.new()
	botao_troca.text = "Propor troca"
	botao_troca.pressed.connect(_abrir_proposta_troca)
	coluna.add_child(botao_troca)
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

	dialogo_saida_ally = ConfirmationDialog.new()
	dialogo_saida_ally.title = "Sair da Ally"
	dialogo_saida_ally.dialog_text = "Deseja sair da Ally? Se você for o líder, outro integrante assumirá a liderança."
	dialogo_saida_ally.confirmed.connect(_sair_da_ally)
	add_child(dialogo_saida_ally)
	_criar_dialogos_troca()
	if not RedeMultiplayer.proposta_troca_recebida.is_connected(_ao_receber_proposta_troca):
		RedeMultiplayer.proposta_troca_recebida.connect(_ao_receber_proposta_troca)
	if not RedeMultiplayer.resultado_troca.is_connected(_ao_resultado_troca):
		RedeMultiplayer.resultado_troca.connect(_ao_resultado_troca)


func _criar_painel_ally() -> void:
	painel_ally = PanelContainer.new()
	painel_ally.name = "PainelAlly"
	painel_ally.set_anchors_preset(Control.PRESET_TOP_LEFT)
	painel_ally.offset_left = 14.0
	painel_ally.offset_top = 14.0
	painel_ally.offset_right = 218.0
	painel_ally.offset_bottom = 150.0
	add_child(painel_ally)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	painel_ally.add_child(coluna)
	var cabecalho := Label.new()
	cabecalho.text = "Minha Ally"
	cabecalho.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cabecalho.add_theme_font_size_override("font_size", 15)
	coluna.add_child(cabecalho)
	lista_membros_ally = VBoxContainer.new()
	lista_membros_ally.add_theme_constant_override("separation", 3)
	coluna.add_child(lista_membros_ally)
	botao_sair_ally = Button.new()
	botao_sair_ally.text = "Sair da Ally"
	botao_sair_ally.visible = false
	botao_sair_ally.pressed.connect(_confirmar_saida_ally)
	coluna.add_child(botao_sair_ally)
	var vazio := Label.new()
	vazio.name = "EstadoAllyVazia"
	vazio.text = "Você ainda não tem uma Ally."
	vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(vazio)

func _ao_atualizar_ally(ally: Dictionary) -> void:
	estado_ally = ally.duplicate(true)
	if is_instance_valid(botao_sair_ally):
		botao_sair_ally.visible = not estado_ally.get("membros", []).is_empty()
	if not is_instance_valid(lista_membros_ally):
		return
	for filho in lista_membros_ally.get_children():
		filho.queue_free()
	var membros: Array = estado_ally.get("membros", [])
	for membro in membros:
		if not membro is Dictionary:
			continue
		var linha := Label.new()
		var nome := str(membro.get("nome", "Aventureiro"))
		var peer_id := int(membro.get("peerId", 0))
		var lider := bool(membro.get("lider", false))
		linha.text = "• %s%s" % [nome, " (Líder)" if lider else ""]
		linha.tooltip_text = "Jogador conectado: %d" % peer_id
		lista_membros_ally.add_child(linha)
	var vazio := painel_ally.find_child("EstadoAllyVazia", true, false)
	if vazio is Label:
		vazio.visible = membros.is_empty()

func _confirmar_saida_ally() -> void:
	if not estado_ally.get("membros", []).is_empty():
		dialogo_saida_ally.popup_centered()

func _sair_da_ally() -> void:
	botao_sair_ally.disabled = true
	RedeMultiplayer.solicitar_sair_da_ally()


func _criar_dialogos_troca() -> void:
	dialogo_proposta_troca = AcceptDialog.new()
	dialogo_proposta_troca.title = "Propor troca"
	var coluna := VBoxContainer.new()
	dialogo_proposta_troca.add_child(coluna)
	campo_item_oferecido = LineEdit.new()
	campo_item_oferecido.placeholder_text = "ID do item que você oferece"
	coluna.add_child(campo_item_oferecido)
	campo_qtd_oferecida = SpinBox.new()
	campo_qtd_oferecida.min_value = 1
	campo_qtd_oferecida.max_value = 999
	campo_qtd_oferecida.value = 1
	coluna.add_child(campo_qtd_oferecida)
	campo_item_pedido = LineEdit.new()
	campo_item_pedido.placeholder_text = "ID do item que você deseja receber"
	coluna.add_child(campo_item_pedido)
	campo_qtd_pedida = SpinBox.new()
	campo_qtd_pedida.min_value = 1
	campo_qtd_pedida.max_value = 999
	campo_qtd_pedida.value = 1
	coluna.add_child(campo_qtd_pedida)
	dialogo_proposta_troca.confirmed.connect(_enviar_proposta_troca)
	add_child(dialogo_proposta_troca)
	dialogo_recebida_troca = ConfirmationDialog.new()
	dialogo_recebida_troca.title = "Proposta de troca"
	dialogo_recebida_troca.confirmed.connect(_aceitar_proposta_troca)
	dialogo_recebida_troca.canceled.connect(_recusar_proposta_troca)
	add_child(dialogo_recebida_troca)

func _abrir_proposta_troca() -> void:
	if jogador_selecionado_peer_id <= 0:
		return
	campo_item_oferecido.text = ""
	campo_item_pedido.text = ""
	dialogo_proposta_troca.popup_centered(Vector2i(360, 300))

func _enviar_proposta_troca() -> void:
	var item_a := campo_item_oferecido.text.strip_edges()
	var item_b := campo_item_pedido.text.strip_edges()
	if item_a.is_empty() or item_b.is_empty():
		aviso.text = "Informe os IDs dos dois itens."
		return
	botao_troca.disabled = true
	RedeMultiplayer.solicitar_propor_troca(jogador_selecionado_peer_id, item_a, int(campo_qtd_oferecida.value), item_b, int(campo_qtd_pedida.value))
	aviso.text = "Enviando proposta de troca..."

func _ao_receber_proposta_troca(proposta: Dictionary) -> void:
	proposta_troca_recebida_id = str(proposta.get("id", ""))
	if proposta_troca_recebida_id.is_empty():
		return
	dialogo_recebida_troca.dialog_text = "%s oferece %d × %s em troca de %d × %s. Aceitar?" % [str(proposta.get("nome", "Aventureiro")), int(proposta.get("quantidadeOferecida", 0)), str(proposta.get("itemOferecido", "")), int(proposta.get("quantidadeSolicitada", 0)), str(proposta.get("itemSolicitado", ""))]
	dialogo_recebida_troca.popup_centered()

func _aceitar_proposta_troca() -> void:
	if not proposta_troca_recebida_id.is_empty():
		RedeMultiplayer.responder_proposta_troca(proposta_troca_recebida_id, true)
	proposta_troca_recebida_id = ""

func _recusar_proposta_troca() -> void:
	if not proposta_troca_recebida_id.is_empty():
		RedeMultiplayer.responder_proposta_troca(proposta_troca_recebida_id, false)
	proposta_troca_recebida_id = ""

func _ao_resultado_troca(sucesso: bool, mensagem: String) -> void:
	aviso.text = mensagem
	if is_instance_valid(botao_troca):
		botao_troca.disabled = false
	if not sucesso:
		push_warning(mensagem)

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
	if is_instance_valid(botao_sair_ally):
		botao_sair_ally.disabled = false
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
