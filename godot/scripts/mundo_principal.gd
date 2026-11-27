extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/jogador.tscn")
const JOYSTICK_SCENE: PackedScene = preload("res://scenes/controle_joystick.tscn")
const PET_SCENE: PackedScene = preload("res://scenes/companheiro.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/guardiao_jormungandr.tscn")
const INTERFACE_EQUIPAMENTOS = preload("res://scripts/interface_inventario_equipamentos.gd")
const CRIATURA_ERRANTE_VISUAL = preload("res://scripts/criatura_errante_visual.gd")
const SISTEMA_DIALOGO_VIAJANTE = preload("res://scripts/sistema_dialogo_viajante.gd")
const INTERFACE_INTERACAO_JOGADOR = preload("res://scripts/interface_interacao_jogador.gd")

const TAMANHO_MUNDO := Vector2(2400.0, 2400.0)
const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")
const SISTEMA_SERPENTE_MUNDO = preload("res://scripts/sistema_serpente_mundo.gd")
const COR_TERRA := Color("#526b45")
const COR_CAMINHO := Color("#a9956d")

@export var companheiro_desbloqueado: bool = false

var jogador: CharacterBody2D
var companheiro: CharacterBody2D
var painel_companheiro_hud: Label
var _ultimo_resumo_companheiro := ""
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
var interface_interacao_jogador: CanvasLayer
var criaturas_persistentes: Dictionary = {}
var mimicos_mapa: Dictionary = {}
var botao_domesticar: Button
var texto_domesticacao: Label
var aguardando_domesticacao := false
var painel_serpente: PanelContainer
var texto_estado_serpente: Label
var texto_vida_serpente: Label
var texto_participantes_serpente: RichTextLabel
var texto_ataque_serpente: Label
var botao_entrar_serpente: Button
var botao_ataque_serpente: Button
var botao_magia_serpente: Button
var botao_defender_serpente: Button
var botao_esquivar_serpente: Button
var botao_filhote_serpente: Button
var estado_serpente_publico: Dictionary = {}
var painel_descanso_clareira: PanelContainer
var texto_descanso_clareira: Label
var botao_descansar_clareira: Button
var aguardando_descanso_clareira := false
var painel_placa_clareira: PanelContainer
var texto_placa_clareira: Label
var botao_placa_clareira: Button
var placa_clareira_aberta := false
var estava_perto_placa_clareira := false
var painel_abrigos_clareira: PanelContainer
var texto_abrigos_clareira: Label
var botao_abrigos_clareira: Button
var abrigo_clareira_atual := -1
var abrigo_clareira_expandido := false
var estava_perto_abrigos_clareira := false
var viajante_clareira: Node2D
var painel_viajante_clareira: PanelContainer
var texto_viajante_clareira: Label
var botao_viajante_clareira: Button
var viajante_em_conversa := false
var etapa_conversa_viajante := 0
var estava_perto_viajante_clareira := false
var botao_missoes_viajante: Button
var lista_missoes_viajante: VBoxContainer
var aguardando_missoes_viajante := false
var _transicao_para_ally_em_andamento := false

func _process(_delta: float) -> void:
	_atualizar_aviso_guardiao()
	_atualizar_interface_serpente()
	_atualizar_interface_descanso_clareira()
	_atualizar_interface_placa_clareira()
	_atualizar_interface_abrigos_clareira()
	_atualizar_interface_viajante_clareira()
	var ataque: Dictionary = estado_serpente_publico.get("ataquePreparando", {})
	var sopro_preparando := str(ataque.get("id", "")) == "sopro_primordial"
	var instante_devastacao := int(estado_serpente_publico.get("ultimaDevastacaoUnix", 0))
	var animando_impacto := instante_devastacao > 0 and int(Time.get_unix_time_from_system()) - instante_devastacao < 5
	var zona_recuperando := _zona_devastada_ativa()
	var marcas_ativas: Array = estado_serpente_publico.get("marcasDestruicao", [])
	var tem_marca_ativa := false
	for marca in marcas_ativas:
		if marca is Dictionary and int(marca.get("expiraUnix", 0)) > int(Time.get_unix_time_from_system()):
			tem_marca_ativa = true
			break
	if sopro_preparando or animando_impacto or zona_recuperando or tem_marca_ativa:
		queue_redraw()

func _ready() -> void:
	interface_interacao_jogador = INTERFACE_INTERACAO_JOGADOR.new()
	add_child(interface_interacao_jogador)
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

	_configurar_companheiro_ativo(snapshot)
	_criar_hud_companheiro()
	_atualizar_hud_companheiro(snapshot)

	RedeMultiplayer.jogador_entrou_com_perfil_visual.connect(_adicionar_jogador_remoto)
	RedeMultiplayer.perfil_personagem_recebido.connect(_ao_receber_perfil_companheiro)
	RedeMultiplayer.jogador_atualizou_perfil_visual.connect(_atualizar_perfil_visual_remoto)
	RedeMultiplayer.jogador_atualizou_posicao.connect(_atualizar_posicao_jogador_remoto)
	RedeMultiplayer.jogador_saiu_do_mundo.connect(_remover_jogador_remoto)
	RedeMultiplayer.estado_inicial_recebido.connect(_carregar_jogadores_remotos)
	RedeMultiplayer.criaturas_persistentes_recebidas.connect(_carregar_criaturas_persistentes)
	RedeMultiplayer.mimicos_recebidos.connect(_carregar_mimicos)
	RedeMultiplayer.posicoes_criaturas_atualizadas.connect(_atualizar_posicoes_criaturas)
	RedeMultiplayer.anuncio_celeste_recebido.connect(_mostrar_anuncio_evento_celeste)
	RedeMultiplayer.relogio_mundo_atualizado.connect(_atualizar_interface_relogio_mundo)
	RedeMultiplayer.estado_serpente_mundo_atualizado.connect(_receber_estado_serpente)
	RedeMultiplayer.aventura_sala_atualizada.connect(_ao_receber_aventura_sala)
	_receber_estado_serpente(RedeMultiplayer.obter_estado_serpente_mundo_publico())
	RedeMultiplayer.grupos_selvagens_recebidos.connect(_carregar_individuos_grupos)
	RedeMultiplayer.posicoes_grupos_selvagens_atualizadas.connect(_atualizar_posicoes_grupos)
	_carregar_mimicos(RedeMultiplayer.obter_mimicos_publicos())

	_adicionar_joystick()
	if RedeMultiplayer.esta_em_sala_cooperativa():
		_adicionar_botao_ally()
	_adicionar_interface_combate()
	_adicionar_interface_recompensas()
	_adicionar_interface_domesticacao()
	_adicionar_interface_serpente()
	var interface_equipamentos = INTERFACE_EQUIPAMENTOS.new()
	interface_equipamentos.name = "InterfaceInventarioEquipamentos"
	add_child(interface_equipamentos)
	_criar_aviso_guardiao()
	_criar_interface_evento_celeste()
	_criar_interface_relogio_mundo()
	_criar_ceu_mundo()
	_criar_interface_descanso_clareira()
	RedeMultiplayer.resultado_descanso_clareira.connect(_ao_resultado_descanso_clareira)
	RedeMultiplayer.resultado_missoes_npc.connect(_ao_receber_dados_missoes_npc)
	_criar_interface_placa_clareira()
	_criar_interface_abrigos_clareira()
	_criar_viajante_clareira()
	_criar_interface_viajante_clareira()
	queue_redraw()


func _criar_interface_descanso_clareira() -> void:
	var camada := CanvasLayer.new()
	camada.name = "InteracaoClareiraInicial"
	camada.layer = 16
	add_child(camada)
	painel_descanso_clareira = PanelContainer.new()
	painel_descanso_clareira.anchor_left = 0.5
	painel_descanso_clareira.anchor_right = 0.5
	painel_descanso_clareira.anchor_top = 1.0
	painel_descanso_clareira.anchor_bottom = 1.0
	painel_descanso_clareira.offset_left = -116.0
	painel_descanso_clareira.offset_right = 116.0
	painel_descanso_clareira.offset_top = -158.0
	painel_descanso_clareira.offset_bottom = -72.0
	painel_descanso_clareira.visible = false
	camada.add_child(painel_descanso_clareira)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	painel_descanso_clareira.add_child(coluna)
	texto_descanso_clareira = Label.new()
	texto_descanso_clareira.text = "Uma pausa junto à fogueira recupera suas forças."
	texto_descanso_clareira.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_descanso_clareira.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_descanso_clareira.add_theme_font_size_override("font_size", 10)
	coluna.add_child(texto_descanso_clareira)
	botao_descansar_clareira = Button.new()
	botao_descansar_clareira.text = "Descansar na fogueira"
	botao_descansar_clareira.pressed.connect(_solicitar_descanso_clareira)
	coluna.add_child(botao_descansar_clareira)

func _atualizar_interface_descanso_clareira() -> void:
	if not is_instance_valid(painel_descanso_clareira) or not is_instance_valid(jogador):
		return
	var perto := jogador.global_position.distance_to(Vector2(1190.0, 1543.0)) <= 82.0
	painel_descanso_clareira.visible = perto
	if perto and not aguardando_descanso_clareira:
		botao_descansar_clareira.disabled = RedeMultiplayer.estado != RedeMultiplayer.EstadoConexao.CONECTADO and RedeMultiplayer.estado != RedeMultiplayer.EstadoConexao.SERVIDOR

func _solicitar_descanso_clareira() -> void:
	if aguardando_descanso_clareira:
		return
	aguardando_descanso_clareira = true
	botao_descansar_clareira.disabled = true
	texto_descanso_clareira.text = "A fogueira aquece suas mãos..."
	RedeMultiplayer.solicitar_descanso_clareira()

