extends SceneTree

const MissoesMundo = preload("res://scripts/sistema_missoes_mundo.gd")

func _initialize() -> void:
	var sistema = MissoesMundo.new()
	var oferta := {
		"id": "rastros_na_trilha_ci",
		"npcId": "iren_viajante",
		"titulo": "Rastros na trilha",
		"descricao": "Investigue os rastros encontrados perto da estrada.",
		"dificuldade": "media",
		"objetivos": [
			{"id": "rastros", "tipo": "visitar_local", "alvoId": "trilha_sul", "quantidade": 1}
		]
	}
	if not bool(sistema.registrar_oferta(oferta).get("ok", false)):
		_falhar("Uma oferta válida de NPC foi rejeitada."); return

	var estado: Dictionary = {}
	var disponiveis: Array = sistema.listar_ofertas("iren_viajante", estado)
	if disponiveis.size() != 1 or str(disponiveis[0].get("id", "")) != "rastros_na_trilha_ci":
		_falhar("A oferta não apareceu ao conversar com o NPC correto."); return
	if not sistema.listar_ofertas("outro_npc", estado).is_empty():
		_falhar("A missão apareceu vinculada ao NPC errado."); return
	if not estado.is_empty():
		_falhar("Apenas consultar ofertas alterou o estado do jogador."); return

	var recusada: Dictionary = sistema.recusar_oferta(estado, "rastros_na_trilha_ci")
	if not bool(recusada.get("ok", false)):
		_falhar("O jogador não conseguiu recusar a oferta."); return
	estado = recusada["estado"]
	if sistema.listar_ofertas("iren_viajante", estado).size() != 1:
		_falhar("Uma recusa deveria permitir voltar e aceitar depois."); return

	var aceita: Dictionary = sistema.aceitar_missao(estado, "rastros_na_trilha_ci")
	if not bool(aceita.get("ok", false)):
		_falhar("O jogador não conseguiu aceitar a missão depois."); return
	estado = aceita["estado"]
	if str(estado["missoes"]["rastros_na_trilha_ci"]["status"]) != "em_andamento":
		_falhar("A missão não foi registrada como ativa."); return
	if not sistema.listar_ofertas("iren_viajante", estado).is_empty():
		_falhar("Uma missão ativa continuou aparecendo como oferta nova."); return

	var evento_errado: Dictionary = sistema.registrar_evento_autoritativo(estado, "visitar_local", "outra_trilha", 1)
	estado = evento_errado["estado"]
	if str(estado["missoes"]["rastros_na_trilha_ci"]["status"]) != "em_andamento":
		_falhar("Um local diferente avançou o objetivo."); return

	var abandono: Dictionary = sistema.abandonar_missao(estado, "rastros_na_trilha_ci")
	if not bool(abandono.get("ok", false)):
		_falhar("Não foi possível abandonar a missão."); return
	estado = abandono["estado"]
	if str(estado["missoes"]["rastros_na_trilha_ci"]["status"]) != "abandonada":
		_falhar("O abandono não foi registrado."); return

	var reaceita: Dictionary = sistema.aceitar_missao(estado, "rastros_na_trilha_ci")
	if not bool(reaceita.get("ok", false)):
		_falhar("O jogador não conseguiu reaceitar a missão abandonada."); return
	estado = reaceita["estado"]
	var evento: Dictionary = sistema.registrar_evento_autoritativo(estado, "visitar_local", "trilha_sul", 1)
	if not bool(evento.get("ok", false)):
		_falhar("O evento validado não foi processado."); return
	estado = evento["estado"]
	if str(estado["missoes"]["rastros_na_trilha_ci"]["status"]) != "objetivos_concluidos":
		_falhar("O objetivo correto não concluiu a missão."); return

	if not bool(sistema.preparar_conclusao(estado, "rastros_na_trilha_ci").get("ok", false)):
		_falhar("A missão com objetivo completo não ficou pronta para conclusão."); return
	var pagamento: Dictionary = sistema.marcar_recompensada(estado, "rastros_na_trilha_ci")
	if not bool(pagamento.get("ok", false)):
		_falhar("Não foi possível marcar a missão recompensada."); return
	estado = pagamento["estado"]
	if not estado.get("missoesConcluidas", {}).has("rastros_na_trilha_ci"):
		_falhar("A conclusão não foi registrada no histórico."); return
	if bool(sistema.aceitar_missao(estado, "rastros_na_trilha_ci").get("ok", false)):
		_falhar("Uma missão concluída pôde ser aceita novamente."); return

	print("TESTE DE MISSÕES DO MUNDO: oferta opcional, recusa, aceitação, abandono, reaceitação e conclusão aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE MISSÕES DO MUNDO: " + mensagem)
	quit(1)
