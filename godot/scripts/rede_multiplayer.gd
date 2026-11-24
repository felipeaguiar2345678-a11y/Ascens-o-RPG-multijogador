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
signal resultado_domesticacao(sucesso: bool, mensagem: String, invocacao: Dictionary)
signal resultado_descanso_clareira(sucesso: bool, mensagem: String)
signal resultado_missoes_npc(dados: Dictionary)
signal resultado_ovo_chocado(sucesso: bool, mensagem: String, invocacao: Dictionary)
signal resultado_selecao_invocacao(sucesso: bool, mensagem: String)
signal resultado_conversao_moedas(sucesso: bool, mensagem: String)
signal combate_atualizado(estado: Dictionary)
signal combate_finalizado(status: String, drops: Array)
signal erro_combate(mensagem: String)
signal criaturas_persistentes_recebidas(criaturas: Array)
signal posicoes_criaturas_atualizadas(atualizacoes: Array)
signal grupos_selvagens_recebidos(individuos: Array)
signal posicoes_grupos_selvagens_atualizadas(atualizacoes: Array)
signal anuncio_celeste_recebido(anuncio: Dictionary)
signal relogio_mundo_atualizado(contexto: Dictionary)
signal estado_serpente_mundo_atualizado(estado: Dictionary)
signal resultado_filhote_serpente(sucesso: bool, mensagem: String, invocacao: Dictionary)
signal sala_atualizada(dados: Dictionary)
signal aventura_sala_atualizada(dados: Dictionary)
signal resultado_mensagem_aventura(sucesso: bool, mensagem: String)
var estado_aventura_sala_atual: Dictionary = {}
var _ultima_mensagem_sala_ms: Dictionary = {}

enum EstadoConexao {
	DESCONECTADO,
	CONECTANDO,
	CONECTADO,
	SERVIDOR,
	FALHA
}

const PORTA_PADRAO: int = 2456
const MAXIMO_JOGADORES_PADRAO: int = 40
const VELOCIDADE_BASE_JOGADOR: float = 165.0
const REPOSITORIO_PERFIL = preload("res://scripts/repositorio_personagem_servidor.gd")
const SERVICO_MISSOES_MUNDO = preload("res://scripts/servico_missoes_mundo_servidor.gd")
const SistemaDrops = preload("res://scripts/sistema_drops.gd")
const SistemaEquipamentos = preload("res://scripts/sistema_equipamentos.gd")
const SistemaCombate = preload("res://scripts/sistema_combate.gd")
const SistemaCombateCooperativo = preload("res://scripts/sistema_combate_cooperativo.gd")
const SISTEMA_INVOCACOES = preload("res://scripts/sistema_invocacoes.gd")
const SISTEMA_CICLO_NOTURNO = preload("res://scripts/sistema_ciclo_noturno.gd")
const REPOSITORIO_CRIATURAS = preload("res://scripts/repositorio_criaturas_servidor.gd")
const SISTEMA_SELECAO_ENCONTROS = preload("res://scripts/sistema_selecao_encontros.gd")
const SISTEMA_AMBIENTES_MUNDO = preload("res://scripts/sistema_ambientes_mundo.gd")
const SISTEMA_COMPORTAMENTO_CRIATURAS = preload("res://scripts/sistema_comportamento_criaturas.gd")
const SISTEMA_ECOLOGIA_CRIATURAS = preload("res://scripts/sistema_ecologia_criaturas.gd")
const REPOSITORIO_GRUPOS = preload("res://scripts/repositorio_grupos_criaturas_servidor.gd")
const SISTEMA_MOVIMENTO_GRUPOS = preload("res://scripts/sistema_movimento_grupos.gd")
const SISTEMA_LIDERES = preload("res://scripts/sistema_lideres_criaturas.gd")
const SISTEMA_COMBATE_ECOLOGICO = preload("res://scripts/sistema_combate_ecologico.gd")
const SISTEMA_DEFESA_COOPERATIVA = preload("res://scripts/sistema_defesa_cooperativa.gd")
const SISTEMA_SERPENTE_MUNDO = preload("res://scripts/sistema_serpente_mundo.gd")
const SISTEMA_AJUDA_ALIMENTAR = preload("res://scripts/sistema_ajuda_alimentar.gd")
const SISTEMA_VALIDACAO_MOVIMENTO = preload("res://scripts/sistema_validacao_movimento.gd")
const SISTEMA_COLISOES_MUNDO = preload("res://scripts/sistema_colisoes_mundo.gd")
const REPOSITORIO_RECURSOS_ECOLOGICOS = preload("res://scripts/repositorio_recursos_ecologicos_servidor.gd")
const SISTEMA_LOCAIS_MISSOES = preload("res://scripts/sistema_locais_missoes_mundo.gd")
const SISTEMA_VALIDACAO_SESSAO = preload("res://scripts/sistema_validacao_sessao.gd")
const INTERVALO_GRAVACAO_MS := 5000
const INTERVALO_MINIMO_ENCONTROS_MS := 30000
const INTERVALO_MINIMO_ACAO_COMBATE_MS := 350
const INTERVALO_MOVIMENTO_CRIATURAS_MS := 1000
const INTERVALO_GRAVACAO_CRIATURAS_MS := 5000
const INTERVALO_GRUPOS_SELVAJENS_MS := 1000
const INTERVALO_COMBATE_ECOLOGICO_MS := 6000
const DISTANCIA_COMBATE_ECOLOGICO := 38.0
const INTERVALO_GRAVACAO_GRUPOS_MS := 5000
const INTERVALO_SIMULACAO_POPULACIONAL_MS := 60000
const LIMITE_GRUPOS_MUNDO := 64
const LIMITE_INDIVIDUOS_GRUPO_MUNDO := 80
const LIMITE_INDIVIDUOS_MUNDO := 2000
const VELOCIDADE_CRIATURA_ERRANTE := 24.0
const RAIO_VAGAR_CRIATURA := 220.0
const CAMINHO_SEMENTE_MUNDO_CELESTE := "user://dados/semente_mundo_celeste.json"
const CAMINHO_ESTADO_SERPENTE := "user://dados/incursao_serpente_mundo.json"
const POSICAO_CABECA_SERPENTE := Vector2(1200.0, 80.0)
const CUSTO_MAGIA_SERPENTE := 10

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
var _local_visitado_atual_por_peer: Dictionary = {}
var _ultimo_evento_visita_por_peer: Dictionary = {}
var _perfil_por_peer: Dictionary = {}
var _repositorio_perfis = REPOSITORIO_PERFIL.new()
var _servico_missoes_mundo = null
var _ultima_gravacao_ms: Dictionary = {}
var _combates_por_peer: Dictionary = {}
var _ultima_acao_combate_ms: Dictionary = {}
var _repositorio_criaturas = REPOSITORIO_CRIATURAS.new()
var _ultimo_encontro_ms: Dictionary = {}
var _criaturas_mundo_cache: Dictionary = {}
var _ultima_atualizacao_criaturas_ms := 0
var _ultima_gravacao_criaturas_ms := 0
var _repositorio_grupos = REPOSITORIO_GRUPOS.new()
var _repositorio_recursos_ecologicos = REPOSITORIO_RECURSOS_ECOLOGICOS.new()
var _ultimo_tick_populacional_ms := 0
var _grupos_mundo_cache: Dictionary = {}
var _ultima_atualizacao_grupos_ms := 0
var _ultima_gravacao_grupos_ms := 0
var _ultimo_ataque_ecologico_ms: Dictionary = {}
var _ultimo_apoio_alimentar_unix: Dictionary = {}
var _semente_mundo_celeste: int = 0
var _ultimo_periodo_celeste: String = "indefinido"
var _ultimo_dia_celeste: int = -1
var _ultimo_envio_relogio_ms := 0
var _contexto_celeste_atual: Dictionary = {}
var _estado_serpente_mundo: Dictionary = {}
var _estado_serpente_mundo_publico: Dictionary = {}
var _ultima_revisao_estado_serpente_recebida: int = -1
var _ultima_limpeza_marcas_destruicao_unix := 0
var _ultimo_ataque_serpente_ms: int = 0
var _ultimo_descanso_clareira_ms: Dictionary = {}
const SISTEMA_SALAS = preload("res://scripts/sistema_salas_multiplayer.gd")
const REPOSITORIO_SALAS = preload("res://scripts/repositorio_salas_multiplayer_servidor.gd")
var _salas_publicas = SISTEMA_SALAS.new()
var _repositorio_salas = REPOSITORIO_SALAS.new()
var acao_sala_cliente: String = "mundo"
var codigo_sala_cliente: String = ""
var _intencao_sala_por_peer: Dictionary = {}

func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var agora := Time.get_ticks_msec()
	_atualizar_ciclo_celeste_autoritativo()
	_atualizar_criaturas_persistentes(agora)
	_atualizar_grupos_selvagens(agora)
	_atualizar_incursao_serpente(agora)
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
	_ultima_revisao_estado_serpente_recebida = -1
	_estado_serpente_mundo_publico.clear()
	estado_aventura_sala_atual.clear()
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
	if not _carregar_salas_persistentes():
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	_servico_missoes_mundo = SERVICO_MISSOES_MUNDO.new(_repositorio_perfis)
	_carregar_criaturas_persistentes()
	_carregar_estado_serpente_mundo()
	_carregar_grupos_selvagens()
	_semente_mundo_celeste = _carregar_ou_criar_semente_mundo_celeste()
	_contexto_celeste_atual.clear()
	_ultimo_periodo_celeste = "indefinido"
	_ultimo_dia_celeste = -1
	_ultimo_envio_relogio_ms = 0
	_ultimo_tick_populacional_ms = Time.get_ticks_msec()
	_mudar_estado(EstadoConexao.SERVIDOR)
	_atualizar_ciclo_celeste_autoritativo()
	return OK

## API interna para a interação futura com NPCs e eventos do mundo.
## Todas as operações exigem identidade já autenticada e são recusadas no cliente.
func registrar_oferta_missao_mundo(definicao: Dictionary) -> Dictionary:
	if not multiplayer.is_server() or _servico_missoes_mundo == null:
		return {"ok": false, "erro": "Operação disponível somente no servidor."}
	return _servico_missoes_mundo.registrar_oferta(definicao)

func listar_ofertas_missao_mundo(peer_id: int, npc_id: String) -> Array:
	if not multiplayer.is_server() or _servico_missoes_mundo == null or not _uid_por_peer.has(peer_id):
		return []
	return _servico_missoes_mundo.listar_ofertas(str(_uid_por_peer[peer_id]), npc_id)

func aceitar_missao_mundo(peer_id: int, missao_id: String) -> Dictionary:
	if not _pode_alterar_missao(peer_id):
		return {"ok": false, "erro": "Jogador não autenticado ou indisponível."}
	return _sincronizar_resultado_missao_peer(peer_id, _servico_missoes_mundo.aceitar(str(_uid_por_peer[peer_id]), missao_id))

func recusar_missao_mundo(peer_id: int, missao_id: String) -> Dictionary:
	if not _pode_alterar_missao(peer_id):
		return {"ok": false, "erro": "Jogador não autenticado ou indisponível."}
	return _sincronizar_resultado_missao_peer(peer_id, _servico_missoes_mundo.recusar(str(_uid_por_peer[peer_id]), missao_id))

func abandonar_missao_mundo(peer_id: int, missao_id: String) -> Dictionary:
	if not _pode_alterar_missao(peer_id):
		return {"ok": false, "erro": "Jogador não autenticado ou indisponível."}
	return _sincronizar_resultado_missao_peer(peer_id, _servico_missoes_mundo.abandonar(str(_uid_por_peer[peer_id]), missao_id))

## Chamar apenas após o servidor confirmar a derrota, coleta, visita ou encontro.
func registrar_evento_missao_mundo(peer_id: int, tipo_evento: String, alvo_id: String, quantidade: int = 1) -> Dictionary:
	if not multiplayer.is_server() or _servico_missoes_mundo == null or not _uid_por_peer.has(peer_id):
		return {"ok": false, "erro": "Jogador não autenticado no servidor."}
	if not _perfil_por_peer.has(peer_id):
		return {"ok": false, "erro": "Perfil do personagem não está carregado."}
	var resultado: Dictionary = _servico_missoes_mundo.registrar_evento_confirmado(str(_uid_por_peer[peer_id]), tipo_evento, alvo_id, quantidade)
	return _sincronizar_resultado_missao_peer(peer_id, resultado)

func _registrar_visita_local_confirmada(peer_id: int, posicao: Vector2) -> void:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id) or _combates_por_peer.has(peer_id):
		return
	var local_id := SISTEMA_LOCAIS_MISSOES.obter_local_visitado(posicao)
	var local_anterior := str(_local_visitado_atual_por_peer.get(peer_id, ""))
	if local_id == local_anterior:
		return
	if local_id.is_empty():
		_local_visitado_atual_por_peer.erase(peer_id)
		return
	_local_visitado_atual_por_peer[peer_id] = local_id
	# O ponto de renascimento só é atualizado quando a posição validada pelo
	# servidor entra em um local explicitamente marcado como seguro.
	var ponto_seguro: Dictionary = SISTEMA_LOCAIS_MISSOES.obter_ponto_renascimento(local_id)
	if not ponto_seguro.is_empty():
		var perfil_atual: Dictionary = _perfil_por_peer[peer_id]
		if str(perfil_atual.get("pontoRenascimentoId", "clareira_inicial")) != local_id:
			var posicao_segura: Vector2 = ponto_seguro.get("posicao", Vector2.ZERO)
			var salvo_ponto: Dictionary = _repositorio_perfis.atualizar_ponto_renascimento(str(_uid_por_peer[peer_id]), local_id, posicao_segura.x, posicao_segura.y)
			if bool(salvo_ponto.get("ok", false)):
				var perfil_seguro: Dictionary = salvo_ponto.get("perfil", {})
				_perfil_por_peer[peer_id] = perfil_seguro.duplicate(true)
				if peer_id == multiplayer.get_unique_id():
					perfil_personagem_atual = perfil_seguro.duplicate(true)
					perfil_personagem_recebido.emit(perfil_personagem_atual)
				else:
					rpc_id(peer_id, "_receber_perfil_personagem", perfil_seguro)
	var agora := Time.get_ticks_msec()
	var cooldowns: Dictionary = _ultimo_evento_visita_por_peer.get(peer_id, {}).duplicate(true)
	var ultimo_evento := int(cooldowns.get(local_id, -60000))
	if agora - ultimo_evento < 60000:
		return
	var resultado := registrar_evento_missao_mundo(peer_id, "visitar_local", local_id, 1)
	if bool(resultado.get("ok", false)):
		cooldowns[local_id] = agora
		_ultimo_evento_visita_por_peer[peer_id] = cooldowns

func concluir_missao_mundo(peer_id: int, missao_id: String) -> Dictionary:
	if not _pode_alterar_missao(peer_id):
		return {"ok": false, "erro": "Jogador não autenticado ou indisponível."}
	return _sincronizar_resultado_missao_peer(peer_id, _servico_missoes_mundo.concluir_e_pagar(str(_uid_por_peer[peer_id]), missao_id))

const POSICAO_IREN_MISSOES := Vector2(1370.0, 1510.0)
const DISTANCIA_INTERACAO_MISSOES := 92.0

func solicitar_dados_missoes_npc(npc_id: String) -> void:
	if estado == EstadoConexao.SERVIDOR:
		_processar_consulta_missoes_npc(multiplayer.get_unique_id(), npc_id)
	elif estado == EstadoConexao.CONECTADO:
		_solicitar_dados_missoes_npc.rpc_id(1, npc_id)

@rpc("any_peer", "call_remote", "reliable")
func _solicitar_dados_missoes_npc(npc_id: String) -> void:
	if multiplayer.is_server():
		_processar_consulta_missoes_npc(multiplayer.get_remote_sender_id(), npc_id)

func solicitar_acao_missao_npc(npc_id: String, missao_id: String, acao: String) -> void:
	if estado == EstadoConexao.SERVIDOR:
		_processar_acao_missao_npc(multiplayer.get_unique_id(), npc_id, missao_id, acao)
	elif estado == EstadoConexao.CONECTADO:
		_solicitar_acao_missao_npc.rpc_id(1, npc_id, missao_id, acao)

@rpc("any_peer", "call_remote", "reliable")
func _solicitar_acao_missao_npc(npc_id: String, missao_id: String, acao: String) -> void:
	if multiplayer.is_server():
		_processar_acao_missao_npc(multiplayer.get_remote_sender_id(), npc_id, missao_id, acao)

func _peer_pode_interagir_com_iren(peer_id: int) -> bool:
	if not multiplayer.is_server() or _servico_missoes_mundo == null:
		return false
	if not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id):
		return false
	if not bool(_perfil_por_peer[peer_id].get("personagemCriado", false)) or _combates_por_peer.has(peer_id):
		return false
	var posicao: Vector2 = _jogadores_no_mundo[peer_id]
	return posicao.distance_to(POSICAO_IREN_MISSOES) <= DISTANCIA_INTERACAO_MISSOES

func _processar_consulta_missoes_npc(peer_id: int, npc_id: String) -> void:
	if npc_id != "iren_viajante" or not _peer_pode_interagir_com_iren(peer_id):
		_enviar_dados_missoes_npc(peer_id, [], [], "Aproxime-se de Iren para conversar.")
		return
	var uid := str(_uid_por_peer[peer_id])
	var ofertas: Array = _servico_missoes_mundo.listar_ofertas(uid, npc_id)
	var ativas: Array = _servico_missoes_mundo.listar_missoes_do_npc(uid, npc_id)
	_enviar_dados_missoes_npc(peer_id, ofertas, ativas, "")

