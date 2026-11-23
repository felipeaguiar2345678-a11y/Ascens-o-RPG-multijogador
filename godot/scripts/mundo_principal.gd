extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/jogador.tscn")
const JOYSTICK_SCENE: PackedScene = preload("res://scenes/controle_joystick.tscn")
const PET_SCENE: PackedScene = preload("res://scenes/companheiro.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/guardiao_jormungandr.tscn")
const INTERFACE_EQUIPAMENTOS = preload("res://scripts/interface_inventario_equipamentos.gd")
const CRIATURA_ERRANTE_VISUAL = preload("res://scripts/criatura_errante_visual.gd")

const TAMANHO_MUNDO := Vector2(2400.0, 2400.0)
const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")
const COR_TERRA := Color("#526b45")
const COR_CAMINHO := Color("#a9956d")

@export var companheiro_desbloqueado: bool = false

var jogador: CharacterBody2D
var companheiro: CharacterBody2D
var aviso_guardiao: Label
var painel_evento_celeste: PanelContainer
var titulo_evento_celeste: Label
var mensagem_evento_celeste: Label
var raridade_evento_celeste: Label
var temporizador_evento_celeste: Timer
var painel_relogio_mundo: PanelContainer
var ceu_mundo
var texto_relogio_mundo: Label
var texto_periodo_mundo: Label
var texto_lua_mundo: Label
var texto_evento_mundo: Label
var animacao_evento_celeste: Tween
var jogadores_remotos: Dictionary = {}
var criaturas_persistentes: Dictionary = {}
var botao_domesticar: Button
var texto_domesticacao: Label
var aguardando_domesticacao := false
var painel_serpente: PanelContainer
var texto_estado_serpente: Label
var texto_vida_serpente: Label
var texto_ataque_serpente: Label
var botao_entrar_serpente: Button
var botao_ataque_serpente: Button
var botao_magia_serpente: Button
var botao_defender_serpente: Button
var botao_esquivar_serpente: Button
var botao_filhote_serpente: Button
var estado_serpente_publico: Dictionary = {}

func _process(_delta: float) -> void:
	_atualizar_aviso_guardiao()
	_atualizar_interface_serpente()

func _ready() -> void:
	jogador = PLAYER_SCENE.instantiate() as CharacterBody2D
	jogador.position = Vector2(1190, 1520)
	var snapshot: Dictionary = RedeMultiplayer.perfil_personagem_atual
	if not snapshot.is_empty():
		var perfil = PerfilPersonagem.new()
		if perfil.carregar_snapshot(snapshot, RedeMultiplayer.uid_autenticado):
			jogador.position = perfil.posicao_mundo
	add_child(jogador)
	_adicionar_serpente_do_mundo()

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
	RedeMultiplayer.criaturas_persistentes_recebidas.connect(_carregar_criaturas_persistentes)
	RedeMultiplayer.posicoes_criaturas_atualizadas.connect(_atualizar_posicoes_criaturas)
	RedeMultiplayer.anuncio_celeste_recebido.connect(_mostrar_anuncio_evento_celeste)
	RedeMultiplayer.relogio_mundo_atualizado.connect(_atualizar_interface_relogio_mundo)
	RedeMultiplayer.estado_serpente_mundo_atualizado.connect(_receber_estado_serpente)
	_receber_estado_serpente(RedeMultiplayer.obter_estado_serpente_mundo_publico())
	RedeMultiplayer.grupos_selvagens_recebidos.connect(_carregar_individuos_grupos)
	RedeMultiplayer.posicoes_grupos_selvagens_atualizadas.connect(_atualizar_posicoes_grupos)

	_adicionar_joystick()
	_adicionar_interface_combate()
	_adicionar_interface_domesticacao()
	_adicionar_interface_serpente()
	var interface_equipamentos = INTERFACE_EQUIPAMENTOS.new()
	interface_equipamentos.name = "InterfaceInventarioEquipamentos"
	add_child(interface_equipamentos)
	_criar_aviso_guardiao()
	_criar_interface_evento_celeste()
	_criar_interface_relogio_mundo()
	_criar_ceu_mundo()
	queue_redraw()


