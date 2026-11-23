extends CanvasLayer
## Interface provisória de inventário e equipamentos.
## Toda alteração é solicitada ao servidor; esta tela nunca modifica o perfil localmente.

const SistemaEquipamentos = preload("res://scripts/sistema_equipamentos.gd")
const TEMA_VISUAL = preload("res://scripts/tema_visual.gd")

var painel: PanelContainer
var lista_inventario: VBoxContainer
var lista_equipados: VBoxContainer
var lista_habilidades: VBoxContainer
var lista_invocacoes: VBoxContainer
var mensagem: Label
var botao_abrir: Button
var _perfil: Dictionary = {}

func _ready() -> void:
	_criar_interface()
	RedeMultiplayer.perfil_personagem_recebido.connect(_ao_receber_perfil)
	RedeMultiplayer.resultado_equipamento.connect(_ao_resultado_equipamento)
	RedeMultiplayer.resultado_selecao_invocacao.connect(_ao_resultado_selecao_invocacao)
	if not RedeMultiplayer.perfil_personagem_atual.is_empty():
		_ao_receber_perfil(RedeMultiplayer.perfil_personagem_atual)

func _criar_interface() -> void:
	botao_abrir = Button.new()
	botao_abrir.text = "✦ Mochila"
	TEMA_VISUAL.aplicar(botao_abrir)
	botao_abrir.custom_minimum_size = Vector2(104, 42)
	botao_abrir.anchor_left = 1.0
	botao_abrir.anchor_right = 1.0
	botao_abrir.offset_left = -122.0
	botao_abrir.offset_right = -18.0
	botao_abrir.offset_top = 18.0
	botao_abrir.offset_bottom = 60.0
	botao_abrir.pressed.connect(_alternar_painel)
	add_child(botao_abrir)

	painel = PanelContainer.new()
	painel.name = "PainelInventarioEquipamentos"
	TEMA_VISUAL.aplicar(painel)
	painel.anchor_left = 1.0
	painel.anchor_right = 1.0
	painel.anchor_top = 0.0
	painel.anchor_bottom = 0.0
	painel.offset_left = -310.0
	painel.offset_right = -16.0
	painel.offset_top = 70.0
	painel.offset_bottom = 520.0
	painel.visible = false
	add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 7)
	painel.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "INVENTÁRIO E EQUIPAMENTOS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 15)
	coluna.add_child(titulo)
	var titulo_habilidades := Label.new()
	titulo_habilidades.text = "Habilidades aprendidas"
	coluna.add_child(titulo_habilidades)
	lista_habilidades = VBoxContainer.new()
	lista_habilidades.custom_minimum_size.y = 48
	coluna.add_child(lista_habilidades)

	var subtitulo_companheiros := Label.new()
	subtitulo_companheiros.text = "Coleção de companheiros"
	coluna.add_child(subtitulo_companheiros)
	var rolagem_companheiros := ScrollContainer.new()
	rolagem_companheiros.custom_minimum_size = Vector2(0, 88)
	rolagem_companheiros.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(rolagem_companheiros)
	lista_invocacoes = VBoxContainer.new()
	lista_invocacoes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_companheiros.add_child(lista_invocacoes)

	var subtitulo := Label.new()
	subtitulo.text = "Equipamentos usados"
	coluna.add_child(subtitulo)

	var rolagem_equipados := ScrollContainer.new()
	rolagem_equipados.custom_minimum_size = Vector2(0, 145)
	rolagem_equipados.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(rolagem_equipados)
	lista_equipados = VBoxContainer.new()
	lista_equipados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_equipados.add_child(lista_equipados)

	var divisor := HSeparator.new()
	coluna.add_child(divisor)

	var subtitulo_itens := Label.new()
	subtitulo_itens.text = "Sua mochila"
	coluna.add_child(subtitulo_itens)

	var rolagem_itens := ScrollContainer.new()
	rolagem_itens.custom_minimum_size = Vector2(0, 175)
	rolagem_itens.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(rolagem_itens)
	lista_inventario = VBoxContainer.new()
	lista_inventario.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_itens.add_child(lista_inventario)

	mensagem = Label.new()
	mensagem.text = "As alterações são confirmadas pelo servidor."
	mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensagem.add_theme_font_size_override("font_size", 11)
	coluna.add_child(mensagem)

func _alternar_painel() -> void:
	painel.visible = not painel.visible
	if painel.visible:
		_atualizar_tela()

func _ao_receber_perfil(dados: Dictionary) -> void:
	_perfil = dados.duplicate(true)
	if is_instance_valid(painel) and painel.visible:
		_atualizar_tela()

func _ao_resultado_equipamento(sucesso: bool, texto: String) -> void:
	if not is_instance_valid(mensagem):
		return
	mensagem.text = texto
	mensagem.add_theme_color_override("font_color", Color("#9bd69b") if sucesso else Color("#f09b8d"))
	if sucesso:
		_perfil = RedeMultiplayer.perfil_personagem_atual.duplicate(true)
		_atualizar_tela()

