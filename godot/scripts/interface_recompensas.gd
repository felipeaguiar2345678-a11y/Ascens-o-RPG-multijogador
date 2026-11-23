extends CanvasLayer
## Revelações de recompensa e eclosão. O servidor decide o resultado; esta interface apenas o apresenta.

const TEMA_VISUAL = preload("res://scripts/tema_visual.gd")

var fundo: ColorRect
var painel: PanelContainer
var coluna: VBoxContainer
var titulo: Label
var subtitulo: Label
var imagem: TextureRect
var nome_resultado: Label
var detalhes: Label
var lista_resultados: VBoxContainer
var botao_fechar: Button
var animacao: Tween

func _ready() -> void:
	layer = 30
	_criar_interface()
	RedeMultiplayer.resultado_ovo_chocado.connect(_ao_resultado_ovo)
	RedeMultiplayer.combate_finalizado.connect(_ao_combate_finalizado)

func _criar_interface() -> void:
	fundo = ColorRect.new()
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.015, 0.02, 0.035, 0.0)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	fundo.visible = false
	add_child(fundo)

	painel = PanelContainer.new()
	TEMA_VISUAL.aplicar(painel)
	painel.anchor_left = 0.5
	painel.anchor_right = 0.5
	painel.anchor_top = 0.5
	painel.anchor_bottom = 0.5
	painel.offset_left = -205.0
	painel.offset_right = 205.0
	painel.offset_top = -158.0
	painel.offset_bottom = 158.0
	painel.custom_minimum_size = Vector2(390, 300)
	painel.scale = Vector2(0.94, 0.94)
	painel.visible = false
	fundo.add_child(painel)

	coluna = VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	painel.add_child(coluna)

	titulo = Label.new()
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 17)
	coluna.add_child(titulo)

	subtitulo = Label.new()
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_font_size_override("font_size", 11)
	subtitulo.add_theme_color_override("font_color", Color("#c9bea5"))
	coluna.add_child(subtitulo)

	imagem = TextureRect.new()
	imagem.custom_minimum_size = Vector2(0, 112)
	imagem.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.visible = false
	coluna.add_child(imagem)

	nome_resultado = Label.new()
	nome_resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome_resultado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome_resultado.add_theme_font_size_override("font_size", 20)
	coluna.add_child(nome_resultado)

	detalhes = Label.new()
	detalhes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detalhes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalhes.add_theme_font_size_override("font_size", 11)
	coluna.add_child(detalhes)

	lista_resultados = VBoxContainer.new()
	lista_resultados.add_theme_constant_override("separation", 5)
	coluna.add_child(lista_resultados)

	botao_fechar = Button.new()
	botao_fechar.text = "Continuar"
	botao_fechar.custom_minimum_size.y = 38
	botao_fechar.pressed.connect(_fechar)
	coluna.add_child(botao_fechar)

func _ao_resultado_ovo(sucesso: bool, mensagem: String, invocacao: Dictionary) -> void:
	if not sucesso:
		_mostrar_mensagem("Eclosão não concluída", mensagem, Color("#e99a8c"))
		return
	_mostrar_eclosao(invocacao, mensagem)

func _mostrar_eclosao(invocacao: Dictionary, mensagem: String) -> void:
	_limpar_resultados()
	var raridade := str(invocacao.get("raridade", "comum")).to_lower()
	var cor := _cor_raridade(raridade)
	titulo.text = "✦ UM NOVO VÍNCULO DESPERTOU ✦"
	titulo.add_theme_color_override("font_color", cor)
	subtitulo.text = "O ovo se partiu... uma nova vida escolheu caminhar ao seu lado."
	nome_resultado.text = str(invocacao.get("nome", "Novo companheiro"))
	nome_resultado.add_theme_color_override("font_color", cor)
	var rank := str(invocacao.get("rank", "E"))
	detalhes.text = "RANK %s  •  %s\nVida %d/%d   |   Ataque %d   |   Defesa %d\nAgilidade %d   |   Poder mágico %d" % [
		rank, raridade.capitalize(),
		int(invocacao.get("vida", invocacao.get("vidaMaxima", 1))),
		int(invocacao.get("vidaMaxima", 1)),
		int(invocacao.get("ataque", 0)), int(invocacao.get("defesa", 0)),
		int(invocacao.get("agilidade", 0)), int(invocacao.get("poderMagico", 0))
	]
	var habilidades: Array = invocacao.get("habilidades", [])
	if not habilidades.is_empty():
		var nomes: Array[String] = []
		for habilidade in habilidades:
			if habilidade is Dictionary:
				nomes.append(str(habilidade.get("nome", habilidade.get("id", "Habilidade"))))
		_adicionar_linha("Habilidades herdadas: " + ", ".join(nomes), cor)
	else:
		_adicionar_linha("O companheiro ainda não possui habilidades registradas.", Color("#bdb5a5"))
	_configurar_imagem(invocacao)
	_abrir()
	if raridade in ["lendario", "mítico", "mitico", "ancestral", "unico", "único", "supremo"]:
		var brilho := create_tween().set_loops(3)
		brilho.tween_property(painel, "modulate", Color(1.0, 0.88, 0.58), 0.24)
		brilho.tween_property(painel, "modulate", Color.WHITE, 0.3)

