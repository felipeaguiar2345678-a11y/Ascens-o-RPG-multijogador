extends SceneTree

const Combate = preload("res://scripts/sistema_combate_cooperativo.gd")

func _initialize() -> void:
	var criatura := {"id":"sentinela","nome":"Sentinela","rank":"C","nivel":12,"vidaMaxima":180,"ataque":8,"defesa":2}
	var equipe := [
		{"uid":"uid-a","nome":"Aventureiro","vida":100,"vidaMaxima":100,"ataque":20,"defesa":5,"agilidade":10},
		{"uid":"uid-b","nome":"Aliada","vida":90,"vidaMaxima":90,"ataque":18,"defesa":4,"agilidade":15}
	]
	var estado: Dictionary = Combate.criar_estado(criatura, equipe)
	if estado.is_empty() or str(estado.get("status", "")) != Combate.EM_ANDAMENTO:
		_falhar("O motor não criou um combate válido para uma equipe.")
		return
	var turno_errado: Dictionary = Combate.executar_acao(estado, "uid-b", Combate.ACAO_ATAQUE, 77)
	if bool(turno_errado.get("ok", false)):
		_falhar("O motor aceitou uma ação fora da ordem de turnos.")
		return
	var primeiro: Dictionary = Combate.executar_acao(estado, "uid-a", Combate.ACAO_ATAQUE, 1234)
	if not bool(primeiro.get("ok", false)):
		_falhar("O primeiro participante não conseguiu atacar.")
		return
	var atualizado: Dictionary = primeiro.get("estado", {})
	var membros: Array = atualizado.get("participantes", [])
	if str(membros[atualizado.get("indiceTurno", 0)].get("uid", "")) != "uid-b":
		_falhar("A ordem de turnos não avançou para a segunda pessoa.")
		return
	var defesa: Dictionary = Combate.executar_acao(atualizado, "uid-b", Combate.ACAO_DEFENDER, 9876)
	if not bool(defesa.get("ok", false)):
		_falhar("A ação de defesa não foi processada.")
		return
	var membro_defendido: Dictionary = defesa.get("estado", {}).get("participantes", [])[1]
	if int(membro_defendido.get("vida", 0)) >= 90:
		_falhar("A criatura não respondeu ao turno de defesa.")
		return
	var criatura_fraca := criatura.duplicate(true)
	criatura_fraca["vidaMaxima"] = 1
	var estado_vitoria: Dictionary = Combate.criar_estado(criatura_fraca, equipe)
	var vitoria: Dictionary = Combate.executar_acao(estado_vitoria, "uid-a", Combate.ACAO_ATAQUE, 5)
	if not bool(vitoria.get("ok", false)) or str(vitoria.get("estado", {}).get("status", "")) != Combate.VITORIA:
		_falhar("O motor não encerrou a batalha quando a criatura foi derrotada.")
		return
	# Um integrante pode cair e continuar elegível; o sobrevivente ainda conclui o combate.
	var criatura_quase_derrotada := criatura.duplicate(true)
	criatura_quase_derrotada["vidaMaxima"] = 2
	criatura_quase_derrotada["defesa"] = 5
	var equipe_com_um_derrotado := [
		{"uid":"uid-a","nome":"Aventureiro","vida":1,"vidaMaxima":100,"ataque":1,"defesa":0,"agilidade":0},
		{"uid":"uid-b","nome":"Aliada","vida":90,"vidaMaxima":90,"ataque":20,"defesa":0,"agilidade":0}
	]
	var combate_com_queda: Dictionary = Combate.criar_estado(criatura_quase_derrotada, equipe_com_um_derrotado)
	var queda_individual: Dictionary = Combate.executar_acao(combate_com_queda, "uid-a", Combate.ACAO_ATAQUE, 41)
	if not bool(queda_individual.get("ok", false)):
		_falhar("O primeiro integrante não conseguiu agir antes de ser derrotado.")
		return
	var estado_apos_queda: Dictionary = queda_individual.get("estado", {})
	if str(estado_apos_queda.get("status", "")) != Combate.EM_ANDAMENTO or int(estado_apos_queda.get("participantes", [])[0].get("vida", 1)) != 0:
		_falhar("A queda de apenas um integrante encerrou indevidamente o combate.")
		return
	var ataque_sobrevivente: Dictionary = Combate.executar_acao(estado_apos_queda, "uid-b", Combate.ACAO_ATAQUE, 42)
	if not bool(ataque_sobrevivente.get("ok", false)) or str(ataque_sobrevivente.get("estado", {}).get("status", "")) != Combate.VITORIA:
		_falhar("O sobrevivente não conseguiu concluir o combate após a queda do parceiro.")
		return
	var participantes_vitoria: Array = ataque_sobrevivente.get("estado", {}).get("participantes", [])
	if int(participantes_vitoria[0].get("vida", 0)) != 1 or not bool(participantes_vitoria[0].get("elegivelRecompensas", false)) or str(participantes_vitoria[0].get("estadoCombate", "")) != "retornando_com_1_hp":
		_falhar("O integrante derrotado não recebeu retorno com 1 HP e elegibilidade às recompensas.")
		return
	if not bool(participantes_vitoria[1].get("elegivelRecompensas", false)):
		_falhar("O sobrevivente não foi marcado como elegível às recompensas.")
		return
	var criatura_forte := criatura.duplicate(true)
	criatura_forte["ataque"] = 1000
	criatura_forte["vidaMaxima"] = 1000
	var equipe_fraca := [
		{"uid":"uid-a","nome":"Aventureiro","vida":1,"vidaMaxima":1,"ataque":1,"defesa":0,"agilidade":0},
		{"uid":"uid-b","nome":"Aliada","vida":1,"vidaMaxima":1,"ataque":1,"defesa":0,"agilidade":0}
	]
	var estado_derrota: Dictionary = Combate.criar_estado(criatura_forte, equipe_fraca)
	var derrota_primeira: Dictionary = Combate.executar_acao(estado_derrota, "uid-a", Combate.ACAO_DEFENDER, 11)
	if not bool(derrota_primeira.get("ok", false)):
		_falhar("O primeiro integrante não recebeu o ataque de resposta.")
		return
	var derrota: Dictionary = Combate.executar_acao(derrota_primeira.get("estado", {}), "uid-b", Combate.ACAO_DEFENDER, 12)
	if not bool(derrota.get("ok", false)) or str(derrota.get("estado", {}).get("status", "")) != Combate.DERROTA or str(derrota.get("estado", {}).get("retornoGrupo", "")) != "ponto_renascimento":
		_falhar("O motor não reconheceu a derrota total e o retorno ao ponto de renascimento.")
		return
	for participante_derrotado in derrota.get("estado", {}).get("participantes", []):
		if bool(participante_derrotado.get("elegivelRecompensas", true)):
			_falhar("A equipe derrotada recebeu elegibilidade indevida às recompensas.")
			return
	var equipe_invalida: Array = [equipe[0], equipe[0]]
	if not Combate.criar_estado(criatura, equipe_invalida).is_empty():
		_falhar("O motor aceitou UIDs duplicados na equipe.")
		return
	print("OK: combate cooperativo, turnos, defesa, vitória, derrota e validação.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error(mensagem)
	quit(1)
