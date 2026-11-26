extends SceneTree

const Salas = preload("res://scripts/sistema_salas_multiplayer.gd")

func _initialize() -> void:
	var sistema = Salas.new()
	if not sistema.criar_sala(10, "uid-a", "PUB234").get("sucesso", false):
		_falhar("Não foi possível criar a sala de teste.")
		return
	if not sistema.entrar_sala(11, "uid-b", "PUB234").get("sucesso", false):
		_falhar("O segundo jogador não entrou na sala.")
		return
	if not sistema.entrar_sala(12, "uid-observador", "PUB234").get("sucesso", false):
		_falhar("O terceiro membro não entrou na sala.")
		return
	var criatura := {"id":"alvo-publico","nome":"Guardião Público","rank":"E","nivel":1,"vidaMaxima":100000,"ataque":1,"experienciaBase":10}
	var participantes := [
		{"uid":"uid-a","nome":"Aventureiro A","vida":100,"vidaMaxima":100,"ataque":10,"defesa":2,"agilidade":10},
		{"uid":"uid-b","nome":"Aventureiro B","vida":100,"vidaMaxima":100,"ataque":10,"defesa":2,"agilidade":8}
	]
	var encontro: Dictionary = sistema.registrar_encontro(10, criatura, participantes)
	if not bool(encontro.get("sucesso", false)):
		_falhar("Não foi possível iniciar o combate de teste.")
		return
	var acao: Dictionary = sistema.executar_acao_encontro(10, "uid-a", "ataque", 12345)
	if not bool(acao.get("sucesso", false)):
		_falhar("O primeiro jogador não conseguiu executar a ação de teste.")
		return
	# Simula metadados privados produzidos pelo motor durante o combate.
	var estado_privado: Dictionary = sistema.obter_estado_aventura(10).get("estado", {}).duplicate(true)
	var encontro_privado: Dictionary = estado_privado.get("encontro", {}).duplicate(true)
	var combate_privado: Dictionary = encontro_privado.get("combate", {}).duplicate(true)
	combate_privado["supremaParticipanteUid"] = "uid-a"
	combate_privado["maestriaArmasAtualizada"] = {"uid-a":{"espada":{"nivel":7}}}
	combate_privado["uidMaiorDano"] = "uid-a"
	encontro_privado["combate"] = combate_privado
	estado_privado["encontro"] = encontro_privado
	if not bool(sistema.atualizar_estado_aventura(10, estado_privado).get("sucesso", false)):
		_falhar("Não foi possível preparar os metadados privados do combate.")
		return
	var snapshot_a: Dictionary = sistema.obter_snapshot_publico(10)
	var snapshot_b: Dictionary = sistema.obter_snapshot_publico(11)
	var snapshot_observador: Dictionary = sistema.obter_snapshot_publico(12)
	if not bool(snapshot_a.get("participanteDoCombate", false)) or not bool(snapshot_b.get("participanteDoCombate", false)):
		_falhar("Os participantes originais não foram identificados corretamente no snapshot.")
		return
	if bool(snapshot_observador.get("participanteDoCombate", true)):
		_falhar("Um membro que não entrou no combate foi marcado como participante.")
		return
	var combate_a: Dictionary = snapshot_a.get("estado", {}).get("encontro", {}).get("combate", {})
	var combate_b: Dictionary = snapshot_b.get("estado", {}).get("encontro", {}).get("combate", {})
	var combate_observador: Dictionary = snapshot_observador.get("estado", {}).get("encontro", {}).get("combate", {})
	if combate_observador.is_empty() or bool(combate_observador.get("turnoDoCliente", true)):
		_falhar("O observador da sala não recebeu a visão compartilhada sem autorização de turno.")
		return
	if combate_observador.get("inimigos", []) != combate_a.get("inimigos", []) or int(combate_observador.get("indiceTurno", -1)) != int(combate_a.get("indiceTurno", -2)):
		_falhar("O observador recebeu uma versão divergente da vida dos inimigos ou da ordem de turno.")
		return
	if bool(combate_a.get("turnoDoCliente", true)) or not bool(combate_b.get("turnoDoCliente", false)):
		_falhar("O snapshot não diferenciou o turno ativo de cada cliente.")
		return
	for combate_publico in [combate_a, combate_b]:
		if combate_publico.has("uidMaiorDano") or combate_publico.has("supremaParticipanteUid") or combate_publico.has("maestriaArmasAtualizada"):
			_falhar("Um UID ou dicionário interno do servidor vazou para o snapshot público.")
			return
	var combate_interno: Dictionary = sistema.obter_estado_aventura(10).get("estado", {}).get("encontro", {}).get("combate", {})
	if str(combate_interno.get("supremaParticipanteUid", "")) != "uid-a" or not combate_interno.has("maestriaArmasAtualizada") or str(combate_interno.get("uidMaiorDano", "")) != "uid-a":
		_falhar("A filtragem pública alterou os dados internos necessários ao servidor.")
		return
	var snapshot_mutavel: Dictionary = snapshot_a.duplicate(true)
	var participantes_mutaveis: Array = snapshot_mutavel.get("estado", {}).get("encontro", {}).get("combate", {}).get("participantes", [])
	participantes_mutaveis[0]["nome"] = "Nome adulterado no cliente"
	if str(sistema.obter_snapshot_publico(11).get("estado", {}).get("encontro", {}).get("combate", {}).get("participantes", [])[0].get("nome", "")) == "Nome adulterado no cliente":
		_falhar("A cópia pública de um cliente alterou os dados vistos por outro.")
		return
	for snapshot in [snapshot_a, snapshot_b, snapshot_observador]:
		var participantes_publicos: Array = snapshot.get("estado", {}).get("encontro", {}).get("combate", {}).get("participantes", [])
		for participante in participantes_publicos:
			if participante.has("uid"):
				_falhar("Um UID interno foi exposto na lista pública de participantes.")
				return
	if str(snapshot_a.get("mundoId", "")) != Salas.ID_MUNDO_COMPARTILHADO or str(snapshot_b.get("mundoId", "")) != Salas.ID_MUNDO_COMPARTILHADO:
		_falhar("O snapshot público perdeu a identidade do mundo compartilhado.")
		return
	# A desconexão do jogador cujo turno está ativo deve pular para um aliado conectado.
	var saida_jogador_ativo: Dictionary = sistema.remover_jogador(11)
	if not bool(saida_jogador_ativo.get("removido", false)):
		_falhar("Não foi possível simular a desconexão do jogador no turno ativo.")
		return
	var snapshot_apos_saida: Dictionary = sistema.obter_snapshot_publico(10)
	var combate_apos_saida: Dictionary = snapshot_apos_saida.get("estado", {}).get("encontro", {}).get("combate", {})
	if int(combate_apos_saida.get("indiceTurno", -1)) != 0 or not bool(combate_apos_saida.get("turnoDoCliente", false)):
		_falhar("A desconexão do jogador ativo não transferiu o turno para o aliado conectado.")
		return
	var retorno_jogador_ativo: Dictionary = sistema.entrar_sala(14, "uid-b", "PUB234")
	if not bool(retorno_jogador_ativo.get("sucesso", false)):
		_falhar("O participante original não conseguiu reconectar à batalha.")
		return
	var snapshot_jogador_reconectado: Dictionary = sistema.obter_snapshot_publico(14)
	var combate_jogador_reconectado: Dictionary = snapshot_jogador_reconectado.get("estado", {}).get("encontro", {}).get("combate", {})
	if not bool(snapshot_jogador_reconectado.get("participanteDoCombate", false)) or bool(combate_jogador_reconectado.get("turnoDoCliente", true)):
		_falhar("O participante reconectado não recuperou sua identidade ou tomou indevidamente o turno atual.")
		return
	var acao_fora_de_turno: Dictionary = sistema.executar_acao_encontro(14, "uid-b", "ataque", 24680)
	if bool(acao_fora_de_turno.get("sucesso", false)):
		_falhar("O participante reconectado agiu antes de sua vez.")
		return
	# Um observador que cai deve conseguir voltar à mesma sala durante o combate.
	var saida_observador: Dictionary = sistema.remover_jogador(12)
	if not bool(saida_observador.get("removido", false)):
		_falhar("Não foi possível simular a desconexão do observador.")
		return
	var retorno_observador: Dictionary = sistema.entrar_sala(13, "uid-observador", "PUB234")
	if not bool(retorno_observador.get("sucesso", false)):
		_falhar("Um observador membro da sala não conseguiu reconectar durante o combate.")
		return
	var snapshot_reconectado: Dictionary = sistema.obter_snapshot_publico(13)
	var combate_reconectado: Dictionary = snapshot_reconectado.get("estado", {}).get("encontro", {}).get("combate", {})
	if bool(snapshot_reconectado.get("participanteDoCombate", true)) or bool(combate_reconectado.get("turnoDoCliente", true)):
		_falhar("O observador reconectado recebeu indevidamente permissão de combate.")
		return
	var snapshot_atual_servidor: Dictionary = sistema.obter_snapshot_publico(10)
	var combate_atual_servidor: Dictionary = snapshot_atual_servidor.get("estado", {}).get("encontro", {}).get("combate", {})
	if combate_reconectado.get("inimigos", []) != combate_atual_servidor.get("inimigos", []) or int(combate_reconectado.get("indiceTurno", -1)) != int(combate_atual_servidor.get("indiceTurno", -2)):
		_falhar("O observador reconectado não recuperou o estado compartilhado atual.")
		return
	var acao_observador: Dictionary = sistema.executar_acao_encontro(13, "uid-observador", "ataque", 67890)
	if bool(acao_observador.get("sucesso", false)):
		_falhar("O observador reconectado conseguiu agir no combate sem ter entrado nele.")
		return
	print("OK: snapshots públicos isolam identidades, metadados internos, observadores e reconexão segura dos participantes com turno preservado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error(mensagem)
	quit(1)
