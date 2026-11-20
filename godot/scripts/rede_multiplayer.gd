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

enum EstadoConexao {
	DESCONECTADO,
	CONECTANDO,
	CONECTADO,
	SERVIDOR,
	FALHA
}

const PORTA_PADRAO: int = 2456
const MAXIMO_JOGADORES_PADRAO: int = 100

var estado: EstadoConexao = EstadoConexao.DESCONECTADO
var endereco_servidor: String = ""
var porta_servidor: int = PORTA_PADRAO
var _peer: ENetMultiplayerPeer
var _jogadores_no_mundo: Dictionary = {}

func _ready() -> void:
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
	_mudar_estado(EstadoConexao.DESCONECTADO)

func esta_conectado() -> bool:
	return estado == EstadoConexao.CONECTADO or estado == EstadoConexao.SERVIDOR

func e_servidor() -> bool:
	return estado == EstadoConexao.SERVIDOR

func _ao_conectar() -> void:
	_mudar_estado(EstadoConexao.CONECTADO)
	solicitar_entrada_mundo.rpc_id(1)

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
	if multiplayer.is_server() and _jogadores_no_mundo.has(id_jogador):
		_jogadores_no_mundo.erase(id_jogador)
		rpc("_receber_jogador_saiu", id_jogador)

@rpc("any_peer", "call_remote", "reliable")
func solicitar_entrada_mundo() -> void:
	if not multiplayer.is_server():
		return
	var id_jogador := multiplayer.get_remote_sender_id()
	if id_jogador <= 0 or _jogadores_no_mundo.has(id_jogador):
		return
	var posicao := Vector2(1190.0 + float((_jogadores_no_mundo.size() % 5) * 24), 1120.0 + float((_jogadores_no_mundo.size() / 5) * 24))
	var lista_existente: Array = []
	for id_existente in _jogadores_no_mundo:
		lista_existente.append({"id": int(id_existente), "posicao": _jogadores_no_mundo[id_existente]})
	_jogadores_no_mundo[id_jogador] = posicao
	rpc_id(id_jogador, "_receber_estado_inicial", lista_existente)
	rpc("_receber_jogador_entrou", id_jogador, posicao)

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

func entrar_no_mundo() -> void:
	if estado == EstadoConexao.CONECTADO:
		solicitar_entrada_mundo.rpc_id(1)

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
	var posicao_anterior: Vector2 = _jogadores_no_mundo[id_jogador]
	var distancia_maxima := 52.0
	var dentro_do_mundo := posicao_solicitada.x >= 0.0 and posicao_solicitada.y >= 0.0 and posicao_solicitada.x <= 2400.0 and posicao_solicitada.y <= 1600.0
	if not dentro_do_mundo or posicao_anterior.distance_to(posicao_solicitada) > distancia_maxima:
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
