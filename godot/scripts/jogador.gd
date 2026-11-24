extends CharacterBody2D

@export var velocidade: float = 165.0
var direcao_virtual := Vector2.ZERO
var _tempo_sincronizacao := 0.0
const INTERVALO_SINCRONIZACAO := 0.1
const AVATAR = preload("res://scripts/avatar_personagem.gd")
const SistemaEquipamentos = preload("res://scripts/sistema_equipamentos.gd")
const SistemaColisoes = preload("res://scripts/sistema_colisoes_mundo.gd")
var _avatar_personagem: Node2D

func _ready() -> void:
	var provisoria := get_node_or_null("FormaProvisoria")
	if provisoria != null:
		provisoria.visible = false
	_avatar_personagem = AVATAR.new()
	_avatar_personagem.name = "AvatarPersonagem"
	add_child(_avatar_personagem)
	if not RedeMultiplayer.perfil_personagem_atual.is_empty():
		_avatar_personagem.configurar(RedeMultiplayer.perfil_personagem_atual)
		_aplicar_velocidade_por_equipamento(RedeMultiplayer.perfil_personagem_atual)
	RedeMultiplayer.perfil_personagem_recebido.connect(_atualizar_perfil_visual)

func _atualizar_perfil_visual(perfil: Dictionary) -> void:
	if is_instance_valid(_avatar_personagem):
		_avatar_personagem.configurar(perfil)
	_aplicar_velocidade_por_equipamento(perfil)

func _aplicar_velocidade_por_equipamento(perfil: Dictionary) -> void:
	var base := {
		"forca": int(perfil.get("forca", 5)),
		"inteligencia": int(perfil.get("inteligencia", 5)),
		"agilidade": int(perfil.get("agilidade", 5)),
		"vitalidade": int(perfil.get("vitalidade", 5)),
		"espirito": int(perfil.get("espirito", 5)),
		"vidaMaxima": int(perfil.get("vidaMaxima", 100)),
		"manaMaxima": int(perfil.get("manaMaxima", 50))
	}
	var efetivos := SistemaEquipamentos.calcular_atributos_efetivos(base, perfil.get("equipamentos", {}))
	velocidade = 165.0 * float(efetivos.get("velocidadePercentual", 100)) / 100.0

func definir_direcao_virtual(direcao: Vector2) -> void:
	direcao_virtual = direcao.limit_length(1.0)

func _physics_process(_delta: float) -> void:
	var direcao_teclado := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direcao := direcao_teclado if direcao_teclado.length_squared() > 0.0 else direcao_virtual
	velocity = direcao.normalized() * velocidade
	# Antecipação local espelha a validação do servidor e evita correções bruscas.
	var destino_previsto := global_position + velocity * _delta
	if velocity.length_squared() > 0.0 and not SistemaColisoes.trajeto_valido(global_position, destino_previsto):
		velocity = Vector2.ZERO
	move_and_slide()
	if is_instance_valid(_avatar_personagem):
		_avatar_personagem.definir_movimento(velocity.length() / maxf(velocidade, 1.0), direcao)
	if RedeMultiplayer.estado == RedeMultiplayer.EstadoConexao.CONECTADO:
		_tempo_sincronizacao += _delta
		if _tempo_sincronizacao >= INTERVALO_SINCRONIZACAO:
			_tempo_sincronizacao = 0.0
			RedeMultiplayer.atualizar_posicao_local_cache(global_position)
			RedeMultiplayer.enviar_posicao_jogador(global_position)
