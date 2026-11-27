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
signal eventos_mundo_atualizados(eventos: Array)
signal estado_serpente_mundo_atualizado(estado: Dictionary)
signal resultado_filhote_serpente(sucesso: bool, mensagem: String, invocacao: Dictionary)
signal sala_atualizada(dados: Dictionary)
signal aventura_sala_atualizada(dados: Dictionary)
signal resultado_mensagem_aventura(sucesso: bool, mensagem: String)
signal resultado_interacao_criatura(sucesso: bool, mensagem: String)
signal mimicos_recebidos(mimicos: Array)
signal resultado_convite_ally(sucesso: bool, mensagem: String)
signal proposta_troca_recebida(proposta: Dictionary)
signal resultado_troca(sucesso: bool, mensagem: String)
signal convite_pvp_recebido(convite: Dictionary)
signal resultado_pvp(sucesso: bool, mensagem: String)
signal convite_ally_recebido(convite: Dictionary)
signal ally_atualizada(ally: Dictionary)
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
const REPOSITORIO_MIMICOS = preload("res://scripts/repositorio_mimicos_servidor.gd")
const REPOSITORIO_PIEDADE_MIMICOS = preload("res://scripts/repositorio_piedade_mimicos.gd")
const SISTEMA_MIMICOS = preload("res://scripts/sistema_mimicos.gd")
const CATALOGO_ARMAS_ONE_PIECE = preload("res://scripts/catalogo_armas_one_piece.gd")
const SERVICO_MISSOES_MUNDO = preload("res://scripts/servico_missoes_mundo_servidor.gd")
const SistemaDrops = preload("res://scripts/sistema_drops.gd")
const SistemaEquipamentos = preload("res://scripts/sistema_equipamentos.gd")
const SistemaCombate = preload("res://scripts/sistema_combate.gd")
const SistemaDueloPvP = preload("res://scripts/sistema_duelo_pvp.gd")
const SistemaCombateCooperativo = preload("res://scripts/sistema_combate_cooperativo.gd")
const SISTEMA_INVOCACOES = preload("res://scripts/sistema_invocacoes.gd")
const SISTEMA_CICLO_NOTURNO = preload("res://scripts/sistema_ciclo_noturno.gd")
const SISTEMA_EVENTOS_MUNDO = preload("res://scripts/sistema_eventos_mundo.gd")
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
const REPOSITORIO_SERPENTE = preload("res://scripts/repositorio_serpente_mundo_servidor.gd")
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
const CAMINHO_ALLYS := "user://dados/ally_persistentes.json"
const DISTANCIA_TROCA := 110.0
const DURACAO_PROPOSTA_TROCA_MS := 30000
const INTERVALO_PROPOSTA_TROCA_MS := 2000
const LIMITE_PROPOSTAS_TROCA_PENDENTES := 100
const DISTANCIA_PVP := 110.0
const DURACAO_CONVITE_PVP_MS := 30000
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
var _propostas_troca: Dictionary = {}
var _ultima_proposta_troca_ms: Dictionary = {}
var _convites_pvp: Dictionary = {}
var _ultimo_convite_pvp_ms: Dictionary = {}
var _duelos_pvp: Dictionary = {}
var _duelo_por_peer: Dictionary = {}
var _validacoes_em_andamento: Dictionary = {}
var porta_servidor: int = PORTA_PADRAO
var _peer: ENetMultiplayerPeer
var _jogadores_no_mundo: Dictionary = {}
var _ultimo_pacote_posicao_ms: Dictionary = {}
var _local_visitado_atual_por_peer: Dictionary = {}
var _ultimo_evento_visita_por_peer: Dictionary = {}
var _perfil_por_peer: Dictionary = {}
var _repositorio_perfis = REPOSITORIO_PERFIL.new()
var _repositorio_mimicos = REPOSITORIO_MIMICOS.new()
var _revisao_mimicos_remota := 0
var _snapshot_mimicos_remoto := ""
var _mimicos_gravacao_remota_em_andamento := false
var _revisao_piedade_mimicos_remota := 0
var _snapshot_piedade_mimicos_remoto := ""
var _piedade_mimicos_gravacao_remota_em_andamento := false
var mimicos_publicos_cache: Array = []
var _repositorio_piedade_mimicos = REPOSITORIO_PIEDADE_MIMICOS.new()
var _servico_missoes_mundo = null
var _ultima_gravacao_ms: Dictionary = {}
var _combates_por_peer: Dictionary = {}
var _ultima_acao_combate_ms: Dictionary = {}
var _repositorio_criaturas = REPOSITORIO_CRIATURAS.new()
var _revisao_catalogo_criaturas_remota := 0
var _snapshot_catalogo_criaturas_remoto := ""
var _ultima_gravacao_catalogo_criaturas_ms := 0
var _catalogo_criaturas_gravacao_em_andamento := false
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
var _eventos_mundo_payload: Dictionary = SISTEMA_EVENTOS_MUNDO.criar_documento()
var _revisao_eventos_mundo_remota := 0
var _ultima_verificacao_eventos_ms := 0
var _eventos_mundo_gravacao_em_andamento := false
const INTERVALO_VERIFICACAO_EVENTOS_MS := 10000
var _estado_serpente_mundo_publico: Dictionary = {}
var _ultima_revisao_estado_serpente_recebida: int = -1
var _ultima_limpeza_marcas_destruicao_unix := 0
var _ultimo_ataque_serpente_ms: int = 0
var _ultimo_descanso_clareira_ms: Dictionary = {}
const SISTEMA_SALAS = preload("res://scripts/sistema_salas_multiplayer.gd")
const REPOSITORIO_SALAS = preload("res://scripts/repositorio_salas_multiplayer_servidor.gd")
var _salas_publicas = SISTEMA_SALAS.new()
var _repositorio_salas = REPOSITORIO_SALAS.new()
var _repositorio_serpente = REPOSITORIO_SERPENTE.new(CAMINHO_ESTADO_SERPENTE)
var _repositorio_mundo_remoto = null
var _revisao_serpente_remota := 0
var _revisao_relogio_remota := 0
var _revisao_recursos_ecologicos_remota := 0
var _snapshot_recursos_ecologicos_remoto := ""
var _revisao_salas_remota := 0
var _salas_gravacao_remota_em_andamento := false
var _revisao_ally_remota := 0
var _ally_gravacao_remota_em_andamento := false
var _revisoes_fauna_remotas: Dictionary = {}
var _revisoes_perfil_remotas: Dictionary = {}
var _perfis_gravacao_remota_em_andamento: Dictionary = {}
var _duelos_pvp_liquidando: Dictionary = {}
var _perfis_globais_pendentes: Dictionary = {}
var _snapshots_fauna_remotos: Dictionary = {}
var _fauna_gravacao_remota_em_andamento := false
var _recursos_gravacao_remota_em_andamento := false
var _ciclo_alimentar_em_andamento := false
var _serpente_gravacao_em_andamento := false
var acao_sala_cliente: String = "mundo"
var codigo_sala_cliente: String = ""
var _intencao_sala_por_peer: Dictionary = {}
var _convites_ally: Dictionary = {}
var _ultimo_convite_ally_ms: Dictionary = {}
var _ally_por_uid: Dictionary = {}
var _ally_ativa: Dictionary = {}
const DISTANCIA_CONVITE_ALLY := 150.0
const DURACAO_CONVITE_ALLY_MS := 30000
const LIMITE_MEMBROS_ALLY := 4

func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	var agora := Time.get_ticks_msec()
	_atualizar_ciclo_celeste_autoritativo()
	if agora - _ultima_verificacao_eventos_ms >= INTERVALO_VERIFICACAO_EVENTOS_MS:
		await _atualizar_eventos_mundo(agora)
	_atualizar_criaturas_persistentes(agora)
	if agora - _ultima_gravacao_catalogo_criaturas_ms >= 10000:
		await _sincronizar_catalogo_criaturas_global()
	await _atualizar_grupos_selvagens(agora)
	await _atualizar_incursao_serpente(agora)
	_limpar_convites_ally_expirados(agora)
	_limpar_convites_pvp_expirados(agora)
	_limpar_propostas_troca_expiradas(agora)
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

var _persistencia_encerramento_executada := false
var _persistencia_encerramento_em_andamento := false
var _encerrando_persistencia_global := false
var _perfis_globais_confirmados_encerramento := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_persistir_estado_antes_de_encerrar()

## Última barreira de persistência para encerramento normal do processo.
## Não depende de RPC: o estado precisa estar no disco antes de fechar ENet.
## Se algum repositório falhar, permite nova tentativa em outra notificação.
func _persistir_estado_antes_de_encerrar() -> bool:
	if _persistencia_encerramento_executada:
		return true
	if _persistencia_encerramento_em_andamento:
		return false
	if multiplayer == null or not multiplayer.is_server():
		return true
	_persistencia_encerramento_em_andamento = true
	var sucesso := true
	if not _perfis_globais_confirmados_encerramento:
		for peer_id_var in _perfil_por_peer.keys().duplicate():
			if not _salvar_perfil_jogador(int(peer_id_var)):
				sucesso = false
	var agora_unix := int(Time.get_unix_time_from_system())
	# Persiste a posição final da fauna antes de fechar o host. A sincronização
	# remota periódica continua sendo a fonte global; esta gravação protege o
	# último estado local confirmado caso o processo seja encerrado entre ticks.
	for grupo_id_var in _grupos_mundo_cache.keys():
		var grupo_id := str(grupo_id_var)
		var grupo: Dictionary = _grupos_mundo_cache[grupo_id]
		if not _repositorio_grupos.salvar_movimento_grupo(grupo_id, grupo.get("individuos", []), agora_unix):
			sucesso = false
	if not _estado_serpente_mundo.is_empty():
		_estado_serpente_mundo["atualizadoUnix"] = agora_unix
		if not _repositorio_serpente.salvar(_estado_serpente_mundo):
			sucesso = false
	if not _salvar_salas_persistentes():
		sucesso = false
	if not _salvar_ally_persistentes():
		sucesso = false
	_persistencia_encerramento_em_andamento = false
	_persistencia_encerramento_executada = sucesso
	if not sucesso:
		push_error("Encerramento do servidor detectou falha ao persistir um ou mais dados críticos; uma nova tentativa será permitida.")
	return sucesso

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

func configurar_persistencia_mundo_remota(repositorio) -> void:
	_repositorio_mundo_remoto = repositorio
	_revisao_serpente_remota = 0
	_revisao_relogio_remota = 0
	_revisao_piedade_mimicos_remota = 0
	_snapshot_piedade_mimicos_remoto = ""
	_piedade_mimicos_gravacao_remota_em_andamento = false
	_revisao_recursos_ecologicos_remota = 0
	_snapshot_recursos_ecologicos_remoto = ""
	_revisao_salas_remota = 0
	_salas_gravacao_remota_em_andamento = false
	_revisoes_fauna_remotas.clear()
	_revisoes_perfil_remotas.clear()
	_perfis_gravacao_remota_em_andamento.clear()
	_perfis_globais_pendentes.clear()
	_snapshots_fauna_remotos.clear()	


## Cada conta tem um documento privado derivado por SHA-256 do UID.
## A revisão remota é independente da revisão local do perfil.
func _chave_documento_personagem(uid: String) -> String:
	return REPOSITORIO_PERFIL.chave_documento_global(uid)

func _carregar_perfil_global(uid: String) -> bool:
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		return false
	var chave := _chave_documento_personagem(uid)
	if chave.is_empty():
		return false
	var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento(chave)
	if not bool(remoto.get("ok", false)):
		push_error("Falha ao carregar perfil global: " + str(remoto.get("erro", "")))
		return false
	var revisao := int(remoto.get("revisao", -1))
	if revisao < 0:
		return false
	if revisao > 0:
		if not _repositorio_perfis.importar_perfil_persistente(uid, remoto.get("payload", null)):
			push_error("Perfil remoto inválido para a conta autenticada; entrada bloqueada.")
			return false
		_revisoes_perfil_remotas[uid] = revisao
		return true
	# Migração inicial: primeiro valida o perfil local e depois cria o documento remoto via CAS.
	var perfil_local := _repositorio_perfis.carregar_ou_criar(uid)
	if perfil_local.is_empty():
		return false
	var snapshot := _repositorio_perfis.exportar_perfil_persistente(uid)
	if snapshot.is_empty():
		return false
	var gravacao: Dictionary = await _repositorio_mundo_remoto.salvar_documento(chave, snapshot, 0)
	if not bool(gravacao.get("ok", false)):
		push_error("Não foi possível migrar o perfil para D1: " + str(gravacao.get("erro", "")))
		return false
	revisao = int(gravacao.get("revisao", -1))
	if revisao <= 0:
		return false
	_revisoes_perfil_remotas[uid] = revisao
	return true

## Persiste o snapshot local já validado. Escritas por UID são serializadas; se o
## perfil mudar durante o HTTP, uma nova rodada grava a versão mais recente.
func _sincronizar_perfil_global(uid: String, snapshot: Dictionary = {}) -> bool:
	if uid.is_empty() or _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		return false
	# Se já existe uma gravação para esta conta, registra explicitamente que
	# houve nova alteração. A gravação ativa fará outra rodada mesmo se o peer
	# desconectar antes da resposta HTTP.
	if _perfis_gravacao_remota_em_andamento.has(uid):
		_perfis_globais_pendentes[uid] = true
		return true
	var chave := _chave_documento_personagem(uid)
	var revisao := int(_revisoes_perfil_remotas.get(uid, -1))
	if chave.is_empty() or revisao < 0:
		encerrar_servidor_por_falha_persistencia_global("Perfil sem chave ou revisão remota: " + uid)
		return false
	# Sempre exporta a revisão local mais recente; um snapshot capturado antes
	# de entrar na fila nunca pode fazer a gravação regredir.
	var snapshot_atual: Dictionary = _repositorio_perfis.exportar_perfil_persistente(uid)
	if snapshot_atual.is_empty():
		encerrar_servidor_por_falha_persistencia_global("Snapshot local inválido para o perfil " + uid)
		return false
	var perfil_enviado: Dictionary = snapshot_atual.get("perfil", {})
	var revisao_perfil_enviada := int(perfil_enviado.get("revisaoServidor", -1))
	if revisao_perfil_enviada < 0:
		encerrar_servidor_por_falha_persistencia_global("Revisão local inválida para o perfil " + uid)
		return false
	_perfis_globais_pendentes.erase(uid)
	_perfis_gravacao_remota_em_andamento[uid] = true
	var gravacao: Dictionary = await _repositorio_mundo_remoto.salvar_documento(chave, snapshot_atual, revisao)
	_perfis_gravacao_remota_em_andamento.erase(uid)
	if not bool(gravacao.get("ok", false)):
		encerrar_servidor_por_falha_persistencia_global("Falha ao confirmar perfil global: " + str(gravacao.get("erro", "")))
		return false
	var nova_revisao := int(gravacao.get("revisao", -1))
	if nova_revisao <= revisao:
		encerrar_servidor_por_falha_persistencia_global("Revisão inválida ao salvar perfil global.")
		return false
	_revisoes_perfil_remotas[uid] = nova_revisao
	# Não depende de o jogador continuar conectado: compara o banco local
	# validado com o snapshot que acabou de ser confirmado no D1.
	var snapshot_mais_recente: Dictionary = _repositorio_perfis.exportar_perfil_persistente(uid)
	var perfil_mais_recente: Dictionary = snapshot_mais_recente.get("perfil", {})
	var revisao_mais_recente := int(perfil_mais_recente.get("revisaoServidor", -1))
	var precisa_repetir := _perfis_globais_pendentes.has(uid) or revisao_mais_recente > revisao_perfil_enviada
	_perfis_globais_pendentes.erase(uid)
	if precisa_repetir:
		call_deferred("_sincronizar_perfil_global", uid)
	return true

## Aguarda uma escrita anterior do mesmo UID terminar antes de confirmar uma
## recompensa/alteração crítica. Evita tratar a marcação de pendência como commit.
func _confirmar_perfil_global(uid: String) -> bool:
	if uid.is_empty():
		return false
	var quadros_espera := 0
	while _perfis_gravacao_remota_em_andamento.has(uid):
		if _encerrando_persistencia_global or quadros_espera >= 600:
			return false
		quadros_espera += 1
		await get_tree().process_frame
	return await _sincronizar_perfil_global(uid)

## Reserva os dois perfis antes de qualquer mutação local. A reserva é atômica
## no loop do servidor: nenhuma coroutine pode intercalar entre a checagem e a marcação.
func _bloquear_perfis_para_transacao(uid_a: String, uid_b: String) -> bool:
	if uid_a.is_empty() or uid_b.is_empty() or uid_a == uid_b:
		return false
	var quadros_espera := 0
	while _perfis_gravacao_remota_em_andamento.has(uid_a) or _perfis_gravacao_remota_em_andamento.has(uid_b):
		if _encerrando_persistencia_global or quadros_espera >= 600:
			return false
		quadros_espera += 1
		await get_tree().process_frame
	if _encerrando_persistencia_global:
		return false
	_perfis_gravacao_remota_em_andamento[uid_a] = true
	_perfis_gravacao_remota_em_andamento[uid_b] = true
	return true

## Serializa alterações que afetam dois perfis. Enquanto a transação está no D1,
## gravações comuns desses UIDs viram pendências e são drenadas antes do sucesso.
func _confirmar_transacao_perfis_globais(transacao_id: String, uid_a: String, uid_b: String, bloqueios_pre_adquiridos: bool = false) -> Dictionary:
	if uid_a.is_empty() or uid_b.is_empty() or uid_a == uid_b or transacao_id.length() != 32 or not transacao_id.is_valid_hex_number(false):
		# Troca/PvP já podem ter alterado os snapshots locais antes desta etapa.
		# Libera reservas adquiridas pelo chamador e fecha o host para impedir
		# que essas alterações sejam tratadas como confirmadas sem transação D1.
		if bloqueios_pre_adquiridos:
			if not uid_a.is_empty():
				_perfis_gravacao_remota_em_andamento.erase(uid_a)
			if not uid_b.is_empty():
				_perfis_gravacao_remota_em_andamento.erase(uid_b)
		encerrar_servidor_por_falha_persistencia_global("Identificadores inválidos para transação bilateral.")
		return {"ok":false,"erro":"Identificadores inválidos para transação bilateral."}
	if bloqueios_pre_adquiridos:
		if not _perfis_gravacao_remota_em_andamento.has(uid_a) or not _perfis_gravacao_remota_em_andamento.has(uid_b):
			encerrar_servidor_por_falha_persistencia_global("Reserva bilateral perdida antes da persistência.")
			return {"ok":false,"erro":"Reserva bilateral perdida antes da persistência."}
	else:
		if not await _bloquear_perfis_para_transacao(uid_a, uid_b):
			return {"ok":false,"erro":"Tempo esgotado aguardando os perfis para a transação."}
	var snapshot_a: Dictionary = _repositorio_perfis.exportar_perfil_persistente(uid_a)
	var snapshot_b: Dictionary = _repositorio_perfis.exportar_perfil_persistente(uid_b)
	var chave_a := _chave_documento_personagem(uid_a)
	var chave_b := _chave_documento_personagem(uid_b)
	var revisao_a := int(_revisoes_perfil_remotas.get(uid_a, -1))
	var revisao_b := int(_revisoes_perfil_remotas.get(uid_b, -1))
	var perfil_a: Dictionary = snapshot_a.get("perfil", {})
	var perfil_b: Dictionary = snapshot_b.get("perfil", {})
	var revisao_local_a := int(perfil_a.get("revisaoServidor", -1))
	var revisao_local_b := int(perfil_b.get("revisaoServidor", -1))
	if snapshot_a.is_empty() or snapshot_b.is_empty() or chave_a.is_empty() or chave_b.is_empty() or revisao_a < 1 or revisao_b < 1 or revisao_local_a < 0 or revisao_local_b < 0:
		_perfis_gravacao_remota_em_andamento.erase(uid_a)
		_perfis_gravacao_remota_em_andamento.erase(uid_b)
		encerrar_servidor_por_falha_persistencia_global("Snapshot ou revisão inválida na transação bilateral.")
		return {"ok":false,"erro":"Não foi possível preparar os dois perfis."}
	var confirmacao: Dictionary = await _repositorio_mundo_remoto.salvar_troca_personagens_atomica(transacao_id, chave_a, snapshot_a, revisao_a, chave_b, snapshot_b, revisao_b)
	_perfis_gravacao_remota_em_andamento.erase(uid_a)
	_perfis_gravacao_remota_em_andamento.erase(uid_b)
	if not bool(confirmacao.get("ok", false)):
		encerrar_servidor_por_falha_persistencia_global("Falha na transação bilateral: " + str(confirmacao.get("erro", "")))
		return {"ok":false,"erro":str(confirmacao.get("erro","Transação global recusada."))}
	var nova_a := int(confirmacao.get("revisaoA", -1))
	var nova_b := int(confirmacao.get("revisaoB", -1))
	if nova_a <= revisao_a or nova_b <= revisao_b:
		encerrar_servidor_por_falha_persistencia_global("A transação bilateral não retornou as duas revisões.")
		return {"ok":false,"erro":"Revisões globais inválidas após a transação."}
	_revisoes_perfil_remotas[uid_a] = nova_a
	_revisoes_perfil_remotas[uid_b] = nova_b
	var uid_lista := [uid_a, uid_b]
	var revisoes_enviadas := {uid_a:revisao_local_a, uid_b:revisao_local_b}
	for uid in uid_lista:
		var snapshot_recente: Dictionary = _repositorio_perfis.exportar_perfil_persistente(uid)
		var perfil_recente: Dictionary = snapshot_recente.get("perfil", {})
		var revisao_recente := int(perfil_recente.get("revisaoServidor", -1))
		var pendente := _perfis_globais_pendentes.has(uid) or revisao_recente > int(revisoes_enviadas[uid])
		_perfis_globais_pendentes.erase(uid)
		if pendente and not await _confirmar_perfil_global(uid):
			return {"ok":false,"erro":"Uma alteração posterior do personagem não foi confirmada."}
	return {"ok":true,"revisaoA":nova_a,"revisaoB":nova_b,"replayed":bool(confirmacao.get("replayed",false))}

## Chamado pelo entrypoint antes de liberar a lease no desligamento normal.
func sincronizar_perfis_globais_antes_de_encerrar() -> bool:
	if not multiplayer.is_server():
		return true
	_encerrando_persistencia_global = true
	var sucesso := true
	for peer_var in _uid_por_peer.keys():
		var peer_id := int(peer_var)
		var uid := str(_uid_por_peer[peer_id])
		var inicio_espera := Time.get_ticks_msec()
		while _perfis_gravacao_remota_em_andamento.has(uid) and Time.get_ticks_msec() - inicio_espera < 22000:
			await get_tree().process_frame
		if _perfis_gravacao_remota_em_andamento.has(uid):
			sucesso = false
			continue
		if not _salvar_perfil_jogador(peer_id):
			sucesso = false
			continue
		if not await _confirmar_perfil_global(uid):
			sucesso = false
	_perfis_globais_confirmados_encerramento = sucesso
	return sucesso

## Carrega estoques ambientais globais antes de simular qualquer grupo selvagem.
## A revisão zero permite uma única importação do cache local; depois D1 prevalece.
## Carrega 16 fragmentos independentes antes de expor ENet. A revisão zero
## importa somente o fragmento local correspondente; revisões existentes sempre prevalecem.
func _chave_fragmento_fauna(indice: int) -> String:
	return "wildlife_groups_%02x" % indice

func _carregar_fauna_global() -> bool:
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		push_error("Fauna global sem repositório remoto ou lease ativa.")
		return false
	_revisoes_fauna_remotas.clear()
	_snapshots_fauna_remotos.clear()
	for indice in range(REPOSITORIO_GRUPOS.QUANTIDADE_FRAGMENTOS_GLOBAIS):
		var chave := _chave_fragmento_fauna(indice)
		var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento(chave)
		if not _repositorio_mundo_remoto.lease_ativa:
			push_error("Lease global perdida durante a recuperação do fragmento " + chave + ".")
			return false
		if not bool(remoto.get("ok", false)):
			push_error("Falha ao carregar fragmento global da fauna " + chave + ": " + str(remoto.get("erro", "")))
			return false
		var revisao := int(remoto.get("revisao", -1))
		if revisao < 0:
			return false
		var snapshot: Dictionary
		if revisao > 0:
			snapshot = remoto.get("payload", {})
			if not _repositorio_grupos.importar_fragmento_global(snapshot, indice):
				push_error("Fragmento remoto inválido; fauna local não será usada como substituta: " + chave)
				return false
		else:
			snapshot = _repositorio_grupos.exportar_fragmento_global(indice)
			if snapshot.is_empty():
				push_error("Fragmento local inválido; migração bloqueada: " + chave)
				return false
			# A migração inicial é adiada; recursos + todos os fragmentos serão
			# criados juntos no primeiro commit atômico do mundo.
			revisao = 0
		_revisoes_fauna_remotas[chave] = revisao
		_snapshots_fauna_remotos[chave] = JSON.stringify(snapshot)
	return true