func _ao_resultado_descanso_clareira(sucesso: bool, mensagem: String) -> void:
	aguardando_descanso_clareira = false
	texto_descanso_clareira.text = mensagem
	botao_descansar_clareira.disabled = false
	if abrigo_clareira_atual == 0 and is_instance_valid(texto_abrigos_clareira) and is_instance_valid(botao_abrigos_clareira):
		texto_abrigos_clareira.text = mensagem
		botao_abrigos_clareira.disabled = false

func _criar_interface_placa_clareira() -> void:
	var camada := CanvasLayer.new()
	camada.name = "InteracaoPlacaClareira"
	camada.layer = 17
	add_child(camada)
	painel_placa_clareira = PanelContainer.new()
	painel_placa_clareira.anchor_left = 0.5
	painel_placa_clareira.anchor_right = 0.5
	painel_placa_clareira.anchor_top = 1.0
	painel_placa_clareira.anchor_bottom = 1.0
	painel_placa_clareira.offset_left = -148.0
	painel_placa_clareira.offset_right = 148.0
	painel_placa_clareira.offset_top = -190.0
	painel_placa_clareira.offset_bottom = -72.0
	painel_placa_clareira.visible = false
	camada.add_child(painel_placa_clareira)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	painel_placa_clareira.add_child(coluna)
	texto_placa_clareira = Label.new()
	texto_placa_clareira.text = "Uma placa antiga indica os caminhos desta região."
	texto_placa_clareira.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_placa_clareira.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_placa_clareira.add_theme_font_size_override("font_size", 11)
	coluna.add_child(texto_placa_clareira)
	botao_placa_clareira = Button.new()
	botao_placa_clareira.text = "Ler placa"
	botao_placa_clareira.pressed.connect(_alternar_leitura_placa_clareira)
	coluna.add_child(botao_placa_clareira)

func _atualizar_interface_placa_clareira() -> void:
	if not is_instance_valid(painel_placa_clareira) or not is_instance_valid(jogador):
		return
	var perto := jogador.global_position.distance_to(Vector2(1322.0, 1558.0)) <= 82.0
	if not perto and estava_perto_placa_clareira:
		placa_clareira_aberta = false
		texto_placa_clareira.text = "Uma placa antiga indica os caminhos desta região."
		botao_placa_clareira.text = "Ler placa"
	estava_perto_placa_clareira = perto
	painel_placa_clareira.visible = perto

func _alternar_leitura_placa_clareira() -> void:
	placa_clareira_aberta = not placa_clareira_aberta
	if placa_clareira_aberta:
		texto_placa_clareira.text = "CLAREIRA INICIAL\nVocê está na borda da Floresta Arcana.\n\nESTRADA PRINCIPAL\nSiga pela trilha para chegar a Aurelia, a grande cidade ao longe.\n\nAO REDOR\nA mata se estende pela Floresta Arcana. Explore livremente: não há missão obrigatória nem caminho que você precise seguir."
		botao_placa_clareira.text = "Fechar placa"
	else:
		texto_placa_clareira.text = "Uma placa antiga indica os caminhos desta região."
		botao_placa_clareira.text = "Ler placa"

func _criar_interface_abrigos_clareira() -> void:
	var camada := CanvasLayer.new()
	camada.name = "InteracaoAbrigosClareira"
	camada.layer = 18
	add_child(camada)
	painel_abrigos_clareira = PanelContainer.new()
	painel_abrigos_clareira.anchor_left = 0.5
	painel_abrigos_clareira.anchor_right = 0.5
	painel_abrigos_clareira.anchor_top = 1.0
	painel_abrigos_clareira.anchor_bottom = 1.0
	painel_abrigos_clareira.offset_left = -150.0
	painel_abrigos_clareira.offset_right = 150.0
	painel_abrigos_clareira.offset_top = -190.0
	painel_abrigos_clareira.offset_bottom = -72.0
	painel_abrigos_clareira.visible = false
	camada.add_child(painel_abrigos_clareira)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	painel_abrigos_clareira.add_child(coluna)
	texto_abrigos_clareira = Label.new()
	texto_abrigos_clareira.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_abrigos_clareira.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_abrigos_clareira.add_theme_font_size_override("font_size", 11)
	coluna.add_child(texto_abrigos_clareira)
	botao_abrigos_clareira = Button.new()
	botao_abrigos_clareira.pressed.connect(_usar_abrigo_clareira)
	coluna.add_child(botao_abrigos_clareira)

func _atualizar_interface_abrigos_clareira() -> void:
	if not is_instance_valid(painel_abrigos_clareira) or not is_instance_valid(jogador):
		return
	var posicoes := [Vector2(1096.0, 1485.0), Vector2(1278.0, 1464.0), Vector2(1198.0, 1608.0)]
	var mais_proximo := -1
	var menor_distancia := 82.0
	for indice in range(posicoes.size()):
		var distancia := jogador.global_position.distance_to(posicoes[indice])
		if distancia <= menor_distancia:
			menor_distancia = distancia
			mais_proximo = indice
	if mais_proximo != abrigo_clareira_atual:
		abrigo_clareira_expandido = false
		abrigo_clareira_atual = mais_proximo
		_atualizar_texto_abrigo_clareira()
	if mais_proximo < 0 and estava_perto_abrigos_clareira:
		abrigo_clareira_expandido = false
	estava_perto_abrigos_clareira = mais_proximo >= 0
	painel_abrigos_clareira.visible = mais_proximo >= 0

func _atualizar_texto_abrigo_clareira() -> void:
	if not is_instance_valid(texto_abrigos_clareira) or not is_instance_valid(botao_abrigos_clareira):
		return
	match abrigo_clareira_atual:
		0:
			texto_abrigos_clareira.text = "ABRIGO DO VIAJANTE\nUm teto simples, protegido do vento. Você pode recuperar suas forças aqui."
			botao_abrigos_clareira.text = "Descansar no abrigo"
		1:
			texto_abrigos_clareira.text = "ABRIGO DO VIGIA\nDo alto da pequena elevação, é possível observar as copas da Floresta Arcana e a trilha que segue para Aurelia."
			botao_abrigos_clareira.text = "Observar a floresta"
		2:
			texto_abrigos_clareira.text = "ABRIGO DOS MATERIAIS\nCaixas antigas guardam ferramentas gastas e anotações de viajantes que passaram pela clareira."
			botao_abrigos_clareira.text = "Examinar as anotações"
		_:
			texto_abrigos_clareira.text = ""
			botao_abrigos_clareira.text = "Interagir"
	if abrigo_clareira_expandido:
		match abrigo_clareira_atual:
			1:
				texto_abrigos_clareira.text += "\n\nEntre as árvores, a estrada aparece e desaparece. Nenhum caminho é obrigatório; a floresta se abre em várias direções."
			2:
				texto_abrigos_clareira.text += "\n\nUma anotação quase apagada diz: 'Leve apenas o necessário. A mata muda, e nem toda trilha continua segura.'"
	botao_abrigos_clareira.visible = abrigo_clareira_atual != 0 or not abrigo_clareira_expandido

func _usar_abrigo_clareira() -> void:
	if abrigo_clareira_atual == 0:
		if aguardando_descanso_clareira:
			return
		aguardando_descanso_clareira = true
		texto_abrigos_clareira.text = "Você se acomoda no abrigo..."
		botao_abrigos_clareira.disabled = true
		RedeMultiplayer.solicitar_descanso_clareira()
		return
	abrigo_clareira_expandido = not abrigo_clareira_expandido
	_atualizar_texto_abrigo_clareira()

func _criar_viajante_clareira() -> void:
	viajante_clareira = Node2D.new()
	viajante_clareira.name = "IrenViajante"
	viajante_clareira.position = Vector2(1370.0, 1510.0)
	viajante_clareira.z_index = 4
	var avatar_script = preload("res://scripts/avatar_personagem.gd")
	var avatar = avatar_script.new()
	avatar.name = "AvatarViajante"
	avatar.configurar({
		"racaId":"humano",
		"sexo":"feminino",
		"aparenciaId":"ruivo",
		"anatomiaRacial":{"altura":1.0,"porte":"medio","orelhas":"humanas"},
		"equipamentos":{"torso":"peitoral_couro","pernas":"calcas_couro","pes":"botas_caminhante","costas":"manto_viajante"}
	})
	viajante_clareira.add_child(avatar)
	var nome := Label.new()
	nome.text = "Iren • Viajante"
	nome.position = Vector2(-38.0, -39.0)
	nome.add_theme_font_size_override("font_size", 9)
	nome.add_theme_color_override("font_color", Color("#f2dfb6"))
	nome.add_theme_color_override("font_shadow_color", Color("#241d18"))
	nome.add_theme_constant_override("shadow_offset_x", 1)
	nome.add_theme_constant_override("shadow_offset_y", 1)
	viajante_clareira.add_child(nome)
	add_child(viajante_clareira)


