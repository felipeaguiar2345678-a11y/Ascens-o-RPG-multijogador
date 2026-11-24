extends SceneTree

const Servico = preload("res://scripts/servico_missoes_mundo_servidor.gd")

class RepositorioMemoria:
	extends RefCounted
	var perfil: Dictionary = {
		"uid": "jogador_teste",
		"personagemCriado": true,
		"missoes": {},
		"missoesConcluidas": {},
		"moedas": {"bronze": 0}
	}
	var pagamentos := 0

	func carregar_ou_criar(_uid: String) -> Dictionary:
		return perfil.duplicate(true)

	func salvar_missoes(_uid: String, missoes: Dictionary) -> Dictionary:
		perfil["missoes"] = missoes.duplicate(true)
		return {"ok": true, "perfil": perfil.duplicate(true)}

	func concluir_missao(_uid: String, missao_id: String, dificuldade: String) -> Dictionary:
		if not perfil["missoes"].has(missao_id):
			return {"ok": false, "erro": "Missão ausente."}
		var registro: Dictionary = perfil["missoes"][missao_id]
		if str(registro.get("status", "")) != "objetivos_concluidos" or str(registro.get("dificuldade", "")) != dificuldade:
			return {"ok": false, "erro": "Missão ainda não concluída."}
		if perfil["missoesConcluidas"].has(missao_id):
			return {"ok": false, "duplicada": true}
		pagamentos += 1
		registro["status"] = "recompensada"
		registro["recompensadaEmUnix"] = 1
		perfil["missoes"][missao_id] = registro
		perfil["missoesConcluidas"][missao_id] = {"status": "recompensada"}
		return {"ok": true, "missaoId": missao_id}

func _initialize() -> void:
	var repositorio := RepositorioMemoria.new()
	var servico := Servico.new(repositorio)
	var oferta := {
		"id": "rastros_integracao",
		"npcId": "iren_viajante",
		"titulo": "Rastros na trilha",
		"descricao": "Investigue os rastros próximos à estrada.",
		"dificuldade": "media",
		"objetivos": [
			{"id": "rastros", "tipo": "visitar_local", "alvoId": "trilha_sul", "quantidade": 2}
		]
	}
	if not bool(servico.registrar_oferta(oferta).get("ok", false)):
		_falhar("A oferta válida não foi registrada."); return
	if servico.listar_ofertas("jogador_teste", "iren_viajante").size() != 1:
		_falhar("A oferta não foi consultada pelo personagem."); return
	if not bool(servico.aceitar("jogador_teste", "rastros_integracao").get("ok", false)):
		_falhar("A aceitação não foi persistida."); return
	if str(repositorio.perfil["missoes"]["rastros_integracao"]["status"]) != "em_andamento":
		_falhar("O perfil não recebeu o estado ativo."); return
	var ativas_iren := servico.listar_missoes_do_npc("jogador_teste", "iren_viajante")
	if ativas_iren.size() != 1 or str(ativas_iren[0].get("id", "")) != "rastros_integracao":
		_falhar("A missão aceita não apareceu na consulta de progresso do NPC."); return
	if servico.missao_vinculada_ao_npc("jogador_teste", "outro_npc", "rastros_integracao", "abandonar"):
		_falhar("Uma missão foi considerada vinculada ao NPC incorreto."); return
	var evento_errado := servico.registrar_evento_confirmado("jogador_teste", "visitar_local", "outro_local", 1)
	if not bool(evento_errado.get("ok", false)) or int(repositorio.perfil["missoes"]["rastros_integracao"]["progresso"]["rastros"]) != 0:
		_falhar("Um evento de alvo diferente alterou o progresso."); return
	var evento_1 := servico.registrar_evento_confirmado("jogador_teste", "visitar_local", "trilha_sul", 1)
	var evento_2 := servico.registrar_evento_confirmado("jogador_teste", "visitar_local", "trilha_sul", 1)
	if not bool(evento_1.get("ok", false)) or not bool(evento_2.get("ok", false)):
		_falhar("Eventos confirmados não foram persistidos."); return
	if str(repositorio.perfil["missoes"]["rastros_integracao"]["status"]) != "objetivos_concluidos":
		_falhar("O progresso não concluiu o objetivo."); return
	var pagamento := servico.concluir_e_pagar("jogador_teste", "rastros_integracao")
	if not bool(pagamento.get("ok", false)) or repositorio.pagamentos != 1:
		_falhar("A conclusão não delegou o pagamento ao repositório."); return
	var repetido := servico.concluir_e_pagar("jogador_teste", "rastros_integracao")
	if bool(repetido.get("ok", false)) or repositorio.pagamentos != 1:
		_falhar("Uma segunda conclusão repetiu o pagamento."); return
	print("TESTE DO SERVIÇO DE MISSÕES: consulta, persistência, eventos confirmados e pagamento único aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DO SERVIÇO DE MISSÕES: " + mensagem)
	quit(1)
