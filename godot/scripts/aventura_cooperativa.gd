extends Control

const TEMA_VISUAL = preload("res://scripts/tema_visual.gd")
const AVATAR_SCRIPT = preload("res://scripts/avatar_personagem.gd")
const PALCO_SCRIPT = preload("res://scripts/palco_aventura_compartilhada.gd")

var lista: RichTextLabel
var campo: LineEdit
var estado: Label
var sala: Label
var botao_enviar: Button
var area_conversa: VBoxContainer
var grupo_participantes: HBoxContainer
var palco_compartilhado: Control
var membros_ativos := 0
var conversa_aberta := false
var painel_combate: VBoxContainer
var estado_combate: Label
var lista_drops_combate: Label
var lista_dano_combate: Label
var barra_vida_criatura: ProgressBar
var linha_alvos: HBoxContainer
var alvo_selecionado_id := ""
var botoes_alvo: Array[Button] = []
var botoes_combate: Array[Button] = []

func _ready() -> void:
	TEMA_VISUAL.aplicar(self)
	_montar_interface()
	RedeMultiplayer.aventura_sala_atualizada.connect(_atualizar_aventura)
	RedeMultiplayer.sala_atualizada.connect(_atualizar_sala)
	RedeMultiplayer.resultado_mensagem_aventura.connect(_resultado_envio)
	RedeMultiplayer.erro_combate.connect(_erro_combate)
	_atualizar_sala({"codigo": RedeMultiplayer.codigo_sala_cliente, "jogadores": 1, "limite": 4})
	_atualizar_aventura(RedeMultiplayer.estado_aventura_sala_atual)

func _montar_interface() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color("#10151d")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for chave in ["margin_left", "margin_right"]:
		margem.add_theme_constant_override(chave, 10)
	margem.add_theme_constant_override("margin_top", 8)
	margem.add_theme_constant_override("margin_bottom", 8)
	add_child(margem)
	var rolagem_tela := ScrollContainer.new()
	rolagem_tela.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_tela.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem_tela.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margem.add_child(rolagem_tela)
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 6)
	rolagem_tela.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "AVENTURA COOPERATIVA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 19)
	coluna.add_child(titulo)
	sala = Label.new()
	sala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(sala)
	palco_compartilhado = PALCO_SCRIPT.new()
	palco_compartilhado.custom_minimum_size = Vector2(0, 205)
	palco_compartilhado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palco_compartilhado.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(palco_compartilhado)
	painel_combate = VBoxContainer.new()
	painel_combate.visible = false
	painel_combate.add_theme_constant_override("separation", 4)
	coluna.add_child(painel_combate)
	estado_combate = Label.new()
	estado_combate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado_combate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	painel_combate.add_child(estado_combate)
	barra_vida_criatura = ProgressBar.new()
	barra_vida_criatura.custom_minimum_size = Vector2(0, 13)
	barra_vida_criatura.show_percentage = false
	painel_combate.add_child(barra_vida_criatura)
	linha_alvos = HBoxContainer.new()
	linha_alvos.add_theme_constant_override("separation", 5)
	painel_combate.add_child(linha_alvos)
	var linha_resumo := HBoxContainer.new()
	linha_resumo.add_theme_constant_override("separation", 8)
	painel_combate.add_child(linha_resumo)
	var coluna_drops := VBoxContainer.new()
	coluna_drops.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha_resumo.add_child(coluna_drops)
	var titulo_drops := Label.new()
	titulo_drops.text = "RECOMPENSAS POSSÍVEIS"
	titulo_drops.add_theme_font_size_override("font_size", 11)
	coluna_drops.add_child(titulo_drops)
	lista_drops_combate = Label.new()
	lista_drops_combate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lista_drops_combate.add_theme_font_size_override("font_size", 10)
	coluna_drops.add_child(lista_drops_combate)
	var coluna_dano := VBoxContainer.new()
	coluna_dano.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha_resumo.add_child(coluna_dano)
	var titulo_dano := Label.new()
	titulo_dano.text = "DANO DO GRUPO"
	titulo_dano.add_theme_font_size_override("font_size", 11)
	coluna_dano.add_child(titulo_dano)
	lista_dano_combate = Label.new()
	lista_dano_combate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lista_dano_combate.add_theme_font_size_override("font_size", 10)
	coluna_dano.add_child(lista_dano_combate)
	var linha_acoes := HBoxContainer.new()
	linha_acoes.add_theme_constant_override("separation", 5)
	painel_combate.add_child(linha_acoes)
	for definicao in [{"acao":"ataque","texto":"Atacar"},{"acao":"defender","texto":"Defender"},{"acao":"esquivar","texto":"Esquivar"}]:
		var botao := Button.new()
		botao.text = str(definicao.texto)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var acao := str(definicao.acao)
		botao.pressed.connect(_solicitar_acao_combate.bind(acao))
		linha_acoes.add_child(botao)
		botoes_combate.append(botao)
	var titulo_grupo := Label.new()
	titulo_grupo.text = "GRUPO DE AVENTUREIROS"
	titulo_grupo.add_theme_font_size_override("font_size", 12)
	coluna.add_child(titulo_grupo)
	var rolagem_grupo := ScrollContainer.new()
	rolagem_grupo.custom_minimum_size = Vector2(0, 112)
	coluna.add_child(rolagem_grupo)
	grupo_participantes = HBoxContainer.new()
	grupo_participantes.add_theme_constant_override("separation", 8)
	rolagem_grupo.add_child(grupo_participantes)
	var titulo_eventos := Label.new()
	titulo_eventos.text = "REGISTRO COMPARTILHADO"
	titulo_eventos.add_theme_font_size_override("font_size", 12)
	coluna.add_child(titulo_eventos)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.custom_minimum_size = Vector2(0, 54)
	coluna.add_child(rolagem)
	lista = RichTextLabel.new()
	lista.bbcode_enabled = true
	lista.fit_content = true
	lista.scroll_following = true
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.custom_minimum_size = Vector2(300, 50)
	rolagem.add_child(lista)
	var abrir_conversa := Button.new()
	abrir_conversa.text = "Abrir conversa do grupo"
	abrir_conversa.pressed.connect(_alternar_conversa)
	coluna.add_child(abrir_conversa)
	area_conversa = VBoxContainer.new()
	area_conversa.visible = false
	coluna.add_child(area_conversa)
	campo = LineEdit.new()
	campo.placeholder_text = "Converse com o grupo (até 300 caracteres)"
	campo.max_length = 300
	campo.text_submitted.connect(_enviar)
	area_conversa.add_child(campo)
	botao_enviar = Button.new()
	botao_enviar.text = "Enviar mensagem"
	botao_enviar.pressed.connect(_enviar)
	area_conversa.add_child(botao_enviar)
	estado = Label.new()
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(estado)
	var voltar_mundo := Button.new()
	voltar_mundo.text = "Voltar ao mundo compartilhado"
	voltar_mundo.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/mundo_principal.tscn"))
	coluna.add_child(voltar_mundo)
	var sair := Button.new()
	sair.text = "Sair da sala"
	sair.pressed.connect(_desconectar)
	coluna.add_child(sair)