func _adicionar_serpente_do_mundo() -> void:
	var serpente = BOSS_SCENE.instantiate()
	serpente.name = "SerpenteDoMundo"
	serpente.position = Vector2.ZERO
	serpente.z_index = 3
	add_child(serpente)

func _adicionar_interface_domesticacao() -> void:
	var camada := CanvasLayer.new()
	camada.name = "InterfaceDomesticacao"
	camada.layer = 15
	add_child(camada)
	var painel := PanelContainer.new()
	painel.anchor_left = 0.5
	painel.anchor_right = 0.5
	painel.anchor_top = 1.0
	painel.anchor_bottom = 1.0
	painel.offset_left = -132.0
	painel.offset_right = 132.0
	painel.offset_top = -104.0
	painel.offset_bottom = -24.0
	camada.add_child(painel)
	var coluna := VBoxContainer.new()
	painel.add_child(coluna)
	texto_domesticacao = Label.new()
	texto_domesticacao.text = "Derrote uma criatura e aproxime-se do corpo. Você tem até 3 tentativas por indivíduo."
	texto_domesticacao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_domesticacao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(texto_domesticacao)
	botao_domesticar = Button.new()
	botao_domesticar.text = "Tentar domesticar"
	botao_domesticar.pressed.connect(_solicitar_domesticacao)
	coluna.add_child(botao_domesticar)
	RedeMultiplayer.resultado_domesticacao.connect(_ao_resultado_domesticacao)

func _solicitar_domesticacao() -> void:
	if aguardando_domesticacao:
		return
	aguardando_domesticacao = true
	botao_domesticar.disabled = true
	texto_domesticacao.text = "Procurando criatura próxima..."
	RedeMultiplayer.solicitar_domesticar_criatura_proxima()

func _ao_resultado_domesticacao(sucesso: bool, mensagem: String, invocacao: Dictionary) -> void:
	aguardando_domesticacao = false
	botao_domesticar.disabled = false
	texto_domesticacao.text = mensagem
	if sucesso:
		botao_domesticar.text = "Domesticar outra criatura"
		print("Nova invocação: %s" % str(invocacao.get("nome", "Criatura")))

func _adicionar_interface_combate() -> void:
	var script_interface = preload("res://scripts/interface_combate.gd")
	var interface_combate = script_interface.new()
	interface_combate.name = "InterfaceCombate"
	add_child(interface_combate)

