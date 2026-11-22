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
signal jogador_entrou_com_perfil_visual(id_jogador: int, posicao: Vector2, perfil_visual: Dictionary)
signal jogador_atualizou_perfil_visual(id_jogador: int, perfil_visual: Dictionary)
signal jogador_atualizou_posicao(id_jogador: int, posicao: Vector2)
signal jogador_saiu_do_mundo(id_jogador: int)
signal autenticacao_concluida(uid: String, email: String)
signal autenticacao_falhou(mensagem: String)
signal perfil_personagem_recebido(dados: Dictionary)
signal equipamento_atualizado(equipamentos: Dictionary)
signal resultado_equipamento(sucesso: bool, mensagem: String)
signal combate_atualizado(estado: Dictionary)
signal combate_finalizado(status: String, drops: Array)
signal erro_combate(mensagem: String)
signal criaturas_persistentes_recebidas(criaturas: Array)
signal posicoes_criaturas_atualizadas(atualizacoes: Array)
signal grupos_selvagens_recebidos(individuos: Array)
signal posicoes_grupos_selvagens_atualizadas(atualizacoes: Array)

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
const REPOSITORIO_PERFIL = preload("res://scripts/repositorio_personagem_servidor.gd")
const SistemaDrops = preload("res://scripts/sistema_drops.gd")
const SistemaEquipamentos = preload("res://scripts/sistema_equipamentos.gd")
const SistemaCombate = preload("res://scripts/sistema_combate.gd")
const REPOSITORIO_CRIATURAS = preload("res://scripts/repositorio_criaturas_servidor.gd")
const SISTEMA_SELECAO_ENCONTROS = preload("res://scripts/sistema_selecao_encontros.gd")
const SISTEMA_COMPORTAMENTO_CRIATURAS = preload("res://scripts/sistema_comportamento_criaturas.gd")
const SISTEMA_ECOLOGIA_CRIATURAS = preload("res://scripts/sistema_ecologia_criaturas.gd")
const REPOSITORIO_GRUPOS = preload("res://scripts/repositorio_grupos_criaturas_servidor.gd")
const SISTEMA_MOVIMENTO_GRUPOS = preload("res://scripts/sistema_movimento_grupos.gd")
const SISTEMA_COMBATE_ECOLOGICO = preload("res://scripts/sistema_combate_ecologico.gd")
const INTERVALO_GRAVACAO_MS := 5000
const INTERVALO_MINIMO_ENCONTROS_MS := 30000
const INTERVALO_MOVIMENTO_CRIATURAS_MS := 1000
const INTERVALO_GRAVACAO_CRIATURAS_MS := 5000
const INTERVALO_GRUPOS_SELVAJENS_MS := 1000
const INTERVALO_COMBATE_ECOLOGICO_MS := 6000
const DISTANCIA_COMBATE_ECOLOGICO := 38.0
const INTERVALO_GRAVACAO_GRUPOS_MS := 5000
const LIMITE_GRUPOS_MUNDO := 64
const LIMITE_INDIVIDUOS_GRUPO_MUNDO := 80
const LIMITE_INDIVIDUOS_MUNDO := 2000
const VELOCIDADE_CRIATURA_ERRANTE := 24.0
const RAIO_VAGAR_CRIATURA := 220.0

var estado: EstadoConexao = EstadoConexao.DESCONECTADO
var endereco_servidor: String = ""
var token_firebase: String = ""
var uid_autenticado: String = ""
var perfil_personagem_atual: Dictionary = {}
var email_autenticado: String = ""
var _chave_firebase: String = ""
var _uid_por_peer: Dictionary = {}
var _validacoes_em_andamento: Dictionary = {}
var porta_servidor: int = PORTA_PADRAO
var _peer: ENetMultiplayerPeer
var _jogadores_no_mundo: Dictionary = {}
var _ultimo_pacote_posicao_ms: Dictionary = {}
var _perfil_por_peer: Dictionary = {}
var _repositorio_perfis = REPOSITORIO_PERFIL.new()
var _ultima_gravacao_ms: Dictionary = {}
var _combates_por_peer: Dictionary = {}
var _repositorio_criaturas = REPOSITORIO_CRIATURAS.new()
var _ultimo_encontro_ms: Dictionary = {}
var _criaturas_mundo_cache: Dictionary = {}
var _ultima_atualizacao_criaturas_ms := 0
var _ultima_gravacao_criaturas_ms := 0
var _repositorio_grupos = REPOSITORIO_GRUPOS.new()
var _grupos_mundo_cache: Dictionary = {}
var _ultima_atualizacao_grupos_ms := 0
var _ultima_gravacao_grupos_ms := 0
var _ultimo_ataque_ecologico_ms: Dictionary = {}

func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var agora := Time.get_ticks_msec()
	_atualizar_criaturas_persistentes(agora)
	_atualizar_grupos_selvagens(agora)
	for id_jogador in _perfil_por_peer.keys():
		if agora - int(_ultima_gravacao_ms.get(id_jogador, agora)) >= INTERVALO_GRAVACAO_MS:
			_salvar_perfil_jogador(int(id_jogador))

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
	_carregar_criaturas_persistentes()
	_carregar_grupos_selvagens()
	_mudar_estado(EstadoConexao.SERVIDOR)
	return OK

func desconectar() -> void:
	_limpar_peer()
	endereco_servidor = ""
	token_firebase = ""
	uid_autenticado = ""
	email_autenticado = ""
	perfil_personagem_atual.clear()
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
		_salvar_perfil_jogador(id_jogador)
		_uid_por_peer.erase(id_jogador)
		_combates_por_peer.erase(id_jogador)
		_perfil_por_peer.erase(id_jogador)
		_ultima_gravacao_ms.erase(id_jogador)
		_ultimo_encontro_ms.erase(id_jogador)
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
	var perfil: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
	if perfil.is_empty():
		_uid_por_peer.erase(peer_id)
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Não foi possível carregar ou criar seu personagem no servidor.")
		requisicao.queue_free()
		return
	_perfil_por_peer[peer_id] = perfil
	var email := str(usuario.get("email", ""))
	rpc_id(peer_id, "_receber_autenticacao_aprovada", uid, email)
	if bool(perfil.get("personagemCriado", false)):
		_adicionar_jogador_autenticado(peer_id)
	requisicao.queue_free()

