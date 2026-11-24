extends SceneTree

const ValidacaoSessao = preload("res://scripts/sistema_validacao_sessao.gd")

func _initialize() -> void:
	var pendentes := {}
	var requisicao_antiga := RefCounted.new()
	var requisicao_nova := RefCounted.new()
	pendentes[17] = requisicao_antiga

	_verificar(not ValidacaoSessao.consumir_se_corresponder(pendentes, 18, requisicao_antiga), "Aceitou uma requisição associada a outro peer.")
	_verificar(ValidacaoSessao.consumir_se_corresponder(pendentes, 17, requisicao_antiga), "Não consumiu a requisição da sessão original.")
	_verificar(not pendentes.has(17), "A requisição consumida continuou pendente.")

	# Simula o peer_id sendo reutilizado por uma nova conexão antes da resposta antiga.
	pendentes[17] = requisicao_nova
	_verificar(not ValidacaoSessao.consumir_se_corresponder(pendentes, 17, requisicao_antiga), "Uma resposta antiga foi aceita para a nova sessão.")
	_verificar(pendentes.get(17) == requisicao_nova, "A resposta antiga removeu a validação da nova sessão.")
	_verificar(ValidacaoSessao.consumir_se_corresponder(pendentes, 17, requisicao_nova), "A validação da nova sessão não pôde ser consumida.")
	_verificar(pendentes.is_empty(), "Restaram validações pendentes após o consumo.")

	print("TESTE DE VALIDAÇÃO DE SESSÃO: isolamento entre conexões e respostas atrasadas aprovado.")
	quit(0)

func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		push_error("TESTE DE VALIDAÇÃO DE SESSÃO: " + mensagem)
		quit(1)
