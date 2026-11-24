extends SceneTree

const Combate = preload("res://scripts/sistema_combate_cooperativo.gd")

func _initialize() -> void:
	if not _testar_vitoria_com_companheiro_derrotado():
		return
	if not _testar_derrota_somente_quando_todos_caem():
		return
	print("OK: regras de morte individual, vitória cooperativa e derrota coletiva.")
	quit(0)

func _testar_vitoria_com_companheiro_derrotado() -> bool:
	var estado := Combate.criar_estado(
		{"id":"criatura_teste","nome":"Guardião de Teste","vidaMaxima":10,"ataque":1000,"defesa":0},
		[
			{"uid":"uid-a","nome":"Aventureiro A","vida":1,"vidaMaxima":100,"ataque":1,"defesa":0},
			{"uid":"uid-b","nome":"Aventureiro B","vida":100,"vidaMaxima":100,"ataque":1000,"defesa":0}
		]
	)
	if estado.is_empty():
		return _falhar("Não foi possível criar o combate cooperativo de teste.")
	var primeira_acao := Combate.executar_acao(estado, "uid-a", Combate.ACAO_DEFENDER, 123)
	if not bool(primeira_acao.get("ok", false)):
		return _falhar("O primeiro participante não conseguiu executar sua ação.")
	estado = primeira_acao.get("estado", {})
	if str(estado.get("status", "")) != Combate.EM_ANDAMENTO:
		return _falhar("A batalha terminou quando apenas o primeiro participante foi derrotado.")
	if int(estado.get("participantes", [])[0].get("vida", -1)) != 0:
		return _falhar("O primeiro participante deveria permanecer derrotado durante a batalha.")
	if int(estado.get("indiceTurno", -1)) != 1:
		return _falhar("O turno não passou para o companheiro que continua vivo.")
	var ataque_final := Combate.executar_acao(estado, "uid-b", Combate.ACAO_ATAQUE, 456)
	if not bool(ataque_final.get("ok", false)):
		return _falhar("O companheiro vivo não conseguiu finalizar a criatura.")
	estado = ataque_final.get("estado", {})
	if str(estado.get("status", "")) != Combate.VITORIA:
		return _falhar("A equipe não venceu após o último ataque do companheiro vivo.")
	var derrotado: Dictionary = estado.get("participantes", [])[0]
	if int(derrotado.get("vida", 0)) != 1 or not bool(derrotado.get("elegivelRecompensas", false)):
		return _falhar("O companheiro derrotado não retornou com 1 HP e direito às recompensas.")
	var distribuicao := Combate.calcular_distribuicao_recompensas(estado, 101)
	if distribuicao.size() != 2:
		return _falhar("A experiência não foi distribuída para todos os participantes originais.")
	if int(distribuicao[0].get("experiencia", 0)) != 51 or int(distribuicao[1].get("experiencia", 0)) != 50:
		return _falhar("A divisão de experiência não preservou o total e o resto.")
	if not bool(distribuicao[1].get("receberDrops", false)) or bool(distribuicao[0].get("receberDrops", true)):
		return _falhar("Os drops não foram destinados ao participante com maior dano.")
	return true

func _testar_derrota_somente_quando_todos_caem() -> bool:
	var estado := Combate.criar_estado(
		{"id":"criatura_teste_2","nome":"Colosso de Teste","vidaMaxima":10000,"ataque":1000,"defesa":0},
		[
			{"uid":"uid-c","nome":"Aventureiro C","vida":1,"vidaMaxima":100,"ataque":1,"defesa":0},
			{"uid":"uid-d","nome":"Aventureiro D","vida":1,"vidaMaxima":100,"ataque":1,"defesa":0}
		]
	)
	if estado.is_empty():
		return _falhar("Não foi possível criar o combate para testar a derrota coletiva.")
	var primeira_acao := Combate.executar_acao(estado, "uid-c", Combate.ACAO_DEFENDER, 789)
	if not bool(primeira_acao.get("ok", false)):
		return _falhar("O primeiro participante não conseguiu executar a ação de teste.")
	estado = primeira_acao.get("estado", {})
	if str(estado.get("status", "")) != Combate.EM_ANDAMENTO:
		return _falhar("A derrota coletiva ocorreu antes de todos os participantes caírem.")
	var segunda_acao := Combate.executar_acao(estado, "uid-d", Combate.ACAO_DEFENDER, 987)
	if not bool(segunda_acao.get("ok", false)):
		return _falhar("O segundo participante não conseguiu executar a ação de teste.")
	estado = segunda_acao.get("estado", {})
	if str(estado.get("status", "")) != Combate.DERROTA:
		return _falhar("A batalha não encerrou após todos os participantes serem derrotados.")
	if str(estado.get("retornoGrupo", "")) != "ponto_renascimento":
		return _falhar("A derrota coletiva não encaminhou o grupo ao ponto de renascimento.")
	for participante in estado.get("participantes", []):
		if bool(participante.get("elegivelRecompensas", false)):
			return _falhar("Um participante derrotado recebeu elegibilidade indevida para recompensas.")
	return true

func _falhar(mensagem: String) -> bool:
	push_error(mensagem)
	printerr("FALHA: " + mensagem)
	quit(1)
	return false
