extends SceneTree

const Combate = preload("res://scripts/sistema_combate_cooperativo.gd")

func _initialize() -> void:
	var criatura := {"id":"sentinela","nome":"Sentinela","rank":"C","nivel":12,"vidaMaxima":180,"ataque":8,"defesa":2}
	var equipe := [
		{"uid":"uid-a","nome":"Aventureiro","vida":100,"vidaMaxima":100,"ataque":20,"defesa":5,"agilidade":10,"sorte":27.5},
		{"uid":"uid-b","nome":"Aliada","vida":90,"vidaMaxima":90,"ataque":18,"defesa":4,"agilidade":15}
	]
	equipe[0]["armaOnePieceId"] = "gryphon"
	var estado: Dictionary = Combate.criar_estado(criatura, equipe)
	if estado.is_empty() or str(estado.get("status", "")) != Combate.EM_ANDAMENTO:
		_falhar("O motor não criou um combate válido para uma equipe.")
		return
	if not is_equal_approx(float(estado.get("participantes", [])[0].get("sorte", -1.0)), 27.5):
		_falhar("O combate não preservou a sorte original para a rolagem de recompensas.")
		return
	var equipe_com_classe: Array = [
		{"uid":"uid-classe","nome":"Invocador","vida":100,"vidaMaxima":100,"ataque":20,"defesa":5,"agilidade":10,"classeId":"invocador"},
		{"uid":"uid-classe-b","nome":"Aliada","vida":90,"vidaMaxima":90,"ataque":18,"defesa":4,"agilidade":15,"classeId":"guerreiro"}
	]
	var estado_classes: Dictionary = Combate.criar_estado(criatura, equipe_com_classe)
	if str(estado_classes.get("participantes", [])[0].get("classeId", "")) != "invocador" or str(estado_classes.get("participantes", [])[1].get("classeId", "")) != "guerreiro":
		_falhar("O combate não preservou a classe original dos participantes para resolver recompensas após reconexão.")
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
	if str(atualizado.get("efeitoAtaqueArma", {}).get("efeito", "")) != "haki_do_rei":
		_falhar("O ataque cooperativo não publicou o efeito Haki da Gryphon.")
		return
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
	if str(vitoria.get("estado", {}).get("retornoGrupo", "")) != "aventura_compartilhada":
		_falhar("A vitória cooperativa não retornou ao palco compartilhado.")
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
	var queda_desconectada: Dictionary = Combate.marcar_desconectado(estado_apos_queda, "uid-a")
	var queda_reconectada: Dictionary = Combate.marcar_reconectado(queda_desconectada, "uid-a")
	if not bool(queda_reconectada.get("participantes", [])[0].get("conectado", false)) or int(queda_reconectada.get("indiceTurno", -1)) != 1:
		_falhar("Um integrante derrotado não conseguiu reconectar sem roubar o turno do sobrevivente.")
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
	if str(ataque_sobrevivente.get("estado", {}).get("uidMaiorDano", "")) != "uid-b" or int(participantes_vitoria[1].get("danoCausado", 0)) <= int(participantes_vitoria[0].get("danoCausado", 0)):
		_falhar("O motor não preservou a contribuição individual de dano para a distribuição futura de recompensas.")
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
	var estado_desconexao: Dictionary = Combate.criar_estado(criatura, equipe)
	var desconectado: Dictionary = Combate.marcar_desconectado(estado_desconexao, "uid-a")
	if int(desconectado.get("indiceTurno", -1)) != 1 or bool(desconectado.get("participantes", [])[0].get("conectado", true)):
		_falhar("A desconexão do jogador da vez não avançou o turno para o integrante conectado.")
		return
	var reconectado: Dictionary = Combate.marcar_reconectado(desconectado, "uid-a")
	if not bool(reconectado.get("participantes", [])[0].get("conectado", false)):
		_falhar("O integrante não foi reativado ao retornar.")
		return
	var equipe_aguardando := [
		{"uid":"uid-a","nome":"Desconectado","vida":100,"vidaMaxima":100,"ataque":10,"defesa":0,"agilidade":0},
		{"uid":"uid-b","nome":"Último ativo","vida":1,"vidaMaxima":1,"ataque":10,"defesa":0,"agilidade":0}
	]
	var criatura_aguardando := {"id":"guardiao","nome":"Guardião","rank":"E","nivel":1,"vidaMaxima":1000,"ataque":100,"defesa":0}
	var estado_aguardando: Dictionary = Combate.criar_estado(criatura_aguardando, equipe_aguardando)
	estado_aguardando = Combate.marcar_desconectado(estado_aguardando, "uid-a")
	var turno_final: Dictionary = Combate.executar_acao(estado_aguardando, "uid-b", "ataque", 76543)
	if not bool(turno_final.get("ok", false)) or str(turno_final.get("estado", {}).get("status", "")) != Combate.EM_ANDAMENTO or int(turno_final.get("estado", {}).get("indiceTurno", 0)) != -1:
		_falhar("O combate declarou derrota ou travou incorretamente quando só restavam aliados vivos desconectados.")
		return
	var retomada_final: Dictionary = Combate.marcar_reconectado(turno_final.get("estado", {}), "uid-a")
	if int(retomada_final.get("indiceTurno", -1)) != 0 or bool(retomada_final.get("aguardandoReconexao", true)):
		_falhar("O combate não retomou o turno quando um aliado vivo reconectou.")
		return
	print("OK: combate cooperativo, turnos, defesa, vitória, derrota, desconexão, espera e reconexão.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error(mensagem)
	quit(1)