## Sincroniza somente fragmentos alterados. Cada fragmento tem CAS próprio e o host
## fecha se qualquer gravação falhar, evitando continuar com ecossistemas divergentes.
func _sincronizar_fauna_global(forcar: bool = false) -> bool:
	if _fauna_gravacao_remota_em_andamento:
		return false
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		return false
	var documentos_fauna: Array = []
	var houve_alteracao := forcar
	for indice in range(REPOSITORIO_GRUPOS.QUANTIDADE_FRAGMENTOS_GLOBAIS):
		var chave := _chave_fragmento_fauna(indice)
		var snapshot := _repositorio_grupos.exportar_fragmento_global(indice)
		if snapshot.is_empty():
			encerrar_servidor_por_falha_persistencia_global("Snapshot local inválido no fragmento " + chave + ".")
			return false
		var serializado := JSON.stringify(snapshot)
		if serializado != str(_snapshots_fauna_remotos.get(chave, "")):
			houve_alteracao = true
		var revisao := int(_revisoes_fauna_remotas.get(chave, -1))
		if revisao < 0:
			encerrar_servidor_por_falha_persistencia_global("Revisão remota ausente para " + chave + ".")
			return false
		documentos_fauna.append({
			"key":chave,
			"expectedRevision":revisao,
			"payload":snapshot
		})
	if not houve_alteracao:
		return true
	var payload_recursos: Variant = JSON.parse_string(_snapshot_recursos_ecologicos_remoto)
	if not (payload_recursos is Dictionary) or payload_recursos.is_empty():
		payload_recursos = _repositorio_recursos_ecologicos.exportar_estado_persistente(int(Time.get_unix_time_from_system()))
	if not (payload_recursos is Dictionary) or payload_recursos.is_empty():
		encerrar_servidor_por_falha_persistencia_global("Snapshot de recursos ausente durante o commit ecológico.")
		return false
	var crypto := Crypto.new()
	var bytes_transacao := crypto.generate_random_bytes(16)
	if bytes_transacao.size() != 16:
		encerrar_servidor_por_falha_persistencia_global("Não foi possível gerar o identificador do ciclo ecológico.")
		return false
	_fauna_gravacao_remota_em_andamento = true
	var confirmacao: Dictionary = await _repositorio_mundo_remoto.salvar_ciclo_ecologico_atomico(
		bytes_transacao.hex_encode(),
		payload_recursos,
		_revisao_recursos_ecologicos_remota,
		documentos_fauna
	)
	_fauna_gravacao_remota_em_andamento = false
	if not bool(confirmacao.get("ok", false)):
		encerrar_servidor_por_falha_persistencia_global("Falha ao confirmar ciclo ecológico atômico: " + str(confirmacao.get("erro", "")))
		return false
	_revisao_recursos_ecologicos_remota = int(confirmacao.get("revisaoRecursos", -1))
	if _revisao_recursos_ecologicos_remota <= 0:
		encerrar_servidor_por_falha_persistencia_global("Revisão dos recursos inválida após o commit ecológico.")
		return false
	var revisoes_fauna: Dictionary = confirmacao.get("revisoesFauna", {})
	for documento in documentos_fauna:
		var chave := str(documento.get("key", ""))
		var nova_revisao := int(revisoes_fauna.get(chave, -1))
		if nova_revisao <= int(documento.get("expectedRevision", -1)):
			encerrar_servidor_por_falha_persistencia_global("Revisão inválida após confirmar " + chave + ".")
			return false
		_revisoes_fauna_remotas[chave] = nova_revisao
		_snapshots_fauna_remotos[chave] = JSON.stringify(documento.get("payload", {}))
	_snapshot_recursos_ecologicos_remoto = JSON.stringify(payload_recursos)
	return true

## O catálogo de espécies é global: um host novo não pode depender do JSON local anterior.
func _carregar_catalogo_criaturas_global() -> bool:
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		push_error("Catálogo de criaturas exige armazenamento remoto e lease global.")
		return false
	var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento("creatures")
	if not _repositorio_mundo_remoto.lease_ativa:
		push_error("Lease global perdida durante a recuperação do catálogo de criaturas.")
		return false
	if not bool(remoto.get("ok", false)):
		push_error("Não foi possível carregar o catálogo global de criaturas: " + str(remoto.get("erro", "")))
		return false
	var revisao := int(remoto.get("revisao", -1))
	if revisao < 0:
		return false
	if revisao > 0:
		if not _repositorio_criaturas.importar_estado_persistente(remoto.get("payload", null)):
			push_error("Catálogo remoto de criaturas inválido; inicialização bloqueada para proteger o mundo.")
			return false
		_revisao_catalogo_criaturas_remota = revisao
	else:
		var legado := _repositorio_criaturas.exportar_estado_persistente()
		if legado.is_empty():
			push_error("Catálogo local inválido ou acima do limite; migração global bloqueada.")
			return false
		var migracao: Dictionary = await _repositorio_mundo_remoto.salvar_documento("creatures", legado, 0)
		if not bool(migracao.get("ok", false)):
			push_error("Migração inicial do catálogo de criaturas falhou: " + str(migracao.get("erro", "")))
			return false
		_revisao_catalogo_criaturas_remota = int(migracao.get("revisao", -1))
		if _revisao_catalogo_criaturas_remota <= 0:
			return false
	_snapshot_catalogo_criaturas_remoto = JSON.stringify(_repositorio_criaturas.exportar_estado_persistente())
	return not _snapshot_catalogo_criaturas_remoto.is_empty() and _snapshot_catalogo_criaturas_remoto != "{}"

## Confirma o catálogo completo por revisão CAS. Conflito ou falha encerra o host.
func _sincronizar_catalogo_criaturas_global() -> bool:
	if _catalogo_criaturas_gravacao_em_andamento:
		return false
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		encerrar_servidor_por_falha_persistencia_global("Lease ausente ao sincronizar catálogo de criaturas.")
		return false
	var snapshot := _repositorio_criaturas.exportar_estado_persistente()
	if snapshot.is_empty():
		encerrar_servidor_por_falha_persistencia_global("Catálogo de criaturas inválido ou acima do limite remoto.")
		return false
	var serializado := JSON.stringify(snapshot)
	if serializado == _snapshot_catalogo_criaturas_remoto:
		_ultima_gravacao_catalogo_criaturas_ms = Time.get_ticks_msec()
		return true
	_catalogo_criaturas_gravacao_em_andamento = true
	var gravacao: Dictionary = await _repositorio_mundo_remoto.salvar_documento("creatures", snapshot, _revisao_catalogo_criaturas_remota)
	_catalogo_criaturas_gravacao_em_andamento = false
	if not bool(gravacao.get("ok", false)):
		encerrar_servidor_por_falha_persistencia_global("Falha ao confirmar catálogo global de criaturas: " + str(gravacao.get("erro", "")))
		return false
	var nova_revisao := int(gravacao.get("revisao", -1))
	if nova_revisao <= _revisao_catalogo_criaturas_remota:
		encerrar_servidor_por_falha_persistencia_global("Revisão inválida ao salvar catálogo global de criaturas.")
		return false
	_revisao_catalogo_criaturas_remota = nova_revisao
	_snapshot_catalogo_criaturas_remoto = serializado
	_ultima_gravacao_catalogo_criaturas_ms = Time.get_ticks_msec()
	return true

func _carregar_recursos_ecologicos_globais() -> bool:
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		push_error("Recursos ecológicos sem repositório remoto ou lease global.")
		return false
	var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento("ecological_resources")
	if not _repositorio_mundo_remoto.lease_ativa:
		push_error("Lease global perdida durante a recuperação dos recursos ecológicos.")
		return false
	if not bool(remoto.get("ok", false)):
		push_error("Não foi possível ler os recursos ecológicos globais: " + str(remoto.get("erro", "")))
		return false
	var revisao := int(remoto.get("revisao", -1))
	if revisao < 0:
		return false
	if revisao > 0:
		if not _repositorio_recursos_ecologicos.importar_estado_persistente(remoto.get("payload", null)):
			push_error("Documento ecológico remoto inválido; estado global preservado sem substituição.")
			return false
		_revisao_recursos_ecologicos_remota = revisao
		_snapshot_recursos_ecologicos_remoto = JSON.stringify(remoto.get("payload", {}))
		return true
	var snapshot_local := _repositorio_recursos_ecologicos.exportar_estado_persistente(int(Time.get_unix_time_from_system()))
	if snapshot_local.is_empty():
		push_error("Cache ecológico local inválido; migração inicial bloqueada.")
		return false
	if not _repositorio_recursos_ecologicos.importar_estado_persistente(snapshot_local):
		push_error("Não foi possível validar o cache ecológico antes da migração.")
		return false
	# Não cria este documento isoladamente: o bootstrap inicial será atômico
	# com os 16 fragmentos da fauna no primeiro commit do ciclo global.
	_revisao_recursos_ecologicos_remota = 0
	_snapshot_recursos_ecologicos_remoto = JSON.stringify(snapshot_local)
	return true


func iniciar_servidor(porta: int = PORTA_PADRAO, maximo_jogadores: int = MAXIMO_JOGADORES_PADRAO, lease_global_confirmada: bool = false) -> Error:
	if not lease_global_confirmada:
		return _falhar("O servidor dedicado precisa adquirir a lease do mundo global antes de abrir a porta ENet.")
	if porta < 1 or porta > 65535:
		return _falhar("A porta informada é inválida.")
	if maximo_jogadores < 1 or maximo_jogadores > MAXIMO_JOGADORES_PADRAO:
		return _falhar("O limite de jogadores deve ficar entre 1 e %d." % MAXIMO_JOGADORES_PADRAO)
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

	porta_servidor = porta
	if not await _carregar_salas_persistentes():
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	if not await _carregar_ally_persistentes():
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	if not await _carregar_catalogo_criaturas_global():
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	_servico_missoes_mundo = SERVICO_MISSOES_MUNDO.new(_repositorio_perfis)
	_carregar_criaturas_persistentes()
	if not await _carregar_estado_serpente_mundo():
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	if not await _carregar_recursos_ecologicos_globais():
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	if not await _carregar_fauna_global():
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	_carregar_grupos_selvagens()
	if not _recuperar_movimento_grupos_offline():
		push_error("Não foi possível recuperar o movimento offline da fauna; inicialização cancelada para proteger o estado compartilhado.")
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CANT_WRITE
	if not await _sincronizar_fauna_global(true):
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CANT_WRITE
	_semente_mundo_celeste = await _carregar_semente_mundo_celeste_global()
	if _semente_mundo_celeste <= 0:
		push_error("Não foi possível recuperar ou persistir a semente do mundo celeste; inicialização cancelada para preservar o calendário compartilhado.")
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	if not await _carregar_eventos_mundo_global():
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	if not await _carregar_mimicos_global(_semente_mundo_celeste):
		push_error("Não foi possível recuperar a população global de mímicos.")
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	if not await _carregar_piedade_mimicos_global():
		push_error("Não foi possível recuperar a piedade global dos Mímicos.")
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CORRUPT
	mimicos_publicos_cache = _repositorio_mimicos.listar_ativos()
	_contexto_celeste_atual.clear()
	_ultimo_periodo_celeste = "indefinido"
	_ultimo_dia_celeste = -1
	_ultimo_envio_relogio_ms = 0
	# Executa a recuperação temporal do ecossistema logo ao iniciar o servidor.
	# Os repositórios usam timestamps persistidos para simular o período offline.
	var agora_inicio_ms := Time.get_ticks_msec()
	_ultimo_tick_populacional_ms = agora_inicio_ms - INTERVALO_SIMULACAO_POPULACIONAL_MS
	multiplayer.multiplayer_peer = _peer
	_mudar_estado(EstadoConexao.SERVIDOR)
	_atualizar_ciclo_celeste_autoritativo()
	await _atualizar_eventos_mundo(agora_inicio_ms, true)
	await _atualizar_incursao_serpente(agora_inicio_ms)
	if not await _processar_ciclo_alimentar(agora_inicio_ms):
		push_error("A recuperação ecológica offline não foi confirmada globalmente; inicialização cancelada.")
		_limpar_peer()
		_mudar_estado(EstadoConexao.FALHA)
		return ERR_FILE_CANT_WRITE
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
	return await _sincronizar_resultado_missao_peer(peer_id, _servico_missoes_mundo.aceitar(str(_uid_por_peer[peer_id]), missao_id))

func recusar_missao_mundo(peer_id: int, missao_id: String) -> Dictionary:
	if not _pode_alterar_missao(peer_id):
		return {"ok": false, "erro": "Jogador não autenticado ou indisponível."}
	return await _sincronizar_resultado_missao_peer(peer_id, _servico_missoes_mundo.recusar(str(_uid_por_peer[peer_id]), missao_id))

func abandonar_missao_mundo(peer_id: int, missao_id: String) -> Dictionary:
	if not _pode_alterar_missao(peer_id):
		return {"ok": false, "erro": "Jogador não autenticado ou indisponível."}
	return await _sincronizar_resultado_missao_peer(peer_id, _servico_missoes_mundo.abandonar(str(_uid_por_peer[peer_id]), missao_id))

## Chamar apenas após o servidor confirmar a derrota, coleta, visita ou encontro.
func registrar_evento_missao_mundo(peer_id: int, tipo_evento: String, alvo_id: String, quantidade: int = 1) -> Dictionary:
	if not multiplayer.is_server() or _servico_missoes_mundo == null or not _uid_por_peer.has(peer_id):
		return {"ok": false, "erro": "Jogador não autenticado no servidor."}
	if not _perfil_por_peer.has(peer_id):
		return {"ok": false, "erro": "Perfil do personagem não está carregado."}
	var resultado: Dictionary = _servico_missoes_mundo.registrar_evento_confirmado(str(_uid_por_peer[peer_id]), tipo_evento, alvo_id, quantidade)
	return await _sincronizar_resultado_missao_peer(peer_id, resultado)

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
	var resultado := await registrar_evento_missao_mundo(peer_id, "visitar_local", local_id, 1)
	if bool(resultado.get("ok", false)):
		cooldowns[local_id] = agora
		_ultimo_evento_visita_por_peer[peer_id] = cooldowns

func concluir_missao_mundo(peer_id: int, missao_id: String) -> Dictionary:
	if not _pode_alterar_missao(peer_id):
		return {"ok": false, "erro": "Jogador não autenticado ou indisponível."}
	return await _sincronizar_resultado_missao_peer(peer_id, _servico_missoes_mundo.concluir_e_pagar(str(_uid_por_peer[peer_id]), missao_id))

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
			resultado = await concluir_missao_mundo(peer_id, missao_id)
		_:
			resultado = {"ok": false, "erro": "Ação inválida."}
	if bool(resultado.get("ok", false)):
		if acao != "concluir":
			resultado = await _sincronizar_resultado_missao_peer(peer_id, resultado)
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
	var uid := str(_uid_por_peer.get(peer_id, ""))
	if uid.is_empty() or not await _confirmar_perfil_global(uid):
		return {"ok":false,"erro":"A alteração da missão não foi confirmada na persistência global."}
	var perfil_atualizado: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
	if not perfil_atualizado.is_empty():
		_perfil_por_peer[peer_id] = perfil_atualizado.duplicate(true)
		rpc_id(peer_id, "_receber_perfil_personagem", perfil_atualizado)
	resultado.erase("perfil")
	return resultado

## Interrompe imediatamente o host quando a lease global deixa de ser válida.
## A porta ENet é fechada antes que novos comandos de jogadores possam ser aceitos.
func encerrar_servidor_por_falha_lease() -> void:
	if multiplayer != null and multiplayer.is_server():
		_persistir_estado_antes_de_encerrar()
	_limpar_peer()
	_mudar_estado(EstadoConexao.FALHA)
	erro_conexao.emit("A autorização do servidor para controlar o mundo global foi perdida. O servidor foi fechado por segurança.")

## Uma falha de gravação global encerra o host: não é seguro continuar com estado divergente.
func encerrar_servidor_por_falha_persistencia_global(mensagem: String) -> void:
	_encerrando_persistencia_global = true
	if multiplayer != null and multiplayer.is_server():
		_persistir_estado_antes_de_encerrar()
	_limpar_peer()
	_mudar_estado(EstadoConexao.FALHA)
	erro_conexao.emit("Persistência global indisponível. O servidor foi fechado para proteger o mundo: " + mensagem)

func desconectar() -> void:
	if multiplayer != null and multiplayer.is_server():
		_persistir_estado_antes_de_encerrar()
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
		_cancelar_duelo_pvp(id_jogador)
		_salvar_perfil_jogador(id_jogador)
		var saida_sala: Dictionary = _salas_publicas.remover_jogador(id_jogador)
		if bool(saida_sala.get("removido", false)):
			await _confirmar_salas_globais()
			_publicar_estado_sala(str(saida_sala.get("codigo", "")))
			# Publica o turno recalculado e a desconexão aos membros que continuam na batalha.
			var membros_restantes: Array = saida_sala.get("sala", {}).get("jogadores", [])
			if not membros_restantes.is_empty():
				_publicar_estado_aventura_da_sala(int(membros_restantes[0]))
		_intencao_sala_por_peer.erase(id_jogador)
		_ultima_mensagem_sala_ms.erase(id_jogador)
		_ultima_proposta_troca_ms.erase(id_jogador)
		_remover_propostas_troca_peer(id_jogador)
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
			await _publicar_estado_serpente_mundo()
		var uid_desconectado := str(_uid_por_peer.get(id_jogador, ""))
		_ultimo_convite_ally_ms.erase(id_jogador)
		_ultimo_convite_pvp_ms.erase(id_jogador)
		for convite_pvp_id in _convites_pvp.keys():
			var convite_pvp: Dictionary = _convites_pvp[convite_pvp_id]
			if int(convite_pvp.get("peerOrigem", -1)) == id_jogador or int(convite_pvp.get("peerAlvo", -1)) == id_jogador:
				var peer_notificar := int(convite_pvp.get("peerAlvo", -1)) if int(convite_pvp.get("peerOrigem", -1)) == id_jogador else int(convite_pvp.get("peerOrigem", -1))
				_convites_pvp.erase(convite_pvp_id)
				if peer_notificar > 0 and _uid_por_peer.has(peer_notificar):
					_enviar_resultado_pvp(peer_notificar, false, "Desafio cancelado porque o outro jogador desconectou.")
		for convite_id in _convites_ally.keys():
			var convite_pendente: Dictionary = _convites_ally[convite_id]
			if str(convite_pendente.get("uidOrigem", "")) == uid_desconectado or str(convite_pendente.get("uidAlvo", "")) == uid_desconectado:
				_notificar_cancelamento_convite_ally(convite_pendente, id_jogador)
				_convites_ally.erase(convite_id)
		_uid_por_peer.erase(id_jogador)
		# Mantém a Ally persistida, mas publica a lista sem o peer desconectado.
		if not uid_desconectado.is_empty() and _ally_por_uid.has(uid_desconectado):
			_publicar_estado_ally(str(_ally_por_uid[uid_desconectado]))
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
	if not await _carregar_perfil_global(uid):
		_uid_por_peer.erase(peer_id)
		_intencao_sala_por_peer.erase(peer_id)
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Não foi possível recuperar seu perfil global com segurança.")
		requisicao.queue_free()
		return
	var perfil: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
	if perfil.is_empty():
		_uid_por_peer.erase(peer_id)
		_intencao_sala_por_peer.erase(peer_id)
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Não foi possível carregar ou criar seu personagem no servidor.")
		requisicao.queue_free()
		return
	var intencao: Dictionary = _intencao_sala_por_peer.get(peer_id, {"acao":"mundo","codigo":""})
	var resultado_sala: Dictionary = await _processar_entrada_sala(peer_id, uid, intencao)
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
		# A entrada na sala já foi registrada; reverta-a antes de rejeitar a sessão.
		# Caso contrário, o peer fica ocupando uma vaga sem UID/perfil autenticado.
		var sala_revertida: Dictionary = _salas_publicas.remover_jogador(peer_id)
		if bool(sala_revertida.get("removido", false)):
			await _confirmar_salas_globais()
			_publicar_estado_sala(str(sala_revertida.get("codigo", "")))
		_uid_por_peer.erase(peer_id)
		_intencao_sala_por_peer.erase(peer_id)
		rpc_id(peer_id, "_receber_autenticacao_rejeitada", "Não foi possível atualizar seu perfil após entrar na sala.")
		requisicao.queue_free()
		return
	_perfil_por_peer[peer_id] = perfil
	# Reassocia a sessão recém-autenticada à Ally persistida, sem expor o UID.
	if _ally_por_uid.has(uid):
		_publicar_estado_ally(str(_ally_por_uid[uid]))
	var email := str(usuario.get("email", ""))
	rpc_id(peer_id, "_receber_autenticacao_aprovada", uid, email)
	if resultado_sala.has("codigo"):
		rpc_id(peer_id, "_receber_sala_atualizada", resultado_sala)
		_publicar_estado_sala(str(resultado_sala.get("codigo", "")))
		# A reconexão pode retomar o turno; todos os membros precisam receber a revisão nova.
		_publicar_estado_aventura_da_sala(peer_id)
	if bool(perfil.get("personagemCriado", false)):
		# A sala organiza a equipe e o combate cooperativo, mas não cria
		# uma cópia do mundo. Todo membro autenticado também entra na simulação
		# espacial compartilhada para explorar, mover-se e alcançar a Serpente.
		await _adicionar_jogador_autenticado(peer_id)
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
	call_deferred("_sincronizar_perfil_global", uid, _repositorio_perfis.exportar_perfil_persistente(uid))
	rpc_id(peer_id, "_receber_perfil_personagem", perfil)
	# O personagem criado em sala também entra no mesmo mundo espacial.
	await _adicionar_jogador_autenticado(peer_id)

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
	await _registrar_visita_local_confirmada(id_jogador, posicao)
	_ultima_gravacao_ms[id_jogador] = Time.get_ticks_msec()
	rpc_id(id_jogador, "_receber_estado_inicial", lista_existente)
	rpc_id(id_jogador, "_receber_criaturas_persistentes", _lista_visual_criaturas())
	rpc_id(id_jogador, "_receber_mimicos", _repositorio_mimicos.listar_ativos())
	rpc_id(id_jogador, "_receber_grupos_selvagens", _lista_visual_individuos_grupos())
	rpc_id(id_jogador, "_receber_perfil_personagem", perfil)
	await _enviar_estado_global_inicial(id_jogador)
	rpc("_receber_jogador_entrou", id_jogador, posicao, _perfil_visual_publico(perfil))


