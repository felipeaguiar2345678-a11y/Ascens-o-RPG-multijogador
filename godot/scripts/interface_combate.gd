extends CanvasLayer

const SistemaCombate = preload("res://scripts/sistema_combate.gd")
const TEMA_VISUAL = preload("res://scripts/tema_visual.gd")
## Interface de combate por turnos; apenas envia intenções ao servidor autoritativo.

var painel: PanelContainer
var titulo: Label
var palco: Control
var barra_vida_jogador: ProgressBar
var texto_vida_jogador: Label
var barra_mana: ProgressBar
var texto_mana: Label
var painel_inimigos: VBoxContainer
var historico: RichTextLabel
var mensagem: Label
var botoes: Array[Button] = []
var aguardando_resposta := false
var alvo_selecionado_id := ""
var combate_ativo := false
var botao_habilidade: Button
var habilidade_atual_id := ""

func _ready() -> void:
	layer = 20
	_construir_interface()
	RedeMultiplayer.combate_atualizado.connect(_ao_atualizar_combate)
	RedeMultiplayer.combate_finalizado.connect(_ao_finalizar_combate)
	RedeMultiplayer.erro_combate.connect(_ao_erro_combate)
	RedeMultiplayer.relogio_mundo_atualizado.connect(Callable(palco, "atualizar_contexto_celeste"))
	visible = false

func _construir_interface() -> void:
	painel = PanelContainer.new()
	painel.name = "PainelCombate"
	TEMA_VISUAL.aplicar(painel)
	painel.anchor_left = 0.08
	painel.anchor_top = 0.06
	painel.anchor_right = 0.92
	painel.anchor_bottom = 0.94
	painel.offset_left = 0
	painel.offset_top = 0
	painel.offset_right = 0
	painel.offset_bottom = 0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#171d25")
	estilo.border_color = Color("#b99a62")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	painel.add_theme_stylebox_override("panel", estilo)
	add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 7)
	painel.add_child(coluna)

	titulo = Label.new()
	titulo.text = "COMBATE"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 21)
	titulo.add_theme_color_override("font_color", Color("#f0d39b"))
	coluna.add_child(titulo)

	palco = preload("res://scripts/palco_combate.gd").new()
	palco.name = "PalcoVisualCombate"
	coluna.add_child(palco)
	palco.alvo_selecionado.connect(_ao_selecionar_alvo)

	var jogador_linha := HBoxContainer.new()
	coluna.add_child(jogador_linha)
	texto_vida_jogador = Label.new()
	texto_vida_jogador.custom_minimum_size.x = 100
	jogador_linha.add_child(texto_vida_jogador)
	barra_vida_jogador = _criar_barra(Color("#b94c4c"))
	jogador_linha.add_child(barra_vida_jogador)

	var mana_linha := HBoxContainer.new()
	coluna.add_child(mana_linha)
	texto_mana = Label.new()
	texto_mana.custom_minimum_size.x = 100
	mana_linha.add_child(texto_mana)
	barra_mana = _criar_barra(Color("#477fc2"))
	mana_linha.add_child(barra_mana)

	painel_inimigos = VBoxContainer.new()
	painel_inimigos.add_theme_constant_override("separation", 3)
	coluna.add_child(painel_inimigos)

	var separador := HSeparator.new()
	coluna.add_child(separador)
	var rotulo_historico := Label.new()
	rotulo_historico.text = "Aconteceu na batalha"
	rotulo_historico.add_theme_color_override("font_color", Color("#d9c59e"))
	coluna.add_child(rotulo_historico)
	historico = RichTextLabel.new()
	historico.bbcode_enabled = false
	historico.scroll_following = true
	historico.size_flags_vertical = Control.SIZE_EXPAND_FILL
	historico.custom_minimum_size.y = 75
	coluna.add_child(historico)

	mensagem = Label.new()
	mensagem.text = "Escolha sua ação."
	mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(mensagem)

	var acoes := GridContainer.new()
	acoes.columns = 2
	acoes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_child(acoes)
	_adicionar_botao(acoes, "Atacar", SistemaCombate.ACAO_ATAQUE)
	_adicionar_botao(acoes, "Usar magia (8 PM)", SistemaCombate.ACAO_MAGIA)
	botao_habilidade = Button.new()
	botao_habilidade.text = "Habilidade inicial"
	botao_habilidade.custom_minimum_size = Vector2(0, 38)
	botao_habilidade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao_habilidade.pressed.connect(_solicitar_habilidade)
	acoes.add_child(botao_habilidade)
	_adicionar_botao(acoes, "Defender", SistemaCombate.ACAO_DEFENDER)
	_adicionar_botao(acoes, "Esquivar", SistemaCombate.ACAO_ESQUIVAR)

	var fechar := Button.new()
	fechar.text = "Fechar resultado"
	fechar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fechar.pressed.connect(_fechar_resultado)
	coluna.add_child(fechar)
	fechar.visible = false
	fechar.name = "BotaoFecharResultado"

