extends StaticBody2D
class_name GuardiaoJormungandr

const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")
var _tempo_animacao := 0.0
@export var espessura_corpo := 58.0
@export var raio_corpo := Geometria.RAIO_CORPO_SERPENTE

func _process(delta: float) -> void:
	_tempo_animacao += delta
	queue_redraw()


func _ready() -> void:
	# A serpente é uma presença visual e narrativa. Não bloqueia a exploração.
	collision_layer = 0
	collision_mask = 0
	queue_redraw()

func _pontos_do_corpo() -> PackedVector2Array:
	var pontos := PackedVector2Array()
	# Corpo acompanha a costa em uma circunferência contínua ao redor do continente.
	for i in range(193):
		var angulo := -PI / 2.0 + TAU * float(i) / 192.0
		pontos.append(Geometria.CENTRO_MUNDO + Vector2(cos(angulo), sin(angulo)) * raio_corpo)
	return pontos

func _draw() -> void:
	var pontos := _pontos_do_corpo()
	# Sombra profunda, placas externas e faixa central de escamas.
	draw_polyline(pontos, Color("#0b1719"), espessura_corpo + 32.0, true)
	draw_polyline(pontos, Color("#172b29"), espessura_corpo + 18.0, true)
	draw_polyline(pontos, Color("#29483b"), espessura_corpo + 7.0, true)
	draw_polyline(pontos, Color("#426b55"), espessura_corpo, true)
	draw_polyline(pontos, Color("#78916a"), espessura_corpo * 0.38, true)
	draw_polyline(pontos, Color("#c1ad70", 0.78), 3.0, true)
	_desenhar_placas_escamas(pontos)
	_desenhar_cristas_dorsais(pontos)
	_desenhar_cabeca()


func _largura_local(progresso: float) -> float:
	var afinamento := absf(progresso - 0.5) * 2.0
	return espessura_corpo * lerpf(1.0, 0.42, pow(afinamento, 3.2))

func _desenhar_placas_escamas(pontos: PackedVector2Array) -> void:
	for i in range(0, pontos.size() - 1, 2):
		var centro: Vector2 = pontos[i].lerp(pontos[i + 1], 0.5)
		var direcao := (pontos[i + 1] - pontos[i]).normalized()
		var normal := Vector2(-direcao.y, direcao.x)
		var meia := _largura_local(float(i) / float(pontos.size() - 1)) * 0.43
		draw_colored_polygon(PackedVector2Array([
			centro - direcao * 5.0, centro - normal * meia,
			centro + direcao * 5.0, centro + normal * meia
		]), Color("#91a276", 0.78))
		draw_line(centro - normal * meia * 0.72, centro + normal * meia * 0.72, Color("#243d32", 0.92), 2.2, true)

func _desenhar_cristas_dorsais(pontos: PackedVector2Array) -> void:
	for i in range(4, pontos.size() - 4, 5):
		var tangente := (pontos[i + 1] - pontos[i - 1]).normalized()
		var normal := Vector2(-tangente.y, tangente.x)
		var altura := _largura_local(float(i) / float(pontos.size() - 1)) * 0.34
		var ponta: Vector2 = pontos[i] + normal * altura
		draw_colored_polygon(PackedVector2Array([
			pontos[i] - tangente * 5.0, ponta, pontos[i] + tangente * 5.0
		]), Color("#b2a66a", 0.92))
		draw_line(pontos[i], ponta, Color("#e0c987", 0.72), 1.5, true)

func _desenhar_cabeca() -> void:
	var cabeca := Geometria.CENTRO_MUNDO + Vector2(0.0, -raio_corpo + sin(_tempo_animacao * 1.25) * 5.0)
	# Pescoço e crânio apontados para dentro do território.
	draw_line(cabeca + Vector2(-20, 42), cabeca + Vector2(-54, 104), Color("#203a32"), 42.0, true)
	draw_line(cabeca + Vector2(20, 42), cabeca + Vector2(54, 104), Color("#203a32"), 42.0, true)
	draw_circle(cabeca, 82.0, Color("#0b1719"))
	draw_circle(cabeca, 72.0, Color("#29483b"))
	draw_colored_polygon(PackedVector2Array([
		cabeca + Vector2(-65, 8), cabeca + Vector2(-48, -38),
		cabeca + Vector2(-19, -61), cabeca + Vector2(0, -45),
		cabeca + Vector2(19, -61), cabeca + Vector2(48, -38),
		cabeca + Vector2(68, 8), cabeca + Vector2(42, 48), cabeca + Vector2(0, 62), cabeca + Vector2(-42, 48)
	]), Color("#78936a"))
	# Chifres e focinho.
	draw_line(cabeca + Vector2(-39, -35), cabeca + Vector2(-70, -70), Color("#c0b17a"), 8.0, true)
	draw_line(cabeca + Vector2(39, -35), cabeca + Vector2(70, -70), Color("#c0b17a"), 8.0, true)
	draw_colored_polygon(PackedVector2Array([cabeca + Vector2(-34, 20), cabeca + Vector2(-24, 42), cabeca + Vector2(0, 48), cabeca + Vector2(24, 42), cabeca + Vector2(34, 20), cabeca + Vector2(0, 10)]), Color("#294638"))
	# Olhos dourados voltados para o mundo.
	for lado in [-1.0, 1.0]:
		var olho := cabeca + Vector2(29.0 * lado, -5)
		draw_circle(olho, 11.0 + sin(_tempo_animacao * 2.0) * 0.8, Color("#f0ce68"))
		draw_circle(olho + Vector2(0, 9), 3.0, Color("#e5b85e", 0.35 + 0.15 * sin(_tempo_animacao * 2.0)))
		draw_circle(olho, 4.0, Color("#201b14"))
		draw_circle(olho + Vector2(-2, -3), 2.0, Color("#fff0b0"))