func _processar_acao_missao_npc(peer_id: int, npc_id: String, missao_id: String, acao: String) -> void:
	if npc_id != "iren_viajante" or not _peer_pode_interagir_com_iren(peer_id):
		_enviar_dados_missoes_npc(peer_id, [], [], "Aproxime-se de Iren e saia de qualquer combate.")
		return
	if missao_id.strip_edges().is_empty() or missao_id.length() > 128 or not ["aceitar", "recusar", "abandonar", "concluir"].has(acao):
		_enviar_dados_missoes_npc(peer_id, [], [], "Ação de missão inválida.")
		return
	var uid := str(_uid_por_peer[peer_id])
	if not _servico_missoes_mundo.missao_vinculada_ao_npc(uid, npc_id, missao_id, acao):
		_enviar_dados_missoes_npc(peer_id, _servico_missoes_mundo.listar_ofertas(uid, npc_id), _servico_missoes_mundo.listar_missoes_do_npc(uid, npc_id), "Essa missão não pertence a este viajante.")
		return
	var resultado: Dictionary
	match acao:
		"aceitar":
			resultado = _servico_missoes_mundo.aceitar(uid, missao_id)
		"recusar":
			resultado = _servico_missoes_mundo.recusar(uid, missao_id)
		"abandonar":
			resultado = _servico_missoes_mundo.abandonar(uid, missao_id)
		"concluir":
			resultado = concluir_missao_mundo(peer_id, missao_id)
		_:
			resultado = {"ok": false, "erro": "Ação inválida."}
	if bool(resultado.get("ok", false)):
		_sincronizar_resultado_missao_peer(peer_id, resultado)
	var ofertas: Array = _servico_missoes_mundo.listar_ofertas(uid, npc_id)
	var ativas: Array = _servico_missoes_mundo.listar_missoes_do_npc(uid, npc_id)
	_enviar_dados_missoes_npc(peer_id, ofertas, ativas, "Escolha registrada." if bool(resultado.get("ok", false)) else str(resultado.get("erro", "Não foi possível atualizar a missão.")))

func _enviar_dados_missoes_npc(peer_id: int, ofertas: Array, ativas: Array, mensagem: String) -> void:
	var dados := {"ofertas": ofertas.duplicate(true), "ativas": ativas.duplicate(true), "mensagem": mensagem}
	if multiplayer.is_server() and peer_id == multiplayer.get_unique_id():
		resultado_missoes_npc.emit(dados)
	elif peer_id > 0:
		rpc_id(peer_id, "_receber_dados_missoes_npc", dados)

@rpc("authority", "call_remote", "reliable")
func _receber_dados_missoes_npc(dados: Dictionary) -> void:
	resultado_missoes_npc.emit(dados.duplicate(true))

func _pode_alterar_missao(peer_id: int) -> bool:
	return multiplayer.is_server() and _servico_missoes_mundo != null and _uid_por_peer.has(peer_id) and _perfil_por_peer.has(peer_id) and not _combates_por_peer.has(peer_id) and bool(_perfil_por_peer[peer_id].get("personagemCriado", false))

func _sincronizar_resultado_missao_peer(peer_id: int, resultado: Dictionary) -> Dictionary:
	if not bool(resultado.get("ok", false)):
		return resultado
	var perfil_atualizado: Dictionary = resultado.get("perfil", {})
	if not perfil_atualizado.is_empty():
		_perfil_por_peer[peer_id] = perfil_atualizado.duplicate(true)
		rpc_id(peer_id, "_receber_perfil_personagem", perfil_atualizado)
	resultado.erase("perfil")
	return resultado

func desconectar() -> void:
	_limpar_peer()
	endereco_servidor = ""
	token_firebase = ""
	uid_autenticado = ""
	email_autenticado = ""
	perfil_personagem_atual.clear()
	estado_aventura_sala_atual.clear()
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
	solicitar_autenticacao.rpc_id(1, token_firebase, acao_sala_cliente, codigo_sala_cliente)

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
		var saida_sala: Dictionary = _salas_publicas.remover_jogador(id_jogador)
		if bool(saida_sala.get("removido", false)):
			_salvar_salas_persistentes()
			_publicar_estado_sala(str(saida_sala.get("codigo", "")))
		_intencao_sala_por_peer.erase(id_jogador)
		_ultima_mensagem_sala_ms.erase(id_jogador)
		# Invalida a requisição HTTP da sessão encerrada. A checagem de identidade
		# no callback também impede que uma resposta atrasada autentique um peer reutilizado.
		var validacao_pendente = _validacoes_em_andamento.get(id_jogador)
		if validacao_pendente is HTTPRequest:
			validacao_pendente.cancel_request()
			validacao_pendente.queue_free()
		_validacoes_em_andamento.erase(id_jogador)
		# Preserva o UID antes de removê-lo da tabela de conexões.
		if _estado_serpente_mundo.size() > 0 and _uid_por_peer.has(id_jogador):
			_estado_serpente_mundo = SISTEMA_SERPENTE_MUNDO.marcar_desconectado(_estado_serpente_mundo, str(_uid_por_peer[id_jogador]), id_jogador)
			_salvar_estado_serpente_mundo()
			_publicar_estado_serpente_mundo()
		_uid_por_peer.erase(id_jogador)
		_combates_por_peer.erase(id_jogador)
		_ultima_acao_combate_ms.erase(id_jogador)
		_perfil_por_peer.erase(id_jogador)
		_ultima_gravacao_ms.erase(id_jogador)
		_ultimo_encontro_ms.erase(id_jogador)
		_jogadores_no_mundo.erase(id_jogador)
		_ultimo_pacote_posicao_ms.erase(id_jogador)
		_local_visitado_atual_por_peer.erase(id_jogador)
		_ultimo_evento_visita_por_peer.erase(id_jogador)
		_ultimo_descanso_clareira_ms.erase(id_jogador)
		rpc("_receber_jogador_saiu", id_jogador)

@rpc("any_peer", "call_remote", "reliable")
func solicitar_autenticacao(token: String, acao_sala: String = "mundo", codigo_sala: String = "") -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 0 or token.is_empty() or token.length() > 8192:
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Credencial inválida.")
		return
	if _validacoes_em_andamento.has(peer_id) or _uid_por_peer.has(peer_id):
		return
	if not ["mundo", "criar_sala", "sala_publica", "entrar_codigo"].has(acao_sala):
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Modo de entrada inválido.")
		return
	if acao_sala == "entrar_codigo" and codigo_sala.strip_edges().length() != SISTEMA_SALAS.TAMANHO_CODIGO:
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Informe um código de sala válido com seis caracteres.")
		return
	_intencao_sala_por_peer[peer_id] = {"acao": acao_sala, "codigo": codigo_sala.strip_edges().to_upper()}
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
	# A resposta só pertence à conexão que iniciou esta requisição. Um peer_id
	# pode ser reutilizado depois de uma desconexão; nunca autentique a nova sessão
	# com a resposta HTTP de uma sessão anterior.
	if not SISTEMA_VALIDACAO_SESSAO.consumir_se_corresponder(_validacoes_em_andamento, peer_id, requisicao):
		requisicao.queue_free()
		return
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
		_intencao_sala_por_peer.erase(peer_id)
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Não foi possível carregar ou criar seu personagem no servidor.")
		requisicao.queue_free()
		return
	var intencao: Dictionary = _intencao_sala_por_peer.get(peer_id, {"acao":"mundo","codigo":""})
	var resultado_sala: Dictionary = _processar_entrada_sala(peer_id, uid, intencao)
	if not bool(resultado_sala.get("sucesso", false)):
		_uid_por_peer.erase(peer_id)
		_intencao_sala_por_peer.erase(peer_id)
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", str(resultado_sala.get("erro", "Não foi possível entrar na sala.")))
		requisicao.queue_free()
		return
	# A entrada pode concluir recompensas pendentes de uma vitória anterior.
	# Recarrega o perfil para não publicar o snapshot anterior à concessão.
	perfil = _repositorio_perfis.carregar_ou_criar(uid)
	if perfil.is_empty():
		_uid_por_peer.erase(peer_id)
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Não foi possível atualizar seu perfil após entrar na sala.")
		requisicao.queue_free()
		return
	_perfil_por_peer[peer_id] = perfil
	var email := str(usuario.get("email", ""))
	rpc_id(peer_id, "_receber_autenticacao_aprovada", uid, email)
	if resultado_sala.has("codigo"):
		rpc_id(peer_id, "_receber_sala_atualizada", resultado_sala)
		_publicar_estado_sala(str(resultado_sala.get("codigo", "")))
		# Sincroniza o estado narrativo atual somente com os membros desta sala.
		rpc_id(peer_id, "_receber_estado_aventura_sala", _salas_publicas.obter_estado_aventura(peer_id))
	if bool(perfil.get("personagemCriado", false)):
		if _esta_em_sala_cooperativa_peer(peer_id):
			rpc_id(peer_id, "_receber_perfil_personagem", perfil)
		else:
			_adicionar_jogador_autenticado(peer_id)
	requisicao.queue_free()

func _esta_em_sala_cooperativa_peer(peer_id: int) -> bool:
	return not _salas_publicas.obter_sala_do_jogador(peer_id).is_empty()

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
	if not _esta_em_sala_cooperativa_peer(peer_id):
		_adicionar_jogador_autenticado(peer_id)

@rpc("authority", "call_remote", "reliable")
func _receber_criacao_personagem_falhou(mensagem: String) -> void:
	erro_conexao.emit(mensagem)
func _adicionar_jogador_autenticado(id_jogador: int) -> void:
	if not _uid_por_peer.has(id_jogador) or _jogadores_no_mundo.has(id_jogador):
		return
	var perfil: Dictionary = _perfil_por_peer.get(id_jogador, {})
	var posicao := Vector2(float(perfil.get("x", 1190.0)), float(perfil.get("y", 1520.0)))
	# Nunca restaura uma posição persistida corrompida ou fora do mundo.
	if not SISTEMA_VALIDACAO_MOVIMENTO.posicao_inicial_valida(posicao):
		push_warning("Posição persistida inválida para peer %d; personagem reposicionado no ponto inicial seguro." % id_jogador)
		posicao = Vector2(1190.0, 1520.0)
		perfil["x"] = posicao.x
		perfil["y"] = posicao.y
		_perfil_por_peer[id_jogador] = perfil
	var lista_existente: Array = []
	for id_existente in _jogadores_no_mundo:
		lista_existente.append({"id": int(id_existente), "posicao": _jogadores_no_mundo[id_existente], "perfil": _perfil_visual_publico(_perfil_por_peer.get(id_existente, {}))})
	_jogadores_no_mundo[id_jogador] = posicao
	_ultimo_pacote_posicao_ms[id_jogador] = Time.get_ticks_msec()
	_registrar_visita_local_confirmada(id_jogador, posicao)
	_ultima_gravacao_ms[id_jogador] = Time.get_ticks_msec()
	rpc_id(id_jogador, "_receber_estado_inicial", lista_existente)
	rpc_id(id_jogador, "_receber_criaturas_persistentes", _lista_visual_criaturas())
	rpc_id(id_jogador, "_receber_grupos_selvagens", _lista_visual_individuos_grupos())
	rpc_id(id_jogador, "_receber_perfil_personagem", perfil)
	# Um jogador que entra no meio de um fenômeno recebe o estado celeste atual imediatamente.
	if _contexto_celeste_atual.is_empty():
		_contexto_celeste_atual = _obter_contexto_celeste_servidor()
	rpc_id(id_jogador, "_receber_relogio_mundo", _contexto_celeste_atual)
	var estado_serpente_inicial := SISTEMA_SERPENTE_MUNDO.obter_estado_publico(_estado_serpente_mundo)
	estado_serpente_inicial["mundoId"] = SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO
	estado_serpente_inicial["escopo"] = "global"
	rpc_id(id_jogador, "_receber_estado_serpente_mundo", estado_serpente_inicial)
	rpc("_receber_jogador_entrou", id_jogador, posicao, _perfil_visual_publico(perfil))


## Envia uma mensagem narrativa; a identidade é obtida exclusivamente da sessão autenticada.
func enviar_mensagem_aventura_sala(texto: String) -> void:
	var mensagem := texto.strip_edges()
	if mensagem.is_empty() or mensagem.length() > 300:
		resultado_mensagem_aventura.emit(false, "A mensagem deve ter de 1 a 300 caracteres.")
		return
	if estado == EstadoConexao.SERVIDOR:
		_processar_mensagem_aventura_sala(multiplayer.get_unique_id(), mensagem)
	elif estado == EstadoConexao.CONECTADO:
		_solicitar_mensagem_aventura_sala.rpc_id(1, mensagem)

@rpc("any_peer", "call_remote", "reliable")
func _solicitar_mensagem_aventura_sala(texto: String) -> void:
	if not multiplayer.is_server():
		return
	_processar_mensagem_aventura_sala(multiplayer.get_remote_sender_id(), texto)

func _processar_mensagem_aventura_sala(peer_id: int, texto: String) -> void:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		_enviar_resultado_mensagem(peer_id, false, "Entre com uma conta válida antes de falar.")
		return
	var agora := Time.get_ticks_msec()
	if agora - int(_ultima_mensagem_sala_ms.get(peer_id, -2000)) < 1200:
		_enviar_resultado_mensagem(peer_id, false, "Aguarde um instante antes de enviar outra mensagem.")
		return
	var perfil: Dictionary = _perfil_por_peer[peer_id]
	var resultado: Dictionary = _salas_publicas.registrar_mensagem(peer_id, str(_uid_por_peer[peer_id]), str(perfil.get("nome", "Aventureiro")), texto)
	if not bool(resultado.get("sucesso", false)):
		_enviar_resultado_mensagem(peer_id, false, str(resultado.get("erro", "Não foi possível enviar a mensagem.")))
		return
	_ultima_mensagem_sala_ms[peer_id] = agora
	_salvar_salas_persistentes()
	_publicar_estado_aventura_da_sala(peer_id)
	_enviar_resultado_mensagem(peer_id, true, "Mensagem enviada.")

func _enviar_resultado_mensagem(peer_id: int, sucesso: bool, mensagem: String) -> void:
	if multiplayer.is_server() and peer_id == multiplayer.get_unique_id():
		resultado_mensagem_aventura.emit(sucesso, mensagem)
	elif peer_id > 0:
		rpc_id(peer_id, "_receber_resultado_mensagem_aventura", sucesso, mensagem)

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_mensagem_aventura(sucesso: bool, mensagem: String) -> void:
	resultado_mensagem_aventura.emit(sucesso, mensagem)

func esta_em_sala_cooperativa() -> bool:
	return ["criar_sala", "sala_publica", "entrar_codigo"].has(acao_sala_cliente)

func _processar_entrada_sala(peer_id: int, uid: String, intencao: Dictionary) -> Dictionary:
	var acao := str(intencao.get("acao", "mundo"))
	if acao == "mundo":
		return {"sucesso": true}
	var resultado: Dictionary
	match acao:
		"criar_sala":
			resultado = _salas_publicas.criar_sala(peer_id, uid)
		"sala_publica":
			resultado = _salas_publicas.entrar_sala_publica(peer_id, uid)
		"entrar_codigo":
			resultado = _salas_publicas.entrar_sala(peer_id, uid, str(intencao.get("codigo", "")))
		_:
			return {"sucesso": false, "erro": "Opção de sala desconhecida."}
	if not bool(resultado.get("sucesso", false)):
		return resultado
	_salvar_salas_persistentes()
	var sala: Dictionary = resultado.get("sala", {})
	var estado_sala: Dictionary = sala.get("estadoAventura", {})
	var encontro_pendente: Dictionary = estado_sala.get("encontro", {})
	if str(encontro_pendente.get("resultado", "")) == "vitoria" and not bool(encontro_pendente.get("recompensasConcluidas", false)):
		if _conceder_recompensas_encontro_cooperativo(encontro_pendente):
			encontro_pendente["recompensasConcluidas"] = true
			estado_sala["encontro"] = encontro_pendente
			var revisao_sala := int(sala.get("revisaoAventura", 0))
			var atualizacao_recompensa: Dictionary = _salas_publicas.atualizar_estado_aventura(peer_id, estado_sala, revisao_sala)
			if bool(atualizacao_recompensa.get("sucesso", false)):
				_salvar_salas_persistentes()
	elif str(encontro_pendente.get("resultado", "")) == "derrota" and not bool(encontro_pendente.get("recursosDerrotaConcluidos", false)):
		if _processar_derrota_total_encontro_cooperativo(peer_id, encontro_pendente):
			encontro_pendente["recursosDerrotaConcluidos"] = true
			estado_sala["encontro"] = encontro_pendente
			var revisao_derrota := int(sala.get("revisaoAventura", 0))
			var atualizacao_derrota: Dictionary = _salas_publicas.atualizar_estado_aventura(peer_id, estado_sala, revisao_derrota)
			if bool(atualizacao_derrota.get("sucesso", false)):
				_salvar_salas_persistentes()
	return {"sucesso":true, "codigo":str(resultado.get("codigo","")), "jogadores":(sala.get("jogadores",[]) as Array).size(), "limite":SISTEMA_SALAS.MAXIMO_JOGADORES_POR_SALA, "anfitriaoPeerId":int(sala.get("anfitriaoPeerId",peer_id))}

