extends SceneTree

const Combate = preload("res://scripts/sistema_combate_cooperativo.gd")

func _initialize() -> void:
	_testar_vitoria_com_companheiro_derrotado()
	_testar_derrota_total_da_equipe()
	print("OK: morte individual não encerra combate, recompensa de XP e retorno com 1 HP; derrota total encerra a equipe.")
	quit(0)

func _testar_vitoria_com_companheiro_derrotado() -> void:
	var criatura := {
		"id": "ogro_teste",
		"nome": "Ogro de Teste",
		"vidaMaxima": 500,
		"ataque": 100,
		"defesa": 0
	}
	var equipe := [
		{"uid":"uid-caido","nome":"Aventureiro Caído","vida":10,"vidaMaxima":10,"ataque":1,"defesa":0},
		{"uid":"uid-vivo","nome":"Último de Pé","vida":10,"vidaMaxima":10,"ataque":1000,"defesa":0}
	]
	var estado := Combate.criar_estado(criatura, equipe)
	assert(not estado.is_empty(), "O encontro cooperativo deve ser criado.")

	var primeiro_turno := Combate.executar_acao(estado, "uid-caido", Combate.ACAO_ATAQUE, 701)
	assert(bool(primeiro_turno.get("ok", false)), "O primeiro integrante deve conseguir agir.")
	var apos_morte: Dictionary = primeiro_turno.estado
	assert(str(apos_morte.status) == Combate.EM_ANDAMENTO, "A morte de um integrante não pode encerrar a luta enquanto outro estiver vivo.")
	assert(int(apos_morte.participantes[0].vida) == 0, "O primeiro integrante deve estar derrotado.")
	assert(str(apos_morte.participantes[0].estadoCombate) == "derrotado", "O estado individual deve registrar a derrota.")
	assert(str(apos_morte.participantes[1].uid) == "uid-vivo", "O companheiro vivo deve receber o próximo turno.")

	var vitoria := Combate.executar_acao(apos_morte, "uid-vivo", Combate.ACAO_ATAQUE, 702)
	assert(bool(vitoria.get("ok", false)), "O companheiro vivo deve poder concluir o combate.")
	var final: Dictionary = vitoria.estado
	assert(str(final.status) == Combate.VITORIA, "A equipe deve vencer quando o último inimigo é derrotado.")
	assert(int(final.participantes[0].vida) == 1, "O integrante derrotado deve retornar com exatamente 1 HP.")
	assert(str(final.participantes[0].estadoCombate) == "retornando_com_1_hp", "O estado deve identificar o retorno com 1 HP.")
	assert(bool(final.participantes[0].elegivelRecompensas), "O integrante derrotado deve continuar elegível às recompensas.")

	var distribuicao := Combate.calcular_distribuicao_recompensas(final, 100)
	assert(distribuicao.size() == 2, "A distribuição deve incluir todos os participantes originais.")
	assert(int(distribuicao[0].experiencia) == 50 and int(distribuicao[1].experiencia) == 50, "O XP deve ser dividido igualmente, inclusive para quem caiu.")
	assert(not bool(distribuicao[0].receberDrops) and bool(distribuicao[1].receberDrops), "Os drops devem continuar destinados ao maior causador de dano.")

func _testar_derrota_total_da_equipe() -> void:
	var criatura := {
		"id": "colosso_teste",
		"nome": "Colosso de Teste",
		"vidaMaxima": 10000,
		"ataque": 1000,
		"defesa": 0
	}
	var equipe := [
		{"uid":"uid-total-a","nome":"Aventureiro A","vida":10,"vidaMaxima":10,"ataque":1,"defesa":0},
		{"uid":"uid-total-b","nome":"Aventureiro B","vida":10,"vidaMaxima":10,"ataque":1,"defesa":0}
	]
	var estado := Combate.criar_estado(criatura, equipe)
	assert(not estado.is_empty(), "O encontro para teste de derrota total deve ser criado.")
	var turno_a := Combate.executar_acao(estado, "uid-total-a", Combate.ACAO_ATAQUE, 801)
	assert(bool(turno_a.get("ok", false)), "O primeiro integrante deve concluir sua ação.")
	assert(str(turno_a.estado.status) == Combate.EM_ANDAMENTO, "A luta deve continuar após a primeira queda.")
	var turno_b := Combate.executar_acao(turno_a.estado, "uid-total-b", Combate.ACAO_ATAQUE, 802)
	assert(bool(turno_b.get("ok", false)), "O segundo integrante deve conseguir agir.")
	var final: Dictionary = turno_b.estado
	assert(str(final.status) == Combate.DERROTA, "A luta só deve terminar em derrota quando todos caírem.")
	assert(str(final.retornoGrupo) == "ponto_renascimento", "A derrota total deve encaminhar o grupo ao ponto de renascimento.")
	for membro in final.participantes:
		assert(int(membro.vida) == 0, "Ninguém deve receber retorno com 1 HP após derrota total.")
		assert(not bool(membro.elegivelRecompensas), "A equipe derrotada não deve receber recompensas de vitória.")
