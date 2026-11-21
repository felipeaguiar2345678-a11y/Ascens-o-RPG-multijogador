extends Node
## Camada inicial de transporte multiplayer.
## O servidor deverá ser a autoridade do mundo; este singleton apenas gerencia
## a conexão ENet e publica eventos de estado da conexão.

signal estado_conexao_alterado(novo_estado: EstadoConexao)
signal erro_conexao(mensagem: String)
signal jogador_conectado(id_jogador: int)
signal jogador_desconectado(id_jogador: int)
signal estado_inicial_recebido(jogadores: Array)
signal jogador_entrou_no_mundo(id_jogador: int, posicao: Vector2)
signal jogador_atualizou_posicao(id_jogador: int, posicao: Vector2)
signal jogador_saiu_do_mundo(id_jogador: int)
signal autenticacao_concluida(uid: String, email: String)
signal autenticacao_falhou(mensagem: String)

enum EstadoConexao {
	DESCONECTADO,
	CONECTANDO,
	CONECTADO,
	SERVIDOR,
	FALHA
}

const PORTA_PADRAO: int = 2456
const MAXIMO_JOGADORES_PADRAO: int = 100
const VELOCIDADE_BASE_JOGADOR: float = 165.0

var estado: EstadoConexao = EstadoConexao.DESCONECTADO
var endereco_servidor: String = ""
var token_firebase: String = ""
var uid_autenticado: String = ""
var email_autenticado: String = ""
var _chave_firebase: String = ""
var _uid_por_peer: Dictionary = {}
var _validacoes_em_andamento: Dictionary = {}
var porta_servidor: int = PORTA_PADRAO
var _peer: ENetMultiplayerPeer
var _jogadores_no_mundo: Dictionary = {}
var _ultimo_pacote_posicao_ms: Dictionary = {}

func _ready() -> void:
	_carregar_configuracao_firebase()
	multiplayer.connected_to_server.connect(_ao_conectar)
	multiplayer.connection_failed.connect(_ao_falhar_conexao)
	multiplayer.server_disconnected.connect(_ao_desconectar_servidor)
	multiplayer.peer_connected.connect(_ao_jogador_conectado)
	multiplayer.peer_disconnected.connect(_ao_jogador_desconectado)

func conectar(endereco: String, porta: int = PORTA_PADRAO) -> Error:
	var host := endereco.strip_edges()
	if host.is_empty():
		return _falhar("Informe o endereço do servidor.")
	if porta < 1 or porta > 65535:
		return _falhar("A porta informada é inválida.")
	if estado == EstadoConexao.CONECTANDO or estado == EstadoConexao.CONECTADO:
		return _falhar("Já existe uma conexão em andamento ou ativa.")

	_limpar_peer()
	_mudar_estado(EstadoConexao.CONECTANDO)
	endereco_servidor = host
	porta_servidor = porta
	_peer = ENetMultiplayerPeer.new()
	var resultado := _peer.create_client(host, porta)
	if resultado != OK:
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		erro_conexao.emit("Não foi possível iniciar a conexão ENet (%s)." % error_string(resultado))
		return resultado

	multiplayer.multiplayer_peer = _peer
	return OK

func iniciar_servidor(porta: int = PORTA_PADRAO, maximo_jogadores: int = MAXIMO_JOGADORES_PADRAO) -> Error:
	if porta < 1 or porta > 65535:
		return _falhar("A porta informada é inválida.")
	if maximo_jogadores < 1:
		return _falhar("O limite de jogadores precisa ser maior que zero.")
	if estado == EstadoConexao.SERVIDOR or estado == EstadoConexao.CONECTADO:
		return _falhar("Já existe uma sessão ativa.")

	_limpar_peer()
	_peer = ENetMultiplayerPeer.new()
	var resultado := _peer.create_server(porta, maximo_jogadores)
	if resultado != OK:
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		erro_conexao.emit("Não foi possível iniciar o servidor ENet (%s)." % error_string(resultado))
		return resultado

	multiplayer.multiplayer_peer = _peer
	porta_servidor = porta
	_mudar_estado(EstadoConexao.SERVIDOR)
	return OK

func desconectar() -> void:
	_limpar_peer()
	endereco_servidor = ""
	token_firebase = ""
	uid_autenticado = ""
	email_autenticado = ""
	_mudar_estado(EstadoConexao.DESCONECTADO)

func esta_conectado() -> bool:
	return estado == EstadoConexao.CONECTADO or estado == EstadoConexao.SERVIDOR

