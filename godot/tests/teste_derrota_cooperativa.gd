extends SceneTree

const Repositorio = preload("res://scripts/repositorio_personagem_servidor.gd")
const SistemaMoedas = preload("res://scripts/sistema_moedas.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
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
	print("TESTE DE DERROTA COOPERATIVA: perda de XP, perda de moedas, troco e idempotência aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE DERROTA COOPERATIVA: " + mensagem)
	quit(1)