func _adicionar_interface_serpente() -> void:
	var camada := CanvasLayer.new()
	camada.name = "InterfaceIncursaoSerpente"
	camada.layer = 18
	add_child(camada)
	painel_serpente = PanelContainer.new()
	painel_serpente.anchor_left = 0.5
	painel_serpente.anchor_right = 0.5
	painel_serpente.anchor_top = 0.0
	painel_serpente.anchor_bottom = 0.0
	painel_serpente.offset_left = -165.0
	painel_serpente.offset_right = 165.0
	painel_serpente.offset_top = 118.0
	painel_serpente.offset_bottom = 294.0
	painel_serpente.visible = false
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#171b20", 0.94)
	estilo.border_color = Color("#b99a5b")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(7)
	painel_serpente.add_theme_stylebox_override("panel", estilo)
	camada.add_child(painel_serpente)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 4)
	painel_serpente.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "JÖRMUNGANDR • CHEFE MUNDIAL"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", Color("#f0d58a"))
	coluna.add_child(titulo)
	texto_estado_serpente = Label.new()
	texto_estado_serpente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(texto_estado_serpente)
	texto_vida_serpente = Label.new()
	texto_vida_serpente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_vida_serpente.add_theme_color_override("font_color", Color("#ff9b87"))
	coluna.add_child(texto_vida_serpente)
	texto_ataque_serpente = Label.new()
	texto_ataque_serpente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_ataque_serpente.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_ataque_serpente.add_theme_font_size_override("font_size", 11)
	coluna.add_child(texto_ataque_serpente)
	botao_entrar_serpente = Button.new()
	botao_entrar_serpente.text = "Participar da batalha"
	botao_entrar_serpente.pressed.connect(RedeMultiplayer.solicitar_entrar_incursao_serpente)
	coluna.add_child(botao_entrar_serpente)
	botao_ataque_serpente = Button.new()
	botao_ataque_serpente.text = "Atacar a cabeça"
	botao_ataque_serpente.pressed.connect(RedeMultiplayer.solicitar_ataque_serpente.bind("ataque"))
	coluna.add_child(botao_ataque_serpente)
	botao_magia_serpente = Button.new()
	botao_magia_serpente.text = "Magia (10 de mana)"
	botao_magia_serpente.pressed.connect(RedeMultiplayer.solicitar_ataque_serpente.bind("magia"))
	coluna.add_child(botao_magia_serpente)
	botao_defender_serpente = Button.new()
	botao_defender_serpente.text = "Defender (reduz dano)"
	botao_defender_serpente.pressed.connect(RedeMultiplayer.solicitar_defesa_serpente.bind("defender"))
	coluna.add_child(botao_defender_serpente)
	botao_esquivar_serpente = Button.new()
	botao_esquivar_serpente.text = "Esquivar (reduz mais dano)"
	botao_esquivar_serpente.pressed.connect(RedeMultiplayer.solicitar_defesa_serpente.bind("esquivar"))
	coluna.add_child(botao_esquivar_serpente)
	botao_filhote_serpente = Button.new()
	botao_filhote_serpente.text = "Tentar vínculo com o filhote"
	botao_filhote_serpente.pressed.connect(RedeMultiplayer.solicitar_filhote_serpente)
	botao_filhote_serpente.visible = false
	coluna.add_child(botao_filhote_serpente)
	RedeMultiplayer.resultado_filhote_serpente.connect(_ao_resultado_filhote_serpente)

func _receber_estado_serpente(dados: Dictionary) -> void:
	estado_serpente_publico = dados.duplicate(true)
	_atualizar_interface_serpente()

func _atualizar_interface_serpente() -> void:
	if painel_serpente == null or jogador == null:
		return
	var cabeca := Vector2(1200.0, 80.0)
	var perto := jogador.position.distance_to(cabeca) <= 310.0
	painel_serpente.visible = perto
	if not perto:
		return
	var status := str(estado_serpente_publico.get("status", "disponivel"))
	var vida := int(estado_serpente_publico.get("vida", 2000000))
	var vida_maxima := maxi(1, int(estado_serpente_publico.get("vidaMaxima", 2000000)))
	texto_estado_serpente.text = "Estado: " + ("Em batalha" if status == "em_combate" else ("Derrotada" if status == "derrotada" else "Aguardando desafiantes"))
	texto_vida_serpente.text = "Vida compartilhada: %s / %s" % [str(vida), str(vida_maxima)]
	var aviso := str(estado_serpente_publico.get("ultimoAtaque", ""))
	if status == "derrotada":
		var renascimento_unix := int(estado_serpente_publico.get("renascimentoUnix", 0))
		var restante := maxi(0, renascimento_unix - int(Time.get_unix_time_from_system()))
		aviso = "A serpente retornará em %d min. %s" % [ceili(float(restante) / 60.0), aviso]
	texto_ataque_serpente.text = aviso
	texto_ataque_serpente.visible = not aviso.is_empty()
	var derrotada := status == "derrotada"
	botao_entrar_serpente.visible = not derrotada
	botao_entrar_serpente.text = "Entrar na incursão" if status == "em_combate" else "Participar da batalha"
	botao_ataque_serpente.visible = status == "em_combate"
	botao_magia_serpente.visible = status == "em_combate"
	var preparando: Dictionary = estado_serpente_publico.get("ataquePreparando", {})
	var ataque_avisado := not preparando.is_empty()
	botao_defender_serpente.visible = status == "em_combate" and ataque_avisado
	botao_esquivar_serpente.visible = status == "em_combate" and ataque_avisado
	botao_defender_serpente.disabled = not ataque_avisado
	botao_esquivar_serpente.disabled = not ataque_avisado
	botao_filhote_serpente.visible = derrotada