func _criar_interface_viajante_clareira() -> void:
	var camada := CanvasLayer.new()
	camada.name = "InteracaoViajanteClareira"
	camada.layer = 19
	add_child(camada)
	painel_viajante_clareira = PanelContainer.new()
	painel_viajante_clareira.anchor_left = 0.5
	painel_viajante_clareira.anchor_right = 0.5
	painel_viajante_clareira.anchor_top = 1.0
	painel_viajante_clareira.anchor_bottom = 1.0
	painel_viajante_clareira.offset_left = -158.0
	painel_viajante_clareira.offset_right = 158.0
	painel_viajante_clareira.offset_top = -340.0
	painel_viajante_clareira.offset_bottom = -72.0
	painel_viajante_clareira.visible = false
	camada.add_child(painel_viajante_clareira)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	painel_viajante_clareira.add_child(coluna)
	texto_viajante_clareira = Label.new()
	texto_viajante_clareira.text = "Uma viajante descansa perto da estrada."
	texto_viajante_clareira.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_viajante_clareira.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_viajante_clareira.add_theme_font_size_override("font_size", 11)
	coluna.add_child(texto_viajante_clareira)
	botao_viajante_clareira = Button.new()
	botao_viajante_clareira.text = "Conversar"
	botao_viajante_clareira.pressed.connect(_alternar_conversa_viajante_clareira)
	coluna.add_child(botao_viajante_clareira)
	botao_missoes_viajante = Button.new()
	botao_missoes_viajante.text = "Consultar missões"
	botao_missoes_viajante.pressed.connect(_solicitar_missoes_viajante)
	coluna.add_child(botao_missoes_viajante)
	lista_missoes_viajante = VBoxContainer.new()
	lista_missoes_viajante.add_theme_constant_override("separation", 3)
	coluna.add_child(lista_missoes_viajante)


func _atualizar_interface_viajante_clareira() -> void:
	if not is_instance_valid(painel_viajante_clareira) or not is_instance_valid(jogador) or not is_instance_valid(viajante_clareira):
		return
	var perto := jogador.global_position.distance_to(viajante_clareira.global_position) <= 92.0
	if not perto and estava_perto_viajante_clareira:
		viajante_em_conversa = false
		etapa_conversa_viajante = 0
		texto_viajante_clareira.text = "Uma viajante descansa perto da estrada."
		botao_viajante_clareira.text = "Conversar"
		aguardando_missoes_viajante = false
		botao_missoes_viajante.disabled = false
		for filho in lista_missoes_viajante.get_children():
			filho.queue_free()
	estava_perto_viajante_clareira = perto
	painel_viajante_clareira.visible = perto


func _alternar_conversa_viajante_clareira() -> void:
	var resultado: Dictionary = SISTEMA_DIALOGO_VIAJANTE.avancar(etapa_conversa_viajante)
	if not bool(resultado.get("continuar", false)):
		viajante_em_conversa = false
		etapa_conversa_viajante = 0
		texto_viajante_clareira.text = "Iren ajeita a mochila e observa a estrada."
		botao_viajante_clareira.text = "Conversar"
		return
	viajante_em_conversa = true
	etapa_conversa_viajante = int(resultado.get("etapa", 0))
	texto_viajante_clareira.text = str(resultado.get("texto", ""))
	botao_viajante_clareira.text = str(resultado.get("botao", "Continuar"))

func _solicitar_missoes_viajante() -> void:
	if aguardando_missoes_viajante:
		return
	aguardando_missoes_viajante = true
	botao_missoes_viajante.disabled = true
	texto_viajante_clareira.text = "Iren procura em suas anotações..."
	RedeMultiplayer.solicitar_dados_missoes_npc("iren_viajante")

func _ao_receber_dados_missoes_npc(dados: Dictionary) -> void:
	aguardando_missoes_viajante = false
	if not is_instance_valid(lista_missoes_viajante) or not is_instance_valid(botao_missoes_viajante):
		return
	botao_missoes_viajante.disabled = false
	for filho in lista_missoes_viajante.get_children():
		filho.queue_free()
	var ofertas: Array = dados.get("ofertas", [])
	var ativas: Array = dados.get("ativas", [])
	var mensagem := str(dados.get("mensagem", ""))
	if not mensagem.is_empty():
		texto_viajante_clareira.text = mensagem
	elif ofertas.is_empty() and ativas.is_empty():
		texto_viajante_clareira.text = "Iren folheia suas anotações. No momento, não tem nenhuma proposta para você."
	else:
		texto_viajante_clareira.text = "IREN • Caminhos e compromissos"
	for oferta in ofertas:
		if not (oferta is Dictionary):
			continue
		var bloco := VBoxContainer.new()
		var titulo := Label.new()
		titulo.text = str(oferta.get("titulo", "Proposta"))
		titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bloco.add_child(titulo)
		var descricao := Label.new()
		descricao.text = str(oferta.get("descricao", ""))
		descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bloco.add_child(descricao)
		var acoes := HBoxContainer.new()
		var aceitar := Button.new()
		aceitar.text = "Aceitar"
		aceitar.pressed.connect(_executar_acao_missao_viajante.bind(str(oferta.get("id", "")), "aceitar"))
		acoes.add_child(aceitar)
		var recusar := Button.new()
		recusar.text = "Recusar"
		recusar.pressed.connect(_executar_acao_missao_viajante.bind(str(oferta.get("id", "")), "recusar"))
		acoes.add_child(recusar)
		bloco.add_child(acoes)
		lista_missoes_viajante.add_child(bloco)
	for missao in ativas:
		if not (missao is Dictionary):
			continue
		var bloco_ativa := VBoxContainer.new()
		var titulo_ativo := Label.new()
		titulo_ativo.text = "%s • %s" % [str(missao.get("titulo", "Missão")), str(missao.get("status", "")).replace("_", " ").capitalize()]
		titulo_ativo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bloco_ativa.add_child(titulo_ativo)
		if str(missao.get("status", "")) == "objetivos_concluidos":
			var concluir := Button.new()
			concluir.text = "Concluir e receber recompensa"
			concluir.pressed.connect(_executar_acao_missao_viajante.bind(str(missao.get("id", "")), "concluir"))
			bloco_ativa.add_child(concluir)
		elif str(missao.get("status", "")) == "em_andamento":
			var abandonar := Button.new()
			abandonar.text = "Abandonar missão"
			abandonar.pressed.connect(_executar_acao_missao_viajante.bind(str(missao.get("id", "")), "abandonar"))
			bloco_ativa.add_child(abandonar)
		lista_missoes_viajante.add_child(bloco_ativa)

func _executar_acao_missao_viajante(missao_id: String, acao: String) -> void:
	if aguardando_missoes_viajante or missao_id.is_empty():
		return
	aguardando_missoes_viajante = true
	botao_missoes_viajante.disabled = true
	RedeMultiplayer.solicitar_acao_missao_npc("iren_viajante", missao_id, acao)


func _ao_receber_perfil_companheiro(perfil: Dictionary) -> void:
	_configurar_companheiro_ativo(perfil)
	_atualizar_hud_companheiro(perfil)

func _criar_hud_companheiro() -> void:
	var camada := CanvasLayer.new()
	camada.name = "HUDCompanheiro"
	camada.layer = 8
	add_child(camada)
	painel_companheiro_hud = Label.new()
	painel_companheiro_hud.position = Vector2(16, 74)
	painel_companheiro_hud.custom_minimum_size = Vector2(230, 34)
	painel_companheiro_hud.add_theme_font_size_override("font_size", 11)
	painel_companheiro_hud.add_theme_color_override("font_color", Color("#f0dfb9"))
	painel_companheiro_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camada.add_child(painel_companheiro_hud)

func _atualizar_hud_companheiro(perfil: Dictionary) -> void:
	if not is_instance_valid(painel_companheiro_hud):
		return
	var ativa_id := str(perfil.get("invocacaoAtivaId", ""))
	for invocacao in perfil.get("invocacoes", []):
		if not invocacao is Dictionary or str(invocacao.get("id", "")) != ativa_id:
			continue
		var resumo := "✦ %s  •  Nv.%d  •  Rank %s  •  %s" % [
			str(invocacao.get("nome", "Companheiro")),
			int(invocacao.get("nivel", 1)),
			str(invocacao.get("rank", "E")),
			str(invocacao.get("raridade", "comum")).capitalize()
		]
		painel_companheiro_hud.text = resumo
		painel_companheiro_hud.visible = true
		return
	painel_companheiro_hud.text = "✦ Nenhum companheiro ativo"
	painel_companheiro_hud.visible = true

func _configurar_companheiro_ativo(perfil: Dictionary) -> void:
	var ativa_id := str(perfil.get("invocacaoAtivaId", ""))
	var dados_ativos: Dictionary = {}
	for invocacao in perfil.get("invocacoes", []):
		if invocacao is Dictionary and str(invocacao.get("id", "")) == ativa_id:
			dados_ativos = invocacao.duplicate(true)
			break
	if dados_ativos.is_empty() and not companheiro_desbloqueado:
		if is_instance_valid(companheiro):
			companheiro.queue_free()
			companheiro = null
		return
	if is_instance_valid(companheiro):
		companheiro.queue_free()
	companheiro = PET_SCENE.instantiate() as CharacterBody2D
	companheiro.position = jogador.position + Vector2(-26, 18)
	add_child(companheiro)
	if not dados_ativos.is_empty() and companheiro.has_method("configurar_companheiro"):
		companheiro.configurar_companheiro(dados_ativos)
	companheiro.configurar_alvo(jogador)

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

