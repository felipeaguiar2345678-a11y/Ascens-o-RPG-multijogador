extends CharacterBody2D

@export var velocidade: float = 205.0
@export var distancia_seguimento: float = 28.0
var alvo: Node2D

func configurar_alvo(novo_alvo: Node2D) -> void:
	alvo = novo_alvo

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(alvo):
		velocity = Vector2.ZERO
		return
	var deslocamento := alvo.global_position - global_position
	if deslocamento.length() > distancia_seguimento:
		velocity = deslocamento.normalized() * velocidade
	else:
		velocity = Vector2.ZERO
	move_and_slide()
