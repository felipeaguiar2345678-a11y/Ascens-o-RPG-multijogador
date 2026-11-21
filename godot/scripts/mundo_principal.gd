extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/jogador.tscn")
const JOYSTICK_SCENE: PackedScene = preload("res://scenes/controle_joystick.tscn")
const PET_SCENE: PackedScene = preload("res://scenes/companheiro.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/guardiao_jormungandr.tscn")
const INTERFACE_EQUIPAMENTOS = preload("res://scripts/interface_inventario_equipamentos.gd")

const TAMANHO_MUNDO := Vector2(2400.0, 1600.0)
const COR_TERRA := Color("#526b45")
const COR_CAMINHO := Color("#a9956d")

@export var companheiro_desbloqueado: bool = false

var jogador: CharacterBody2D
var companheiro: CharacterBody2D
var aviso_guardiao: Label
var jogadores_remotos: Dictionary = {}

func _process(_delta: float) -> void:
	_atualizar_aviso_guardiao()

func _ready() -> void:
	jogador = PLAYER_SCENE.instantiate() as CharacterBody2D
	jogador.position = Vector2(1190, 1120)
	var snapshot: Dictionary = RedeMultiplayer.perfil_personagem_atual
	if not snapshot.is_empty():
		var perfil = PerfilPersonagem.new()
		if perfil.carregar_snapshot(snapshot, RedeMultiplayer.uid_autenticado):
			jogador.position = perfil.posicao_mundo
	add_child(jogador)

	var camera := jogador.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(TAMANHO_MUNDO.x)
	camera.limit_bottom = int(TAMANHO_MUNDO.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0

	if companheiro_desbloqueado:
		companheiro = PET_SCENE.instantiate() as CharacterBody2D
		companheiro.position = jogador.position + Vector2(-26, 18)
		add_child(companheiro)
		companheiro.configurar_alvo(jogador)

	RedeMultiplayer.jogador_entrou_com_perfil_visual.connect(_adicionar_jogador_remoto)
	RedeMultiplayer.jogador_atualizou_perfil_visual.connect(_atualizar_perfil_visual_remoto)
	RedeMultiplayer.jogador_atualizou_posicao.connect(_atualizar_posicao_jogador_remoto)
	RedeMultiplayer.jogador_saiu_do_mundo.connect(_remover_jogador_remoto)
	RedeMultiplayer.estado_inicial_recebido.connect(_carregar_jogadores_remotos)

	_adicionar_joystick()
	var interface_equipamentos = INTERFACE_EQUIPAMENTOS.new()
	interface_equipamentos.name = "InterfaceInventarioEquipamentos"
	add_child(interface_equipamentos)
	_criar_aviso_guardiao()
	queue_redraw()

func _criar_aviso_guardiao() -> void:
	var camada := CanvasLayer.new()
	camada.name = "AvisoDoGuardiao"
	add_child(camada)
	aviso_guardiao = Label.new()
	aviso_guardiao.name = "MensagemDePerigo"
	aviso_guardiao.text = "ALGO COLOSSAL OBSERVA VOCE..."
	aviso_guardiao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_guardiao.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aviso_guardiao.add_theme_color_override("font_color", Color("#f0d58a"))
	aviso_guardiao.add_theme_color_override("font_shadow_color", Color("#171b18"))
	aviso_guardiao.add_theme_constant_override("shadow_offset_x", 2)
	aviso_guardiao.add_theme_constant_override("shadow_offset_y", 2)
	aviso_guardiao.add_theme_font_size_override("font_size", 18)
	aviso_guardiao.anchor_left = 0.1
	aviso_guardiao.anchor_top = 0.06
	aviso_guardiao.anchor_right = 0.9
	aviso_guardiao.anchor_bottom = 0.14
	aviso_guardiao.visible = false
	camada.add_child(aviso_guardiao)

func _atualizar_aviso_guardiao() -> void:
	if aviso_guardiao == null or jogador == null:
		return
	var distancia := min(
		min(jogador.position.x, TAMANHO_MUNDO.x - jogador.position.x),
		min(jogador.position.y, TAMANHO_MUNDO.y - jogador.position.y)
	)
	aviso_guardiao.visible = distancia <= 300.0
	if distancia <= 130.0:
		aviso_guardiao.text = "JǪRMUNGANDR BLOQUEIA SEU CAMINHO"
		aviso_guardiao.add_theme_color_override("font_color", Color("#ff987d"))
	else:
		aviso_guardiao.text = "ALGO COLOSSAL OBSERVA VOCE..."
		aviso_guardiao.add_theme_color_override("font_color", Color("#f0d58a"))

func _adicionar_joystick() -> void:
	var camada := CanvasLayer.new()
	camada.name = "InterfaceMovimento"
	add_child(camada)
	var joystick = JOYSTICK_SCENE.instantiate()
	camada.add_child(joystick)
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 24.0
	joystick.offset_top = -186.0
	joystick.offset_right = 186.0
	joystick.offset_bottom = -24.0
	joystick.direcao_alterada.connect(jogador.definir_direcao_virtual)

func _draw() -> void:
	# Mapa regional amplo: composição de referência, ainda sem arte final.
	draw_rect(Rect2(Vector2.ZERO, TAMANHO_MUNDO), COR_TERRA, true)
	_desenhar_terreno()
	_desenhar_estradas()
	_desenhar_aurelia()
	_desenhar_rotulos()

func _desenhar_terreno() -> void:
	# Clareiras e manchas de vegetação dão leitura de bioma sem depender de assets externos.
	for i in range(115):
		var x := float((i * 193 + 71) % int(TAMANHO_MUNDO.x))
		var y := float((i * 317 + 43) % int(TAMANHO_MUNDO.y))
		var raio := float(18 + (i * 17) % 34)
		var tom := Color("#3d5b3e") if i % 3 == 0 else Color("#456342")
		draw_circle(Vector2(x, y), raio, Color(tom, 0.72))
	for i in range(34):
		var x := float(250 + (i * 227) % 1850)
		var y := float(180 + (i * 149) % 1180)
		draw_circle(Vector2(x, y), float(10 + i % 9), Color("#78905a", 0.55))
	# Lago ao norte da capital.
	draw_circle(Vector2(1530, 420), 155, Color("#426f78"))
	draw_circle(Vector2(1530, 420), 137, Color("#568894"))

func _desenhar_estradas() -> void:
	var estrada_principal := PackedVector2Array([
		Vector2(1190, 1120), Vector2(1130, 980), Vector2(1050, 850),
		Vector2(1110, 720), Vector2(1260, 610), Vector2(1390, 520),
		Vector2(1450, 390)
	])
	draw_polyline(estrada_principal, Color("#594d3b"), 34.0, true)
	draw_polyline(estrada_principal, COR_CAMINHO, 25.0, true)
	var estrada_leste := PackedVector2Array([
		Vector2(1260, 610), Vector2(1480, 650), Vector2(1710, 760),
		Vector2(1940, 900), Vector2(2220, 980)
	])
	draw_polyline(estrada_leste, Color("#594d3b"), 25.0, true)
	draw_polyline(estrada_leste, COR_CAMINHO, 17.0, true)
	var estrada_oeste := PackedVector2Array([
		Vector2(1260, 610), Vector2(1010, 560), Vector2(760, 600),
		Vector2(520, 740), Vector2(270, 850)
	])
	draw_polyline(estrada_oeste, Color("#594d3b"), 25.0, true)
	draw_polyline(estrada_oeste, COR_CAMINHO, 17.0, true)

func _desenhar_aurelia() -> void:
	# Núcleo urbano de Aurelia; prédios geométricos serão trocados por arte modular.
	draw_circle(Vector2(1260, 610), 205, Color("#354a3e", 0.48))
	draw_circle(Vector2(1260, 610), 174, Color("#b69a70"))
	draw_circle(Vector2(1260, 610), 155, Color("#d0b58a"))
	for i in range(12):
		var angulo := TAU * float(i) / 12.0
		var centro := Vector2(1260, 610) + Vector2(cos(angulo), sin(angulo)) * 112.0
		draw_rect(Rect2(centro - Vector2(20, 15), Vector2(40, 30)), Color("#785c4c"), true)
		draw_rect(Rect2(centro - Vector2(15, 10), Vector2(30, 20)), Color("#b77d58"), true)
	draw_circle(Vector2(1260, 610), 43, Color("#e2c58c"))
	draw_circle(Vector2(1260, 610), 25, Color("#8a765b"))
	# Praça e torre central.
	draw_rect(Rect2(Vector2(1238, 576), Vector2(44, 68)), Color("#eee0bd"), true)
	draw_circle(Vector2(1260, 610), 13, Color("#8e704e"))

func _desenhar_rotulos() -> void:
	var fonte := ThemeDB.fallback_font
	if fonte == null:
		return
	draw_string(fonte, Vector2(1160, 365), "LAGO DE AURELIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e5e7d0"))
	draw_string(fonte, Vector2(1175, 865), "AURELIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#fff0cf"))
	draw_string(fonte, Vector2(250, 360), "FLORESTA ARCANA", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#d4e0bd"))
	draw_string(fonte, Vector2(1850, 1260), "CAMPOS CENTRAIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#d4e0bd"))


