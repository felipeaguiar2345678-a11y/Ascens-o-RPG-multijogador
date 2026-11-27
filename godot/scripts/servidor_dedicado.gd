extends Node
## Entrada dedicada. A lease é conquistada antes de abrir a porta ENet.
## Execute com: godot --headless --path godot res://scenes/servidor_dedicado.tscn

const PORTA_PADRAO := 2456
const LIMITE_JOGADORES_PADRAO := 40
const TTL_LEASE_SEGUNDOS := 30
const INTERVALO_RENOVACAO_SEGUNDOS := 10
const REPOSITORIO_REMOTO = preload("res://scripts/repositorio_mundo_remoto.gd")

var _cliente_lease
var _timer_lease: Timer
var _renovacao_em_andamento := false
var _encerramento_em_andamento := false
var _flush_persistencia_global_em_andamento := false
var _porta := PORTA_PADRAO
var _limite := LIMITE_JOGADORES_PADRAO

func _ready() -> void:
	if not RedeMultiplayer.erro_conexao.is_connected(_ao_erro_rede):
		RedeMultiplayer.erro_conexao.connect(_ao_erro_rede)
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--porta="):
			_porta = int(argumento.trim_prefix("--porta="))
		elif argumento.begins_with("--limite="):
			_limite = int(argumento.trim_prefix("--limite="))
	if _limite < 1 or _limite > LIMITE_JOGADORES_PADRAO or _porta < 1 or _porta > 65535:
		_falhar_inicio("Porta ou limite de jogadores inválido.")
		return
	call_deferred("_iniciar_com_lease")

func _iniciar_com_lease() -> void:
	_cliente_lease = REPOSITORIO_REMOTO.new()
	add_child(_cliente_lease)
	if not _cliente_lease.configurar():
		_falhar_inicio("Persistência global não configurada. Defina ASCENSAO_WORLD_STORAGE_URL e ASCENSAO_WORLD_STORAGE_TOKEN no host dedicado.")
		return
	if not _cliente_lease.criar_identidade_lease():
		_falhar_inicio("Não foi possível gerar uma identidade criptograficamente aleatória para este host.")
		return

	print("Solicitando autorização exclusiva para hospedar o mundo global...")
	var resultado_lease: Dictionary = await _cliente_lease.adquirir_lease(TTL_LEASE_SEGUNDOS)
	if not bool(resultado_lease.get("ok", false)):
		_falhar_inicio("Não foi possível adquirir a lease global: %s" % str(resultado_lease.get("erro", "erro desconhecido")))
		return

	# A inicialização recupera vários documentos globais em sequência e pode
	# ultrapassar o TTL. Renova a lease desde já, não apenas após abrir ENet.
	_iniciar_timer_renovacao_lease()
	RedeMultiplayer.configurar_persistencia_mundo_remota(_cliente_lease)
	var resultado_servidor: Error = await RedeMultiplayer.iniciar_servidor(_porta, _limite, true)
	if resultado_servidor != OK:
		if is_instance_valid(_timer_lease):
			_timer_lease.stop()
		await _cliente_lease.liberar_lease()
		_falhar_inicio("Falha ao iniciar servidor ENet: %s" % error_string(resultado_servidor))
		return

	print("Ascensão do Soberano — host autorizado na porta UDP %d (limite %d jogadores)." % [_porta, _limite])
	print("Lease global adquirida; renovação automática a cada %d segundos." % INTERVALO_RENOVACAO_SEGUNDOS)
	print("D1 autoritativo: Serpente, calendário, recursos ecológicos, 16 fragmentos da fauna, perfis, catálogo de criaturas, salas cooperativas, Allys, eventos, mímicos e piedade.")
	print("Arquivos user:// são espelhos/cache locais de recuperação; o D1 mantém a autoridade global enquanto a lease estiver ativa.")

func _iniciar_timer_renovacao_lease() -> void:
	_timer_lease = Timer.new()
	_timer_lease.name = "RenovacaoLeaseMundoGlobal"
	_timer_lease.wait_time = INTERVALO_RENOVACAO_SEGUNDOS
	_timer_lease.one_shot = false
	_timer_lease.timeout.connect(_renovar_lease)
	add_child(_timer_lease)
	_timer_lease.start()