func _criar_barra(cor: Color) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(100, 18)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.show_percentage = false
	barra.add_theme_stylebox_override("fill", _estilo_barra(cor))
	barra.add_theme_stylebox_override("background", _estilo_barra(Color("#343b46")))
	return barra

func _estilo_barra(cor: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_corner_radius_all(3)
	return estilo

func _adicionar_botao(conteiner: GridContainer, rotulo: String, acao: String) -> void:
	var botao := Button.new()
	botao.text = rotulo
	botao.custom_minimum_size = Vector2(0, 38)
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao.pressed.connect(_solicitar_acao.bind(acao))
	conteiner.add_child(botao)
	botoes.append(botao)

func _solicitar_acao(acao: String) -> void:
	if not combate_ativo or aguardando_resposta:
		return
	aguardando_resposta = true
	_atualizar_botoes()
	mensagem.text = "Aguardando resposta do servidor..."
	RedeMultiplayer.solicitar_acao_combate(acao, alvo_selecionado_id)

func _ao_atualizar_combate(estado: Dictionary) -> void:
	combate_ativo = str(estado.get("status", "")) == "em_andamento"
	aguardando_resposta = false
	visible = true
	var jogador: Dictionary = estado.get("jogador", {})
	var inimigo: Dictionary = estado.get("inimigo", {})
	var inimigos: Array = estado.get("inimigos", [inimigo])
	if inimigos.is_empty():
		inimigos = [inimigo]
	titulo.text = "BATALHA — %d %s" % [inimigos.size(), "criatura" if inimigos.size() == 1 else "criaturas"]
	if alvo_selecionado_id.is_empty() or not _alvo_ainda_vivo(inimigos, alvo_selecionado_id):
		alvo_selecionado_id = str(estado.get("alvoSelecionadoId", ""))
	palco.configurar_grupo(jogador, inimigos, alvo_selecionado_id, estado.get("invocacao", {}))
	var ataques_visuais: Array = []
	for inimigo_aviso in inimigos:
		var ataque_visual: Dictionary = inimigo_aviso.get("ataqueEspecialPreparando", {})
		if not ataque_visual.is_empty():
			var ataque_com_origem := ataque_visual.duplicate(true)
			ataque_com_origem["origemNome"] = str(inimigo_aviso.get("nome", "Criatura"))
			ataques_visuais.append(ataque_com_origem)
	palco.configurar_ataques_telegrafados(ataques_visuais)
	_atualizar_botao_habilidade(jogador)
	var efeito_habilidade: Dictionary = estado.get("efeitoHabilidade", {})
	if not efeito_habilidade.is_empty():
		palco.configurar_efeito_habilidade(efeito_habilidade)
	_atualizar_barra(barra_vida_jogador, texto_vida_jogador, "Vida", int(jogador.get("vida", 0)), int(jogador.get("vidaMaxima", 1)))
	_atualizar_barra(barra_mana, texto_mana, "Mana", int(jogador.get("mana", 0)), int(jogador.get("manaMaxima", 1)))
	_atualizar_painel_inimigos(inimigos)
	var eventos: Array = estado.get("historico", [])
	historico.text = "\n".join(PackedStringArray(eventos.map(func(item): return str(item))))
	if not eventos.is_empty():
		var evento_visual := str(eventos.back())
		for indice_evento in range(eventos.size() - 1, maxi(-1, eventos.size() - 2), -1):
			var candidato := str(eventos[indice_evento]).to_lower()
			if "executa" in candidato and ("constrição" in candidato or "constricao" in candidato or "onda" in candidato or "tremor" in candidato or "sopro" in candidato):
				evento_visual = str(eventos[indice_evento])
				break
		palco.registrar_evento(evento_visual)
	if combate_ativo:
		var avisos_ataque: Array[String] = []
		for inimigo_aviso in inimigos:
			var ataque_pendente: Dictionary = inimigo_aviso.get("ataqueEspecialPreparando", {})
			if not ataque_pendente.is_empty():
				avisos_ataque.append("%s: %s" % [inimigo_aviso.get("nome", "Criatura"), ataque_pendente.get("nome", "ataque especial")])
		if not avisos_ataque.is_empty():
			mensagem.text = "⚠ ATAQUE PREPARADO — %s. Escolha DEFENDER ou ESQUIVAR agora!" % " | ".join(avisos_ataque)
		else:
			mensagem.text = "Sua vez. Escolha uma ação."
	else:
		mensagem.text = "A batalha terminou. Aguarde o resultado confirmado pelo servidor."
	_atualizar_botoes()
	_botao_fechar().visible = false

func _atualizar_botao_habilidade(jogador: Dictionary) -> void:
	var habilidades: Array = jogador.get("habilidades", [])
	if habilidades.is_empty() or not (habilidades[0] is Dictionary):
		habilidade_atual_id = ""
		botao_habilidade.text = "Sem habilidade"
		botao_habilidade.disabled = true
		return
	var habilidade: Dictionary = habilidades[0]
	habilidade_atual_id = str(habilidade.get("id", ""))
	var custo := int(habilidade.get("custoMana", 0))
	botao_habilidade.text = "%s (%d PM)" % [str(habilidade.get("nome", "Habilidade")), custo]
	botao_habilidade.disabled = not combate_ativo or aguardando_resposta or int(jogador.get("mana", 0)) < custo

func _solicitar_habilidade() -> void:
	if not combate_ativo or aguardando_resposta or habilidade_atual_id.is_empty():
		return
	aguardando_resposta = true
	_atualizar_botoes()
	botao_habilidade.disabled = true
	mensagem.text = "Preparando habilidade..."
	RedeMultiplayer.solicitar_acao_combate(SistemaCombate.ACAO_HABILIDADE, alvo_selecionado_id, habilidade_atual_id)

func _ao_selecionar_alvo(individuo_id: String) -> void:
	if aguardando_resposta or not combate_ativo:
		return
	alvo_selecionado_id = individuo_id
	palco.definir_alvo_selecionado(alvo_selecionado_id)
	mensagem.text = "Alvo selecionado. Escolha sua ação."

func _alvo_ainda_vivo(inimigos: Array, individuo_id: String) -> bool:
	for inimigo in inimigos:
		if str(inimigo.get("id", "")) == individuo_id and int(inimigo.get("vida", 0)) > 0:
			return true
	return false

func _atualizar_painel_inimigos(inimigos: Array) -> void:
	for filho in painel_inimigos.get_children():
		painel_inimigos.remove_child(filho)
		filho.queue_free()
	for indice in range(mini(3, inimigos.size())):
		var inimigo: Dictionary = inimigos[indice]
		var linha := HBoxContainer.new()
		painel_inimigos.add_child(linha)
		var rotulo := Label.new()
		rotulo.custom_minimum_size.x = 112
		rotulo.text = str(inimigo.get("nome", "Criatura"))
		linha.add_child(rotulo)
		var barra := _criar_barra(Color("#a34b42"))
		linha.add_child(barra)
		barra.max_value = maxi(1, int(inimigo.get("vidaMaxima", 1)))
		barra.value = clampi(int(inimigo.get("vida", 0)), 0, int(barra.max_value))
		var vida := Label.new()
		vida.custom_minimum_size.x = 58
		vida.text = "%d/%d" % [int(inimigo.get("vida", 0)), int(inimigo.get("vidaMaxima", 1))]
		linha.add_child(vida)

func _atualizar_barra(barra: ProgressBar, rotulo: Label, nome: String, atual: int, maximo: int) -> void:
	barra.max_value = maxi(1, maximo)
	barra.value = clampi(atual, 0, maxi(1, maximo))
	rotulo.text = "%s %d/%d" % [nome, atual, maximo]

func _ao_finalizar_combate(status: String, drops: Array) -> void:
	combate_ativo = false
	aguardando_resposta = false
	_atualizar_botoes()
	if status == "vitoria":
		var obtidos := 0
		for tentativa in drops:
			if tentativa is Dictionary and bool(tentativa.get("obtido", false)):
				obtidos += 1
		mensagem.text = "Vitória! %d recompensa(s) obtida(s) de %d roleta(s)." % [obtidos, drops.size()]
		_animar_resultados_roleta(drops)
	else:
		mensagem.text = "Você foi derrotado. Seus recursos foram restaurados."
	_botao_fechar().visible = true

## A animação só revela o resultado já decidido pelo servidor; nunca sorteia localmente.
func _animar_resultados_roleta(resultados: Array) -> void:
	if resultados.is_empty():
		historico.text += "\n\nNenhuma recompensa disponível nesta batalha."
		return
	historico.text += "\n\nROLETA DE RECOMPENSAS"
	for tentativa in resultados:
		if not (tentativa is Dictionary):
			continue
		var nome := str(tentativa.get("nome", tentativa.get("itemId", "Recompensa")))
		var chance := float(tentativa.get("chanceFinal", 0.0)) * 100.0
		for giro in range(6):
			mensagem.text = "🎰 %s  %s" % [nome, "❌" if giro % 2 == 0 else "✅"]
			await get_tree().create_timer(0.12).timeout
		if bool(tentativa.get("obtido", false)):
			var linha_sucesso := "✅ %s ×%d — chance %.2f%%" % [nome, int(tentativa.get("quantidade", 1)), chance]
			historico.text += "\n" + linha_sucesso
			mensagem.text = "✨ RECOMPENSA CONQUISTADA: %s!" % nome
		else:
			var linha_falha := "❌ %s — chance %.2f%%" % [nome, chance]
			historico.text += "\n" + linha_falha
			mensagem.text = "A roleta não concedeu: %s." % nome
		await get_tree().create_timer(0.28).timeout
	mensagem.text = "Roletas concluídas. Confira os resultados acima."

func _ao_erro_combate(texto: String) -> void:
	aguardando_resposta = false
	mensagem.text = texto
	_atualizar_botoes()

func _atualizar_botoes() -> void:
	for botao in botoes:
		botao.disabled = not combate_ativo or aguardando_resposta
	if is_instance_valid(botao_habilidade):
		botao_habilidade.disabled = not combate_ativo or aguardando_resposta or habilidade_atual_id.is_empty()

func _botao_fechar() -> Button:
	return painel.get_node("VBoxContainer/BotaoFecharResultado") as Button

func _fechar_resultado() -> void:
	if combate_ativo:
		return
	visible = false
	historico.clear()
	mensagem.text = ""
