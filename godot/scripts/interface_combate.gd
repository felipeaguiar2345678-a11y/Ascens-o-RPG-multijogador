extends CanvasLayer

const SistemaCombate = preload("res://scripts/sistema_combate.gd")
## Interface de combate por turnos; apenas envia intenções ao servidor autoritativo.

var painel: PanelContainer
var titulo: Label
var barra_vida_jogador: ProgressBar
var texto_vida_jogador: Label
var barra_mana: ProgressBar
var texto_mana: Label
var barra_vida_inimigo: ProgressBar
var texto_vida_inimigo: Label
var historico: RichTextLabel
var mensagem: Label
var botoes: Array[Button] = []
var aguardando_resposta := false
var combate_ativo := false

func _ready() -> void:
	layer = 20
	_construir_interface()
	RedeMultiplayer.combate_atualizado.connect(_ao_atualizar_combate)
	RedeMultiplayer.combate_finalizado.connect(_ao_finalizar_combate)
	RedeMultiplayer.erro_combate.connect(_ao_erro_combate)
	visible = false

func _construir_interface() -> void:
	painel = PanelContainer.new()
	painel.name = "PainelCombate"
	painel.anchor_left = 0.08
	painel.anchor_top = 0.06
	painel.anchor_right = 0.92
	painel.anchor_bottom = 0.94
	painel.offset_left = 0
	painel.offset_top = 0
	painel.offset_right = 0
	painel.offset_bottom = 0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#171d25")
	estilo.border_color = Color("#b99a62")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	painel.add_theme_stylebox_override("panel", estilo)
	add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 7)
	painel.add_child(coluna)

	titulo = Label.new()
	titulo.text = "COMBATE"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 21)
	titulo.add_theme_color_override("font_color", Color("#f0d39b"))
	coluna.add_child(titulo)

	var jogador_linha := HBoxContainer.new()
	coluna.add_child(jogador_linha)
	texto_vida_jogador = Label.new()
	texto_vida_jogador.custom_minimum_size.x = 100
	jogador_linha.add_child(texto_vida_jogador)
	barra_vida_jogador = _criar_barra(Color("#b94c4c"))
	jogador_linha.add_child(barra_vida_jogador)

	var mana_linha := HBoxContainer.new()
	coluna.add_child(mana_linha)
	texto_mana = Label.new()
	texto_mana.custom_minimum_size.x = 100
	mana_linha.add_child(texto_mana)
	barra_mana = _criar_barra(Color("#477fc2"))
	mana_linha.add_child(barra_mana)

	var inimigo_linha := HBoxContainer.new()
	coluna.add_child(inimigo_linha)
	texto_vida_inimigo = Label.new()
	texto_vida_inimigo.custom_minimum_size.x = 100
	inimigo_linha.add_child(texto_vida_inimigo)
	barra_vida_inimigo = _criar_barra(Color("#a34b42"))
	inimigo_linha.add_child(barra_vida_inimigo)

	var separador := HSeparator.new()
	coluna.add_child(separador)
	var rotulo_historico := Label.new()
	rotulo_historico.text = "Aconteceu na batalha"
	rotulo_historico.add_theme_color_override("font_color", Color("#d9c59e"))
	coluna.add_child(rotulo_historico)
	historico = RichTextLabel.new()
	historico.bbcode_enabled = false
	historico.scroll_following = true
	historico.size_flags_vertical = Control.SIZE_EXPAND_FILL
	historico.custom_minimum_size.y = 75
	coluna.add_child(historico)

	mensagem = Label.new()
	mensagem.text = "Escolha sua ação."
	mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(mensagem)

	var acoes := GridContainer.new()
	acoes.columns = 2
	acoes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_child(acoes)
	_adicionar_botao(acoes, "Atacar", SistemaCombate.ACAO_ATAQUE)
	_adicionar_botao(acoes, "Usar magia (8 PM)", SistemaCombate.ACAO_MAGIA)
	_adicionar_botao(acoes, "Defender", SistemaCombate.ACAO_DEFENDER)
	_adicionar_botao(acoes, "Esquivar", SistemaCombate.ACAO_ESQUIVAR)

	var fechar := Button.new()
	fechar.text = "Fechar resultado"
	fechar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fechar.pressed.connect(_fechar_resultado)
	coluna.add_child(fechar)
	fechar.visible = false
	fechar.name = "BotaoFecharResultado"

