extends SceneTree

const Sistema = preload("res://scripts/sistema_serpente_mundo.gd")

func _initialize() -> void:
	var estado := Sistema.criar_estado(1000)
	assert(not estado.is_empty())
	var longe := Sistema.entrar(estado, "uid_a", 2, Vector2(1000, 1000), Vector2.ZERO)
	assert(not bool(longe.get("ok", false)), "Não pode entrar na incursão fora da arena.")
	var entrada_a := Sistema.entrar(estado, "uid_a", 2, Vector2(40, 30), Vector2.ZERO)
	assert(bool(entrada_a.get("ok", false)))
	estado = entrada_a.estado
	var entrada_b := Sistema.entrar(entrada_a.estado, "uid_b", 3, Vector2(20, 20), Vector2.ZERO)
	assert(bool(entrada_b.get("ok", false)), "Outro jogador deve compartilhar a mesma incursão.")
	estado = entrada_b.estado
	var perfil_a := {"forca": 20, "inteligencia": 5, "espirito": 5}
	var ataque_a := Sistema.aplicar_ataque(entrada_b.estado, "uid_a", 2, perfil_a, "ataque", 5000)
	assert(bool(ataque_a.get("ok", false)))
	assert(int(ataque_a.estado.vida) == 928)
	var repetido := Sistema.aplicar_ataque(ataque_a.estado, "uid_a", 2, perfil_a, "ataque", 5500)
	assert(not bool(repetido.get("ok", false)), "O intervalo por participante deve bloquear spam.")
	var perfil_b := {"forca": 30, "inteligencia": 5, "espirito": 5}
	var ataque_b := Sistema.aplicar_ataque(ataque_a.estado, "uid_b", 3, perfil_b, "ataque", 5500)
	assert(bool(ataque_b.get("ok", false)))
	assert(int(ataque_b.estado.vida) == 826, "Os jogadores devem reduzir a mesma vida global.")
	var estado_quase_morto := ataque_b.estado.duplicate(true)
	estado_quase_morto["vida"] = 50
	var final := Sistema.aplicar_ataque(estado_quase_morto, "uid_a", 2, perfil_a, "ataque", 7000)
	assert(bool(final.get("ok", false)))
	assert(bool(final.get("derrotada", false)))
	assert(str(final.estado.status) == Sistema.STATUS_DERROTADA)
	assert(bool(final.estado.serpenteOriginalPreservada), "Derrotar a chefe não pode remover a serpente original.")
	var nao_participante := Sistema.registrar_tentativa_filhote(final.estado, "uid_c")
	assert(not bool(nao_participante.get("ok", false)))
	var tentativas := Sistema.registrar_tentativa_filhote(final.estado, "uid_a")
	assert(bool(tentativas.get("ok", false)))
	assert(int(tentativas.get("restantes", -1)) == 2)
	var estado_tentativa := tentativas.estado
	for i in range(2):
		var nova := Sistema.registrar_tentativa_filhote(estado_tentativa, "uid_a")
		assert(bool(nova.get("ok", false)))
		estado_tentativa = nova.estado
	var quarta := Sistema.registrar_tentativa_filhote(estado_tentativa, "uid_a")
	assert(not bool(quarta.get("ok", false)))
	var outro := Sistema.registrar_tentativa_filhote(final.estado, "uid_b")
	assert(bool(outro.get("ok", false)), "As tentativas são individuais por jogador.")
	print("OK: arena da cabeça, vida compartilhada, validação de peer, intervalo, derrota e tentativas individuais.")
	quit()
