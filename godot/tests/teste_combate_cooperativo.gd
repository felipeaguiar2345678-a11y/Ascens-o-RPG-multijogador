extends SceneTree

const Combate = preload("res://scripts/sistema_combate_cooperativo.gd")

func _initialize() -> void:
	if not _testar_vitoria_com_companheiro_derrotado():
		return
	if not _testar_derrota_somente_quando_todos_caem():
		return
	if not _testar_grupo_de_tres_criaturas():
		return
	if not _testar_morte_individual_em_grupo_de_criaturas():
		return
	if not _testar_derrota_coletiva_em_grupo_de_criaturas():
		return
	print("OK: morte individual, derrota coletiva, reconexão lógica e grupos de até três criaturas.")
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
	if not bool(distribuicao[0].get("receberDrops", false)) or not bool(distribuicao[1].get("receberDrops", false)):
		return _falhar("Todos os participantes elegíveis, inclusive quem foi derrotado antes da vitória, devem receber drops.")
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


func _testar_grupo_de_tres_criaturas() -> bool:
	var criaturas := [
		{"id":"especie_lobo","especieId":"especie_lobo","individuoId":"lobo-01","grupoId":"grupo-lobos","nome":"Lobo jovem","rank":"E","nivel":1,"vidaMaxima":1,"ataque":1,"defesa":0},
		{"id":"especie_lobo","especieId":"especie_lobo","individuoId":"lobo-02","grupoId":"grupo-lobos","nome":"Lobo caçador","rank":"D","nivel":2,"vidaMaxima":1,"ataque":1,"defesa":0},
		{"id":"especie_lobo","especieId":"especie_lobo","individuoId":"lobo-03","grupoId":"grupo-lobos","nome":"Lobo líder","rank":"C","nivel":3,"vidaMaxima":1,"ataque":1,"defesa":0}
	]
	criaturas[0]["vidaMaxima"] = 30
	criaturas[0]["vida"] = 17
	var estado := Combate.criar_estado_grupo(criaturas, [
		{"uid":"uid-grupo-a","nome":"Aventureiro A","vida":100,"vidaMaxima":100,"ataque":100,"defesa":100,"agilidade":100},
		{"uid":"uid-grupo-b","nome":"Aventureiro B","vida":100,"vidaMaxima":100,"ataque":100,"defesa":100,"agilidade":100}
	])
	if estado.is_empty() or estado.get("inimigos", []).size() != 3:
		return _falhar("O motor cooperativo não criou os três inimigos.")
	var ids := {}
	for inimigo in estado.get("inimigos", []):
		ids[str(inimigo.get("id", ""))] = true
	if not ids.has("lobo-01") or not ids.has("lobo-02") or not ids.has("lobo-03"):
		return _falhar("O encontro não preservou os IDs individuais dos três membros do grupo.")
	if int(estado.get("inimigos", [])[0].get("vida", 0)) != 17 or int(estado.get("inimigos", [])[0].get("vidaMaxima", 0)) != 30:
		return _falhar("O encontro não preservou a vida atual do indivíduo ferido no mundo.")
	var primeira := Combate.executar_acao(estado, "uid-grupo-a", Combate.ACAO_ATAQUE, 1001, "lobo-01")
	if not bool(primeira.get("ok", false)):
		return _falhar("O primeiro alvo não pôde ser atacado.")
	estado = primeira.get("estado", {})
	if str(estado.get("status", "")) != Combate.EM_ANDAMENTO:
		return _falhar("A batalha terminou após derrotar somente uma criatura.")
	if int(estado.get("inimigos", [])[0].get("vida", 1)) != 0:
		return _falhar("A vida da primeira criatura não foi atualizada.")
	if str(estado.get("alvoSelecionadoId", "")) == "lobo-01":
		return _falhar("O alvo selecionado não avançou para uma criatura viva.")
	var segunda := Combate.executar_acao(estado, "uid-grupo-b", Combate.ACAO_ATAQUE, 1002, "lobo-02")
	if not bool(segunda.get("ok", false)):
		return _falhar("O segundo alvo não pôde ser atacado.")
	estado = segunda.get("estado", {})
	if str(estado.get("status", "")) != Combate.EM_ANDAMENTO:
		return _falhar("A batalha terminou antes de derrotar a terceira criatura.")
	var terceira := Combate.executar_acao(estado, "uid-grupo-a", Combate.ACAO_ATAQUE, 1003, "lobo-03")
	if not bool(terceira.get("ok", false)):
		return _falhar("O terceiro alvo não pôde ser atacado.")
	estado = terceira.get("estado", {})
	if str(estado.get("status", "")) != Combate.VITORIA:
		return _falhar("A equipe não venceu após derrotar todos os três indivíduos.")
	for inimigo_final in estado.get("inimigos", []):
		if int(inimigo_final.get("vida", 1)) != 0:
			return _falhar("Uma criatura permaneceu viva após a vitória.")
	for participante_final in estado.get("participantes", []):
		if not bool(participante_final.get("elegivelRecompensas", false)):
			return _falhar("Um participante não recebeu elegibilidade após vitória do grupo.")
	return true