func _ao_resultado_filhote_serpente(sucesso: bool, mensagem: String, invocacao: Dictionary) -> void:
	if texto_estado_serpente == null:
		return
	texto_estado_serpente.text = mensagem
	if sucesso:
		botao_filhote_serpente.disabled = true
		botao_filhote_serpente.text = "Filhote obtido!"
		print("Nova invocação mundial: %s" % str(invocacao.get("nome", "Serpente Filhote Primordial")))

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



func _criar_ceu_mundo() -> void:
	var camada := CanvasLayer.new()
	camada.name = "CeuCompartilhado"
	camada.layer = 0
	add_child(camada)
	ceu_mundo = preload("res://scripts/ceu_mundo.gd").new()
	ceu_mundo.name = "AtmosferaCeleste"
	ceu_mundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ceu_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(ceu_mundo)
	RedeMultiplayer.relogio_mundo_atualizado.connect(ceu_mundo.atualizar_contexto)

func _criar_interface_relogio_mundo() -> void:
	var camada := CanvasLayer.new()
	camada.name = "RelogioDoMundo"
	camada.layer = 15
	add_child(camada)
	painel_relogio_mundo = PanelContainer.new()
	painel_relogio_mundo.name = "PainelRelogio"
	painel_relogio_mundo.anchor_left = 1.0
	painel_relogio_mundo.anchor_right = 1.0
	painel_relogio_mundo.anchor_top = 0.0
	painel_relogio_mundo.anchor_bottom = 0.0
	painel_relogio_mundo.offset_left = -190.0
	painel_relogio_mundo.offset_right = -12.0
	painel_relogio_mundo.offset_top = 12.0
	painel_relogio_mundo.offset_bottom = 112.0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#171b20", 0.92)
	estilo.border_color = Color("#b99a5b", 0.9)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(7)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 7
	estilo.content_margin_bottom = 7
	painel_relogio_mundo.add_theme_stylebox_override("panel", estilo)
	camada.add_child(painel_relogio_mundo)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 2)
	painel_relogio_mundo.add_child(coluna)
	texto_relogio_mundo = Label.new()
	texto_relogio_mundo.text = "--:--  |  DIA 1"
	texto_relogio_mundo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_relogio_mundo.add_theme_font_size_override("font_size", 19)
	texto_relogio_mundo.add_theme_color_override("font_color", Color("#f2d99b"))
	coluna.add_child(texto_relogio_mundo)
	texto_periodo_mundo = Label.new()
	texto_periodo_mundo.text = "Aguardando o mundo..."
	texto_periodo_mundo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_periodo_mundo.add_theme_font_size_override("font_size", 12)
	texto_periodo_mundo.add_theme_color_override("font_color", Color("#d8d2c4"))
	coluna.add_child(texto_periodo_mundo)
	texto_lua_mundo = Label.new()
	texto_lua_mundo.text = "Lua: --"
	texto_lua_mundo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_lua_mundo.add_theme_font_size_override("font_size", 11)
	texto_lua_mundo.add_theme_color_override("font_color", Color("#b9c8e8"))
	coluna.add_child(texto_lua_mundo)
	texto_evento_mundo = Label.new()
	texto_evento_mundo.text = "Céu tranquilo"
	texto_evento_mundo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_evento_mundo.add_theme_font_size_override("font_size", 10)
	texto_evento_mundo.add_theme_color_override("font_color", Color("#cbbd9b"))
	texto_evento_mundo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(texto_evento_mundo)