func _alternar_conversa() -> void:
	conversa_aberta = not conversa_aberta
	area_conversa.visible = conversa_aberta

func _atualizar_sala(dados: Dictionary) -> void:
	if not is_instance_valid(sala):
		return
	membros_ativos = int(dados.get("jogadores", 0))
	sala.text = "Sala %s • %d/%d participantes" % [str(dados.get("codigo", "------")), membros_ativos, int(dados.get("limite", 4))]
	for filho in grupo_participantes.get_children():
		filho.queue_free()
	var participantes: Array = dados.get("participantes", [])
	palco_compartilhado.call("configurar_participantes", participantes)
	for participante in participantes:
		if participante is Dictionary:
			_adicionar_cartao_participante(participante)
	if participantes.is_empty():
		var aguardando := Label.new()
		aguardando.text = "Aguardando aventureiros..."
		grupo_participantes.add_child(aguardando)
	if is_instance_valid(botao_enviar):
		botao_enviar.disabled = membros_ativos < 2
	if is_instance_valid(estado) and membros_ativos < 2:
		estado.text = "A aventura compartilhada começa quando pelo menos dois jogadores estiverem na sala."

func _adicionar_cartao_participante(participante: Dictionary) -> void:
	var cartao := PanelContainer.new()
	cartao.custom_minimum_size = Vector2(108, 0)
	grupo_participantes.add_child(cartao)
	var coluna_cartao := VBoxContainer.new()
	coluna_cartao.add_theme_constant_override("separation", 2)
	cartao.add_child(coluna_cartao)
	var visual: Dictionary = participante.get("visual", {}) if participante.get("visual", {}) is Dictionary else {}
	var moldura := SubViewportContainer.new()
	moldura.custom_minimum_size = Vector2(88, 68)
	moldura.stretch = true
	coluna_cartao.add_child(moldura)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 76)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	moldura.add_child(viewport)
	var avatar := Node2D.new()
	avatar.set_script(AVATAR_SCRIPT)
	viewport.add_child(avatar)
	avatar.position = Vector2(48, 55)
	avatar.call("configurar", visual)
	avatar.scale = avatar.scale * Vector2(2.1, 2.1)
	var nome := Label.new()
	nome.text = str(participante.get("nome", "Aventureiro")) + (" ★" if bool(participante.get("anfitriao", false)) else "")
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.add_theme_font_size_override("font_size", 10)
	coluna_cartao.add_child(nome)
	var nivel := Label.new()
	nivel.text = "Nível %d" % int(visual.get("nivel", 1))
	nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nivel.add_theme_font_size_override("font_size", 9)
	coluna_cartao.add_child(nivel)
	_adicionar_barra(coluna_cartao, int(visual.get("vida", 0)), int(visual.get("vidaMaxima", 1)), Color("#a94c4c"))
	_adicionar_barra(coluna_cartao, int(visual.get("mana", 0)), int(visual.get("manaMaxima", 1)), Color("#4e83b5"))

