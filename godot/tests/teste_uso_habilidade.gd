extends SceneTree

const SistemaCombate = preload("res://scripts/sistema_combate.gd")

func _initialize() -> void:
	var habilidade := {
		"id":"teste_habilidade_fogo",
		"nome":"Brasa Inicial",
		"elemento":"fogo",
		"categoria":"magica",
		"custoMana":3,
		"multiplicadorDano":1.08,
		"habilidadeInicial":true
	}
	var perfil := {
		"personagemCriado":true,
		"nome":"Aventureiro",
		"vida":100,"vidaMaxima":100,"mana":20,"manaMaxima":20,
		"forca":8,"inteligencia":8,"agilidade":8,"vitalidade":8,"espirito":8,
		"habilidades":[habilidade],
		"equipamentos":{}
	}
	var criatura := {
		"id":"criatura_teste","nome":"Lobo de Teste","vida":200,"vidaMaxima":200,
		"ataque":1,"defesa":0,"agilidade":0,"manaMaxima":0,"poderMagico":0,
		"experienciaBase":1
	}
	var estado := SistemaCombate.criar_estado(perfil, criatura)
	assert(not estado.is_empty(), "O combate de teste deve ser criado.")
	var resultado := SistemaCombate.executar_rodada(estado, SistemaCombate.ACAO_HABILIDADE, 123456, str(estado.get("inimigo", {}).get("id", "")), "teste_habilidade_fogo")
	assert(bool(resultado.get("ok", false)), "O servidor deve aceitar a habilidade pertencente ao personagem.")
	var novo_estado: Dictionary = resultado.get("estado", {})
	assert(int(novo_estado.get("jogador", {}).get("mana", 0)) == 17, "O custo de 3 PM deve ser descontado no servidor.")
	assert(novo_estado.get("efeitoHabilidade", {}).get("elemento", "") == "fogo", "O elemento validado deve chegar ao evento visual.")
	var negado := SistemaCombate.executar_rodada(estado, SistemaCombate.ACAO_HABILIDADE, 123457, str(estado.get("inimigo", {}).get("id", "")), "habilidade_inventada")
	assert(not bool(negado.get("ok", false)), "O servidor deve rejeitar uma habilidade que o personagem não possui.")
	print("Teste de uso e validação da habilidade inicial aprovado.")
	quit()
