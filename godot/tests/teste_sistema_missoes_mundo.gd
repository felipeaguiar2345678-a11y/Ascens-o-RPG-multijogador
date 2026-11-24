extends SceneTree

const SistemaMissoes = preload("res://scripts/sistema_missoes_mundo.gd")

func _initialize() -> void:
	var sistema = SistemaMissoes.new()
	var estado := {"missoes": {}, "missoesConcluidas": {}}
	var definicao := {
		"id": "teste_derrotar_lobos",
		"npcId": "iren_viajante",
		"titulo": "Rastro na clareira",
		"descricao": "Confirme duas vitórias contra a criatura de teste.",
		"dificuldade": "facil",
		"objetivos": [
			{"id": "vitorias", "tipo": "derrotar_criatura", "alvoId": "criatura_teste", "quantidade": 2}
		]
	}
	_verificar(bool(sistema.registrar_oferta(definicao).get("ok", false)), "A oferta válida não foi registrada.")

	var inicio: Dictionary = sistema.aceitar_missao(estado, "teste_derrotar_lobos")
	_verificar(bool(inicio.get("ok", false)), "A missão não pôde ser aceita.")
	estado = inicio["estado"]

	var irrelevante: Dictionary = sistema.registrar_evento_autoritativo(estado, "derrotar_criatura", "outra_criatura", 1)
	_verificar(bool(irrelevante.get("ok", false)), "Evento não relacionado foi rejeitado.")
	estado = irrelevante["estado"]
	_verificar(int(estado["missoes"]["teste_derrotar_lobos"]["progresso"]["vitorias"]) == 0, "Evento de outra criatura avançou a missão.")

	var primeira: Dictionary = sistema.registrar_evento_autoritativo(estado, "derrotar_criatura", "criatura_teste", 1)
	estado = primeira["estado"]
	_verificar(int(estado["missoes"]["teste_derrotar_lobos"]["progresso"]["vitorias"]) == 1, "A primeira vitória não foi contabilizada.")
	_verificar(str(estado["missoes"]["teste_derrotar_lobos"]["status"]) == "em_andamento", "A missão foi concluída antes da meta.")

	var excedente: Dictionary = sistema.registrar_evento_autoritativo(estado, "derrotar_criatura", "criatura_teste", 5)
	estado = excedente["estado"]
	_verificar(int(estado["missoes"]["teste_derrotar_lobos"]["progresso"]["vitorias"]) == 2, "O progresso ultrapassou o limite do objetivo.")
	_verificar(str(estado["missoes"]["teste_derrotar_lobos"]["status"]) == "objetivos_concluidos", "A missão não foi marcada como pronta.")
	_verificar(bool(sistema.preparar_conclusao(estado, "teste_derrotar_lobos").get("ok", false)), "A conclusão válida foi recusada.")

	var definicao_abandono := definicao.duplicate(true)
	definicao_abandono["id"] = "teste_abandonar"
	definicao_abandono["objetivos"] = [{"id": "visitas", "tipo": "visitar_local", "alvoId": "local_teste", "quantidade": 1}]
	_verificar(bool(sistema.registrar_oferta(definicao_abandono).get("ok", false)), "A segunda oferta não foi registrada.")
	var aceita_abandono: Dictionary = sistema.aceitar_missao(estado, "teste_abandonar")
	estado = aceita_abandono["estado"]
	var abandono: Dictionary = sistema.abandonar_missao(estado, "teste_abandonar")
	_verificar(bool(abandono.get("ok", false)), "A missão ativa não pôde ser abandonada.")
	estado = abandono["estado"]
	_verificar(str(estado["missoes"]["teste_abandonar"]["status"]) == "abandonada", "O abandono não foi persistido no estado retornado.")

	var definicao_recusa := definicao.duplicate(true)
	definicao_recusa["id"] = "teste_recusar_reaceitar"
	_verificar(bool(sistema.registrar_oferta(definicao_recusa).get("ok", false)), "A terceira oferta não foi registrada.")
	var recusa: Dictionary = sistema.recusar_oferta(estado, "teste_recusar_reaceitar")
	_verificar(bool(recusa.get("ok", false)), "A oferta não pôde ser recusada.")
	estado = recusa["estado"]
	var reaceite: Dictionary = sistema.aceitar_missao(estado, "teste_recusar_reaceitar")
	_verificar(bool(reaceite.get("ok", false)), "Uma oferta recusada não pôde ser aceita posteriormente.")

	print("TESTE DE MISSÕES DO MUNDO: eventos específicos, limite de progresso, conclusão, abandono e recusa reversível aprovados.")
	quit(0)

func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		push_error("TESTE DE MISSÕES DO MUNDO: " + mensagem)
		quit(1)