## O estado global não pertence a uma sala: todo cliente autenticado recebe o
## mesmo relógio celeste e o mesmo snapshot da Serpente, inclusive em cooperação.
func _enviar_estado_global_inicial(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id <= 0 or not _uid_por_peer.has(peer_id):
		return
	if _contexto_celeste_atual.is_empty():
		_contexto_celeste_atual = _obter_contexto_celeste_servidor()
	rpc_id(peer_id, "_receber_relogio_mundo", _contexto_celeste_atual.duplicate(true))
	# O cliente recém-conectado recebe imediatamente os eventos globais em andamento,
	# sem depender do próximo tick periódico de sincronização (10 segundos).
	var agora_eventos_unix := int(Time.get_unix_time_from_system())
	var eventos_ativos_iniciais := SISTEMA_EVENTOS_MUNDO.criar_snapshot_inicial(_eventos_mundo_payload, agora_eventos_unix)
	rpc_id(peer_id, "_receber_eventos_mundo", eventos_ativos_iniciais)
	if _estado_serpente_mundo.is_empty():
		_estado_serpente_mundo = SISTEMA_SERPENTE_MUNDO.criar_estado()
	# O primeiro snapshot também precisa cumprir o contrato de revisão do cliente.
	# Estados recém-criados ainda não passaram por uma publicação incremental.
	if int(_estado_serpente_mundo.get("revisaoSincronizacao", 0)) <= 0:
		_estado_serpente_mundo["revisaoSincronizacao"] = 1
		_estado_serpente_mundo["atualizadoUnix"] = int(Time.get_unix_time_from_system())
		if not await _salvar_estado_serpente_mundo():
			push_error("Não foi possível persistir a revisão inicial da Serpente; snapshot de entrada cancelado.")
			return
	var estado_serpente_inicial := SISTEMA_SERPENTE_MUNDO.obter_snapshot_global(_estado_serpente_mundo, SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO)
	rpc_id(peer_id, "_receber_estado_serpente_mundo", estado_serpente_inicial)


## Convites de Ally: o cliente informa apenas o peer visível; o servidor valida
## identidade, distância, combate e sala usando os dados da sessão.
func solicitar_convidar_para_ally(peer_alvo: int) -> void:
	if peer_alvo <= 0 or peer_alvo == multiplayer.get_unique_id():
		return
	if estado == EstadoConexao.SERVIDOR:
		_processar_convite_ally(multiplayer.get_unique_id(), peer_alvo)
	elif estado == EstadoConexao.CONECTADO:
		_solicitar_convite_ally.rpc_id(1, peer_alvo)

@rpc("any_peer", "call_remote", "reliable")
func _solicitar_convite_ally(peer_alvo: int) -> void:
	if multiplayer.is_server():
		_processar_convite_ally(multiplayer.get_remote_sender_id(), peer_alvo)


## Proposta bilateral: o servidor recebe somente IDs/quantidades e consulta os perfis oficiais.
func solicitar_propor_troca(peer_alvo: int, item_proprio: String, quantidade_propria: int, item_desejado: String, quantidade_desejada: int) -> void:
	if estado == EstadoConexao.CONECTADO and peer_alvo > 0:
		_enviar_proposta_troca.rpc_id(1, peer_alvo, item_proprio, quantidade_propria, item_desejado, quantidade_desejada)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_proposta_troca(peer_alvo: int, item_proprio: String, quantidade_propria: int, item_desejado: String, quantidade_desejada: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_origem := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_origem) or not _uid_por_peer.has(peer_alvo) or peer_origem == peer_alvo:
		_enviar_resultado_troca(peer_origem, false, "Jogadores inválidos para a troca.")
		return
	var agora_proposta_ms := Time.get_ticks_msec()
	if agora_proposta_ms - int(_ultima_proposta_troca_ms.get(peer_origem, -INTERVALO_PROPOSTA_TROCA_MS)) < INTERVALO_PROPOSTA_TROCA_MS:
		_enviar_resultado_troca(peer_origem, false, "Aguarde antes de enviar outra proposta de troca.")
		return
	if _propostas_troca.size() >= LIMITE_PROPOSTAS_TROCA_PENDENTES:
		_enviar_resultado_troca(peer_origem, false, "O sistema de trocas está ocupado. Tente novamente em instantes.")
		return
	if not _jogadores_no_mundo.has(peer_origem) or not _jogadores_no_mundo.has(peer_alvo) or _combates_por_peer.has(peer_origem) or _combates_por_peer.has(peer_alvo):
		_enviar_resultado_troca(peer_origem, false, "Os dois jogadores precisam estar livres e no mundo.")
		return
	var posicao_origem: Vector2 = _jogadores_no_mundo[peer_origem]
	var posicao_alvo: Vector2 = _jogadores_no_mundo[peer_alvo]
	if posicao_origem.distance_to(posicao_alvo) > DISTANCIA_TROCA:
		_enviar_resultado_troca(peer_origem, false, "Aproxime-se do jogador para negociar.")
		return
	var sala_a: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_origem)
	var sala_b: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_alvo)
	if str(sala_a.get("codigo", "")).is_empty() or str(sala_a.get("codigo", "")) != str(sala_b.get("codigo", "")):
		_enviar_resultado_troca(peer_origem, false, "Os jogadores precisam estar na mesma sala.")
		return
	if item_proprio.strip_edges().is_empty() or item_desejado.strip_edges().is_empty() or item_proprio.length() > 128 or item_desejado.length() > 128 or quantidade_propria < 1 or quantidade_propria > 999 or quantidade_desejada < 1 or quantidade_desejada > 999:
		_enviar_resultado_troca(peer_origem, false, "Itens ou quantidades inválidos.")
		return
	var uid_a := str(_uid_por_peer[peer_origem])
	var uid_b := str(_uid_por_peer[peer_alvo])
	var perfil_a: Dictionary = _perfil_por_peer[peer_origem]
	var perfil_b: Dictionary = _perfil_por_peer[peer_alvo]
	var valida_a := _validar_item_para_troca(perfil_a, item_proprio, quantidade_propria)
	var valida_b := _validar_item_para_troca(perfil_b, item_desejado, quantidade_desejada)
	if not bool(valida_a.get("ok", false)) or not bool(valida_b.get("ok", false)):
		_enviar_resultado_troca(peer_origem, false, str(valida_a.get("erro", valida_b.get("erro", "Itens indisponíveis."))))
		return
	_ultima_proposta_troca_ms[peer_origem] = agora_proposta_ms
	var id := "troca_%d_%d" % [Time.get_ticks_usec(), peer_origem]
	_propostas_troca[id] = {"id":id,"peerOrigem":peer_origem,"peerAlvo":peer_alvo,"uidOrigem":uid_a,"uidAlvo":uid_b,"itemOrigem":item_proprio,"qtdOrigem":quantidade_propria,"itemAlvo":item_desejado,"qtdAlvo":quantidade_desejada,"expira":Time.get_ticks_msec()+DURACAO_PROPOSTA_TROCA_MS}
	var nome := str(perfil_a.get("nome", "Aventureiro"))
	rpc_id(peer_alvo, "_receber_proposta_troca", {"id":id,"nome":nome,"itemOferecido":item_proprio,"quantidadeOferecida":quantidade_propria,"itemSolicitado":item_desejado,"quantidadeSolicitada":quantidade_desejada})
	_enviar_resultado_troca(peer_origem, true, "Proposta enviada. A troca só acontece se o outro jogador aceitar.")

func _limpar_propostas_troca_expiradas(agora_ms: int) -> void:
	for proposta_id in _propostas_troca.keys():
		var proposta: Dictionary = _propostas_troca.get(proposta_id, {})
		if int(proposta.get("expira", 0)) > agora_ms:
			continue
		_propostas_troca.erase(proposta_id)
		# A expiração precisa encerrar também a expectativa visual dos dois lados.
		# Sem este aviso, o destinatário mantém uma proposta que já não pode aceitar.
		var peer_origem := int(proposta.get("peerOrigem", -1))
		var peer_alvo := int(proposta.get("peerAlvo", -1))
		if peer_origem > 0 and _uid_por_peer.has(peer_origem):
			_enviar_resultado_troca(peer_origem, false, "A proposta de troca expirou.")
		if peer_alvo > 0 and _uid_por_peer.has(peer_alvo):
			_enviar_resultado_troca(peer_alvo, false, "A proposta de troca expirou.")

func _remover_propostas_troca_peer(peer_id: int) -> void:
	for proposta_id in _propostas_troca.keys():
		var proposta: Dictionary = _propostas_troca.get(proposta_id, {})
		if int(proposta.get("peerOrigem", -1)) == peer_id or int(proposta.get("peerAlvo", -1)) == peer_id:
			var outro_peer := int(proposta.get("peerAlvo", -1)) if int(proposta.get("peerOrigem", -1)) == peer_id else int(proposta.get("peerOrigem", -1))
			_propostas_troca.erase(proposta_id)
			if outro_peer > 0 and _uid_por_peer.has(outro_peer):
				_enviar_resultado_troca(outro_peer, false, "A proposta de troca foi cancelada porque o outro jogador desconectou.")

func _validar_item_para_troca(perfil: Dictionary, item_id: String, quantidade: int) -> Dictionary:
	if quantidade < 1 or quantidade > 999:
		return {"ok":false,"erro":"Quantidade inválida."}
	var equipamentos: Dictionary = perfil.get("equipamentos", {})
	if equipamentos.values().has(item_id):
		return {"ok":false,"erro":"Desequipe o item antes de negociar."}
	for item in perfil.get("inventario", []):
		if str(item.get("itemId", "")) == item_id and str(item.get("categoria", "")).to_lower() != "moeda" and int(item.get("quantidade", 0)) >= quantidade:
			return {"ok":true}
	return {"ok":false,"erro":"Um dos jogadores não possui a quantidade solicitada."}

func responder_proposta_troca(proposta_id: String, aceitar: bool) -> void:
	if estado == EstadoConexao.CONECTADO and not proposta_id.is_empty():
		_responder_proposta_troca.rpc_id(1, proposta_id, aceitar)

@rpc("any_peer", "call_remote", "reliable")
func _responder_proposta_troca(proposta_id: String, aceitar: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer_alvo := multiplayer.get_remote_sender_id()
	var proposta: Dictionary = _propostas_troca.get(proposta_id, {})
	if proposta.is_empty() or int(proposta.get("peerAlvo", -1)) != peer_alvo or int(proposta.get("expira", 0)) < Time.get_ticks_msec():
		_propostas_troca.erase(proposta_id)
		_enviar_resultado_troca(peer_alvo, false, "A proposta expirou ou não é mais válida.")
		return
	_propostas_troca.erase(proposta_id)
	var peer_origem := int(proposta.get("peerOrigem", -1))
	if not aceitar:
		_enviar_resultado_troca(peer_origem, false, "A proposta de troca foi recusada.")
		_enviar_resultado_troca(peer_alvo, true, "Você recusou a troca.")
		return
	if not _uid_por_peer.has(peer_origem) or not _uid_por_peer.has(peer_alvo) or str(_uid_por_peer[peer_origem]) != str(proposta.get("uidOrigem", "")) or str(_uid_por_peer[peer_alvo]) != str(proposta.get("uidAlvo", "")) or not _jogadores_no_mundo.has(peer_origem) or not _jogadores_no_mundo.has(peer_alvo) or _combates_por_peer.has(peer_origem) or _combates_por_peer.has(peer_alvo):
		_enviar_resultado_troca(peer_alvo, false, "A troca foi cancelada porque os jogadores não estão mais próximos ou disponíveis.")
		_enviar_resultado_troca(peer_origem, false, "A troca foi cancelada.")
		return
	var posicao_origem_atual: Vector2 = _jogadores_no_mundo[peer_origem]
	var posicao_alvo_atual: Vector2 = _jogadores_no_mundo[peer_alvo]
	if posicao_origem_atual.distance_to(posicao_alvo_atual) > DISTANCIA_TROCA:
		_enviar_resultado_troca(peer_alvo, false, "A troca foi cancelada porque os jogadores se afastaram.")
		_enviar_resultado_troca(peer_origem, false, "A troca foi cancelada.")
		return
	var sala_origem: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_origem)
	var sala_alvo: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_alvo)
	if str(sala_origem.get("codigo", "")).is_empty() or str(sala_origem.get("codigo", "")) != str(sala_alvo.get("codigo", "")):
		_enviar_resultado_troca(peer_origem, false, "A troca foi cancelada porque os jogadores não estão mais na mesma sala.")
		_enviar_resultado_troca(peer_alvo, false, "A troca foi cancelada.")
		return
	var uid_origem := str(proposta["uidOrigem"])
	var uid_alvo := str(proposta["uidAlvo"])
	if not await _bloquear_perfis_para_transacao(uid_origem, uid_alvo):
		_enviar_resultado_troca(peer_origem, false, "Os perfis estão ocupados. Tente novamente.")
		_enviar_resultado_troca(peer_alvo, false, "Os perfis estão ocupados. Tente novamente.")
		return
	# Revalida propriedade e quantidades dentro da reserva, antes de alterar ambos.
	var perfil_origem_bloqueado: Dictionary = _repositorio_perfis.carregar_ou_criar(uid_origem)
	var perfil_alvo_bloqueado: Dictionary = _repositorio_perfis.carregar_ou_criar(uid_alvo)
	var validacao_origem := _validar_item_para_troca(perfil_origem_bloqueado, str(proposta["itemOrigem"]), int(proposta["qtdOrigem"]))
	var validacao_alvo := _validar_item_para_troca(perfil_alvo_bloqueado, str(proposta["itemAlvo"]), int(proposta["qtdAlvo"]))
	if not bool(validacao_origem.get("ok", false)) or not bool(validacao_alvo.get("ok", false)):
		_perfis_gravacao_remota_em_andamento.erase(uid_origem)
		_perfis_gravacao_remota_em_andamento.erase(uid_alvo)
		var erro_validacao := str(validacao_origem.get("erro", validacao_alvo.get("erro", "Inventário alterado antes da troca.")))
		_enviar_resultado_troca(peer_origem, false, erro_validacao)
		_enviar_resultado_troca(peer_alvo, false, erro_validacao)
		return
	var resultado: Dictionary = _repositorio_perfis.trocar_itens(uid_origem, uid_alvo, str(proposta["itemOrigem"]), int(proposta["qtdOrigem"]), str(proposta["itemAlvo"]), int(proposta["qtdAlvo"]))
	if not bool(resultado.get("ok", false)):
		_perfis_gravacao_remota_em_andamento.erase(uid_origem)
		_perfis_gravacao_remota_em_andamento.erase(uid_alvo)
		_enviar_resultado_troca(peer_origem, false, str(resultado.get("erro", "A troca falhou.")))
		_enviar_resultado_troca(peer_alvo, false, str(resultado.get("erro", "A troca falhou.")))
		return
	# O mesmo coordenador serializa as duas contas, confirma D1 e drena alterações
	# que tenham chegado enquanto a transação estava em andamento.
	var crypto_troca := Crypto.new()
	var bytes_troca := crypto_troca.generate_random_bytes(16)
	if bytes_troca.size() != 16:
		_perfis_gravacao_remota_em_andamento.erase(uid_origem)
		_perfis_gravacao_remota_em_andamento.erase(uid_alvo)
		encerrar_servidor_por_falha_persistencia_global("Não foi possível gerar o identificador da troca.")
		_enviar_resultado_troca(peer_origem, false, "A troca não foi confirmada globalmente.")
		_enviar_resultado_troca(peer_alvo, false, "A troca não foi confirmada globalmente.")
		return
	var confirmacao: Dictionary = await _confirmar_transacao_perfis_globais(bytes_troca.hex_encode(), uid_origem, uid_alvo, true)
	if not bool(confirmacao.get("ok", false)):
		_enviar_resultado_troca(peer_origem, false, "A troca não foi confirmada globalmente. O servidor entrou em segurança.")
		_enviar_resultado_troca(peer_alvo, false, "A troca não foi confirmada globalmente. O servidor entrou em segurança.")
		return
	for peer in [peer_origem, peer_alvo]:
		var uid := str(_uid_por_peer[peer])
		var perfil: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
		if perfil.is_empty():
			encerrar_servidor_por_falha_persistencia_global("Perfil ausente após confirmar a troca bilateral.")
			return
		_perfil_por_peer[peer] = perfil.duplicate(true)
		if int(peer) == multiplayer.get_unique_id():
			perfil_personagem_atual = perfil.duplicate(true)
			perfil_personagem_recebido.emit(perfil_personagem_atual)
		else:
			rpc_id(int(peer), "_receber_perfil_personagem", perfil)
		_enviar_resultado_troca(int(peer), true, "Troca concluída com sucesso!")

func _enviar_resultado_troca(peer_id: int, sucesso: bool, mensagem: String) -> void:
	if peer_id <= 0:
		return
	if peer_id == multiplayer.get_unique_id():
		resultado_troca.emit(sucesso, mensagem)
	else:
		rpc_id(peer_id, "_receber_resultado_troca", sucesso, mensagem)

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_troca(sucesso: bool, mensagem: String) -> void:
	resultado_troca.emit(sucesso, mensagem)

@rpc("authority", "call_remote", "reliable")
func _receber_proposta_troca(proposta: Dictionary) -> void:
	proposta_troca_recebida.emit(proposta.duplicate(true))


## PvP sempre começa por convite explícito; o servidor valida identidade, distância e sala.
func solicitar_pvp(peer_alvo: int) -> void:
	if peer_alvo <= 0:
		return
	if estado == EstadoConexao.SERVIDOR:
		_processar_convite_pvp(multiplayer.get_unique_id(), peer_alvo)
	elif estado == EstadoConexao.CONECTADO:
		_enviar_convite_pvp.rpc_id(1, peer_alvo)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_convite_pvp(peer_alvo: int) -> void:
	if multiplayer.is_server():
		_processar_convite_pvp(multiplayer.get_remote_sender_id(), peer_alvo)

func _processar_convite_pvp(peer_origem: int, peer_alvo: int) -> void:
	if not multiplayer.is_server() or peer_origem == peer_alvo:
		return
	if not _uid_por_peer.has(peer_origem) or not _uid_por_peer.has(peer_alvo) or not _perfil_por_peer.has(peer_origem) or not _perfil_por_peer.has(peer_alvo) or not _jogadores_no_mundo.has(peer_origem) or not _jogadores_no_mundo.has(peer_alvo):
		_enviar_resultado_pvp(peer_origem, false, "Os dois jogadores precisam estar conectados no mundo.")
		return
	if _combates_por_peer.has(peer_origem) or _combates_por_peer.has(peer_alvo) or _duelo_por_peer.has(peer_origem) or _duelo_por_peer.has(peer_alvo):
		_enviar_resultado_pvp(peer_origem, false, "Um dos jogadores já está em combate.")
		return
	var agora_pvp_ms := Time.get_ticks_msec()
	if agora_pvp_ms - int(_ultimo_convite_pvp_ms.get(peer_origem, -3000)) < 2500:
		_enviar_resultado_pvp(peer_origem, false, "Aguarde um instante antes de enviar outro desafio.")
		return
	_ultimo_convite_pvp_ms[peer_origem] = agora_pvp_ms
	var perfil_a: Dictionary = _perfil_por_peer[peer_origem]
	var perfil_b: Dictionary = _perfil_por_peer[peer_alvo]
	if int(perfil_a.get("vida", 0)) <= 0 or int(perfil_b.get("vida", 0)) <= 0:
		_enviar_resultado_pvp(peer_origem, false, "Os dois personagens precisam estar vivos para duelar.")
		return
	var pos_a: Vector2 = _jogadores_no_mundo[peer_origem]
	var pos_b: Vector2 = _jogadores_no_mundo[peer_alvo]
	if pos_a.distance_to(pos_b) > DISTANCIA_PVP:
		_enviar_resultado_pvp(peer_origem, false, "Aproxime-se do jogador para desafiá-lo.")
		return
	var sala_a: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_origem)
	var sala_b: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_alvo)
	var codigo := str(sala_a.get("codigo", ""))
	if codigo.is_empty() or codigo != str(sala_b.get("codigo", "")):
		_enviar_resultado_pvp(peer_origem, false, "Os dois jogadores precisam estar na mesma sala.")
		return
	for convite_id in _convites_pvp.keys():
		var existente: Dictionary = _convites_pvp[convite_id]
		if int(existente.get("peerAlvo", -1)) == peer_alvo:
			_enviar_resultado_pvp(peer_origem, false, "Esse jogador já tem um desafio pendente.")
			return
	var id := "pvp_%d_%d" % [Time.get_ticks_usec(), peer_origem]
	_convites_pvp[id] = {"id":id,"peerOrigem":peer_origem,"peerAlvo":peer_alvo,"uidOrigem":str(_uid_por_peer[peer_origem]),"uidAlvo":str(_uid_por_peer[peer_alvo]),"codigoSala":codigo,"expira":Time.get_ticks_msec()+DURACAO_CONVITE_PVP_MS}
	rpc_id(peer_alvo, "_receber_convite_pvp", {"id":id,"nome":str(perfil_a.get("nome","Aventureiro")),"expiraEmSegundos":30})
	_enviar_resultado_pvp(peer_origem, true, "Desafio enviado. A batalha só começa se o jogador aceitar.")

func _limpar_convites_pvp_expirados(agora_ms: int) -> void:
	for convite_id in _convites_pvp.keys():
		var convite: Dictionary = _convites_pvp.get(convite_id, {})
		if int(convite.get("expira", 0)) > agora_ms:
			continue
		_convites_pvp.erase(convite_id)
		var peer_origem := int(convite.get("peerOrigem", -1))
		var peer_alvo := int(convite.get("peerAlvo", -1))
		if peer_origem > 0 and _uid_por_peer.has(peer_origem):
			_enviar_resultado_pvp(peer_origem, false, "O desafio PvP expirou sem resposta.")
		if peer_alvo > 0 and _uid_por_peer.has(peer_alvo):
			_enviar_resultado_pvp(peer_alvo, false, "O desafio PvP expirou.")

func responder_convite_pvp(convite_id: String, aceitar: bool) -> void:
	if estado == EstadoConexao.SERVIDOR:
		_processar_resposta_convite_pvp(multiplayer.get_unique_id(), convite_id, aceitar)
	elif estado == EstadoConexao.CONECTADO and not convite_id.is_empty():
		_responder_convite_pvp.rpc_id(1, convite_id, aceitar)

@rpc("any_peer", "call_remote", "reliable")
func _responder_convite_pvp(convite_id: String, aceitar: bool) -> void:
	if multiplayer.is_server():
		_processar_resposta_convite_pvp(multiplayer.get_remote_sender_id(), convite_id, aceitar)

func _processar_resposta_convite_pvp(peer_alvo: int, convite_id: String, aceitar: bool) -> void:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_alvo):
		return
	var convite: Dictionary = _convites_pvp.get(convite_id, {})
	if convite.is_empty() or int(convite.get("peerAlvo", -1)) != peer_alvo or int(convite.get("expira", 0)) < Time.get_ticks_msec():
		_convites_pvp.erase(convite_id)
		_enviar_resultado_pvp(peer_alvo, false, "O desafio expirou ou não é mais válido.")
		return
	_convites_pvp.erase(convite_id)
	var peer_origem := int(convite.get("peerOrigem", -1))
	if not aceitar:
		_enviar_resultado_pvp(peer_alvo, true, "Você recusou o desafio.")
		_enviar_resultado_pvp(peer_origem, false, "O jogador recusou o desafio.")
		return
	if not _uid_por_peer.has(peer_origem) or str(_uid_por_peer[peer_origem]) != str(convite.get("uidOrigem", "")) or str(_uid_por_peer[peer_alvo]) != str(convite.get("uidAlvo", "")) or not _jogadores_no_mundo.has(peer_origem) or not _jogadores_no_mundo.has(peer_alvo) or _combates_por_peer.has(peer_origem) or _combates_por_peer.has(peer_alvo):
		_enviar_resultado_pvp(peer_alvo, false, "O desafio foi cancelado porque um dos jogadores não está disponível.")
		return
	var sala_a: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_origem)
	var sala_b: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_alvo)
	var pos_a: Vector2 = _jogadores_no_mundo[peer_origem]
	var pos_b: Vector2 = _jogadores_no_mundo[peer_alvo]
	if str(sala_a.get("codigo", "")) != str(convite.get("codigoSala", "")) or str(sala_b.get("codigo", "")) != str(convite.get("codigoSala", "")) or pos_a.distance_to(pos_b) > DISTANCIA_PVP:
		_enviar_resultado_pvp(peer_alvo, false, "Vocês se afastaram ou saíram da mesma sala. O duelo não começou.")
		_enviar_resultado_pvp(peer_origem, false, "O duelo foi cancelado.")
		return
	var perfil_a: Dictionary = _perfil_por_peer[peer_origem]
	var perfil_b: Dictionary = _perfil_por_peer[peer_alvo]
	if int(perfil_a.get("vida", 0)) <= 0 or int(perfil_b.get("vida", 0)) <= 0:
		_enviar_resultado_pvp(peer_alvo, false, "Os dois personagens precisam estar vivos.")
		return
	var duelo_id := "duelo_%d_%d" % [Time.get_ticks_usec(), peer_origem]
	var duelo := SistemaDueloPvP.criar_duelo(duelo_id, peer_origem, peer_alvo, perfil_a, perfil_b)
	if duelo.is_empty():
		_enviar_resultado_pvp(peer_alvo, false, "Não foi possível preparar os personagens para o duelo.")
		return
	_duelos_pvp[duelo_id] = duelo
	_duelo_por_peer[peer_origem] = duelo_id
	_duelo_por_peer[peer_alvo] = duelo_id
	_combates_por_peer[peer_origem] = {"tipo":"pvp","dueloId":duelo_id}
	_combates_por_peer[peer_alvo] = {"tipo":"pvp","dueloId":duelo_id}
	_publicar_estado_duelo_pvp(duelo_id)
	_enviar_resultado_pvp(peer_origem, true, "O duelo começou!")
	_enviar_resultado_pvp(peer_alvo, true, "O duelo começou!")

func _publicar_estado_duelo_pvp(duelo_id: String) -> void:
	var duelo: Dictionary = _duelos_pvp.get(duelo_id, {})
	if duelo.is_empty():
		return
	for peer in [int(duelo.get("peerA", -1)), int(duelo.get("peerB", -1))]:
		if not _uid_por_peer.has(peer):
			continue
		var estado_peer := SistemaDueloPvP.estado_para_peer(duelo, peer)
		# O jogador que hospeda também é cliente local; call_remote não entrega RPC a si próprio.
		if peer == multiplayer.get_unique_id():
			combate_atualizado.emit(estado_peer)
		else:
			rpc_id(peer, "_receber_estado_combate", estado_peer)

func _processar_acao_duelo_pvp(peer_id: int, acao: String, habilidade_id: String) -> void:
	if acao == SistemaCombate.ACAO_SUPREMA or SistemaCombate.ACOES_SUPREMAS_CLASSE.has(acao):
		_enviar_resultado_pvp(peer_id, false, "Supremas só podem ser usadas em combates contra criaturas.")
		return
	var duelo_id := str(_duelo_por_peer.get(peer_id, ""))
	var duelo: Dictionary = _duelos_pvp.get(duelo_id, {})
	if duelo.is_empty():
		_enviar_resultado_pvp(peer_id, false, "Este duelo não está mais ativo.")
		return
	var resultado := SistemaDueloPvP.executar_acao(duelo, peer_id, acao, habilidade_id, int(Time.get_ticks_usec()) ^ peer_id)
	if not bool(resultado.get("ok", false)):
		rpc_id(peer_id, "_receber_erro_combate", str(resultado.get("erro", "Ação PvP recusada.")))
		return
	duelo = resultado.get("duelo", {})
	_duelos_pvp[duelo_id] = duelo
	if str(duelo.get("status", "")) == "em_andamento":
		_publicar_estado_duelo_pvp(duelo_id)
	else:
		await _finalizar_duelo_pvp(duelo_id)