func _ao_combate_finalizado(status: String, drops: Array) -> void:
	if drops.is_empty():
		return
	_mostrar_roleta(drops)

func _mostrar_roleta(drops: Array) -> void:
	_limpar_resultados()
	titulo.text = "✦ RESULTADO DAS RECOMPENSAS ✦"
	titulo.add_theme_color_override("font_color", Color("#e6c77f"))
	subtitulo.text = "Cada resultado abaixo foi calculado e confirmado pelo servidor."
	nome_resultado.text = "Recompensas da batalha"
	nome_resultado.add_theme_color_override("font_color", Color("#f0dfb9"))
	detalhes.text = "✓ recompensa obtida     X tentativa sem recompensa"
	imagem.visible = false
	for drop in drops:
		if not drop is Dictionary:
			continue
		var obtido := bool(drop.get("obtido", false))
		var chance := clampf(float(drop.get("chanceFinal", 0.0)) * 100.0, 0.0, 100.0)
		var texto := ("✓  " if obtido else "X  ") + str(drop.get("nome", drop.get("itemId", "Recompensa")))
		if obtido:
			texto += " ×%d" % int(drop.get("quantidade", 1))
		texto += "   •   chance %.2f%%" % chance
		_adicionar_linha(texto, _cor_raridade(str(drop.get("raridade", "comum"))) if obtido else Color("#a49b91"))
	_abrir()

func _mostrar_mensagem(cabecalho: String, texto: String, cor: Color) -> void:
	_limpar_resultados()
	titulo.text = cabecalho
	titulo.add_theme_color_override("font_color", cor)
	subtitulo.text = texto
	nome_resultado.text = ""
	detalhes.text = ""
	imagem.visible = false
	_abrir()

func _configurar_imagem(invocacao: Dictionary) -> void:
	imagem.texture = null
	imagem.visible = false
	for campo in ["detalhePath", "iconePath"]:
		var caminho := str(invocacao.get(campo, ""))
		if caminho.begins_with("res://") and ResourceLoader.exists(caminho):
			var recurso = load(caminho)
			if recurso is Texture2D:
				imagem.texture = recurso
				imagem.visible = true
				return

func _adicionar_linha(texto: String, cor: Color) -> void:
	var linha := Label.new()
	linha.text = texto
	linha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	linha.add_theme_font_size_override("font_size", 11)
	linha.add_theme_color_override("font_color", cor)
	lista_resultados.add_child(linha)

func _limpar_resultados() -> void:
	for filho in lista_resultados.get_children():
		filho.queue_free()

func _abrir() -> void:
	fundo.visible = true
	painel.visible = true
	fundo.color.a = 0.0
	painel.scale = Vector2(0.90, 0.90)
	painel.modulate = Color.WHITE
	if animacao != null and animacao.is_running():
		animacao.kill()
	animacao = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animacao.tween_property(fundo, "color:a", 0.88, 0.22)
	animacao.parallel().tween_property(painel, "scale", Vector2.ONE, 0.38)

func _fechar() -> void:
	if animacao != null and animacao.is_running():
		animacao.kill()
	animacao = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	animacao.tween_property(fundo, "color:a", 0.0, 0.16)
	animacao.parallel().tween_property(painel, "scale", Vector2(0.96, 0.96), 0.16)
	animacao.tween_callback(func() -> void:
		fundo.visible = false
		painel.visible = false
	)

func _cor_raridade(raridade: String) -> Color:
	match raridade.to_lower():
		"comum": return Color("#d1d0c8")
		"incomum": return Color("#8bd49a")
		"raro": return Color("#72b7ed")
		"epico", "épico": return Color("#c39aff")
		"lendario", "lendária", "lendario": return Color("#f1c56f")
		"mitico", "mítico", "ancestral": return Color("#f18cbd")
		"unico", "único", "supremo": return Color("#ff8b73")
		_: return Color("#e8dfc9")