func _carregar_salas_persistentes() -> bool:
	var leitura: Dictionary = _repositorio_salas.carregar()
	if not bool(leitura.get("sucesso", false)):
		push_error("Salas persistentes não foram carregadas: %s" % str(leitura.get("erro", "erro desconhecido")))
		return false
	var restauracao: Dictionary = _salas_publicas.restaurar_estado_persistente(leitura.get("salas", []))
	if not bool(restauracao.get("sucesso", false)):
		push_error("Estado persistente das salas foi rejeitado: %s" % str(restauracao.get("erro", "erro desconhecido")))
		return false
	print("Salas cooperativas restauradas: %d." % int(restauracao.get("quantidade", 0)))
	return true

func _salvar_salas_persistentes() -> void:
	if not multiplayer.is_server():
		return
	if not _repositorio_salas.salvar(_salas_publicas.exportar_estado_persistente()):
		push_error("Não foi possível persistir o progresso das salas cooperativas.")

func _criar_perfil_visual_publico(perfil: Dictionary) -> Dictionary:
	var anatomia: Dictionary = perfil.get("anatomiaRacial", {}) if perfil.get("anatomiaRacial", {}) is Dictionary else {}
	var equipamentos: Dictionary = perfil.get("equipamentos", {}) if perfil.get("equipamentos", {}) is Dictionary else {}
	return {
		"nome": str(perfil.get("nome", "Aventureiro")).substr(0, 40),
		"nivel": clampi(int(perfil.get("nivel", 1)), 1, 1000000),
		"vida": clampi(int(perfil.get("vida", 0)), 0, 100000000),
		"vidaMaxima": clampi(int(perfil.get("vidaMaxima", 1)), 1, 100000000),
		"mana": clampi(int(perfil.get("mana", 0)), 0, 100000000),
		"manaMaxima": clampi(int(perfil.get("manaMaxima", 1)), 1, 100000000),
		"aparenciaId": str(perfil.get("aparenciaId", "")).substr(0, 80),
		"sexo": str(perfil.get("sexo", "masculino")).substr(0, 20),
		"racaId": str(perfil.get("racaId", "humano")).substr(0, 40),
		"classeId": str(perfil.get("classeId", "")).substr(0, 40),
		"anatomiaRacial": anatomia.duplicate(true),
		"equipamentos": equipamentos.duplicate(true)
	}

func _publicar_estado_sala(codigo: String) -> void:
	if codigo.is_empty():
		return
	var sala := _salas_publicas.obter_sala(codigo)
	if sala.is_empty():
		return
	var participantes: Array = []
	for membro in sala.get("jogadores", []):
		var perfil: Dictionary = _perfil_por_peer.get(int(membro), {})
		participantes.append({
			"nome": str(perfil.get("nome", "Aventureiro")).substr(0, 40),
			"anfitriao": int(membro) == int(sala.get("anfitriaoPeerId", -1)),
			"visual": _criar_perfil_visual_publico(perfil)
		})
	var estado_sala := {"codigo": codigo, "jogadores": (sala.get("jogadores", []) as Array).size(), "limite": SISTEMA_SALAS.MAXIMO_JOGADORES_POR_SALA, "anfitriaoPeerId": int(sala.get("anfitriaoPeerId", -1)), "participantes": participantes}
	for membro in sala.get("jogadores", []):
		rpc_id(int(membro), "_receber_sala_atualizada", estado_sala)

## Ponto de integração para missões e narrativas: somente o servidor chama após validar a progressão.
## Não exponha este método como RPC nem aceite estado arbitrário enviado pelo cliente.
func atualizar_aventura_da_sala(peer_id: int, novo_estado_validado: Dictionary, revisao_esperada: int = -1) -> Dictionary:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id):
		return {"sucesso": false, "erro": "Somente o servidor pode atualizar uma aventura autenticada."}
	var resultado: Dictionary = _salas_publicas.atualizar_estado_aventura(peer_id, novo_estado_validado, revisao_esperada)
	if not bool(resultado.get("sucesso", false)):
		# Em caso de conflito, devolve o snapshot atual apenas ao jogador que enviou a revisão antiga.
		if bool(resultado.get("conflito", false)):
			rpc_id(peer_id, "_receber_estado_aventura_sala", {
				"codigo": str(_salas_publicas.obter_sala_do_jogador(peer_id).get("codigo", "")),
				"mundoId": SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO,
				"revisao": int(resultado.get("revisaoAtual", 0)),
				"estado": resultado.get("estadoAtual", {}).duplicate(true)
			})
		return resultado
	_salvar_salas_persistentes()
	_publicar_estado_aventura_da_sala(peer_id)
	return resultado

## Inicia um encontro cooperativo usando exclusivamente uma criatura já catalogada no servidor.
## O gatilho de mundo deve chamar este método após validar o contexto; não é RPC do cliente.
func iniciar_encontro_cooperativo_servidor(peer_id: int, criatura_id: String) -> Dictionary:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		return {"sucesso": false, "erro": "Apenas um participante autenticado pode iniciar o fluxo do encontro."}
	var sala: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_id)
	var jogadores: Array = sala.get("jogadores", [])
	if sala.is_empty() or jogadores.size() < 2 or jogadores.size() > 4:
		return {"sucesso": false, "erro": "O encontro exige de dois a quatro jogadores ativos."}
	var id := criatura_id.strip_edges()
	if id.is_empty() or id.length() > 128:
		return {"sucesso": false, "erro": "Identificador de criatura inválido."}
	var criatura: Dictionary = _repositorio_criaturas.obter_criatura(id)
	if criatura.is_empty():
		return {"sucesso": false, "erro": "A criatura não existe no catálogo confiável do servidor."}
	var participantes: Array = []
	for membro_peer in jogadores:
		var membro_id := int(membro_peer)
		if not _uid_por_peer.has(membro_id) or not _perfil_por_peer.has(membro_id):
			return {"sucesso": false, "erro": "Todos os integrantes precisam estar autenticados e com perfil carregado."}
		var perfil: Dictionary = _perfil_por_peer[membro_id]
		var atributos := _atributos_efetivos_perfil(perfil)
		var ataque := maxi(int(atributos.get("forca", 5)), int(atributos.get("inteligencia", 5)))
		var arma_id := str(perfil.get("equipamentos", {}).get("mao_principal", ""))
		var arma: Dictionary = SistemaEquipamentos.obter(arma_id)
		ataque += maxi(0, int(arma.get("dano", 0)))
		participantes.append({
			"uid": str(_uid_por_peer[membro_id]),
			"nome": str(perfil.get("nome", "Aventureiro")).substr(0, 40),
			"vida": int(perfil.get("vida", atributos.get("vidaMaxima", 100))),
			"vidaMaxima": int(atributos.get("vidaMaxima", 100)),
			"ataque": ataque,
			"defesa": int(atributos.get("defesaEquipamento", 0)) + int(atributos.get("vitalidade", 5)) / 3,
			"agilidade": int(atributos.get("agilidade", 5))
		})
	var resultado: Dictionary = _salas_publicas.registrar_encontro(peer_id, criatura, participantes)
	if not bool(resultado.get("sucesso", false)):
		return resultado
	_salvar_salas_persistentes()
	_publicar_estado_aventura_da_sala(peer_id)
	return resultado

## Cliente envia somente uma das ações básicas; identidade e turno são conferidos pelo servidor.
func solicitar_acao_encontro_cooperativo(acao: String) -> void:
	if estado == EstadoConexao.SERVIDOR:
		_processar_acao_encontro_cooperativo(multiplayer.get_unique_id(), acao)
	elif estado == EstadoConexao.CONECTADO:
		_solicitar_acao_encontro_cooperativo.rpc_id(1, acao)

@rpc("any_peer", "call_remote", "reliable")
func _solicitar_acao_encontro_cooperativo(acao: String) -> void:
	if multiplayer.is_server():
		_processar_acao_encontro_cooperativo(multiplayer.get_remote_sender_id(), acao)

func _processar_acao_encontro_cooperativo(peer_id: int, acao: String) -> void:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id):
		return
	var agora := Time.get_ticks_msec()
	if not _registrar_acao_combate_se_permitida(peer_id, agora):
		return
	var semente := int(Time.get_ticks_usec()) ^ (peer_id * 104729)
	var resultado: Dictionary = _salas_publicas.executar_acao_encontro(peer_id, str(_uid_por_peer[peer_id]), acao, semente)
	if not bool(resultado.get("sucesso", false)):
		if peer_id == multiplayer.get_unique_id():
			erro_combate.emit(str(resultado.get("erro", "Ação recusada.")))
		else:
			rpc_id(peer_id, "_receber_erro_combate", str(resultado.get("erro", "Ação recusada.")))
		return
	_salvar_salas_persistentes()
	var sala_atual := _salas_publicas.obter_sala_do_jogador(peer_id)
	var estado_atual: Dictionary = sala_atual.get("estadoAventura", {})
	var encontro_atual: Dictionary = estado_atual.get("encontro", {})
	if str(encontro_atual.get("resultado", "")) == "vitoria" and not bool(encontro_atual.get("recompensasConcluidas", false)):
		if _conceder_recompensas_encontro_cooperativo(encontro_atual):
			encontro_atual["recompensasConcluidas"] = true
			estado_atual["encontro"] = encontro_atual
			var salvo_recompensas: Dictionary = _salas_publicas.atualizar_estado_aventura(peer_id, estado_atual, int(sala_atual.get("revisaoAventura", 0)))
			if bool(salvo_recompensas.get("sucesso", false)):
				_salvar_salas_persistentes()
			else:
				push_error("Recompensas concedidas, mas não foi possível marcar a conclusão na sala.")
		else:
			push_error("Recompensas cooperativas pendentes; os recibos individuais impedem duplicação em nova tentativa.")
	elif str(encontro_atual.get("resultado", "")) == "derrota" and not bool(encontro_atual.get("recursosDerrotaConcluidos", false)):
		if _processar_derrota_total_encontro_cooperativo(peer_id, encontro_atual):
			encontro_atual["recursosDerrotaConcluidos"] = true
			estado_atual["encontro"] = encontro_atual
			var salvo_derrota: Dictionary = _salas_publicas.atualizar_estado_aventura(peer_id, estado_atual, int(sala_atual.get("revisaoAventura", 0)))
			if bool(salvo_derrota.get("sucesso", false)):
				_salvar_salas_persistentes()
			else:
				push_error("Recursos restaurados, mas não foi possível registrar a conclusão da derrota.")
		else:
			push_error("A restauração após derrota total ficou pendente; será tentada novamente.")
	_publicar_estado_aventura_da_sala(peer_id)

## Distribui XP igualmente e entrega os drops ao maior causador de dano.
## Cada perfil registra o ID do encontro no mesmo salvamento que recebe os itens.
func _conceder_recompensas_encontro_cooperativo(encontro: Dictionary) -> bool:
	var combate: Dictionary = encontro.get("combate", {})
	var participantes: Array = combate.get("participantes", [])
	if str(combate.get("status", "")) != "vitoria" or participantes.size() < 2:
		return false
	var encontro_id := str(encontro.get("idRecompensa", "")).strip_edges()
	if encontro_id.is_empty():
		return false
	var criatura: Dictionary = encontro.get("dadosRecompensa", {})
	if criatura.is_empty():
		return false
	var xp_total := clampi(int(encontro.get("experienciaBase", criatura.get("experienciaBase", 0))), 0, 100000000)
	var distribuicao: Array = SistemaCombateCooperativo.calcular_distribuicao_recompensas(combate, xp_total)
	if distribuicao.size() != participantes.size():
		return false
	var indice_destaque := -1
	for i in range(distribuicao.size()):
		if bool(distribuicao[i].get("receberDrops", false)):
			indice_destaque = i
			break
	if indice_destaque < 0:
		return false
	var perfil_destaque: Dictionary = _repositorio_perfis.carregar_ou_criar(uid_destaque)
	if perfil_destaque.is_empty():
		return false
	var contexto := {"sorte":float(perfil_destaque.get("sorte", 0.0)), "periodo":str(_contexto_celeste_atual.get("periodo", "dia")), "nivelPerigo":int(criatura.get("perigo", 0))}
	var tabela: Array = criatura.get("tabelaDrops", []).duplicate(true) if criatura.get("tabelaDrops", []) is Array else []
	var moeda := SistemaDrops.criar_entrada_moeda_criatura(criatura, contexto)
	if not moeda.is_empty():
		tabela.append(moeda)
	if str(perfil_destaque.get("classeId", "")) != "invocador":
		var ovo := SistemaDrops.criar_entrada_ovo(criatura)
		if not ovo.is_empty():
			tabela.append(ovo)
	var rolagens: Array = SistemaDrops.resolver_tabela(tabela, str(criatura.get("id", "")), contexto)
	var drops_obtidos: Array = []
	for resultado_drop in rolagens:
		if bool(resultado_drop.get("obtido", false)):
			drops_obtidos.append(resultado_drop)
	for i in range(participantes.size()):
		var membro: Dictionary = participantes[i]
		var uid := str(membro.get("uid", ""))
		var perfil: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
		if perfil.is_empty():
			return false
		var vida_final := int(membro.get("vida", 0))
		var mana_final := int(perfil.get("mana", perfil.get("manaMaxima", 0)))
		var drops_entregues: Array = drops_obtidos if bool(distribuicao[i].get("receberDrops", false)) else []
		var xp_individual := int(distribuicao[i].get("experiencia", 0))
		var concessao: Dictionary = _repositorio_perfis.conceder_recompensa_encontro(uid, encontro_id, xp_individual, drops_entregues, vida_final, mana_final)
		if not bool(concessao.get("ok", false)):
			push_error("Falha ao conceder recompensa cooperativa para um participante.")
			return false
		for peer_atual in _uid_por_peer.keys():
			if str(_uid_por_peer[peer_atual]) == uid:
				_perfil_por_peer[int(peer_atual)] = concessao.get("perfil", perfil).duplicate(true)
				break
	# Atualiza os cartões visuais de todos os integrantes com os recursos recém-persistidos.
	# Sem esta publicação, o perfil no servidor estaria correto, mas a tela poderia exibir HP antigo.
	var sala_recompensada: Dictionary = {}
	# Procura qualquer integrante ainda conectado; o primeiro participante pode estar desconectado.
	for participante_sala in participantes:
		var uid_sala := str(participante_sala.get("uid", ""))
		for peer_sala in _uid_por_peer.keys():
			if str(_uid_por_peer[peer_sala]) == uid_sala:
				sala_recompensada = _salas_publicas.obter_sala_do_jogador(int(peer_sala))
				if not sala_recompensada.is_empty():
					break
		if not sala_recompensada.is_empty():
			break
	if not sala_recompensada.is_empty():
		_publicar_estado_sala(str(sala_recompensada.get("codigo", "")))
	return true

## Derrota total: restaura HP e Mana de todos, inclusive quem estava desconectado.
## O marcador da sala é gravado pelo chamador após todas as gravações individuais concluírem.
func _processar_derrota_total_encontro_cooperativo(peer_id: int, encontro: Dictionary) -> bool:
	var combate: Dictionary = encontro.get("combate", {})
	var participantes: Array = combate.get("participantes", [])
	if str(combate.get("status", "")) != "derrota" or participantes.size() < 2:
		return false
	var encontro_id := str(encontro.get("idRecompensa", "")).strip_edges()
	if encontro_id.is_empty():
		return false
	for membro in participantes:
		var uid := str(membro.get("uid", "")).strip_edges()
		if uid.is_empty():
			return false
		var penalidade: Dictionary = _repositorio_perfis.processar_derrota_cooperativa(uid, encontro_id)
		if not bool(penalidade.get("ok", false)):
			push_error("Não foi possível registrar a penalidade de derrota para um participante.")
			return false
		if not _repositorio_perfis.registrar_recursos_combate(uid, 0, 0, true):
			return false
		var perfil_atualizado: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
		if perfil_atualizado.is_empty():
			return false
		for peer_atual in _uid_por_peer.keys():
			if str(_uid_por_peer[peer_atual]) == uid:
				_perfil_por_peer[int(peer_atual)] = perfil_atualizado.duplicate(true)
				break
	var sala_derrota := _salas_publicas.obter_sala_do_jogador(peer_id)
	if not sala_derrota.is_empty():
		_publicar_estado_sala(str(sala_derrota.get("codigo", "")))
	return true

## Só deve ser chamado pelo resolvedor autoritativo após finalizar o encontro.
func limpar_encontro_cooperativo_servidor(peer_id: int) -> Dictionary:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id):
		return {"sucesso": false, "erro": "Apenas o servidor pode encerrar o encontro."}
	var resultado: Dictionary = _salas_publicas.limpar_encontro(peer_id)
	if bool(resultado.get("sucesso", false)):
		_salvar_salas_persistentes()
		_publicar_estado_aventura_da_sala(peer_id)
	return resultado

