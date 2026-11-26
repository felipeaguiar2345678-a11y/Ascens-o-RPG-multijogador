extends SceneTree

const Repositorio = preload("res://scripts/repositorio_serpente_mundo_servidor.gd")
const Sistema = preload("res://scripts/sistema_serpente_mundo.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var base := "user://dados/teste_serpente_persistencia_%s.json" % str(Time.get_ticks_usec())
	var repositorio = Repositorio.new(base)
	var caminhos := [base, base + ".bak", base + ".tmp"]
	_limpar(caminhos)
	var inicial: Dictionary = repositorio.carregar()
	if not bool(inicial.get("sucesso", false)) or not bool(inicial.get("arquivoNovo", false)):
		_falhar("Não criou um estado inicial seguro para a Serpente.")
		return
	var estado: Dictionary = inicial.get("estado", {}).duplicate(true)
	estado["vida"] = 1500000
	estado["revisaoSincronizacao"] = 11
	if not repositorio.salvar(estado):
		_falhar("Não persistiu o primeiro estado da Serpente.")
		return
	estado["vida"] = 1250000
	estado["revisaoSincronizacao"] = 12
	if not repositorio.salvar(estado):
		_falhar("Não persistiu a atualização mais recente.")
		return
	var principal_abs := ProjectSettings.globalize_path(base)
	var arquivo_corrompido := FileAccess.open(base, FileAccess.WRITE)
	if arquivo_corrompido == null:
		_falhar("Não conseguiu preparar o teste de corrupção do arquivo principal.")
		return
	arquivo_corrompido.store_string("{arquivo corrompido")
	arquivo_corrompido.close()
	var recuperacao: Dictionary = repositorio.carregar()
	if not bool(recuperacao.get("sucesso", false)) or not bool(recuperacao.get("recuperadoBackup", false)):
		_falhar("Não recuperou o backup válido após corrupção do arquivo principal.")
		return
	var estado_recuperado: Dictionary = recuperacao.get("estado", {})
	if int(estado_recuperado.get("vida", 0)) != 1500000:
		_falhar("A recuperação não preservou o último estado íntegro anterior à gravação interrompida.")
		return
	if int(estado_recuperado.get("revisaoSincronizacao", 0)) != 11:
		_falhar("A recuperação do backup perdeu a revisão global persistida da Serpente.")
		return
	# A gravação seguinte restaura o backup antes de promover o novo principal.
	estado_recuperado["vida"] = 1400000
	if not repositorio.salvar(estado_recuperado):
		_falhar("Não conseguiu gravar após recuperar o backup.")
		return
	var restaurado: Dictionary = repositorio.carregar()
	if not bool(restaurado.get("sucesso", false)) or int(restaurado.get("estado", {}).get("vida", 0)) != 1400000:
		_falhar("O estado não permaneceu válido após recuperação e nova gravação.")
		return
	if int(restaurado.get("estado", {}).get("revisaoSincronizacao", 0)) != 11:
		_falhar("A nova gravação após recuperação não preservou a revisão global.")
		return
	for caminho in [base, base + ".bak"]:
		var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
		if arquivo == null:
			_falhar("Não conseguiu preparar corrupção total para teste de proteção.")
			return
		arquivo.store_string("inválido")
		arquivo.close()
	var bloqueio: Dictionary = repositorio.carregar()
	if bool(bloqueio.get("sucesso", true)):
		_falhar("Aceitou estado corrompido sem backup; deveria bloquear inicialização para proteger o mundo.")
		return
	if repositorio.salvar(Sistema.criar_estado()):
		_falhar("Sobrescreveu arquivos corrompidos sem recuperação válida.")
		return
	# Simula um novo processo/host retomando a Serpente três dias após a janela de renascimento.
	var base_offline := base + ".offline"
	var caminhos_offline := [base_offline, base_offline + ".bak", base_offline + ".tmp"]
	_limpar(caminhos_offline)
	var repositorio_offline = Repositorio.new(base_offline)
	var derrotado := Sistema.criar_estado()
	var derrota_unix := 1800000000
	derrotado["status"] = Sistema.STATUS_DERROTADA
	derrotado["vida"] = 0
	derrotado["derrotadaUnix"] = derrota_unix
	derrotado["proximoRenascimentoUnix"] = derrota_unix + Sistema.TEMPO_RENASCIMENTO_SEGUNDOS
	derrotado["ciclos"] = 5
	derrotado["totalDerrotas"] = 4
	derrotado["revisaoSincronizacao"] = 19
	if not repositorio_offline.salvar(derrotado):
		_falhar("Não persistiu a derrota antes da troca de host.")
		return
	var novo_host = Repositorio.new(base_offline)
	var estado_recarregado: Dictionary = novo_host.carregar()
	if not bool(estado_recarregado.get("sucesso", false)):
		_falhar("O novo host não recuperou o estado derrotado da Serpente.")
		return
	var estado_apos_tres_dias := Sistema.verificar_renascimento(
		estado_recarregado.get("estado", {}),
		derrotado["proximoRenascimentoUnix"] + 3 * 86400
	)
	if str(estado_apos_tres_dias.get("status", "")) != Sistema.STATUS_DISPONIVEL or int(estado_apos_tres_dias.get("vida", 0)) != int(estado_apos_tres_dias.get("vidaMaxima", 0)):
		_falhar("A Serpente não concluiu o renascimento offline após a troca de host.")
		return
	if int(estado_apos_tres_dias.get("ciclos", 0)) != 6 or int(estado_apos_tres_dias.get("totalDerrotas", 0)) != 4 or int(estado_apos_tres_dias.get("ultimaDerrotaUnix", 0)) != derrota_unix:
		_falhar("A recuperação offline duplicou o ciclo ou perdeu o histórico de derrotas.")
		return
	_limpar(caminhos_offline)
	_limpar(caminhos)
	print("OK: estado global da Serpente, backup atômico, recuperação, renascimento offline e bloqueio contra perda de progresso.")
	quit()

func _limpar(caminhos: Array) -> void:
	for caminho in caminhos:
		var absoluto := ProjectSettings.globalize_path(str(caminho))
		if FileAccess.file_exists(str(caminho)):
			DirAccess.remove_absolute(absoluto)

func _falhar(mensagem: String) -> void:
	push_error(mensagem)
	quit(1)