func _atualizar_tela() -> void:
	if not is_instance_valid(lista_inventario) or not is_instance_valid(lista_equipados):
		return
	_limpar(lista_equipados)
	_limpar(lista_inventario)
	_limpar(lista_habilidades)
	_limpar(lista_invocacoes)
	var habilidades: Array = _perfil.get("habilidades", [])
	if habilidades.is_empty():
		var sem_habilidade := Label.new()
		sem_habilidade.text = "Nenhuma habilidade registrada."
		lista_habilidades.add_child(sem_habilidade)
	else:
		for habilidade in habilidades:
			if not (habilidade is Dictionary):
				continue
			var detalhe := Label.new()
			detalhe.text = "%s — %s, nível %d\n%s\nElemento: %s | Raridade: %s | Custo: %d PM" % [str(habilidade.get("nome", "Habilidade")), str(habilidade.get("categoria", "técnica")), int(habilidade.get("nivel", 1)), str(habilidade.get("descricao", "")), str(habilidade.get("elemento", "arcano")), str(habilidade.get("raridade", "comum")).capitalize(), int(habilidade.get("custoMana", 0))]
			detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detalhe.add_theme_font_size_override("font_size", 11)
			lista_habilidades.add_child(detalhe)

	var invocacoes: Array = _perfil.get("invocacoes", [])
	var ativa_id := str(_perfil.get("invocacaoAtivaId", ""))
	if invocacoes.is_empty():
		var sem_companheiros := Label.new()
		sem_companheiros.text = "Nenhum companheiro na coleção."
		sem_companheiros.add_theme_font_size_override("font_size", 11)
		lista_invocacoes.add_child(sem_companheiros)
	else:
		for invocacao in invocacoes:
			if not invocacao is Dictionary:
				continue
			var id_invocacao := str(invocacao.get("id", ""))
			var linha_companheiro := HBoxContainer.new()
			linha_companheiro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var dados_companheiro := Label.new()
			dados_companheiro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dados_companheiro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dados_companheiro.add_theme_font_size_override("font_size", 11)
			dados_companheiro.text = "%s • %s/%s • Nv. %d%s" % [
				str(invocacao.get("nome", "Companheiro")),
				str(invocacao.get("rank", "E")),
				str(invocacao.get("raridade", "comum")).capitalize(),
				int(invocacao.get("nivel", 1)),
				" • ATIVO" if id_invocacao == ativa_id else ""
			]
			linha_companheiro.add_child(dados_companheiro)
			var selecionar := Button.new()
			selecionar.text = "Ativo" if id_invocacao == ativa_id else "Usar"
			selecionar.disabled = id_invocacao.is_empty() or id_invocacao == ativa_id
			selecionar.custom_minimum_size = Vector2(58, 30)
			selecionar.pressed.connect(_solicitar_selecao_invocacao.bind(id_invocacao))
			linha_companheiro.add_child(selecionar)
			lista_invocacoes.add_child(linha_companheiro)
			var detalhes_companheiro := Label.new()
			detalhes_companheiro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detalhes_companheiro.add_theme_font_size_override("font_size", 10)
			detalhes_companheiro.text = "%s  •  Vida %d/%d  •  ATQ %d  •  DEF %d  •  AGI %d  •  MAG %d  •  Essências absorvidas: %d" % [
				str(invocacao.get("formaNome", "Forma original")),
				int(invocacao.get("vida", invocacao.get("vidaMaxima", 1))),
				int(invocacao.get("vidaMaxima", 1)),
				int(invocacao.get("ataque", 0)), int(invocacao.get("defesa", 0)),
				int(invocacao.get("agilidade", 0)), int(invocacao.get("poderMagico", 0)),
				int(invocacao.get("monstrosConsumidos", 0))
			]
			lista_invocacoes.add_child(detalhes_companheiro)
			var progresso_xp := ProgressBar.new()
			progresso_xp.custom_minimum_size = Vector2(0, 8)
			progresso_xp.show_percentage = false
			var xp_atual := maxi(0, int(invocacao.get("experiencia", 0)))
			var xp_necessario := maxi(1, int(invocacao.get("experienciaProximoNivel", int(invocacao.get("nivel", 1)) * 100)))
			progresso_xp.max_value = xp_necessario
			progresso_xp.value = mini(xp_atual, xp_necessario)
			lista_invocacoes.add_child(progresso_xp)
			var texto_xp := Label.new()
			texto_xp.text = "Experiência: %d / %d" % [xp_atual, xp_necessario]
			texto_xp.add_theme_font_size_override("font_size", 9)
			texto_xp.add_theme_color_override("font_color", Color("#c9bea5"))
			lista_invocacoes.add_child(texto_xp)

	var equipamentos: Dictionary = _perfil.get("equipamentos", {})
	for slot in SistemaEquipamentos.SLOTS:
		var item_id := str(equipamentos.get(slot, ""))
		var linha := HBoxContainer.new()
		linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rotulo := Label.new()
		rotulo.text = "%s: %s" % [_nome_slot(slot), _nome_item(item_id)]
		rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rotulo.add_theme_font_size_override("font_size", 11)
		linha.add_child(rotulo)
		if not item_id.is_empty():
			var retirar := Button.new()
			retirar.text = "Retirar"
			retirar.custom_minimum_size = Vector2(66, 30)
			retirar.pressed.connect(_solicitar_desequipar.bind(slot))
			linha.add_child(retirar)
		lista_equipados.add_child(linha)

	var inventario: Array = _perfil.get("inventario", [])
	if inventario.is_empty():
		var vazio := Label.new()
		vazio.text = "Sua mochila está vazia."
		vazio.add_theme_font_size_override("font_size", 11)
		lista_inventario.add_child(vazio)
		return

	for item in inventario:
		if not item is Dictionary:
			continue
		var item_id := str(item.get("itemId", ""))
		var quantidade := int(item.get("quantidade", 0))
		if item_id.is_empty() or quantidade <= 0:
			continue
		var linha_item := HBoxContainer.new()
		linha_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var descricao := Label.new()
		var categoria_item := str(item.get("categoria", "")).to_lower()
		if categoria_item == "ovo":
			var modelo_ovo: Dictionary = item.get("modeloCompanheiro", {})
			descricao.text = "🥚 %s ×%d • Rank %s • %s" % [
				str(item.get("nome", _nome_item(item_id))), quantidade,
				str(modelo_ovo.get("rank", "E")),
				str(item.get("raridade", "comum")).capitalize()
			]
		else:
			descricao.text = "%s ×%d • %s" % [
				str(item.get("nome", _nome_item(item_id))), quantidade,
				str(item.get("raridade", "comum")).capitalize()
			]
		descricao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		descricao.add_theme_font_size_override("font_size", 11)
		linha_item.add_child(descricao)
		if categoria_item == "ovo" and str(_perfil.get("classeId", "")) != "invocador":
			var chocar := Button.new()
			chocar.text = "Chocar"
			chocar.custom_minimum_size = Vector2(68, 30)
			chocar.pressed.connect(_solicitar_chocar_ovo.bind(item_id))
			linha_item.add_child(chocar)
		if not SistemaEquipamentos.obter(item_id).is_empty():
			var equipar := Button.new()
			equipar.text = "Usar"
			equipar.custom_minimum_size = Vector2(58, 30)
			equipar.pressed.connect(_solicitar_equipar.bind(item_id))
			linha_item.add_child(equipar)
		lista_inventario.add_child(linha_item)

