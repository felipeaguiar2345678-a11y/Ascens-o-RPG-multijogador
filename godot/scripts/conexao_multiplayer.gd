extends Control
## Tela inicial obrigatória: o mapa só é carregado após conexão ENet confirmada.

var campo_endereco: LineEdit
var campo_porta: SpinBox
var botao_conectar: Button
var texto_estado: Label

func _ready() -> void:
	_criar_interface()
	RedeMultiplayer.estado_conexao_alterado.connect(_ao_mudar_estado)
	RedeMultiplayer.erro_conexao.connect(_ao_ocorrer_erro)
	if RedeMultiplayer.estado == RedeMultiplayer.EstadoConexao.CONECTADO:
		_entrar_no_mundo()

func _criar_interface() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color("#101b20")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(340, 250)
	centro.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	painel.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "ASCENSÃO DO SOBERANO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	coluna.add_child(titulo)
	var subtitulo := Label.new()
	subtitulo.text = "Mundo compartilhado • acesso online obrigatório"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(subtitulo)
	var rotulo_endereco := Label.new()
	rotulo_endereco.text = "Endereço do servidor"
	coluna.add_child(rotulo_endereco)
	campo_endereco = LineEdit.new()
	campo_endereco.placeholder_text = "IP ou domínio do servidor"
	campo_endereco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_child(campo_endereco)
	var rotulo_porta := Label.new()
	rotulo_porta.text = "Porta UDP"
	coluna.add_child(rotulo_porta)
	campo_porta = SpinBox.new()
	campo_porta.min_value = 1
	campo_porta.max_value = 65535
	campo_porta.value = RedeMultiplayer.PORTA_PADRAO
	coluna.add_child(campo_porta)
	botao_conectar = Button.new()
	botao_conectar.text = "Conectar ao mundo"
	botao_conectar.custom_minimum_size.y = 44
	botao_conectar.pressed.connect(_conectar)
	coluna.add_child(botao_conectar)
	texto_estado = Label.new()
	texto_estado.text = "Informe o endereço do servidor para entrar."
	texto_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(texto_estado)

func _conectar() -> void:
	var endereco := campo_endereco.text.strip_edges()
	if endereco.is_empty():
		texto_estado.text = "Digite o IP ou domínio do servidor."
		return
	botao_conectar.disabled = true
	texto_estado.text = "Conectando ao mundo..."
	var resultado := RedeMultiplayer.conectar(endereco, int(campo_porta.value))
	if resultado != OK:
		botao_conectar.disabled = false
		texto_estado.text = "Não foi possível iniciar a conexão."

func _ao_mudar_estado(novo_estado: RedeMultiplayer.EstadoConexao) -> void:
	match novo_estado:
		RedeMultiplayer.EstadoConexao.CONECTADO:
			texto_estado.text = "Conectado! Entrando no mundo..."
			_entrar_no_mundo()
		RedeMultiplayer.EstadoConexao.CONECTANDO:
			texto_estado.text = "Conectando..."
		RedeMultiplayer.EstadoConexao.FALHA:
			botao_conectar.disabled = false
		RedeMultiplayer.EstadoConexao.DESCONECTADO:
			botao_conectar.disabled = false
			texto_estado.text = "Desconectado. É necessário conectar para jogar."

func _ao_ocorrer_erro(mensagem: String) -> void:
	texto_estado.text = mensagem
	botao_conectar.disabled = false

func _entrar_no_mundo() -> void:
	if RedeMultiplayer.estado != RedeMultiplayer.EstadoConexao.CONECTADO:
		return
	get_tree().change_scene_to_file("res://scenes/mundo_principal.tscn")