func _atualizar_interface_relogio_mundo(contexto: Dictionary) -> void:
	if texto_relogio_mundo == null:
		return
	var minuto_ciclo := int(contexto.get("minutoNoCiclo", 0))
	var minutos_visuais := int(floor(float(minuto_ciclo) * 1440.0 / 210.0))
	var hora_visual := int(minutos_visuais / 60) % 24
	var minuto_visual := minutos_visuais % 60
	var dia := int(contexto.get("dia", 1))
	texto_relogio_mundo.text = "%02d:%02d  |  DIA %d" % [hora_visual, minuto_visual, dia]
	var periodo := str(contexto.get("periodo", "indefinido"))
	var nome_periodo := "Dia"
	var cor_periodo := Color("#e6c56f")
	match periodo:
		"crepusculo":
			nome_periodo = "Crepúsculo"
			cor_periodo = Color("#e9a06b")
		"noite":
			nome_periodo = "Noite profunda"
			cor_periodo = Color("#a9b8ef")
		"madrugada":
			nome_periodo = "Madrugada"
			cor_periodo = Color("#9b9beF")
	texto_periodo_mundo.text = nome_periodo + ("  •  bônus noturno ativo" if bool(contexto.get("noturno", false)) else "")
	texto_periodo_mundo.add_theme_color_override("font_color", cor_periodo)
	var fase := str(contexto.get("faseLunar", "indefinida"))
	var nomes_lua := {
		"lua_nova":"Lua nova", "lua_crescente":"Lua crescente",
		"quarto_crescente":"Quarto crescente", "lua_gibosa_crescente":"Lua gibosa crescente",
		"lua_cheia":"Lua cheia", "lua_gibosa_minguante":"Lua gibosa minguante",
		"quarto_minguante":"Quarto minguante", "lua_minguante":"Lua minguante",
		"fase_intermediaria":"Lua em transição"
	}
	texto_lua_mundo.text = "☾ " + str(nomes_lua.get(fase, "Fase lunar indefinida"))
	var evento: Dictionary = contexto.get("eventoCeleste", {})
	var nome_evento := str(evento.get("nome", "Céu tranquilo"))
	if str(evento.get("id", "nenhum")) == "nenhum":
		texto_evento_mundo.text = "Céu tranquilo"
	else:
		texto_evento_mundo.text = "✦ " + nome_evento
	texto_evento_mundo.add_theme_color_override("font_color", Color("#e6bd78") if str(evento.get("id", "nenhum")) != "nenhum" else Color("#a8a49a"))

func _criar_interface_evento_celeste() -> void:
	var camada := CanvasLayer.new()
	camada.name = "AnuncioEventoCeleste"
	camada.layer = 30
	add_child(camada)
	painel_evento_celeste = PanelContainer.new()
	painel_evento_celeste.name = "PainelAnuncio"
	painel_evento_celeste.anchor_left = 0.08
	painel_evento_celeste.anchor_right = 0.92
	painel_evento_celeste.anchor_top = 0.12
	painel_evento_celeste.anchor_bottom = 0.32
	painel_evento_celeste.offset_top = -90
	painel_evento_celeste.offset_bottom = -90
	painel_evento_celeste.modulate.a = 0.0
	painel_evento_celeste.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#17131b", 0.96)
	estilo.border_color = Color("#c6a45d")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 18
	estilo.content_margin_right = 18
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 12
	painel_evento_celeste.add_theme_stylebox_override("panel", estilo)
	camada.add_child(painel_evento_celeste)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	painel_evento_celeste.add_child(coluna)
	raridade_evento_celeste = Label.new()
	raridade_evento_celeste.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raridade_evento_celeste.add_theme_font_size_override("font_size", 11)
	raridade_evento_celeste.add_theme_color_override("font_color", Color("#d6b86f"))
	coluna.add_child(raridade_evento_celeste)
	titulo_evento_celeste = Label.new()
	titulo_evento_celeste.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_evento_celeste.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo_evento_celeste.add_theme_font_size_override("font_size", 21)
	titulo_evento_celeste.add_theme_color_override("font_color", Color("#fff0c9"))
	coluna.add_child(titulo_evento_celeste)
	mensagem_evento_celeste = Label.new()
	mensagem_evento_celeste.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mensagem_evento_celeste.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensagem_evento_celeste.add_theme_font_size_override("font_size", 13)
	mensagem_evento_celeste.add_theme_color_override("font_color", Color("#d5c9b4"))
	coluna.add_child(mensagem_evento_celeste)
	temporizador_evento_celeste = Timer.new()
	temporizador_evento_celeste.one_shot = true
	temporizador_evento_celeste.wait_time = 8.0
	temporizador_evento_celeste.timeout.connect(_ocultar_anuncio_evento_celeste)
	add_child(temporizador_evento_celeste)