## Envia o snapshot exclusivamente aos integrantes registrados na mesma sala.
func _publicar_estado_aventura_da_sala(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sala := _salas_publicas.obter_sala_do_jogador(peer_id)
	if sala.is_empty():
		return
	var estado_aventura: Dictionary = _salas_publicas.obter_estado_aventura(peer_id)
	for membro in sala.get("jogadores", []):
		var membro_id := int(membro)
		var snapshot_publico: Dictionary = estado_aventura.duplicate(true)
		var estado_publico: Dictionary = snapshot_publico.get("estado", {}).duplicate(true)
		var encontro_publico: Dictionary = estado_publico.get("encontro", {}).duplicate(true)
		var combate_publico: Dictionary = encontro_publico.get("combate", {}).duplicate(true)
		if not combate_publico.is_empty():
			var integrantes_publicos: Array = []
			var integrantes_internos: Array = combate_publico.get("participantes", [])
			var indice_turno := int(combate_publico.get("indiceTurno", -1))
			var uid_turno := ""
			if indice_turno >= 0 and indice_turno < integrantes_internos.size():
				uid_turno = str(integrantes_internos[indice_turno].get("uid", ""))
			for integrante in integrantes_internos:
				var integrante_publico: Dictionary = integrante.duplicate(true)
				integrante_publico.erase("uid")
				integrantes_publicos.append(integrante_publico)
			combate_publico["participantes"] = integrantes_publicos
			combate_publico.erase("uidMaiorDano")
			combate_publico["turnoDoCliente"] = uid_turno == str(_uid_por_peer.get(membro_id, ""))
			encontro_publico["combate"] = combate_publico
			estado_publico["encontro"] = encontro_publico
			snapshot_publico["estado"] = estado_publico
		rpc_id(membro_id, "_receber_estado_aventura_sala", snapshot_publico)

@rpc("authority", "call_remote", "reliable")
func _receber_estado_aventura_sala(dados: Dictionary) -> void:
	if str(dados.get("mundoId", "")) != SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO:
		return
	estado_aventura_sala_atual = dados.duplicate(true)
	aventura_sala_atualizada.emit(estado_aventura_sala_atual.duplicate(true))

@rpc("authority", "call_remote", "reliable")
func _receber_sala_atualizada(dados: Dictionary) -> void:
	sala_atualizada.emit(dados.duplicate(true))

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

## A seleção é validada e persistida pelo servidor autenticado.
func solicitar_selecionar_invocacao(invocacao_id: String) -> void:
	if estado == EstadoConexao.CONECTADO and not invocacao_id.strip_edges().is_empty():
		_enviar_pedido_selecionar_invocacao.rpc_id(1, invocacao_id)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_pedido_selecionar_invocacao(invocacao_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id) or _combates_por_peer.has(peer_id):
		return
	if invocacao_id.strip_edges().is_empty() or invocacao_id.length() > 128:
		rpc_id(peer_id, "_receber_resultado_selecao_invocacao", false, "Identificação do companheiro inválida.")
		return
	var uid := str(_uid_por_peer[peer_id])
	var resultado: Dictionary = _repositorio_perfis.selecionar_invocacao(uid, invocacao_id)
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_resultado_selecao_invocacao", false, str(resultado.get("erro", "Não foi possível selecionar o companheiro.")))
		return
	var perfil_atualizado: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
	if perfil_atualizado.is_empty():
		rpc_id(peer_id, "_receber_resultado_selecao_invocacao", false, "Não foi possível atualizar o perfil.")
		return
	_perfil_por_peer[peer_id] = perfil_atualizado
	rpc_id(peer_id, "_receber_perfil_personagem", perfil_atualizado)
	rpc_id(peer_id, "_receber_resultado_selecao_invocacao", true, "Companheiro ativo atualizado!")

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_selecao_invocacao(sucesso: bool, mensagem: String) -> void:
	resultado_selecao_invocacao.emit(sucesso, mensagem)

## O cliente informa apenas o identificador do ovo; o servidor verifica posse e classe.
func solicitar_chocar_ovo(item_id: String) -> void:
	if estado == EstadoConexao.CONECTADO and not item_id.strip_edges().is_empty():
		_enviar_pedido_chocar_ovo.rpc_id(1, item_id)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_pedido_chocar_ovo(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		return
	if item_id.strip_edges().is_empty() or item_id.length() > 128:
		rpc_id(peer_id, "_receber_resultado_ovo_chocado", false, "Identificação de ovo inválida.", {})
		return
	var uid := str(_uid_por_peer[peer_id])
	var resultado := _repositorio_perfis.chocar_ovo(uid, item_id)
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_resultado_ovo_chocado", false, str(resultado.get("erro", "Não foi possível chocar o ovo.")), {})
		return
	var perfil_atualizado: Dictionary = resultado.get("perfil", {})
	if perfil_atualizado.is_empty():
		rpc_id(peer_id, "_receber_resultado_ovo_chocado", false, "Perfil atualizado indisponível.", {})
		return
	_perfil_por_peer[peer_id] = perfil_atualizado
	rpc_id(peer_id, "_receber_perfil_personagem", perfil_atualizado)
	rpc_id(peer_id, "_receber_resultado_ovo_chocado", true, str(resultado.get("mensagem", "O ovo chocou!")), resultado.get("invocacao", {}))

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_ovo_chocado(sucesso: bool, mensagem: String, invocacao: Dictionary) -> void:
	resultado_ovo_chocado.emit(sucesso, mensagem, invocacao.duplicate(true))

## O cliente solicita a tentativa; a criatura e os atributos são escolhidos pelo servidor.
func solicitar_domesticar_criatura_proxima() -> void:
	if estado == EstadoConexao.CONECTADO:
		_enviar_pedido_domesticacao.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_pedido_domesticacao() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		return
	if str(_perfil_por_peer[peer_id].get("classeId", "")) != "invocador":
		rpc_id(peer_id, "_receber_resultado_domesticacao", false, "Somente a classe Invocador pode domesticar. Para as demais classes, use ovos.", {})
		return
	if not _jogadores_no_mundo.has(peer_id) or _combates_por_peer.has(peer_id):
		rpc_id(peer_id, "_receber_resultado_domesticacao", false, "Não é possível domesticar durante um combate.", {})
		return
	var posicao_jogador: Vector2 = _jogadores_no_mundo[peer_id]
	var menor_distancia := 85.0
	var criatura_escolhida: Dictionary = {}
	var grupo_escolhido_id := ""
	var individuo_escolhido_id := ""
	for grupo_id in _grupos_mundo_cache.keys():
		var grupo: Dictionary = _grupos_mundo_cache[grupo_id]
		var especie_id := str(grupo.get("especieId", ""))
		if especie_id.is_empty():
			continue
		for individuo in grupo.get("individuos", []):
			# Somente indivíduos derrotados diretamente por jogadores podem ser domesticados.
			if bool(individuo.get("vivo", true)) or not bool(individuo.get("derrotadoEmCombate", false)):
				continue
			var p: Dictionary = individuo.get("posicaoMundo", {})
			var pos_criatura := Vector2(float(p.get("x", -10000.0)), float(p.get("y", -10000.0)))
			var distancia := posicao_jogador.distance_to(pos_criatura)
			if distancia >= menor_distancia:
				continue
			var catalogada := _repositorio_criaturas.obter_criatura(especie_id)
			if catalogada.is_empty():
				continue
			menor_distancia = distancia
			criatura_escolhida = catalogada.duplicate(true)
			grupo_escolhido_id = str(grupo_id)
			individuo_escolhido_id = str(individuo.get("individuoId", ""))
	if criatura_escolhida.is_empty():
		rpc_id(peer_id, "_receber_resultado_domesticacao", false, "Derrote uma criatura primeiro e aproxime-se do corpo para tentar domesticá-la.", {})
		return
	criatura_escolhida["derrotadoEmCombate"] = true
	criatura_escolhida["individuoId"] = individuo_escolhido_id
	var uid := str(_uid_por_peer[peer_id])
	var tentativa := _repositorio_perfis.registrar_tentativa_domesticacao(uid, individuo_escolhido_id)
	if not bool(tentativa.get("ok", false)):
		rpc_id(peer_id, "_receber_resultado_domesticacao", false, str(tentativa.get("erro", "Não foi possível tentar domesticar.")), {})
		return
	_perfil_por_peer[peer_id] = tentativa.get("perfil", _perfil_por_peer[peer_id]).duplicate(true)
	var chance := SISTEMA_INVOCACOES.calcular_chance_domesticacao(criatura_escolhida)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() > chance:
		var restantes := int(tentativa.get("restantes", 0))
		var texto_restantes := "Você ainda tem %d tentativa(s)." % restantes if restantes > 0 else "Suas 3 tentativas acabaram para essa criatura."
		rpc_id(peer_id, "_receber_resultado_domesticacao", false, "A criatura resistiu. Chance: %d%%. %s" % [int(round(chance * 100.0)), texto_restantes], {})
		return
	var resultado: Dictionary = _repositorio_perfis.registrar_domesticacao(uid, criatura_escolhida)
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_resultado_domesticacao", false, str(resultado.get("erro", "Não foi possível domesticar a criatura.")), {})
		return
	var saida := _repositorio_grupos.registrar_domesticacao_individuo(grupo_escolhido_id, individuo_escolhido_id)
	if not bool(saida.get("ok", false)):
		rpc_id(peer_id, "_receber_resultado_domesticacao", false, str(saida.get("erro", "Não foi possível retirar a criatura do grupo.")), {})
		return
	_grupos_mundo_cache[grupo_escolhido_id] = saida.get("grupo", {})
	var perfil_atualizado: Dictionary = resultado.get("perfil", {})
	if not perfil_atualizado.is_empty():
		_perfil_por_peer[peer_id] = perfil_atualizado
		rpc_id(peer_id, "_receber_perfil_personagem", perfil_atualizado)
	rpc("_receber_grupos_selvagens", _lista_visual_individuos_grupos())
	rpc_id(peer_id, "_receber_resultado_domesticacao", true, "Domesticação concluída! Chance aplicada: %d%%." % int(round(chance * 100.0)), resultado.get("invocacao", {}))

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_domesticacao(sucesso: bool, mensagem: String, invocacao: Dictionary) -> void:
	resultado_domesticacao.emit(sucesso, mensagem, invocacao.duplicate(true))

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

func solicitar_descanso_clareira() -> void:
	if estado == EstadoConexao.SERVIDOR:
		_processar_descanso_clareira(multiplayer.get_unique_id())
	elif estado == EstadoConexao.CONECTADO:
		solicitar_descanso_clareira_servidor.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func solicitar_descanso_clareira_servidor() -> void:
	if not multiplayer.is_server():
		return
	_processar_descanso_clareira(multiplayer.get_remote_sender_id())

func _processar_descanso_clareira(peer_id: int) -> void:
	if peer_id <= 0 or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id):
		_enviar_resultado_descanso_clareira(peer_id, false, "Não foi possível identificar seu personagem.")
		return
	if _combates_por_peer.has(peer_id):
		_enviar_resultado_descanso_clareira(peer_id, false, "Você não pode descansar durante um combate.")
		return
	var posicao: Vector2 = _jogadores_no_mundo[peer_id]
	var pontos_descanso := [Vector2(1190.0, 1543.0), Vector2(1096.0, 1485.0)]
	var esta_perto_de_local_seguro := false
	for ponto_descanso in pontos_descanso:
		if posicao.distance_to(ponto_descanso) <= 82.0:
			esta_perto_de_local_seguro = true
			break
	if not esta_perto_de_local_seguro:
		_enviar_resultado_descanso_clareira(peer_id, false, "Aproxime-se da fogueira ou do Abrigo do Viajante.")
		return
	var agora := Time.get_ticks_msec()
	var ultimo_descanso := int(_ultimo_descanso_clareira_ms.get(peer_id, -60000))
	if agora - ultimo_descanso < 60000:
		var restante := ceili(float(60000 - (agora - ultimo_descanso)) / 1000.0)
		_enviar_resultado_descanso_clareira(peer_id, false, "A fogueira precisa de mais %d s para aquecer novamente." % restante)
		return
	var uid := str(_uid_por_peer[peer_id])
	# Atualiza a revisão antes de gravar: o perfil em memória pode estar desatualizado
	# se outra operação (combate, equipamento ou inventário) salvou depois dele.
	var perfil: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		_enviar_resultado_descanso_clareira(peer_id, false, "Não foi possível carregar seu personagem para descansar.")
		return
	# Preserva a posição mais recente validada pelo servidor, sem restaurar uma posição antiga do disco.
	var posicao_validada: Vector2 = _jogadores_no_mundo[peer_id]
	perfil["x"] = posicao_validada.x
	perfil["y"] = posicao_validada.y
	var atributos_base := {
		"forca": int(perfil.get("forca", 5)),
		"inteligencia": int(perfil.get("inteligencia", 5)),
		"agilidade": int(perfil.get("agilidade", 5)),
		"vitalidade": int(perfil.get("vitalidade", 5)),
		"espirito": int(perfil.get("espirito", 5)),
		"vidaMaxima": int(perfil.get("vidaMaxima", 100)),
		"manaMaxima": int(perfil.get("manaMaxima", 50))
	}
	var atributos_efetivos := SistemaEquipamentos.calcular_atributos_efetivos(atributos_base, perfil.get("equipamentos", {}))
	perfil["vida"] = int(atributos_efetivos.get("vidaMaxima", atributos_base["vidaMaxima"]))
	perfil["mana"] = int(atributos_efetivos.get("manaMaxima", atributos_base["manaMaxima"]))
	if not _repositorio_perfis.salvar(uid, perfil):
		_enviar_resultado_descanso_clareira(peer_id, false, "Não foi possível registrar seu descanso. Tente novamente.")
		return
	_perfil_por_peer[peer_id] = perfil
	_ultima_gravacao_ms[peer_id] = agora
	_ultimo_descanso_clareira_ms[peer_id] = agora
	_enviar_resultado_descanso_clareira(peer_id, true, "Você descansou. Vida e mana foram restauradas.")

func _enviar_resultado_descanso_clareira(peer_id: int, sucesso: bool, mensagem: String) -> void:
	if multiplayer.is_server() and peer_id == multiplayer.get_unique_id():
		_receber_resultado_descanso_clareira(sucesso, mensagem, _perfil_por_peer.get(peer_id, {}))
	elif peer_id > 0:
		rpc_id(peer_id, "_receber_resultado_descanso_clareira", sucesso, mensagem, _perfil_por_peer.get(peer_id, {}))

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_descanso_clareira(sucesso: bool, mensagem: String, perfil: Dictionary) -> void:
	if sucesso and not perfil.is_empty():
		perfil_personagem_atual = perfil.duplicate(true)
		perfil_personagem_recebido.emit(perfil_personagem_atual)
	resultado_descanso_clareira.emit(sucesso, mensagem)

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
	var perfil_movimento: Dictionary = _perfil_por_peer.get(id_jogador, {})
	var atributos_movimento := _atributos_efetivos_perfil(perfil_movimento)
	var velocidade_autorizada := VELOCIDADE_BASE_JOGADOR * (float(atributos_movimento.get("velocidadePercentual", 100)) / 100.0)
	if not SISTEMA_VALIDACAO_MOVIMENTO.posicao_valida(posicao_anterior, posicao_solicitada, decorrido_ms, velocidade_autorizada) or not SISTEMA_COLISOES_MUNDO.trajeto_valido(posicao_anterior, posicao_solicitada, false, _estado_serpente_mundo.get("zonaDevastada", {}), SISTEMA_SERPENTE_MUNDO.obter_marcas_destruicao_ativas(_estado_serpente_mundo, int(Time.get_unix_time_from_system()))):
		rpc_id(id_jogador, "_receber_posicao_jogador", id_jogador, posicao_anterior)
		return
	_jogadores_no_mundo[id_jogador] = posicao_solicitada
	_registrar_visita_local_confirmada(id_jogador, posicao_solicitada)
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


## Conversão manual: o servidor confere saldo e identidade autenticada.
func solicitar_converter_moedas(denominacao: String, quantidade: int) -> void:
	if estado == EstadoConexao.CONECTADO and quantidade >= 100 and quantidade % 100 == 0:
		_enviar_pedido_converter_moedas.rpc_id(1, denominacao, quantidade)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_pedido_converter_moedas(denominacao: String, quantidade: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id) or _combates_por_peer.has(peer_id):
		return
	if quantidade < 100 or quantidade > 2000000000 or quantidade % 100 != 0:
		rpc_id(peer_id, "_receber_resultado_conversao_moedas", false, "Quantidade inválida para conversão.")
		return
	var uid := str(_uid_por_peer[peer_id])
	var resultado: Dictionary = _repositorio_perfis.converter_moedas(uid, denominacao, quantidade)
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_resultado_conversao_moedas", false, str(resultado.get("erro", "Conversão recusada.")))
		return
	var perfil: Dictionary = resultado.get("perfil", {})
	if perfil.is_empty():
		perfil = _repositorio_perfis.carregar_ou_criar(uid)
	if perfil.is_empty():
		rpc_id(peer_id, "_receber_resultado_conversao_moedas", false, "Não foi possível atualizar a carteira.")
		return
	_perfil_por_peer[peer_id] = perfil
	rpc_id(peer_id, "_receber_perfil_personagem", perfil)
	var mensagem := "%d moedas de %s convertidas em %d de %s." % [quantidade, str(resultado.get("origem", denominacao)).capitalize(), int(resultado.get("quantidadeRecebida", 0)), str(resultado.get("destino", "")).capitalize()]
	rpc_id(peer_id, "_receber_resultado_conversao_moedas", true, mensagem)

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_conversao_moedas(sucesso: bool, mensagem: String) -> void:
	resultado_conversao_moedas.emit(sucesso, mensagem)
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
	_ecossistema_id: String = "",
	_bioma: String = "",
	_perigo: int = 0,
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
	# O ambiente, perigo e período são sempre calculados pelo servidor.
	var contexto_ambiente := SISTEMA_AMBIENTES_MUNDO.obter_contexto(_jogadores_no_mundo[peer_id])
	if contexto_ambiente.is_empty():
		return false
	var ecossistema_id := str(contexto_ambiente.get("ecossistemaId", ""))
	var bioma := str(contexto_ambiente.get("bioma", ""))
	var perigo_autoritativo := clampi(int(contexto_ambiente.get("perigoBase", 0)), 0, 100)
	if ecossistema_id not in REPOSITORIO_CRIATURAS.ECOSSISTEMAS or bioma.is_empty():
		return false
	var periodo := str(_contexto_celeste_atual.get("periodo", "indefinido"))
	if periodo == "indefinido" or periodo.is_empty():
		_contexto_celeste_atual = _obter_contexto_celeste_servidor()
		periodo = str(_contexto_celeste_atual.get("periodo", "indefinido"))
	if periodo == "indefinido" or periodo.is_empty():
		return false
	var agora_ms := Time.get_ticks_msec()
	var ultimo_ms := int(_ultimo_encontro_ms.get(peer_id, 0))
	if ultimo_ms > 0 and agora_ms - ultimo_ms < INTERVALO_MINIMO_ENCONTROS_MS:
		return false
	var catalogo := _repositorio_criaturas.listar_criaturas_do_ecossistema(ecossistema_id)
	var semente := int(Time.get_ticks_usec()) ^ (peer_id * 7919)
	var posicao_encontro: Vector2 = _jogadores_no_mundo[peer_id]
	var marcas_ativas := SISTEMA_SERPENTE_MUNDO.obter_marcas_destruicao_ativas(_estado_serpente_mundo, int(Time.get_unix_time_from_system()))
	var criatura := SISTEMA_SELECAO_ENCONTROS.selecionar(
		catalogo, ecossistema_id, bioma, perigo_autoritativo, permitir_chefe, semente, periodo,
		posicao_encontro, marcas_ativas, int(Time.get_unix_time_from_system())
	)
	if criatura.is_empty():
		return false
	if not iniciar_combate_servidor(peer_id, criatura):
		return false
	_ultimo_encontro_ms[peer_id] = agora_ms
	return true


## Procura um indivíduo real de um grupo selvagem próximo e inicia o encontro.
## Ecossistema e bioma vêm do contexto validado pelo servidor, nunca do cliente.
func tentar_iniciar_encontro_grupo_servidor(
	peer_id: int,
	_ecossistema_id: String = "",
	_bioma: String = "",
	distancia_maxima: float = 72.0
) -> bool:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id):
		return false
	if not _perfil_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id):
		return false
	if _combates_por_peer.has(peer_id) or distancia_maxima <= 0.0 or distancia_maxima > 150.0:
		return false
	var posicao_jogador: Vector2 = _jogadores_no_mundo[peer_id]
	var contexto_jogador := SISTEMA_AMBIENTES_MUNDO.obter_contexto(posicao_jogador)
	if contexto_jogador.is_empty():
		return false
	var ecossistema_id := str(contexto_jogador.get("ecossistemaId", ""))
	var bioma := str(contexto_jogador.get("bioma", ""))
	if ecossistema_id.is_empty() or bioma.is_empty():
		return false
	var agora_ms := Time.get_ticks_msec()
	var ultimo_ms := int(_ultimo_encontro_ms.get(peer_id, 0))
	if ultimo_ms > 0 and agora_ms - ultimo_ms < INTERVALO_MINIMO_ENCONTROS_MS:
		return false
	var melhor_grupo: Dictionary = {}
	var menor_distancia := distancia_maxima
	for grupo in _grupos_mundo_cache.values():
		if str(grupo.get("ecossistemaId", "")) != ecossistema_id or str(grupo.get("bioma", "")) != bioma:
			continue
		var candidatos_grupo: Array = []
		for individuo in grupo.get("individuos", []):
			if not bool(individuo.get("vivo", false)):
				continue
			var dados_posicao: Dictionary = individuo.get("posicaoMundo", {})
			var posicao := Vector2(float(dados_posicao.get("x", -10000.0)), float(dados_posicao.get("y", -10000.0)))
			var contexto_individuo := SISTEMA_AMBIENTES_MUNDO.obter_contexto(posicao)
			if contexto_individuo.is_empty():
				continue
			if str(contexto_individuo.get("ecossistemaId", "")) != ecossistema_id or str(contexto_individuo.get("bioma", "")) != bioma:
				continue
			var distancia := posicao_jogador.distance_to(posicao)
			if distancia <= distancia_maxima:
				candidatos_grupo.append({"individuo":individuo.duplicate(true),"distancia":distancia})
		if candidatos_grupo.is_empty():
			continue
		candidatos_grupo.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("distancia", INF)) < float(b.get("distancia", INF)))
		var distancia_grupo := float(candidatos_grupo[0].get("distancia", INF))
		if distancia_grupo < menor_distancia:
			menor_distancia = distancia_grupo
			melhor_grupo = {"grupo":grupo.duplicate(true),"individuos":candidatos_grupo.slice(0, 3)}
	if melhor_grupo.is_empty():
		return false
	var encontros: Array = []
	var grupo_encontrado: Dictionary = melhor_grupo.get("grupo", {})
	var especie_id := str(grupo_encontrado.get("especieId", ""))
	var especie := _repositorio_criaturas.obter_criatura(especie_id)
	if especie.is_empty():
		return false
	for candidato in melhor_grupo.get("individuos", []):
		var individuo: Dictionary = candidato.get("individuo", {})
		var encontro := especie.duplicate(true)
		encontro["especieId"] = especie_id
		encontro["grupoId"] = str(grupo_encontrado.get("grupoId", ""))
		encontro["individuoId"] = str(individuo.get("individuoId", ""))
		encontro["liderNato"] = bool(individuo.get("liderNato", false))
		encontro["atributos"] = individuo.get("atributos", {}).duplicate(true)
		encontros.append(encontro)
	return iniciar_combate_grupo_servidor(peer_id, encontros)