func _adicionar_interface_recompensas() -> void:
	var script_interface = preload("res://scripts/interface_recompensas.gd")
	var interface_recompensas = script_interface.new()
	interface_recompensas.name = "InterfaceRecompensas"
	add_child(interface_recompensas)

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
	painel_serpente.offset_bottom = 366.0
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
	var titulo_contribuicao := Label.new()
	titulo_contribuicao.text = "CONTRIBUIÇÃO NA INCURSÃO"
	titulo_contribuicao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_contribuicao.add_theme_font_size_override("font_size", 11)
	coluna.add_child(titulo_contribuicao)
	texto_participantes_serpente = RichTextLabel.new()
	texto_participantes_serpente.bbcode_enabled = true
	texto_participantes_serpente.fit_content = true
	texto_participantes_serpente.scroll_active = false
	texto_participantes_serpente.custom_minimum_size = Vector2(0, 42)
	texto_participantes_serpente.add_theme_font_size_override("normal_font_size", 10)
	coluna.add_child(texto_participantes_serpente)
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
	queue_redraw()

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
	var ranking_participantes: Array = estado_serpente_publico.get("rankingParticipantes", []) if estado_serpente_publico.get("rankingParticipantes", []) is Array else []
	var linhas_participantes: Array[String] = []
	for registro_var in ranking_participantes:
		if not registro_var is Dictionary:
			continue
		var registro: Dictionary = registro_var
		var nome_participante := str(registro.get("nome", "Aventureiro")).substr(0, 22).replace("[", "(").replace("]", ")")
		var dano_participante := int(registro.get("danoTotal", 0))
		var percentual_participante := float(registro.get("percentualDano", 0.0))
		if bool(registro.get("nomeVerde", false)):
			nome_participante = "[color=#4ade80]%s[/color]" % nome_participante
		linhas_participantes.append("%s — %d dano (%.1f%%)" % [nome_participante, dano_participante, percentual_participante])
	texto_participantes_serpente.text = "\n".join(linhas_participantes) if not linhas_participantes.is_empty() else "Aguardando participantes..."
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

func _adicionar_botao_ally() -> void:
	var camada := CanvasLayer.new()
	camada.name = "AcessoAlly"
	camada.layer = 24
	add_child(camada)
	var botao := Button.new()
	botao.text = "ALLY • GRUPO"
	botao.tooltip_text = "Abrir o painel da equipe e do combate cooperativo"
	botao.anchor_left = 1.0
	botao.anchor_right = 1.0
	botao.anchor_top = 0.0
	botao.anchor_bottom = 0.0
	botao.offset_left = -142.0
	botao.offset_right = -16.0
	botao.offset_top = 18.0
	botao.offset_bottom = 58.0
	botao.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/aventura_cooperativa.tscn"))
	camada.add_child(botao)

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
	_desenhar_floresta_detalhada()
	_desenhar_clareira_inicial()
	_desenhar_estradas()
	_desenhar_aurelia()
	_desenhar_rotulos()
	_desenhar_rios_e_arena()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_desenhar_margem_oceano()
	_desenhar_sopro_e_devastacao_serpente()
	_desenhar_marcas_destruicao_mundo()
	# Ondas costeiras discretas dão leitura de escala ao Mar Eterno.
	for i in range(48):
		var angulo := TAU * float(i) / 48.0
		var centro := Geometria.CENTRO_MUNDO + Vector2(cos(angulo), sin(angulo)) * (Geometria.RAIO_TERRA + 34.0)
		draw_arc(centro, 12.0, angulo - 0.8, angulo + 0.8, 8, Color("#8bb8b0", 0.5), 2.0, true)


func _desenhar_marcas_destruicao_mundo() -> void:
	var agora := int(Time.get_unix_time_from_system())
	var marcas: Array = estado_serpente_publico.get("marcasDestruicao", [])
	for indice in range(marcas.size()):
		var marca = marcas[indice]
		if not (marca is Dictionary):
			continue
		var expira := int(marca.get("expiraUnix", 0))
		var criado := int(marca.get("criadoUnix", 0))
		if expira <= agora or expira <= criado:
			continue
		var restante := expira - agora
		var duracao_total := maxi(1, expira - criado)
		var idade := clampf(float(agora - criado), 0.0, float(duracao_total))
		# Recuperação contínua: a cicatriz perde intensidade durante toda a sua vida útil.
		var progresso_recuperacao := clampf(idade / float(duracao_total), 0.0, 1.0)
		var opacidade := 1.0 - smoothstep(0.0, 1.0, progresso_recuperacao)
		var centro := Vector2(float(marca.get("x", 0.0)), float(marca.get("y", 0.0)))
		var raio := clampf(float(marca.get("raio", 24.0)), 12.0, 900.0)
		var tipo := str(marca.get("tipo", "cratera_elemental"))
		var elemento := str(marca.get("elemento", ""))
		var variacao: int = absi(hash(str(marca.get("id", indice)))) % 17
		var rotacao := float(variacao) * 0.19
		var cor_escura := Color("#252321", 0.82 * opacidade)
		match tipo:
			"fissura_tectonica":
				draw_circle(centro, raio, Color("#332f2a", 0.22 * opacidade))
				for ramo in range(5):
					var angulo := rotacao + TAU * float(ramo) / 5.0
					var direcao := Vector2(cos(angulo), sin(angulo))
					var meio := centro + direcao * raio * 0.48
					var ponta := centro + direcao.rotated(0.22) * raio * (0.78 + float(ramo % 3) * 0.06)
					draw_line(centro - direcao * raio * 0.22, meio, cor_escura, maxf(3.0, raio * 0.055), true)
					draw_line(meio, ponta, cor_escura, maxf(2.0, raio * 0.035), true)
					draw_line(meio, meio + direcao.rotated(-0.72) * raio * 0.24, Color("#9a7654", 0.75 * opacidade), maxf(1.5, raio * 0.012), true)
				draw_arc(centro, raio * 0.92, rotacao, rotacao + PI * 1.35, 36, Color("#88705a", 0.62 * opacidade), maxf(2.0, raio * 0.018), true)
			"cicatriz_alagada":
				draw_circle(centro, raio, Color("#244d59", 0.38 * opacidade))
				draw_circle(centro + Vector2(-raio * 0.12, -raio * 0.08), raio * 0.68, Color("#397987", 0.48 * opacidade))
				for anel in range(3):
					var deslocamento := float(anel) * 0.17
					draw_arc(centro + Vector2(float(anel % 2) * raio * 0.08, 0), raio * (0.38 + deslocamento), rotacao, rotacao + TAU * 0.88, 48, Color("#9bd0cf", (0.62 - float(anel) * 0.12) * opacidade), maxf(1.5, raio * 0.014), true)
				draw_line(centro + Vector2(-raio * 0.48, -raio * 0.12), centro + Vector2(raio * 0.36, -raio * 0.2), Color("#c2e3d7", 0.55 * opacidade), maxf(1.5, raio * 0.012), true)
			"solo_congelado":
				draw_circle(centro, raio, Color("#668eaa", 0.30 * opacidade))
				draw_circle(centro, raio * 0.58, Color("#b4e4ed", 0.24 * opacidade))
				for ponta in range(8):
					var angulo := rotacao + TAU * float(ponta) / 8.0
					var direcao := Vector2(cos(angulo), sin(angulo))
					var lateral := direcao.rotated(PI * 0.5) * raio * 0.10
					var base := centro + direcao * raio * 0.42
					var topo := centro + direcao * raio * (0.88 if ponta % 2 == 0 else 0.70)
					draw_colored_polygon(PackedVector2Array([base - lateral, topo, base + lateral]), Color("#b9e8f2", 0.62 * opacidade))
					draw_line(centro, topo, Color("#e0fbff", 0.76 * opacidade), maxf(1.5, raio * 0.012), true)
				draw_arc(centro, raio * 0.72, rotacao, rotacao + TAU, 56, Color("#d4f5fa", 0.62 * opacidade), maxf(2.0, raio * 0.018), true)
			"solo_eletrificado":
				draw_circle(centro, raio, Color("#403b62", 0.34 * opacidade))
				for ramificacao in range(7):
					var angulo := rotacao + TAU * float(ramificacao) / 7.0
					var direcao := Vector2(cos(angulo), sin(angulo))
					var fim := centro + direcao * raio * (0.72 + float(ramificacao % 2) * 0.12)
					var dobra := centro + direcao * raio * 0.38 + direcao.rotated(0.55) * raio * 0.12
					draw_line(centro, dobra, Color("#e5d76b", 0.92 * opacidade), maxf(2.0, raio * 0.025), true)
					draw_line(dobra, fim, Color("#a99cff", 0.88 * opacidade), maxf(1.5, raio * 0.018), true)
					draw_circle(fim, maxf(2.0, raio * 0.025), Color("#e7e1a0", 0.9 * opacidade))
				draw_circle(centro, raio * 0.16, Color("#b8a6ff", 0.42 * opacidade))
			"cratera_queimada":
				draw_circle(centro, raio, Color("#47302a", 0.40 * opacidade))
				draw_arc(centro, raio * 0.91, rotacao, rotacao + TAU, 72, Color("#1e2020", 0.88 * opacidade), maxf(3.0, raio * 0.045), true)
				draw_circle(centro, raio * 0.58, Color("#17191b", 0.78 * opacidade))
				draw_arc(centro, raio * 0.66, 0.0, TAU, 56, Color("#c45b35", 0.72 * opacidade), maxf(2.0, raio * 0.025), true)
				for brasa in range(9):
					var angulo := rotacao + TAU * float(brasa) / 9.0
					var ponto := centro + Vector2(cos(angulo), sin(angulo)) * raio * (0.35 + float(brasa % 3) * 0.15)
					draw_circle(ponto, maxf(2.0, raio * 0.025), Color("#ff9a4b", 0.82 * opacidade))
			_:
				var cor_base := Color("#55453d")
				if elemento == "fogo":
					cor_base = Color("#643b30")
				elif elemento == "gelo":
					cor_base = Color("#789ba6")
				elif elemento == "raio":
					cor_base = Color("#827b9e")
				draw_circle(centro, raio, Color(cor_base.r, cor_base.g, cor_base.b, 0.38 * opacidade))
				draw_arc(centro, raio * 0.94, 0.0, TAU, 72, Color("#25282a", 0.82 * opacidade), maxf(2.0, raio * 0.025), true)
				draw_arc(centro, raio * 0.62, 0.0, TAU, 56, Color(cor_base.r, cor_base.g, cor_base.b, 0.88 * opacidade), maxf(2.0, raio * 0.018), true)
				draw_circle(centro, raio * 0.28, Color("#1c2022", 0.72 * opacidade))
				for rachadura in range(8):
					var angulo := rotacao + TAU * float(rachadura) / 8.0
					var direcao := Vector2(cos(angulo), sin(angulo))
					draw_line(centro + direcao * raio * 0.30, centro + direcao * raio * (0.72 + float(rachadura % 3) * 0.06), Color("#242729", 0.82 * opacidade), maxf(2.0, raio * 0.018), true)
		_desenhar_vestigios_marca(centro, raio, tipo, rotacao, opacidade, str(marca.get("id", indice)))