func _mostrar_anuncio_evento_celeste(anuncio: Dictionary) -> void:
	if painel_evento_celeste == null:
		return
	var raridade := str(anuncio.get("raridade", "comum"))
	var cor := Color("#d6b86f")
	match raridade:
		"rara": cor = Color("#68b8e8")
		"muito_rara": cor = Color("#b28be8")
		"lendaria": cor = Color("#f0a45b")
		"transcendente", "unica": cor = Color("#ff647b")
	raridade_evento_celeste.text = raridade.replace("_", " ").to_upper()
	raridade_evento_celeste.add_theme_color_override("font_color", cor)
	titulo_evento_celeste.text = str(anuncio.get("titulo", "A noite chegou"))
	mensagem_evento_celeste.text = str(anuncio.get("mensagem", "O mundo mergulha na escuridão."))
	var estilo := painel_evento_celeste.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	estilo.border_color = cor
	painel_evento_celeste.add_theme_stylebox_override("panel", estilo)
	if animacao_evento_celeste and animacao_evento_celeste.is_running():
		animacao_evento_celeste.kill()
	painel_evento_celeste.modulate.a = 0.0
	painel_evento_celeste.position.y = -18.0
	animacao_evento_celeste = create_tween()
	animacao_evento_celeste.set_parallel(true)
	animacao_evento_celeste.tween_property(painel_evento_celeste, "modulate:a", 1.0, 0.55)
	animacao_evento_celeste.tween_property(painel_evento_celeste, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	temporizador_evento_celeste.start()

func _ocultar_anuncio_evento_celeste() -> void:
	if painel_evento_celeste == null:
		return
	if animacao_evento_celeste and animacao_evento_celeste.is_running():
		animacao_evento_celeste.kill()
	animacao_evento_celeste = create_tween()
	animacao_evento_celeste.tween_property(painel_evento_celeste, "modulate:a", 0.0, 0.65)

func _atualizar_aviso_guardiao() -> void:
	if aviso_guardiao == null or jogador == null:
		return
	var distancia := absf(jogador.position.distance_to(Geometria.CENTRO_MUNDO) - Geometria.RAIO_CORPO_SERPENTE)
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
	# Oceano envolve o continente; a geografia antiga é transladada 400 px
	# para coincidir com os dados persistidos já migrados.
	draw_rect(Rect2(Vector2.ZERO, TAMANHO_MUNDO), Color("#173b49"), true)
	var costa := PackedVector2Array()
	for i in range(97):
		var angulo := TAU * float(i) / 96.0
		costa.append(Geometria.CENTRO_MUNDO + Vector2(cos(angulo), sin(angulo)) * Geometria.RAIO_TERRA)
	draw_colored_polygon(costa, COR_TERRA)
	draw_polyline(costa, Color("#c2b47e"), 13.0, true)
	draw_polyline(costa, Color("#6f9b91"), 5.0, true)
	draw_set_transform(Vector2(0.0, 400.0), 0.0, Vector2.ONE)
	_desenhar_terreno()
	_desenhar_biomas()
	_desenhar_estradas()
	_desenhar_aurelia()
	_desenhar_rotulos()
	_desenhar_rios_e_arena()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_desenhar_margem_oceano()
	# Ondas costeiras discretas dão leitura de escala ao Mar Eterno.
	for i in range(48):
		var angulo := TAU * float(i) / 48.0
		var centro := Geometria.CENTRO_MUNDO + Vector2(cos(angulo), sin(angulo)) * (Geometria.RAIO_TERRA + 34.0)
		draw_arc(centro, 12.0, angulo - 0.8, angulo + 0.8, 8, Color("#8bb8b0", 0.5), 2.0, true)

 
func _desenhar_rios_e_arena() -> void:
	# Rio sinuoso liga as terras altas ao lago e segue para a costa sul.
	var rio := PackedVector2Array([
		Vector2(1510, 690), Vector2(1430, 820), Vector2(1320, 930),
		Vector2(1370, 1060), Vector2(1280, 1190), Vector2(1320, 1350),
		Vector2(1190, 1510), Vector2(1110, 1660)
	])
	draw_polyline(rio, Color("#315b60"), 27.0, true)
	draw_polyline(rio, Color("#6da5a0"), 17.0, true)
	draw_polyline(rio, Color("#a5c9b5", 0.55), 3.0, true)
	# Arena costeira da cabeça: clareira ampla, reconhecível e separada do corpo.
	var arena := Vector2(1200, -130)
	draw_circle(arena, 118.0, Color("#4b5747"))
	draw_circle(arena, 105.0, Color("#9a8965"))
	draw_arc(arena, 91.0, 0.0, TAU, 48, Color("#d7c18c"), 5.0, true)
	draw_arc(arena, 72.0, 0.0, TAU, 48, Color("#665b45"), 2.0, true)
	for i in range(8):
		var angulo := TAU * float(i) / 8.0
		var marco := arena + Vector2(cos(angulo), sin(angulo)) * 86.0
		draw_circle(marco, 6.0, Color("#d4c28e"))
	var fonte := ThemeDB.fallback_font
	if fonte != null:
		draw_string(fonte, Vector2(1095, 10), "ARENA DA CABEÇA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#f1d9a2"))