func e_servidor() -> bool:
	return estado == EstadoConexao.SERVIDOR

func _ao_conectar() -> void:
	_mudar_estado(EstadoConexao.CONECTADO)
	if token_firebase.is_empty():
		autenticacao_falhou.emit("Entre com sua conta antes de conectar ao mundo.")
		desconectar()
		return
	solicitar_autenticacao.rpc_id(1, token_firebase)

func _ao_falhar_conexao() -> void:
	_limpar_peer()
	_mudar_estado(EstadoConexao.FALHA)
	erro_conexao.emit("Não foi possível conectar ao mundo. Verifique a conexão e tente novamente.")

func _ao_desconectar_servidor() -> void:
	_limpar_peer()
	_mudar_estado(EstadoConexao.DESCONECTADO)
	erro_conexao.emit("A conexão com o mundo foi perdida.")

func _ao_jogador_conectado(id_jogador: int) -> void:
	jogador_conectado.emit(id_jogador)

func _ao_jogador_desconectado(id_jogador: int) -> void:
	jogador_desconectado.emit(id_jogador)
	if multiplayer.is_server():
		_uid_por_peer.erase(id_jogador)
		_validacoes_em_andamento.erase(id_jogador)
		if _jogadores_no_mundo.has(id_jogador):
			_jogadores_no_mundo.erase(id_jogador)
		_ultimo_pacote_posicao_ms.erase(id_jogador)
		rpc("_receber_jogador_saiu", id_jogador)

@rpc("any_peer", "call_remote", "reliable")
func solicitar_autenticacao(token: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 0 or token.is_empty() or token.length() > 8192:
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Credencial inválida.")
		return
	if _validacoes_em_andamento.has(peer_id) or _uid_por_peer.has(peer_id):
		return
	if _chave_firebase.is_empty():
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Servidor sem configuração Firebase.")
		return

	var requisicao := HTTPRequest.new()
	requisicao.timeout = 12.0
	add_child(requisicao)
	_validacoes_em_andamento[peer_id] = requisicao
	requisicao.request_completed.connect(_ao_validar_token_firebase.bind(peer_id, requisicao))
	var cabecalhos := PackedStringArray(["Content-Type: application/json"])
	var corpo := JSON.stringify({"idToken": token})
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + _chave_firebase
	var erro := requisicao.request(url, cabecalhos, HTTPClient.METHOD_POST, corpo)
	if erro != OK:
		_validacoes_em_andamento.erase(peer_id)
		requisicao.queue_free()
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Não foi possível validar a conta.")

func _ao_validar_token_firebase(resultado: int, codigo_http: int, _cabecalhos: PackedStringArray, corpo: PackedByteArray, peer_id: int, requisicao: HTTPRequest) -> void:
	_validacoes_em_andamento.erase(peer_id)
	if not multiplayer.is_server() or not multiplayer.get_peers().has(peer_id):
		requisicao.queue_free()
		return
	var dados = JSON.parse_string(corpo.get_string_from_utf8())
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo_http != 200 or not (dados is Dictionary):
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Conta não pôde ser validada. Entre novamente.")
		requisicao.queue_free()
		return
	var usuarios = dados.get("users", [])
	if not (usuarios is Array) or usuarios.is_empty() or not (usuarios[0] is Dictionary):
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "A conta não foi encontrada.")
		requisicao.queue_free()
		return
	var usuario: Dictionary = usuarios[0]
	var uid := str(usuario.get("localId", ""))
	if uid.is_empty() or bool(usuario.get("disabled", false)):
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Esta conta não pode acessar o mundo.")
		requisicao.queue_free()
		return
	if _uid_por_peer.values().has(uid):
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Esta conta já está conectada ao mundo.")
		requisicao.queue_free()
		return
	_uid_por_peer[peer_id] = uid
	var email := str(usuario.get("email", ""))
	rpc_id(peer_id, "_receber_autenticacao_aprovada", uid, email)
	_adicionar_jogador_autenticado(peer_id)
	requisicao.queue_free()

