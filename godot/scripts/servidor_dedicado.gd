extends Node
## Entrada dedicada. A lease é conquistada antes de abrir a porta ENet.
## Execute com: godot --headless --path godot res://scenes/servidor_dedicado.tscn

const PORTA_PADRAO := 2456
const LIMITE_JOGADORES_PADRAO := 40
const TTL_LEASE_SEGUNDOS := 30
const INTERVALO_RENOVACAO_SEGUNDOS := 10
const REPOSITORIO_REMOTO = preload("res://scripts/repositorio_mundo_remoto.gd")

var _cliente_lease: Node
var _timer_lease: Timer
var _renovacao_em_andamento := false
var _encerramento_em_andamento := false
var _porta := PORTA_PADRAO
var _limite := LIMITE_JOGADORES_PADRAO

func _ready() -> void:
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

	var resultado_servidor := RedeMultiplayer.iniciar_servidor(_porta, _limite, true)
	if resultado_servidor != OK:
		await _cliente_lease.liberar_lease()
		_falhar_inicio("Falha ao iniciar servidor ENet: %s" % error_string(resultado_servidor))
		return

	_timer_lease = Timer.new()
	_timer_lease.name = "RenovacaoLeaseMundoGlobal"
	_timer_lease.wait_time = INTERVALO_RENOVACAO_SEGUNDOS
	_timer_lease.one_shot = false
	_timer_lease.timeout.connect(_renovar_lease)
	add_child(_timer_lease)
	_timer_lease.start()

	print("Ascensão do Soberano — host autorizado na porta UDP %d (limite %d jogadores)." % [_porta, _limite])
	print("Lease global adquirida; renovação automática a cada %d segundos." % INTERVALO_RENOVACAO_SEGUNDOS)
	print("Atenção: a lease impede dois hosts ativos, mas os repositórios do jogo ainda usam armazenamento local neste estágio.")

func _renovar_lease() -> void:
	if _renovacao_em_andamento or _encerramento_em_andamento:
		return
	_renovacao_em_andamento = true
	var resultado: Dictionary = await _cliente_lease.renovar_lease(TTL_LEASE_SEGUNDOS)
	_renovacao_em_andamento = false
	if bool(resultado.get("ok", false)):
		return
	if is_instance_valid(_timer_lease):
		_timer_lease.stop()
	push_error("LEASE GLOBAL PERDIDA: %s" % str(resultado.get("erro", "renovação recusada")))
	RedeMultiplayer.encerrar_servidor_por_falha_lease()
	get_tree().quit(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		call_deferred("_encerrar_ordenadamente")

func _encerrar_ordenadamente() -> void:
	if _encerramento_em_andamento:
		return
	_encerramento_em_andamento = true
	if is_instance_valid(_timer_lease):
		_timer_lease.stop()
	RedeMultiplayer.desconectar()
	if is_instance_valid(_cliente_lease) and _cliente_lease.lease_ativa:
		var resultado: Dictionary = await _cliente_lease.liberar_lease()
		if not bool(resultado.get("ok", false)):
			push_warning("A liberação explícita da lease falhou; ela expirará automaticamente em até %d segundos." % TTL_LEASE_SEGUNDOS)
	get_tree().quit(0)

func _falhar_inicio(mensagem: String) -> void:
	push_error("Falha ao iniciar servidor dedicado: " + mensagem)
	get_tree().quit(1)