func _finalizar_duelo_pvp(duelo_id: String) -> void:
	var duelo: Dictionary = _duelos_pvp.get(duelo_id, {})
	if duelo.is_empty() or _duelos_pvp_liquidando.has(duelo_id):
		return
	var vencedor_peer := int(duelo.get("vencedorPeer", -1))
	var perdedor_peer := int(duelo.get("perdedorPeer", -1))
	if not _uid_por_peer.has(vencedor_peer) or not _uid_por_peer.has(perdedor_peer):
		_cancelar_duelo_pvp(vencedor_peer if _uid_por_peer.has(vencedor_peer) else perdedor_peer)
		return
	var lutadores: Dictionary = duelo.get("lutadores", {})
	var vencedor_estado: Dictionary = lutadores.get(str(vencedor_peer), {})
	var perdedor_estado: Dictionary = lutadores.get(str(perdedor_peer), {})
	var uid_vencedor := str(_uid_por_peer[vencedor_peer])
	var uid_perdedor := str(_uid_por_peer[perdedor_peer])
	# Impede duas coroutines de liquidarem o mesmo duelo enquanto aguardam D1.
	_duelos_pvp_liquidando[duelo_id] = true
	if not await _bloquear_perfis_para_transacao(uid_vencedor, uid_perdedor):
		_duelos_pvp_liquidando.erase(duelo_id)
		_enviar_resultado_pvp(vencedor_peer, false, "As carteiras estão ocupadas. A recompensa foi bloqueada.")
		_enviar_resultado_pvp(perdedor_peer, false, "A liquidação foi bloqueada por segurança.")
		return
	var transferencia: Dictionary = _repositorio_perfis.transferir_recompensa_pvp(uid_vencedor, uid_perdedor, duelo_id, int(vencedor_estado.get("vida", 1)), int(vencedor_estado.get("mana", 0)))
	if bool(transferencia.get("ok", false)):
		# O identificador determinístico permite repetir a liquidação sem duplicar
		# a transferência, e o coordenador bloqueia gravações concorrentes dos dois UIDs.
		var id_transacao := duelo_id.sha256_text().substr(0, 32)
		var confirmacao_pvp: Dictionary = await _confirmar_transacao_perfis_globais(id_transacao, uid_vencedor, uid_perdedor, true)
		if not bool(confirmacao_pvp.get("ok", false)):
			_duelos_pvp_liquidando.erase(duelo_id)
			_enviar_resultado_pvp(vencedor_peer, false, "A recompensa PvP não foi confirmada globalmente.")
			_enviar_resultado_pvp(perdedor_peer, false, "A liquidação PvP foi bloqueada por segurança.")
			return
		var perfil_vencedor: Dictionary = _repositorio_perfis.carregar_ou_criar(uid_vencedor)
		var perfil_perdedor: Dictionary = _repositorio_perfis.carregar_ou_criar(uid_perdedor)
		if perfil_vencedor.is_empty() or perfil_perdedor.is_empty():
			_duelos_pvp_liquidando.erase(duelo_id)
			encerrar_servidor_por_falha_persistencia_global("Perfis ausentes após confirmar a liquidação PvP.")
			return
		_perfil_por_peer[vencedor_peer] = perfil_vencedor
		_perfil_por_peer[perdedor_peer] = perfil_perdedor
		if vencedor_peer == multiplayer.get_unique_id():
			perfil_personagem_recebido.emit(perfil_vencedor.duplicate(true))
		else:
			rpc_id(vencedor_peer, "_receber_perfil_personagem", perfil_vencedor)
		if perdedor_peer == multiplayer.get_unique_id():
			perfil_personagem_recebido.emit(perfil_perdedor.duplicate(true))
		else:
			rpc_id(perdedor_peer, "_receber_perfil_personagem", perfil_perdedor)
		var premio := int(transferencia.get("valorTransferidoEmBronze", 0))
		_enviar_resultado_pvp(vencedor_peer, true, "Vitória! Você recebeu 20%% da carteira comum do adversário (%d em valor de Bronzhar)." % premio)
		_enviar_resultado_pvp(perdedor_peer, true, "Derrota. 20%% do valor da sua carteira comum foi transferido ao vencedor.")
	else:
		_perfis_gravacao_remota_em_andamento.erase(uid_vencedor)
		_perfis_gravacao_remota_em_andamento.erase(uid_perdedor)
		_duelos_pvp_liquidando.erase(duelo_id)
		_enviar_resultado_pvp(vencedor_peer, false, str(transferencia.get("erro", "A recompensa não pôde ser transferida.")))
		_enviar_resultado_pvp(perdedor_peer, false, "Duelo encerrado, mas a transferência foi bloqueada.")
	_duelos_pvp_liquidando.erase(duelo_id)
	_duelo_por_peer.erase(vencedor_peer)
	_duelo_por_peer.erase(perdedor_peer)
	_duelos_pvp.erase(duelo_id)
	_combates_por_peer.erase(vencedor_peer)
	_combates_por_peer.erase(perdedor_peer)
	if vencedor_peer == multiplayer.get_unique_id():
		combate_finalizado.emit("vitoria", [])
	else:
		rpc_id(vencedor_peer, "_receber_combate_finalizado", "vitoria", [])
	if perdedor_peer == multiplayer.get_unique_id():
		combate_finalizado.emit("derrota", [])
	else:
		rpc_id(perdedor_peer, "_receber_combate_finalizado", "derrota", [])

func _cancelar_duelo_pvp(peer_id: int) -> void:
	var duelo_id := str(_duelo_por_peer.get(peer_id, ""))
	if duelo_id.is_empty():
		return
	var duelo: Dictionary = _duelos_pvp.get(duelo_id, {})
	var outro := int(duelo.get("peerB", -1)) if int(duelo.get("peerA", -1)) == peer_id else int(duelo.get("peerA", -1))
	_duelo_por_peer.erase(peer_id)
	_duelo_por_peer.erase(outro)
	_combates_por_peer.erase(peer_id)
	_combates_por_peer.erase(outro)
	_duelos_pvp.erase(duelo_id)
	if outro > 0 and _uid_por_peer.has(outro):
		rpc_id(outro, "_receber_erro_combate", "Duelo cancelado porque o adversário desconectou. Nenhuma moeda foi transferida.")
		rpc_id(outro, "_receber_combate_finalizado", "cancelado", [])

func _enviar_resultado_pvp(peer_id: int, sucesso: bool, mensagem: String) -> void:
	if peer_id <= 0:
		return
	if peer_id == multiplayer.get_unique_id():
		resultado_pvp.emit(sucesso, mensagem)
	else:
		rpc_id(peer_id, "_receber_resultado_pvp", sucesso, mensagem)

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_pvp(sucesso: bool, mensagem: String) -> void:
	resultado_pvp.emit(sucesso, mensagem)

@rpc("authority", "call_remote", "reliable")
func _receber_convite_pvp(convite: Dictionary) -> void:
	convite_pvp_recebido.emit(convite.duplicate(true))

func solicitar_sair_da_ally() -> void:
	if estado == EstadoConexao.SERVIDOR:
		await _processar_saida_ally(multiplayer.get_unique_id())
	elif estado == EstadoConexao.CONECTADO:
		_solicitar_saida_ally.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _solicitar_saida_ally() -> void:
	if multiplayer.is_server():
		await _processar_saida_ally(multiplayer.get_remote_sender_id())

func _processar_saida_ally(peer_id: int) -> void:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id):
		return
	var uid := str(_uid_por_peer[peer_id])
	if not _ally_por_uid.has(uid):
		_enviar_resultado_convite_ally(peer_id, false, "Você não pertence a uma Ally.")
		return
	var ally_id_anterior := str(_ally_por_uid.get(uid, ""))
	var membros_anteriores: Array = (_ally_ativa.get(ally_id_anterior, {}).get("membros", []) as Array).duplicate()
	_remover_uid_da_ally(uid)
	if not await _confirmar_ally_global():
		_enviar_resultado_convite_ally(peer_id, false, "A saída não foi confirmada no mundo global.")
		return
	if _ally_ativa.has(ally_id_anterior):
		_publicar_estado_ally(ally_id_anterior)
	else:
		for membro_uid in membros_anteriores:
			if str(membro_uid) != uid:
				_enviar_estado_ally_vazio_uid(str(membro_uid))
	if peer_id == multiplayer.get_unique_id():
		ally_atualizada.emit({})
	else:
		rpc_id(peer_id, "_receber_estado_ally", {})
	_enviar_resultado_convite_ally(peer_id, true, "Você saiu da Ally.")

func responder_convite_ally(convite_id: String, aceitar: bool) -> void:
	var id := convite_id.strip_edges()
	if id.is_empty() or id.length() > 160:
		return
	if estado == EstadoConexao.SERVIDOR:
		await _processar_resposta_convite_ally(multiplayer.get_unique_id(), id, aceitar)
	elif estado == EstadoConexao.CONECTADO:
		_responder_convite_ally.rpc_id(1, id, aceitar)

@rpc("any_peer", "call_remote", "reliable")
func _responder_convite_ally(convite_id: String, aceitar: bool) -> void:
	if multiplayer.is_server():
		await _processar_resposta_convite_ally(multiplayer.get_remote_sender_id(), convite_id, aceitar)

func _processar_convite_ally(peer_origem: int, peer_alvo: int) -> void:
	if not multiplayer.is_server() or peer_origem == peer_alvo:
		return
	if not _uid_por_peer.has(peer_origem) or not _uid_por_peer.has(peer_alvo):
		_enviar_resultado_convite_ally(peer_origem, false, "Os dois jogadores precisam estar conectados e autenticados.")
		return
	var agora_convite_ms := Time.get_ticks_msec()
	if agora_convite_ms - int(_ultimo_convite_ally_ms.get(peer_origem, -3000)) < 2500:
		_enviar_resultado_convite_ally(peer_origem, false, "Aguarde um instante antes de enviar outro convite.")
		return
	_ultimo_convite_ally_ms[peer_origem] = agora_convite_ms
	if not _perfil_por_peer.has(peer_origem) or not _perfil_por_peer.has(peer_alvo) or not _jogadores_no_mundo.has(peer_origem) or not _jogadores_no_mundo.has(peer_alvo):
		_enviar_resultado_convite_ally(peer_origem, false, "Um dos personagens ainda não está no mundo.")
		return
	if _combates_por_peer.has(peer_origem) or _combates_por_peer.has(peer_alvo):
		_enviar_resultado_convite_ally(peer_origem, false, "Não é possível convidar durante um combate.")
		return
	var pos_origem: Vector2 = _jogadores_no_mundo[peer_origem]
	var pos_alvo: Vector2 = _jogadores_no_mundo[peer_alvo]
	if pos_origem.distance_to(pos_alvo) > DISTANCIA_CONVITE_ALLY:
		_enviar_resultado_convite_ally(peer_origem, false, "Aproxime-se do jogador para convidá-lo.")
		return
	var sala_origem: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_origem)
	var sala_alvo: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_alvo)
	var codigo_sala := str(sala_origem.get("codigo", ""))
	if codigo_sala.is_empty() or codigo_sala != str(sala_alvo.get("codigo", "")):
		_enviar_resultado_convite_ally(peer_origem, false, "Para formar uma Ally, os dois jogadores precisam estar na mesma sala.")
		return
	var uid_origem := str(_uid_por_peer[peer_origem])
	var uid_alvo := str(_uid_por_peer[peer_alvo])
	if _ally_por_uid.has(uid_alvo):
		_enviar_resultado_convite_ally(peer_origem, false, "Esse jogador já pertence a uma Ally.")
		return
	var ally_id := str(_ally_por_uid.get(uid_origem, ""))
	if not ally_id.is_empty():
		var ally_atual: Dictionary = _ally_ativa.get(ally_id, {})
		if (ally_atual.get("membros", []) as Array).size() >= LIMITE_MEMBROS_ALLY:
			_enviar_resultado_convite_ally(peer_origem, false, "Sua Ally já atingiu o limite de quatro jogadores.")
			return
	for convite_existente in _convites_ally.values():
		if str(convite_existente.get("uidAlvo", "")) == uid_alvo:
			_enviar_resultado_convite_ally(peer_origem, false, "Esse jogador já tem um convite pendente.")
			return
	var convite_id := "%s_%d" % [uid_origem.substr(0, min(8, uid_origem.length())), Time.get_ticks_usec()]
	var perfil_origem: Dictionary = _perfil_por_peer[peer_origem]
	_convites_ally[convite_id] = {
		"id": convite_id,
		"uidOrigem": uid_origem,
		"uidAlvo": uid_alvo,
		"peerOrigem": peer_origem,
		"peerAlvo": peer_alvo,
		"codigoSala": codigo_sala,
		"expiraEm": Time.get_ticks_msec() + DURACAO_CONVITE_ALLY_MS
	}
	rpc_id(peer_alvo, "_receber_convite_ally", {"id": convite_id, "nome": str(perfil_origem.get("nome", "Aventureiro")), "expiraEmSegundos": 30})
	_enviar_resultado_convite_ally(peer_origem, true, "Convite enviado.")

func _processar_resposta_convite_ally(peer_alvo: int, convite_id: String, aceitar: bool) -> void:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_alvo):
		return
	var convite: Dictionary = _convites_ally.get(convite_id, {})
	if convite.is_empty() or int(convite.get("peerAlvo", -1)) != peer_alvo:
		_enviar_resultado_convite_ally(peer_alvo, false, "Esse convite expirou ou não é mais válido.")
		return
	if int(convite.get("expiraEm", 0)) <= Time.get_ticks_msec():
		_notificar_expiracao_convite_ally(convite)
		_convites_ally.erase(convite_id)
		return
	_convites_ally.erase(convite_id)
	var peer_origem := int(convite.get("peerOrigem", -1))
	var uid_origem := str(convite.get("uidOrigem", ""))
	var uid_alvo := str(_uid_por_peer[peer_alvo])
	if not aceitar:
		_enviar_resultado_convite_ally(peer_alvo, true, "Você recusou o convite.")
		if _uid_por_peer.has(peer_origem):
			_enviar_resultado_convite_ally(peer_origem, false, "O jogador recusou o convite.")
		return
	if not _uid_por_peer.has(peer_origem) or str(_uid_por_peer[peer_origem]) != uid_origem:
		_enviar_resultado_convite_ally(peer_alvo, false, "Quem enviou o convite não está mais conectado.")
		return
	if not _jogadores_no_mundo.has(peer_origem) or not _jogadores_no_mundo.has(peer_alvo) or _combates_por_peer.has(peer_origem) or _combates_por_peer.has(peer_alvo):
		_enviar_resultado_convite_ally(peer_alvo, false, "A situação dos jogadores mudou; convide novamente quando estiverem livres.")
		return
	var sala_origem: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_origem)
	var sala_alvo: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_alvo)
	if str(sala_origem.get("codigo", "")) != str(convite.get("codigoSala", "")) or str(sala_alvo.get("codigo", "")) != str(convite.get("codigoSala", "")):
		_enviar_resultado_convite_ally(peer_alvo, false, "Os jogadores não estão mais na mesma sala.")
		return
	var pos_origem: Vector2 = _jogadores_no_mundo[peer_origem]
	var pos_alvo: Vector2 = _jogadores_no_mundo[peer_alvo]
	if pos_origem.distance_to(pos_alvo) > DISTANCIA_CONVITE_ALLY:
		_enviar_resultado_convite_ally(peer_alvo, false, "Vocês se afastaram demais. A Ally não foi criada.")
		return
	if _ally_por_uid.has(uid_alvo):
		_enviar_resultado_convite_ally(peer_alvo, false, "Você já pertence a uma Ally.")
		return
	var ally_id := str(_ally_por_uid.get(uid_origem, ""))
	if ally_id.is_empty():
		ally_id = "ALLY_%d" % Time.get_ticks_usec()
		_ally_ativa[ally_id] = {"id": ally_id, "liderUid": uid_origem, "membros": [uid_origem]}
		_ally_por_uid[uid_origem] = ally_id
	var ally: Dictionary = _ally_ativa.get(ally_id, {})
	var membros: Array = ally.get("membros", []).duplicate()
	if membros.size() >= LIMITE_MEMBROS_ALLY:
		_enviar_resultado_convite_ally(peer_alvo, false, "Sua Ally já está completa.")
		return
	membros.append(uid_alvo)
	ally["membros"] = membros
	_ally_ativa[ally_id] = ally
	_ally_por_uid[uid_alvo] = ally_id
	if not await _confirmar_ally_global():
		_enviar_resultado_convite_ally(peer_alvo, false, "A entrada na Ally não foi confirmada no mundo global.")
		return
	_publicar_estado_ally(ally_id)
	_enviar_resultado_convite_ally(peer_alvo, true, "Você entrou para a Ally!")
	_enviar_resultado_convite_ally(peer_origem, true, "Novo integrante aceitou o convite.")

func _publicar_estado_ally(ally_id: String) -> void:
	var ally: Dictionary = _ally_ativa.get(ally_id, {})
	if ally.is_empty():
		return
	var membros_publicos: Array = []
	for uid in ally.get("membros", []):
		for peer in _uid_por_peer.keys():
			if str(_uid_por_peer[peer]) == str(uid):
				membros_publicos.append({"peerId": int(peer), "nome": str(_perfil_por_peer.get(peer, {}).get("nome", "Aventureiro")), "lider": str(uid) == str(ally.get("liderUid", ""))})
	var dados := {"id": ally_id, "liderUid": str(ally.get("liderUid", "")), "membros": membros_publicos, "limite": LIMITE_MEMBROS_ALLY}
	for membro in ally.get("membros", []):
		for peer in _uid_por_peer.keys():
			if str(_uid_por_peer[peer]) == str(membro):
				rpc_id(int(peer), "_receber_estado_ally", dados)

func _limpar_convites_ally_expirados(agora_ms: int) -> void:
	for convite_id in _convites_ally.keys():
		var convite: Dictionary = _convites_ally[convite_id]
		if agora_ms < int(convite.get("expiraEm", 0)):
			continue
		_notificar_expiracao_convite_ally(convite)
		_convites_ally.erase(convite_id)

func _notificar_expiracao_convite_ally(convite: Dictionary) -> void:
	var peer_origem := int(convite.get("peerOrigem", -1))
	var peer_alvo := int(convite.get("peerAlvo", -1))
	if peer_origem > 0 and _uid_por_peer.has(peer_origem):
		_enviar_resultado_convite_ally(peer_origem, false, "O convite para Ally expirou sem resposta.")
	if peer_alvo > 0 and _uid_por_peer.has(peer_alvo):
		_enviar_resultado_convite_ally(peer_alvo, false, "O convite para Ally expirou.")

func _notificar_cancelamento_convite_ally(convite: Dictionary, peer_desconectado: int) -> void:
	var peer_origem := int(convite.get("peerOrigem", -1))
	var peer_alvo := int(convite.get("peerAlvo", -1))
	var peer_notificar := peer_alvo if peer_origem == peer_desconectado else peer_origem
	if peer_notificar > 0 and peer_notificar != peer_desconectado and _uid_por_peer.has(peer_notificar):
		_enviar_resultado_convite_ally(peer_notificar, false, "Convite para Ally cancelado porque o outro jogador desconectou.")

func _remover_uid_da_ally(uid: String) -> void:
	var ally_id := str(_ally_por_uid.get(uid, ""))
	if ally_id.is_empty():
		return
	_ally_por_uid.erase(uid)
	var ally: Dictionary = _ally_ativa.get(ally_id, {})
	var membros: Array = ally.get("membros", []).duplicate()
	membros.erase(uid)
	if membros.size() < 2:
		for membro in membros:
			_ally_por_uid.erase(str(membro))
		_ally_ativa.erase(ally_id)
	else:
		ally["membros"] = membros
		if str(ally.get("liderUid", "")) == uid:
			ally["liderUid"] = str(membros[0])
		_ally_ativa[ally_id] = ally


func _carregar_ally_persistentes() -> bool:
	_ally_por_uid.clear()
	_ally_ativa.clear()
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		push_error("Allys exigem a lease e o armazenamento D1 do mundo global.")
		return false
	var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento("allies")
	if not _repositorio_mundo_remoto.lease_ativa:
		push_error("Lease global perdida durante a recuperação das Allys.")
		return false
	if not bool(remoto.get("ok", false)):
		push_error("Não foi possível carregar as Allys do D1: " + str(remoto.get("erro", "")))
		return false
	var revisao := int(remoto.get("revisao", -1))
	var registros: Array = []
	if revisao > 0:
		var payload = remoto.get("payload", null)
		if not (payload is Dictionary) or int(payload.get("versao", 0)) != 1 or not (payload.get("allys", null) is Array):
			push_error("Documento global de Allys possui formato inválido; inicialização bloqueada.")
			return false
		registros = payload.get("allys", [])
	else:
		var arquivo_local: Dictionary = _carregar_allys_locais()
		if not bool(arquivo_local.get("sucesso", false)):
			return false
		registros = arquivo_local.get("allys", [])
		var migracao: Dictionary = await _repositorio_mundo_remoto.salvar_documento("allies", {"versao": 1, "allys": registros}, 0)
		if not _repositorio_mundo_remoto.lease_ativa:
			push_error("Lease global perdida durante a migração das Allys.")
			return false
		if not bool(migracao.get("ok", false)) or int(migracao.get("revisao", -1)) <= 0:
			push_error("Migração inicial das Allys para D1 falhou: " + str(migracao.get("erro", "")))
			return false
		revisao = int(migracao.get("revisao", -1))
	if not _restaurar_allys(registros):
		return false
	_revisao_ally_remota = revisao
	if not _salvar_ally_persistentes():
		push_warning("D1 carregou as Allys, mas o espelho local não foi atualizado.")
	print("Allys globais restauradas: %d (D1 revisão %d)." % [_ally_ativa.size(), revisao])
	return true

func _carregar_allys_locais() -> Dictionary:
	if not FileAccess.file_exists(CAMINHO_ALLYS):
		return {"sucesso": true, "allys": []}
	var arquivo := FileAccess.open(CAMINHO_ALLYS, FileAccess.READ)
	if arquivo == null:
		return {"sucesso": false, "erro": "Não foi possível abrir o arquivo local de Allys."}
	var dados = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1 or not (dados.get("allys", null) is Array):
		return {"sucesso": false, "erro": "Arquivo local de Allys possui formato inválido."}
	return {"sucesso": true, "allys": dados.get("allys", [])}

func _restaurar_allys(registros: Array) -> bool:
	_ally_por_uid.clear()
	_ally_ativa.clear()
	for registro in registros:
		if not (registro is Dictionary):
			return false
		var ally_id := str(registro.get("id", ""))
		var lider := str(registro.get("liderUid", ""))
		var membros = registro.get("membros", [])
		if ally_id.is_empty() or ally_id.length() > 100 or lider.is_empty() or not (membros is Array) or membros.size() < 2 or membros.size() > LIMITE_MEMBROS_ALLY or not membros.has(lider) or _ally_ativa.has(ally_id):
			push_error("Registro global de Ally inválido; inicialização interrompida.")
			return false
		var membros_validos: Array = []
		for valor in membros:
			var uid := str(valor)
			if uid.is_empty() or uid.length() > 256 or membros_validos.has(uid) or _ally_por_uid.has(uid):
				push_error("Membros duplicados ou inválidos no documento global de Allys.")
				return false
			membros_validos.append(uid)
		var ally := {"id": ally_id, "liderUid": lider, "membros": membros_validos}
		_ally_ativa[ally_id] = ally
		for uid in membros_validos:
			_ally_por_uid[uid] = ally_id
	return true

func _exportar_allys_globais() -> Array:
	var registros: Array = []
	var ids: Array = _ally_ativa.keys()
	ids.sort()
	for ally_id in ids:
		var ally: Dictionary = _ally_ativa[ally_id]
		registros.append({"id": str(ally_id), "liderUid": str(ally.get("liderUid", "")), "membros": (ally.get("membros", []) as Array).duplicate()})
	return registros

func _confirmar_ally_global() -> bool:
	if multiplayer == null or not multiplayer.is_server() or _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		encerrar_servidor_por_falha_persistencia_global("Lease D1 indisponível ao confirmar Allys.")
		return false
	while _ally_gravacao_remota_em_andamento:
		await get_tree().process_frame
		if not multiplayer.is_server() or not _repositorio_mundo_remoto.lease_ativa:
			return false
	_ally_gravacao_remota_em_andamento = true
	var sucesso := false
	for tentativa in range(16):
		var registros := _exportar_allys_globais()
		var payload := {"versao": 1, "allys": registros}
		var gravacao: Dictionary = await _repositorio_mundo_remoto.salvar_documento("allies", payload, _revisao_ally_remota)
		if not bool(gravacao.get("ok", false)):
			push_error("Falha ao confirmar Allys no D1: " + str(gravacao.get("erro", "")))
			break
		var nova_revisao := int(gravacao.get("revisao", -1))
		if nova_revisao <= _revisao_ally_remota:
			push_error("D1 não retornou revisão crescente para as Allys.")
			break
		_revisao_ally_remota = nova_revisao
		if not _salvar_ally_persistentes():
			push_warning("O D1 confirmou Allys, mas o espelho local não foi atualizado.")
		if JSON.stringify(registros) == JSON.stringify(_exportar_allys_globais()):
			sucesso = true
			break
	_ally_gravacao_remota_em_andamento = false
	if not sucesso:
		encerrar_servidor_por_falha_persistencia_global("O estado das Allys não pôde ser confirmado integralmente no D1.")
	return sucesso


