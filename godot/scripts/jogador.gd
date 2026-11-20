extends CharacterBody2D

@export var velocidade: float = 165.0
var direcao_virtual := Vector2.ZERO
var _tempo_sincronizacao := 0.0
const INTERVALO_SINCRONIZACAO := 0.1

func definir_direcao_virtual(direcao: Vector2) -> void:
	direcao_virtual = direcao.limit_length(1.0)

func _physics_process(_delta: float) -> void:
	var direcao_teclado := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direcao := direcao_teclado if direcao_teclado.length_squared() > 0.0 else direcao_virtual
	velocity = direcao.normalized() * velocidade
	move_and_slide()
	if RedeMultiplayer.estado == RedeMultiplayer.EstadoConexao.CONECTADO:
		_tempo_sincronizacao += _delta
		if _tempo_sincronizacao >= INTERVALO_SINCRONIZACAO:
			_tempo_sincronizacao = 0.0
			RedeMultiplayer.enviar_posicao_jogador(global_position)
