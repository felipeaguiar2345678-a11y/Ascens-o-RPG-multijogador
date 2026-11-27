extends SceneTree

const Repositorio = preload("res://scripts/repositorio_personagem_servidor.gd")
const SistemaMoedas = preload("res://scripts/sistema_moedas.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var repositorio = Repositorio.new()
	var uid := "ci_moedas_%s" % str(Time.get_ticks_usec())
	var perfil: Dictionary = repositorio.carregar_ou_criar(uid)
	if perfil.is_empty():
		_falhar("Não criou perfil para teste de moedas.")
		return
	var criado := repositorio.criar_personagem(uid, "Teste Moedas", "masculino", "masc_cabelo_curto", "humano", "guerreiro")
	if criado.is_empty():
		_falhar("Não criou personagem para teste de moedas.")
		return
	var saldo_inicial: Dictionary = criado.get("moedas", {})
	for moeda in SistemaMoedas.DENOMINACOES:
		if SistemaMoedas.nome_exibicao(moeda).is_empty() or SistemaMoedas.simbolo(moeda).is_empty():
			_falhar("Toda denominação precisa de nome e símbolo próprios.")
			return
		if int(saldo_inicial.get(moeda, -1)) != 0:
			_falhar("O saldo inicial deve começar zerado.")
			return
	var credito := repositorio.conceder_moedas(uid, "bronze", 250)
	if not bool(credito.get("ok", false)):
		_falhar("Não concedeu moedas pelo servidor.")
		return
	var conversao := repositorio.converter_moedas(uid, "bronze", 200)
	if not bool(conversao.get("ok", false)):
		_falhar("Não converteu 200 moedas de bronze.")
		return
	var saldo: Dictionary = conversao.get("moedas", {})
	if int(saldo.get("bronze", -1)) != 50 or int(saldo.get("ferro", -1)) != 2:
		_falhar("A conversão não preservou o valor e o troco.")
		return
	if SistemaMoedas.valor_total_em_bronze(saldo) != 250:
		_falhar("A conversão alterou o valor econômico total.")
		return
	if repositorio.converter_moedas(uid, "bronze", 50).get("ok", false):
		_falhar("Aceitou conversão que não é múltipla de 100.")
		return
	if repositorio.converter_moedas(uid, "ferro", 100).get("ok", false):
		_falhar("Aceitou conversão sem saldo suficiente.")
		return
	if repositorio.converter_moedas(uid, "jade", 100).get("ok", false):
		_falhar("Permitiu converter a moeda de maior valor para cima.")
		return
	var recarregado: Dictionary = repositorio.carregar_ou_criar(uid)
	var saldo_salvo: Dictionary = recarregado.get("moedas", {})
	if int(saldo_salvo.get("bronze", -1)) != 50 or int(saldo_salvo.get("ferro", -1)) != 2:
		_falhar("O saldo convertido não foi persistido.")
		return
	print("TESTE DE MOEDAS: saldos, conversão manual, troco, limites e persistência aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE MOEDAS: " + mensagem)
	quit(1)