func _salvar_ally_persistentes() -> bool:
	if multiplayer == null or not multiplayer.is_server():
		return false
	var registros: Array = []
	for ally_id in _ally_ativa.keys():
		var ally: Dictionary = _ally_ativa[ally_id]
		registros.append({"id": str(ally_id), "liderUid": str(ally.get("liderUid", "")), "membros": (ally.get("membros", []) as Array).duplicate()})
	var diretorio := DirAccess.open("user://")
	if diretorio == null:
		push_error("Não foi possível acessar o diretório de dados para salvar Allys.")
		return false
	if not diretorio.dir_exists("dados") and diretorio.make_dir("dados") != OK:
		push_error("Não foi possível criar o diretório de Allys persistentes.")
		return false
	var arquivo := FileAccess.open(CAMINHO_ALLYS, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível gravar as Allys persistentes.")
		return false
	arquivo.store_string(JSON.stringify({"versao": 1, "allys": registros}))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		push_error("Falha ao finalizar a gravação das Allys persistentes.")
		return false
	return true

func _enviar_estado_ally_vazio_uid(uid: String) -> void:
	for peer in _uid_por_peer.keys():
		if str(_uid_por_peer[peer]) == uid:
			if int(peer) == multiplayer.get_unique_id():
				ally_atualizada.emit({})
			else:
				rpc_id(int(peer), "_receber_estado_ally", {})
			return

func _enviar_resultado_convite_ally(peer_id: int, sucesso: bool, mensagem: String) -> void:
	if peer_id <= 0:
		return
	if multiplayer.is_server() and peer_id == multiplayer.get_unique_id():
		resultado_convite_ally.emit(sucesso, mensagem)
	else:
		rpc_id(peer_id, "_receber_resultado_convite_ally", sucesso, mensagem)

@rpc("authority", "call_remote", "reliable")
func _receber_resultado_convite_ally(sucesso: bool, mensagem: String) -> void:
	resultado_convite_ally.emit(sucesso, mensagem)

@rpc("authority", "call_remote", "reliable")
func _receber_convite_ally(convite: Dictionary) -> void:
	convite_ally_recebido.emit(convite.duplicate(true))

@rpc("authority", "call_remote", "reliable")
func _receber_estado_ally(ally: Dictionary) -> void:
	ally_atualizada.emit(ally.duplicate(true))


## Envia uma mensagem narrativa; a identidade é obtida exclusivamente da sessão autenticada.
func enviar_mensagem_aventura_sala(texto: String) -> void:
	var mensagem := texto.strip_edges()
	if mensagem.is_empty() or mensagem.length() > 300:
		resultado_mensagem_aventura.emit(false, "A mensagem deve ter de 1 a 300 caracteres.")
		return
	if estado == EstadoConexao.SERVIDOR:
		await _processar_mensagem_aventura_sala(multiplayer.get_unique_id(), mensagem)
	elif estado == EstadoConexao.CONECTADO:
		_solicitar_mensagem_aventura_sala.rpc_id(1, mensagem)

@rpc("any_peer", "call_remote", "reliable")
func _solicitar_mensagem_aventura_sala(texto: String) -> void:
	if not multiplayer.is_server():
		return
	await _processar_mensagem_aventura_sala(multiplayer.get_remote_sender_id(), texto)

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
	if not await _confirmar_salas_globais():
		_enviar_resultado_mensagem(peer_id, false, "Não foi possível salvar a mensagem no mundo global.")
		return
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
	if not await _confirmar_salas_globais():
		return {"sucesso": false, "erro": "Não foi possível confirmar a entrada da sala no mundo global."}
	var sala: Dictionary = resultado.get("sala", {})
	var estado_sala: Dictionary = sala.get("estadoAventura", {})
	var encontro_pendente: Dictionary = estado_sala.get("encontro", {})
	if str(encontro_pendente.get("resultado", "")) == "vitoria" and not bool(encontro_pendente.get("ecologiaConcluida", false)):
		if _registrar_ecologia_encontro_cooperativo(encontro_pendente):
			encontro_pendente["ecologiaConcluida"] = true
			estado_sala["encontro"] = encontro_pendente
			var salvo_ecologia_reentrada: Dictionary = _salas_publicas.atualizar_estado_aventura(peer_id, estado_sala, int(sala.get("revisaoAventura", 0)))
			if bool(salvo_ecologia_reentrada.get("sucesso", false)):
				if not await _confirmar_salas_globais():
					return {"sucesso": false, "erro": "A recuperação ecológica da sala não foi confirmada no D1."}
				sala = _salas_publicas.obter_sala_do_jogador(peer_id)
				estado_sala = sala.get("estadoAventura", {})
				encontro_pendente = estado_sala.get("encontro", {})
			else:
				encontro_pendente["ecologiaConcluida"] = false
	if str(encontro_pendente.get("resultado", "")) == "vitoria" and bool(encontro_pendente.get("ecologiaConcluida", false)) and not bool(encontro_pendente.get("recompensasConcluidas", false)):
		if _conceder_recompensas_encontro_cooperativo(encontro_pendente):
			encontro_pendente["recompensasConcluidas"] = true
			estado_sala["encontro"] = encontro_pendente
			var revisao_sala := int(sala.get("revisaoAventura", 0))
			var atualizacao_recompensa: Dictionary = _salas_publicas.atualizar_estado_aventura(peer_id, estado_sala, revisao_sala)
			if bool(atualizacao_recompensa.get("sucesso", false)):
				if not await _confirmar_salas_globais():
					return {"sucesso": false, "erro": "As recompensas não foram confirmadas no D1."}
	elif str(encontro_pendente.get("resultado", "")) == "derrota" and not bool(encontro_pendente.get("recursosDerrotaConcluidos", false)):
		if _processar_derrota_total_encontro_cooperativo(peer_id, encontro_pendente):
			encontro_pendente["recursosDerrotaConcluidos"] = true
			estado_sala["encontro"] = encontro_pendente
			var revisao_derrota := int(sala.get("revisaoAventura", 0))
			var atualizacao_derrota: Dictionary = _salas_publicas.atualizar_estado_aventura(peer_id, estado_sala, revisao_derrota)
			if bool(atualizacao_derrota.get("sucesso", false)):
				if not await _confirmar_salas_globais():
					return {"sucesso": false, "erro": "A derrota não foi confirmada no D1."}
	return {"sucesso":true, "codigo":str(resultado.get("codigo","")), "jogadores":(sala.get("jogadores",[]) as Array).size(), "limite":SISTEMA_SALAS.MAXIMO_JOGADORES_POR_SALA, "anfitriaoPeerId":int(sala.get("anfitriaoPeerId",peer_id))}

func _carregar_salas_persistentes() -> bool:
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		push_error("Salas cooperativas exigem a lease e o armazenamento D1 do mundo global.")
		return false
	var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento("cooperative_rooms")
	if not _repositorio_mundo_remoto.lease_ativa:
		push_error("Lease global perdida durante a recuperação das salas cooperativas.")
		return false
	if not bool(remoto.get("ok", false)):
		push_error("Não foi possível carregar as salas do D1: " + str(remoto.get("erro", "")))
		return false
	var revisao := int(remoto.get("revisao", -1))
	var payload: Dictionary = {}
	if revisao > 0:
		var bruto = remoto.get("payload", null)
		if not (bruto is Dictionary) or int(bruto.get("versao", 0)) != 1 or not (bruto.get("salas", null) is Array):
			push_error("Documento global de salas possui formato inválido; inicialização bloqueada.")
			return false
		payload = bruto
	else:
		var local: Dictionary = _repositorio_salas.carregar()
		if not bool(local.get("sucesso", false)):
			push_error("Não foi possível ler o espelho local para migração das salas.")
			return false
		payload = {"versao": 1, "salas": local.get("salas", [])}
		var migracao: Dictionary = await _repositorio_mundo_remoto.salvar_documento("cooperative_rooms", payload, 0)
		if not _repositorio_mundo_remoto.lease_ativa:
			push_error("Lease global perdida durante a migração das salas cooperativas.")
			return false
		if not bool(migracao.get("ok", false)) or int(migracao.get("revisao", -1)) <= 0:
			push_error("Migração inicial das salas para D1 falhou: " + str(migracao.get("erro", "")))
			return false
		revisao = int(migracao.get("revisao", -1))
	var restauracao: Dictionary = _salas_publicas.restaurar_estado_persistente(payload.get("salas", []))
	if not bool(restauracao.get("sucesso", false)):
		push_error("Estado persistente global das salas foi rejeitado: " + str(restauracao.get("erro", "erro desconhecido")))
		return false
	_revisao_salas_remota = revisao
	if not _repositorio_salas.salvar(payload.get("salas", [])):
		push_error("Aviso: D1 foi carregado, mas o espelho local das salas não pôde ser atualizado.")
	print("Salas cooperativas globais restauradas: %d (D1 revisão %d)." % [int(restauracao.get("quantidade", 0)), revisao])
	return true

func _salvar_salas_persistentes() -> bool:
	if multiplayer == null or not multiplayer.is_server():
		return false
	if not _repositorio_salas.salvar(_salas_publicas.exportar_estado_persistente()):
		push_error("Não foi possível atualizar o espelho local das salas cooperativas.")
		return false
	return true

func _confirmar_salas_globais() -> bool:
	if multiplayer == null or not multiplayer.is_server() or _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		encerrar_servidor_por_falha_persistencia_global("Lease D1 indisponível ao confirmar salas cooperativas.")
		return false
	while _salas_gravacao_remota_em_andamento:
		await get_tree().process_frame
		if not multiplayer.is_server() or not _repositorio_mundo_remoto.lease_ativa:
			return false
	_salas_gravacao_remota_em_andamento = true
	var sucesso := false
	for tentativa in range(16):
		var registros := _salas_publicas.exportar_estado_persistente()
		var payload := {"versao": 1, "salas": registros}
		var gravacao: Dictionary = await _repositorio_mundo_remoto.salvar_documento("cooperative_rooms", payload, _revisao_salas_remota)
		if not bool(gravacao.get("ok", false)):
			push_error("Falha ao confirmar salas cooperativas no D1: " + str(gravacao.get("erro", "")))
			break
		var nova_revisao := int(gravacao.get("revisao", -1))
		if nova_revisao <= _revisao_salas_remota:
			push_error("D1 não retornou uma revisão crescente para as salas cooperativas.")
			break
		_revisao_salas_remota = nova_revisao
		if not _repositorio_salas.salvar(registros):
			push_warning("O D1 confirmou as salas, mas o espelho local não foi atualizado.")
		if JSON.stringify(registros) == JSON.stringify(_salas_publicas.exportar_estado_persistente()):
			sucesso = true
			break
	_salas_gravacao_remota_em_andamento = false
	if not sucesso:
		encerrar_servidor_por_falha_persistencia_global("O estado das salas não pôde ser confirmado integralmente no D1.")
	return sucesso

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
	if not await _confirmar_salas_globais():
		return {"sucesso": false, "erro": "A aventura não foi confirmada no armazenamento global."}
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
		return {"sucesso": false, "erro": "O encontro exige uma Ally com dois a quatro integrantes ativos."}
	var id := criatura_id.strip_edges()
	if id.is_empty() or id.length() > 128:
		return {"sucesso": false, "erro": "Identificador de criatura inválido."}
	var criatura: Dictionary = _repositorio_criaturas.obter_criatura(id)
	var criatura_mundo: Dictionary = _criaturas_mundo_cache.get(id, {})
	if criatura.is_empty() or criatura_mundo.is_empty():
		return {"sucesso": false, "erro": "A criatura não está presente no mundo compartilhado."}
	var posicao_dados: Dictionary = criatura_mundo.get("posicaoMundo", {})
	var posicao_criatura := Vector2(float(posicao_dados.get("x", -10000.0)), float(posicao_dados.get("y", -10000.0)))
	if not _jogadores_no_mundo.has(peer_id) or _jogadores_no_mundo[peer_id].distance_to(posicao_criatura) > 92.0:
		return {"sucesso": false, "erro": "Aproxime-se da criatura para iniciar o encontro."}
	var peers_proximos: Array = _listar_peers_proximos_criatura(peer_id, posicao_criatura, 260.0)
	if peers_proximos.size() < 2:
		return {"sucesso": false, "erro": "Pelo menos dois integrantes da Ally precisam estar próximos da criatura."}
	var participantes: Array = []
	for membro_peer in peers_proximos:
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
			"agilidade": int(atributos.get("agilidade", 5)),
			"sorte": clampf(float(perfil.get("sorte", 0.0)), 0.0, 100.0),
			"classeId": str(perfil.get("classeId", "")).strip_edges().to_lower(),
			"armaOnePieceId": arma_id if not CATALOGO_ARMAS_ONE_PIECE.obter(arma_id).is_empty() else "",
			"armaId": arma_id,
			"maestriaArmas": perfil.get("maestriaArmas", {}).duplicate(true) if perfil.get("maestriaArmas", {}) is Dictionary else {}
		})
	var criatura_com_contexto: Dictionary = criatura.duplicate(true)
	criatura_com_contexto["periodoRecompensa"] = str(_contexto_celeste_atual.get("periodo", "dia"))
	var resultado: Dictionary = _salas_publicas.registrar_encontro(peer_id, criatura_com_contexto, participantes)
	if not bool(resultado.get("sucesso", false)):
		return resultado
	if not await _confirmar_salas_globais():
		return {"sucesso": false, "erro": "O encontro não foi confirmado no armazenamento global."}
	_publicar_estado_aventura_da_sala(peer_id)
	return resultado

## Cliente envia somente uma das ações básicas; identidade e turno são conferidos pelo servidor.
func solicitar_acao_encontro_cooperativo(acao: String, alvo_id: String = "") -> void:
	if estado == EstadoConexao.SERVIDOR:
		await _processar_acao_encontro_cooperativo(multiplayer.get_unique_id(), acao, alvo_id)
	elif estado == EstadoConexao.CONECTADO:
		_solicitar_acao_encontro_cooperativo.rpc_id(1, acao, alvo_id)

@rpc("any_peer", "call_remote", "reliable")
func _solicitar_acao_encontro_cooperativo(acao: String, alvo_id: String = "") -> void:
	if multiplayer.is_server():
		await _processar_acao_encontro_cooperativo(multiplayer.get_remote_sender_id(), acao, alvo_id)

func _processar_acao_encontro_cooperativo(peer_id: int, acao: String, alvo_id: String = "") -> void:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id):
		return
	if alvo_id.length() > 128:
		_notificar_erro_interacao_criatura(peer_id, "Identificador de alvo inválido.")
		return
	var agora := Time.get_ticks_msec()
	if not _registrar_acao_combate_se_permitida(peer_id, agora):
		return
	var semente := int(Time.get_ticks_usec()) ^ (peer_id * 104729)
	var resultado: Dictionary = _salas_publicas.executar_acao_encontro(peer_id, str(_uid_por_peer[peer_id]), acao, semente, alvo_id)
	if not bool(resultado.get("sucesso", false)):
		if peer_id == multiplayer.get_unique_id():
			erro_combate.emit(str(resultado.get("erro", "Ação recusada.")))
		else:
			rpc_id(peer_id, "_receber_erro_combate", str(resultado.get("erro", "Ação recusada.")))
		return
	var sala_maestria := _salas_publicas.obter_sala_do_jogador(peer_id)
	var estado_maestria: Dictionary = sala_maestria.get("estadoAventura", {})
	var encontro_maestria: Dictionary = estado_maestria.get("encontro", {})
	var combate_maestria: Dictionary = encontro_maestria.get("combate", {})
	var maestrias_participante: Dictionary = combate_maestria.get("maestriaArmasAtualizada", {})
	var uid_acao := str(_uid_por_peer.get(peer_id, ""))
	if maestrias_participante.has(uid_acao):
		var salvo_maestria_coop := _repositorio_perfis.salvar_maestria_armas(uid_acao, maestrias_participante[uid_acao])
		if bool(salvo_maestria_coop.get("ok", false)):
			_perfil_por_peer[peer_id] = salvo_maestria_coop.get("perfil", _perfil_por_peer.get(peer_id, {})).duplicate(true)
		else:
			push_error("Maestria cooperativa ainda não foi persistida: " + str(salvo_maestria_coop.get("erro", "")))
	if not await _confirmar_salas_globais():
		return
	var sala_atual := _salas_publicas.obter_sala_do_jogador(peer_id)
	var estado_atual: Dictionary = sala_atual.get("estadoAventura", {})
	var encontro_atual: Dictionary = estado_atual.get("encontro", {})
	if str(encontro_atual.get("resultado", "")) == "vitoria" and not bool(encontro_atual.get("ecologiaConcluida", false)):
		if _registrar_ecologia_encontro_cooperativo(encontro_atual):
			encontro_atual["ecologiaConcluida"] = true
			estado_atual["encontro"] = encontro_atual
			var salvo_ecologia: Dictionary = _salas_publicas.atualizar_estado_aventura(peer_id, estado_atual, int(sala_atual.get("revisaoAventura", 0)))
			if bool(salvo_ecologia.get("sucesso", false)):
				if not await _confirmar_salas_globais():
					return
				sala_atual = _salas_publicas.obter_sala_do_jogador(peer_id)
			else:
				encontro_atual["ecologiaConcluida"] = false
				push_error("Derrotas ecológicas registradas, mas o marcador do encontro não foi persistido.")
		else:
			push_error("Registro ecológico do encontro ficou pendente; as recompensas aguardam a conclusão.")
	if str(encontro_atual.get("resultado", "")) == "vitoria" and bool(encontro_atual.get("ecologiaConcluida", false)) and not bool(encontro_atual.get("recompensasConcluidas", false)):
		if _conceder_recompensas_encontro_cooperativo(encontro_atual):
			encontro_atual["recompensasConcluidas"] = true
			estado_atual["encontro"] = encontro_atual
			var salvo_recompensas: Dictionary = _salas_publicas.atualizar_estado_aventura(peer_id, estado_atual, int(sala_atual.get("revisaoAventura", 0)))
			if bool(salvo_recompensas.get("sucesso", false)):
				if not await _confirmar_salas_globais():
					return
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
				if not await _confirmar_salas_globais():
					return
			else:
				push_error("Recursos restaurados, mas não foi possível registrar a conclusão da derrota.")
		else:
			push_error("A restauração após derrota total ficou pendente; será tentada novamente.")
	_publicar_estado_aventura_da_sala(peer_id)


## Persiste cada indivíduo derrotado antes de liberar as recompensas do encontro.
## O repositório ecológico é idempotente por grupo/indivíduo, permitindo retomar após falha.
func _registrar_ecologia_encontro_cooperativo(encontro: Dictionary) -> bool:
	var combate: Dictionary = encontro.get("combate", {})
	var inimigos_estado: Array = combate.get("inimigos", []) if combate.get("inimigos", []) is Array else []
	var dados: Dictionary = encontro.get("dadosRecompensa", {})
	var inimigos_dados: Array = dados.get("inimigos", []) if dados.get("inimigos", []) is Array else []
	if inimigos_estado.is_empty() or inimigos_dados.size() != inimigos_estado.size():
		return inimigos_estado.is_empty()
	var uid_vencedor := str(combate.get("uidMaiorDano", ""))
	if uid_vencedor.is_empty():
		var participantes: Array = combate.get("participantes", [])
		if participantes.is_empty():
			return false
		uid_vencedor = str(participantes[0].get("uid", ""))
	if uid_vencedor.is_empty():
		return false
	var grupos_alterados: Dictionary = {}
	for indice in range(inimigos_estado.size()):
		var estado_inimigo: Dictionary = inimigos_estado[indice]
		if int(estado_inimigo.get("vida", 0)) > 0:
			continue
		var criatura: Dictionary = inimigos_dados[indice]
		var grupo_id := str(criatura.get("grupoId", ""))
		var individuo_id := str(criatura.get("individuoId", ""))
		var especie_id := str(criatura.get("especieId", criatura.get("id", "")))
		if grupo_id.is_empty() or individuo_id.is_empty():
			continue
		var registro: Dictionary = _repositorio_grupos.registrar_derrota_em_combate(grupo_id, individuo_id, uid_vencedor)
		if not bool(registro.get("ok", false)):
			push_error("Não foi possível persistir a derrota ecológica de %s: %s" % [individuo_id, str(registro.get("erro", ""))])
			return false
		grupos_alterados[grupo_id] = registro.get("grupo", {})
		var estatistica := _repositorio_criaturas.registrar_derrota_individuo(uid_vencedor, especie_id, individuo_id)
		if not bool(estatistica.get("ok", false)):
			push_error("A criatura foi removida do grupo, mas a estatística global não foi atualizada: %s" % especie_id)
			return false
	for grupo_id in grupos_alterados:
		_grupos_mundo_cache[str(grupo_id)] = grupos_alterados[grupo_id]
	if not grupos_alterados.is_empty():
		rpc("_receber_grupos_selvagens", _lista_visual_individuos_grupos())
	return true

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
	var dados_recompensa: Dictionary = encontro.get("dadosRecompensa", {})
	if dados_recompensa.is_empty():
		return false
	var criaturas_recompensa: Array = dados_recompensa.get("inimigos", []) if dados_recompensa.get("inimigos", []) is Array and not dados_recompensa.get("inimigos", []).is_empty() else [dados_recompensa]
	var criatura: Dictionary = criaturas_recompensa[0] if criaturas_recompensa[0] is Dictionary else dados_recompensa
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
	var uid_destaque := str(participantes[indice_destaque].get("uid", "")).strip_edges()
	if uid_destaque.is_empty():
		return false
	var perfil_destaque: Dictionary = _repositorio_perfis.carregar_ou_criar(uid_destaque)
	if perfil_destaque.is_empty():
		return false
	var contexto_base := {
		"sorte":float(participantes[indice_destaque].get("sorte", 0.0)),
		"periodo":str(criatura.get("periodoRecompensa", "dia")),
		"nivelPerigo":int(criatura.get("perigo", 0))
	}
	var classe_destaque := str(participantes[indice_destaque].get("classeId", "")).strip_edges().to_lower()
	if classe_destaque.is_empty():
		classe_destaque = str(perfil_destaque.get("classeId", "")).strip_edges().to_lower()
	var drops_obtidos: Array = []
	for criatura_recompensa in criaturas_recompensa:
		if not (criatura_recompensa is Dictionary):
			return false
		var contexto := contexto_base.duplicate(true)
		contexto["periodo"] = str(criatura_recompensa.get("periodoRecompensa", contexto_base.get("periodo", "dia")))
		contexto["nivelPerigo"] = int(criatura_recompensa.get("perigo", contexto_base.get("nivelPerigo", 0)))
		# Cada indivíduo usa semente própria e estável para retomar a concessão sem rerrolar.
		var identidade_individuo := str(criatura_recompensa.get("individuoId", criatura_recompensa.get("id", "")))
		contexto["semente"] = (encontro_id.hash() ^ identidade_individuo.hash()) & 0x7fffffff
		var tabela: Array = criatura_recompensa.get("tabelaDrops", []).duplicate(true) if criatura_recompensa.get("tabelaDrops", []) is Array else []
		var moeda := SistemaDrops.criar_entrada_moeda_criatura(criatura_recompensa, contexto)
		if not moeda.is_empty():
			tabela.append(moeda)
		if classe_destaque != "invocador":
			var ovo := SistemaDrops.criar_entrada_ovo(criatura_recompensa)
			if not ovo.is_empty():
				tabela.append(ovo)
		var rolagens: Array = SistemaDrops.resolver_tabela(tabela, str(criatura_recompensa.get("id", "")), contexto)
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
		if not await _confirmar_salas_globais():
			return {"sucesso": false, "erro": "Não foi possível persistir o encerramento do encontro."}
		_publicar_estado_aventura_da_sala(peer_id)
	return resultado