func _criar_barra(cor: Color) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(100, 18)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.show_percentage = false
	barra.add_theme_stylebox_override("fill", _estilo_barra(cor))
	barra.add_theme_stylebox_override("background", _estilo_barra(Color("#343b46")))
	return barra

func _estilo_barra(cor: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_corner_radius_all(3)
	return estilo

func _adicionar_botao(conteiner: GridContainer, rotulo: String, acao: String) -> void:
	var botao := Button.new()
	botao.text = rotulo
	botao.custom_minimum_size = Vector2(0, 38)
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao.pressed.connect(_solicitar_acao.bind(acao))
	conteiner.add_child(botao)
	botoes.append(botao)

func _solicitar_acao(acao: String) -> void:
	if not combate_ativo or aguardando_resposta:
		return
	aguardando_resposta = true
	_atualizar_botoes()
	mensagem.text = "Aguardando resposta do servidor..."
	RedeMultiplayer.solicitar_acao_combate(acao)

func _ao_atualizar_combate(estado: Dictionary) -> void:
	combate_ativo = str(estado.get("status", "")) == "em_andamento"
	aguardando_resposta = false
	visible = true
	var jogador: Dictionary = estado.get("jogador", {})
	var inimigo: Dictionary = estado.get("inimigo", {})
	titulo.text = "BATALHA — %s" % str(inimigo.get("nome", "Criatura"))
	_atualizar_barra(barra_vida_jogador, texto_vida_jogador, "Vida", int(jogador.get("vida", 0)), int(jogador.get("vidaMaxima", 1)))
	_atualizar_barra(barra_mana, texto_mana, "Mana", int(jogador.get("mana", 0)), int(jogador.get("manaMaxima", 1)))
	_atualizar_barra(barra_vida_inimigo, texto_vida_inimigo, "Inimigo", int(inimigo.get("vida", 0)), int(inimigo.get("vidaMaxima", 1)))
	var eventos: Array = estado.get("historico", [])
	historico.text = "\n".join(PackedStringArray(eventos.map(func(item): return str(item))))
	if combate_ativo:
		mensagem.text = "Sua vez. Escolha uma ação."
	else:
		mensagem.text = "A batalha terminou. Aguarde o resultado confirmado pelo servidor."
	_atualizar_botoes()
	_botao_fechar().visible = false

func _atualizar_barra(barra: ProgressBar, rotulo: Label, nome: String, atual: int, maximo: int) -> void:
	barra.max_value = maxi(1, maximo)
	barra.value = clampi(atual, 0, maxi(1, maximo))
	rotulo.text = "%s %d/%d" % [nome, atual, maximo]

func _ao_finalizar_combate(status: String, drops: Array) -> void:
	combate_ativo = false
	aguardando_resposta = false
	_atualizar_botoes()
	if status == "vitoria":
		mensagem.text = "Vitória! Recompensas recebidas: %d." % drops.size()
	else:
		mensagem.text = "Você foi derrotado. Seus recursos foram restaurados."
	_botao_fechar().visible = true

func _ao_erro_combate(texto: String) -> void:
	aguardando_resposta = false
	mensagem.text = texto
	_atualizar_botoes()

func _atualizar_botoes() -> void:
	for botao in botoes:
		botao.disabled = not combate_ativo or aguardando_resposta

func _botao_fechar() -> Button:
	return painel.get_node("VBoxContainer/BotaoFecharResultado") as Button

func _fechar_resultado() -> void:
	if combate_ativo:
		return
	visible = false
	historico.clear()
	mensagem.text = ""
