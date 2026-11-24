extends Control
## Cenário ilustrado procedural temporário para a aventura cooperativa.
const AVATAR_SCRIPT = preload("res://scripts/avatar_personagem.gd")

var _tempo := 0.0
var _participantes: Array = []
var _avatares: Array[Node2D] = []
var _nomes: Array[String] = []
var _encontro: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(320, 150)
	set_process(true)

func configurar_participantes(participantes: Array) -> void:
	_participantes.clear()
	_avatares.clear()
	_nomes.clear()
	for filho in get_children():
		filho.queue_free()
	for participante in participantes.slice(0, 4):
		if not participante is Dictionary:
			continue
		var visual: Dictionary = participante.get("visual", {}) if participante.get("visual", {}) is Dictionary else {}
		var avatar := Node2D.new()
		avatar.set_script(AVATAR_SCRIPT)
		add_child(avatar)
		avatar.call("configurar", visual)
		avatar.scale = avatar.scale * Vector2(2.0, 2.0)
		_avatares.append(avatar)
		_nomes.append(str(participante.get("nome", "Aventureiro")).substr(0, 18))
	_participantes = participantes.slice(0, 4)
	_ajustar_posicoes_avatares()
	queue_redraw()

## Recebe apenas o snapshot validado e sincronizado pelo servidor da sala.
func configurar_encontro(encontro: Dictionary) -> void:
	_encontro = encontro.duplicate(true) if bool(encontro.get("ativo", false)) else {}
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_ajustar_posicoes_avatares()

func _ajustar_posicoes_avatares() -> void:
	var quantidade := _avatares.size()
	if quantidade == 0:
		return
	var largura_util := size.x * 0.66
	var inicio := size.x * 0.16
	for indice in range(quantidade):
		var fracao := 0.5 if quantidade == 1 else float(indice) / float(quantidade - 1)
		_avatares[indice].position = Vector2(inicio + largura_util * fracao, size.y * 0.83)

func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()

func _desenhar_encontro(w: float, h: float) -> void:
	var painel := Rect2(Vector2(7, 7), Vector2(minf(w * 0.48, 190.0), minf(h * 0.39, 78.0)))
	draw_rect(painel, Color("#111820", 0.94), true)
	draw_rect(painel, Color("#b69a63"), false, 1.2)
	var fonte := ThemeDB.fallback_font
	if fonte:
		var nome := str(_encontro.get("nome", "Criatura desconhecida")).substr(0, 24)
		var rank := str(_encontro.get("rank", "?"))
		var nivel := int(_encontro.get("nivel", 1))
		draw_string(fonte, painel.position + Vector2(7, 17), nome, HORIZONTAL_ALIGNMENT_LEFT, painel.size.x - 14, 11, Color("#f2dfb6"))
		draw_string(fonte, painel.position + Vector2(7, 32), "Rank %s • Nível %d" % [rank, nivel], HORIZONTAL_ALIGNMENT_LEFT, painel.size.x - 14, 9, Color("#d4b77d"))
		var vida_maxima := maxi(1, int(_encontro.get("vidaMaxima", 1)))
		var vida_atual := clampi(int(_encontro.get("vidaAtual", vida_maxima)), 0, vida_maxima)
		var trilho := Rect2(painel.position + Vector2(7, 43), Vector2(painel.size.x - 14, 7))
		draw_rect(trilho, Color("#392b2b"), true)
		draw_rect(Rect2(trilho.position, Vector2(trilho.size.x * float(vida_atual) / float(vida_maxima), trilho.size.y)), Color("#a94747"), true)
		draw_string(fonte, painel.position + Vector2(7, 65), "Vida %d / %d" % [vida_atual, vida_maxima], HORIZONTAL_ALIGNMENT_LEFT, painel.size.x - 14, 8, Color("#e8d8c4"))
	# Silhueta provisória para indicar a presença da criatura até a arte original ser ligada.
	var centro := Vector2(w * 0.78, h * 0.58)
	var escala := minf(h * 0.23, 42.0)
	var cor := Color("#766d62")
	draw_circle(centro + Vector2(0, -escala * 0.35), escala * 0.38, cor)
	draw_colored_polygon(PackedVector2Array([
		centro + Vector2(-escala * 0.62, escala * 0.72),
		centro + Vector2(-escala * 0.42, -escala * 0.05),
		centro + Vector2(escala * 0.42, -escala * 0.05),
		centro + Vector2(escala * 0.62, escala * 0.72)
	]), cor.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([
		centro + Vector2(-escala * 0.25, -escala * 0.55),
		centro + Vector2(-escala * 0.7, -escala * 1.05),
		centro + Vector2(-escala * 0.55, -escala * 0.3)
	]), cor.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([
		centro + Vector2(escala * 0.25, -escala * 0.55),
		centro + Vector2(escala * 0.7, -escala * 1.05),
		centro + Vector2(escala * 0.55, -escala * 0.3)
	]), cor.lightened(0.18))

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
	var fonte := ThemeDB.fallback_font
	if fonte:
		for indice in range(_nomes.size()):
			var x := _avatares[indice].position.x
			draw_string(fonte, Vector2(x - 42, h * 0.98), _nomes[indice], HORIZONTAL_ALIGNMENT_CENTER, 84, 9, Color("#f0dfb8"))
	draw_colored_polygon(PackedVector2Array([Vector2(w*0.44,h),Vector2(w*0.56,h),Vector2(w*0.53,h*0.82),Vector2(w*0.47,h*0.82)]), Color("#756344"))
	if _encontro.is_empty():
		var fonte_ambiente := ThemeDB.fallback_font
		if fonte_ambiente:
			draw_string(fonte_ambiente, Vector2(8, h * 0.15), "Aventura compartilhada • aguardando acontecimento", HORIZONTAL_ALIGNMENT_LEFT, w * 0.7, 9, Color("#d5c8a8"))
	else:
		_desenhar_encontro(w, h)
	for i in range(9):
		var fase := _tempo * 0.8 + float(i) * 1.7
		var ponto := Vector2(w * (0.08 + float((i * 37) % 83) / 100.0), h * (0.35 + 0.32 * absf(sin(fase))))
		draw_circle(ponto, 1.2, Color("#e7d58a", 0.45 + 0.45 * absf(sin(fase))))