func _testar_morte_individual_em_grupo_de_criaturas() -> bool:
	var criaturas := [
		{"id":"especie_teste","individuoId":"individuo-a","grupoId":"grupo-teste","nome":"Predador A","vidaMaxima":1,"ataque":1,"defesa":0},
		{"id":"especie_teste","individuoId":"individuo-b","grupoId":"grupo-teste","nome":"Predador B","vidaMaxima":1,"ataque":1,"defesa":0},
		{"id":"especie_teste","individuoId":"individuo-c","grupoId":"grupo-teste","nome":"Predador C","vidaMaxima":1,"ataque":1,"defesa":0}
	]
	var estado := Combate.criar_estado_grupo(criaturas, [
		{"uid":"uid-grupo-morto","nome":"Aventureiro Derrotado","vida":1,"vidaMaxima":100,"ataque":100,"defesa":0},
		{"uid":"uid-grupo-vivo","nome":"Aventureiro Vivo","vida":100,"vidaMaxima":100,"ataque":100,"defesa":0}
	])
	if estado.is_empty():
		return _falhar("Não foi possível criar o grupo para testar morte individual.")
	var primeira := Combate.executar_acao(estado, "uid-grupo-morto", Combate.ACAO_DEFENDER, 2001)
	if not bool(primeira.get("ok", false)):
		return _falhar("O primeiro integrante não conseguiu agir no encontro com várias criaturas.")
	estado = primeira.get("estado", {})
	if str(estado.get("status", "")) != Combate.EM_ANDAMENTO:
		return _falhar("O grupo de criaturas encerrou o combate após derrotar apenas um integrante.")
	if int(estado.get("participantes", [])[0].get("vida", -1)) != 0:
		return _falhar("O integrante derrotado não permaneceu com zero HP durante o combate.")
	if int(estado.get("indiceTurno", -1)) != 1:
		return _falhar("O turno do grupo não passou para o único integrante ainda vivo.")
	for alvo in ["individuo-a", "individuo-b", "individuo-c"]:
		var ataque := Combate.executar_acao(estado, "uid-grupo-vivo", Combate.ACAO_ATAQUE, 2002, alvo)
		if not bool(ataque.get("ok", false)):
			return _falhar("O integrante vivo não conseguiu continuar a luta após a morte do aliado.")
		estado = ataque.get("estado", {})
		if alvo != "individuo-c" and str(estado.get("status", "")) != Combate.EM_ANDAMENTO:
			return _falhar("A luta terminou antes de todas as criaturas do grupo serem derrotadas.")
	if str(estado.get("status", "")) != Combate.VITORIA:
		return _falhar("O integrante vivo não conseguiu vencer o grupo após a morte do aliado.")
	var aliado_derrotado: Dictionary = estado.get("participantes", [])[0]
	if int(aliado_derrotado.get("vida", 0)) != 1 or not bool(aliado_derrotado.get("elegivelRecompensas", false)):
		return _falhar("O aliado derrotado no combate contra grupo não voltou com 1 HP e direito às recompensas.")
	return true

func _testar_derrota_coletiva_em_grupo_de_criaturas() -> bool:
	var criaturas := [
		{"id":"especie_teste","individuoId":"individuo-x","grupoId":"grupo-derrota","nome":"Predador X","vidaMaxima":1000,"ataque":1,"defesa":0},
		{"id":"especie_teste","individuoId":"individuo-y","grupoId":"grupo-derrota","nome":"Predador Y","vidaMaxima":1000,"ataque":1,"defesa":0},
		{"id":"especie_teste","individuoId":"individuo-z","grupoId":"grupo-derrota","nome":"Predador Z","vidaMaxima":1000,"ataque":1,"defesa":0}
	]
	var estado := Combate.criar_estado_grupo(criaturas, [
		{"uid":"uid-derrota-a","nome":"Aventureiro A","vida":1,"vidaMaxima":100,"ataque":1,"defesa":0},
		{"uid":"uid-derrota-b","nome":"Aventureiro B","vida":1,"vidaMaxima":100,"ataque":1,"defesa":0}
	])
	if estado.is_empty():
		return _falhar("Não foi possível criar o grupo para testar derrota coletiva.")
	var primeira := Combate.executar_acao(estado, "uid-derrota-a", Combate.ACAO_DEFENDER, 3001)
	if not bool(primeira.get("ok", false)):
		return _falhar("O primeiro integrante não conseguiu agir no teste de derrota coletiva.")
	estado = primeira.get("estado", {})
	if str(estado.get("status", "")) != Combate.EM_ANDAMENTO:
		return _falhar("O grupo foi derrotado antes de o segundo integrante receber seu turno.")
	var segunda := Combate.executar_acao(estado, "uid-derrota-b", Combate.ACAO_DEFENDER, 3002)
	if not bool(segunda.get("ok", false)):
		return _falhar("O segundo integrante não conseguiu agir no teste de derrota coletiva.")
	estado = segunda.get("estado", {})
	if str(estado.get("status", "")) != Combate.DERROTA:
		return _falhar("O encontro com várias criaturas não encerrou após todos os integrantes caírem.")
	if str(estado.get("retornoGrupo", "")) != "ponto_renascimento":
		return _falhar("A derrota coletiva do grupo não definiu o retorno ao ponto de renascimento.")
	for participante in estado.get("participantes", []):
		if bool(participante.get("elegivelRecompensas", false)):
			return _falhar("Um integrante derrotado na derrota coletiva recebeu recompensas indevidas.")
	return true

func _falhar(mensagem: String) -> bool:
	push_error(mensagem)
	printerr("FALHA: " + mensagem)
	quit(1)
	return false