func _desenhar_margem_oceano() -> void:
	# Máscara em setores cobre qualquer detalhe antigo que ultrapasse a costa circular.
	var centro := Geometria.CENTRO_MUNDO
	var raio_interno := Geometria.RAIO_TERRA + 2.0
	var raio_externo := 1800.0
	for i in range(96):
		var a0 := TAU * float(i) / 96.0
		var a1 := TAU * float(i + 1) / 96.0
		draw_colored_polygon(PackedVector2Array([
			centro + Vector2(cos(a0), sin(a0)) * raio_interno,
			centro + Vector2(cos(a0), sin(a0)) * raio_externo,
			centro + Vector2(cos(a1), sin(a1)) * raio_externo,
			centro + Vector2(cos(a1), sin(a1)) * raio_interno
		]), Color("#173b49"))
	var costa := PackedVector2Array()
	for i in range(97):
		var angulo := TAU * float(i) / 96.0
		costa.append(centro + Vector2(cos(angulo), sin(angulo)) * Geometria.RAIO_TERRA)
	draw_polyline(costa, Color("#c2b47e"), 13.0, true)
	draw_polyline(costa, Color("#6f9b91"), 5.0, true)


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

func _desenhar_biomas() -> void:
	# Floresta Arcana: copas em camadas e clareiras para leitura de profundidade.
	for i in range(46):
		var x := 280.0 + float((i * 83) % 500)
		var y := 110.0 + float((i * 137) % 1120)
		if Vector2(x, y).distance_to(Vector2(1260, 610)) < 330.0:
			continue
		var escala := 0.72 + float(i % 5) * 0.12
		draw_rect(Rect2(Vector2(x - 3, y + 5) * 1.0, Vector2(6, 15) * escala), Color("#493d31"))
		draw_circle(Vector2(x, y), 17.0 * escala, Color("#263f32", 0.78))
		draw_circle(Vector2(x - 5, y - 5), 11.0 * escala, Color("#55764a", 0.88))
		draw_circle(Vector2(x + 5, y - 2), 9.0 * escala, Color("#3d6240", 0.92))
	# Cordilheira ao nordeste, com faces iluminadas e sombras frias.
	var montanhas := [
		PackedVector2Array([Vector2(1480, 70), Vector2(1630, 285), Vector2(1780, 70)]),
		PackedVector2Array([Vector2(1660, 30), Vector2(1840, 330), Vector2(2020, 30)]),
		PackedVector2Array([Vector2(1870, 75), Vector2(2010, 270), Vector2(2150, 75)])
	]
	for pico in montanhas:
		draw_colored_polygon(pico, Color("#566779"))
		draw_colored_polygon(PackedVector2Array([pico[0], pico[1], (pico[1] + pico[2]) * 0.5]), Color("#394b5d"))
		draw_colored_polygon(PackedVector2Array([pico[1] + Vector2(-32, -52), pico[1], pico[1] + Vector2(32, -52)]), Color("#d5d9d2"))
	# Dunas e pedras no sul-oeste.
	for i in range(9):
		var centro := Vector2(380 + i * 50, 1260 + (i % 3) * 34)
		draw_arc(centro, 75.0 + float(i % 4) * 8.0, PI * 1.08, PI * 1.92, 28, Color("#c4a16a", 0.55), 5.0, true)
		draw_circle(centro + Vector2(18, 12), 4.0, Color("#8d795b", 0.7))
	# Pântano oriental: água escura, juncos e pequenas ilhas.
	for i in range(13):
		var lagoa := Vector2(1870 + (i * 37) % 200, 1040 + (i * 47) % 320)
		draw_set_transform(lagoa, 0.0, Vector2(1.7, 0.85))
		draw_circle(Vector2.ZERO, 18.0, Color("#315d59", 0.78))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(lagoa, 24.0, 0.0, TAU * 0.82, 20, Color("#82aaa0", 0.65), 2.0, true)
		for j in range(3):
			draw_line(lagoa + Vector2(-8 + j * 8, 5), lagoa + Vector2(-12 + j * 9, -9), Color("#9b9a63"), 2.0)
	# Pequenos marcos de pedra nas rotas, úteis como leitura de escala.
	for marco in [Vector2(1000, 850), Vector2(1510, 700), Vector2(760, 610), Vector2(1740, 900)]:
		draw_rect(Rect2(marco + Vector2(-5, -8), Vector2(10, 16)), Color("#77766a"))
		draw_rect(Rect2(marco + Vector2(-7, -10), Vector2(14, 4)), Color("#aaa28b"))

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