func _ao_erro_rede(_mensagem: String) -> void:
	if RedeMultiplayer.estado == RedeMultiplayer.EstadoConexao.FALHA and not _encerramento_em_andamento:
		call_deferred("_encerrar_ordenadamente")

static func renovacao_lease_permitida(encerrando: bool, flush_ativo: bool, requisicao_em_andamento: bool) -> bool:
	return not requisicao_em_andamento and (not encerrando or flush_ativo)

func _renovar_lease() -> void:
	if not renovacao_lease_permitida(_encerramento_em_andamento, _flush_persistencia_global_em_andamento, _renovacao_em_andamento):
		return
	_renovacao_em_andamento = true
	var resultado: Dictionary = await _cliente_lease.renovar_lease(TTL_LEASE_SEGUNDOS)
	_renovacao_em_andamento = false
	# Durante o flush final a lease continua sendo renovada. Se essa renovação
	# falhar, o repositório marca lease_ativa=false e o flush aborta sem liberá-la.
	if _encerramento_em_andamento:
		if _flush_persistencia_global_em_andamento and not bool(resultado.get("ok", false)):
			if is_instance_valid(_timer_lease):
				_timer_lease.stop()
			push_error("A lease global expirou durante o flush final: %s" % str(resultado.get("erro", "renovação recusada")))
		return
	if bool(resultado.get("ok", false)):
		return
	if is_instance_valid(_timer_lease):
		_timer_lease.stop()
	push_error("LEASE GLOBAL PERDIDA: %s" % str(resultado.get("erro", "renovação recusada")))
	# Fecha ENet imediatamente; em seguida conclui o fluxo único de encerramento
	# para não deixar uma saída concorrente interromper a limpeza do host.
	RedeMultiplayer.encerrar_servidor_por_falha_lease()
	await _encerrar_ordenadamente(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		call_deferred("_encerrar_ordenadamente")

func _encerrar_ordenadamente(codigo_saida: int = 0) -> void:
	if _encerramento_em_andamento:
		return
	_encerramento_em_andamento = true
	# Mantém o timer ativo durante a drenagem: o TTL é de 30s e o flush final
	# pode fazer várias confirmações HTTP sequenciais antes de terminar.
	_flush_persistencia_global_em_andamento = true
	while _renovacao_em_andamento:
		await get_tree().process_frame
	var estado_global_confirmado := await RedeMultiplayer.sincronizar_estado_global_antes_de_encerrar()
	_flush_persistencia_global_em_andamento = false
	if is_instance_valid(_timer_lease):
		_timer_lease.stop()
	# Espera eventual renovação que já tenha começado no fim do flush e verifica
	# novamente a validade local antes de decidir por uma liberação explícita.
	while _renovacao_em_andamento:
		await get_tree().process_frame
	if estado_global_confirmado and (not is_instance_valid(_cliente_lease) or not _cliente_lease.lease_ativa):
		estado_global_confirmado = false
		push_warning("A lease não permaneceu ativa até o fim do flush; ela expirará sem liberação manual.")
	if not estado_global_confirmado:
		push_warning("Nem todos os snapshots globais foram confirmados em D1. A lease não será liberada manualmente e expirará em até %d segundos." % TTL_LEASE_SEGUNDOS)
	RedeMultiplayer.desconectar()
	if estado_global_confirmado and is_instance_valid(_cliente_lease) and _cliente_lease.lease_ativa:
		var resultado: Dictionary = await _cliente_lease.liberar_lease()
		if not bool(resultado.get("ok", false)):
			push_warning("A liberação explícita da lease falhou; ela expirará automaticamente em até %d segundos." % TTL_LEASE_SEGUNDOS)
	get_tree().quit(codigo_saida)

func _falhar_inicio(mensagem: String) -> void:
	push_error("Falha ao iniciar servidor dedicado: " + mensagem)
	get_tree().quit(1)
