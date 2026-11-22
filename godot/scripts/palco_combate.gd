extends Control
## Palco 2D estilizado do combate por turnos. A lógica e o resultado continuam no servidor.

var nome_heroi := "Aventureiro"
var nome_inimigo := "Criatura"
var chefe := false
var _tempo := 0.0
var _impacto := 0.0
var _ultimo_evento := ""
var _tipo_efeito := "impacto"
var _lado_efeito := "inimigo"
var _tempo_efeito := 0.0

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
	_tempo_efeito = 0.0
	var texto := evento.to_lower()
	_lado_efeito = "heroi" if ("recebe" in texto or "atinge o aventureiro" in texto or "jogador sofre" in texto) else "inimigo"
	if "magia" in texto or "místico" in texto or "mistico" in texto or "feitiço" in texto or "feitico" in texto:
		_tipo_efeito = "magia"
	elif "crítico" in texto or "critico" in texto:
		_tipo_efeito = "critico"
	elif "esquiv" in texto:
		_tipo_efeito = "esquiva"
	elif "defend" in texto or "bloque" in texto:
		_tipo_efeito = "defesa"
	else:
		_tipo_efeito = "fisico"
	queue_redraw()

func _process(delta: float) -> void:
	_tempo += delta
	_tempo_efeito += delta
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
		_desenhar_efeito_ataque(heroi, inimigo)
	var fonte := ThemeDB.fallback_font
	if fonte:
		draw_string(fonte, Vector2(8, 14), nome_heroi, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.35, 10, Color("#e7d5b2"))
		draw_string(fonte, Vector2(size.x - 8, 14), nome_inimigo, HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.35, 10, Color("#f0b3a0"))


func _desenhar_efeito_ataque(heroi: Vector2, inimigo: Vector2) -> void:
	var alvo := heroi if _lado_efeito == "heroi" else inimigo
	var origem := inimigo if _lado_efeito == "heroi" else heroi
	var progresso := clampf(_tempo_efeito / 0.48, 0.0, 1.0)
	var opacidade := _impacto
	if _tipo_efeito == "esquiva":
		var deslocamento := Vector2(-12 if _lado_efeito == "heroi" else 12, -5)
		draw_arc(alvo + deslocamento, 12.0 + progresso * 5.0, -1.2, 1.2, 18, Color("#9bd9e8", opacidade), 2.0)
		draw_line(alvo + deslocamento + Vector2(-5, -8), alvo + deslocamento + Vector2(5, 8), Color("#d7f4ff", opacidade), 2.0)
		return
	if _tipo_efeito == "defesa":
		draw_arc(alvo + Vector2(0, -5), 18.0, PI, TAU, 24, Color("#8fb9cf", opacidade), 3.0)
		draw_line(alvo + Vector2(-12, -5), alvo + Vector2(0, -18), Color("#d7e8f0", opacidade), 2.0)
		draw_line(alvo + Vector2(0, -18), alvo + Vector2(12, -5), Color("#d7e8f0", opacidade), 2.0)
		return
	if _tipo_efeito == "magia":
		var ponto := origem.lerp(alvo, progresso)
		draw_line(origem, ponto, Color("#8069d8", opacidade * 0.55), 3.0)
		draw_circle(ponto, 4.0 + sin(_tempo_efeito * 28.0) * 1.2, Color("#a8dfff", opacidade))
		draw_arc(ponto, 8.0 + progresso * 5.0, 0.0, TAU, 20, Color("#d9b8ff", opacidade), 1.8)
		return
	var cor_corte := Color("#ffe2a1") if _tipo_efeito == "critico" else Color("#e9d3b2")
	var direcao := (alvo - origem).normalized()
	var centro := alvo + Vector2(0, -8)
	var abertura := 12.0 + (1.0 - progresso) * 10.0
	draw_line(centro + Vector2(-abertura, -8), centro + Vector2(abertura, 8), cor_corte * Color(1, 1, 1, opacidade), 2.5 if _tipo_efeito == "critico" else 1.8)
	draw_line(centro + Vector2(-abertura, 8), centro + Vector2(abertura, -8), Color("#fff4d5", opacidade * 0.8), 1.2)
	if _tipo_efeito == "critico":
		for i in range(4):
			var angulo := float(i) * TAU / 4.0 + _tempo_efeito * 5.0
			var raio := 13.0 + progresso * 8.0
			draw_circle(centro + Vector2(cos(angulo), sin(angulo)) * raio, 1.8, Color("#ffd36f", opacidade))

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
