extends Node2D

signal interacao_solicitada(bau_id: String)

var bau_id := ""
var estado := "disfarcado"
var tem_pistas := false
var _tempo := 0.0
var _area: Area2D

func configurar(dados: Dictionary) -> void:
	bau_id = str(dados.get("id", ""))
	estado = str(dados.get("estado", "disfarcado"))
	tem_pistas = bool(dados.get("pistasVisuais", false))
	queue_redraw()
	_atualizar_rotulo()

func definir_posicao_mundo(posicao: Vector2) -> void:
	global_position = posicao

func _ready() -> void:
	z_index = 3
	_area = Area2D.new()
	_area.input_pickable = true
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(48, 42)
	forma.shape = retangulo
	_area.add_child(forma)
	_area.input_event.connect(_ao_input)
	add_child(_area)
	_atualizar_rotulo()

func _atualizar_rotulo() -> void:
	var rotulo := get_node_or_null("Rotulo") as Label
	if rotulo == null:
		rotulo = Label.new()
		rotulo.name = "Rotulo"
		rotulo.position = Vector2(-48, -40)
		rotulo.size = Vector2(96, 18)
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rotulo.add_theme_font_size_override("font_size", 9)
		rotulo.add_theme_color_override("font_color", Color("#f4e5c7"))
		rotulo.add_theme_color_override("font_shadow_color", Color("#17120e"))
		rotulo.add_theme_constant_override("shadow_offset_x", 1)
		rotulo.add_theme_constant_override("shadow_offset_y", 1)
		add_child(rotulo)
	rotulo.text = "Baú vazio" if estado == "derrotado" else ("Sendo investigado" if estado == "em_combate" else ("Baú suspeito" if tem_pistas else "Baú"))

func _ao_input(_viewport: Viewport, evento: InputEvent, _indice: int) -> void:
	var acionado := evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT
	acionado = acionado or (evento is InputEventScreenTouch and evento.pressed)
	if acionado and not bau_id.is_empty() and estado == "disfarcado":
		interacao_solicitada.emit(bau_id)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()

func _draw() -> void:
	if estado == "derrotado":
		draw_arc(Vector2.ZERO, 18, 0, TAU, 24, Color("#6f6a5e"), 2.0)
		draw_line(Vector2(-11,-8), Vector2(11,8), Color("#6f6a5e"), 2.0)
		return
	var pulsar := 1.0 + sin(_tempo * 2.2) * 0.025
	if estado == "em_combate":
		pulsar = 1.0 + sin(_tempo * 5.0) * 0.04
	draw_set_transform(Vector2(0, sin(_tempo * 3.0) * 0.6), 0.0, Vector2(pulsar,pulsar))
	# Baú de madeira com ferragens antigas, sem revelar que é um monstro.
	draw_colored_polygon(PackedVector2Array([Vector2(-19,-5),Vector2(-15,-15),Vector2(15,-15),Vector2(19,-5)]), Color("#4b3022"))
	draw_colored_polygon(PackedVector2Array([Vector2(-20,-5),Vector2(20,-5),Vector2(17,14),Vector2(-17,14)]), Color("#80502f"))
	draw_rect(Rect2(-18,-4,36,17), Color("#a16b3d"), true)
	draw_rect(Rect2(-18,-4,36,17), Color("#39271e"), false, 2.0)
	for x in [-12.0, 0.0, 12.0]:
		draw_line(Vector2(x,-3), Vector2(x,12), Color("#563722"), 2.0)
	draw_rect(Rect2(-3,-5,6,19), Color("#c5a45e"), true)
	draw_rect(Rect2(-3,-5,6,19), Color("#4b3823"), false, 1.0)
	draw_circle(Vector2(0,4), 2.0, Color("#f1d58a"))
	if tem_pistas:
		var brilho := 0.5 + sin(_tempo * 4.0) * 0.3
		draw_arc(Vector2.ZERO, 24, -0.7, 0.7, 12, Color(0.78,0.23,0.18,brilho), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
