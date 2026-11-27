extends SceneTree

const RedeMultiplayer = preload("res://scripts/rede_multiplayer.gd")

func _initialize() -> void:
	var rede = RedeMultiplayer.new()
	rede._ally_ativa = {
		"ALLY_TESTE": {
			"id": "ALLY_TESTE",
			"liderUid": "uid_privado_lider_123",
			"membros": ["uid_privado_lider_123", "uid_privado_membro_456"]
		}
	}
	rede._uid_por_peer = {
		2: "uid_privado_lider_123",
		3: "uid_privado_membro_456"
	}
	rede._perfil_por_peer = {
		2: {"nome": "Líder"},
		3: {"nome": "Companheiro"}
	}

	var snapshot: Dictionary = rede._criar_snapshot_publico_ally("ALLY_TESTE")
	if snapshot.is_empty():
		_falhar("O snapshot público da Ally deveria ser criado.")
		return
	if snapshot.has("liderUid") or JSON.stringify(snapshot).contains("uid_privado"):
		_falhar("O snapshot público não pode expor UIDs internos das contas.")
		return
	var membros: Array = snapshot.get("membros", [])
	if membros.size() != 2:
		_falhar("O snapshot deve incluir os dois membros conectados.")
		return
	if not bool(membros[0].get("lider", false)) or bool(membros[1].get("lider", true)):
		_falhar("A indicação pública de liderança está incorreta.")
		return
	if str(membros[0].get("nome", "")) != "Líder" or int(membros[1].get("peerId", 0)) != 3:
		_falhar("O snapshot perdeu nome ou peer conectado.")
		return

	rede.queue_free()
	print("TESTE MULTIPLAYER: snapshot público de Ally sem UIDs privados aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE MULTIPLAYER: " + mensagem)
	quit(1)
