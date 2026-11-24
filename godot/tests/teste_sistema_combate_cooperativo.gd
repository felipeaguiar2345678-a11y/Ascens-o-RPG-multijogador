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
	var criatura_forte := criatura.duplicate(true)
	criatura_forte["ataque"] = 1000
	criatura_forte["vidaMaxima"] = 1000
	var equipe_fraca := [
		{"uid":"uid-a","nome":"Aventureiro","vida":1,"vidaMaxima":1,"ataque":1,"defesa":0,"agilidade":0},
		{"uid":"uid-b","nome":"Aliada","vida":1,"vidaMaxima":1,"ataque":1,"defesa":0,"agilidade":0}
	]
	var estado_derrota: Dictionary = Combate.criar_estado(criatura_forte, equipe_fraca)
	var derrota: Dictionary = Combate.executar_acao(estado_derrota, "uid-a", Combate.ACAO_DEFENDER, 11)
	if not bool(derrota.get("ok", false)) or str(derrota.get("estado", {}).get("status", "")) != Combate.DERROTA:
		_falhar("O motor não reconheceu a derrota de toda a equipe.")
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