func _desenhar_vestigios_marca(centro: Vector2, raio: float, tipo: String, rotacao: float, opacidade: float, identificador: String) -> void:
	# Padrão determinístico: os mesmos vestígios aparecem em todos os redraws e clientes.
	var semente: int = absi(hash(identificador))
	var quantidade_pedras := clampi(int(raio / 18.0), 5, 18)
	var cor_pedra := Color("#625b52", 0.92 * opacidade)
	var cor_luz := Color("#a49a85", 0.78 * opacidade)
	if tipo == "cicatriz_alagada":
		cor_pedra = Color("#526e70", 0.82 * opacidade)
		cor_luz = Color("#9abbb2", 0.68 * opacidade)
	elif tipo == "solo_congelado":
		cor_pedra = Color("#8db7c5", 0.88 * opacidade)
		cor_luz = Color("#e0f7fa", 0.82 * opacidade)
	elif tipo == "solo_eletrificado":
		cor_pedra = Color("#625b83", 0.90 * opacidade)
		cor_luz = Color("#c0b4ff", 0.80 * opacidade)
	elif tipo == "cratera_queimada":
		cor_pedra = Color("#393432", 0.96 * opacidade)
		cor_luz = Color("#80604d", 0.74 * opacidade)
	elif tipo == "fissura_tectonica":
		cor_pedra = Color("#51483f", 0.96 * opacidade)
		cor_luz = Color("#a18a70", 0.78 * opacidade)
	for i in range(quantidade_pedras):
		var angulo := rotacao + float(i) * 2.399963 + float((semente >> (i % 16)) & 7) * 0.11
		var fracao := 0.34 + float((semente + i * 37) % 59) / 100.0
		var distancia := raio * minf(fracao, 0.91)
		var ponto := centro + Vector2(cos(angulo), sin(angulo)) * distancia
		var tamanho := clampf(raio * (0.018 + float((semente + i * 13) % 9) * 0.002), 2.5, 13.0)
		var inclina := Vector2(cos(angulo + 0.8), sin(angulo + 0.8)) * tamanho
		draw_colored_polygon(PackedVector2Array([ponto - inclina + Vector2(-tamanho * 0.35, tamanho * 0.2), ponto + Vector2(0, -tamanho), ponto + inclina, ponto + Vector2(tamanho * 0.35, tamanho * 0.55)]), cor_pedra)
		draw_line(ponto + Vector2(-tamanho * 0.25, -tamanho * 0.35), ponto + Vector2(tamanho * 0.25, tamanho * 0.12), cor_luz, 1.5, true)
	# Troncos tombados surgem em impactos físicos; a orientação também é fixa por marca.
	if tipo == "cratera_queimada" or tipo == "fissura_tectonica" or tipo == "cratera_elemental":
		var troncos := 2 if raio >= 100.0 else 1
		for arvore in range(troncos):
			var angulo_arvore := rotacao + float(arvore) * PI * 0.72 + float((semente >> (arvore * 3)) & 3) * 0.16
			var direcao_arvore := Vector2(cos(angulo_arvore), sin(angulo_arvore))
			var base := centro + direcao_arvore * raio * (0.18 + float(arvore) * 0.16)
			var ponta := base + direcao_arvore.rotated(0.16) * raio * 0.30
			var cor_tronco := Color("#302722", 0.96 * opacidade) if tipo == "cratera_queimada" else Color("#594735", 0.94 * opacidade)
			draw_line(base, ponta, cor_tronco, clampf(raio * 0.035, 3.0, 9.0), true)
			draw_line(ponta, ponta + direcao_arvore.rotated(0.75) * raio * 0.10, cor_tronco, 2.5, true)
			draw_line(ponta - direcao_arvore * raio * 0.08, ponta - direcao_arvore * raio * 0.08 + direcao_arvore.rotated(-0.85) * raio * 0.11, cor_tronco, 2.0, true)
			draw_line(base + direcao_arvore * raio * 0.08, base + direcao_arvore * raio * 0.08 + direcao_arvore.rotated(1.1) * raio * 0.07, cor_tronco, 2.0, true)
	# Sedimento, gelo quebrado e carvão deixam a superfície coerente com o elemento.
	if tipo == "cicatriz_alagada":
		for detrito in range(4):
			var angulo_detrito := rotacao + float(detrito) * TAU / 4.0
			var raiz := centro + Vector2(cos(angulo_detrito), sin(angulo_detrito)) * raio * 0.48
			draw_line(raiz, raiz + Vector2(cos(angulo_detrito + 0.9), sin(angulo_detrito + 0.9)) * raio * 0.10, Color("#9ab6a0", 0.76 * opacidade), 2.0, true)
	elif tipo == "solo_congelado":
		for lasca in range(5):
			var angulo_lasca := rotacao + float(lasca) * TAU / 5.0
			var lasca_base := centro + Vector2(cos(angulo_lasca), sin(angulo_lasca)) * raio * 0.52
			var lasca_ponta := lasca_base + Vector2(cos(angulo_lasca + 0.4), sin(angulo_lasca + 0.4)) * raio * 0.09
			draw_line(lasca_base, lasca_ponta, Color("#d6f6ff", 0.84 * opacidade), 3.0, true)
	elif tipo == "cratera_queimada":
		for carvao in range(6):
			var angulo_carvao := rotacao + float(carvao) * TAU / 6.0
			var carvao_pos := centro + Vector2(cos(angulo_carvao), sin(angulo_carvao)) * raio * 0.72
			draw_circle(carvao_pos, maxf(2.0, raio * 0.018), Color("#211d1b", 0.92 * opacidade))

func _obter_zona_devastada() -> Dictionary:
	var zona = estado_serpente_publico.get("zonaDevastada", {})
	return zona if zona is Dictionary else {}

func _zona_devastada_ativa() -> bool:
	var zona := _obter_zona_devastada()
	if zona.is_empty():
		return false
	var recuperacao_unix := int(zona.get("recuperacaoUnix", 0))
	return recuperacao_unix <= 0 or int(Time.get_unix_time_from_system()) < recuperacao_unix

func _ponto_atingido_pelo_sopro(ponto_visual: Vector2) -> bool:
	var zona := _obter_zona_devastada()
	if zona.is_empty() or not _zona_devastada_ativa():
		return false
	var ponto_mundo := ponto_visual + Vector2(0.0, 400.0)
	var centro := Vector2(float(zona.get("x", 0.0)), float(zona.get("y", 0.0)))
	var raio := clampf(float(zona.get("raio", 0.0)), 0.0, 2000.0)
	if raio <= 0.0 or ponto_mundo.distance_to(centro) > raio:
		return false
	# Aurelia permanece protegida mesmo se uma expansão futura alcançar sua muralha.
	return ponto_mundo.distance_to(Vector2(1260.0, 1010.0)) > 230.0