func _solicitar_chocar_ovo(item_id: String) -> void:
	if RedeMultiplayer.estado != RedeMultiplayer.EstadoConexao.CONECTADO:
		mensagem.text = "Conecte-se ao mundo para chocar um ovo."
		return
	mensagem.text = "O servidor está verificando o ovo..."
	RedeMultiplayer.solicitar_chocar_ovo(item_id)

func _solicitar_selecao_invocacao(invocacao_id: String) -> void:
	if RedeMultiplayer.estado != RedeMultiplayer.EstadoConexao.CONECTADO:
		mensagem.text = "Conecte-se ao mundo para escolher um companheiro."
		return
	mensagem.text = "Salvando companheiro ativo no servidor..."
	RedeMultiplayer.solicitar_selecionar_invocacao(invocacao_id)

func _ao_resultado_selecao_invocacao(sucesso: bool, texto: String) -> void:
	if not is_instance_valid(mensagem):
		return
	mensagem.text = texto
	mensagem.add_theme_color_override("font_color", Color("#9bd69b") if sucesso else Color("#f09b8d"))
	if sucesso:
		_perfil = RedeMultiplayer.perfil_personagem_atual.duplicate(true)
		_atualizar_tela()

func _solicitar_equipar(item_id: String) -> void:
	if RedeMultiplayer.estado != RedeMultiplayer.EstadoConexao.CONECTADO:
		mensagem.text = "Conecte-se ao mundo para alterar equipamentos."
		return
	mensagem.text = "Enviando pedido ao servidor..."
	RedeMultiplayer.solicitar_equipar_item(item_id)

func _solicitar_desequipar(slot: String) -> void:
	if RedeMultiplayer.estado != RedeMultiplayer.EstadoConexao.CONECTADO:
		mensagem.text = "Conecte-se ao mundo para alterar equipamentos."
		return
	mensagem.text = "Enviando pedido ao servidor..."
	RedeMultiplayer.solicitar_desequipar_slot(slot)

func _nome_slot(slot: String) -> String:
	var nomes := {
		"mao_principal":"Mão principal", "mao_secundaria":"Mão secundária",
		"cabeca":"Cabeça", "torso":"Torso", "pernas":"Pernas",
		"maos":"Mãos", "pes":"Pés", "costas":"Costas",
		"anel":"Anel", "colar":"Colar", "bracelete":"Bracelete", "cinto":"Cinto"
	}
	return str(nomes.get(slot, slot))

func _nome_item(item_id: String) -> String:
	if item_id.is_empty():
		return "Vazio"
	var definicao := SistemaEquipamentos.obter(item_id)
	return str(definicao.get("nome", item_id)) if not definicao.is_empty() else item_id

func _limpar(container: Node) -> void:
	for filho in container.get_children():
		filho.queue_free()
