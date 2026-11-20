extends StaticBody2D
class_name GuardiaoJormungandr

@export var tamanho_mundo := Vector2(2400.0, 1600.0)
@export var espessura_corpo := 66.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_criar_colisoes_do_perimetro()
	queue_redraw()

func _pontos_do_corpo() -> PackedVector2Array:
	var margem := espessura_corpo * 0.5
	return PackedVector2Array([
		Vector2(margem, margem),
		Vector2(tamanho_mundo.x * 0.25, margem),
		Vector2(tamanho_mundo.x * 0.5, margem),
		Vector2(tamanho_mundo.x * 0.75, margem),
		Vector2(tamanho_mundo.x - margem, margem),
		Vector2(tamanho_mundo.x - margem, tamanho_mundo.y * 0.25),
		Vector2(tamanho_mundo.x - margem, tamanho_mundo.y * 0.5),
		Vector2(tamanho_mundo.x - margem, tamanho_mundo.y * 0.75),
		Vector2(tamanho_mundo.x - margem, tamanho_mundo.y - margem),
		Vector2(tamanho_mundo.x * 0.75, tamanho_mundo.y - margem),
		Vector2(tamanho_mundo.x * 0.5, tamanho_mundo.y - margem),
		Vector2(tamanho_mundo.x * 0.25, tamanho_mundo.y - margem),
		Vector2(margem, tamanho_mundo.y - margem),
		Vector2(margem, tamanho_mundo.y * 0.75),
		Vector2(margem, tamanho_mundo.y * 0.5),
		Vector2(margem, tamanho_mundo.y * 0.25),
		Vector2(margem, margem)
	])

func _criar_colisoes_do_perimetro() -> void:
	var metade := espessura_corpo * 0.5
	_criar_barreira(Vector2(tamanho_mundo.x * 0.5, metade), Vector2(tamanho_mundo.x, espessura_corpo))
	_criar_barreira(Vector2(tamanho_mundo.x * 0.5, tamanho_mundo.y - metade), Vector2(tamanho_mundo.x, espessura_corpo))
	_criar_barreira(Vector2(metade, tamanho_mundo.y * 0.5), Vector2(espessura_corpo, tamanho_mundo.y))
	_criar_barreira(Vector2(tamanho_mundo.x - metade, tamanho_mundo.y * 0.5), Vector2(espessura_corpo, tamanho_mundo.y))

func _criar_barreira(posicao: Vector2, dimensao: Vector2) -> void:
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = dimensao
	forma.shape = retangulo
	forma.position = posicao
	add_child(forma)

func _draw() -> void:
	var pontos := _pontos_do_corpo()
	draw_polyline(pontos, Color("#172b2c"), espessura_corpo + 18.0, true)
	draw_polyline(pontos, Color("#315b4d"), espessura_corpo, true)
	draw_polyline(pontos, Color("#62836a"), espessura_corpo * 0.48, true)
	# Marcas de escamas ao longo das curvas do corpo.
	for i in range(1, 16):
		var t := float(i) / 16.0
		var p := Vector2(espessura_corpo * 0.5, tamanho_mundo.y * t)
		draw_arc(p, 22.0, -1.0, 1.0, 12, Color("#a5a66e", 0.7), 4.0)
	# Cabeça colossal no centro da borda norte.
	var cabeca := Vector2(tamanho_mundo.x * 0.5, espessura_corpo * 0.5)
	draw_circle(cabeca, 70.0, Color("#172b2c"))
	draw_circle(cabeca, 58.0, Color("#426c58"))
	draw_polygon(PackedVector2Array([
		cabeca + Vector2(-52, 10), cabeca + Vector2(-35, -48),
		cabeca + Vector2(0, -62), cabeca + Vector2(35, -48),
		cabeca + Vector2(52, 10), cabeca + Vector2(0, 42)
	]), PackedColorArray([Color("#78936a")]))
	# Olhos dourados voltados para o território.
	draw_circle(cabeca + Vector2(-25, 4), 8.0, Color("#e9c45d"))
	draw_circle(cabeca + Vector2(25, 4), 8.0, Color("#e9c45d"))
	draw_circle(cabeca + Vector2(-25, 4), 3.0, Color("#211b17"))
	draw_circle(cabeca + Vector2(25, 4), 3.0, Color("#211b17"))
