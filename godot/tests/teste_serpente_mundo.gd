extends SceneTree

const Sistema = preload("res://scripts/sistema_serpente_mundo.gd")

func _initialize() -> void:
	var estado := Sistema.criar_estado(1000)
	assert(not estado.is_empty())
	var longe := Sistema.entrar(estado, "uid_a", 2, Vector2(1000, 1000), Vector2.ZERO)
	assert(not bool(longe.get("ok", false)), "Não pode entrar na incursão fora da arena.")
	var entrada_a := Sistema.entrar(estado, "uid_a", 2, Vector2(40, 30), Vector2.ZERO)
	assert(bool(entrada_a.get("ok", false)))
	var entrada_b := Sistema.entrar(entrada_a.estado, "uid_b", 3, Vector2(20, 20), Vector2.ZERO)
	assert(bool(entrada_b.get("ok", false)), "Outro jogador deve compartilhar a mesma incursão.")
	var perfil_a := {"forca": 20, "inteligencia": 5, "espirito": 5}
	var ataque_a := Sistema.aplicar_ataque(entrada_b.estado, "uid_a", 2, perfil_a, "ataque", 5000)
	assert(bool(ataque_a.get("ok", false)))
	assert(int(ataque_a.estado.vida) == 928)
	var repetido := Sistema.aplicar_ataque(ataque_a.estado, "uid_a", 2, perfil_a, "ataque", 5500)
	assert(not bool(repetido.get("ok", false)), "O intervalo por participante deve bloquear spam.")
	var perfil_b := {"forca": 30, "inteligencia": 5, "espirito": 5}
	var ataque_b := Sistema.aplicar_ataque(ataque_a.estado, "uid_b", 3, perfil_b, "ataque", 5500)
	assert(bool(ataque_b.get("ok", false)))
	assert(int(ataque_b.estado.vida) == 826)
	assert(Sistema.calcular_dano_serpente({"vidaMaxima": 100, "vitalidade": 5}) == 7, "Vitalidade reduz o dano do tremor.")
	var quase_morto := ataque_b.estado.duplicate(true)
	quase_morto["vida"] = 50
	var final := Sistema.aplicar_ataque(quase_morto, "uid_a", 2, perfil_a, "ataque", 7000)
	assert(bool(final.get("derrotada", false)))
	assert(str(final.estado.status) == Sistema.STATUS_DERROTADA)
	assert(int(final.estado.proximoRenascimentoUnix) == int(final.estado.derrotadaUnix) + Sistema.TEMPO_RENASCIMENTO_SEGUNDOS)
	assert(bool(final.estado.serpenteOriginalPreservada))
	assert(not bool(Sistema.registrar_tentativa_filhote(final.estado, "uid_c").get("ok", false)))
	var tentativa := Sistema.registrar_tentativa_filhote(final.estado, "uid_a")
	assert(bool(tentativa.get("ok", false)))
	assert(int(tentativa.get("restantes", -1)) == 2)
	var ciclo := tentativa.estado
	for i in range(2):
		ciclo = Sistema.registrar_tentativa_filhote(ciclo, "uid_a").estado
	assert(not bool(Sistema.registrar_tentativa_filhote(ciclo, "uid_a").get("ok", false)))
	assert(bool(Sistema.registrar_tentativa_filhote(final.estado, "uid_b").get("ok", false)))
	var renascido := Sistema.verificar_renascimento(final.estado, int(final.estado.proximoRenascimentoUnix))
	assert(str(renascido.status) == Sistema.STATUS_DISPONIVEL)
	assert(int(renascido.ciclos) == 2)
	assert(int(renascido.totalDerrotas) == 1)
	assert(renascido.tentativasDomesticacao.is_empty())
	var antes_da_hora := Sistema.verificar_renascimento(final.estado, int(final.estado.proximoRenascimentoUnix) - 1)
	assert(antes_da_hora == final.estado)
	print("OK: arena, vida compartilhada, tremor, defesa por vitalidade, derrota, filhote e renascimento.")
	quit()