func _carregar_criaturas_persistentes(lista: Array) -> void:
	for dados in lista:
		if dados is Dictionary:
			_adicionar_ou_atualizar_criatura_persistente(dados)

func _atualizar_posicoes_criaturas(atualizacoes: Array) -> void:
	for dados in atualizacoes:
		if not (dados is Dictionary):
			continue
		var id := str(dados.get("id", ""))
		if criaturas_persistentes.has(id):
			var entidade: Node2D = criaturas_persistentes[id]
			entidade.call("definir_posicao_mundo", dados.get("posicao", entidade.global_position))
			entidade.call("definir_comportamento", str(dados.get("comportamento", "vagando")) )

func _carregar_individuos_grupos(lista: Array) -> void:
	for dados in lista:
		if not (dados is Dictionary):
			continue
		var copia: Dictionary = dados.duplicate(true)
		copia["id"] = "grupo:" + str(copia.get("id", ""))
		_adicionar_ou_atualizar_criatura_persistente(copia)

func _atualizar_posicoes_grupos(atualizacoes: Array) -> void:
	for dados in atualizacoes:
		if not (dados is Dictionary):
			continue
		var id := "grupo:" + str(dados.get("individuoId", ""))
		if not criaturas_persistentes.has(id):
			continue
		var entidade: Node2D = criaturas_persistentes[id]
		entidade.call("definir_posicao_mundo", dados.get("posicao", entidade.global_position))
		entidade.call("definir_comportamento", str(dados.get("comportamento", "acompanhando_grupo")))
		entidade.call("definir_lider", bool(dados.get("lider", false)), dados.get("identidadeVisual", {}))

func _adicionar_ou_atualizar_criatura_persistente(dados: Dictionary) -> void:
	var id := str(dados.get("id", ""))
	if id.is_empty():
		return
	var entidade: Node2D
	if criaturas_persistentes.has(id):
		entidade = criaturas_persistentes[id]
	else:
		entidade = CRIATURA_ERRANTE_VISUAL.new() as Node2D
		entidade.name = "CriaturaErrante_" + id
		add_child(entidade)
		criaturas_persistentes[id] = entidade
	entidade.call("configurar", dados)
	entidade.call("definir_posicao_mundo", dados.get("posicao", Vector2.ZERO))
