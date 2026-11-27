extends SceneTree

const Combate = preload("res://scripts/sistema_combate.gd")

func _initialize() -> void:
	var perfil := {"personagemCriado":true,"nome":"Aventureiro","vida":100,"vidaMaxima":100,"mana":50,"manaMaxima":50,"forca":20,"inteligencia":15,"agilidade":10,"vitalidade":10,"espirito":10,"equipamentos":{}}
	var criaturas := [
		{"id":"lobo_a","nome":"Lobo Alfa","vidaMaxima":8,"ataque":1,"defesa":0,"agilidade":0,"experienciaBase":5},
		{"id":"lobo_b","nome":"Lobo Jovem","vidaMaxima":8,"ataque":1,"defesa":0,"agilidade":0,"experienciaBase":5},
		{"id":"lobo_c","nome":"Lobo Vigia","vidaMaxima":8,"ataque":1,"defesa":0,"agilidade":0,"experienciaBase":5}
	]
	var estado := Combate.criar_estado_grupo(perfil, criaturas, {"periodo":"dia"})
	if estado.is_empty() or estado.get("inimigos", []).size() != 3:
		_falhar("Não criou uma batalha com três inimigos.")
		return
	var resultado := Combate.executar_rodada(estado, Combate.ACAO_ATAQUE, 12)
	if not bool(resultado.get("ok", false)):
		_falhar("Não executou rodada contra grupo.")
		return
	if resultado["estado"].get("inimigos", []).size() != 3:
		_falhar("A batalha perdeu integrantes do grupo após a rodada.")
		return
	var perfil_forte := perfil.duplicate(true)
	perfil_forte["forca"] = 10000
	var criaturas_alvo := criaturas.duplicate(true)
	for indice in range(criaturas_alvo.size()):
		criaturas_alvo[indice]["individuoId"] = "individuo_%d" % indice
	var estado_alvos := Combate.criar_estado_grupo(perfil_forte, criaturas_alvo, {"periodo":"dia"})
	var alvo_escolhido := Combate.executar_rodada(estado_alvos, Combate.ACAO_ATAQUE, 123, "individuo_1")
	if not bool(alvo_escolhido.get("ok", false)):
		_falhar("Não permitiu atacar o segundo inimigo selecionado.")
		return
	var estado_alvo: Dictionary = alvo_escolhido["estado"]
	if int(estado_alvo["inimigos"][0]["vida"]) != int(estado_alvos["inimigos"][0]["vida"]):
		_falhar("O ataque atingiu o primeiro inimigo em vez do alvo selecionado.")
		return
	if str(estado_alvo.get("alvoSelecionadoId", "")) == "individuo_1":
		_falhar("Não trocou o alvo após derrotar o inimigo selecionado.")
		return
	var alvo_invalido := Combate.executar_rodada(estado_alvos, Combate.ACAO_ATAQUE, 123, "alvo_inexistente")
	if bool(alvo_invalido.get("ok", false)):
		_falhar("Aceitou um alvo que não pertence ao combate.")
		return
	var dois := Combate.criar_estado_grupo(perfil, criaturas.slice(0, 2), {"periodo":"dia"})
	if dois.is_empty() or dois.get("inimigos", []).size() != 2:
		_falhar("Não criou batalha com dois inimigos.")
		return
	if not Combate.criar_estado_grupo(perfil, criaturas + [criaturas[0]], {}).is_empty():
		_falhar("Aceitou mais de três inimigos.")
		return
	print("TESTE DE COMBATE EM GRUPO: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE COMBATE EM GRUPO: " + mensagem)
	quit(1)
