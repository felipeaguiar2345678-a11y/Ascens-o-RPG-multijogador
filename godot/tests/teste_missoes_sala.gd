extends SceneTree
const Missoes = preload("res://scripts/sistema_missoes_sala.gd")
func _initialize() -> void:
	var sistema = Missoes.new()
	var definicao := {"id":"prova_floresta_01","titulo":"Prova da Floresta","dificuldade":"media","objetivos":[{"id":"lobos","tipo":"derrotar_criatura","alvoId":"lobo_arcano","quantidade":2},{"id":"ervas","tipo":"coletar_recurso","alvoId":"erva_lunar","quantidade":3}]}
	if not bool(sistema.registrar_definicao(definicao).get("ok", false)):
		_falhar("Definição válida rejeitada."); return
	var inicio: Dictionary = sistema.iniciar_missao({}, "prova_floresta_01")
	if not bool(inicio.get("ok", false)):
		_falhar("Falha ao iniciar."); return
	var estado: Dictionary = inicio["estado"]
	if bool(sistema.preparar_conclusao(estado, "prova_floresta_01").get("ok", false)):
		_falhar("Missão concluída sem objetivos."); return
	estado = sistema.registrar_evento_autoritativo(estado, "derrotar_criatura", "lobo_sombrio", 10)["estado"]
	if int(estado["missoes"]["prova_floresta_01"]["progresso"]["lobos"]) != 0:
		_falhar("Alvo diferente avançou objetivo."); return
	estado = sistema.registrar_evento_autoritativo(estado, "derrotar_criatura", "lobo_arcano", 5)["estado"]
	if int(estado["missoes"]["prova_floresta_01"]["progresso"]["lobos"]) != 2:
		_falhar("Progresso excedeu limite."); return
	estado = sistema.registrar_evento_autoritativo(estado, "coletar_recurso", "erva_lunar", 3)["estado"]
	var pronto: Dictionary = sistema.preparar_conclusao(estado, "prova_floresta_01")
	if not bool(pronto.get("ok", false)) or str(pronto.get("dificuldade", "")) != "media":
		_falhar("Objetivos completos não liberaram conclusão."); return
	estado = sistema.marcar_recompensada(estado, "prova_floresta_01")["estado"]
	if str(estado["missoes"]["prova_floresta_01"]["status"]) != "recompensada":
		_falhar("Recompensa não marcada."); return
	if bool(sistema.preparar_conclusao(estado, "prova_floresta_01").get("ok", false)):
		_falhar("Missão recompensada pôde ser concluída de novo."); return
	if bool(sistema.iniciar_missao(estado, "prova_floresta_01").get("ok", false)):
		_falhar("Missão pôde ser iniciada duas vezes."); return
	print("TESTE DE MISSÕES: objetivos, alvos, limites, conclusão e recompensa única aprovados.")
	quit(0)
func _falhar(mensagem: String) -> void:
	push_error("TESTE DE MISSÕES: " + mensagem)
	quit(1)
