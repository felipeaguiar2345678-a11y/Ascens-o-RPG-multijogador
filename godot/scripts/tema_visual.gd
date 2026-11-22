extends RefCounted
## Identidade visual compartilhada: fantasia sombria, pedra, ouro antigo e azul arcano.

static func criar_tema() -> Theme:
	var tema := Theme.new()
	tema.default_font_size = 14
	tema.set_color("font_color", "Label", Color("#e8dfc9"))
	tema.set_color("font_shadow_color", "Label", Color("#100f16"))
	tema.set_color("font_color", "Button", Color("#f4e8cc"))
	tema.set_color("font_hover_color", "Button", Color("#fff4d7"))
	tema.set_color("font_pressed_color", "Button", Color("#d6b56e"))
	tema.set_color("font_disabled_color", "Button", Color("#827d73"))
	tema.set_color("font_color", "LineEdit", Color("#f0e8d8"))
	tema.set_color("font_placeholder_color", "LineEdit", Color("#8f8a80"))
	tema.set_color("font_color", "OptionButton", Color("#f0e8d8"))
	tema.set_color("font_color", "ProgressBar", Color("#f5e8c9"))
	var painel := _caixa(Color("#171923"), Color("#75613e"), 2, 9, 12)
	tema.set_stylebox("panel", "PanelContainer", painel)
	var normal := _caixa(Color("#30313b"), Color("#806b46"), 1, 6, 8)
	var hover := _caixa(Color("#45404a"), Color("#d2b36d"), 2, 6, 8)
	var pressionado := _caixa(Color("#202b37"), Color("#a98c56"), 2, 6, 8)
	var desabilitado := _caixa(Color("#24252c"), Color("#45434a"), 1, 6, 8)
	for tipo in ["Button", "OptionButton"]:
		tema.set_stylebox("normal", tipo, normal)
		tema.set_stylebox("hover", tipo, hover)
		tema.set_stylebox("pressed", tipo, pressionado)
		tema.set_stylebox("disabled", tipo, desabilitado)
	var campo := _caixa(Color("#20232d"), Color("#66583e"), 1, 5, 8)
	var foco := _caixa(Color("#242b38"), Color("#c6a35d"), 2, 5, 8)
	for tipo in ["LineEdit", "SpinBox"]:
		tema.set_stylebox("normal", tipo, campo)
		tema.set_stylebox("focus", tipo, foco)
		tema.set_stylebox("read_only", tipo, desabilitado)
	var preenchimento := _caixa(Color("#b18b4d"), Color("#d4b86e"), 1, 4, 2)
	var fundo_barra := _caixa(Color("#292c35"), Color("#4d4b48"), 1, 4, 2)
	tema.set_stylebox("fill", "ProgressBar", preenchimento)
	tema.set_stylebox("background", "ProgressBar", fundo_barra)
	return tema

static func aplicar(controle: Control) -> void:
	controle.theme = criar_tema()

static func _caixa(fundo: Color, borda: Color, largura: int, raio: int, margem: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = borda
	estilo.set_border_width_all(largura)
	estilo.set_corner_radius_all(raio)
	estilo.content_margin_left = margem
	estilo.content_margin_right = margem
	estilo.content_margin_top = margem
	estilo.content_margin_bottom = margem
	return estilo