func _desenhar_sopro_e_devastacao_serpente() -> void:
	var ataque: Dictionary = estado_serpente_publico.get("ataquePreparando", {})
	var cabeca := Vector2(1200.0, 80.0)
	var centro_impacto := Vector2(1200.0, 285.0)
	var agora := int(Time.get_unix_time_from_system())
	var instante_devastacao := int(estado_serpente_publico.get("ultimaDevastacaoUnix", 0))
	var tempo_impacto := float(agora - instante_devastacao) + fposmod(float(Time.get_ticks_msec()), 1000.0) / 1000.0
	var preparando := str(ataque.get("id", "")) == "sopro_primordial"
	if preparando:
		var pulso := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012)
		var largura := 62.0 + pulso * 48.0
		var cone := PackedVector2Array([cabeca + Vector2(-18, 0), centro_impacto + Vector2(-largura, 0), centro_impacto + Vector2(largura, 0), cabeca + Vector2(18, 0)])
		draw_colored_polygon(cone, Color("#ff4b20", 0.20 + pulso * 0.18))
		draw_polyline(PackedVector2Array([cabeca, centro_impacto + Vector2(-largura, 0)]), Color("#ffd36b", 0.9), 7.0, true)
		draw_polyline(PackedVector2Array([cabeca, centro_impacto + Vector2(largura, 0)]), Color("#ff8b3d", 0.9), 7.0, true)
		draw_circle(cabeca + Vector2(0, 24), 24.0 + pulso * 12.0, Color("#fff0b0", 0.28))
		for i in range(20):
			var fator := float(i) / 20.0
			var pos := cabeca.lerp(centro_impacto, fator)
			pos.x += sin(float(i) * 2.1 + float(Time.get_ticks_msec()) * 0.009) * largura * fator
			draw_circle(pos, 2.5 + pulso * 2.0, Color("#ffe7a1", 0.88))
	if bool(estado_serpente_publico.get("cenarioDevastado", false)) and _zona_devastada_ativa():
		# A zona externa queimada apaga a vegetação; o núcleo mantém crateras e rocha vitrificada.
		draw_circle(centro_impacto, 480.0, Color("#282321", 0.24))
		draw_arc(centro_impacto, 478.0, 0.0, TAU, 120, Color("#6e4030", 0.52), 13.0, true)
		draw_circle(centro_impacto, 205.0, Color("#171b1d", 0.72))
		draw_circle(centro_impacto, 164.0, Color("#4a2923", 0.72))
		draw_circle(centro_impacto, 112.0, Color("#211e20", 0.82))
		draw_arc(centro_impacto, 205.0, 0.0, TAU, 80, Color("#d65b36", 0.82), 8.0, true)
		draw_arc(centro_impacto, 164.0, 0.0, TAU, 72, Color("#f09a4c", 0.55), 4.0, true)
		for i in range(12):
			var angulo := TAU * float(i) / 12.0
			var direcao := Vector2(cos(angulo), sin(angulo))
			var inicio := centro_impacto + direcao * 95.0
			var fim := centro_impacto + direcao * (178.0 + float(i % 4) * 9.0)
			draw_line(inicio, fim, Color("#0e1518", 0.95), 7.0, true)
			draw_circle(fim, 9.0 + float(i % 3) * 3.0, Color("#65534a", 0.96))
		for i in range(26):
			var angulo := float(i) * 2.399963
			var distancia := 58.0 + float((i * 47) % 145)
			var pedra := centro_impacto + Vector2(cos(angulo), sin(angulo)) * distancia
			var tamanho := 5.0 + float(i % 5) * 2.0
			draw_colored_polygon(PackedVector2Array([pedra + Vector2(-tamanho, tamanho * 0.35), pedra + Vector2(-1, -tamanho), pedra + Vector2(tamanho, tamanho * 0.5)]), Color("#51443d", 0.96))
		if tempo_impacto >= 0.0 and tempo_impacto < 4.0:
			var progresso := clampf(tempo_impacto / 4.0, 0.0, 1.0)
			var raio_onda := 35.0 + progresso * 390.0
			var opacidade := 1.0 - progresso
			draw_circle(centro_impacto, 90.0 * (1.0 - progresso) + 8.0, Color(1.0, 0.72, 0.38, 0.16 * opacidade))
			draw_arc(centro_impacto, raio_onda, 0.0, TAU, 96, Color(1.0, 0.68, 0.32, 0.9 * opacidade), 13.0 * (1.0 - progresso) + 2.0, true)
			draw_arc(centro_impacto, raio_onda * 0.82, 0.0, TAU, 96, Color(1.0, 0.91, 0.64, 0.55 * opacidade), 4.0, true)
			for i in range(24):
				var angulo := TAU * float(i) / 24.0
				var direcao := Vector2(cos(angulo), sin(angulo))
				var deslocamento := direcao * (progresso * (150.0 + float((i * 31) % 110)))
				var detrito := centro_impacto + deslocamento
				draw_colored_polygon(PackedVector2Array([detrito + Vector2(-5, 3), detrito + Vector2(0, -10), detrito + Vector2(7, 4)]), Color(0.78, 0.62, 0.45, opacidade))
		if tempo_impacto >= 0.0 and tempo_impacto < 5.0:
			for i in range(10):
				var fase := fposmod(tempo_impacto * 0.7 + float(i) * 0.13, 1.0)
				var fumaca := centro_impacto + Vector2(sin(float(i) * 4.0 + tempo_impacto) * 65.0, -fase * 105.0)
				draw_circle(fumaca, 9.0 + fase * 19.0, Color("#667078", 0.20 * (1.0 - fase)))

 
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
	# Clareiras, manchas de vegetação e regeneração gradual do solo.
	for i in range(115):
		var x := float((i * 193 + 71) % int(TAMANHO_MUNDO.x))
		var y := float((i * 317 + 43) % int(TAMANHO_MUNDO.y))
		var ponto := Vector2(x, y)
		var raio := float(18 + (i * 17) % 34)
		var tom := Color("#3d5b3e") if i % 3 == 0 else Color("#456342")
		var marca := _obter_marca_terreno_no_ponto(ponto)
		var influencia := clampf(float(marca.get("influenciaVisual", 0.0)), 0.0, 1.0)
		if influencia > 0.0:
			var tipo := str(marca.get("tipo", ""))
			var solo := Color("#4a4035")
			if tipo == "solo_congelado":
				solo = Color("#7897a2")
			elif tipo == "cicatriz_alagada":
				solo = Color("#315d5a")
			elif tipo == "solo_eletrificado":
				solo = Color("#49445f")
			elif tipo == "cratera_queimada":
				solo = Color("#302a27")
			tom = tom.lerp(solo, influencia * 0.88)
		draw_circle(ponto, raio, Color(tom, 0.72))
		# Brotos aparecem primeiro nas bordas e ficam mais verdes conforme a cicatriz some.
		if influencia > 0.025 and influencia < 0.82:
			var regeneracao := 1.0 - influencia
			var angulo_broto := float(i) * 2.399963
			var deslocamento := Vector2(cos(angulo_broto), sin(angulo_broto)) * raio * 0.48
			var base_broto := ponto + deslocamento
			var cor_broto := Color("#80a85a", 0.18 + regeneracao * 0.62)
			draw_line(base_broto, base_broto + Vector2(0, -5.0 - regeneracao * 5.0), cor_broto, 2.0, true)
			draw_circle(base_broto + Vector2(-2.5, -4.0), 2.2, cor_broto)
			draw_circle(base_broto + Vector2(2.5, -6.0), 2.2, cor_broto)
	for i in range(34):
		var x := float(250 + (i * 227) % 1850)
		var y := float(180 + (i * 149) % 1180)
		var ponto := Vector2(x, y)
		var marca := _obter_marca_terreno_no_ponto(ponto)
		var influencia := clampf(float(marca.get("influenciaVisual", 0.0)), 0.0, 1.0)
		var cor := Color("#78905a", 0.55).lerp(Color("#665b43", 0.55), influencia)
		draw_circle(ponto, float(10 + i % 9), cor)
	# Lago ao norte da capital.
	draw_circle(Vector2(1530, 420), 155, Color("#426f78"))
	draw_circle(Vector2(1530, 420), 137, Color("#568894"))

func _obter_marca_terreno_no_ponto(ponto_visual: Vector2) -> Dictionary:
	var ponto_mundo := ponto_visual + Vector2(0.0, 400.0)
	var agora := int(Time.get_unix_time_from_system())
	var melhor: Dictionary = {}
	var maior_influencia := 0.0
	var marcas: Array = estado_serpente_publico.get("marcasDestruicao", [])
	for marca in marcas:
		if not (marca is Dictionary):
			continue
		var expira := int(marca.get("expiraUnix", 0))
		var criado := int(marca.get("criadoUnix", 0))
		if expira <= agora or expira <= criado:
			continue
		var centro := Vector2(float(marca.get("x", 0.0)), float(marca.get("y", 0.0)))
		var raio := clampf(float(marca.get("raio", 24.0)), 12.0, 900.0)
		var distancia := ponto_mundo.distance_to(centro)
		if distancia > raio:
			continue
		var duracao_total := maxi(1, expira - criado)
		var progresso_recuperacao := clampf(float(agora - criado) / float(duracao_total), 0.0, 1.0)
		var intensidade_temporal := 1.0 - smoothstep(0.0, 1.0, progresso_recuperacao)
		var influencia := (1.0 - distancia / raio) * intensidade_temporal
		if influencia > maior_influencia:
			maior_influencia = influencia
			melhor = marca.duplicate(false)
			melhor["influenciaVisual"] = influencia
	return melhor


