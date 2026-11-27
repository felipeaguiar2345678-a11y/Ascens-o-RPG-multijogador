extends Control

signal direcao_alterada(direcao: Vector2)

@export var raio: float = 58.0
var pressionado := false
var id_toque := -1
var direcao := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(raio * 2.8, raio * 2.8)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not pressionado:
			pressionado = true
			id_toque = event.index
			_atualizar_direcao(event.position)
		elif not event.pressed and pressionado and event.index == id_toque:
			_finalizar_toque()
	elif event is InputEventScreenDrag and pressionado and event.index == id_toque:
		_atualizar_direcao(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressionado = true
			_atualizar_direcao(event.position)
		else:
			_finalizar_toque()
	elif event is InputEventMouseMotion and pressionado and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_atualizar_direcao(event.position)

func _atualizar_direcao(posicao: Vector2) -> void:
	var centro := size * 0.5
	var deslocamento := posicao - centro
	direcao = deslocamento.limit_length(raio) / raio
	direcao_alterada.emit(direcao)
	queue_redraw()
	accept_event()

func _finalizar_toque() -> void:
	pressionado = false
	id_toque = -1
	direcao = Vector2.ZERO
	direcao_alterada.emit(Vector2.ZERO)
	queue_redraw()
	accept_event()

func _draw() -> void:
	var centro := size * 0.5
	draw_circle(centro, raio, Color(0.04, 0.06, 0.07, 0.48))
	draw_arc(centro, raio, 0.0, TAU, 48, Color(0.85, 0.83, 0.72, 0.55), 3.0)
	draw_circle(centro + direcao * raio, raio * 0.38, Color(0.88, 0.82, 0.65, 0.78))
