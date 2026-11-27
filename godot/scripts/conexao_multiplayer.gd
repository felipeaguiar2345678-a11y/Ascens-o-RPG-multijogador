extends Control

const TEMA_VISUAL = preload("res://scripts/tema_visual.gd")
## Login Firebase obrigatório antes de abrir a conexão com o mundo.

var campo_email: LineEdit
var campo_senha: LineEdit
var campo_endereco: LineEdit
var campo_porta: SpinBox
var seletor_entrada: OptionButton
var campo_codigo_sala: LineEdit
var botao_entrar: Button
var botao_criar: Button
var texto_estado: Label
var requisicao_auth: HTTPRequest

func _ready() -> void:
	_criar_interface()
	if not RedeMultiplayer.motivo_autenticacao_pendente.is_empty():
		texto_estado.text = RedeMultiplayer.motivo_autenticacao_pendente
		RedeMultiplayer.motivo_autenticacao_pendente = ""
	RedeMultiplayer.estado_conexao_alterado.connect(_ao_mudar_estado)
	RedeMultiplayer.erro_conexao.connect(_ao_ocorrer_erro)
	RedeMultiplayer.autenticacao_concluida.connect(_ao_autenticacao_concluida)
	RedeMultiplayer.autenticacao_falhou.connect(_ao_autenticacao_falhou)
	requisicao_auth = HTTPRequest.new()
	requisicao_auth.timeout = 15.0
	requisicao_auth.request_completed.connect(_ao_resultado_auth)
	add_child(requisicao_auth)