## Inicia uma batalha com até três indivíduos reais do mesmo grupo ecológico.
func iniciar_combate_grupo_servidor(peer_id: int, criaturas_servidor: Array) -> bool:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		return false
	if _combates_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id) or criaturas_servidor.is_empty() or criaturas_servidor.size() > 3:
		return false
	var contexto_ciclo := _obter_contexto_celeste_servidor()
	var criaturas_catalogadas: Array = []
	var primeira_criatura: Dictionary = {}
	for criatura_servidor in criaturas_servidor:
		if not (criatura_servidor is Dictionary):
			return false
		var criatura_id := str(criatura_servidor.get("id", criatura_servidor.get("especieId", "")))
		if criatura_id.is_empty():
			return false
		var catalogada := _repositorio_criaturas.obter_criatura(criatura_id)
		if catalogada.is_empty():
			return false
		var criatura_combate: Dictionary = catalogada.duplicate(true)
		var atributos_individuo: Dictionary = criatura_servidor.get("atributos", {})
		for atributo in ["vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"]:
			if atributos_individuo.has(atributo):
				criatura_combate[atributo] = int(atributos_individuo[atributo])
		criatura_combate["grupoId"] = str(criatura_servidor.get("grupoId", ""))
		criatura_combate["individuoId"] = str(criatura_servidor.get("individuoId", ""))
		criatura_combate["liderNato"] = bool(criatura_servidor.get("liderNato", false))
		if not SISTEMA_CICLO_NOTURNO.criatura_disponivel(criatura_combate, str(contexto_ciclo.get("periodo", "dia"))):
			return false
		criaturas_catalogadas.append(criatura_combate)
		if primeira_criatura.is_empty():
			primeira_criatura = catalogada
	var perfil: Dictionary = _perfil_por_peer[peer_id]
	var estado_inicial := SistemaCombate.criar_estado_grupo(perfil, criaturas_catalogadas, contexto_ciclo)
	if estado_inicial.is_empty():
		return false
	var uid := str(_uid_por_peer[peer_id])
	for criatura in criaturas_catalogadas:
		var descoberta := _repositorio_criaturas.registrar_descoberta(uid, str(criatura.get("id", "")))
		if not bool(descoberta.get("ok", false)):
			return false
	_combates_por_peer[peer_id] = {"estado":estado_inicial,"criatura":primeira_criatura,"criaturas":criaturas_catalogadas}
	rpc_id(peer_id, "_receber_estado_combate", estado_inicial)
	return true

func iniciar_combate_servidor(peer_id: int, criatura_servidor: Dictionary) -> bool:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		return false
	if _combates_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id):
		return false
	var criatura_id := str(criatura_servidor.get("id", criatura_servidor.get("especieId", "")))
	if criatura_id.is_empty():
		return false
	# A espécie e a tabela de loot vêm do catálogo persistido do servidor.
	# Se o encontro veio de um indivíduo selvagem, preservamos somente os
	# atributos/traços daquele indivíduo, nunca dados enviados por RPC do cliente.
	var criatura_catalogada := _repositorio_criaturas.obter_criatura(criatura_id)
	if criatura_catalogada.is_empty():
		var registro := _repositorio_criaturas.registrar_criatura_gerada(criatura_servidor)
		if not bool(registro.get("ok", false)):
			return false
		criatura_catalogada = _repositorio_criaturas.obter_criatura(criatura_id)
	if criatura_catalogada.is_empty():
		return false
	var criatura_combate: Dictionary = criatura_catalogada.duplicate(true)
	if criatura_servidor.has("liderNato"):
		criatura_combate["liderNato"] = bool(criatura_servidor.get("liderNato", false))
	var atributos_individuo: Dictionary = criatura_servidor.get("atributos", {})
	for atributo in ["vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"]:
		if atributos_individuo.has(atributo):
			criatura_combate[atributo] = int(atributos_individuo[atributo])
	var perfil: Dictionary = _perfil_por_peer[peer_id]
	# O combate usa exatamente o mesmo relógio acelerado, dia e fenômeno do mundo compartilhado.
	var contexto_ciclo := _obter_contexto_celeste_servidor()
	if not SISTEMA_CICLO_NOTURNO.criatura_disponivel(criatura_combate, str(contexto_ciclo.get("periodo", "dia"))):
		return false
	var estado_inicial := SistemaCombate.criar_estado(perfil, criatura_combate, contexto_ciclo)
	if estado_inicial.is_empty():
		return false
	var uid := str(_uid_por_peer[peer_id])
	var descoberta := _repositorio_criaturas.registrar_descoberta(uid, criatura_id)
	if not bool(descoberta.get("ok", false)):
		return false
	_combates_por_peer[peer_id] = {"estado":estado_inicial,"criatura":criatura_combate}
	rpc_id(peer_id, "_receber_estado_combate", estado_inicial)
	return true

## Incursão mundial: o cliente envia apenas intenção; posição, identidade, dano e recompensa são verificados no servidor.
func solicitar_entrar_incursao_serpente() -> void:
	if estado == EstadoConexao.CONECTADO:
		_enviar_entrada_incursao_serpente.rpc_id(1)

func solicitar_ataque_serpente(acao: String = "ataque") -> void:
	if estado == EstadoConexao.CONECTADO:
		_enviar_ataque_serpente.rpc_id(1, acao)

func solicitar_filhote_serpente() -> void:
	if estado == EstadoConexao.CONECTADO:
		_enviar_tentativa_filhote_serpente.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_entrada_incursao_serpente() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id):
		return
	var uid := str(_uid_por_peer[peer_id])
	var posicao: Vector2 = _jogadores_no_mundo[peer_id]
	if _estado_serpente_mundo.is_empty():
		_estado_serpente_mundo = SISTEMA_SERPENTE_MUNDO.criar_estado()
	var resultado := SISTEMA_SERPENTE_MUNDO.entrar(_estado_serpente_mundo, uid, peer_id, posicao, POSICAO_CABECA_SERPENTE)
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_erro_combate", str(resultado.get("erro", "Não foi possível entrar na incursão.")))
		return
	_estado_serpente_mundo = resultado.estado
	_salvar_estado_serpente_mundo()
	_publicar_estado_serpente_mundo()

@rpc("any_peer", "call_remote", "reliable")
func _enviar_ataque_serpente(acao: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id):
		return
	var uid := str(_uid_por_peer[peer_id])
	var posicao: Vector2 = _jogadores_no_mundo[peer_id]
	if posicao.distance_to(POSICAO_CABECA_SERPENTE) > SISTEMA_SERPENTE_MUNDO.RAIO_ARENA:
		rpc_id(peer_id, "_receber_erro_combate", "Você precisa estar perto da cabeça da Serpente para atacar.")
		return
	var perfil: Dictionary = _perfil_por_peer[peer_id]
	if acao != "ataque" and acao != "magia":
		rpc_id(peer_id, "_receber_erro_combate", "Ação inválida contra a Serpente.")
		return
	var participantes: Dictionary = _estado_serpente_mundo.get("participantes", {})
	if not participantes.has(uid) or int(participantes[uid].get("peerId", -1)) != peer_id or not bool(participantes[uid].get("ativo", false)):
		rpc_id(peer_id, "_receber_erro_combate", "Entre na incursão antes de atacar.")
		return
	var ultima_acao := int(participantes[uid].get("ultimaAcaoMs", -SISTEMA_SERPENTE_MUNDO.INTERVALO_ACAO_MS))
	if Time.get_ticks_msec() - ultima_acao < SISTEMA_SERPENTE_MUNDO.INTERVALO_ACAO_MS:
		rpc_id(peer_id, "_receber_erro_combate", "Aguarde antes de atacar novamente.")
		return
	var perfil_dano := _atributos_efetivos_perfil(perfil)
	if acao == "magia" and int(perfil.get("mana", 0)) < CUSTO_MAGIA_SERPENTE:
		rpc_id(peer_id, "_receber_erro_combate", "Mana insuficiente. São necessários 10 pontos.")
		return
	var resultado := SISTEMA_SERPENTE_MUNDO.aplicar_ataque(_estado_serpente_mundo, uid, peer_id, perfil_dano, acao, Time.get_ticks_msec())
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_erro_combate", str(resultado.get("erro", "Ataque recusado.")))
		return
	if acao == "magia":
		perfil["mana"] = int(perfil.get("mana", 0)) - CUSTO_MAGIA_SERPENTE
		if not _repositorio_perfis.salvar(uid, perfil):
			rpc_id(peer_id, "_receber_erro_combate", "Não foi possível registrar o custo de mana; o ataque foi cancelado.")
			return
		_perfil_por_peer[peer_id] = perfil
		rpc_id(peer_id, "_receber_perfil_personagem", perfil)
	_estado_serpente_mundo = resultado.estado
	_salvar_estado_serpente_mundo()
	_publicar_estado_serpente_mundo()
	if bool(resultado.get("derrotada", false)):
		rpc("_receber_estado_serpente_mundo", SISTEMA_SERPENTE_MUNDO.obter_estado_publico(_estado_serpente_mundo))

@rpc("any_peer", "call_remote", "reliable")
func _enviar_tentativa_filhote_serpente() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id):
		return
	var uid := str(_uid_por_peer[peer_id])
	if not _perfil_por_peer.has(peer_id):
		rpc_id(peer_id, "_receber_resultado_filhote_serpente", false, "Perfil do personagem indisponível.", {})
		return
	var perfil_dono: Dictionary = _perfil_por_peer[peer_id]
	if str(perfil_dono.get("classeId", "")) != "invocador":
		rpc_id(peer_id, "_receber_resultado_filhote_serpente", false, "Somente a classe Invocador pode domesticar a Serpente do Mundo. As demais classes usam ovos.", {})
		return
	for invocacao_existente in perfil_dono.get("invocacoes", []):
		if str(invocacao_existente.get("origem", "")) == "filhote_serpente_mundo" or str(invocacao_existente.get("tipoInvocacao", "")) == "serpente_mundo":
			rpc_id(peer_id, "_receber_resultado_filhote_serpente", false, "Você já possui uma Serpente Filhote Primordial.", {})
			return
	var tentativa := SISTEMA_SERPENTE_MUNDO.registrar_tentativa_filhote(_estado_serpente_mundo, uid)
	if not bool(tentativa.get("ok", false)):
		rpc_id(peer_id, "_receber_resultado_filhote_serpente", false, str(tentativa.get("erro", "Tentativa indisponível.")), {})
		return
	_estado_serpente_mundo = tentativa.estado
	_salvar_estado_serpente_mundo()
	var criatura_derrotada := {
		"id": SISTEMA_SERPENTE_MUNDO.ID_CHEFE,
		"tipoChefeMundo": "serpente_mundo",
		"nome": "Serpente do Mundo",
		"rank": "SSS",
		"raridade": "unico",
		"chefe": true,
		"derrotadoEmCombate": true,
		"vidaMaxima": 2000000,
		"ataque": 5000,
		"defesa": 3000,
		"agilidade": 800,
		"poderMagico": 1200
	}
	var chance := SISTEMA_INVOCACOES.calcular_chance_domesticacao(criatura_derrotada)
	if randf() >= chance:
		var restantes := int(tentativa.get("restantes", 0))
		rpc_id(peer_id, "_receber_resultado_filhote_serpente", false, "A serpente filhote não aceitou o vínculo. Chance: %.1f%%. Tentativas restantes: %d." % [chance * 100.0, restantes], {})
		return
	var resultado := _repositorio_perfis.registrar_domesticacao(uid, criatura_derrotada)
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_resultado_filhote_serpente", false, str(resultado.get("erro", "Não foi possível salvar o filhote.")), {})
		return
	var perfil_atualizado: Dictionary = resultado.get("perfil", {})
	if not perfil_atualizado.is_empty():
		_perfil_por_peer[peer_id] = perfil_atualizado
		rpc_id(peer_id, "_receber_perfil_personagem", perfil_atualizado)
	rpc_id(peer_id, "_receber_resultado_filhote_serpente", true, "A Serpente Filhote Primordial reconheceu você! Ela está na sua coleção de invocações.", resultado.get("invocacao", {}))