func _desenhar_biomas() -> void:
	# Floresta Arcana: copas em camadas e clareiras para leitura de profundidade.
	for i in range(46):
		var x := 280.0 + float((i * 83) % 500)
		var y := 110.0 + float((i * 137) % 1120)
		if Vector2(x, y).distance_to(Vector2(1260, 610)) < 330.0:
			continue
		if _ponto_atingido_pelo_sopro(Vector2(x, y)):
			continue
		var escala := 0.72 + float(i % 5) * 0.12
		var marca_solo := _obter_marca_terreno_no_ponto(Vector2(x, y))
		var tipo_marca := str(marca_solo.get("tipo", ""))
		var influencia := float(marca_solo.get("influenciaVisual", 0.0))
		# Fissuras profundas derrubam árvores próximas ao centro do impacto.
		if tipo_marca == "fissura_tectonica" and influencia > 0.52:
			continue
		var cor_tronco := Color("#493d31")
		var copa_base := Color("#263f32", 0.78)
		var copa_luz := Color("#55764a", 0.88)
		var copa_sombra := Color("#3d6240", 0.92)
		match tipo_marca:
			"cratera_queimada":
				cor_tronco = Color("#211f20")
				copa_base = Color("#292725", 0.92)
				copa_luz = Color("#554038", 0.86)
				copa_sombra = Color("#302a28", 0.94)
			"solo_congelado":
				cor_tronco = Color("#657d88")
				copa_base = Color("#456b78", 0.84)
				copa_luz = Color("#b0dce4", 0.88)
				copa_sombra = Color("#709ba8", 0.94)
			"solo_eletrificado":
				cor_tronco = Color("#514568")
				copa_base = Color("#34334d", 0.88)
				copa_luz = Color("#7770a0", 0.88)
				copa_sombra = Color("#49415f", 0.94)
			"cicatriz_alagada":
				cor_tronco = Color("#394e49")
				copa_base = Color("#28534c", 0.84)
				copa_luz = Color("#528d80", 0.88)
				copa_sombra = Color("#315f58", 0.94)
		if influencia > 0.0:
			cor_tronco = Color("#493d31").lerp(cor_tronco, influencia)
			copa_base = Color("#263f32", 0.78).lerp(copa_base, influencia)
			copa_luz = Color("#55764a", 0.88).lerp(copa_luz, influencia)
			copa_sombra = Color("#3d6240", 0.92).lerp(copa_sombra, influencia)
		draw_rect(Rect2(Vector2(x - 3, y + 5) * 1.0, Vector2(6, 15) * escala), cor_tronco)
		draw_circle(Vector2(x, y), 17.0 * escala, copa_base)
		draw_circle(Vector2(x - 5, y - 5), 11.0 * escala, copa_luz)
		draw_circle(Vector2(x + 5, y - 2), 9.0 * escala, copa_sombra)
		if influencia > 0.08:
			var tom_efeito := Color("#d17a4d", 0.48) if tipo_marca == "cratera_queimada" else Color("#b9e8f2", 0.52) if tipo_marca == "solo_congelado" else Color("#a99cff", 0.48) if tipo_marca == "solo_eletrificado" else Color("#72b9b0", 0.42)
			draw_circle(Vector2(x, y), 18.0 * escala, Color(tom_efeito, influencia * 0.55))
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
	# Afloramentos rochosos menores podem ser pulverizados pelo sopro primordial.
	var rochas := [
		Vector2(1040, 90), Vector2(1115, 145), Vector2(1290, 160), Vector2(1380, 230),
		Vector2(1030, 340), Vector2(1400, 390), Vector2(950, 250), Vector2(1500, 300)
	]
	for i in range(rochas.size()):
		var rocha: Vector2 = rochas[i]
		if _ponto_atingido_pelo_sopro(rocha):
			continue
		draw_colored_polygon(PackedVector2Array([rocha + Vector2(-15, 8), rocha + Vector2(-7, -13), rocha + Vector2(10, -9), rocha + Vector2(17, 8)]), Color("#686b68"))
		draw_line(rocha + Vector2(-6, -7), rocha + Vector2(3, 2), Color("#a4a69b"), 2.0, true)
	# Pequenos postos de vigia e abrigos fora da capital podem ser arrasados.
	var estruturas := [Vector2(970, 160), Vector2(1450, 200), Vector2(1050, 340)]
	for estrutura in estruturas:
		if _ponto_atingido_pelo_sopro(estrutura):
			continue
		draw_rect(Rect2(estrutura + Vector2(-17, -10), Vector2(34, 24)), Color("#68513d"))
		draw_colored_polygon(PackedVector2Array([estrutura + Vector2(-22, -10), estrutura + Vector2(0, -27), estrutura + Vector2(22, -10)]), Color("#8b6546"))
		draw_rect(Rect2(estrutura + Vector2(-4, 1), Vector2(8, 13)), Color("#302c27"))
	# Pequenos marcos de pedra nas rotas, úteis como leitura de escala.
	for marco in [Vector2(1000, 850), Vector2(1510, 700), Vector2(760, 610), Vector2(1740, 900)]:
		if _ponto_atingido_pelo_sopro(marco):
			continue
		draw_rect(Rect2(marco + Vector2(-5, -8), Vector2(10, 16)), Color("#77766a"))
		draw_rect(Rect2(marco + Vector2(-7, -10), Vector2(14, 4)), Color("#aaa28b"))


func _desenhar_floresta_detalhada() -> void:
	for i in range(78):
		var x := 760.0 + float((i * 137 + 29) % 700)
		var y := 690.0 + float((i * 211 + 71) % 760)
		var ponto := Vector2(x, y)
		if ponto.distance_to(Vector2(1190.0, 1120.0)) < 205.0 or ponto.distance_to(Vector2(1260.0, 610.0)) < 350.0:
			continue
		if _ponto_atingido_pelo_sopro(ponto):
			continue
		var escala := 0.72 + float((i * 7) % 6) * 0.105
		draw_circle(ponto + Vector2(5.0, 11.0), 17.0 * escala, Color("#172b25", 0.36))
		draw_rect(Rect2(ponto + Vector2(-3.5, -1.0), Vector2(7.0, 25.0) * escala), Color("#382b24"))
		draw_rect(Rect2(ponto + Vector2(-1.0, 5.0), Vector2(2.0, 15.0) * escala), Color("#806044"))
		draw_line(ponto + Vector2(0, 16) * escala, ponto + Vector2(-10, 21) * escala, Color("#382b24"), 3.0 * escala, true)
		draw_line(ponto + Vector2(0, 16) * escala, ponto + Vector2(11, 20) * escala, Color("#382b24"), 3.0 * escala, true)
		draw_circle(ponto + Vector2(0, -5) * escala, 22.0 * escala, Color("#14271f", 0.8))
		draw_circle(ponto + Vector2(-8, -12) * escala, 14.0 * escala, Color("#203d30"))
		draw_circle(ponto + Vector2(8, -10) * escala, 16.0 * escala, Color("#315b3d"))
		draw_circle(ponto + Vector2(-2, -19) * escala, 12.0 * escala, Color("#64834a"))
		draw_rect(Rect2(ponto + Vector2(-11, -18) * escala, Vector2(7, 4) * escala), Color("#89a85a", 0.8))
		draw_rect(Rect2(ponto + Vector2(4, -5) * escala, Vector2(6, 4) * escala), Color("#1d392b", 0.9))
		if i % 7 == 0:
			draw_circle(ponto + Vector2(-7, -18) * escala, 2.0 * escala, Color("#d8a95c"))
	for i in range(96):
		var ponto := Vector2(735.0 + float((i * 97 + 13) % 790), 720.0 + float((i * 163 + 41) % 720))
		if ponto.distance_to(Vector2(1190.0, 1120.0)) < 150.0 or ponto.distance_to(Vector2(1260.0, 610.0)) < 345.0:
			continue
		if i % 3 == 0:
			draw_circle(ponto, 5.0, Color("#25452f", 0.9))
			draw_circle(ponto + Vector2(-4, -2), 3.5, Color("#5f8548", 0.95))
			draw_circle(ponto + Vector2(4, -3), 3.0, Color("#789653", 0.9))
		elif i % 3 == 1:
			draw_colored_polygon(PackedVector2Array([ponto + Vector2(-7, 3), ponto + Vector2(-2, -8), ponto + Vector2(1, 3)]), Color("#8d9b5a", 0.9))
			draw_colored_polygon(PackedVector2Array([ponto + Vector2(0, 3), ponto + Vector2(5, -10), ponto + Vector2(8, 3)]), Color("#627f4a", 0.9))
		else:
			draw_colored_polygon(PackedVector2Array([ponto + Vector2(-7, 2), ponto + Vector2(-3, -5), ponto + Vector2(6, -4), ponto + Vector2(9, 3)]), Color("#77786a", 0.9))
			draw_line(ponto + Vector2(-2, -2), ponto + Vector2(4, -1), Color("#b5ad91"), 1.5, true)
	for i in range(15):
		var ponto := Vector2(850.0 + float((i * 79) % 560), 760.0 + float((i * 113) % 620))
		if ponto.distance_to(Vector2(1190.0, 1120.0)) < 235.0:
			continue
		draw_circle(ponto, 2.0 + float(i % 3), Color("#9bc58a", 0.32))
		draw_circle(ponto + Vector2(3, -4), 1.2, Color("#d9e8a8", 0.72))


func _desenhar_clareira_inicial() -> void:
	var centro := Vector2(1190.0, 1120.0)
	draw_circle(centro + Vector2(0, 12), 188.0, Color("#263c2c", 0.22))
	draw_circle(centro, 174.0, Color("#6e8050", 0.78))
	draw_circle(centro + Vector2(-8, -5), 145.0, Color("#82915b", 0.55))
	draw_arc(centro, 176.0, 0.0, TAU, 96, Color("#c1ae78", 0.72), 5.0, true)
	var trilha := PackedVector2Array([centro + Vector2(0, 145), centro + Vector2(22, 205), Vector2(1230, 1390), Vector2(1190, 1510)])
	draw_polyline(trilha, Color("#594b36"), 29.0, true)
	draw_polyline(trilha, Color("#b69a6a"), 20.0, true)
	for i in range(44):
		var angulo := float(i) * 2.399963
		var distancia := 38.0 + float((i * 31) % 105)
		var ponto := centro + Vector2(cos(angulo), sin(angulo)) * distancia
		if absf(ponto.x - centro.x) < 16.0 and ponto.y > centro.y + 85.0:
			continue
		draw_circle(ponto, 2.0 + float(i % 3), Color("#b2a16c") if i % 3 == 0 else Color("#536b43"))
	_desenhar_abrigo_clareira(centro + Vector2(-94, -35), 0.9)
	_desenhar_abrigo_clareira(centro + Vector2(88, -56), 0.78)
	_desenhar_abrigo_clareira(centro + Vector2(8, 88), 0.72)
	draw_circle(centro + Vector2(0, 23), 17.0, Color("#4a3a2d"))
	draw_arc(centro + Vector2(0, 23), 14.0, 0.0, TAU, 24, Color("#9c8a68"), 3.0, true)
	for i in range(5):
		var lenha := centro + Vector2(-9 + i * 4, 20 + (i % 2) * 5)
		draw_line(lenha, lenha + Vector2(10, 3), Color("#49352a"), 3.0, true)
	var marco := centro + Vector2(132, 38)
	draw_rect(Rect2(marco + Vector2(-3, -18), Vector2(6, 38)), Color("#4a3828"))
	draw_rect(Rect2(marco + Vector2(-17, -18), Vector2(34, 14)), Color("#876644"))
	draw_rect(Rect2(marco + Vector2(-13, -15), Vector2(26, 8)), Color("#c2a16b"))
	var fonte := ThemeDB.fallback_font
	if fonte != null:
		draw_string(fonte, centro + Vector2(-78, -148), "CLAREIRA INICIAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f0e2b9"))


