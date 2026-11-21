extends CanvasLayer
## Interface provisória de inventário e equipamentos.
## Toda alteração é solicitada ao servidor; esta tela nunca modifica o perfil localmente.

const SistemaEquipamentos = preload("res://scripts/sistema_equipamentos.gd")

var painel: PanelContainer
var lista_inventario: VBoxContainer
var lista_equipados: VBoxContainer
var mensagem: Label
var botao_abrir: Button
var _perfil: Dictionary = {}

func _ready() -> void:
	_criar_interface()
	RedeMultiplayer.perfil_personagem_recebido.connect(_ao_receber_perfil)
	RedeMultiplayer.resultado_equipamento.connect(_ao_resultado_equipamento)
	if not RedeMultiplayer.perfil_personagem_atual.is_empty():
		_ao_receber_perfil(RedeMultiplayer.perfil_personagem_atual)

func _criar_interface() -> void:
	botao_abrir = Button.new()
	botao_abrir.text = "Mochila"
	botao_abrir.custom_minimum_size = Vector2(104, 42)
	botao_abrir.anchor_left = 1.0
	botao_abrir.anchor_right = 1.0
	botao_abrir.offset_left = -122.0
	botao_abrir.offset_right = -18.0
	botao_abrir.offset_top = 18.0
	botao_abrir.offset_bottom = 60.0
	botao_abrir.pressed.connect(_alternar_painel)
	add_child(botao_abrir)

	painel = PanelContainer.new()
	painel.name = "PainelInventarioEquipamentos"
	painel.anchor_left = 1.0
	painel.anchor_right = 1.0
	painel.anchor_top = 0.0
	painel.anchor_bottom = 0.0
	painel.offset_left = -310.0
	painel.offset_right = -16.0
	painel.offset_top = 70.0
	painel.offset_bottom = 520.0
	painel.visible = false
	add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 7)
	painel.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "INVENTÁRIO E EQUIPAMENTOS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 15)
	coluna.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "Equipamentos usados"
	coluna.add_child(subtitulo)

	var rolagem_equipados := ScrollContainer.new()
	rolagem_equipados.custom_minimum_size = Vector2(0, 145)
	rolagem_equipados.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(rolagem_equipados)
	lista_equipados = VBoxContainer.new()
	lista_equipados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_equipados.add_child(lista_equipados)

	var divisor := HSeparator.new()
	coluna.add_child(divisor)

	var subtitulo_itens := Label.new()
	subtitulo_itens.text = "Sua mochila"
	coluna.add_child(subtitulo_itens)

	var rolagem_itens := ScrollContainer.new()
	rolagem_itens.custom_minimum_size = Vector2(0, 175)
	rolagem_itens.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(rolagem_itens)
	lista_inventario = VBoxContainer.new()
	lista_inventario.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_itens.add_child(lista_inventario)

	mensagem = Label.new()
	mensagem.text = "As alterações são confirmadas pelo servidor."
	mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensagem.add_theme_font_size_override("font_size", 11)
	coluna.add_child(mensagem)

func _alternar_painel() -> void:
	painel.visible = not painel.visible
	if painel.visible:
		_atualizar_tela()

func _ao_receber_perfil(dados: Dictionary) -> void:
	_perfil = dados.duplicate(true)
	if is_instance_valid(painel) and painel.visible:
		_atualizar_tela()

func _ao_resultado_equipamento(sucesso: bool, texto: String) -> void:
	if not is_instance_valid(mensagem):
		return
	mensagem.text = texto
	mensagem.add_theme_color_override("font_color", Color("#9bd69b") if sucesso else Color("#f09b8d"))
	if sucesso:
		_perfil = RedeMultiplayer.perfil_personagem_atual.duplicate(true)
		_atualizar_tela()

func _atualizar_tela() -> void:
	if not is_instance_valid(lista_inventario) or not is_instance_valid(lista_equipados):
		return
	_limpar(lista_equipados)
	_limpar(lista_inventario)

	var equipamentos: Dictionary = _perfil.get("equipamentos", {})
	for slot in SistemaEquipamentos.SLOTS:
		var item_id := str(equipamentos.get(slot, ""))
		var linha := HBoxContainer.new()
		linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rotulo := Label.new()
		rotulo.text = "%s: %s" % [_nome_slot(slot), _nome_item(item_id)]
		rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rotulo.add_theme_font_size_override("font_size", 11)
		linha.add_child(rotulo)
		if not item_id.is_empty():
			var retirar := Button.new()
			retirar.text = "Retirar"
			retirar.custom_minimum_size = Vector2(66, 30)
			retirar.pressed.connect(_solicitar_desequipar.bind(slot))
			linha.add_child(retirar)
		lista_equipados.add_child(linha)

	var inventario: Array = _perfil.get("inventario", [])
	if inventario.is_empty():
		var vazio := Label.new()
		vazio.text = "Sua mochila está vazia."
		vazio.add_theme_font_size_override("font_size", 11)
		lista_inventario.add_child(vazio)
		return

	for item in inventario:
		if not item is Dictionary:
			continue
		var item_id := str(item.get("itemId", ""))
		var quantidade := int(item.get("quantidade", 0))
		if item_id.is_empty() or quantidade <= 0:
			continue
		var linha_item := HBoxContainer.new()
		linha_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var descricao := Label.new()
		descricao.text = "%s ×%d" % [str(item.get("nome", _nome_item(item_id))), quantidade]
		descricao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		descricao.add_theme_font_size_override("font_size", 11)
		linha_item.add_child(descricao)
		if not SistemaEquipamentos.obter(item_id).is_empty():
			var equipar := Button.new()
			equipar.text = "Usar"
			equipar.custom_minimum_size = Vector2(58, 30)
			equipar.pressed.connect(_solicitar_equipar.bind(item_id))
			linha_item.add_child(equipar)
		lista_inventario.add_child(linha_item)

func _solicitar_equipar(item_id: String) -> void:
	if RedeMultiplayer.estado != RedeMultiplayer.EstadoConexao.CONECTADO:
		mensagem.text = "Conecte-se ao mundo para alterar equipamentos."
		return
	mensagem.text = "Enviando pedido ao servidor..."
	RedeMultiplayer.solicitar_equipar_item(item_id)

func _solicitar_desequipar(slot: String) -> void:
	if RedeMultiplayer.estado != RedeMultiplayer.EstadoConexao.CONECTADO:
		mensagem.text = "Conecte-se ao mundo para alterar equipamentos."
		return
	mensagem.text = "Enviando pedido ao servidor..."
	RedeMultiplayer.solicitar_desequipar_slot(slot)

func _nome_slot(slot: String) -> String:
	var nomes := {
		"mao_principal":"Mão principal", "mao_secundaria":"Mão secundária",
		"cabeca":"Cabeça", "torso":"Torso", "pernas":"Pernas",
		"maos":"Mãos", "pes":"Pés", "costas":"Costas",
		"anel":"Anel", "colar":"Colar", "bracelete":"Bracelete", "cinto":"Cinto"
	}
	return str(nomes.get(slot, slot))

func _nome_item(item_id: String) -> String:
	if item_id.is_empty():
		return "Vazio"
	var definicao := SistemaEquipamentos.obter(item_id)
	return str(definicao.get("nome", item_id)) if not definicao.is_empty() else item_id

func _limpar(container: Node) -> void:
	for filho in container.get_children():
		filho.queue_free()