func _adicionar_jogador_autenticado(id_jogador: int) -> void:
	if not _uid_por_peer.has(id_jogador) or _jogadores_no_mundo.has(id_jogador):
		return
	var posicao := Vector2(1190.0 + float((_jogadores_no_mundo.size() % 5) * 24), 1120.0 + float((_jogadores_no_mundo.size() / 5) * 24))
	var lista_existente: Array = []
	for id_existente in _jogadores_no_mundo:
		lista_existente.append({"id": int(id_existente), "posicao": _jogadores_no_mundo[id_existente]})
	_jogadores_no_mundo[id_jogador] = posicao
	_ultimo_pacote_posicao_ms[id_jogador] = Time.get_ticks_msec()
	rpc_id(id_jogador, "_receber_estado_inicial", lista_existente)
	rpc("_receber_jogador_entrou", id_jogador, posicao)

@rpc("authority", "call_remote", "reliable")
func _receber_autenticacao_aprovada(uid: String, email: String) -> void:
	uid_autenticado = uid
	email_autenticado = email
	autenticacao_concluida.emit(uid, email)

@rpc("authority", "call_remote", "reliable")
func _receber_autenticacao_rejeitada(mensagem: String) -> void:
	autenticacao_falhou.emit(mensagem)

func _carregar_configuracao_firebase() -> void:
	if not FileAccess.file_exists("res://firebase_config.json"):
		push_error("Arquivo firebase_config.json não encontrado no projeto Godot.")
		return
	var arquivo := FileAccess.open("res://firebase_config.json", FileAccess.READ)
	if arquivo == null:
		return
	var dados = JSON.parse_string(arquivo.get_as_text())
	if dados is Dictionary:
		_chave_firebase = str(dados.get("apiKey", ""))

func obter_chave_firebase() -> String:
	return _chave_firebase

@rpc("authority", "call_remote", "reliable")
func _receber_estado_inicial(jogadores: Array) -> void:
	estado_inicial_recebido.emit(jogadores)

@rpc("authority", "call_remote", "reliable")
func _receber_jogador_entrou(id_jogador: int, posicao: Vector2) -> void:
	if id_jogador == multiplayer.get_unique_id():
		return
	jogador_entrou_no_mundo.emit(id_jogador, posicao)

@rpc("authority", "call_remote", "reliable")
func _receber_jogador_saiu(id_jogador: int) -> void:
	jogador_saiu_do_mundo.emit(id_jogador)

func obter_jogadores_conectados() -> Dictionary:
	return _jogadores_no_mundo.duplicate(true)

func enviar_posicao_jogador(posicao: Vector2) -> void:
	if estado == EstadoConexao.CONECTADO:
		solicitar_atualizacao_posicao.rpc_id(1, posicao)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func solicitar_atualizacao_posicao(posicao_solicitada: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var id_jogador := multiplayer.get_remote_sender_id()
	if not _jogadores_no_mundo.has(id_jogador):
		return
	var agora_ms := Time.get_ticks_msec()
	var ultimo_ms := int(_ultimo_pacote_posicao_ms.get(id_jogador, agora_ms))
	var decorrido_ms := agora_ms - ultimo_ms
	# Descarta spam de pacotes sem deixar que ele aumente a velocidade permitida.
	if decorrido_ms < 35:
		return
	_ultimo_pacote_posicao_ms[id_jogador] = agora_ms

	var posicao_anterior: Vector2 = _jogadores_no_mundo[id_jogador]
	var dentro_do_mundo := posicao_solicitada.x >= 0.0 and posicao_solicitada.y >= 0.0 and posicao_solicitada.x <= 2400.0 and posicao_solicitada.y <= 1600.0
	var distancia_permitida := VELOCIDADE_BASE_JOGADOR * (float(decorrido_ms) / 1000.0) * 1.8 + 16.0
	if not dentro_do_mundo or posicao_anterior.distance_to(posicao_solicitada) > distancia_permitida:
		rpc_id(id_jogador, "_receber_posicao_jogador", id_jogador, posicao_anterior)
		return
	_jogadores_no_mundo[id_jogador] = posicao_solicitada
	rpc("_receber_posicao_jogador", id_jogador, posicao_solicitada)

@rpc("authority", "call_remote", "unreliable_ordered")
func _receber_posicao_jogador(id_jogador: int, posicao: Vector2) -> void:
	jogador_atualizou_posicao.emit(id_jogador, posicao)

func _falhar(mensagem: String) -> Error:
	erro_conexao.emit(mensagem)
	return ERR_INVALID_PARAMETER

func _limpar_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	if _peer != null:
		_peer.close()
		_peer = null

func _mudar_estado(novo_estado: EstadoConexao) -> void:
	if estado == novo_estado:
		return
	estado = novo_estado
	estado_conexao_alterado.emit(estado)