func _carregar_jogadores_remotos(lista: Array) -> void:
	for dados in lista:
		if dados is Dictionary and dados.has("id") and dados.has("posicao"):
			_adicionar_jogador_remoto(int(dados["id"]), dados["posicao"], dados.get("perfil", {}))

func _adicionar_jogador_remoto(id_jogador: int, posicao: Vector2, perfil_visual: Dictionary = {}) -> void:
	if jogadores_remotos.has(id_jogador):
		return
	var remoto := Node2D.new()
	remoto.name = "JogadorRemoto_%s" % id_jogador
	remoto.position = posicao
	var avatar_script = preload("res://scripts/avatar_personagem.gd")
	var avatar = avatar_script.new()
	avatar.name = "AvatarPersonagem"
	avatar.configurar(perfil_visual)
	remoto.add_child(avatar)
	var identificacao := Label.new()
	identificacao.text = str(perfil_visual.get("nome", "Jogador %s" % id_jogador))
	identificacao.position = Vector2(-35, -28)
	identificacao.add_theme_font_size_override("font_size", 10)
	remoto.add_child(identificacao)
	add_child(remoto)
	jogadores_remotos[id_jogador] = remoto

func _atualizar_perfil_visual_remoto(id_jogador: int, perfil_visual: Dictionary) -> void:
	if not jogadores_remotos.has(id_jogador):
		return
	var remoto: Node2D = jogadores_remotos[id_jogador]
	var avatar := remoto.get_node_or_null("AvatarPersonagem")
	if avatar != null:
		avatar.configurar(perfil_visual)

func _atualizar_posicao_jogador_remoto(id_jogador: int, posicao: Vector2) -> void:
	if id_jogador == multiplayer.get_unique_id():
		if is_instance_valid(jogador):
			jogador.global_position = posicao
		return
	if jogadores_remotos.has(id_jogador):
		var remoto: Node2D = jogadores_remotos[id_jogador]
		remoto.position = posicao
	else:
		_adicionar_jogador_remoto(id_jogador, posicao)

func _remover_jogador_remoto(id_jogador: int) -> void:
	if not jogadores_remotos.has(id_jogador):
		return
	var remoto: Node = jogadores_remotos[id_jogador]
	jogadores_remotos.erase(id_jogador)
	if is_instance_valid(remoto):
		remoto.queue_free()