## Envia o snapshot exclusivamente aos integrantes registrados na mesma sala.
func _publicar_estado_aventura_da_sala(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sala := _salas_publicas.obter_sala_do_jogador(peer_id)
	if sala.is_empty():
		return
	for membro in sala.get("jogadores", []):
		var membro_id := int(membro)
		var snapshot_publico: Dictionary = _salas_publicas.obter_snapshot_publico(membro_id)
		if snapshot_publico.is_empty():
			continue
		if membro_id == multiplayer.get_unique_id():
			_receber_estado_aventura_sala(snapshot_publico)
		else:
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
	var chance: float = SISTEMA_INVOCACOES.calcular_chance_domesticacao(criatura_escolhida)
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

func atualizar_posicao_local_cache(posicao: Vector2) -> void:
	if not is_finite(posicao.x) or not is_finite(posicao.y):
		return
	if perfil_personagem_atual.is_empty():
		return
	perfil_personagem_atual["x"] = posicao.x
	perfil_personagem_atual["y"] = posicao.y

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
	await _registrar_visita_local_confirmada(id_jogador, posicao_solicitada)
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
	await _processar_resultado_equipamento(peer_id, resultado)

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
	# Equipamento altera atributos e combate: só confirma ao cliente depois
	# que a revisão individual também foi aceita pelo armazenamento global.
	if not await _confirmar_perfil_global(uid):
		rpc_id(peer_id, "_receber_resultado_equipamento", false, "Equipamento não confirmado na persistência global. O servidor foi colocado em segurança.", {})
		return
	perfil = _repositorio_perfis.carregar_ou_criar(uid)
	if perfil.is_empty():
		encerrar_servidor_por_falha_persistencia_global("Perfil indisponível após sincronizar equipamento: " + uid)
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

## Cliente envia somente o ID do baú; posição, estado e criatura são conferidos pelo servidor.
func solicitar_interacao_mimico(bau_id: String) -> void:
	var id := bau_id.strip_edges()
	if id.is_empty() or id.length() > 128:
		erro_combate.emit("Baú inválido.")
		return
	if estado == EstadoConexao.CONECTADO:
		_solicitar_interacao_mimico.rpc_id(1, id)
	elif estado == EstadoConexao.SERVIDOR and multiplayer.is_server():
		_processar_interacao_mimico(multiplayer.get_unique_id(), id)

@rpc("any_peer", "call_remote", "reliable")
func _solicitar_interacao_mimico(bau_id: String) -> void:
	if multiplayer.is_server():
		_processar_interacao_mimico(multiplayer.get_remote_sender_id(), bau_id)

func _processar_interacao_mimico(peer_id: int, bau_id: String) -> void:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id):
		return
	if _combates_por_peer.has(peer_id):
		_notificar_erro_interacao_criatura(peer_id, "Você já está em combate.")
		return
	var bau := _repositorio_mimicos.obter(bau_id)
	if bau.is_empty() or str(bau.get("estado", "")) != "disfarcado":
		_notificar_erro_interacao_criatura(peer_id, "Este baú já foi aberto ou não existe.")
		return
	var posicao_dados: Dictionary = bau.get("posicao", {})
	var posicao_bau := Vector2(float(posicao_dados.get("x", -10000.0)), float(posicao_dados.get("y", -10000.0)))
	if _jogadores_no_mundo[peer_id].distance_to(posicao_bau) > 90.0:
		_notificar_erro_interacao_criatura(peer_id, "Aproxime-se do baú para investigar.")
		return
	var uid := str(_uid_por_peer[peer_id])
	var reserva := _repositorio_mimicos.reservar_encontro(bau_id, uid)
	if not bool(reserva.get("ok", false)):
		_notificar_erro_interacao_criatura(peer_id, str(reserva.get("erro", "Este baú não está disponível.")))
		return
	await _publicar_mimicos()
	var mimico: Dictionary = bau.get("mimico", {})
	var decisao := SISTEMA_MIMICOS.decidir_comportamento(mimico, {"jogadorInteragiu":true,"distanciaJogador":_jogadores_no_mundo[peer_id].distance_to(posicao_bau)}, int(Time.get_ticks_usec()))
	if not bool(decisao.get("iniciaCombate", false)):
		_repositorio_mimicos.liberar_reserva(bau_id, uid)
		await _publicar_mimicos()
		_notificar_erro_interacao_criatura(peer_id, "O baú não reagiu. Tente novamente.")
		return
	var inimigo := SISTEMA_MIMICOS.preparar_inimigo_combate(mimico)
	var estado_inicial := SistemaCombate.criar_estado(_perfil_por_peer[peer_id], inimigo, _obter_contexto_celeste_servidor())
	if estado_inicial.is_empty():
		_repositorio_mimicos.liberar_reserva(bau_id, uid)
		await _publicar_mimicos()
		_notificar_erro_interacao_criatura(peer_id, "Não foi possível preparar a emboscada.")
		return
	estado_inicial["historico"].append("O baú se abriu e revelou um mímico %s!" % str(mimico.get("raridade", "comum")))
	_combates_por_peer[peer_id] = {"estado":estado_inicial,"criatura":inimigo,"criaturas":[inimigo],"mimicoBauId":bau_id,"mimico":true}
	_enviar_estado_combate_peer(peer_id, estado_inicial)

@rpc("authority", "call_remote", "reliable")
func _receber_mimicos(lista: Array) -> void:
	mimicos_publicos_cache = lista.duplicate(true)
	mimicos_recebidos.emit(mimicos_publicos_cache.duplicate(true))

func obter_mimicos_publicos() -> Array:
	return mimicos_publicos_cache.duplicate(true)

## A piedade é progresso por UID: a troca de host nunca pode reiniciar os contadores.
## O documento único é protegido por lease global + revisão CAS.
func _carregar_piedade_mimicos_global() -> bool:
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		return false
	var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento("mimic_pity")
	if not _repositorio_mundo_remoto.lease_ativa:
		push_error("Lease global perdida durante a recuperação da piedade dos mímicos.")
		return false
	if not bool(remoto.get("ok", false)):
		push_error("Falha ao carregar piedade global: " + str(remoto.get("erro", "")))
		return false
	_revisao_piedade_mimicos_remota = int(remoto.get("revisao", -1))
	if _revisao_piedade_mimicos_remota < 0:
		return false
	if _revisao_piedade_mimicos_remota > 0:
		if not _repositorio_piedade_mimicos.importar_estado_persistente(remoto.get("payload", null)):
			push_error("Snapshot remoto de piedade inválido; progresso local não substituirá o global.")
			return false
		_snapshot_piedade_mimicos_remoto = JSON.stringify(remoto.get("payload", {}))
	else:
		var legado := _repositorio_piedade_mimicos.exportar_estado_persistente()
		if legado.is_empty():
			return false
		var migracao: Dictionary = await _repositorio_mundo_remoto.salvar_documento("mimic_pity", legado, 0)
		if not _repositorio_mundo_remoto.lease_ativa:
			push_error("Lease global perdida durante a migração da piedade dos mímicos.")
			return false
		if not bool(migracao.get("ok", false)):
			push_error("Migração inicial da piedade falhou: " + str(migracao.get("erro", "")))
			return false
		_revisao_piedade_mimicos_remota = int(migracao.get("revisao", -1))
		if _revisao_piedade_mimicos_remota <= 0:
			return false
		_snapshot_piedade_mimicos_remoto = JSON.stringify(legado)
	if _snapshot_piedade_mimicos_remoto.is_empty():
		return await _sincronizar_piedade_mimicos_global()
	return true

func _sincronizar_piedade_mimicos_global() -> bool:
	if _piedade_mimicos_gravacao_remota_em_andamento:
		return false
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa or _revisao_piedade_mimicos_remota < 1:
		return false
	var snapshot := _repositorio_piedade_mimicos.exportar_estado_persistente()
	if snapshot.is_empty():
		return false
	var serializado := JSON.stringify(snapshot)
	if serializado == _snapshot_piedade_mimicos_remoto:
		return true
	_piedade_mimicos_gravacao_remota_em_andamento = true
	var gravacao: Dictionary = await _repositorio_mundo_remoto.salvar_documento("mimic_pity", snapshot, _revisao_piedade_mimicos_remota)
	_piedade_mimicos_gravacao_remota_em_andamento = false
	if not bool(gravacao.get("ok", false)):
		push_error("Conflito ou falha ao persistir piedade global: " + str(gravacao.get("erro", "")))
		return false
	var nova_revisao := int(gravacao.get("revisao", -1))
	if nova_revisao <= _revisao_piedade_mimicos_remota:
		return false
	_revisao_piedade_mimicos_remota = nova_revisao
	_snapshot_piedade_mimicos_remoto = serializado
	return true

## Recupera os mímicos do documento global. O arquivo local só é usado na migração inicial.
func _carregar_mimicos_global(semente: int) -> bool:
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		return false
	var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento("mimics")
	if not _repositorio_mundo_remoto.lease_ativa:
		push_error("Lease global perdida durante a recuperação dos mímicos.")
		return false
	if not bool(remoto.get("ok", false)):
		push_error("Falha ao carregar mímicos globais: " + str(remoto.get("erro", "")))
		return false
	_revisao_mimicos_remota = int(remoto.get("revisao", -1))
	if _revisao_mimicos_remota < 0:
		return false
	if _revisao_mimicos_remota > 0:
		if not _repositorio_mimicos.importar_estado_persistente(remoto.get("payload", null)):
			push_error("Snapshot global de mímicos inválido; cache local não será usado como substituto.")
			return false
	else:
		var legado := _repositorio_mimicos.carregar_ou_criar(semente)
		if legado.is_empty():
			return false
		var snapshot := _repositorio_mimicos.exportar_estado_persistente()
		if snapshot.is_empty():
			return false
		var migracao: Dictionary = await _repositorio_mundo_remoto.salvar_documento("mimics", snapshot, 0)
		if not _repositorio_mundo_remoto.lease_ativa:
			push_error("Lease global perdida durante a migração dos mímicos.")
			return false
		if not bool(migracao.get("ok", false)):
			push_error("Migração inicial dos mímicos falhou: " + str(migracao.get("erro", "")))
			return false
		_revisao_mimicos_remota = int(migracao.get("revisao", -1))
		if _revisao_mimicos_remota <= 0:
			return false
	_snapshot_mimicos_remoto = JSON.stringify(_repositorio_mimicos.exportar_estado_persistente())
	if not _repositorio_mimicos.recuperar_reservas_expiradas(int(Time.get_unix_time_from_system())):
		return false
	if JSON.stringify(_repositorio_mimicos.exportar_estado_persistente()) != _snapshot_mimicos_remoto:
		if not await _sincronizar_mimicos_global():
			return false
	return not _snapshot_mimicos_remoto.is_empty()

## Reserva, liberação, derrota e expiração são confirmadas por CAS antes da publicação.
func _sincronizar_mimicos_global() -> bool:
	if _mimicos_gravacao_remota_em_andamento:
		return false
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa or _revisao_mimicos_remota < 1:
		return false
	var snapshot := _repositorio_mimicos.exportar_estado_persistente()
	if snapshot.is_empty():
		return false
	var serializado := JSON.stringify(snapshot)
	if serializado == _snapshot_mimicos_remoto:
		return true
	_mimicos_gravacao_remota_em_andamento = true
	var remoto: Dictionary = await _repositorio_mundo_remoto.salvar_documento("mimics", snapshot, _revisao_mimicos_remota)
	_mimicos_gravacao_remota_em_andamento = false
	if not bool(remoto.get("ok", false)):
		push_error("Conflito ou falha ao persistir mímicos globais: " + str(remoto.get("erro", "")))
		return false
	var nova_revisao := int(remoto.get("revisao", -1))
	if nova_revisao <= _revisao_mimicos_remota:
		return false
	_revisao_mimicos_remota = nova_revisao
	_snapshot_mimicos_remoto = serializado
	return true

func _publicar_mimicos() -> void:
	if multiplayer.is_server():
		if not await _sincronizar_mimicos_global():
			encerrar_servidor_por_falha_persistencia_global("Não foi possível confirmar a alteração dos mímicos no mundo global.")
			return
		mimicos_publicos_cache = _repositorio_mimicos.listar_ativos()
		mimicos_recebidos.emit(mimicos_publicos_cache.duplicate(true))
		rpc("_receber_mimicos", mimicos_publicos_cache)

## Inicia encontro somente quando chamado por lógica confiável do servidor.
## A criatura nunca é recebida por RPC do cliente.
## Registra uma criatura entregue pelo gerador confiável do servidor.
## Esta função nunca é exposta como RPC de cliente.
func registrar_criatura_gerada_servidor(criatura: Dictionary) -> Dictionary:
	if not multiplayer.is_server():
		return {"ok":false,"erro":"Somente o servidor pode registrar criaturas."}
	return _repositorio_criaturas.registrar_criatura_gerada(criatura)

## O cliente envia somente o ID visual; o servidor confirma existência, posição e ecossistema.
func solicitar_interacao_criatura(criatura_id: String) -> void:
	var id := criatura_id.strip_edges()
	if id.is_empty() or id.length() > 128:
		erro_combate.emit("Criatura inválida.")
		return
	if estado == EstadoConexao.SERVIDOR:
		await _processar_interacao_criatura(multiplayer.get_unique_id(), id)
	elif estado == EstadoConexao.CONECTADO:
		_solicitar_interacao_criatura.rpc_id(1, id)

@rpc("any_peer", "call_remote", "reliable")
func _solicitar_interacao_criatura(criatura_id: String) -> void:
	if multiplayer.is_server():
		await _processar_interacao_criatura(multiplayer.get_remote_sender_id(), criatura_id)

func _processar_interacao_criatura(peer_id: int, criatura_id: String) -> void:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id) or not _jogadores_no_mundo.has(peer_id):
		return
	if _combates_por_peer.has(peer_id):
		_notificar_erro_interacao_criatura(peer_id, "Você já está em combate.")
		return
	var id := criatura_id.strip_edges()
	if id.is_empty() or id.length() > 128:
		_notificar_erro_interacao_criatura(peer_id, "Esta criatura não está mais disponível no mundo.")
		return
	if not _criaturas_mundo_cache.has(id):
		var grupo_encontrado := _obter_individuo_grupo_por_id(id)
		if grupo_encontrado.is_empty():
			_notificar_erro_interacao_criatura(peer_id, "Esta criatura não está mais disponível no mundo.")
			return
		var grupo: Dictionary = grupo_encontrado.get("grupo", {})
		var individuo: Dictionary = grupo_encontrado.get("individuo", {})
		var posicao_individuo_dados: Dictionary = individuo.get("posicaoMundo", {})
		var posicao_individuo := Vector2(float(posicao_individuo_dados.get("x", -10000.0)), float(posicao_individuo_dados.get("y", -10000.0)))
		if _jogadores_no_mundo[peer_id].distance_to(posicao_individuo) > 92.0:
			_notificar_erro_interacao_criatura(peer_id, "Aproxime-se da criatura para interagir.")
			return
		var contexto_local := SISTEMA_AMBIENTES_MUNDO.obter_contexto(_jogadores_no_mundo[peer_id])
		var contexto_alvo := SISTEMA_AMBIENTES_MUNDO.obter_contexto(posicao_individuo)
		if contexto_local.is_empty() or contexto_alvo.is_empty() or str(contexto_local.get("ecossistemaId", "")) != str(contexto_alvo.get("ecossistemaId", "")) or str(contexto_local.get("bioma", "")) != str(contexto_alvo.get("bioma", "")):
			_notificar_erro_interacao_criatura(peer_id, "A criatura está em outra região do mundo.")
			return
		var criaturas_grupo := _montar_encontro_individuos_grupo(grupo, posicao_individuo, contexto_alvo)
		if criaturas_grupo.is_empty():
			_notificar_erro_interacao_criatura(peer_id, "Não foi possível reunir os indivíduos vivos deste grupo.")
			return
		var agora_grupo := Time.get_ticks_msec()
		var ultimo_grupo := int(_ultimo_encontro_ms.get(peer_id, 0))
		if ultimo_grupo > 0 and agora_grupo - ultimo_grupo < INTERVALO_MINIMO_ENCONTROS_MS:
			_notificar_erro_interacao_criatura(peer_id, "Aguarde um instante antes de iniciar outro encontro.")
			return
		var sala_grupo := _salas_publicas.obter_sala_do_jogador(peer_id)
		if not sala_grupo.is_empty():
			var encontro_grupo_atual: Dictionary = sala_grupo.get("estadoAventura", {}).get("encontro", {})
			if bool(encontro_grupo_atual.get("ativo", false)):
				_notificar_erro_interacao_criatura(peer_id, "Sua Ally já está em um encontro.")
				return
			var peers_grupo := _listar_peers_proximos_criatura(peer_id, posicao_individuo, 260.0)
			if peers_grupo.size() >= 2:
				var coop_grupo: Dictionary = await iniciar_encontro_cooperativo_grupo_servidor(peer_id, criaturas_grupo)
				if not bool(coop_grupo.get("sucesso", false)):
					_notificar_erro_interacao_criatura(peer_id, str(coop_grupo.get("erro", "Não foi possível iniciar o combate cooperativo do grupo.")))
					return
			elif not iniciar_combate_grupo_servidor(peer_id, criaturas_grupo):
				_notificar_erro_interacao_criatura(peer_id, "Não foi possível iniciar o combate contra o grupo.")
				return
		elif not iniciar_combate_grupo_servidor(peer_id, criaturas_grupo):
			_notificar_erro_interacao_criatura(peer_id, "Não foi possível iniciar o combate contra o grupo.")
			return
		_ultimo_encontro_ms[peer_id] = agora_grupo
		return
	var criatura_mundo: Dictionary = _criaturas_mundo_cache[id]
	var posicao_dados: Dictionary = criatura_mundo.get("posicaoMundo", {})
	var posicao_criatura := Vector2(float(posicao_dados.get("x", -10000.0)), float(posicao_dados.get("y", -10000.0)))
	var posicao_jogador: Vector2 = _jogadores_no_mundo[peer_id]
	if posicao_jogador.distance_to(posicao_criatura) > 92.0:
		_notificar_erro_interacao_criatura(peer_id, "Aproxime-se da criatura para interagir.")
		return
	var contexto_jogador := SISTEMA_AMBIENTES_MUNDO.obter_contexto(posicao_jogador)
	var contexto_criatura := SISTEMA_AMBIENTES_MUNDO.obter_contexto(posicao_criatura)
	if contexto_jogador.is_empty() or contexto_criatura.is_empty() or str(contexto_jogador.get("ecossistemaId", "")) != str(contexto_criatura.get("ecossistemaId", "")) or str(contexto_jogador.get("bioma", "")) != str(contexto_criatura.get("bioma", "")):
		_notificar_erro_interacao_criatura(peer_id, "A criatura está em outra região do mundo.")
		return
	var agora_ms := Time.get_ticks_msec()
	var ultimo_ms := int(_ultimo_encontro_ms.get(peer_id, 0))
	if ultimo_ms > 0 and agora_ms - ultimo_ms < INTERVALO_MINIMO_ENCONTROS_MS:
		_notificar_erro_interacao_criatura(peer_id, "Aguarde um instante antes de iniciar outro encontro.")
		return
	var sala := _salas_publicas.obter_sala_do_jogador(peer_id)
	if not sala.is_empty():
		var estado_sala: Dictionary = sala.get("estadoAventura", {})
		var encontro_atual: Dictionary = estado_sala.get("encontro", {})
		if bool(encontro_atual.get("ativo", false)):
			_notificar_erro_interacao_criatura(peer_id, "Sua Ally já está em um encontro.")
			return
		var peers_proximos := _listar_peers_proximos_criatura(peer_id, posicao_criatura, 260.0)
		if peers_proximos.size() >= 2:
			var cooperativo: Dictionary = await iniciar_encontro_cooperativo_servidor(peer_id, id)
			if not bool(cooperativo.get("sucesso", false)):
				_notificar_erro_interacao_criatura(peer_id, str(cooperativo.get("erro", "Não foi possível iniciar o combate cooperativo.")))
				return
			_ultimo_encontro_ms[peer_id] = agora_ms
			return
	var criatura_catalogada := _repositorio_criaturas.obter_criatura(id)
	if criatura_catalogada.is_empty() or not iniciar_combate_servidor(peer_id, criatura_catalogada):
		_notificar_erro_interacao_criatura(peer_id, "Não foi possível iniciar o combate com esta criatura.")
		return
	_ultimo_encontro_ms[peer_id] = agora_ms


func _obter_individuo_grupo_por_id(individuo_id: String) -> Dictionary:
	for grupo in _grupos_mundo_cache.values():
		for individuo in grupo.get("individuos", []):
			if str(individuo.get("individuoId", "")) == individuo_id and bool(individuo.get("vivo", false)):
				return {"grupo":grupo.duplicate(true),"individuo":individuo.duplicate(true)}
	return {}

func _montar_encontro_individuos_grupo(grupo: Dictionary, centro: Vector2, contexto: Dictionary) -> Array:
	var especie_id := str(grupo.get("especieId", ""))
	var especie := _repositorio_criaturas.obter_criatura(especie_id)
	if especie.is_empty():
		return []
	var candidatos: Array = []
	for individuo in grupo.get("individuos", []):
		if not bool(individuo.get("vivo", false)):
			continue
		var posicao_dados: Dictionary = individuo.get("posicaoMundo", {})
		var posicao := Vector2(float(posicao_dados.get("x", -10000.0)), float(posicao_dados.get("y", -10000.0)))
		var contexto_individuo := SISTEMA_AMBIENTES_MUNDO.obter_contexto(posicao)
		if contexto_individuo.is_empty() or str(contexto_individuo.get("ecossistemaId", "")) != str(contexto.get("ecossistemaId", "")) or str(contexto_individuo.get("bioma", "")) != str(contexto.get("bioma", "")):
			continue
		var distancia := centro.distance_to(posicao)
		if distancia <= 150.0:
			candidatos.append({"individuo":individuo.duplicate(true),"distancia":distancia})
	candidatos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("distancia", INF)) < float(b.get("distancia", INF)))
	var resultado: Array = []
	var ciclo := _obter_contexto_celeste_servidor()
	for candidato in candidatos.slice(0, 3):
		var individuo: Dictionary = candidato.get("individuo", {})
		var criatura := especie.duplicate(true)
		criatura["especieId"] = especie_id
		criatura["grupoId"] = str(grupo.get("grupoId", ""))
		criatura["individuoId"] = str(individuo.get("individuoId", ""))
		criatura["liderNato"] = bool(individuo.get("liderNato", false))
		criatura["atributos"] = individuo.get("atributos", {}).duplicate(true)
		criatura["posicaoMundo"] = individuo.get("posicaoMundo", {}).duplicate(true)
		criatura["periodoRecompensa"] = str(ciclo.get("periodo", "dia"))
		for atributo in ["vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"]:
			if criatura["atributos"].has(atributo):
				criatura[atributo] = int(criatura["atributos"][atributo])
		var vida_maxima_individuo := maxi(1, int(criatura.get("vidaMaxima", 1)))
		criatura["vida"] = clampi(int(individuo.get("vidaAtual", vida_maxima_individuo)), 1, vida_maxima_individuo)
		resultado.append(criatura)
	return resultado

## Recebe apenas snapshots montados a partir do repositório autoritativo de grupos.
func iniciar_encontro_cooperativo_grupo_servidor(peer_id: int, criaturas: Array) -> Dictionary:
	if not multiplayer.is_server() or not _uid_por_peer.has(peer_id) or not _perfil_por_peer.has(peer_id):
		return {"sucesso":false,"erro":"É necessária uma sessão autenticada."}
	if criaturas.is_empty() or criaturas.size() > 3:
		return {"sucesso":false,"erro":"O encontro precisa conter de uma a três criaturas vivas."}
	var sala: Dictionary = _salas_publicas.obter_sala_do_jogador(peer_id)
	var jogadores: Array = sala.get("jogadores", [])
	if sala.is_empty() or jogadores.size() < 2 or jogadores.size() > 4:
		return {"sucesso":false,"erro":"O encontro exige uma Ally com dois a quatro integrantes."}
	var primeira: Dictionary = criaturas[0]
	var posicao_dados: Dictionary = primeira.get("posicaoMundo", {})
	var posicao_criatura := Vector2(float(posicao_dados.get("x", -10000.0)), float(posicao_dados.get("y", -10000.0)))
	var peers_proximos := _listar_peers_proximos_criatura(peer_id, posicao_criatura, 260.0)
	if peers_proximos.size() < 2:
		return {"sucesso":false,"erro":"Pelo menos dois integrantes da Ally precisam estar próximos."}
	var participantes: Array = []
	for membro_peer in peers_proximos:
		var membro_id := int(membro_peer)
		if not _uid_por_peer.has(membro_id) or not _perfil_por_peer.has(membro_id):
			return {"sucesso":false,"erro":"Todos os participantes precisam estar autenticados."}
		var perfil: Dictionary = _perfil_por_peer[membro_id]
		var atributos := _atributos_efetivos_perfil(perfil)
		var arma_id := str(perfil.get("equipamentos", {}).get("mao_principal", ""))
		var arma: Dictionary = SistemaEquipamentos.obter(arma_id)
		participantes.append({
			"uid":str(_uid_por_peer[membro_id]),
			"nome":str(perfil.get("nome", "Aventureiro")).substr(0, 40),
			"vida":int(perfil.get("vida", atributos.get("vidaMaxima", 100))),
			"vidaMaxima":int(atributos.get("vidaMaxima", 100)),
			"ataque":maxi(int(atributos.get("forca", 5)), int(atributos.get("inteligencia", 5))) + maxi(0, int(arma.get("dano", 0))),
			"defesa":int(atributos.get("defesaEquipamento", 0)) + int(atributos.get("vitalidade", 5)) / 3,
			"agilidade":int(atributos.get("agilidade", 5)),
			"sorte":clampf(float(perfil.get("sorte", 0.0)), 0.0, 100.0),
			"classeId":str(perfil.get("classeId", "")).strip_edges().to_lower(),
			"armaOnePieceId":arma_id if not CATALOGO_ARMAS_ONE_PIECE.obter(arma_id).is_empty() else "",
			"armaId":arma_id,
			"maestriaArmas":perfil.get("maestriaArmas", {}).duplicate(true) if perfil.get("maestriaArmas", {}) is Dictionary else {}
		})
	var principal: Dictionary = primeira.duplicate(true)
	principal["inimigos"] = criaturas.duplicate(true)
	var resultado: Dictionary = _salas_publicas.registrar_encontro(peer_id, principal, participantes)
	if not bool(resultado.get("sucesso", false)):
		return resultado
	if not await _confirmar_salas_globais():
		return {"sucesso": false, "erro": "O encontro do grupo não foi confirmado no mundo global."}
	_publicar_estado_aventura_da_sala(peer_id)
	return resultado

func _listar_peers_proximos_criatura(peer_id: int, posicao_criatura: Vector2, raio: float) -> Array:
	var resultado: Array = []
	var sala := _salas_publicas.obter_sala_do_jogador(peer_id)
	if sala.is_empty() or not _uid_por_peer.has(peer_id):
		return resultado
	# A sala é apenas o limite técnico de matchmaking. A equipe que participa
	# do combate é a Ally explicitamente formada, nunca todos os ocupantes da sala.
	var uid_iniciador := str(_uid_por_peer[peer_id])
	var ally_id_iniciador := str(_ally_por_uid.get(uid_iniciador, ""))
	if ally_id_iniciador.is_empty():
		return resultado
	for membro in sala.get("jogadores", []):
		var membro_id := int(membro)
		if not _uid_por_peer.has(membro_id) or not _perfil_por_peer.has(membro_id) or not _jogadores_no_mundo.has(membro_id) or _combates_por_peer.has(membro_id):
			continue
		var uid_membro := str(_uid_por_peer[membro_id])
		if str(_ally_por_uid.get(uid_membro, "")) != ally_id_iniciador:
			continue
		var posicao: Vector2 = _jogadores_no_mundo[membro_id]
		if posicao.distance_to(posicao_criatura) <= raio:
			resultado.append(membro_id)
	return resultado