func solicitar_defesa_serpente(acao: String) -> void:
	if estado == EstadoConexao.CONECTADO and acao in ["defender", "esquivar"]:
		_enviar_defesa_serpente.rpc_id(1, acao)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_defesa_serpente(acao: String) -> void:
	if not multiplayer.is_server() or acao not in ["defender", "esquivar"]:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id):
		return
	var uid := str(_uid_por_peer[peer_id])
	if not _estado_serpente_mundo.has("ataquePreparando"):
		rpc_id(peer_id, "_receber_erro_combate", "A serpente ainda não anunciou um ataque.")
		return
	var defesas: Dictionary = _estado_serpente_mundo.get("defesasPreparadas", {})
	defesas[uid] = acao
	_estado_serpente_mundo["defesasPreparadas"] = defesas
	_salvar_estado_serpente_mundo()

func _aplicar_fuga_fauna_sopro(zona: Dictionary, agora_unix: int) -> void:
	var centro := Vector2(float(zona.get("x", 0.0)), float(zona.get("y", 0.0)))
	var raio := clampf(float(zona.get("raio", 0.0)), 0.0, 2000.0)
	if raio <= 0.0:
		return
	var houve_migracao := false
	for grupo_id_var in _grupos_mundo_cache.keys():
		var grupo_id := str(grupo_id_var)
		var resultado := _repositorio_grupos.fugir_da_devastacao(grupo_id, centro, raio, agora_unix)
		if not bool(resultado.get("ok", false)):
			push_warning("A fauna não conseguiu avaliar a fuga de " + grupo_id + ": " + str(resultado.get("erro", "")))
			continue
		if bool(resultado.get("fugiu", false)):
			_grupos_mundo_cache[grupo_id] = resultado.get("grupo", {})
			var perseguicao := _repositorio_grupos.registrar_perseguicao_de_fauna_migrante(grupo_id, agora_unix)
			if bool(perseguicao.get("ok", false)):
				for grupo_predador in perseguicao.get("perseguidores", []):
					var id_predador := str(grupo_predador.get("grupoId", ""))
					if not id_predador.is_empty():
						_grupos_mundo_cache[id_predador] = grupo_predador
			else:
				push_warning("Não foi possível registrar predadores rastreando " + grupo_id + ": " + str(perseguicao.get("erro", "")))
			houve_migracao = true
	if houve_migracao:
		rpc("_receber_grupos_selvagens", _lista_visual_individuos_grupos())


func _atualizar_incursao_serpente(agora_ms: int) -> void:
	if _estado_serpente_mundo.is_empty():
		return
	var renascido := SISTEMA_SERPENTE_MUNDO.verificar_renascimento(_estado_serpente_mundo, int(Time.get_unix_time_from_system()))
	if renascido != _estado_serpente_mundo:
		_estado_serpente_mundo = renascido
		_ultimo_ataque_serpente_ms = agora_ms
		_salvar_estado_serpente_mundo()
		_publicar_estado_serpente_mundo()
		return
	if str(_estado_serpente_mundo.get("status", "")) != SISTEMA_SERPENTE_MUNDO.STATUS_EM_COMBATE:
		return
	var agora_unix := int(Time.get_unix_time_from_system())
	if not _estado_serpente_mundo.has("ataquePreparando"):
		if agora_ms - _ultimo_ataque_serpente_ms < SISTEMA_SERPENTE_MUNDO.INTERVALO_ATAQUE_MS:
			return
		var indice := int(_estado_serpente_mundo.get("indiceAtaque", 0))
		_estado_serpente_mundo = SISTEMA_SERPENTE_MUNDO.iniciar_ataque_telegrafado(_estado_serpente_mundo, indice)
		_estado_serpente_mundo["indiceAtaque"] = indice + 1
		_salvar_estado_serpente_mundo()
		_publicar_estado_serpente_mundo()
		return
	var ataque: Dictionary = _estado_serpente_mundo.get("ataquePreparando", {})
	if agora_unix < int(ataque.get("impactoUnix", 0)):
		return
	var sopro_devastador := bool(ataque.get("destruirCenario", false)) or str(ataque.get("id", "")) == "sopro_primordial"
	if sopro_devastador:
		_estado_serpente_mundo["cenarioDevastado"] = true
		_estado_serpente_mundo["ultimaDevastacaoUnix"] = agora_unix
		# Zona autoritativa: árvores queimadas deixam de bloquear a movimentação de todos.
		_estado_serpente_mundo["zonaDevastada"] = {"x": 1200.0, "y": 285.0, "raio": 480.0, "tipo": "sopro_primordial", "recuperacaoUnix": agora_unix + SISTEMA_SERPENTE_MUNDO.TEMPO_RECUPERACAO_CENARIO_SEGUNDOS}
		_estado_serpente_mundo = SISTEMA_SERPENTE_MUNDO.registrar_marca_destruicao(_estado_serpente_mundo, {"x":1200.0,"y":285.0,"raio":480.0,"tipo":"cratera_queimada","elemento":"primordial","intensidade":1.0,"origem":"serpente_do_mundo"}, agora_unix)
		_aplicar_fuga_fauna_sopro(_estado_serpente_mundo["zonaDevastada"], agora_unix)
	var atingidos := 0
	var participantes: Dictionary = _estado_serpente_mundo.get("participantes", {})
	var defesas: Dictionary = _estado_serpente_mundo.get("defesasPreparadas", {})
	for uid_var in participantes.keys():
		var uid := str(uid_var)
		var participante: Dictionary = participantes[uid]
		var peer_id := int(participante.get("peerId", -1))
		if not bool(participante.get("ativo", false)) or not _perfil_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id):
			continue
		var posicao: Vector2 = _jogadores_no_mundo[peer_id]
		if posicao.distance_to(POSICAO_CABECA_SERPENTE) > SISTEMA_SERPENTE_MUNDO.RAIO_ARENA:
			continue
		var perfil: Dictionary = _perfil_por_peer[peer_id]
		var dano := SISTEMA_SERPENTE_MUNDO.calcular_dano_ataque(perfil, ataque, str(defesas.get(uid, "")))
		var vida_nova := maxi(0, int(perfil.get("vida", perfil.get("vidaMaxima", 100))) - dano)
		if not _repositorio_perfis.registrar_recursos_combate(uid, vida_nova, int(perfil.get("mana", 0)), vida_nova <= 0):
			continue
		var atualizado: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
		if atualizado.is_empty():
			continue
		_perfil_por_peer[peer_id] = atualizado
		rpc_id(peer_id, "_receber_perfil_personagem", atualizado)
		atingidos += 1
	_estado_serpente_mundo.erase("ataquePreparando")
	_estado_serpente_mundo["defesasPreparadas"] = {}
	_estado_serpente_mundo["ultimoAtaque"] = "%s atingiu toda a arena! %d participante(s) sofreram o impacto.%s" % [str(ataque.get("nome", "Ataque da serpente")), atingidos, " O cenário foi devastado!" if sopro_devastador else ""]
	_estado_serpente_mundo["ultimoAtaqueUnix"] = agora_unix
	_ultimo_ataque_serpente_ms = agora_ms
	_salvar_estado_serpente_mundo()
	_publicar_estado_serpente_mundo()

func _carregar_estado_serpente_mundo() -> void:
	_estado_serpente_mundo = {}
	if FileAccess.file_exists(CAMINHO_ESTADO_SERPENTE):
		var arquivo := FileAccess.open(CAMINHO_ESTADO_SERPENTE, FileAccess.READ)
		if arquivo != null:
			var dados = JSON.parse_string(arquivo.get_as_text())
			if dados is Dictionary and str(dados.get("chefeId", "")) == SISTEMA_SERPENTE_MUNDO.ID_CHEFE:
				_estado_serpente_mundo = dados
	if _estado_serpente_mundo.is_empty():
		_estado_serpente_mundo = SISTEMA_SERPENTE_MUNDO.criar_estado()
	else:
		# IDs de conexão e relógios monotônicos não sobrevivem à reinicialização do servidor.
		var participantes: Dictionary = _estado_serpente_mundo.get("participantes", {})
		for uid in participantes.keys():
			var participante: Dictionary = participantes[uid]
			participante["ativo"] = false
			participante["ultimaAcaoMs"] = -SISTEMA_SERPENTE_MUNDO.INTERVALO_ACAO_MS
			participantes[uid] = participante
		_estado_serpente_mundo["participantes"] = participantes
		# Migra arquivos criados antes do ciclo de renascimento.
		_estado_serpente_mundo["versao"] = 2
		_estado_serpente_mundo["ciclos"] = maxi(1, int(_estado_serpente_mundo.get("ciclos", 1)))
		_estado_serpente_mundo["totalDerrotas"] = int(_estado_serpente_mundo.get("totalDerrotas", 1 if str(_estado_serpente_mundo.get("status", "")) == SISTEMA_SERPENTE_MUNDO.STATUS_DERROTADA else 0))
		_estado_serpente_mundo["serpenteOriginalPreservada"] = true
		if not _estado_serpente_mundo.has("ultimoAtaque"):
			_estado_serpente_mundo["ultimoAtaque"] = "A Serpente observa a arena."
		if str(_estado_serpente_mundo.get("status", "")) == SISTEMA_SERPENTE_MUNDO.STATUS_DERROTADA and int(_estado_serpente_mundo.get("proximoRenascimentoUnix", 0)) <= 0:
			var derrota_antiga := int(_estado_serpente_mundo.get("derrotadaUnix", 0))
			if derrota_antiga <= 0:
				derrota_antiga = int(Time.get_unix_time_from_system())
				_estado_serpente_mundo["derrotadaUnix"] = derrota_antiga
			_estado_serpente_mundo["proximoRenascimentoUnix"] = derrota_antiga + SISTEMA_SERPENTE_MUNDO.TEMPO_RENASCIMENTO_SEGUNDOS
	_salvar_estado_serpente_mundo()

