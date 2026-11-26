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
	print("OK: snapshots públicos isolam identidades, metadados internos, participação e turno por cliente.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error(mensagem)
	quit(1)