func _criar_personagem_para_peer(peer_id: int, nome: String, sexo: String, aparencia_id: String, raca_id: String, classe_id: String) -> void:
	if not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id) or _jogadores_no_mundo.has(peer_id):
		return
	var uid := str(_uid_por_peer[peer_id])
	var perfil: Dictionary = _repositorio_perfis.criar_personagem(uid, nome, sexo, aparencia_id, raca_id, classe_id)
	if perfil.is_empty():
		rpc_id(peer_id, "_receber_criacao_personagem_falhou", "Não foi possível criar. Confira o nome e tente novamente.")
		return
	_perfil_por_peer[peer_id] = perfil
	rpc_id(peer_id, "_receber_perfil_personagem", perfil)
	_adicionar_jogador_autenticado(peer_id)

@rpc("authority", "call_remote", "reliable")
func _receber_criacao_personagem_falhou(mensagem: String) -> void:
	erro_conexao.emit(mensagem)
func _adicionar_jogador_autenticado(id_jogador: int) -> void:
	if not _uid_por_peer.has(id_jogador) or _jogadores_no_mundo.has(id_jogador):
		return
	var perfil: Dictionary = _perfil_por_peer.get(id_jogador, {})
	var posicao := Vector2(float(perfil.get("x", 1190.0)), float(perfil.get("y", 1120.0)))
	var lista_existente: Array = []
	for id_existente in _jogadores_no_mundo:
		lista_existente.append({"id": int(id_existente), "posicao": _jogadores_no_mundo[id_existente], "perfil": _perfil_visual_publico(_perfil_por_peer.get(id_existente, {}))})
	_jogadores_no_mundo[id_jogador] = posicao
	_ultimo_pacote_posicao_ms[id_jogador] = Time.get_ticks_msec()
	_ultima_gravacao_ms[id_jogador] = Time.get_ticks_msec()
	rpc_id(id_jogador, "_receber_estado_inicial", lista_existente)
	rpc_id(id_jogador, "_receber_criaturas_persistentes", _lista_visual_criaturas())
	rpc_id(id_jogador, "_receber_grupos_selvagens", _lista_visual_individuos_grupos())
	rpc_id(id_jogador, "_receber_perfil_personagem", perfil)
	rpc("_receber_jogador_entrou", id_jogador, posicao, _perfil_visual_publico(perfil))

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
func _receber_jogador_entrou(id_jogador: int, posicao: Vector2, perfil_visual: Dictionary) -> void:
	if id_jogador == multiplayer.get_unique_id():
		return
	jogador_entrou_no_mundo.emit(id_jogador, posicao)
	jogador_entrou_com_perfil_visual.emit(id_jogador, posicao, perfil_visual)

@rpc("authority", "call_remote", "reliable")
func _receber_visual_jogador_atualizado(id_jogador: int, perfil_visual: Dictionary) -> void:
	jogador_atualizou_perfil_visual.emit(id_jogador, perfil_visual)

@rpc("authority", "call_remote", "reliable")
func _receber_jogador_saiu(id_jogador: int) -> void:
	jogador_saiu_do_mundo.emit(id_jogador)

func obter_jogadores_conectados() -> Dictionary:
	return _jogadores_no_mundo.duplicate(true)

func solicitar_criacao_personagem(nome: String, sexo: String, aparencia_id: String, raca_id: String, classe_id: String) -> void:
	if estado == EstadoConexao.CONECTADO:
		_enviar_criacao_personagem.rpc_id(1, nome, sexo, aparencia_id, raca_id, classe_id)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_criacao_personagem(nome: String, sexo: String, aparencia_id: String, raca_id: String, classe_id: String) -> void:
	if multiplayer.is_server():
		# O servidor usa o peer autenticado, nunca um UID fornecido pelo cliente.
		_criar_personagem_para_peer(multiplayer.get_remote_sender_id(), nome, sexo, aparencia_id, raca_id, classe_id)

