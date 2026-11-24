extends SceneTree

const Repositorio = preload("res://scripts/repositorio_personagem_servidor.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var repositorio = Repositorio.new()
	var uid := "ci_missao_unica_%s" % str(Time.get_ticks_usec())
	var perfil := repositorio.carregar_ou_criar(uid)
	if perfil.is_empty():
		_falhar("Não criou o perfil de teste.")
		return
	perfil = repositorio.criar_personagem(uid, "Teste Missao", "masculino", "masc_cabelo_curto", "humano", "guerreiro")
	if perfil.is_empty():
		_falhar("Não criou o personagem de teste.")
		return
	var primeiro: Dictionary = repositorio.concluir_missao(uid, "missao_teste_unica", "dificil")
	if not bool(primeiro.get("ok", false)):
		_falhar("Não concedeu a primeira recompensa.")
		return
	var quantidade := int(primeiro.get("quantidadeRecebida", 0))
	if quantidade < 13 or quantidade > 18 or str(primeiro.get("nomeMoeda", "")) != "Bronzhar ⛨":
		_falhar("Valor ou identidade da recompensa incorretos.")
		return
	var segundo: Dictionary = repositorio.concluir_missao(uid, "missao_teste_unica", "dificil")
	if bool(segundo.get("ok", false)) or not bool(segundo.get("duplicada", false)):
		_falhar("Permitiu pagar a mesma missão duas vezes.")
		return
	var salvo := repositorio.carregar_ou_criar(uid)
	if int(salvo.get("moedas", {}).get("bronze", 0)) != quantidade:
		_falhar("Saldo salvo não corresponde ao pagamento único.")
		return
	if not salvo.get("missoesConcluidas", {}).has("missao_teste_unica"):
		_falhar("Conclusão da missão não foi persistida.")
		return
	var recibo: Dictionary = salvo["missoesConcluidas"]["missao_teste_unica"]
	if int(recibo.get("concluidaEmUnix", 0)) <= 0:
		_falhar("O recibo não registrou a data de conclusão.")
		return
	var recompensas: Array = recibo.get("recompensas", [])
	if recompensas.size() != 1 or str(recompensas[0].get("denominacao", "")) != "bronze" or int(recompensas[0].get("quantidade", 0)) != quantidade:
		_falhar("O recibo não preservou os detalhes da recompensa.")
		return
	var invalida: Dictionary = repositorio.concluir_missao(uid, "missao_sem_dificuldade", "impossivel")
	if bool(invalida.get("ok", false)):
		_falhar("Aceitou dificuldade inválida.")
		return
	print("TESTE DE PAGAMENTO ÚNICO DE MISSÃO: idempotência e persistência aprovadas.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE PAGAMENTO ÚNICO DE MISSÃO: " + mensagem)
	quit(1)