func _desenhar_abrigo_clareira(centro: Vector2, escala: float) -> void:
	draw_rect(Rect2(centro + Vector2(-20, -5) * escala, Vector2(40, 28) * escala), Color("#4a392c"))
	draw_rect(Rect2(centro + Vector2(-17, -3) * escala, Vector2(34, 22) * escala), Color("#8b6947"))
	draw_colored_polygon(PackedVector2Array([centro + Vector2(-25, -5) * escala, centro + Vector2(0, -27) * escala, centro + Vector2(25, -5) * escala, centro + Vector2(18, 1) * escala, centro + Vector2(-18, 1) * escala]), Color("#51382c"))
	draw_colored_polygon(PackedVector2Array([centro + Vector2(-19, -7) * escala, centro + Vector2(0, -23) * escala, centro + Vector2(19, -7) * escala]), Color("#a06a43"))
	draw_rect(Rect2(centro + Vector2(-5, 8) * escala, Vector2(10, 15) * escala), Color("#302820"))
	draw_rect(Rect2(centro + Vector2(9, 2) * escala, Vector2(5, 5) * escala), Color("#e4c47a"))

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
	var centro := Vector2(1260.0, 610.0)
	draw_circle(centro + Vector2(0, 15), 210.0, Color("#1c3029", 0.42))
	draw_circle(centro, 196.0, Color("#354a3e", 0.62))
	draw_arc(centro, 184.0, 0.0, TAU, 112, Color("#b8a47a"), 13.0, true)
	draw_arc(centro, 174.0, 0.0, TAU, 112, Color("#e0c99a"), 3.0, true)
	for i in range(8):
		var angulo := TAU * float(i) / 8.0
		var direcao := Vector2(cos(angulo), sin(angulo))
		draw_line(centro + direcao * 38.0, centro + direcao * 170.0, Color("#bca77e", 0.9), 12.0, true)
		draw_line(centro + direcao * 40.0, centro + direcao * 170.0, Color("#e1c99b", 0.45), 3.0, true)
	for i in range(16):
		var angulo := TAU * float(i) / 16.0
		var pos := centro + Vector2(cos(angulo), sin(angulo)) * (119.0 + float(i % 3) * 13.0)
		_desenhar_casa_aurelia(pos, 0.78 + float(i % 4) * 0.08, i)
	for i in range(8):
		var angulo := TAU * float(i) / 8.0
		var pos := centro + Vector2(cos(angulo), sin(angulo)) * 177.0
		draw_rect(Rect2(pos + Vector2(-10, -13), Vector2(20, 27)), Color("#6f6655"))
		draw_rect(Rect2(pos + Vector2(-7, -11), Vector2(14, 22)), Color("#b9a98a"))
		draw_rect(Rect2(pos + Vector2(-12, -17), Vector2(24, 7)), Color("#574b3e"))
		for ameia in range(3):
			draw_rect(Rect2(pos + Vector2(-9 + ameia * 7, -21), Vector2(4, 5)), Color("#c8b99a"))
	draw_circle(centro, 52.0, Color("#8c8068"))
	draw_circle(centro, 44.0, Color("#d5c49f"))
	draw_arc(centro, 37.0, 0.0, TAU, 48, Color("#806b4d"), 3.0, true)
	draw_rect(Rect2(centro + Vector2(-22, -22), Vector2(44, 48)), Color("#76634d"))
	draw_rect(Rect2(centro + Vector2(-17, -18), Vector2(34, 40)), Color("#d6c39a"))
	draw_colored_polygon(PackedVector2Array([centro + Vector2(-25, -18), centro + Vector2(0, -49), centro + Vector2(25, -18)]), Color("#8d493b"))
	draw_rect(Rect2(centro + Vector2(-5, 3), Vector2(10, 19)), Color("#49372c"))
	draw_circle(centro + Vector2(0, -34), 5.0, Color("#e5c77b"))


func _desenhar_casa_aurelia(centro: Vector2, escala: float, indice: int) -> void:
	var pedra := Color("#8d8068")
	var reboco := Color("#d0b98d") if indice % 3 != 0 else Color("#b9a17c")
	var telhado := Color("#713f35") if indice % 2 == 0 else Color("#4d5150")
	draw_rect(Rect2(centro + Vector2(-17, -8) * escala, Vector2(34, 25) * escala), pedra)
	draw_rect(Rect2(centro + Vector2(-14, -6) * escala, Vector2(28, 21) * escala), reboco)
	draw_colored_polygon(PackedVector2Array([centro + Vector2(-21, -8) * escala, centro + Vector2(0, -25) * escala, centro + Vector2(21, -8) * escala, centro + Vector2(15, -3) * escala, centro + Vector2(-15, -3) * escala]), telhado)
	draw_line(centro + Vector2(-17, -7) * escala, centro + Vector2(0, -23) * escala, Color("#d1a17a"), 2.0 * escala, true)
	draw_rect(Rect2(centro + Vector2(-4, 4) * escala, Vector2(8, 13) * escala), Color("#49372b"))
	draw_rect(Rect2(centro + Vector2(7, -2) * escala, Vector2(5, 6) * escala), Color("#f1cf83"))
	draw_rect(Rect2(centro + Vector2(-13, -2) * escala, Vector2(5, 6) * escala), Color("#f1cf83"))

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
	identificacao.name = "IdentificacaoSocial"
	identificacao.text = str(perfil_visual.get("nome", "Jogador %s" % id_jogador))
	identificacao.position = Vector2(-35, -28)
	identificacao.add_theme_font_size_override("font_size", 10)
	identificacao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	remoto.add_child(identificacao)

	# Área independente do desenho para toque no celular e clique no computador.
	var area_interacao := Area2D.new()
	area_interacao.name = "AreaInteracaoSocial"
	area_interacao.collision_layer = 2
	area_interacao.collision_mask = 0
	area_interacao.input_pickable = true
	var forma_toque := CollisionShape2D.new()
	var circulo_toque := CircleShape2D.new()
	circulo_toque.radius = 20.0
	forma_toque.shape = circulo_toque
	area_interacao.add_child(forma_toque)
	area_interacao.input_event.connect(_ao_tocar_jogador_remoto.bind(id_jogador))
	remoto.add_child(area_interacao)
	add_child(remoto)
	jogadores_remotos[id_jogador] = remoto

func _ao_tocar_jogador_remoto(_viewport: Node, evento: InputEvent, _indice_forma: int, id_jogador: int) -> void:
	var toque_valido := false
	if evento is InputEventMouseButton:
		toque_valido = evento.button_index == MOUSE_BUTTON_LEFT and evento.pressed
	elif evento is InputEventScreenTouch:
		toque_valido = evento.pressed
	if not toque_valido or id_jogador == multiplayer.get_unique_id():
		return
	if is_instance_valid(interface_interacao_jogador):
		var remoto: Node2D = jogadores_remotos.get(id_jogador)
		if is_instance_valid(remoto):
			var identificacao := remoto.get_node_or_null("IdentificacaoSocial")
			var nome := str(identificacao.text) if identificacao is Label else "Jogador %d" % id_jogador
			interface_interacao_jogador.abrir(id_jogador, nome)


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

func _carregar_mimicos(lista: Array) -> void:
	var presentes: Dictionary = {}
	for dados in lista:
		if not (dados is Dictionary):
			continue
		var id := str(dados.get("id", ""))
		if id.is_empty():
			continue
		presentes[id] = true
		var entidade: Node2D
		if mimicos_mapa.has(id):
			entidade = mimicos_mapa[id]
		else:
			entidade = preload("res://scripts/mimico_bau_visual.gd").new() as Node2D
			entidade.name = "BauMimico_" + id
			add_child(entidade)
			mimicos_mapa[id] = entidade
			entidade.interacao_solicitada.connect(_ao_interagir_mimico)
		var posicao_dados: Dictionary = dados.get("posicao", {})
		entidade.call("configurar", dados)
		entidade.call("definir_posicao_mundo", Vector2(float(posicao_dados.get("x", 0.0)), float(posicao_dados.get("y", 0.0))))
	for id_antigo in mimicos_mapa.keys():
		if presentes.has(id_antigo):
			continue
		var antigo: Node = mimicos_mapa[id_antigo]
		mimicos_mapa.erase(id_antigo)
		if is_instance_valid(antigo):
			antigo.queue_free()

func _ao_interagir_mimico(bau_id: String) -> void:
	if bau_id.strip_edges().is_empty():
		return
	RedeMultiplayer.solicitar_interacao_mimico(bau_id)

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

func _ao_interagir_criatura(criatura_id: String) -> void:
	var id := criatura_id.strip_edges()
	if id.is_empty():
		return
	# Os marcadores ecológicos usam prefixo visual para não colidir com criaturas catalogadas.
	# A autoridade do servidor recebe o ID real do indivíduo, sem o prefixo de apresentação.
	if id.begins_with("grupo:"):
		id = id.trim_prefix("grupo:")
	RedeMultiplayer.solicitar_interacao_criatura(id)

func _ao_receber_aventura_sala(dados: Dictionary) -> void:
	if _transicao_para_ally_em_andamento or not bool(dados.get("participanteDoCombate", false)):
		return
	var estado_aventura: Dictionary = dados.get("estado", {})
	var encontro: Dictionary = estado_aventura.get("encontro", {})
	if not bool(encontro.get("ativo", false)):
		return
	_transicao_para_ally_em_andamento = true
	get_tree().change_scene_to_file("res://scenes/aventura_cooperativa.tscn")

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
	entidade.call("definir_interacao_habilitada", true)
	var sinal_interacao := Callable(self, "_ao_interagir_criatura")
	if not entidade.is_connected("interacao_solicitada", sinal_interacao):
		entidade.connect("interacao_solicitada", sinal_interacao)
