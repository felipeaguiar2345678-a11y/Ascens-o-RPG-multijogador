extends CharacterBody2D

@export var velocidade: float = 150.0

func _physics_process(_delta: float) -> void:
	var direcao := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direcao.normalized() * velocidade
	move_and_slide()
