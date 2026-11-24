
extends SceneTree

const Duelo = preload("res://scripts/sistema_duelo_pvp.gd")

func _initialize() -> void:
	var perfil_a := _perfil("Aventureiro A", 100, 100, 30)
	var perfil_b := _perfil("Aventureiro B", 100, 100, 30)
	var duelo: Dictionary = Duelo.criar_duelo("duelo_teste", 11, 12, perfil_a, perfil_b)
	if duelo.is_empty():
		_falhar("O sistema não criou um duelo com dois personagens válidos.")
		return
	if str(Duelo.estado_para_peer(duelo, 11).get("turno", "")) != "jogador" or str(Duelo.estado_para_peer(duelo, 12).get("turno", "")) != "inimigo":
		_falhar("A orientação do turno inicial não foi publicada corretamente.")
		return
	var acao_fora_de_turno := Duelo.executar_acao(duelo, 12, "ataque", "", 123)
	if bool(acao_fora_de_turno.get("ok", false)):
		_falhar("O adversário conseguiu agir fora do próprio turno.")
		return
	var primeiro_ataque := Duelo.executar_acao(duelo, 11, "ataque", "", 456)
	if not bool(primeiro_ataque.get("ok", false)):
		_falhar("O primeiro ataque válido foi recusado.")
		return
	duelo = primeiro_ataque["duelo"]
	if int(duelo.get("turnoPeer", -1)) != 12:
		_falhar("O turno não passou ao segundo participante.")
		return
	if str(Duelo.estado_para_peer(duelo, 12).get("turno", "")) != "jogador":
		_falhar("O segundo participante não recebeu seu turno.")
		return
	var perfil_forte := _perfil("Vencedor", 100, 100, 10000)
	var perfil_fraco := _perfil("Derrotado", 1, 1, 1)
	var duelo_rapido: Dictionary = Duelo.criar_duelo("duelo_final", 21, 22, perfil_forte, perfil_fraco)
	var final := Duelo.executar_acao(duelo_rapido, 21, "ataque", "", 789)
	if not bool(final.get("ok", false)) or str(final.get("duelo", {}).get("status", "")) != "vitoria" or int(final.get("duelo", {}).get("vencedorPeer", -1)) != 21:
		_falhar("O servidor não registrou corretamente a vitória quando a vida do adversário chegou a zero.")
		return
	print("Teste PvP: turnos, orientação e vitória verificados.")
	quit(0)

func _perfil(nome: String, vida: int, vida_maxima: int, forca: int) -> Dictionary:
	return {"personagemCriado":true,"nome":nome,"vida":vida,"vidaMaxima":vida_maxima,"mana":30,"manaMaxima":30,"forca":forca,"inteligencia":10,"agilidade":10,"vitalidade":10,"espirito":10,"equipamentos":{"mao_principal":""},"habilidades":[]}

func _falhar(mensagem: String) -> void:
	push_error(mensagem)
	quit(1)