func _criar_interface() -> void:
	TEMA_VISUAL.aplicar(self)
	var fundo := ColorRect.new()
	fundo.color = Color("#101b20")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(360, 330)
	centro.add_child(painel)
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(340, 310)
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	painel.add_child(rolagem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "ASCENSÃO DO SOBERANO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 21)
	coluna.add_child(titulo)
	var subtitulo := Label.new()
	subtitulo.text = "Entre ou crie sua conta para acessar o mundo compartilhado."
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(subtitulo)
	var label_email := Label.new()
	label_email.text = "E-mail"
	coluna.add_child(label_email)
	campo_email = LineEdit.new()
	campo_email.placeholder_text = "seuemail@exemplo.com"
	campo_email.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo_email.text = ""
	coluna.add_child(campo_email)
	var label_senha := Label.new()
	label_senha.text = "Senha (mínimo 6 caracteres)"
	coluna.add_child(label_senha)
	campo_senha = LineEdit.new()
	campo_senha.secret = true
	campo_senha.placeholder_text = "Sua senha"
	coluna.add_child(campo_senha)
	var botoes_conta := HBoxContainer.new()
	coluna.add_child(botoes_conta)
	botao_entrar = Button.new()
	botao_entrar.text = "Entrar"
	botao_entrar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao_entrar.pressed.connect(_autenticar.bind(false))
	botoes_conta.add_child(botao_entrar)
	botao_criar = Button.new()
	botao_criar.text = "Criar conta"
	botao_criar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao_criar.pressed.connect(_autenticar.bind(true))
	botoes_conta.add_child(botao_criar)
	var separador := HSeparator.new()
	coluna.add_child(separador)
	var label_servidor := Label.new()
	label_servidor.text = "Servidor do mundo"
	coluna.add_child(label_servidor)
	campo_endereco = LineEdit.new()
	campo_endereco.placeholder_text = "IP ou domínio do servidor"
	coluna.add_child(campo_endereco)
	campo_porta = SpinBox.new()
	campo_porta.min_value = 1
	campo_porta.max_value = 65535
	campo_porta.value = RedeMultiplayer.PORTA_PADRAO
	coluna.add_child(campo_porta)
	var label_entrada := Label.new()
	label_entrada.text = "Como deseja jogar?"
	coluna.add_child(label_entrada)
	seletor_entrada = OptionButton.new()
	seletor_entrada.add_item("Mundo principal (até 40 jogadores)", 0)
	seletor_entrada.add_item("Criar sala pública (até 4 jogadores)", 1)
	seletor_entrada.add_item("Entrar em sala pública automaticamente", 2)
	seletor_entrada.add_item("Entrar com código de sala", 3)
	seletor_entrada.item_selected.connect(_ao_selecionar_modo_entrada)
	coluna.add_child(seletor_entrada)
	campo_codigo_sala = LineEdit.new()
	campo_codigo_sala.placeholder_text = "Código de seis caracteres"
	campo_codigo_sala.max_length = 6
	campo_codigo_sala.visible = false
	coluna.add_child(campo_codigo_sala)
	texto_estado = Label.new()
	texto_estado.text = "Mundo principal: até 40 jogadores. Salas públicas: até 4."
	texto_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(texto_estado)

func _ao_selecionar_modo_entrada(indice: int) -> void:
	if is_instance_valid(campo_codigo_sala):
		campo_codigo_sala.visible = indice == 3

func _autenticar(criar_conta: bool) -> void:
	var email := campo_email.text.strip_edges().to_lower()
	var senha := campo_senha.text
	if not email.contains("@") or not email.contains("."):
		texto_estado.text = "Informe um e-mail válido."
		return
	if senha.length() < 6:
		texto_estado.text = "A senha precisa ter pelo menos 6 caracteres."
		return
	if campo_endereco.text.strip_edges().is_empty():
		texto_estado.text = "Informe o endereço do servidor antes de entrar."
		return
	if seletor_entrada.get_selected_id() == 3 and campo_codigo_sala.text.strip_edges().length() != 6:
		texto_estado.text = "Digite o código de sala com seis caracteres."
		return
	var chave := RedeMultiplayer.obter_chave_firebase()
	if chave.is_empty():
		texto_estado.text = "Configuração Firebase ausente no projeto."
		return
	botao_entrar.disabled = true
	botao_criar.disabled = true
	texto_estado.text = "Criando conta..." if criar_conta else "Autenticando conta..."
	var acao := "signUp" if criar_conta else "signInWithPassword"
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:%s?key=%s" % [acao, chave]
	var corpo := JSON.stringify({"email": email, "password": senha, "returnSecureToken": true})
	var erro := requisicao_auth.request(url, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, corpo)
	if erro != OK:
		_habilitar_botoes()
		texto_estado.text = "Não foi possível iniciar a autenticação."

func _ao_resultado_auth(resultado: int, codigo_http: int, _cabecalhos: PackedStringArray, corpo: PackedByteArray) -> void:
	var dados = JSON.parse_string(corpo.get_string_from_utf8())
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo_http != 200 or not (dados is Dictionary):
		var mensagem := "Falha ao autenticar. Confira os dados e tente novamente."
		if dados is Dictionary:
			var erro = dados.get("error", {})
			if erro is Dictionary:
				mensagem = _traduzir_erro_firebase(str(erro.get("message", "")))
		_habilitar_botoes()
		texto_estado.text = mensagem
		return
	var token := str(dados.get("idToken", ""))
	if token.is_empty():
		_habilitar_botoes()
		texto_estado.text = "O Firebase não retornou uma credencial válida."
		return
	# O refresh token é um segredo bearer: fica somente na memória do singleton
	# durante a sessão e nunca é escrito em arquivo, log ou enviado pelo ENet.
	var refresh_token := str(dados.get("refreshToken", ""))
	if refresh_token.is_empty():
		_habilitar_botoes()
		texto_estado.text = "O Firebase não retornou o token de renovação. Tente novamente."
		return
	RedeMultiplayer.token_firebase = token
	RedeMultiplayer.iniciar_renovacao_firebase(refresh_token, int(str(dados.get("expiresIn", "3600"))))
	match seletor_entrada.get_selected_id():
		0:
			RedeMultiplayer.acao_sala_cliente = "mundo"
			RedeMultiplayer.codigo_sala_cliente = ""
		1:
			RedeMultiplayer.acao_sala_cliente = "criar_sala"
			RedeMultiplayer.codigo_sala_cliente = ""
		2:
			RedeMultiplayer.acao_sala_cliente = "sala_publica"
			RedeMultiplayer.codigo_sala_cliente = ""
		3:
			RedeMultiplayer.acao_sala_cliente = "entrar_codigo"
			RedeMultiplayer.codigo_sala_cliente = campo_codigo_sala.text.strip_edges().to_upper()
	texto_estado.text = "Conta confirmada. Conectando ao servidor..."
	var erro_conexao := RedeMultiplayer.conectar(campo_endereco.text.strip_edges(), int(campo_porta.value))
	if erro_conexao != OK:
		_habilitar_botoes()

func _traduzir_erro_firebase(codigo: String) -> String:
	match codigo:
		"EMAIL_EXISTS": return "Este e-mail já possui uma conta. Use Entrar."
		"EMAIL_NOT_FOUND", "INVALID_LOGIN_CREDENTIALS": return "E-mail ou senha incorretos."
		"INVALID_PASSWORD": return "Senha incorreta."
		"WEAK_PASSWORD : Password should be at least 6 characters": return "A senha precisa ter pelo menos 6 caracteres."
		"OPERATION_NOT_ALLOWED": return "O login por e-mail e senha ainda não está ativado no Firebase."
		"TOO_MANY_ATTEMPTS_TRY_LATER": return "Muitas tentativas. Aguarde e tente novamente."
		_: return "Não foi possível autenticar (%s)." % codigo

func _ao_mudar_estado(novo_estado: RedeMultiplayer.EstadoConexao) -> void:
	match novo_estado:
		RedeMultiplayer.EstadoConexao.CONECTADO:
			texto_estado.text = "Conexão estabelecida. Validando sua conta no servidor..."
		RedeMultiplayer.EstadoConexao.CONECTANDO:
			texto_estado.text = "Conectando ao servidor..."
		RedeMultiplayer.EstadoConexao.FALHA, RedeMultiplayer.EstadoConexao.DESCONECTADO:
			_habilitar_botoes()

func _ao_ocorrer_erro(mensagem: String) -> void:
	texto_estado.text = mensagem
	_habilitar_botoes()

func _ao_autenticacao_concluida(uid: String, email: String) -> void:
	texto_estado.text = "Conta validada. Entrando no mundo..."
	# A apresentação é uma experiência de primeira entrada por conta, não uma tela
	# obrigatória repetida a cada login.
	var configuracao := ConfigFile.new()
	configuracao.load("user://aberturas_mundo.cfg")
	if bool(configuracao.get_value("contas", uid, false)):
		get_tree().change_scene_to_file("res://scenes/criacao_personagem.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/abertura_mundo.tscn")

func _ao_autenticacao_falhou(mensagem: String) -> void:
	texto_estado.text = mensagem
	RedeMultiplayer.desconectar()
	_habilitar_botoes()

func _habilitar_botoes() -> void:
	if is_instance_valid(botao_entrar):
		botao_entrar.disabled = false
	if is_instance_valid(botao_criar):
		botao_criar.disabled = false
