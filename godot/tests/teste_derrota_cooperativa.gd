extends SceneTree

const Repositorio = preload("res://scripts/repositorio_personagem_servidor.gd")
const SistemaMoedas = preload("res://scripts/sistema_moedas.gd")
const LocaisMundo = preload("res://scripts/sistema_locais_missoes_mundo.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var ponto_abrigo: Dictionary = LocaisMundo.obter_ponto_renascimento("abrigo_viajante")
	var posicao_abrigo: Vector2 = ponto_abrigo.get("posicao", Vector2.ZERO)
	if ponto_abrigo.is_empty() or posicao_abrigo != Vector2(1096.0, 1485.0):
		_falhar("O abrigo do viajante não foi reconhecido como ponto seguro canônico.")
		return
	if not LocaisMundo.obter_ponto_renascimento("iren_viajante").is_empty():
		_falhar("Um NPC foi classificado incorretamente como ponto de renascimento.")
		return
	var repositorio = Repositorio.new()
	var uid := "ci_derrota_coop_%s" % str(Time.get_ticks_usec())
	var criado: Dictionary = repositorio.criar_personagem(uid, "Teste Derrota", "masculino", "masc_cabelo_curto", "humano", "guerreiro")
	if criado.is_empty():
		_falhar("Não criou o personagem para testar a derrota cooperativa.")
		return
	if str(criado.get("pontoRenascimentoId", "")) != "clareira_inicial" or float(criado.get("xRenascimento", -1.0)) != 1190.0 or float(criado.get("yRenascimento", -1.0)) != 1520.0:
		_falhar("O personagem novo não recebeu a Clareira Inicial como ponto de renascimento.")
		return
	var checkpoint: Dictionary = repositorio.atualizar_ponto_renascimento(uid, "aurelia", 1320.0, 1410.0)
	if not bool(checkpoint.get("ok", false)):
		_falhar("Não persistiu o último ponto de renascimento validado pelo servidor.")
		return
	criado = repositorio.carregar_ou_criar(uid)
	criado["pontoMundoId"] = "local_temporario"
	criado["x"] = 200.0
	criado["y"] = 250.0
	if not repositorio.salvar(uid, criado):
		_falhar("Não preparou a posição atual diferente do ponto de renascimento.")
		return
	var saldo_inicial := {
		"bronze":250,
		"ferro":0,
		"ouro":1,
		"diamante":0,
		"jade":1
	}
	criado["experiencia"] = 101
	criado["moedas"] = saldo_inicial
	if not repositorio.salvar(uid, criado):
		_falhar("Não persistiu os recursos iniciais do teste.")
		return
	var valor_inicial := SistemaMoedas.valor_total_em_bronze(saldo_inicial)
	var esperado_perda := int(floor(float(valor_inicial) * 0.2))
	var esperado_saldo := valor_inicial - esperado_perda
	var primeiro: Dictionary = repositorio.processar_derrota_cooperativa(uid, "encontro-derrota-teste")
	if not bool(primeiro.get("ok", false)) or bool(primeiro.get("duplicada", true)):
		_falhar("Não aplicou a primeira penalidade de derrota.")
		return
	if int(primeiro.get("experienciaPerdida", -1)) != 51 or int(primeiro.get("experienciaRestante", -1)) != 50:
		_falhar("A derrota não removeu metade da experiência acumulada.")
		return
	if int(primeiro.get("valorMoedasPerdidoEmBronze", -1)) != esperado_perda:
		_falhar("A perda monetária não correspondeu a 20% do valor total.")
		return
	var perfil_apos_derrota: Dictionary = primeiro.get("perfil", {})
	if str(perfil_apos_derrota.get("pontoMundoId", "")) != "aurelia" or float(perfil_apos_derrota.get("x", -1.0)) != 1320.0 or float(perfil_apos_derrota.get("y", -1.0)) != 1410.0:
		_falhar("A derrota não retornou o personagem ao último ponto de renascimento persistido.")
		return
	var saldo_resultante: Dictionary = primeiro.get("moedas", {})
	if SistemaMoedas.valor_total_em_bronze(saldo_resultante) != esperado_saldo:
		_falhar("A perda monetária não preservou o valor correto após devolver o troco.")
		return
	var segundo: Dictionary = repositorio.processar_derrota_cooperativa(uid, "encontro-derrota-teste")
	if not bool(segundo.get("ok", false)) or not bool(segundo.get("duplicada", false)):
		_falhar("A repetição da mesma derrota não foi reconhecida como duplicada.")
		return
	var salvo: Dictionary = repositorio.carregar_ou_criar(uid)
	if int(salvo.get("experiencia", -1)) != 50 or SistemaMoedas.valor_total_em_bronze(salvo.get("moedas", {})) != esperado_saldo:
		_falhar("A penalidade foi reaplicada ou não foi persistida corretamente.")
		return
	if not repositorio.registrar_recursos_combate(uid, 0, 0, true):
		_falhar("Não restaurou os recursos após a derrota total.")
		return
	salvo = repositorio.carregar_ou_criar(uid)
	if int(salvo.get("vida", 0)) != int(salvo.get("vidaMaxima", 0)) or int(salvo.get("mana", 0)) != int(salvo.get("manaMaxima", 0)):
		_falhar("A derrota total não restaurou HP e Mana ao máximo.")
		return
	if int(salvo.get("experiencia", -1)) != 50 or SistemaMoedas.valor_total_em_bronze(salvo.get("moedas", {})) != esperado_saldo:
		_falhar("A restauração de HP/Mana alterou as penalidades já registradas.")
		return
	var outro_encontro: Dictionary = repositorio.processar_derrota_cooperativa(uid, "encontro-derrota-segundo")
	if not bool(outro_encontro.get("ok", false)) or int(outro_encontro.get("experienciaRestante", -1)) != 25:
		_falhar("Uma nova derrota não aplicou uma nova penalidade.")
		return
	# Simula a queda do servidor depois de penalizar apenas o primeiro integrante.
	var uids_recuperacao := ["ci_derrota_parcial_a_" + uid, "ci_derrota_parcial_b_" + uid]
	for i in range(2):
		var perfil_criado: Dictionary = repositorio.criar_personagem(uids_recuperacao[i], "Teste Retomada %d" % (i + 1), "masculino", "masc_cabelo_curto", "humano", "guerreiro")
		if perfil_criado.is_empty():
			_falhar("Não criou participante para testar retomada parcial da derrota.")
			return
		perfil_criado["experiencia"] = 101 + (i * 100)
		if not repositorio.salvar(uids_recuperacao[i], perfil_criado):
			_falhar("Não preparou a experiência da retomada parcial.")
			return
	var id_derrota_parcial := "encontro-derrota-parcial-" + uid
	var primeira_penalidade: Dictionary = repositorio.processar_derrota_cooperativa(uids_recuperacao[0], id_derrota_parcial)
	if not bool(primeira_penalidade.get("ok", false)) or bool(primeira_penalidade.get("duplicada", true)):
		_falhar("Não persistiu a primeira penalidade da equipe.")
		return
	# Novo objeto simula o repositório após reinício; a conta A não pode perder XP duas vezes.
	var repositorio_recuperado = Repositorio.new()
	for i in range(2):
		var penalidade_recuperada: Dictionary = repositorio_recuperado.processar_derrota_cooperativa(uids_recuperacao[i], id_derrota_parcial)
		if not bool(penalidade_recuperada.get("ok", false)):
			_falhar("Não retomou a aplicação das penalidades pendentes.")
			return
		if i == 0 and not bool(penalidade_recuperada.get("duplicada", false)):
			_falhar("A retomada reaplicou a penalidade já confirmada.")
			return
		if i == 1 and bool(penalidade_recuperada.get("duplicada", true)):
			_falhar("A retomada não aplicou a penalidade do participante pendente.")
			return
		if not repositorio_recuperado.registrar_recursos_combate(uids_recuperacao[i], 0, 0, true):
			_falhar("Não restaurou os recursos após retomar a derrota.")
			return
		var perfil_recuperado: Dictionary = repositorio_recuperado.carregar_ou_criar(uids_recuperacao[i])
		var xp_esperado := 50 if i == 0 else 100
		if int(perfil_recuperado.get("experiencia", -1)) != xp_esperado:
			_falhar("A recuperação parcial alterou indevidamente a experiência do participante.")
			return
		if int(perfil_recuperado.get("vida", 0)) != int(perfil_recuperado.get("vidaMaxima", 0)) or int(perfil_recuperado.get("mana", 0)) != int(perfil_recuperado.get("manaMaxima", 0)):
			_falhar("A recuperação parcial não restaurou HP e Mana.")
			return
	print("TESTE DE DERROTA COOPERATIVA: penalidades, restauração e retomada parcial idempotente aprovadas.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE DERROTA COOPERATIVA: " + mensagem)
	quit(1)
