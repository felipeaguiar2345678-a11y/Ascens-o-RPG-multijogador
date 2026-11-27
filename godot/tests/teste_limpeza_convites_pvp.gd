extends SceneTree

const RedeMultiplayer = preload("res://scripts/rede_multiplayer.gd")

func _initialize() -> void:
	var rede = RedeMultiplayer.new()
	rede._convites_pvp = {
		"expirado": {"peerOrigem": 2, "peerAlvo": 3, "expira": 99},
		"no_limite": {"peerOrigem": 4, "peerAlvo": 5, "expira": 100},
		"ativo": {"peerOrigem": 6, "peerAlvo": 7, "expira": 101}
	}
	rede._limpar_convites_pvp_expirados(100)
	if rede._convites_pvp.has("expirado") or rede._convites_pvp.has("no_limite"):
		_falhar("Convites expirados, inclusive no instante limite, precisam ser removidos.")
		return
	if not rede._convites_pvp.has("ativo") or rede._convites_pvp.size() != 1:
		_falhar("A limpeza removeu um convite PvP ainda válido.")
		return
	rede.queue_free()
	print("TESTE MULTIPLAYER: expiração de convites PvP aprovada.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE MULTIPLAYER: " + mensagem)
	quit(1)