func enviar_posicao_jogador(posicao: Vector2) -> void:
	if estado == EstadoConexao.CONECTADO:
		solicitar_atualizacao_posicao.rpc_id(1, posicao)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func solicitar_atualizacao_posicao(posicao_solicitada: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var id_jogador := multiplayer.get_remote_sender_id()
	if not _jogadores_no_mundo.has(id_jogador) or _combates_por_peer.has(id_jogador):
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
	var perfil_movimento: Dictionary = _perfil_por_peer.get(id_jogador, {})
	var atributos_movimento := _atributos_efetivos_perfil(perfil_movimento)
	var velocidade_autorizada := VELOCIDADE_BASE_JOGADOR * (float(atributos_movimento.get("velocidadePercentual", 100)) / 100.0)
	var distancia_permitida := velocidade_autorizada * (float(decorrido_ms) / 1000.0) * 1.8 + 16.0
	if not dentro_do_mundo or posicao_anterior.distance_to(posicao_solicitada) > distancia_permitida:
		rpc_id(id_jogador, "_receber_posicao_jogador", id_jogador, posicao_anterior)
		return
	_jogadores_no_mundo[id_jogador] = posicao_solicitada
	if _perfil_por_peer.has(id_jogador):
		var perfil: Dictionary = _perfil_por_peer[id_jogador]
		perfil["x"] = posicao_solicitada.x
		perfil["y"] = posicao_solicitada.y
		_perfil_por_peer[id_jogador] = perfil
	rpc("_receber_posicao_jogador", id_jogador, posicao_solicitada)

@rpc("authority", "call_remote", "reliable")
func _receber_perfil_personagem(dados: Dictionary) -> void:
	if str(dados.get("uid", "")) != uid_autenticado:
		autenticacao_falhou.emit("O servidor enviou um perfil que não corresponde à conta autenticada.")
		desconectar()
		return
	perfil_personagem_atual = dados.duplicate(true)
	perfil_personagem_recebido.emit(perfil_personagem_atual)


## Pedido de equipamento: o servidor identifica a conta pelo peer autenticado.
func solicitar_equipar_item(item_id: String) -> void:
	if estado == EstadoConexao.CONECTADO:
		_enviar_pedido_equipar_item.rpc_id(1, item_id)

func solicitar_desequipar_slot(slot: String) -> void:
	if estado == EstadoConexao.CONECTADO:
		_enviar_pedido_desequipar_slot.rpc_id(1, slot)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_pedido_equipar_item(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or _combates_por_peer.has(peer_id):
		return
	var uid := str(_uid_por_peer[peer_id])
	var resultado: Dictionary = _repositorio_perfis.equipar_item(uid, item_id)
	_processar_resultado_equipamento(peer_id, resultado)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_pedido_desequipar_slot(slot: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or _combates_por_peer.has(peer_id):
		return
	var uid := str(_uid_por_peer[peer_id])
	var resultado: Dictionary = _repositorio_perfis.desequipar_slot(uid, slot)
	_processar_resultado_equipamento(peer_id, resultado)

func _processar_resultado_equipamento(peer_id: int, resultado: Dictionary) -> void:
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_resultado_equipamento", false, str(resultado.get("erro", "Não foi possível alterar o equipamento.")), {})
		return
	var uid := str(_uid_por_peer.get(peer_id, ""))
	var perfil: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
	if perfil.is_empty():
		rpc_id(peer_id, "_receber_resultado_equipamento", false, "Não foi possível atualizar o perfil.", {})
		return
	_perfil_por_peer[peer_id] = perfil
	rpc_id(peer_id, "_receber_perfil_personagem", perfil)
	rpc("_receber_visual_jogador_atualizado", peer_id, _perfil_visual_publico(perfil))
	rpc_id(peer_id, "_receber_resultado_equipamento", true, "Equipamento atualizado.", resultado.get("equipamentos", {}))

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_equipamento(sucesso: bool, mensagem: String, equipamentos: Dictionary) -> void:
	if sucesso:
		equipamento_atualizado.emit(equipamentos)
	resultado_equipamento.emit(sucesso, mensagem)

## Inicia encontro somente quando chamado por lógica confiável do servidor.
## A criatura nunca é recebida por RPC do cliente.
## Registra uma criatura entregue pelo gerador confiável do servidor.
## Esta função nunca é exposta como RPC de cliente.
func registrar_criatura_gerada_servidor(criatura: Dictionary) -> Dictionary:
	if not multiplayer.is_server():
		return {"ok":false,"erro":"Somente o servidor pode registrar criaturas."}
	return _repositorio_criaturas.registrar_criatura_gerada(criatura)

## Orquestra um encontro a partir de contexto calculado pela lógica confiável do mundo.
## Não é RPC: o cliente não escolhe ecossistema, bioma, perigo ou criatura.
## Até existir um gatilho de zona no mundo, esta função não inicia encontros sozinha.
func tentar_iniciar_encontro_servidor(
	peer_id: int,
	ecossistema_id: String,
	bioma: String,
	perigo: int,
	permitir_chefe: bool = false
) -> bool:
	if not multiplayer.is_server():
		return false
	if not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		return false
	if not bool(_perfil_por_peer[peer_id].get("personagemCriado", false)):
		return false
	if not _jogadores_no_mundo.has(peer_id) or _combates_por_peer.has(peer_id):
		return false
	if ecossistema_id not in REPOSITORIO_CRIATURAS.ECOSSISTEMAS:
		return false
	if bioma.strip_edges().is_empty() or bioma.length() > 64 or perigo < 0 or perigo > 100:
		return false
	var agora_ms := Time.get_ticks_msec()
	var ultimo_ms := int(_ultimo_encontro_ms.get(peer_id, 0))
	if ultimo_ms > 0 and agora_ms - ultimo_ms < INTERVALO_MINIMO_ENCONTROS_MS:
		return false
	var catalogo := _repositorio_criaturas.listar_criaturas_do_ecossistema(ecossistema_id)
	var semente := int(Time.get_ticks_usec()) ^ (peer_id * 7919)
	var criatura := SISTEMA_SELECAO_ENCONTROS.selecionar(
		catalogo, ecossistema_id, bioma, perigo, permitir_chefe, semente
	)
	if criatura.is_empty():
		return false
	if not iniciar_combate_servidor(peer_id, criatura):
		return false
	_ultimo_encontro_ms[peer_id] = agora_ms
	return true

func iniciar_combate_servidor(peer_id: int, criatura_servidor: Dictionary) -> bool:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		return false
	if _combates_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id):
		return false
	var criatura_id := str(criatura_servidor.get("id", ""))
	if criatura_id.is_empty():
		return false
	# O combate usa sempre a cópia persistida do catálogo, nunca atributos soltos
	# fornecidos por um cliente ou alterados depois do registro.
	var criatura_catalogada := _repositorio_criaturas.obter_criatura(criatura_id)
	if criatura_catalogada.is_empty():
		var registro := _repositorio_criaturas.registrar_criatura_gerada(criatura_servidor)
		if not bool(registro.get("ok", false)):
			return false
		criatura_catalogada = _repositorio_criaturas.obter_criatura(criatura_id)
	if criatura_catalogada.is_empty():
		return false
	var perfil: Dictionary = _perfil_por_peer[peer_id]
	var estado_inicial := SistemaCombate.criar_estado(perfil, criatura_catalogada)
	if estado_inicial.is_empty():
		return false
	var uid := str(_uid_por_peer[peer_id])
	var descoberta := _repositorio_criaturas.registrar_descoberta(uid, criatura_id)
	if not bool(descoberta.get("ok", false)):
		return false
	_combates_por_peer[peer_id] = {"estado":estado_inicial,"criatura":criatura_catalogada.duplicate(true)}
	rpc_id(peer_id, "_receber_estado_combate", estado_inicial)
	return true

## Cliente envia somente uma ação da lista permitida; o servidor calcula todo o resultado.
func solicitar_acao_combate(acao: String) -> void:
	if estado == EstadoConexao.CONECTADO:
		_enviar_acao_combate.rpc_id(1, acao)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_acao_combate(acao: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or not _combates_por_peer.has(peer_id):
		return
	if not [SistemaCombate.ACAO_ATAQUE, SistemaCombate.ACAO_MAGIA, SistemaCombate.ACAO_DEFENDER, SistemaCombate.ACAO_ESQUIVAR].has(acao):
		rpc_id(peer_id, "_receber_erro_combate", "Ação de combate inválida.")
		return
	var sessao: Dictionary = _combates_por_peer[peer_id]
	var estado_atual: Dictionary = sessao.get("estado", {})
	var semente_servidor := int(Time.get_ticks_usec()) ^ (peer_id * 7919)
	var resultado := SistemaCombate.executar_rodada(estado_atual, acao, semente_servidor)
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_erro_combate", str(resultado.get("erro", "Não foi possível executar a ação.")))
		return
	var novo_estado: Dictionary = resultado["estado"]
	sessao["estado"] = novo_estado
	_combates_por_peer[peer_id] = sessao
	rpc_id(peer_id, "_receber_estado_combate", novo_estado)
	var status := str(novo_estado.get("status", SistemaCombate.STATUS_EM_ANDAMENTO))
	if status == SistemaCombate.STATUS_VITORIA or status == SistemaCombate.STATUS_DERROTA:
		var uid := str(_uid_por_peer.get(peer_id, ""))
		var estado_jogador: Dictionary = novo_estado.get("jogador", {})
		var derrotado := status == SistemaCombate.STATUS_DERROTA
		var salvo := _repositorio_perfis.registrar_recursos_combate(
			uid,
			int(estado_jogador.get("vida", 0)),
			int(estado_jogador.get("mana", 0)),
			derrotado
		)
		if not salvo:
			rpc_id(peer_id, "_receber_erro_combate", "Não foi possível salvar os recursos da batalha. O resultado foi encerrado sem conceder recompensas.")
			_combates_por_peer.erase(peer_id)
			return
		var perfil_atualizado: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
		if not perfil_atualizado.is_empty():
			_perfil_por_peer[peer_id] = perfil_atualizado
			rpc_id(peer_id, "_receber_perfil_personagem", perfil_atualizado)
		var drops: Array = []
		if status == SistemaCombate.STATUS_DERROTA:
			var criatura_sobrevivente: Dictionary = sessao.get("criatura", {})
			var posicao_derrota: Vector2 = _jogadores_no_mundo.get(peer_id, Vector2(1190.0, 1120.0))
			var evolucao_sobrevivente := _repositorio_criaturas.registrar_vitoria_sobre_jogador(uid, str(criatura_sobrevivente.get("id", "")), posicao_derrota)
			if bool(evolucao_sobrevivente.get("ok", false)):
				_carregar_criaturas_persistentes()
				rpc("_receber_criaturas_persistentes", _lista_visual_criaturas())
			if not bool(evolucao_sobrevivente.get("ok", false)):
				push_error("Não foi possível salvar a vitória e a evolução da criatura sobrevivente.")
		if status == SistemaCombate.STATUS_VITORIA:
			var criatura_derrotada: Dictionary = sessao.get("criatura", {})
			var registro_derrota := _repositorio_criaturas.registrar_derrota(uid, str(criatura_derrotada.get("id", "")))
			if not bool(registro_derrota.get("ok", false)):
				push_error("Não foi possível atualizar as estatísticas globais da criatura derrotada.")
			drops = concluir_combate_e_conceder_drops(peer_id, criatura_derrotada)
		_combates_por_peer.erase(peer_id)
		rpc_id(peer_id, "_receber_combate_finalizado", status, drops)

@rpc("authority", "call_remote", "reliable")
func _receber_estado_combate(novo_estado: Dictionary) -> void:
	combate_atualizado.emit(novo_estado.duplicate(true))

@rpc("authority", "call_remote", "reliable")
func _receber_erro_combate(mensagem: String) -> void:
	erro_combate.emit(mensagem)

@rpc("authority", "call_remote", "reliable")
func _receber_combate_finalizado(status: String, drops: Array) -> void:
	combate_finalizado.emit(status, drops)


## Restaura grupos existentes e cria populações somente para espécies com ecologia explícita.
func _carregar_grupos_selvagens() -> void:
	_grupos_mundo_cache.clear()
	var total_individuos := 0
	for grupo_existente in _repositorio_grupos.listar_todos_grupos():
		if _grupos_mundo_cache.size() >= LIMITE_GRUPOS_MUNDO:
			break
		var id_existente := str(grupo_existente.get("grupoId", ""))
		if id_existente.is_empty():
			continue
		var vivos_grupo := 0
		for individuo in grupo_existente.get("individuos", []):
			if bool(individuo.get("vivo", true)):
				vivos_grupo += 1
		if grupo_existente.get("individuos", []).size() > LIMITE_INDIVIDUOS_GRUPO_MUNDO or total_individuos + vivos_grupo > LIMITE_INDIVIDUOS_MUNDO:
			continue
		_grupos_mundo_cache[id_existente] = grupo_existente
		total_individuos += vivos_grupo
	var ecossistemas := REPOSITORIO_CRIATURAS.ECOSSISTEMAS
	for ecossistema_id in ecossistemas:
		if _grupos_mundo_cache.size() >= LIMITE_GRUPOS_MUNDO or total_individuos >= LIMITE_INDIVIDUOS_MUNDO:
			break
		for criatura in _repositorio_criaturas.listar_criaturas_do_ecossistema(str(ecossistema_id)):
			if _grupos_mundo_cache.size() >= LIMITE_GRUPOS_MUNDO or total_individuos >= LIMITE_INDIVIDUOS_MUNDO:
				break
			var ecologia: Dictionary = criatura.get("ecologia", {})
			var populacao: Dictionary = ecologia.get("populacao", {})
			var territorio: Dictionary = ecologia.get("territorio", {})
			if populacao.is_empty() or territorio.is_empty():
				continue
			var grupo_id := str(territorio.get("grupoId", str(criatura.get("id", "")) + "_" + str(criatura.get("bioma", ""))))
			if _grupos_mundo_cache.has(grupo_id):
				continue
			var quantidade_inicial := int(populacao.get("quantidadeInicial", 0))
			if quantidade_inicial <= 0 or quantidade_inicial > LIMITE_INDIVIDUOS_GRUPO_MUNDO:
				continue
			var criado := _repositorio_grupos.criar_grupo_para_criatura(str(criatura.get("id", "")))
			if not bool(criado.get("ok", false)):
				continue
			var grupo: Dictionary = criado.get("grupo", {})
			_grupos_mundo_cache[grupo_id] = grupo
			total_individuos += quantidade_inicial
	_ultima_atualizacao_grupos_ms = Time.get_ticks_msec()
	_ultima_gravacao_grupos_ms = _ultima_atualizacao_grupos_ms

func _lista_visual_individuos_grupos() -> Array:
	var resultado: Array = []
	for grupo in _grupos_mundo_cache.values():
		var especie := _repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
		var nome_especie := str(especie.get("nome", "Criatura selvagem"))
		var lider_id := str(grupo.get("liderAtual", {}).get("individuoId", ""))
		for individuo in grupo.get("individuos", []):
			var p: Dictionary = individuo.get("posicaoMundo", {})
			resultado.append({
				"id":str(individuo.get("individuoId", "")),
				"nome":nome_especie,
				"chefe":false,
				"lider":str(individuo.get("individuoId", "")) == lider_id,
				"morto":not bool(individuo.get("vivo", true)),
				"mutacoes":[],
				"comportamento":str(individuo.get("estadoMundo", "acompanhando_grupo")),
				"posicao":Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
			})
	return resultado

func _atualizar_grupos_selvagens(agora_ms: int) -> void:
	if agora_ms - _ultima_atualizacao_grupos_ms < INTERVALO_GRUPOS_SELVAJENS_MS:
		return
	var delta_segundos := clampf(float(agora_ms - _ultima_atualizacao_grupos_ms) / 1000.0, 0.0, 2.0)
	_ultima_atualizacao_grupos_ms = agora_ms
	if _grupos_mundo_cache.is_empty():
		return
	var atualizacoes: Array = []
	for grupo_id in _grupos_mundo_cache.keys():
		var grupo: Dictionary = _grupos_mundo_cache[grupo_id]
		var movimento := SISTEMA_MOVIMENTO_GRUPOS.avancar(grupo, delta_segundos, int(Time.get_ticks_usec()) ^ hash(str(grupo_id)))
		if not bool(movimento.get("ok", false)):
			continue
		grupo = movimento["grupo"]
		_grupos_mundo_cache[grupo_id] = grupo
		for atualizacao in movimento.get("atualizacoes", []):
			atualizacoes.append(atualizacao)
	if not atualizacoes.is_empty():
		rpc("_receber_posicoes_grupos_selvagens", atualizacoes)
	_processar_combate_ecologico(agora_ms)
	if agora_ms - _ultima_gravacao_grupos_ms >= INTERVALO_GRAVACAO_GRUPOS_MS:
		var salvou_todos := true
		for grupo_id in _grupos_mundo_cache.keys():
			var grupo: Dictionary = _grupos_mundo_cache[grupo_id]
			if not _repositorio_grupos.salvar_movimento_grupo(str(grupo_id), grupo.get("individuos", [])):
				salvou_todos = false
		if salvou_todos:
			_ultima_gravacao_grupos_ms = agora_ms

## Resolve encontros entre grupos no servidor, respeitando somente relações de dieta declaradas.
func _processar_combate_ecologico(agora_ms: int) -> void:
	var ids := _grupos_mundo_cache.keys()
	if ids.size() < 2:
		return
	for id_predador in ids:
		var grupo_predador: Dictionary = _grupos_mundo_cache[id_predador]
		var especie_predador := _repositorio_criaturas.obter_criatura(str(grupo_predador.get("especieId", "")))
		if especie_predador.is_empty():
			continue
		var membros_predadores: Array = grupo_predador.get("individuos", [])
		var atacante: Dictionary = {}
		for membro in membros_predadores:
			if bool(membro.get("vivo", false)):
				atacante = membro
				break
		if atacante.is_empty():
			continue
		var pos_atacante_dados: Dictionary = atacante.get("posicaoMundo", {})
		var pos_atacante := Vector2(float(pos_atacante_dados.get("x", -9999.0)), float(pos_atacante_dados.get("y", -9999.0)))
		for id_presa in ids:
			if id_presa == id_predador:
				continue
			var chave := str(id_predador) + "->" + str(id_presa)
			if agora_ms - int(_ultimo_ataque_ecologico_ms.get(chave, -INTERVALO_COMBATE_ECOLOGICO_MS)) < INTERVALO_COMBATE_ECOLOGICO_MS:
				continue
			var grupo_presa: Dictionary = _grupos_mundo_cache[id_presa]
			if str(grupo_presa.get("ecossistemaId", "")) != str(grupo_predador.get("ecossistemaId", "")):
				continue
			var especie_presa := _repositorio_criaturas.obter_criatura(str(grupo_presa.get("especieId", "")))
			if especie_presa.is_empty():
				continue
			var relacao := SISTEMA_ECOLOGIA_CRIATURAS.avaliar_relacao(especie_predador, especie_presa)
			if relacao.get("tipo") != "predador" or str(relacao.get("predador", "")) != str(especie_predador.get("id", "")):
				continue
			var alvo: Dictionary = {}
			var menor_distancia := DISTANCIA_COMBATE_ECOLOGICO
			for membro_presa in grupo_presa.get("individuos", []):
				if not bool(membro_presa.get("vivo", false)):
					continue
				var pos_dados: Dictionary = membro_presa.get("posicaoMundo", {})
				var pos := Vector2(float(pos_dados.get("x", -9999.0)), float(pos_dados.get("y", -9999.0)))
				var distancia := pos_atacante.distance_to(pos)
				if distancia < menor_distancia:
					menor_distancia = distancia
					alvo = membro_presa
			if alvo.is_empty():
				continue
			var presa_com_grupo := especie_presa.duplicate(true)
			presa_com_grupo["_grupo"] = grupo_presa
			var resultado := SISTEMA_COMBATE_ECOLOGICO.resolver_ataque(
				especie_predador, presa_com_grupo, atacante, alvo,
				int(Time.get_ticks_usec()) ^ hash(chave)
			)
			if not bool(resultado.get("ok", false)):
				continue
			var dano := int(resultado.get("dano", 0))
			var aplicado := _repositorio_grupos.aplicar_dano_ecologico(
				str(id_presa), str(resultado.get("alvoIndividuoId", "")), dano
			)
			if not bool(aplicado.get("ok", false)):
				continue
			grupo_presa = aplicado["grupo"]
			_grupos_mundo_cache[id_presa] = grupo_presa
			_ultimo_ataque_ecologico_ms[chave] = agora_ms
			var alvo_atualizado: Dictionary = aplicado.get("individuo", {})
			if bool(aplicado.get("morreu", false)):
				rpc("_receber_grupos_selvagens", _lista_visual_individuos_grupos())
			else:
				rpc("_receber_posicoes_grupos_selvagens", [{
					"individuoId":str(alvo_atualizado.get("individuoId", "")),
					"posicao":Vector2(float(alvo_atualizado.get("posicaoMundo", {}).get("x", 0.0)), float(alvo_atualizado.get("posicaoMundo", {}).get("y", 0.0))),
					"comportamento":"fugindo",
					"lider":str(alvo_atualizado.get("individuoId", "")) == str(grupo_presa.get("liderAtual", {}).get("individuoId", ""))
				}])
			break

## Carrega as criaturas sobreviventes salvas no disco do servidor.
func _carregar_criaturas_persistentes() -> void:
	_criaturas_mundo_cache.clear()
	for criatura in _repositorio_criaturas.listar_criaturas_persistentes():
		var id := str(criatura.get("id", ""))
		if not id.is_empty():
			_criaturas_mundo_cache[id] = criatura.duplicate(true)
	_ultima_atualizacao_criaturas_ms = Time.get_ticks_msec()
	_ultima_gravacao_criaturas_ms = _ultima_atualizacao_criaturas_ms

func _lista_visual_criaturas() -> Array:
	var lista: Array = []
	for criatura in _criaturas_mundo_cache.values():
		lista.append(_dados_visuais_criatura(criatura))
	return lista

func _dados_visuais_criatura(criatura: Dictionary) -> Dictionary:
	var evolucao: Dictionary = criatura.get("evolucao", {})
	var posicao: Dictionary = criatura.get("posicaoMundo", {})
	return {
		"id":str(criatura.get("id", "")),
		"nome":str(criatura.get("nome", "Criatura desconhecida")),
		"chefe":bool(criatura.get("chefe", false)),
		"raridade":str(criatura.get("raridade", "comum")),
		"mutacoes":evolucao.get("mutacoes", []).duplicate(true),
		"comportamento":str(criatura.get("estadoMundo", "vagando")),
		"posicao":Vector2(float(posicao.get("x", 0.0)), float(posicao.get("y", 0.0)))
	}

## Simula a movimentação errante no servidor; clientes recebem apenas posições autorizadas.
func _atualizar_criaturas_persistentes(agora_ms: int) -> void:
	if agora_ms - _ultima_atualizacao_criaturas_ms < INTERVALO_MOVIMENTO_CRIATURAS_MS:
		return
	var delta_segundos := clampf(float(agora_ms - _ultima_atualizacao_criaturas_ms) / 1000.0, 0.0, 2.0)
	_ultima_atualizacao_criaturas_ms = agora_ms
	if _criaturas_mundo_cache.is_empty():
		return
	var atualizacoes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for id in _criaturas_mundo_cache.keys():
		var criatura: Dictionary = _criaturas_mundo_cache[id]
		var posicao_dados: Dictionary = criatura.get("posicaoMundo", {})
		var origem_dados: Dictionary = criatura.get("origemMundo", posicao_dados)
		var alvo_dados: Dictionary = criatura.get("alvoMundo", posicao_dados)
		var posicao := Vector2(float(posicao_dados.get("x", 0.0)), float(posicao_dados.get("y", 0.0)))
		var origem := Vector2(float(origem_dados.get("x", posicao.x)), float(origem_dados.get("y", posicao.y)))
		var alvo := Vector2(float(alvo_dados.get("x", posicao.x)), float(alvo_dados.get("y", posicao.y)))
		var contexto := _obter_contexto_jogador_proximo(posicao, criatura)
		if not bool(contexto.get("ameacaPresente", false)):
			var contexto_ecologico := _obter_contexto_ecologico_proximo(id, posicao, criatura)
			if not contexto_ecologico.is_empty():
				contexto = contexto_ecologico
		var decisao := SISTEMA_COMPORTAMENTO_CRIATURAS.decidir(criatura, contexto)
		var comportamento := str(decisao.get("estado", "vagando"))
		var jogador_alvo: Vector2 = contexto.get("posicaoAlvo", posicao)
		if comportamento == SISTEMA_COMPORTAMENTO_CRIATURAS.FUGINDO:
			var direcao_fuga := posicao - jogador_alvo
			if direcao_fuga.length_squared() < 0.01:
				direcao_fuga = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
			alvo = posicao + direcao_fuga.normalized() * 150.0
		elif comportamento == SISTEMA_COMPORTAMENTO_CRIATURAS.CACANDO or comportamento == SISTEMA_COMPORTAMENTO_CRIATURAS.DEFENDENDO_TERRITORIO:
			var direcao_caca := jogador_alvo - posicao
			var distancia_parada := 28.0 if comportamento == SISTEMA_COMPORTAMENTO_CRIATURAS.CACANDO else 48.0
			if direcao_caca.length() > distancia_parada:
				alvo = jogador_alvo - direcao_caca.normalized() * distancia_parada
			else:
				alvo = posicao
		elif posicao.distance_to(alvo) < 12.0 or comportamento != str(criatura.get("estadoMundo", "vagando")):
			var angulo := rng.randf_range(0.0, TAU)
			var distancia := rng.randf_range(35.0, RAIO_VAGAR_CRIATURA)
			alvo = origem + Vector2(cos(angulo), sin(angulo)) * distancia
		alvo.x = clampf(alvo.x, 8.0, 2392.0)
		alvo.y = clampf(alvo.y, 8.0, 1592.0)
		var deslocamento := alvo - posicao
		var velocidade := VELOCIDADE_CRIATURA_ERRANTE * float(decisao.get("multiplicadorVelocidade", 1.0))
		var passo := velocidade * delta_segundos
		if deslocamento.length() > passo and passo > 0.0:
			posicao += deslocamento.normalized() * passo
		else:
			posicao = alvo
		criatura["posicaoMundo"] = {"x":posicao.x,"y":posicao.y}
		criatura["alvoMundo"] = {"x":alvo.x,"y":alvo.y}
		criatura["estadoMundo"] = comportamento
		_criaturas_mundo_cache[id] = criatura
		atualizacoes.append({"id":str(id),"posicao":posicao,"comportamento":comportamento})
	if not atualizacoes.is_empty():
		rpc("_receber_posicoes_criaturas", atualizacoes)
	if agora_ms - _ultima_gravacao_criaturas_ms >= INTERVALO_GRAVACAO_CRIATURAS_MS:
		var salvar: Array = []
		for criatura in _criaturas_mundo_cache.values():
			salvar.append({
				"id":str(criatura.get("id", "")),
				"posicaoMundo":criatura.get("posicaoMundo", {}),
				"alvoMundo":criatura.get("alvoMundo", {}),
				"estadoMundo":str(criatura.get("estadoMundo", "vagando"))
			})
		if _repositorio_criaturas.salvar_posicoes_mundo(salvar):
			_ultima_gravacao_criaturas_ms = agora_ms


## Procura a interação ecológica mais próxima entre criaturas persistentes.
## O servidor calcula posições e força; clientes não escolhem alvos.
func _obter_contexto_ecologico_proximo(id_atual: String, posicao: Vector2, criatura: Dictionary) -> Dictionary:
	var melhor_contexto: Dictionary = {}
	var menor_distancia := 140.0
	var forca_atual := _calcular_forca_comparativa(criatura, false)
	for outro_id in _criaturas_mundo_cache.keys():
		if str(outro_id) == id_atual:
			continue
		var outra: Dictionary = _criaturas_mundo_cache[outro_id]
		if str(outra.get("ecossistemaId", "")) != str(criatura.get("ecossistemaId", "")):
			continue
		var dados_posicao: Dictionary = outra.get("posicaoMundo", {})
		var posicao_outra := Vector2(float(dados_posicao.get("x", -1.0)), float(dados_posicao.get("y", -1.0)))
		if posicao_outra.x < 0.0 or posicao_outra.y < 0.0:
			continue
		var distancia := posicao.distance_to(posicao_outra)
		if distancia >= menor_distancia:
			continue
		var contexto := SISTEMA_ECOLOGIA_CRIATURAS.criar_contexto_interacao(
			criatura, outra, distancia, forca_atual,
			_calcular_forca_comparativa(outra, false), posicao_outra
		)
		if contexto.is_empty():
			continue
		menor_distancia = distancia
		melhor_contexto = contexto
	return melhor_contexto

## Compara a criatura com o jogador mais próximo usando apenas dados já validados pelo servidor.
## A criatura pode perseguir ou fugir, mas isso nunca inicia combate automaticamente.
func _obter_contexto_jogador_proximo(posicao: Vector2, criatura: Dictionary) -> Dictionary:
	var melhor_distancia := 180.0
	var melhor_peer := 0
	var melhor_posicao := posicao
	for peer_id in _jogadores_no_mundo.keys():
		var id := int(peer_id)
		if _combates_por_peer.has(id) or not _perfil_por_peer.has(id):
			continue
		var posicao_jogador: Vector2 = _jogadores_no_mundo[id]
		var distancia := posicao.distance_to(posicao_jogador)
		if distancia < melhor_distancia:
			melhor_distancia = distancia
			melhor_peer = id
			melhor_posicao = posicao_jogador
	if melhor_peer <= 0:
		return {"ameacaPresente":false}
	var perfil: Dictionary = _perfil_por_peer[melhor_peer]
	var forca_jogador := _calcular_forca_comparativa(perfil, true)
	var forca_criatura := _calcular_forca_comparativa(criatura, false)
	return {
		"ameacaPresente":true,
		"distanciaAmeaca":melhor_distancia,
		"forcaCriatura":forca_criatura,
		"forcaAmeaca":forca_jogador,
		"posicaoAlvo":melhor_posicao
	}

func _calcular_forca_comparativa(dados: Dictionary, jogador: bool) -> float:
	var nivel := maxf(1.0, float(dados.get("nivel", 1)))
	var vida := maxf(0.0, float(dados.get("vidaMaxima", 0)))
	var mana := maxf(0.0, float(dados.get("manaMaxima", 0)))
	if jogador:
		var efetivos := _atributos_efetivos_perfil(dados)
		return nivel * 5.0 + float(efetivos.get("forca", 5)) + float(efetivos.get("inteligencia", 5)) + float(efetivos.get("agilidade", 5)) + float(efetivos.get("vitalidade", 5)) + float(efetivos.get("espirito", 5)) + vida / 10.0 + mana / 10.0 + float(efetivos.get("defesaEquipamento", 0))
	return nivel * 5.0 + float(dados.get("ataque", 0)) + float(dados.get("defesa", 0)) + float(dados.get("agilidade", 0)) + float(dados.get("poderMagico", 0)) + vida / 10.0 + mana / 10.0

@rpc("authority", "call_remote", "reliable")
func _receber_grupos_selvagens(individuos: Array) -> void:
	grupos_selvagens_recebidos.emit(individuos.duplicate(true))

@rpc("authority", "call_remote", "unreliable_ordered")
func _receber_posicoes_grupos_selvagens(atualizacoes: Array) -> void:
	posicoes_grupos_selvagens_atualizadas.emit(atualizacoes.duplicate(true))

@rpc("authority", "call_remote", "reliable")
func _receber_criaturas_persistentes(lista: Array) -> void:
	criaturas_persistentes_recebidas.emit(lista.duplicate(true))

@rpc("authority", "call_remote", "unreliable_ordered")
func _receber_posicoes_criaturas(atualizacoes: Array) -> void:
	posicoes_criaturas_atualizadas.emit(atualizacoes.duplicate(true))

## Chamado exclusivamente pela lógica de combate executada no servidor.
## Não é RPC: clientes não podem escolher criatura, tabela, contexto ou recompensa.
func concluir_combate_e_conceder_drops(peer_id: int, criatura: Dictionary, contexto_batalha: Dictionary = {}) -> Array:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		return []
	if not bool(_perfil_por_peer[peer_id].get("personagemCriado", false)):
		return []
	var tabela: Array = criatura.get("tabelaDrops", [])
	if not SistemaDrops.validar_tabela(tabela):
		push_warning("Tabela de drops inválida; recompensa bloqueada.")
		return []
	var contexto := contexto_batalha.duplicate(true)
	# A semente é criada pelo servidor; não aceita sorteio escolhido pelo cliente.
	contexto["semente"] = int(Time.get_ticks_usec()) ^ (peer_id * 7919)
	var drops: Array = SistemaDrops.gerar_drops(criatura, contexto)
	if drops.is_empty():
		return []
	var uid := str(_uid_por_peer[peer_id])
	if not _repositorio_perfis.conceder_drops(uid, drops):
		push_error("Falha ao persistir recompensa de combate para o jogador autenticado.")
		return []
	var perfil_atualizado: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
	if perfil_atualizado.is_empty():
		return []
	_perfil_por_peer[peer_id] = perfil_atualizado
	rpc_id(peer_id, "_receber_perfil_personagem", perfil_atualizado)
	return drops


## Deriva os atributos de movimento no servidor a partir do perfil e do equipamento salvo.
func _atributos_efetivos_perfil(perfil: Dictionary) -> Dictionary:
	var base := {
		"forca": int(perfil.get("forca", 5)),
		"inteligencia": int(perfil.get("inteligencia", 5)),
		"agilidade": int(perfil.get("agilidade", 5)),
		"vitalidade": int(perfil.get("vitalidade", 5)),
		"espirito": int(perfil.get("espirito", 5)),
		"vidaMaxima": int(perfil.get("vidaMaxima", 100)),
		"manaMaxima": int(perfil.get("manaMaxima", 50))
	}
	return SistemaEquipamentos.calcular_atributos_efetivos(base, perfil.get("equipamentos", {}))

func _salvar_perfil_jogador(id_jogador: int) -> void:
	if not _uid_por_peer.has(id_jogador) or not _perfil_por_peer.has(id_jogador):
		return
	var perfil: Dictionary = _perfil_por_peer[id_jogador]
	if _jogadores_no_mundo.has(id_jogador):
		var posicao: Vector2 = _jogadores_no_mundo[id_jogador]
		perfil["x"] = posicao.x
		perfil["y"] = posicao.y
	var uid := str(_uid_por_peer[id_jogador])
	if _repositorio_perfis.salvar(uid, perfil):
		_perfil_por_peer[id_jogador] = perfil
		_ultima_gravacao_ms[id_jogador] = Time.get_ticks_msec()
	else:
		push_error("Falha ao salvar personagem do UID autenticado.")

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


## Compartilha somente dados cosméticos públicos, nunca UID, inventário ou atributos privados.
func _perfil_visual_publico(perfil: Dictionary) -> Dictionary:
	var publico := {}
	for chave in ["nome", "sexo", "aparenciaId", "racaId", "classeId", "anatomiaRacial", "equipamentos"]:
		if perfil.has(chave):
			publico[chave] = perfil[chave]
	return publico
