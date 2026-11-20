extends CharacterBody2D

@export var velocidade: float = 150.0

func _physics_process(_delta: float) -> void:
	var direcao := Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	if direcao == Vector2.ZERO:
		direcao = _ler_controles_teclado()
	velocity = direcao.normalized() * velocidade
	move_and_slide()

func _ler_controles_teclado() -> Vector2:
	return Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
