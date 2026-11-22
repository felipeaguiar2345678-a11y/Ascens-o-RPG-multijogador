extends StaticBody2D
class_name GuardiaoJormungandr

const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")
@export var espessura_corpo := 58.0
@export var raio_corpo := Geometria.RAIO_CORPO_SERPENTE

func _ready() -> void:
	# A serpente é uma presença visual e narrativa. Não bloqueia a exploração.
	collision_layer = 0
	collision_mask = 0
	queue_redraw()

func _pontos_do_corpo() -> PackedVector2Array:
	var pontos := PackedVector2Array()
	# Corpo acompanha a costa em uma circunferência contínua ao redor do continente.
	for i in range(97):
		var angulo := -PI / 2.0 + TAU * float(i) / 96.0
		pontos.append(Geometria.CENTRO_MUNDO + Vector2(cos(angulo), sin(angulo)) * raio_corpo)
	return pontos

func _draw() -> void:
	var pontos := _pontos_do_corpo()
	# Sombra profunda, placas externas e faixa central de escamas.
	draw_polyline(pontos, Color("#101d20", 0.96), espessura_corpo + 24.0, true)
	draw_polyline(pontos, Color("#263e38"), espessura_corpo + 8.0, true)
	draw_polyline(pontos, Color("#426b55"), espessura_corpo, true)
	draw_polyline(pontos, Color("#78916a"), espessura_corpo * 0.43, true)
	draw_polyline(pontos, Color("#b2a66a", 0.72), 3.0, true)

	# Escamas transversais distribuídas ao longo de todos os lados.
	for i in range(pontos.size() - 1):
		var inicio: Vector2 = pontos[i]
		var fim: Vector2 = pontos[i + 1]
		for marca in range(1, 5):
			var t := float(marca) / 5.0
			var centro := inicio.lerp(fim, t)
			var direcao := (fim - inicio).normalized()
			var normal := Vector2(-direcao.y, direcao.x)
			draw_line(centro - normal * 19.0, centro + normal * 19.0, Color("#b3b17a", 0.62), 3.0, true)
			draw_line(centro - normal * 9.0, centro + normal * 9.0, Color("#253d35", 0.8), 2.0, true)

	_desenhar_cabeca()

func _desenhar_cabeca() -> void:
	var cabeca := Geometria.CENTRO_MUNDO + Vector2(0.0, -raio_corpo)
	# Pescoço e crânio apontados para dentro do território.
	draw_line(cabeca + Vector2(-20, 42), cabeca + Vector2(-54, 104), Color("#203a32"), 42.0, true)
	draw_line(cabeca + Vector2(20, 42), cabeca + Vector2(54, 104), Color("#203a32"), 42.0, true)
	draw_circle(cabeca, 78.0, Color("#101d20"))
	draw_circle(cabeca, 68.0, Color("#315b49"))
	draw_colored_polygon(PackedVector2Array([
		cabeca + Vector2(-65, 8), cabeca + Vector2(-48, -38),
		cabeca + Vector2(-19, -61), cabeca + Vector2(0, -45),
		cabeca + Vector2(19, -61), cabeca + Vector2(48, -38),
		cabeca + Vector2(65, 8), cabeca + Vector2(0, 56)
	]), Color("#78936a"))
	# Chifres e focinho.
	draw_line(cabeca + Vector2(-39, -35), cabeca + Vector2(-70, -70), Color("#c0b17a"), 8.0, true)
	draw_line(cabeca + Vector2(39, -35), cabeca + Vector2(70, -70), Color("#c0b17a"), 8.0, true)
	draw_colored_polygon(PackedVector2Array([cabeca + Vector2(-34, 20), cabeca + Vector2(-24, 42), cabeca + Vector2(0, 48), cabeca + Vector2(24, 42), cabeca + Vector2(34, 20), cabeca + Vector2(0, 10)]), Color("#294638"))
	# Olhos dourados voltados para o mundo.
	for lado in [-1.0, 1.0]:
		var olho := cabeca + Vector2(29.0 * lado, -5)
		draw_circle(olho, 11.0, Color("#f0ce68"))
		draw_circle(olho, 4.0, Color("#201b14"))
		draw_circle(olho + Vector2(-2, -3), 2.0, Color("#fff0b0"))