func _salvar_estado_serpente_mundo() -> void:
	if not multiplayer.is_server() or _estado_serpente_mundo.is_empty():
		return
	var diretorio := DirAccess.open("user://")
	if diretorio != null:
		diretorio.make_dir_recursive("dados")
	var arquivo := FileAccess.open(CAMINHO_ESTADO_SERPENTE, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível persistir o estado da Serpente do Mundo.")
		return
	arquivo.store_string(JSON.stringify(_estado_serpente_mundo))
	arquivo.close()

func _publicar_estado_serpente_mundo() -> void:
	if multiplayer.is_server():
		# A revisão fica no arquivo persistente: após reiniciar, o servidor continua
		# publicando uma sequência que permite rejeitar snapshots atrasados.
		_estado_serpente_mundo["revisaoSincronizacao"] = int(_estado_serpente_mundo.get("revisaoSincronizacao", 0)) + 1
		_estado_serpente_mundo["atualizadoUnix"] = int(Time.get_unix_time_from_system())
		_salvar_estado_serpente_mundo()
	var publico := SISTEMA_SERPENTE_MUNDO.obter_estado_publico(_estado_serpente_mundo)
	publico["mundoId"] = SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO
	publico["escopo"] = "global"
	_estado_serpente_mundo_publico = publico.duplicate(true)
	_ultima_revisao_estado_serpente_recebida = int(publico.get("revisaoSincronizacao", 0))
	estado_serpente_mundo_atualizado.emit(publico.duplicate(true))
	if multiplayer.is_server():
		rpc("_receber_estado_serpente_mundo", publico)

@rpc("authority", "call_remote", "reliable")
func _receber_estado_serpente_mundo(dados: Dictionary) -> void:
	var revisao := int(dados.get("revisaoSincronizacao", 0))
	if revisao < _ultima_revisao_estado_serpente_recebida:
		return
	var estado_recebido := dados.duplicate(true)
	if str(estado_recebido.get("mundoId", "")) != SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO or str(estado_recebido.get("escopo", "")) != "global":
		return
	if not (estado_recebido.get("marcasDestruicao", []) is Array):
		estado_recebido["marcasDestruicao"] = []
	_ultima_revisao_estado_serpente_recebida = revisao
	_estado_serpente_mundo_publico = estado_recebido
	estado_serpente_mundo_atualizado.emit(_estado_serpente_mundo_publico.duplicate(true))

func obter_estado_serpente_mundo_publico() -> Dictionary:
	return _estado_serpente_mundo_publico.duplicate(true)

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_filhote_serpente(sucesso: bool, mensagem: String, invocacao: Dictionary) -> void:
	resultado_filhote_serpente.emit(sucesso, mensagem, invocacao.duplicate(true))

## Cliente envia somente uma ação da lista permitida; o servidor calcula todo o resultado.
func solicitar_acao_combate(acao: String, alvo_selecionado_id: String = "", habilidade_id: String = "") -> void:
	if estado == EstadoConexao.CONECTADO:
		_enviar_acao_combate.rpc_id(1, acao, alvo_selecionado_id, habilidade_id)

## Modos e ordens são apenas intenções; o servidor valida e executa a decisão do companheiro.
func solicitar_comando_companheiro(modo: String, ordem: String, alvo_id: String = "") -> void:
	if estado == EstadoConexao.CONECTADO:
		_enviar_comando_companheiro.rpc_id(1, modo, ordem, alvo_id)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_comando_companheiro(modo: String, ordem: String, alvo_id: String = "") -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or not _combates_por_peer.has(peer_id):
		return
	var sessao: Dictionary = _combates_por_peer[peer_id]
	var estado_atual: Dictionary = sessao.get("estado", {})
	var resultado := SistemaCombate.aplicar_comando_companheiro(estado_atual, modo, ordem, alvo_id)
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_erro_combate", str(resultado.get("erro", "Não foi possível comandar o companheiro.")))
		return
	sessao["estado"] = resultado["estado"]
	_combates_por_peer[peer_id] = sessao
	rpc_id(peer_id, "_receber_estado_combate", resultado["estado"])

@rpc("any_peer", "call_remote", "reliable")
func _enviar_acao_combate(acao: String, alvo_selecionado_id: String = "", habilidade_id: String = "") -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or not _combates_por_peer.has(peer_id):
		return
	if not [SistemaCombate.ACAO_ATAQUE, SistemaCombate.ACAO_MAGIA, SistemaCombate.ACAO_HABILIDADE, SistemaCombate.ACAO_DEFENDER, SistemaCombate.ACAO_ESQUIVAR].has(acao):
		rpc_id(peer_id, "_receber_erro_combate", "Ação de combate inválida.")
		return
	# Evita que pacotes repetidos avancem várias rodadas em sequência.
	var agora_ms := Time.get_ticks_msec()
	if not _registrar_acao_combate_se_permitida(peer_id, agora_ms):
		return
	var sessao: Dictionary = _combates_por_peer[peer_id]
	var estado_atual: Dictionary = sessao.get("estado", {})
	var semente_servidor := int(Time.get_ticks_usec()) ^ (peer_id * 7919)
	var resultado := SistemaCombate.executar_rodada(estado_atual, acao, semente_servidor, alvo_selecionado_id, habilidade_id)
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_erro_combate", str(resultado.get("erro", "Não foi possível executar a ação.")))
		return
	var novo_estado: Dictionary = resultado["estado"]
	_registrar_marcas_chefe_combate(peer_id, sessao, estado_atual, novo_estado)
	sessao["estado"] = novo_estado
	_combates_por_peer[peer_id] = sessao
	rpc_id(peer_id, "_receber_estado_combate", novo_estado)
	var status := str(novo_estado.get("status", SistemaCombate.STATUS_EM_ANDAMENTO))
	if status == SistemaCombate.STATUS_VITORIA or status == SistemaCombate.STATUS_DERROTA:
		var uid := str(_uid_por_peer.get(peer_id, ""))
		var estado_jogador: Dictionary = novo_estado.get("jogador", {})
		var derrotado := status == SistemaCombate.STATUS_DERROTA
		var salvo: bool = _repositorio_perfis.registrar_recursos_combate(
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
		var criaturas_da_batalha: Array = sessao.get("criaturas", [sessao.get("criatura", {})])
		if status == SistemaCombate.STATUS_DERROTA:
			var posicao_derrota: Vector2 = _jogadores_no_mundo.get(peer_id, Vector2(1190.0, 1120.0))
			var inimigos_finais: Array = novo_estado.get("inimigos", [])
			for indice in range(criaturas_da_batalha.size()):
				if indice < inimigos_finais.size() and int(inimigos_finais[indice].get("vida", 0)) <= 0:
					continue
				var criatura_sobrevivente: Dictionary = criaturas_da_batalha[indice]
				var evolucao_sobrevivente := _repositorio_criaturas.registrar_vitoria_sobre_jogador(uid, str(criatura_sobrevivente.get("id", "")), posicao_derrota)
				if not bool(evolucao_sobrevivente.get("ok", false)):
					push_error("Não foi possível salvar a vitória e a evolução da criatura sobrevivente.")
				else:
					_carregar_criaturas_persistentes()
					rpc("_receber_criaturas_persistentes", _lista_visual_criaturas())
		if status == SistemaCombate.STATUS_VITORIA:
			var inimigos_derrotados: Array = novo_estado.get("inimigos", [])
			var algum_corpo_atualizado := false
			for indice_derrota in range(criaturas_da_batalha.size()):
				if indice_derrota >= inimigos_derrotados.size() or int(inimigos_derrotados[indice_derrota].get("vida", 0)) > 0:
					continue
				var criatura_derrotada_sessao: Dictionary = criaturas_da_batalha[indice_derrota]
				var grupo_derrota_id := str(criatura_derrotada_sessao.get("grupoId", ""))
				var individuo_derrota_id := str(criatura_derrotada_sessao.get("individuoId", ""))
				if not grupo_derrota_id.is_empty() and not individuo_derrota_id.is_empty():
					var corpo := _repositorio_grupos.registrar_derrota_em_combate(grupo_derrota_id, individuo_derrota_id, uid)
					if bool(corpo.get("ok", false)):
						_grupos_mundo_cache[grupo_derrota_id] = corpo.get("grupo", {})
						algum_corpo_atualizado = true
					else:
						push_error("Não foi possível registrar o corpo derrotado para domesticação: " + str(corpo.get("erro", "")))
			if algum_corpo_atualizado:
				rpc("_receber_grupos_selvagens", _lista_visual_individuos_grupos())
			var periodo_recompensa := str(novo_estado.get("periodo", "dia"))
			var xp_concedido := 0
			var companheiro_recebeu_essencia := false
			var perfil_para_companheiro: Dictionary = _perfil_por_peer.get(peer_id, {})
			var companheiro_ativo_id := str(perfil_para_companheiro.get("invocacaoAtivaId", ""))
			for criatura_derrotada in criaturas_da_batalha:
				var criatura_derrotada_id := str(criatura_derrotada.get("id", ""))
				var registro_derrota := _repositorio_criaturas.registrar_derrota(uid, criatura_derrotada_id)
				if not bool(registro_derrota.get("ok", false)):
					push_error("Não foi possível atualizar as estatísticas globais da criatura derrotada.")
				# A vitória já foi confirmada pelo motor de combate autoritativo.
				# O progresso de missão não depende da gravação das estatísticas globais.
				var evento_missao := registrar_evento_missao_mundo(peer_id, "derrotar_criatura", criatura_derrotada_id, 1)
				if not bool(evento_missao.get("ok", false)):
					push_warning("A derrota foi confirmada, mas o progresso de missão não foi atualizado: " + str(evento_missao.get("erro", "")))
				if not companheiro_ativo_id.is_empty():
					var essencia := _repositorio_perfis.alimentar_invocacao(uid, companheiro_ativo_id, criatura_derrotada)
					if bool(essencia.get("ok", false)):
						companheiro_recebeu_essencia = true
						if bool(essencia.get("evoluiuForma", false)):
							print("O companheiro %s despertou uma nova forma: %s." % [essencia.invocacao.get("nome", "Companheiro"), essencia.invocacao.get("formaNome", essencia.invocacao.get("nome", ""))])
					else:
						push_warning("A essência da criatura não foi absorvida pelo companheiro: " + str(essencia.get("erro", "")))
				var xp_base := int(criatura_derrotada.get("experienciaBase", 0))
				xp_concedido += SISTEMA_CICLO_NOTURNO.calcular_experiencia(xp_base, periodo_recompensa, criatura_derrotada)
				var drops_criatura := concluir_combate_e_conceder_drops(peer_id, criatura_derrotada, {"periodo":periodo_recompensa})
				drops.append_array(drops_criatura)
			if companheiro_recebeu_essencia:
				var perfil_com_companheiro: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
				if not perfil_com_companheiro.is_empty():
					_perfil_por_peer[peer_id] = perfil_com_companheiro
					rpc_id(peer_id, "_receber_perfil_personagem", perfil_com_companheiro)
			if xp_concedido > 0:
				var resultado_xp: Dictionary = _repositorio_perfis.conceder_experiencia(uid, xp_concedido)
				if bool(resultado_xp.get("ok", false)):
					var perfil_com_xp: Dictionary = resultado_xp.get("perfil", {})
					if not perfil_com_xp.is_empty():
						_perfil_por_peer[peer_id] = perfil_com_xp
						rpc_id(peer_id, "_receber_perfil_personagem", perfil_com_xp)
				else:
					push_error("Não foi possível conceder a experiência das criaturas derrotadas.")
		_combates_por_peer.erase(peer_id)
		rpc_id(peer_id, "_receber_combate_finalizado", status, drops)

## O servidor registra no estado mundial os especiais destrutivos executados por chefes.
func _registrar_marcas_chefe_combate(peer_id: int, sessao: Dictionary, estado_anterior: Dictionary, novo_estado: Dictionary) -> void:
	if not multiplayer.is_server() or not _jogadores_no_mundo.has(peer_id):
		return
	var historico_antigo: Array = estado_anterior.get("historico", [])
	var historico_novo: Array = novo_estado.get("historico", [])
	# O histórico mantém somente as 30 últimas linhas; encontra a sobreposição
	# para reconhecer também um especial repetido depois que a linha antiga saiu da janela.
	var sobreposicao := 0
	var limite_sobreposicao := mini(historico_antigo.size(), historico_novo.size())
	for tamanho in range(limite_sobreposicao, 0, -1):
		var coincide := true
		for indice in range(tamanho):
			if str(historico_antigo[historico_antigo.size() - tamanho + indice]) != str(historico_novo[indice]):
				coincide = false
				break
		if coincide:
			sobreposicao = tamanho
			break
	var criaturas: Array = sessao.get("criaturas", [])
	if criaturas.is_empty():
		var criatura_unica: Dictionary = sessao.get("criatura", {})
		if not criatura_unica.is_empty():
			criaturas.append(criatura_unica)
	if criaturas.is_empty():
		return
	var posicao: Vector2 = _jogadores_no_mundo[peer_id]
	if _estado_serpente_mundo.is_empty():
		_estado_serpente_mundo = SISTEMA_SERPENTE_MUNDO.criar_estado()
	var agora_unix := int(Time.get_unix_time_from_system())
	var houve_marca := false
	for indice_evento in range(sobreposicao, historico_novo.size()):
		var evento := str(historico_novo[indice_evento])
		if not evento.contains(" executa "):
			continue
		for criatura in criaturas:
			if not (criatura is Dictionary):
				continue
			var configuracao := SISTEMA_SERPENTE_MUNDO.obter_configuracao_marca_chefe(criatura, evento)
			if configuracao.is_empty():
				continue
			var dados := configuracao.duplicate(true)
			dados["x"] = posicao.x
			dados["y"] = posicao.y
			_estado_serpente_mundo = SISTEMA_SERPENTE_MUNDO.registrar_marca_destruicao(_estado_serpente_mundo, dados, agora_unix)
			_aplicar_fuga_fauna_sopro({"x":posicao.x,"y":posicao.y,"raio":float(dados.get("raio", 0.0))}, agora_unix)
			houve_marca = true
			break
	if houve_marca:
		_salvar_estado_serpente_mundo()
		_publicar_estado_serpente_mundo()

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
		var dados_lider: Dictionary = grupo.get("liderAtual", {})
		for individuo in grupo.get("individuos", []):
			var p: Dictionary = individuo.get("posicaoMundo", {})
			var eh_lider := str(individuo.get("individuoId", "")) == lider_id and bool(individuo.get("vivo", true))
			var identidade_visual: Dictionary = dados_lider.get("identidadeVisual", {}) if eh_lider else {}
			if eh_lider and identidade_visual.is_empty():
				identidade_visual = SISTEMA_LIDERES.criar_identidade_visual(
					str(grupo.get("grupoId", "")),
					str(individuo.get("individuoId", "")),
					bool(individuo.get("liderNato", false))
				)
			resultado.append({
				"id":str(individuo.get("individuoId", "")),
				"nome":nome_especie,
				"chefe":false,
				"lider":eh_lider,
				"titulo":"Líder do grupo" if eh_lider else "",
				"liderNato":bool(dados_lider.get("liderNato", false)) if eh_lider else false,
				"identidadeVisual":identidade_visual.duplicate(true),
				"auraLider":eh_lider and bool(identidade_visual.get("auraAtiva", false)),
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
	var perseguicoes := _repositorio_grupos.avancar_perseguicoes(delta_segundos, int(Time.get_unix_time_from_system()))
	if bool(perseguicoes.get("ok", false)):
		for grupo_perseguidor in perseguicoes.get("grupos", []):
			var id_perseguidor := str(grupo_perseguidor.get("grupoId", ""))
			if not id_perseguidor.is_empty():
				_grupos_mundo_cache[id_perseguidor] = grupo_perseguidor
	else:
		push_warning("Perseguições ecológicas não avançaram: " + str(perseguicoes.get("erro", "")))
	var atualizacoes: Array = []
	for grupo_id in _grupos_mundo_cache.keys():
		var grupo: Dictionary = _grupos_mundo_cache[grupo_id]
		if not grupo.get("alertasRecebidos", []).is_empty():
			var reacao_alerta := _repositorio_grupos.processar_alertas_recebidos(str(grupo_id))
			if bool(reacao_alerta.get("ok", false)):
				grupo = reacao_alerta.get("grupo", grupo)
				_grupos_mundo_cache[grupo_id] = grupo
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
	_processar_ciclo_alimentar(agora_ms)
	if agora_ms - _ultima_gravacao_grupos_ms >= INTERVALO_GRAVACAO_GRUPOS_MS:
		var salvou_todos := true
		for grupo_id in _grupos_mundo_cache.keys():
			var grupo: Dictionary = _grupos_mundo_cache[grupo_id]
			if not _repositorio_grupos.salvar_movimento_grupo(str(grupo_id), grupo.get("individuos", [])):
				salvou_todos = false
		if salvou_todos:
			_ultima_gravacao_grupos_ms = agora_ms

## Processa estoque compartilhado e reprodução/mortalidade de todos os grupos em um ciclo controlado.
func _processar_ciclo_alimentar(agora_ms: int) -> void:
	if agora_ms - _ultimo_tick_populacional_ms < INTERVALO_SIMULACAO_POPULACIONAL_MS:
		return
	_ultimo_tick_populacional_ms = agora_ms
	if _grupos_mundo_cache.is_empty():
		return
	var grupos: Array = _grupos_mundo_cache.values()
	var agora_unix := int(Time.get_unix_time_from_system())
	var marcas_ativas_recursos := SISTEMA_SERPENTE_MUNDO.obter_marcas_destruicao_ativas(_estado_serpente_mundo, agora_unix)
	var recursos := _repositorio_recursos_ecologicos.processar_tick(grupos, agora_unix, marcas_ativas_recursos)
	if not bool(recursos.get("ok", false)):
		push_warning("Ciclo alimentar não avançou: " + str(recursos.get("erro", "erro desconhecido")))
		return
	var disponibilidade: Dictionary = recursos.get("disponibilidadePorEspecie", {})
	var disponibilidade_local: Dictionary = recursos.get("disponibilidadePorGrupo", {})
	var carcaças := _repositorio_grupos.processar_carcacas_ecologicas(agora_unix)
	if not bool(carcaças.get("ok", false)):
		push_warning("Ciclo de carcaças não avançou: " + str(carcaças.get("erro", "")))
		return
	for grupo_atualizado in carcaças.get("grupos", []):
		var id_grupo := str(grupo_atualizado.get("grupoId", ""))
		if _grupos_mundo_cache.has(id_grupo):
			_grupos_mundo_cache[id_grupo] = grupo_atualizado
	var disponibilidade_carcacas: Dictionary = carcaças.get("disponibilidadePorEspecie", {})
	for especie_consumidora in disponibilidade_carcacas:
		disponibilidade[especie_consumidora] = minf(float(disponibilidade.get(especie_consumidora, 1.0)), float(disponibilidade_carcacas[especie_consumidora]))
	var disponibilidade_por_grupo := {}
	for grupo_id in _grupos_mundo_cache.keys():
		var grupo_base: Dictionary = _grupos_mundo_cache[grupo_id]
		var especie_base := str(grupo_base.get("especieId", ""))
		disponibilidade_por_grupo[str(grupo_id)] = clampf(float(disponibilidade_local.get(str(grupo_id), disponibilidade.get(especie_base, 1.0))), 0.0, 1.0)
	var ajuda_alimentar := SISTEMA_AJUDA_ALIMENTAR.aplicar_ajuda(_grupos_mundo_cache.values(), disponibilidade_por_grupo, _ultimo_apoio_alimentar_unix, agora_unix)
	disponibilidade_por_grupo = ajuda_alimentar.get("disponibilidadePorGrupo", disponibilidade_por_grupo)
	var grupos_protegidos_por_ajuda := {}
	for evento_ajuda in ajuda_alimentar.get("eventos", []):
		grupos_protegidos_por_ajuda[str(evento_ajuda.get("grupoReceptorId", ""))] = true
	var mudou := false
	var marcas_ativas := SISTEMA_SERPENTE_MUNDO.obter_marcas_destruicao_ativas(_estado_serpente_mundo, agora_unix)
	for grupo_id in _grupos_mundo_cache.keys():
		var grupo_retorno: Dictionary = _grupos_mundo_cache[grupo_id]
		if not grupo_retorno.get("retornoDevastacao", {}).is_empty():
			var especie_retorno := str(grupo_retorno.get("especieId", ""))
			var alimento_retorno := clampf(float(disponibilidade.get(especie_retorno, 0.0)), 0.0, 1.0)
			var retorno_habitat := _repositorio_grupos.retornar_da_devastacao(str(grupo_id), marcas_ativas, agora_unix, alimento_retorno)
			if not bool(retorno_habitat.get("ok", false)):
				push_warning("Retorno ao habitat não avançou para " + str(grupo_id) + ": " + str(retorno_habitat.get("erro", "")))
			elif bool(retorno_habitat.get("retornou", false)):
				_grupos_mundo_cache[grupo_id] = retorno_habitat["grupo"]
				mudou = true
	for grupo_id in _grupos_mundo_cache.keys():
		var grupo: Dictionary = _grupos_mundo_cache[grupo_id]
		var especie_id := str(grupo.get("especieId", ""))
		var alimento := clampf(float(disponibilidade_por_grupo.get(str(grupo_id), disponibilidade.get(especie_id, 1.0))), 0.0, 1.0)
		var migracao := _repositorio_grupos.avaliar_migracao_por_escassez(str(grupo_id), alimento, agora_unix)
		if not bool(migracao.get("ok", false)):
			push_warning("Migração ecológica não avançou para " + str(grupo_id) + ": " + str(migracao.get("erro", "")))
		elif bool(migracao.get("migrou", false)):
			_grupos_mundo_cache[grupo_id] = migracao["grupo"]
			grupo = migracao["grupo"]
			mudou = true
		var protecao_fome := 0.25 if grupos_protegidos_por_ajuda.has(str(grupo_id)) else 0.0
		var resultado := _repositorio_grupos.avancar_grupo(str(grupo_id), agora_unix, alimento, protecao_fome)
		if not bool(resultado.get("ok", false)):
			push_warning("População não avançou para " + str(grupo_id) + ": " + str(resultado.get("erro", "")))
			continue
		if bool(resultado.get("alterou", false)):
			_grupos_mundo_cache[grupo_id] = resultado["grupo"]
			mudou = true
	mudou = _processar_encontros_sociais(agora_unix) or mudou
	if mudou:
		rpc("_receber_grupos_selvagens", _lista_visual_individuos_grupos())

## Encontros pacíficos entre grupos próximos podem construir confiança; o servidor decide e persiste.
func _processar_encontros_sociais(agora_unix: int) -> bool:
	var ids: Array = _grupos_mundo_cache.keys()
	if ids.size() < 2:
		return false
	var registrou := false
	for indice_a in range(ids.size()):
		var id_a := str(ids[indice_a])
		var grupo_a: Dictionary = _grupos_mundo_cache[id_a]
		var territorio_a: Dictionary = grupo_a.get("territorio", {})
		var centro_a_dados: Dictionary = territorio_a.get("centro", {})
		var centro_a := Vector2(float(centro_a_dados.get("x", -10000.0)), float(centro_a_dados.get("y", -10000.0)))
		var raio_a := float(territorio_a.get("raio", 0.0))
		var personalidade_a: Dictionary = grupo_a.get("personalidade", {})
		for indice_b in range(indice_a + 1, ids.size()):
			var id_b := str(ids[indice_b])
			var grupo_b: Dictionary = _grupos_mundo_cache[id_b]
			if str(grupo_a.get("ecossistemaId", "")) != str(grupo_b.get("ecossistemaId", "")):
				continue
			var territorio_b: Dictionary = grupo_b.get("territorio", {})
			var centro_b_dados: Dictionary = territorio_b.get("centro", {})
			var centro_b := Vector2(float(centro_b_dados.get("x", -10000.0)), float(centro_b_dados.get("y", -10000.0)))
			var raio_b := float(territorio_b.get("raio", 0.0))
			if centro_a.distance_to(centro_b) > raio_a + raio_b + 60.0:
				continue
			var relacoes_a: Dictionary = grupo_a.get("relacoesGrupos", {})
			var relacao: Dictionary = relacoes_a.get(id_b, {})
			if str(relacao.get("estado", "neutro")) == "rival":
				continue
			if agora_unix - int(relacao.get("ultimaInteracaoUnix", 0)) < 21600:
				continue
			var personalidade_b: Dictionary = grupo_b.get("personalidade", {})
			var sociabilidade_a := clampf(float(personalidade_a.get("sociabilidade", 1.0)), 0.70, 1.30)
			var sociabilidade_b := clampf(float(personalidade_b.get("sociabilidade", 1.0)), 0.70, 1.30)
			var chance := clampf(0.10 + ((sociabilidade_a + sociabilidade_b - 1.40) * 0.25), 0.10, 0.35)
			var par_ordenado := id_a + "|" + id_b
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(hash(par_ordenado + "|" + str(int(agora_unix / 3600))))
			if rng.randf() > chance:
				continue
			var resultado_social := _repositorio_grupos.registrar_interacao_social(id_a, id_b, "cooperacao", agora_unix)
			if not bool(resultado_social.get("ok", false)):
				continue
			var atualizado_a: Dictionary = resultado_social.get("grupoA", {})
			var atualizado_b: Dictionary = resultado_social.get("grupoB", {})
			grupo_a["relacoesGrupos"] = atualizado_a.get("relacoesGrupos", grupo_a.get("relacoesGrupos", {}))
			grupo_a["historicoSocial"] = atualizado_a.get("historicoSocial", grupo_a.get("historicoSocial", []))
			grupo_b["relacoesGrupos"] = atualizado_b.get("relacoesGrupos", grupo_b.get("relacoesGrupos", {}))
			grupo_b["historicoSocial"] = atualizado_b.get("historicoSocial", grupo_b.get("historicoSocial", []))
			_grupos_mundo_cache[id_a] = grupo_a
			_grupos_mundo_cache[id_b] = grupo_b
			registrou = true
	return registrou

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
		var quantidade_predadores_vivos := 0
		var atacante: Dictionary = {}
		for membro in membros_predadores:
			if bool(membro.get("vivo", false)):
				quantidade_predadores_vivos += 1
				if atacante.is_empty():
					atacante = membro
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
			var alvo_isolado: Dictionary = {}
			var maior_isolamento := 0.0
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
				var distancia_aliado := INF
				for outro_membro in grupo_presa.get("individuos", []):
					if not bool(outro_membro.get("vivo", false)) or str(outro_membro.get("individuoId", "")) == str(membro_presa.get("individuoId", "")):
						continue
					var outro_pos_dados: Dictionary = outro_membro.get("posicaoMundo", {})
					var outro_pos := Vector2(float(outro_pos_dados.get("x", -9999.0)), float(outro_pos_dados.get("y", -9999.0)))
					distancia_aliado = minf(distancia_aliado, pos.distance_to(outro_pos))
				if distancia_aliado > maior_isolamento:
					maior_isolamento = distancia_aliado
					alvo_isolado = membro_presa
			if alvo.is_empty():
				continue
			var alvo_coordenado := SISTEMA_DEFESA_COOPERATIVA.selecionar_alvo_prioritario(grupo_presa, pos_atacante)
			if not alvo_coordenado.is_empty():
				alvo = alvo_coordenado
			var forca_predador := _repositorio_grupos._calcular_forca_territorial(grupo_predador)
			var forca_presa := _repositorio_grupos._calcular_forca_territorial(grupo_presa)
			var personalidade_predador: Dictionary = grupo_predador.get("personalidade", {})
			var ecologia_predador: Dictionary = especie_predador.get("ecologia", {})
			var habitats_emboscada: Array = ecologia_predador.get("habitatsEmboscada", [])
			var pode_emboscar := bool(ecologia_predador.get("capacidadeEmboscada", false))
			var habitat_compativel := habitats_emboscada.has(str(grupo_presa.get("habitat", "")))
			var perseguicao: Dictionary = grupo_predador.get("perseguicaoAtual", {})
			var inicio_perseguicao := int(perseguicao.get("iniciadaUnix", Time.get_unix_time_from_system()))
			var duracao_perseguicao := maxf(0.0, float(Time.get_unix_time_from_system() - inicio_perseguicao))
			var estrategia := SISTEMA_COMPORTAMENTO_CRIATURAS.decidir_estrategia_caca(
				forca_predador / maxf(1.0, forca_presa),
				float(personalidade_predador.get("agressividade", 1.0)),
				float(personalidade_predador.get("coragem", 1.0)),
				maior_isolamento >= 45.0, maior_isolamento, pode_emboscar, habitat_compativel,
				int(perseguicao.get("falhasSeguidas", 0)), duracao_perseguicao, quantidade_predadores_vivos
			)
			var memoria_cacada_geracional := SISTEMA_COMPORTAMENTO_CRIATURAS.combinar_memoria_cacada_com_heranca(
				grupo_predador.get("memoriaCacada", []), grupo_predador.get("individuos", []), int(Time.get_unix_time_from_system())
			)
			estrategia = SISTEMA_COMPORTAMENTO_CRIATURAS.ajustar_estrategia_com_memoria(
				estrategia, memoria_cacada_geracional,
				str(especie_presa.get("id", "")), str(grupo_predador.get("ecossistemaId", "")),
				str(grupo_predador.get("bioma", "")), quantidade_predadores_vivos, int(Time.get_unix_time_from_system())
			)
			var agora_unix_tatico := int(Time.get_unix_time_from_system())
			var centro_presa_tatico: Dictionary = grupo_presa.get("territorio", {}).get("centro", {})
			var estrategia_nome := str(estrategia.get("estrategia", ""))
			if estrategia_nome == "cercar":
				grupo_predador["formacaoTatica"] = {
					"tipo":"cerco",
					"centroAlvo":{"x":float(centro_presa_tatico.get("x", -1.0)),"y":float(centro_presa_tatico.get("y", -1.0))},
					"raio":34.0,
					"expiraUnix":agora_unix_tatico + 30
				}
			elif estrategia_nome == "emboscar":
				var formacao_furtiva_atual: Dictionary = grupo_predador.get("formacaoTatica", {})
				var centro_formacao_atual: Dictionary = formacao_furtiva_atual.get("centroAlvo", {})
				var centro_presa_vetor := Vector2(float(centro_presa_tatico.get("x", -1.0)), float(centro_presa_tatico.get("y", -1.0)))
				var mesma_formacao_furtiva := str(formacao_furtiva_atual.get("tipo", "")) == "aproximacao_furtiva" and Vector2(float(centro_formacao_atual.get("x", -9999.0)), float(centro_formacao_atual.get("y", -9999.0))).distance_to(centro_presa_vetor) < 12.0
				if mesma_formacao_furtiva:
					formacao_furtiva_atual["expiraUnix"] = agora_unix_tatico + 45
					grupo_predador["formacaoTatica"] = formacao_furtiva_atual
				else:
					grupo_predador["formacaoTatica"] = {
						"tipo":"aproximacao_furtiva",
						"centroAlvo":{"x":centro_presa_vetor.x,"y":centro_presa_vetor.y},
						"raio":26.0,
						"expiraUnix":agora_unix_tatico + 45,
						"concluida":false
					}
			elif estrategia_nome == "desistir":
				grupo_predador.erase("formacaoTatica")
			grupo_predador["estrategiaCacaAtual"] = estrategia
			_grupos_mundo_cache[id_predador] = grupo_predador
			if estrategia_nome == "desistir":
				continue
			if estrategia_nome == "emboscar" and not bool(grupo_predador.get("formacaoTatica", {}).get("concluida", false)):
				_grupos_mundo_cache[id_predador] = grupo_predador
				continue
			if str(estrategia.get("estrategia", "")) == "atacar_isolado" and not alvo_isolado.is_empty():
				var pos_isolado: Dictionary = alvo_isolado.get("posicaoMundo", {})
				var distancia_isolado := pos_atacante.distance_to(Vector2(float(pos_isolado.get("x", -9999.0)), float(pos_isolado.get("y", -9999.0))))
				if distancia_isolado < DISTANCIA_COMBATE_ECOLOGICO:
					alvo = alvo_isolado
			var predador_com_grupo := especie_predador.duplicate(true)
			predador_com_grupo["_grupo"] = grupo_predador
			var presa_com_grupo := especie_presa.duplicate(true)
			presa_com_grupo["_grupo"] = grupo_presa
			var resultado := SISTEMA_COMBATE_ECOLOGICO.resolver_ataque(
				predador_com_grupo, presa_com_grupo, atacante, alvo,
				int(Time.get_ticks_usec()) ^ hash(chave)
			)
			if not bool(resultado.get("ok", false)):
				continue
			var intervencao := SISTEMA_DEFESA_COOPERATIVA.avaliar_intervencao(grupo_presa, _grupos_mundo_cache.values(), alvo)
			var reacao := _repositorio_grupos.reagir_ameaca_ecologica(
				str(id_presa), str(id_predador), bool(intervencao.get("interveio", false)),
				int(Time.get_unix_time_from_system())
			)
			if bool(reacao.get("ok", false)):
				grupo_presa = reacao["grupo"]
				_grupos_mundo_cache[id_presa] = grupo_presa
				if str(reacao.get("acao", "")) == "fugir":
					rpc("_receber_grupos_selvagens", _lista_visual_individuos_grupos())
					continue
			var dano := int(resultado.get("dano", 0))
			if bool(intervencao.get("interveio", false)):
				dano = maxi(1, roundi(float(dano) * (1.0 - float(intervencao.get("reducaoDano", 0.25)))))
			var aplicado := _repositorio_grupos.aplicar_dano_ecologico(
				str(id_presa), str(resultado.get("alvoIndividuoId", "")), dano
			)
			if not bool(aplicado.get("ok", false)):
				continue
			var confronto := _repositorio_grupos.registrar_confronto_ecologico(
					str(id_predador), str(id_presa), str(resultado.get("alvoIndividuoId", "")),
					int(Time.get_unix_time_from_system())
				)
			if bool(confronto.get("ok", false)):
				_grupos_mundo_cache[str(id_predador)] = confronto["predador"]
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
		var marcas_ativas := SISTEMA_SERPENTE_MUNDO.obter_marcas_destruicao_ativas(_estado_serpente_mundo, int(Time.get_unix_time_from_system()))
		var direcao_cicatriz := SISTEMA_SELECAO_ENCONTROS.calcular_direcao_fuga_cicatriz(marcas_ativas, posicao, int(Time.get_unix_time_from_system()))
		var criatura_especial := bool(criatura.get("chefe", false)) or bool(criatura.get("chefeMundial", false)) or str(criatura.get("categoria", "")).to_lower() == "chefe_mundial"
		if not criatura_especial and direcao_cicatriz != Vector2.ZERO:
			comportamento = SISTEMA_COMPORTAMENTO_CRIATURAS.FUGINDO
		if comportamento == SISTEMA_COMPORTAMENTO_CRIATURAS.FUGINDO:
			var direcao_fuga := direcao_cicatriz if direcao_cicatriz != Vector2.ZERO else posicao - jogador_alvo
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

## O relógio do servidor decide os fenômenos; todos os clientes recebem o mesmo anúncio.
func _atualizar_ciclo_celeste_autoritativo() -> void:
	var contexto := _obter_contexto_celeste_servidor()
	_contexto_celeste_atual = contexto.duplicate(true)
	var dia_mundo := int(contexto.get("dia", 1))
	var periodo := str(contexto.get("periodo", "indefinido"))
	if dia_mundo != _ultimo_dia_celeste or periodo != _ultimo_periodo_celeste:
		var anuncio := SISTEMA_CICLO_NOTURNO.criar_anuncio_inicio_noite(contexto, _ultimo_periodo_celeste)
		_ultimo_dia_celeste = dia_mundo
		_ultimo_periodo_celeste = periodo
		if bool(anuncio.get("deveAnunciar", false)):
			anuncio["mundoId"] = SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO
			anuncio["escopo"] = "global"
			rpc("_receber_anuncio_celeste", anuncio)
	# Publica o relógio uma vez por segundo para que todos vejam o mesmo horário e céu.
	var agora_ms := Time.get_ticks_msec()
	if agora_ms - _ultimo_envio_relogio_ms >= 1000:
		_ultimo_envio_relogio_ms = agora_ms
		rpc("_receber_relogio_mundo", contexto)
		relogio_mundo_atualizado.emit(contexto.duplicate(true))

## Impede que um cliente avance várias rodadas em sequência por pacotes repetidos.
func _registrar_acao_combate_se_permitida(peer_id: int, agora_ms: int) -> bool:
	var ultima_acao_ms := int(_ultima_acao_combate_ms.get(peer_id, agora_ms - INTERVALO_MINIMO_ACAO_COMBATE_MS))
	if agora_ms - ultima_acao_ms < INTERVALO_MINIMO_ACAO_COMBATE_MS:
		return false
	_ultima_acao_combate_ms[peer_id] = agora_ms
	return true

## Calcula o contexto usando a mesma semente persistida durante toda a vida do mundo.
func _obter_contexto_celeste_servidor() -> Dictionary:
	var agora_unix := int(Time.get_unix_time_from_system())
	var contexto := SISTEMA_CICLO_NOTURNO.criar_contexto_por_tempo_unix(agora_unix, _semente_mundo_celeste)
	contexto["mundoId"] = SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO
	contexto["escopo"] = "global"
	return contexto

## A semente não muda quando o processo reinicia: os fenômenos previstos para cada dia permanecem iguais.
func _carregar_ou_criar_semente_mundo_celeste(caminho: String = CAMINHO_SEMENTE_MUNDO_CELESTE) -> int:
	if FileAccess.file_exists(caminho):
		var arquivo_existente := FileAccess.open(caminho, FileAccess.READ)
		if arquivo_existente != null:
			var dados = JSON.parse_string(arquivo_existente.get_as_text())
			arquivo_existente.close()
			if dados is Dictionary:
				var semente_salva := int(dados.get("semente", 0))
				if semente_salva > 0:
					return semente_salva
			push_warning("Semente celeste ausente ou inválida; uma nova semente será criada.")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var nova_semente := maxi(1, int(rng.randi()))
	var diretorio := ProjectSettings.globalize_path(caminho.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(diretorio) != OK and not DirAccess.dir_exists_absolute(diretorio):
		push_error("Não foi possível criar o diretório para persistir a semente do mundo.")
		return nova_semente
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível persistir a semente do mundo celeste.")
		return nova_semente
	arquivo.store_string(JSON.stringify({"versao":1,"semente":nova_semente}))
	arquivo.flush()
	var erro_gravacao := arquivo.get_error()
	arquivo.close()
	if erro_gravacao != OK:
		push_error("Falha ao gravar a semente persistente do mundo.")
	return nova_semente

@rpc("authority", "call_remote", "reliable")
func _receber_anuncio_celeste(anuncio: Dictionary) -> void:
	anuncio_celeste_recebido.emit(anuncio.duplicate(true))

@rpc("authority", "call_remote", "unreliable_ordered")
func _receber_relogio_mundo(contexto: Dictionary) -> void:
	if str(contexto.get("mundoId", "")) != SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO or str(contexto.get("escopo", "")) != "global":
		return
	relogio_mundo_atualizado.emit(contexto.duplicate(true))

## Resolve e concede qualquer tabela de recompensas originada pelo servidor.
## Não é RPC: o cliente nunca escolhe tabela, chance, contexto ou resultado.
func concluir_atividade_e_conceder_recompensas(peer_id: int, origem_id: String, tabela: Array, contexto_atividade: Dictionary = {}) -> Array:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		return []
	if not bool(_perfil_por_peer[peer_id].get("personagemCriado", false)):
		return []
	if origem_id.strip_edges().is_empty() or not SistemaDrops.validar_tabela(tabela):
		push_warning("Tabela de recompensas inválida; concessão bloqueada.")
		return []
	var contexto := contexto_atividade.duplicate(true)
	# A semente é criada exclusivamente no servidor.
	contexto["semente"] = int(Time.get_ticks_usec()) ^ (peer_id * 7919)
	var resultados: Array = SistemaDrops.resolver_tabela(tabela, origem_id, contexto)
	var obtidos: Array = []
	for tentativa in resultados:
		if bool(tentativa.get("obtido", false)):
			obtidos.append(tentativa)
	if obtidos.is_empty():
		return resultados
	var uid := str(_uid_por_peer[peer_id])
	if not _repositorio_perfis.conceder_drops(uid, obtidos):
		push_error("Falha ao persistir recompensa para o jogador autenticado.")
		return []
	var perfil_atualizado: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
	if perfil_atualizado.is_empty():
		return []
	_perfil_por_peer[peer_id] = perfil_atualizado
	rpc_id(peer_id, "_receber_perfil_personagem", perfil_atualizado)
	return resultados


## Ponto de integração interno para o futuro fluxo de conclusão de missões.
## Não é RPC: apenas o servidor pode confirmar e pagar uma missão.
## Compatibilidade com chamadas antigas: a dificuldade recebida é ignorada.
## A dificuldade válida é lida do registro persistido pelo serviço de missões.
func concluir_missao_e_conceder_recompensa(peer_id: int, missao_id: String, _dificuldade: String = "") -> Dictionary:
	return concluir_missao_mundo(peer_id, missao_id)

## O combate usa o mesmo motor universal de recompensas.
func concluir_combate_e_conceder_drops(peer_id: int, criatura: Dictionary, contexto_batalha: Dictionary = {}) -> Array:
	var perfil: Dictionary = _perfil_por_peer.get(peer_id, {})
	var contexto := contexto_batalha.duplicate(true)
	contexto["classeId"] = str(perfil.get("classeId", ""))
	contexto["sorte"] = float(perfil.get("sorte", 0.0))
	var tabela: Array = criatura.get("tabelaDrops", []).duplicate(true)
	var entrada_moeda := SistemaDrops.criar_entrada_moeda_criatura(criatura, contexto)
	if not entrada_moeda.is_empty():
		tabela.append(entrada_moeda)
	if str(perfil.get("classeId", "")) != "invocador":
		var ovo := SistemaDrops.criar_entrada_ovo(criatura)
		if not ovo.is_empty():
			tabela.append(ovo)
	return concluir_atividade_e_conceder_recompensas(
		peer_id,
		str(criatura.get("id", "")),
		tabela,
		contexto
	)


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
