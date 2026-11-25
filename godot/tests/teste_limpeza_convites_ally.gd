extends SceneTree

const RedeMultiplayer = preload("res://scripts/rede_multiplayer.gd")

func _initialize() -> void:
	var rede = RedeMultiplayer.new()
	rede._convites_ally = {
		"expirado": {"peerOrigem": 2, "peerAlvo": 3, "expiraEm": 99, "uidOrigem": "uid2", "uidAlvo": "uid3"},
		"no_limite": {"peerOrigem": 4, "peerAlvo": 5, "expiraEm": 100, "uidOrigem": "uid4", "uidAlvo": "uid5"},
		"ativo": {"peerOrigem": 6, "peerAlvo": 7, "expiraEm": 101, "uidOrigem": "uid6", "uidAlvo": "uid7"}
	}
	rede._limpar_convites_ally_expirados(100)
	if rede._convites_ally.has("expirado") or rede._convites_ally.has("no_limite"):
		_falhar("Convites Ally vencidos, inclusive no instante limite, precisam ser removidos.")
		return
	if not rede._convites_ally.has("ativo") or rede._convites_ally.size() != 1:
		_falhar("A limpeza removeu um convite Ally ainda válido.")
		return

	# A rotina de cancelamento por desconexão deve preservar os outros convites.
	var convite_terceiros: Dictionary = {"peerOrigem": 8, "peerAlvo": 9}
	rede._notificar_cancelamento_convite_ally(convite_terceiros, 10)
	if rede._convites_ally.size() != 1 or not rede._convites_ally.has("ativo"):
		_falhar("A notificação de desconexão alterou convites não relacionados.")
		return

	rede.queue_free()
	print("TESTE MULTIPLAYER: expiração e cancelamento de convites Ally aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE MULTIPLAYER: " + mensagem)
	quit(1)
