extends Control
## Cenário ilustrado procedural temporário para a aventura cooperativa.
var _tempo := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(320, 150)
	set_process(true)

func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#111c25"))
	draw_rect(Rect2(0, 0, w, h * 0.48), Color("#1c3040"))
	draw_circle(Vector2(w * 0.78, h * 0.22), minf(h * 0.09, 13.0), Color("#d9d1b5"))
	draw_circle(Vector2(w * 0.78, h * 0.22), minf(h * 0.12, 17.0), Color("#d9d1b5", 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(0,h*0.58),Vector2(w*0.18,h*0.3),Vector2(w*0.36,h*0.56),Vector2(w*0.57,h*0.34),Vector2(w*0.82,h*0.59),Vector2(w,h*0.4),Vector2(w,h),Vector2(0,h)]), Color("#263c3b"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,h*0.7),Vector2(w*0.2,h*0.48),Vector2(w*0.42,h*0.68),Vector2(w*0.67,h*0.47),Vector2(w,h*0.69),Vector2(w,h),Vector2(0,h)]), Color("#1c302b"))
	var pedra := Color("#59605a")
	draw_rect(Rect2(w*0.43,h*0.43,w*0.025,h*0.2), pedra)
	draw_rect(Rect2(w*0.53,h*0.4,w*0.025,h*0.23), pedra.darkened(0.12))
	draw_rect(Rect2(w*0.41,h*0.42,w*0.16,h*0.035), pedra.lightened(0.12))
	for i in range(7):
		var x := w * (float(i) / 6.0)
		var altura := h * (0.28 + float((i * 7) % 4) * 0.035)
		var base := h * (0.79 + float(i % 3) * 0.025)
		draw_rect(Rect2(x - 2, base - altura * 0.48, 4, altura * 0.52), Color("#493d32"))
		draw_colored_polygon(PackedVector2Array([Vector2(x,base-altura),Vector2(x-altura*0.28,base-altura*0.42),Vector2(x+altura*0.28,base-altura*0.42)]), Color("#29483b") if i % 2 == 0 else Color("#34513d"))
	draw_rect(Rect2(0,h*0.82,w,h*0.18), Color("#263329"))
	draw_colored_polygon(PackedVector2Array([Vector2(w*0.44,h),Vector2(w*0.56,h),Vector2(w*0.53,h*0.82),Vector2(w*0.47,h*0.82)]), Color("#756344"))
	for i in range(9):
		var fase := _tempo * 0.8 + float(i) * 1.7
		var ponto := Vector2(w * (0.08 + float((i * 37) % 83) / 100.0), h * (0.35 + 0.32 * absf(sin(fase))))
		draw_circle(ponto, 1.2, Color("#e7d58a", 0.45 + 0.45 * absf(sin(fase))))
