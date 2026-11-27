extends SceneTree

const SistemaDrops = preload("res://scripts/sistema_drops.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var dificuldades := ["facil", "media", "dificil", "extrema"]
	var minimos := [4, 8, 13, 19]
	var maximos := [7, 12, 18, 25]
	var quantidades: Array[int] = []
	for i in range(dificuldades.size()):
		var entrada := SistemaDrops.criar_entrada_moeda_missao(dificuldades[i])
		if entrada.is_empty():
			_falhar("Não foi criada recompensa para %s." % dificuldades[i])
			return
		if str(entrada.get("denominacaoMoeda", "")) != "bronze" or float(entrada.get("chance", 0.0)) != 1.0:
			_falhar("A recompensa de missão deve ser Bronzhar garantida.")
			return
		if int(entrada.get("quantidadeMinima", 0)) != minimos[i] or int(entrada.get("quantidadeMaxima", 0)) != maximos[i]:
			_falhar("Faixa monetária incorreta para %s." % dificuldades[i])
			return
		quantidades.append(int(entrada["quantidadeMinima"]))
	for i in range(1, quantidades.size()):
		if quantidades[i] <= quantidades[i - 1]:
			_falhar("Missões mais difíceis precisam pagar mais.")
			return
	if not SistemaDrops.criar_entrada_moeda_missao("impossivel").is_empty():
		_falhar("Dificuldade desconhecida não pode gerar recompensa.")
		return
	var tabela: Array = [SistemaDrops.criar_entrada_moeda_missao("dificil")]
	if not SistemaDrops.validar_tabela(tabela):
		_falhar("A recompensa de missão precisa ser compatível com o motor de drops.")
		return
	var resultado := SistemaDrops.resolver_tabela(tabela, "missao_teste", {"semente":12345})
	if resultado.size() != 1 or not bool(resultado[0].get("obtido", false)):
		_falhar("A recompensa garantida não foi resolvida.")
		return
	print("TESTE DE RECOMPENSAS DE MISSÕES: dificuldade, faixas e garantia aprovadas.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE RECOMPENSAS DE MISSÕES: " + mensagem)
	quit(1)
