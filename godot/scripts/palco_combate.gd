extends Control
## Palco 2D estilizado do combate por turnos. A lógica e o resultado continuam no servidor.

var nome_heroi := "Aventureiro"
var nome_inimigo := "Criatura"
var chefe := false
var _tempo := 0.0
var _impacto := 0.0
var _ultimo_evento := ""

func _ready() -> void:
	custom_minimum_size = Vector2(0, 112)
	set_process(true)

func configurar(jogador: Dictionary, inimigo: Dictionary) -> void:
	nome_heroi = str(jogador.get("nome", "Aventureiro"))
	nome_inimigo = str(inimigo.get("nome", "Criatura"))
	chefe = bool(inimigo.get("chefe", false))
	queue_redraw()

func registrar_evento(evento: String) -> void:
	if evento == _ultimo_evento:
		return
	_ultimo_evento = evento
	_impacto = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	_tempo += delta
	_impacto = move_toward(_impacto, 0.0, delta * 2.6)
	queue_redraw()

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color("#101722"), true)
	draw_rect(Rect2(Vector2(0, size.y * 0.68), Vector2(size.x, size.y * 0.32)), Color("#242a2d"), true)
	for i in range(12):
		var x := float(i) * size.x / 11.0
		draw_line(Vector2(x, size.y * 0.68), Vector2(x - 12, size.y), Color("#4b4941", 0.35), 1.0)
	# Arcos de pedra e luzes ao fundo.
	draw_rect(Rect2(Vector2(size.x * 0.43, 8), Vector2(size.x * 0.14, size.y * 0.55)), Color("#252b35"))
	draw_rect(Rect2(Vector2(size.x * 0.47, 16), Vector2(size.x * 0.06, size.y * 0.47)), Color("#111b27"))
	draw_circle(Vector2(size.x * 0.5, 24), 7.0, Color("#d2ad65", 0.8))
	var heroi := Vector2(size.x * 0.25, size.y * 0.63 + sin(_tempo * 3.0) * 1.5)
	var inimigo := Vector2(size.x * 0.75, size.y * 0.61 + sin(_tempo * 2.2 + 1.0) * 2.0)
	_desenhar_heroi(heroi)
	_desenhar_inimigo(inimigo)
	if _impacto > 0.05:
		var centro := Vector2(size.x * 0.5, size.y * 0.48)
		draw_circle(centro, 10.0 + (1.0 - _impacto) * 20.0, Color("#f6d28a", _impacto * 0.28))
		draw_arc(centro, 15.0 + (1.0 - _impacto) * 25.0, 0.0, TAU, 28, Color("#fff0c2", _impacto), 2.0)
	var fonte := ThemeDB.fallback_font
	if fonte:
		draw_string(fonte, Vector2(8, 14), nome_heroi, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.35, 10, Color("#e7d5b2"))
		draw_string(fonte, Vector2(size.x - 8, 14), nome_inimigo, HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.35, 10, Color("#f0b3a0"))

func _desenhar_heroi(p: Vector2) -> void:
	var sombra := Color("#090d12", 0.55)
	draw_ellipse_placeholder(p + Vector2(0, 8), Vector2(17, 5), sombra)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -5), p + Vector2(8, -5), p + Vector2(7, 14), p + Vector2(-7, 14)]), Color("#53677a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -4), p + Vector2(0, -9), p + Vector2(6, -4), p + Vector2(5, 5), p + Vector2(-5, 5)]), Color("#b38b59"))
	draw_rect(Rect2(p + Vector2(-5, -23), Vector2(10, 10)), Color("#d8b58a"))
	draw_rect(Rect2(p + Vector2(-6, -25), Vector2(12, 4)), Color("#403b38"))
	draw_line(p + Vector2(8, -3), p + Vector2(18, -19), Color("#cbd3d7"), 3.0)
	draw_line(p + Vector2(5, 0), p + Vector2(15, -12), Color("#78583d"), 2.0)
	draw_line(p + Vector2(-4, 13), p + Vector2(-7, 24), Color("#8a7156"), 4.0)
	draw_line(p + Vector2(4, 13), p + Vector2(7, 24), Color("#8a7156"), 4.0)

func _desenhar_inimigo(p: Vector2) -> void:
	var escala := 1.25 if chefe else 1.0
	draw_circle(p + Vector2(0, 4), 17.0 * escala, Color("#080d12", 0.48))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -8) * escala, p + Vector2(13, -8) * escala, p + Vector2(16, 12) * escala, p + Vector2(-15, 12) * escala]), Color("#754b48") if chefe else Color("#65734f"))
	draw_circle(p + Vector2(0, -15) * escala, 10.0 * escala, Color("#9a6250") if chefe else Color("#89936b"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -20) * escala, p + Vector2(-14, -31) * escala, p + Vector2(-3, -23) * escala]), Color("#c5a16b"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(8, -20) * escala, p + Vector2(14, -31) * escala, p + Vector2(3, -23) * escala]), Color("#c5a16b"))
	draw_circle(p + Vector2(-4, -16) * escala, 2.0 * escala, Color("#f4d16b"))
	draw_circle(p + Vector2(4, -16) * escala, 2.0 * escala, Color("#f4d16b"))
	draw_line(p + Vector2(-11, 4) * escala, p + Vector2(-19, 13) * escala, Color("#d3b18a"), 3.0)
	draw_line(p + Vector2(11, 4) * escala, p + Vector2(19, 13) * escala, Color("#d3b18a"), 3.0)

func draw_ellipse_placeholder(centro: Vector2, raios: Vector2, cor: Color) -> void:
	draw_set_transform(centro, 0.0, Vector2(raios.x / 8.0, raios.y / 8.0))
	draw_circle(Vector2.ZERO, 8.0, cor)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