func _adicionar_barra(pai: VBoxContainer, atual: int, maximo: int, cor: Color) -> void:
	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(0, 7)
	barra.show_percentage = false
	barra.max_value = maxi(1, maximo)
	barra.value = clampi(atual, 0, maxi(1, maximo))
	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = cor
	preenchimento.set_corner_radius_all(2)
	barra.add_theme_stylebox_override("fill", preenchimento)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("#252832")
	fundo.set_corner_radius_all(2)
	barra.add_theme_stylebox_override("background", fundo)
	pai.add_child(barra)

func _atualizar_aventura(dados: Dictionary) -> void:
	if not is_instance_valid(lista):
		return
	var estado_aventura: Dictionary = dados.get("estado", {})
	var encontro: Dictionary = estado_aventura.get("encontro", {})
	if is_instance_valid(palco_compartilhado):
		palco_compartilhado.call("configurar_encontro", encontro)
	_atualizar_painel_combate(encontro)
	var mensagens: Array = estado_aventura.get("mensagens", [])
	lista.clear()
	if mensagens.is_empty():
		lista.append_text("[color=#c8b994]O diário está vazio. Os acontecimentos da aventura aparecerão aqui.[/color]")
		return
	for mensagem in mensagens:
		if not mensagem is Dictionary:
			continue
		var autor := str(mensagem.get("autor", "Aventureiro")).replace("[", "(").replace("]", ")")
		var texto := str(mensagem.get("texto", "")).replace("[", "(").replace("]", ")")
		lista.append_text("[color=#e5c98e]%s:[/color] %s\n" % [autor, texto])

