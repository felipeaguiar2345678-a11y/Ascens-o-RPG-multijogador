extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/jogador.tscn")

var jogador: CharacterBody2D

func _ready() -> void:
	jogador = PLAYER_SCENE.instantiate() as CharacterBody2D
	jogador.position = Vector2(320, 180)
	add_child(jogador)
	queue_redraw()

func _draw() -> void:
	# Base provisória de leitura espacial; será substituída por mapas e tilesets finais.
	var area := Rect2(Vector2.ZERO, Vector2(640, 360))
	draw_rect(area, Color("#294b3b"), true)
	for x in range(0, 641, 32):
		draw_line(Vector2(x, 0), Vector2(x, 360), Color(0.32, 0.49, 0.37, 0.28), 1.0)
	for y in range(0, 361, 32):
		draw_line(Vector2(0, y), Vector2(640, y), Color(0.32, 0.49, 0.37, 0.28), 1.0)
