extends SceneTree

const RedeMultiplayer = preload("res://scripts/rede_multiplayer.gd")

func _initialize() -> void:
	var rede = RedeMultiplayer.new()
	rede._propostas_troca = {
		"expirada": {"peerOrigem": 2, "peerAlvo": 3, "expira": 99},
		"ativa": {"peerOrigem": 4, "peerAlvo": 5, "expira": 500}
	}
	rede._limpar_propostas_troca_expiradas(100)
	if rede._propostas_troca.has("expirada") or not rede._propostas_troca.has("ativa"):
		_falhar("A limpeza por prazo removeu proposta válida ou manteve proposta expirada.")
		return

	# A desconexão deve remover propostas nos dois sentidos, preservando as de terceiros.
	rede._propostas_troca = {
		"origem_desconectada": {"peerOrigem": 7, "peerAlvo": 8, "expira": 900},
		"alvo_desconectado": {"peerOrigem": 9, "peerAlvo": 7, "expira": 900},
		"terceiros": {"peerOrigem": 10, "peerAlvo": 11, "expira": 900}
	}
	rede._remover_propostas_troca_peer(7)
	if rede._propostas_troca.has("origem_desconectada") or rede._propostas_troca.has("alvo_desconectado") or not rede._propostas_troca.has("terceiros"):
		_falhar("A desconexão não limpou somente as propostas ligadas ao peer.")
		return

	rede.queue_free()
	print("TESTE DE TROCAS MULTIPLAYER: expiração e limpeza por desconexão aprovadas.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE TROCAS MULTIPLAYER: " + mensagem)
	quit(1)