func _atualizar_painel_combate(encontro: Dictionary) -> void:
	if not is_instance_valid(painel_combate):
		return
	var combate: Dictionary = encontro.get("combate", {})
	var ativo := bool(encontro.get("ativo", false)) and str(combate.get("status", "")) == "em_andamento"
	painel_combate.visible = ativo
	if not ativo:
		if not str(encontro.get("resultado", "")).is_empty() and is_instance_valid(estado):
			var resultado_final := str(encontro.get("resultado", ""))
			if resultado_final == "vitoria":
				estado.text = "Vitória! Recompensas da equipe processadas. O grupo continua na aventura compartilhada."
			elif resultado_final == "derrota":
				var recursos_restaurados := bool(encontro.get("recursosDerrotaConcluidos", false))
				estado.text = "Toda a equipe foi derrotada. " + ("HP e Mana restaurados. Perda de 50% da experiência acumulada e 20% do valor das moedas aplicada." if recursos_restaurados else "Registrando penalidades e restaurando os recursos da equipe...")
			else:
				estado.text = "Combate encerrado: " + resultado_final.replace("_", " ")
		return
	var membros: Array = combate.get("participantes", [])
	var indice := int(combate.get("indiceTurno", -1))
	var nome_turno := "Aguardando turno"
	if bool(combate.get("aguardandoReconexao", false)):
		nome_turno = "Aguardando reconexão de um aventureiro vivo"
	elif indice >= 0 and indice < membros.size():
		nome_turno = str(membros[indice].get("nome", "Aventureiro"))
	var criatura: Dictionary = combate.get("criatura", {})
	var inimigos: Array = combate.get("inimigos", []) if combate.get("inimigos", []) is Array else []
	if inimigos.is_empty():
		inimigos = [criatura]
	alvo_selecionado_id = str(combate.get("alvoSelecionadoId", criatura.get("id", "")))
	var alvo_atual: Dictionary = criatura
	for inimigo in inimigos:
		if str(inimigo.get("id", "")) == alvo_selecionado_id:
			alvo_atual = inimigo
			break
	for filho_alvo in linha_alvos.get_children():
		filho_alvo.queue_free()
	botoes_alvo.clear()
	for inimigo in inimigos:
		var id_alvo := str(inimigo.get("id", ""))
		var botao_alvo := Button.new()
		botao_alvo.text = "%s %d/%d" % [str(inimigo.get("nome", "Criatura")).substr(0, 12), int(inimigo.get("vida", 0)), int(inimigo.get("vidaMaxima", 1))]
		botao_alvo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao_alvo.disabled = int(inimigo.get("vida", 0)) <= 0 or not bool(combate.get("turnoDoCliente", false))
		botao_alvo.button_pressed = id_alvo == alvo_selecionado_id
		botao_alvo.pressed.connect(_selecionar_alvo.bind(id_alvo))
		linha_alvos.add_child(botao_alvo)
		botoes_alvo.append(botao_alvo)
	var vidas: Array[String] = []
	for membro in membros:
		var situacao := " (derrotado)" if int(membro.get("vida", 0)) <= 0 else ""
		vidas.append("%s %d/%d%s" % [str(membro.get("nome", "Aventureiro")).substr(0, 12), int(membro.get("vida", 0)), int(membro.get("vidaMaxima", 1)), situacao])
	var resumo_inimigos := "%d criatura(s)" % inimigos.size()
	estado_combate.text = "%s • %s • Vida %d/%d • Rodada %d\nAlvos: %s\nEquipe: %s\nQuem for derrotado continuará elegível às recompensas se o grupo vencer." % [nome_turno, str(alvo_atual.get("nome", encontro.get("nome", "Criatura"))), int(alvo_atual.get("vida", 0)), int(alvo_atual.get("vidaMaxima", 1)), int(combate.get("rodada", 1)), resumo_inimigos, " | ".join(vidas)]
	barra_vida_criatura.max_value = maxi(1, int(alvo_atual.get("vidaMaxima", 1)))
	barra_vida_criatura.value = clampi(int(alvo_atual.get("vida", 0)), 0, maxi(1, int(alvo_atual.get("vidaMaxima", 1))))
	var total_dano := 0
	for membro_dano in membros:
		total_dano += maxi(0, int(membro_dano.get("danoCausado", 0)))
	var ranking: Array = membros.duplicate(true)
	ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("danoCausado", 0)) > int(b.get("danoCausado", 0)))
	var linhas_dano: Array[String] = []
	for posicao in range(ranking.size()):
		var contribuinte: Dictionary = ranking[posicao]
		var dano_jogador := maxi(0, int(contribuinte.get("danoCausado", 0)))
		var percentual := 0.0 if total_dano <= 0 else float(dano_jogador) * 100.0 / float(total_dano)
		var situacao_dano := " • derrotado" if int(contribuinte.get("vida", 0)) <= 0 else ""
		linhas_dano.append("%d. %s — %d (%.1f%%)%s" % [posicao + 1, str(contribuinte.get("nome", "Aventureiro")).substr(0, 18), dano_jogador, percentual, situacao_dano])
	lista_dano_combate.text = "\n".join(linhas_dano) if not linhas_dano.is_empty() else "Aguardando dano..."
	var drops: Array = encontro.get("dropsPrevistos", [])
	var linhas_drops: Array[String] = []
	for drop in drops:
		if drop is Dictionary:
			linhas_drops.append("• %s [%s]" % [str(drop.get("nome", "Recompensa")), str(drop.get("raridade", "comum"))])
	lista_drops_combate.text = "\n".join(linhas_drops) if not linhas_drops.is_empty() else "Nenhum drop catalogado."
	var meu_turno := bool(combate.get("turnoDoCliente", false))
	for botao in botoes_combate:
		botao.disabled = not meu_turno
	for botao_alvo_atual in botoes_alvo:
		botao_alvo_atual.disabled = not meu_turno or botao_alvo_atual.text.ends_with("0/1")


func _selecionar_alvo(id_alvo: String) -> void:
	alvo_selecionado_id = id_alvo
	for botao in botoes_alvo:
		botao.button_pressed = botao.text.begins_with(str(id_alvo))


func _solicitar_acao_combate(acao: String) -> void:
	RedeMultiplayer.solicitar_acao_encontro_cooperativo(acao, alvo_selecionado_id)

func _erro_combate(mensagem: String) -> void:
	if is_instance_valid(estado):
		estado.text = mensagem


func _enviar(_texto: String = "") -> void:
	if not is_instance_valid(campo) or not is_instance_valid(botao_enviar):
		return
	var mensagem := campo.text.strip_edges()
	if mensagem.is_empty():
		estado.text = "Escreva uma mensagem antes de enviar."
		return
	botao_enviar.disabled = true
	RedeMultiplayer.enviar_mensagem_aventura_sala(mensagem)
	campo.clear()

func _resultado_envio(_sucesso: bool, mensagem: String) -> void:
	if not is_instance_valid(estado):
		return
	estado.text = mensagem
	if is_instance_valid(botao_enviar):
		botao_enviar.disabled = membros_ativos < 2

func _desconectar() -> void:
	RedeMultiplayer.desconectar()
	get_tree().change_scene_to_file("res://scenes/conexao_multiplayer.tscn")