func _notificar_erro_interacao_criatura(peer_id: int, mensagem: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		erro_combate.emit(mensagem)
	else:
		rpc_id(peer_id, "_receber_erro_combate", mensagem)

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
	if _serpente_gravacao_em_andamento:
		return
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
	await _publicar_estado_serpente_mundo()

@rpc("any_peer", "call_remote", "reliable")
func _enviar_ataque_serpente(acao: String) -> void:
	if _serpente_gravacao_em_andamento:
		return
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
	await _publicar_estado_serpente_mundo()

@rpc("any_peer", "call_remote", "reliable")
func _enviar_tentativa_filhote_serpente() -> void:
	if _serpente_gravacao_em_andamento:
		return
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
	if not await _salvar_estado_serpente_mundo():
		rpc_id(peer_id, "_receber_resultado_filhote_serpente", false, "A persistência global está indisponível; tentativa não confirmada.", {})
		return
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
	var chance: float = SISTEMA_INVOCACOES.calcular_chance_domesticacao(criatura_derrotada)
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
	if _serpente_gravacao_em_andamento:
		return
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
	await _salvar_estado_serpente_mundo()

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
	if _serpente_gravacao_em_andamento or _estado_serpente_mundo.is_empty():
		return
	var agora_unix := int(Time.get_unix_time_from_system())
	var renascido := SISTEMA_SERPENTE_MUNDO.verificar_renascimento(_estado_serpente_mundo, agora_unix)
	if renascido != _estado_serpente_mundo:
		_estado_serpente_mundo = renascido
		_ultimo_ataque_serpente_ms = agora_ms
		await _publicar_estado_serpente_mundo()
		return
	var cenario_recuperado := SISTEMA_SERPENTE_MUNDO.recuperar_cenario(_estado_serpente_mundo, agora_unix)
	if cenario_recuperado != _estado_serpente_mundo:
		_estado_serpente_mundo = cenario_recuperado
		await _publicar_estado_serpente_mundo()
	if str(_estado_serpente_mundo.get("status", "")) != SISTEMA_SERPENTE_MUNDO.STATUS_EM_COMBATE:
		return
	if not _estado_serpente_mundo.has("ataquePreparando"):
		if agora_ms - _ultimo_ataque_serpente_ms < SISTEMA_SERPENTE_MUNDO.INTERVALO_ATAQUE_MS:
			return
		var indice := int(_estado_serpente_mundo.get("indiceAtaque", 0))
		_estado_serpente_mundo = SISTEMA_SERPENTE_MUNDO.iniciar_ataque_telegrafado(_estado_serpente_mundo, indice)
		_estado_serpente_mundo["indiceAtaque"] = indice + 1
		await _publicar_estado_serpente_mundo()
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
	await _publicar_estado_serpente_mundo()

func _carregar_estado_serpente_mundo() -> bool:
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		push_error("Inicialização bloqueada: cliente remoto sem lease global ativa.")
		return false
	var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento("world_boss")
	if not _repositorio_mundo_remoto.lease_ativa:
		push_error("Lease global perdida durante a recuperação da Serpente.")
		return false
	if not bool(remoto.get("ok", false)):
		push_error("Não foi possível carregar a Serpente do banco global: " + str(remoto.get("erro", "")))
		return false
	_revisao_serpente_remota = int(remoto.get("revisao", -1))
	if _revisao_serpente_remota < 0:
		return false

	if _revisao_serpente_remota > 0:
		var estado_remoto = remoto.get("payload", null)
		if not (estado_remoto is Dictionary) or not _repositorio_serpente._estado_valido(estado_remoto):
			push_error("Documento remoto da Serpente inválido; servidor não iniciará nem substituirá o progresso.")
			return false
		_estado_serpente_mundo = estado_remoto.duplicate(true)
		if not _repositorio_serpente.salvar(_estado_serpente_mundo):
			push_error("Não foi possível atualizar o cache local a partir do estado global.")
			return false
	else:
		# Migração inicial: preserva o progresso local existente somente quando D1
		# ainda não contém documento. A primeira gravação usa CAS revision=0.
		var local: Dictionary = _repositorio_serpente.carregar()
		if not bool(local.get("sucesso", false)):
			push_error("Estado local da Serpente inválido e banco global vazio; migração cancelada.")
			return false
		_estado_serpente_mundo = local.get("estado", {}).duplicate(true)
		if bool(local.get("arquivoNovo", false)):
			_estado_serpente_mundo = SISTEMA_SERPENTE_MUNDO.criar_estado()

	if _estado_serpente_mundo.is_empty():
		return false
	if int(_estado_serpente_mundo.get("revisaoSincronizacao", 0)) <= 0:
		_estado_serpente_mundo["revisaoSincronizacao"] = 1
		_estado_serpente_mundo["atualizadoUnix"] = int(Time.get_unix_time_from_system())
	# IDs de conexão e relógios monotônicos não sobrevivem à reinicialização.
	var participantes: Dictionary = _estado_serpente_mundo.get("participantes", {})
	for uid in participantes.keys():
		var participante: Dictionary = participantes[uid]
		participante["ativo"] = false
		participante["ultimaAcaoMs"] = -SISTEMA_SERPENTE_MUNDO.INTERVALO_ACAO_MS
		participantes[uid] = participante
	_estado_serpente_mundo["participantes"] = participantes
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
	return await _salvar_estado_serpente_mundo()

func _salvar_estado_serpente_mundo() -> bool:
	if _serpente_gravacao_em_andamento:
		if multiplayer != null and multiplayer.is_server():
			encerrar_servidor_por_falha_persistencia_global("Duas alterações simultâneas tentaram gravar a Serpente.")
		return false
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa or _estado_serpente_mundo.is_empty():
		if multiplayer != null and multiplayer.is_server():
			encerrar_servidor_por_falha_persistencia_global("A lease ou o cliente remoto não está disponível.")
		return false
	_serpente_gravacao_em_andamento = true
	var sucesso := _repositorio_serpente.salvar(_estado_serpente_mundo)
	var erro := ""
	if not sucesso:
		erro = "Não foi possível persistir o cache local da Serpente."
	else:
		var remoto: Dictionary = await _repositorio_mundo_remoto.salvar_documento("world_boss", _estado_serpente_mundo, _revisao_serpente_remota)
		sucesso = bool(remoto.get("ok", false))
		if sucesso:
			_revisao_serpente_remota = int(remoto.get("revisao", -1))
			sucesso = _revisao_serpente_remota > 0
		else:
			erro = str(remoto.get("erro", "Falha desconhecida na gravação remota."))
	_serpente_gravacao_em_andamento = false
	if not sucesso:
		push_error("Falha ao confirmar estado da Serpente no banco global: " + erro)
		if multiplayer != null and multiplayer.is_server():
			encerrar_servidor_por_falha_persistencia_global(erro)
	return sucesso

func _publicar_estado_serpente_mundo() -> void:
	if multiplayer.is_server():
		# A revisão fica no arquivo persistente: após reiniciar, o servidor continua
		# publicando uma sequência que permite rejeitar snapshots atrasados.
		_estado_serpente_mundo["revisaoSincronizacao"] = int(_estado_serpente_mundo.get("revisaoSincronizacao", 0)) + 1
		_estado_serpente_mundo["atualizadoUnix"] = int(Time.get_unix_time_from_system())
		if not await _salvar_estado_serpente_mundo():
			return
	var publico := SISTEMA_SERPENTE_MUNDO.obter_snapshot_global(_estado_serpente_mundo, SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO)
	_estado_serpente_mundo_publico = publico.duplicate(true)
	_ultima_revisao_estado_serpente_recebida = int(publico.get("revisaoSincronizacao", 0))
	estado_serpente_mundo_atualizado.emit(publico.duplicate(true))
	if multiplayer.is_server():
		rpc("_receber_estado_serpente_mundo", publico)

## Valida o contrato público antes de qualquer dado remoto alcançar HUD ou sistemas locais.
## O cliente nunca tenta "consertar" campos críticos: pacote inconsistente é descartado.
func _snapshot_serpente_global_valido(dados: Dictionary) -> bool:
	if str(dados.get("mundoId", "")) != SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO or str(dados.get("escopo", "")) != "global":
		return false
	if str(dados.get("chefeId", "")) != SISTEMA_SERPENTE_MUNDO.ID_CHEFE:
		return false
	var status := str(dados.get("status", ""))
	if status not in [SISTEMA_SERPENTE_MUNDO.STATUS_DISPONIVEL, SISTEMA_SERPENTE_MUNDO.STATUS_EM_COMBATE, SISTEMA_SERPENTE_MUNDO.STATUS_DERROTADA]:
		return false
	for campo in ["revisaoSincronizacao", "atualizadoUnix", "vida", "vidaMaxima", "participantes", "ciclos", "totalDerrotas", "renascimentoRestante", "renascimentoUnix", "ultimaDevastacaoUnix"]:
		if typeof(dados.get(campo)) != TYPE_INT:
			return false
	var revisao: int = dados["revisaoSincronizacao"]
	var atualizado: int = dados["atualizadoUnix"]
	var vida: int = dados["vida"]
	var vida_maxima: int = dados["vidaMaxima"]
	var participantes: int = dados["participantes"]
	var ciclos: int = dados["ciclos"]
	var derrotas: int = dados["totalDerrotas"]
	var renascimento_restante: int = dados["renascimentoRestante"]
	var renascimento_unix: int = dados["renascimentoUnix"]
	if revisao <= 0 or atualizado <= 0 or vida_maxima < 1 or vida_maxima > 2000000000:
		return false
	if vida < 0 or vida > vida_maxima or participantes < 0 or participantes > SISTEMA_SERPENTE_MUNDO.LIMITE_PARTICIPANTES:
		return false
	if ciclos < 1 or derrotas < 0 or renascimento_restante < 0 or renascimento_restante > SISTEMA_SERPENTE_MUNDO.TEMPO_RENASCIMENTO_SEGUNDOS or renascimento_unix < 0:
		return false
	if typeof(dados.get("serpenteOriginalPreservada")) != TYPE_BOOL or typeof(dados.get("cenarioDevastado")) != TYPE_BOOL:
		return false
	if typeof(dados.get("ultimoAtaque")) != TYPE_STRING or str(dados["ultimoAtaque"]).length() > 500:
		return false
	if status == SISTEMA_SERPENTE_MUNDO.STATUS_DERROTADA:
		if vida != 0 or renascimento_unix <= 0:
			return false
	elif vida <= 0 or renascimento_restante != 0:
		return false
	var ataque = dados.get("ataquePreparando", {})
	if not (ataque is Dictionary) or ataque.size() > 16:
		return false
	if not ataque.is_empty():
		if typeof(ataque.get("id")) != TYPE_STRING or str(ataque["id"]).is_empty() or str(ataque["id"]).length() > 80:
			return false
		if typeof(ataque.get("nome")) != TYPE_STRING or str(ataque["nome"]).is_empty() or str(ataque["nome"]).length() > 120:
			return false
		if typeof(ataque.get("impactoUnix")) != TYPE_INT or int(ataque["impactoUnix"]) <= 0:
			return false
	var zona = dados.get("zonaDevastada", {})
	if not (zona is Dictionary) or zona.size() > 32:
		return false
	var marcas = dados.get("marcasDestruicao", null)
	if not (marcas is Array) or marcas.size() > SISTEMA_SERPENTE_MUNDO.LIMITE_MARCAS_DESTRUICAO:
		return false
	for marca in marcas:
		if not (marca is Dictionary):
			return false
		for campo in ["x", "y", "raio", "intensidade"]:
			if typeof(marca.get(campo)) not in [TYPE_INT, TYPE_FLOAT]:
				return false
			if not is_finite(float(marca[campo])):
				return false
		if float(marca["x"]) < 0.0 or float(marca["x"]) > 2400.0 or float(marca["y"]) < 0.0 or float(marca["y"]) > 2400.0:
			return false
		if float(marca["raio"]) < 12.0 or float(marca["raio"]) > 900.0 or float(marca["intensidade"]) < 0.1 or float(marca["intensidade"]) > 1.0:
			return false
		if typeof(marca.get("criadoUnix")) != TYPE_INT or typeof(marca.get("expiraUnix")) != TYPE_INT or int(marca["criadoUnix"]) <= 0 or int(marca["expiraUnix"]) <= int(marca["criadoUnix"]):
			return false
		if typeof(marca.get("id")) != TYPE_STRING or str(marca["id"]).is_empty() or typeof(marca.get("tipo")) != TYPE_STRING or str(marca["tipo"]).is_empty():
			return false
	return true

@rpc("authority", "call_remote", "reliable")
func _receber_estado_serpente_mundo(dados: Dictionary) -> void:
	if not _snapshot_serpente_global_valido(dados):
		return
	var revisao: int = dados["revisaoSincronizacao"]
	# Revisão igual também é rejeitada: não pode substituir o mesmo estado por
	# outro conteúdo divergente nem reemitir uma atualização duplicada.
	if revisao <= _ultima_revisao_estado_serpente_recebida:
		return
	var estado_recebido := dados.duplicate(true)
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
	elif estado == EstadoConexao.SERVIDOR and multiplayer.is_server():
		# O anfitrião também joga localmente: não pode depender de RPC call_remote para si próprio.
		var peer_local := multiplayer.get_unique_id()
		if not _combates_por_peer.has(peer_local) or not _uid_por_peer.has(peer_local):
			return
		if not [SistemaCombate.ACAO_ATAQUE, SistemaCombate.ACAO_MAGIA, SistemaCombate.ACAO_HABILIDADE, SistemaCombate.ACAO_DEFENDER, SistemaCombate.ACAO_ESQUIVAR, SistemaCombate.ACAO_SUPREMA, SistemaCombate.ACAO_SUPREMA_CLASSE, SistemaCombate.ACAO_SUPREMA_AVANCADA, SistemaCombate.ACAO_SUPREMA_COMBINADA].has(acao):
			erro_combate.emit("Ação de combate inválida.")
			return
		if not _registrar_acao_combate_se_permitida(peer_local, Time.get_ticks_msec()):
			return
		if _duelo_por_peer.has(peer_local):
			await _processar_acao_duelo_pvp(peer_local, acao, habilidade_id)
		else:
			await _processar_acao_pve_peer(peer_local, acao, alvo_selecionado_id, habilidade_id)

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
	if _duelo_por_peer.has(peer_id):
		rpc_id(peer_id, "_receber_erro_combate", "Comandos de companheiro não podem ser usados em duelos PvP.")
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

func _processar_acao_pve_peer(peer_id: int, acao: String, alvo_selecionado_id: String, habilidade_id: String) -> void:
	var sessao: Dictionary = _combates_por_peer.get(peer_id, {})
	if sessao.is_empty():
		return
	var estado_atual: Dictionary = sessao.get("estado", {})
	var semente_servidor := int(Time.get_ticks_usec()) ^ (peer_id * 7919)
	var resultado := SistemaCombate.executar_rodada(estado_atual, acao, semente_servidor, alvo_selecionado_id, habilidade_id)
	if not bool(resultado.get("ok", false)):
		_enviar_erro_combate_peer(peer_id, str(resultado.get("erro", "Não foi possível executar a ação.")))
		return
	var novo_estado: Dictionary = resultado["estado"]
	var jogador_estado_maestria: Dictionary = novo_estado.get("jogador", {})
	var arma_maestria_id := str(jogador_estado_maestria.get("armaId", ""))
	if not arma_maestria_id.is_empty() and novo_estado.has("maestriaArmasAtualizada"):
		var salvo_maestria := _repositorio_perfis.salvar_maestria_armas(str(_uid_por_peer.get(peer_id, "")), novo_estado.get("maestriaArmasAtualizada", {}))
		if not bool(salvo_maestria.get("ok", false)):
			_enviar_erro_combate_peer(peer_id, str(salvo_maestria.get("erro", "Não foi possível salvar a maestria.")))
			return
		_perfil_por_peer[peer_id] = salvo_maestria.get("perfil", _perfil_por_peer.get(peer_id, {})).duplicate(true)
	await _registrar_marcas_chefe_combate(peer_id, sessao, estado_atual, novo_estado)
	sessao["estado"] = novo_estado
	_combates_por_peer[peer_id] = sessao
	_enviar_estado_combate_peer(peer_id, novo_estado)
	var status := str(novo_estado.get("status", SistemaCombate.STATUS_EM_ANDAMENTO))
	if status != SistemaCombate.STATUS_VITORIA and status != SistemaCombate.STATUS_DERROTA:
		return
	var uid := str(_uid_por_peer.get(peer_id, ""))
	var estado_jogador: Dictionary = novo_estado.get("jogador", {})
	var derrotado := status == SistemaCombate.STATUS_DERROTA
	var salvo: bool = _repositorio_perfis.registrar_recursos_combate(uid, int(estado_jogador.get("vida", 0)), int(estado_jogador.get("mana", 0)), derrotado)
	if not salvo:
		_enviar_erro_combate_peer(peer_id, "Não foi possível salvar os recursos da batalha. O resultado foi encerrado sem conceder recompensas.")
		_combates_por_peer.erase(peer_id)
		return
	var perfil_atualizado: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
	if not perfil_atualizado.is_empty():
		_perfil_por_peer[peer_id] = perfil_atualizado
		_enviar_perfil_peer(peer_id, perfil_atualizado)
	var drops: Array = []
	var criaturas_da_batalha: Array = sessao.get("criaturas", [sessao.get("criatura", {})])
	if status == SistemaCombate.STATUS_DERROTA and not bool(sessao.get("mimico", false)):
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
	if status == SistemaCombate.STATUS_VITORIA and not bool(sessao.get("mimico", false)):
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
			var evento_missao := await registrar_evento_missao_mundo(peer_id, "derrotar_criatura", criatura_derrotada_id, 1)
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
			xp_concedido += SISTEMA_CICLO_NOTURNO.calcular_experiencia(int(criatura_derrotada.get("experienciaBase", 0)), periodo_recompensa, criatura_derrotada)
			drops.append_array(await concluir_combate_e_conceder_drops(peer_id, criatura_derrotada, {"periodo":periodo_recompensa}))
		if companheiro_recebeu_essencia:
			var perfil_com_companheiro: Dictionary = _repositorio_perfis.carregar_ou_criar(uid)
			if not perfil_com_companheiro.is_empty():
				_perfil_por_peer[peer_id] = perfil_com_companheiro
				_enviar_perfil_peer(peer_id, perfil_com_companheiro)
		if xp_concedido > 0:
			var resultado_xp: Dictionary = _repositorio_perfis.conceder_experiencia(uid, xp_concedido)
			if bool(resultado_xp.get("ok", false)):
				var perfil_com_xp: Dictionary = resultado_xp.get("perfil", {})
				if not perfil_com_xp.is_empty():
					_perfil_por_peer[peer_id] = perfil_com_xp
					_enviar_perfil_peer(peer_id, perfil_com_xp)
			else:
				push_error("Não foi possível conceder a experiência das criaturas derrotadas.")
	if bool(sessao.get("mimico", false)):
		var bau_id := str(sessao.get("mimicoBauId", ""))
		if status == SistemaCombate.STATUS_VITORIA:
			var mimico_derrotado: Dictionary = sessao.get("criatura", {})
			var resultado_piedade := _repositorio_piedade_mimicos.registrar_vitoria(
				uid, bau_id, str(mimico_derrotado.get("raridade", "comum")),
				CATALOGO_ARMAS_ONE_PIECE.listar_para_drop(),
				int(Time.get_ticks_usec()) ^ (peer_id * 7919)
			)
			if bool(resultado_piedade.get("ok", false)):
				if not await _sincronizar_piedade_mimicos_global():
					encerrar_servidor_por_falha_persistencia_global("A vitória do Mímico não foi confirmada na piedade global.")
					_combates_por_peer.erase(peer_id)
					_enviar_erro_combate_peer(peer_id, "Não foi possível confirmar o progresso global. A recompensa foi bloqueada por segurança.")
					return
				var arma: Dictionary = resultado_piedade.get("arma", {})
				if arma.is_empty() and bool(resultado_piedade.get("duplicado", false)):
					# Recuperação após falha entre confirmar inventário e marcar o baú como aberto.
					_repositorio_mimicos.registrar_derrota(bau_id)
					await _publicar_mimicos()
				elif not arma.is_empty():
					var item_arma := {
						"itemId":"arma_" + str(arma.get("id", "")),
						"nome":str(arma.get("nome", "Arma especial")),
						"categoria":"arma",
						"raridade":str(arma.get("raridade", "comum")),
						"quantidade":1,
						"origemCriaturaId":"mimico_" + str(mimico_derrotado.get("raridade", "comum"))
					}
					if not _repositorio_perfis.conceder_arma_mimico(uid, bau_id, item_arma):
						_repositorio_mimicos.liberar_reserva(bau_id, uid)
						await _publicar_mimicos()
						_enviar_erro_combate_peer(peer_id, "A vitória foi salva, mas a arma ainda não pôde ser entregue. O baú ficará disponível para recuperar a recompensa.")
					else:
						if not _repositorio_piedade_mimicos.confirmar_entrega(uid, bau_id) or not await _sincronizar_piedade_mimicos_global():
							encerrar_servidor_por_falha_persistencia_global("Não foi possível confirmar a entrega da recompensa do Mímico no estado global.")
							_combates_por_peer.erase(peer_id)
							_enviar_erro_combate_peer(peer_id, "A recompensa está protegida, mas a confirmação global falhou. Entre em contato com o suporte.")
							return
						drops.append({"itemId":item_arma.itemId,"nome":item_arma.nome,"raridade":item_arma.raridade,"quantidade":1,"obtido":true})
						var perfil_com_arma := _repositorio_perfis.carregar_ou_criar(uid)
						if not perfil_com_arma.is_empty():
							_perfil_por_peer[peer_id] = perfil_com_arma
							_enviar_perfil_peer(peer_id, perfil_com_arma)
						var bau_derrotado := _repositorio_mimicos.registrar_derrota(bau_id)
						if not bool(bau_derrotado.get("ok", false)):
							push_error("Não foi possível marcar o baú mímico como derrotado: " + str(bau_derrotado.get("erro", "")))
						await _publicar_mimicos()
				else:
					_repositorio_mimicos.liberar_reserva(bau_id, uid)
					await _publicar_mimicos()
					_enviar_erro_combate_peer(peer_id, "A recompensa deste encontro precisa ser recuperada. Tente interagir novamente.")
			else:
				_repositorio_mimicos.liberar_reserva(bau_id, uid)
				await _publicar_mimicos()
				_enviar_erro_combate_peer(peer_id, str(resultado_piedade.get("erro", "Não foi possível calcular a recompensa do mímico.")))
		else:
			_repositorio_mimicos.liberar_reserva(bau_id, uid)
			await _publicar_mimicos()
	if bool(sessao.get("mimico", false)) and status == SistemaCombate.STATUS_VITORIA:
		await _publicar_mimicos()
	_combates_por_peer.erase(peer_id)
	_enviar_combate_finalizado_peer(peer_id, status, drops)

func _enviar_erro_combate_peer(peer_id: int, mensagem: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		erro_combate.emit(mensagem)
	else:
		rpc_id(peer_id, "_receber_erro_combate", mensagem)

func _enviar_estado_combate_peer(peer_id: int, estado_novo: Dictionary) -> void:
	if peer_id == multiplayer.get_unique_id():
		combate_atualizado.emit(estado_novo.duplicate(true))
	else:
		rpc_id(peer_id, "_receber_estado_combate", estado_novo)

func _enviar_perfil_peer(peer_id: int, perfil: Dictionary) -> void:
	if peer_id == multiplayer.get_unique_id():
		perfil_personagem_recebido.emit(perfil.duplicate(true))
	else:
		rpc_id(peer_id, "_receber_perfil_personagem", perfil)

func _enviar_combate_finalizado_peer(peer_id: int, status: String, drops: Array) -> void:
	if peer_id == multiplayer.get_unique_id():
		combate_finalizado.emit(status, drops)
	else:
		rpc_id(peer_id, "_receber_combate_finalizado", status, drops)

@rpc("any_peer", "call_remote", "reliable")
func _enviar_acao_combate(acao: String, alvo_selecionado_id: String = "", habilidade_id: String = "") -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _uid_por_peer.has(peer_id) or not _combates_por_peer.has(peer_id):
		return
	if not [SistemaCombate.ACAO_ATAQUE, SistemaCombate.ACAO_MAGIA, SistemaCombate.ACAO_HABILIDADE, SistemaCombate.ACAO_DEFENDER, SistemaCombate.ACAO_ESQUIVAR, SistemaCombate.ACAO_SUPREMA, SistemaCombate.ACAO_SUPREMA_CLASSE, SistemaCombate.ACAO_SUPREMA_AVANCADA, SistemaCombate.ACAO_SUPREMA_COMBINADA].has(acao):
		rpc_id(peer_id, "_receber_erro_combate", "Ação de combate inválida.")
		return
	# Evita que pacotes repetidos avancem várias rodadas em sequência.
	var agora_ms := Time.get_ticks_msec()
	if not _registrar_acao_combate_se_permitida(peer_id, agora_ms):
		return
	if _duelo_por_peer.has(peer_id):
		await _processar_acao_duelo_pvp(peer_id, acao, habilidade_id)
		return
	await _processar_acao_pve_peer(peer_id, acao, alvo_selecionado_id, habilidade_id)

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
		await _publicar_estado_serpente_mundo()

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

## Recupera a deriva da fauna e o avanço de perseguições após a parada do servidor.
## Cada grupo mantém seu próprio relógio de movimento, independente da ecologia populacional.
func _recuperar_movimento_grupos_offline() -> bool:
	var agora_unix := int(Time.get_unix_time_from_system())
	var grupos_alterados := 0
	for grupo_id_var in _grupos_mundo_cache.keys():
		var grupo_id := str(grupo_id_var)
		var grupo: Dictionary = _grupos_mundo_cache[grupo_id]
		var ultima_movimentacao := int(grupo.get("ultimaMovimentacaoUnix", grupo.get("atualizadoUnix", grupo.get("criadoUnix", agora_unix))))
		var intervalo := float(agora_unix - ultima_movimentacao)
		if intervalo > 30.0 * 86400.0:
			push_error("Grupo " + grupo_id + " exige recuperação de movimento superior ao limite seguro de 30 dias.")
			return false
		if intervalo <= 0.0:
			continue
		var movimento := SISTEMA_MOVIMENTO_GRUPOS.avancar_offline(grupo, intervalo, hash(grupo_id + ":" + str(ultima_movimentacao)))
		if not bool(movimento.get("ok", false)):
			push_error("Falha ao recuperar movimento offline do grupo " + grupo_id + ": " + str(movimento.get("erro", "")))
			return false
		var grupo_movido: Dictionary = movimento.get("grupo", grupo)
		if not _repositorio_grupos.salvar_movimento_grupo(grupo_id, grupo_movido.get("individuos", []), agora_unix):
			push_error("Falha ao persistir movimento offline do grupo " + grupo_id)
			return false
		grupo_movido["ultimaMovimentacaoUnix"] = agora_unix
		_grupos_mundo_cache[grupo_id] = grupo_movido
		grupos_alterados += 1
	var perseguicoes := _repositorio_grupos.avancar_perseguicoes(1.0, agora_unix, true)
	if not bool(perseguicoes.get("ok", false)):
		push_error("Falha ao recuperar perseguições offline: " + str(perseguicoes.get("erro", "")))
		return false
	for perseguidor in perseguicoes.get("grupos", []):
		var id_perseguidor := str(perseguidor.get("grupoId", ""))
		if not id_perseguidor.is_empty():
			_grupos_mundo_cache[id_perseguidor] = perseguidor
	if grupos_alterados > 0 or not perseguicoes.get("grupos", []).is_empty():
		print("Recuperação offline da fauna concluída: ", grupos_alterados, " grupos movimentados.")
	return true

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
	# Mesmo sem grupos carregados, o ciclo de recursos ambientais precisa avançar.
	# Os laços abaixo aceitam cache vazio; não retornar antes de _processar_ciclo_alimentar.
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
	if not await _processar_ciclo_alimentar(agora_ms):
		return
	if agora_ms - _ultima_gravacao_grupos_ms >= INTERVALO_GRAVACAO_GRUPOS_MS:
		var salvou_todos := true
		for grupo_id in _grupos_mundo_cache.keys():
			var grupo: Dictionary = _grupos_mundo_cache[grupo_id]
			if not _repositorio_grupos.salvar_movimento_grupo(str(grupo_id), grupo.get("individuos", []), int(Time.get_unix_time_from_system())):
				salvou_todos = false
		if salvou_todos:
			_ultima_gravacao_grupos_ms = agora_ms
			await _sincronizar_fauna_global()
		else:
			encerrar_servidor_por_falha_persistencia_global("Falha ao gravar o movimento de um ou mais grupos da fauna no armazenamento local; servidor encerrado para evitar divergência do mundo.")
			return

## Processa estoque compartilhado e reprodução/mortalidade de todos os grupos em um ciclo controlado.

func _processar_ciclo_alimentar(agora_ms: int) -> bool:
	if _ciclo_alimentar_em_andamento or _fauna_gravacao_remota_em_andamento or _recursos_gravacao_remota_em_andamento:
		return false
	_ciclo_alimentar_em_andamento = true
	var sucesso: bool = await _executar_ciclo_alimentar(agora_ms)
	_ciclo_alimentar_em_andamento = false
	return sucesso

func _executar_ciclo_alimentar(agora_ms: int) -> bool:
	if _recursos_gravacao_remota_em_andamento or _fauna_gravacao_remota_em_andamento:
		return false
	if agora_ms - _ultimo_tick_populacional_ms < INTERVALO_SIMULACAO_POPULACIONAL_MS:
		return true
	_ultimo_tick_populacional_ms = agora_ms
	# Mesmo sem fauna carregada, os estoques ambientais avançam pelo relógio Unix.
	# Isso mantém o mundo consistente durante períodos sem grupos ativos.
	var grupos: Array = _grupos_mundo_cache.values()
	var agora_unix := int(Time.get_unix_time_from_system())
	var marcas_ativas_recursos := SISTEMA_SERPENTE_MUNDO.obter_marcas_destruicao_ativas(_estado_serpente_mundo, agora_unix)
	var recursos := _repositorio_recursos_ecologicos.processar_tick(grupos, agora_unix, marcas_ativas_recursos)
	if not bool(recursos.get("ok", false)):
		encerrar_servidor_por_falha_persistencia_global("Ciclo alimentar offline inválido: " + str(recursos.get("erro", "erro desconhecido")))
		return false
	# O snapshot será confirmado junto aos 16 fragmentos da fauna no fim do ciclo.
	var disponibilidade: Dictionary = recursos.get("disponibilidadePorEspecie", {})
	var disponibilidade_local: Dictionary = recursos.get("disponibilidadePorGrupo", {})
	var carcaças := _repositorio_grupos.processar_carcacas_ecologicas(agora_unix)
	if not bool(carcaças.get("ok", false)):
		encerrar_servidor_por_falha_persistencia_global("Ciclo de carcaças offline inválido: " + str(carcaças.get("erro", "")))
		return false
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
	var mudou := bool(carcaças.get("alterou", false))
	var marcas_ativas := SISTEMA_SERPENTE_MUNDO.obter_marcas_destruicao_ativas(_estado_serpente_mundo, agora_unix)
	for grupo_id in _grupos_mundo_cache.keys():
		var grupo_retorno: Dictionary = _grupos_mundo_cache[grupo_id]
		if not grupo_retorno.get("retornoDevastacao", {}).is_empty():
			var especie_retorno := str(grupo_retorno.get("especieId", ""))
			var alimento_retorno := clampf(float(disponibilidade.get(especie_retorno, 0.0)), 0.0, 1.0)
			var retorno_habitat := _repositorio_grupos.retornar_da_devastacao(str(grupo_id), marcas_ativas, agora_unix, alimento_retorno)
			if not bool(retorno_habitat.get("ok", false)):
				encerrar_servidor_por_falha_persistencia_global("Retorno de habitat falhou para " + str(grupo_id) + ": " + str(retorno_habitat.get("erro", "")))
				return false
			elif bool(retorno_habitat.get("retornou", false)):
				_grupos_mundo_cache[grupo_id] = retorno_habitat["grupo"]
				mudou = true
	for grupo_id in _grupos_mundo_cache.keys():
		var grupo: Dictionary = _grupos_mundo_cache[grupo_id]
		var especie_id := str(grupo.get("especieId", ""))
		var alimento := clampf(float(disponibilidade_por_grupo.get(str(grupo_id), disponibilidade.get(especie_id, 1.0))), 0.0, 1.0)
		var migracao := _repositorio_grupos.avaliar_migracao_por_escassez(str(grupo_id), alimento, agora_unix)
		if not bool(migracao.get("ok", false)):
			encerrar_servidor_por_falha_persistencia_global("Migração ecológica falhou para " + str(grupo_id) + ": " + str(migracao.get("erro", "")))
			return false
		elif bool(migracao.get("migrou", false)):
			_grupos_mundo_cache[grupo_id] = migracao["grupo"]
			grupo = migracao["grupo"]
			mudou = true
		var protecao_fome := 0.25 if grupos_protegidos_por_ajuda.has(str(grupo_id)) else 0.0
		var resultado := _repositorio_grupos.avancar_grupo(str(grupo_id), agora_unix, alimento, protecao_fome)
		if not bool(resultado.get("ok", false)):
			encerrar_servidor_por_falha_persistencia_global("Simulação populacional falhou para " + str(grupo_id) + ": " + str(resultado.get("erro", "")))
			return false
		if bool(resultado.get("alterou", false)):
			_grupos_mundo_cache[grupo_id] = resultado["grupo"]
			mudou = true
	mudou = _processar_encontros_sociais(agora_unix) or mudou
	if mudou:
		rpc("_receber_grupos_selvagens", _lista_visual_individuos_grupos())
	_snapshot_recursos_ecologicos_remoto = JSON.stringify(_repositorio_recursos_ecologicos.exportar_estado_persistente(agora_unix))
	if not await _sincronizar_fauna_global(true):
		return false
	return true

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
			var relacao: Dictionary = SISTEMA_ECOLOGIA_CRIATURAS.avaliar_relacao(especie_predador, especie_presa)
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
			var alvo_coordenado: Dictionary = SISTEMA_DEFESA_COOPERATIVA.selecionar_alvo_prioritario(grupo_presa, pos_atacante)
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
			var intervencao: Dictionary = SISTEMA_DEFESA_COOPERATIVA.avaliar_intervencao(grupo_presa, _grupos_mundo_cache.values(), alvo)
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
		var contexto: Dictionary = SISTEMA_ECOLOGIA_CRIATURAS.criar_contexto_interacao(
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


## Eventos globais sobrevivem à troca de host; expiração usa Unix, nunca relógio do processo.
func _carregar_eventos_mundo_global() -> bool:
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		return false
	var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento("world_events")
	if not _repositorio_mundo_remoto.lease_ativa:
		push_error("Lease global perdida durante a recuperação dos eventos; host não pode assumir o estado.")
		return false
	if not bool(remoto.get("ok", false)):
		push_error("Falha ao carregar eventos globais: " + str(remoto.get("erro", "")))
		return false
	var revisao := int(remoto.get("revisao", -1))
	if revisao < 0:
		return false
	if revisao == 0:
		_eventos_mundo_payload = SISTEMA_EVENTOS_MUNDO.criar_documento()
		var inicial: Dictionary = await _repositorio_mundo_remoto.salvar_documento("world_events", _eventos_mundo_payload, 0)
		if not _repositorio_mundo_remoto.lease_ativa:
			push_error("Lease global perdida durante a criação do documento de eventos.")
			return false
		if not bool(inicial.get("ok", false)):
			push_error("Falha ao inicializar documento global de eventos: " + str(inicial.get("erro", "")))
			return false
		revisao = int(inicial.get("revisao", -1))
	else:
		var payload = remoto.get("payload", null)
		if not SISTEMA_EVENTOS_MUNDO.documento_valido(payload):
			push_error("Documento global de eventos inválido; inicialização bloqueada.")
			return false
		_eventos_mundo_payload = payload.duplicate(true)
	_revisao_eventos_mundo_remota = revisao
	if _revisao_eventos_mundo_remota <= 0:
		return false
	return true

func _atualizar_eventos_mundo(agora_ms: int, forcar: bool = false) -> bool:
	if _eventos_mundo_gravacao_em_andamento:
		return false
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		return false
	_ultima_verificacao_eventos_ms = agora_ms
	var agora_unix := int(Time.get_unix_time_from_system())
	var resultado: Dictionary = SISTEMA_EVENTOS_MUNDO.expirar(_eventos_mundo_payload, agora_unix)
	if not bool(resultado.get("ok", false)):
		encerrar_servidor_por_falha_persistencia_global("Documento de eventos globais inválido.")
		return false
	if bool(resultado.get("alterou", false)):
		var revisao_anterior := _revisao_eventos_mundo_remota
		_eventos_mundo_gravacao_em_andamento = true
		var salvo: Dictionary = await _repositorio_mundo_remoto.salvar_documento("world_events", resultado["payload"], revisao_anterior)
		_eventos_mundo_gravacao_em_andamento = false
		if not _repositorio_mundo_remoto.lease_ativa:
			encerrar_servidor_por_falha_persistencia_global("Lease global perdida durante a expiração de eventos.")
			return false
		if not bool(salvo.get("ok", false)):
			encerrar_servidor_por_falha_persistencia_global("Falha ao confirmar expiração de eventos globais: " + str(salvo.get("erro", "")))
			return false
		var nova_revisao := int(salvo.get("revisao", -1))
		if nova_revisao <= revisao_anterior:
			encerrar_servidor_por_falha_persistencia_global("Revisão não avançou após expiração de evento.")
			return false
		_revisao_eventos_mundo_remota = nova_revisao
		_eventos_mundo_payload = resultado["payload"].duplicate(true)
	var ativos := SISTEMA_EVENTOS_MUNDO.listar_ativos(_eventos_mundo_payload, agora_unix)
	rpc("_receber_eventos_mundo", ativos)
	eventos_mundo_atualizados.emit(ativos.duplicate(true))
	return true

func registrar_evento_mundo(evento: Dictionary) -> Dictionary:
	if not multiplayer.is_server() or _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		return {"ok": false, "erro": "Somente o host global pode registrar eventos."}
	# A gravação de eventos é uma seção crítica: não permita que um registro
	# concorra com a expiração periódica ou com outro registro usando a mesma revisão.
	if _eventos_mundo_gravacao_em_andamento:
		return {"ok": false, "erro": "A persistência de eventos está ocupada; tente novamente."}
	var resultado: Dictionary = SISTEMA_EVENTOS_MUNDO.registrar(_eventos_mundo_payload, evento, int(Time.get_unix_time_from_system()))
	if not bool(resultado.get("ok", false)):
		return resultado
	_eventos_mundo_gravacao_em_andamento = true
	var revisao_anterior := _revisao_eventos_mundo_remota
	var salvo: Dictionary = await _repositorio_mundo_remoto.salvar_documento("world_events", resultado["payload"], revisao_anterior)
	_eventos_mundo_gravacao_em_andamento = false
	if not _repositorio_mundo_remoto.lease_ativa:
		encerrar_servidor_por_falha_persistencia_global("Lease global perdida durante o registro de evento.")
		return {"ok": false, "erro": "A lease global foi perdida durante a gravação."}
	if not bool(salvo.get("ok", false)):
		encerrar_servidor_por_falha_persistencia_global("Falha ao registrar evento global: " + str(salvo.get("erro", "")))
		return {"ok": false, "erro": str(salvo.get("erro", "Falha na persistência."))}
	var nova_revisao := int(salvo.get("revisao", -1))
	if nova_revisao <= revisao_anterior:
		encerrar_servidor_por_falha_persistencia_global("Revisão inválida ao registrar evento global.")
		return {"ok": false, "erro": "Revisão inválida."}
	_revisao_eventos_mundo_remota = nova_revisao
	_eventos_mundo_payload = resultado["payload"].duplicate(true)
	await _atualizar_eventos_mundo(Time.get_ticks_msec(), true)
	return {"ok": true, "eventosAtivos": SISTEMA_EVENTOS_MUNDO.listar_ativos(_eventos_mundo_payload, int(Time.get_unix_time_from_system()))}

@rpc("authority", "call_remote", "reliable")
func _receber_eventos_mundo(eventos: Array) -> void:
	eventos_mundo_atualizados.emit(eventos.duplicate(true))

## Calcula o contexto usando a mesma semente persistida durante toda a vida do mundo.
func _obter_contexto_celeste_servidor() -> Dictionary:
	var agora_unix := int(Time.get_unix_time_from_system())
	var contexto := SISTEMA_CICLO_NOTURNO.criar_contexto_por_tempo_unix(agora_unix, _semente_mundo_celeste)
	contexto["mundoId"] = SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO
	contexto["escopo"] = "global"
	return contexto

## A semente não muda quando o processo reinicia: os fenômenos previstos para cada dia permanecem iguais.
## Falha fechada: arquivo corrompido ou gravação incompleta nunca gera uma semente substituta silenciosa.
## A semente do calendário é um dado global imutável: todos os hosts/clientes
## calculam a mesma lua e os mesmos fenômenos a partir do Unix + esta semente.
## O cache local só serve como origem de migração quando D1 ainda não possui documento.
static func _semente_relogio_valida(payload: Variant) -> bool:
	return payload is Dictionary and int(payload.get("versao", 0)) == 1 and int(payload.get("semente", 0)) > 0

func _carregar_semente_mundo_celeste_global() -> int:
	if _repositorio_mundo_remoto == null or not _repositorio_mundo_remoto.lease_ativa:
		push_error("Calendário global sem repositório remoto ou lease ativa.")
		return 0
	var remoto: Dictionary = await _repositorio_mundo_remoto.carregar_documento("world_clock")
	if not _repositorio_mundo_remoto.lease_ativa:
		push_error("Lease global perdida durante a recuperação do calendário celeste.")
		return 0
	if not bool(remoto.get("ok", false)):
		push_error("Não foi possível ler o calendário global: " + str(remoto.get("erro", "erro desconhecido")))
		return 0
	var revisao := int(remoto.get("revisao", -1))
	if revisao < 0:
		return 0
	if revisao > 0:
		var payload = remoto.get("payload", null)
		if not _semente_relogio_valida(payload):
			push_error("Documento world_clock inválido; calendário global preservado sem substituição.")
			return 0
		_revisao_relogio_remota = revisao
		return int(payload["semente"])
	# Migração única: a semente local validada é importada para D1 por CAS.
	var semente_local := _carregar_ou_criar_semente_mundo_celeste()
	if semente_local <= 0:
		return 0
	var documento := {"versao":1,"semente":semente_local}
	var gravacao: Dictionary = await _repositorio_mundo_remoto.salvar_documento("world_clock", documento, 0)
	if not _repositorio_mundo_remoto.lease_ativa:
		push_error("Lease global perdida ao inicializar o calendário celeste.")
		return 0
	if not bool(gravacao.get("ok", false)):
		push_error("Não foi possível fixar a semente inicial no calendário global: " + str(gravacao.get("erro", "erro desconhecido")))
		return 0
	_revisao_relogio_remota = int(gravacao.get("revisao", -1))
	if _revisao_relogio_remota <= 0:
		push_error("A persistência global não confirmou a revisão do calendário.")
		return 0
	return semente_local

func _carregar_ou_criar_semente_mundo_celeste(caminho: String = CAMINHO_SEMENTE_MUNDO_CELESTE) -> int:
	if FileAccess.file_exists(caminho):
		var arquivo_existente := FileAccess.open(caminho, FileAccess.READ)
		if arquivo_existente == null:
			push_error("Não foi possível abrir a semente persistente do mundo celeste.")
			return 0
		var dados = JSON.parse_string(arquivo_existente.get_as_text())
		arquivo_existente.close()
		if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1:
			push_error("A semente persistente do mundo celeste está corrompida ou usa uma versão inválida.")
			return 0
		var semente_salva := int(dados.get("semente", 0))
		if semente_salva <= 0:
			push_error("A semente persistente do mundo celeste é inválida.")
			return 0
		return semente_salva
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var nova_semente := maxi(1, int(rng.randi()))
	var diretorio := ProjectSettings.globalize_path(caminho.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(diretorio) != OK and not DirAccess.dir_exists_absolute(diretorio):
		push_error("Não foi possível criar o diretório para persistir a semente do mundo.")
		return 0
	var caminho_temporario := caminho + ".tmp"
	var arquivo := FileAccess.open(caminho_temporario, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível abrir o arquivo temporário da semente celeste.")
		return 0
	arquivo.store_string(JSON.stringify({"versao":1,"semente":nova_semente}))
	arquivo.flush()
	var erro_gravacao := arquivo.get_error()
	arquivo.close()
	if erro_gravacao != OK:
		push_error("Falha ao gravar a semente temporária do mundo celeste.")
		return 0
	var verificacao := FileAccess.open(caminho_temporario, FileAccess.READ)
	if verificacao == null:
		push_error("Não foi possível verificar a semente temporária do mundo celeste.")
		return 0
	var dados_verificados = JSON.parse_string(verificacao.get_as_text())
	verificacao.close()
	if not (dados_verificados is Dictionary) or int(dados_verificados.get("versao", 0)) != 1 or int(dados_verificados.get("semente", 0)) != nova_semente:
		push_error("A verificação da semente temporária do mundo celeste falhou.")
		return 0
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho_temporario), ProjectSettings.globalize_path(caminho)) != OK:
		push_error("Não foi possível promover a semente verificada para o arquivo persistente.")
		return 0
	return nova_semente

@rpc("authority", "call_remote", "reliable")
func _receber_anuncio_celeste(anuncio: Dictionary) -> void:
	# Anúncios também precisam pertencer ao mundo global ativo. Não aceite
	# payload incompleto ou originado de outro escopo geográfico/sala.
	if str(anuncio.get("mundoId", "")) != SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO or str(anuncio.get("escopo", "")) != "global":
		return
	var titulo := str(anuncio.get("titulo", "")).strip_edges()
	var mensagem := str(anuncio.get("mensagem", "")).strip_edges()
	if titulo.is_empty() or mensagem.is_empty() or titulo.length() > 160 or mensagem.length() > 1200:
		return
	anuncio_celeste_recebido.emit(anuncio.duplicate(true))

## Pacotes de relógio são frequentes e alimentam HUD, céu e eventos.
## Além do escopo global, valida o esquema para impedir valores inválidos na interface.
func _contexto_relogio_global_valido(contexto: Dictionary) -> bool:
	if str(contexto.get("mundoId", "")) != SISTEMA_SALAS.ID_MUNDO_COMPARTILHADO or str(contexto.get("escopo", "")) != "global":
		return false
	if not (contexto.get("hora", null) is int) or not (contexto.get("dia", null) is int):
		return false
	var hora := int(contexto["hora"])
	var dia := int(contexto["dia"])
	if hora < 0 or hora > 23 or dia < 1:
		return false
	var periodo := str(contexto.get("periodo", ""))
	if not ["dia", "crepusculo", "noite", "madrugada"].has(periodo):
		return false
	if not (contexto.get("noturno", null) is bool) or bool(contexto["noturno"]) != SISTEMA_CICLO_NOTURNO.esta_no_periodo_noturno(periodo):
		return false
	var fases_lunares := ["lua_nova", "lua_crescente", "quarto_crescente", "lua_gibosa_crescente", "lua_cheia", "lua_gibosa_minguante", "quarto_minguante", "lua_minguante", "fase_intermediaria"]
	if not fases_lunares.has(str(contexto.get("faseLunar", ""))):
		return false
	var evento = contexto.get("eventoCeleste", null)
	if not (evento is Dictionary):
		return false
	if str(evento.get("id", "")).is_empty() or str(evento.get("nome", "")).is_empty():
		return false
	var eventos = evento.get("eventos", null)
	if not (eventos is Array) or eventos.size() > 8:
		return false
	for campo in ["multiplicadorAparicao", "multiplicadorXP", "multiplicadorDrop"]:
		var multiplicador = evento.get(campo, null)
		if not (multiplicador is int or multiplicador is float):
			return false
		if not is_finite(float(multiplicador)) or float(multiplicador) < 0.0 or float(multiplicador) > 3.0:
			return false
	return true

@rpc("authority", "call_remote", "unreliable_ordered")
func _receber_relogio_mundo(contexto: Dictionary) -> void:
	if not _contexto_relogio_global_valido(contexto):
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
	# XP, itens, ovos e moedas só chegam ao cliente após confirmação do perfil no D1.
	if not await _confirmar_perfil_global(uid):
		push_error("Recompensa local não confirmada globalmente; host interrompido por segurança.")
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
	return await concluir_missao_mundo(peer_id, missao_id)

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
	return await concluir_atividade_e_conceder_recompensas(
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

func _salvar_perfil_jogador(id_jogador: int) -> bool:
	if not _uid_por_peer.has(id_jogador) or not _perfil_por_peer.has(id_jogador):
		return false
	var perfil: Dictionary = _perfil_por_peer[id_jogador]
	if _jogadores_no_mundo.has(id_jogador):
		var posicao: Vector2 = _jogadores_no_mundo[id_jogador]
		perfil["x"] = posicao.x
		perfil["y"] = posicao.y
	var uid := str(_uid_por_peer[id_jogador])
	if _repositorio_perfis.salvar(uid, perfil):
		_perfil_por_peer[id_jogador] = perfil
		_ultima_gravacao_ms[id_jogador] = Time.get_ticks_msec()
		if not _encerrando_persistencia_global:
			call_deferred("_sincronizar_perfil_global", uid, _repositorio_perfis.exportar_perfil_persistente(uid))
		return true
	push_error("Falha ao salvar personagem do UID autenticado.")
	return false

@rpc("authority", "call_remote", "unreliable_ordered")
func _receber_posicao_jogador(id_jogador: int, posicao: Vector2) -> void:
	# O cache usado ao trocar de cena recebe somente coordenadas confirmadas
	# pelo servidor, nunca a posição provisória prevista pelo cliente.
	if id_jogador == multiplayer.get_unique_id():
		atualizar_posicao_local_cache(posicao)
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
