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

	var habilidade_fisica := habilidade.duplicate(true)
	habilidade_fisica["id"] = "teste_habilidade_fisica"
	habilidade_fisica["nome"] = "Golpe Rúnico"
	habilidade_fisica["categoria"] = "fisica"
	habilidade_fisica["custoMana"] = 0
	var perfil_fisico := perfil.duplicate(true)
	perfil_fisico["habilidades"] = [habilidade_fisica]
	var estado_fisico := SistemaCombate.criar_estado(perfil_fisico, criatura)
	var resultado_fisico := SistemaCombate.executar_rodada(estado_fisico, SistemaCombate.ACAO_HABILIDADE, 123458, str(estado_fisico.get("inimigo", {}).get("id", "")), "teste_habilidade_fisica")
	assert(bool(resultado_fisico.get("ok", false)), "A habilidade física deve ser aceita.")
	assert(int(resultado_fisico.get("estado", {}).get("jogador", {}).get("mana", 0)) == 20, "Habilidade física sem custo não deve consumir mana.")

	var habilidade_cura := habilidade.duplicate(true)
	habilidade_cura["id"] = "teste_cura"
	habilidade_cura["categoria"] = "suporte"
	habilidade_cura["custoMana"] = 3
	var perfil_ferido := perfil.duplicate(true)
	perfil_ferido["vida"] = 40
	perfil_ferido["habilidades"] = [habilidade_cura]
	var estado_ferido := SistemaCombate.criar_estado(perfil_ferido, criatura)
	var resultado_cura := SistemaCombate.executar_rodada(estado_ferido, SistemaCombate.ACAO_HABILIDADE, 123459, str(estado_ferido.get("inimigo", {}).get("id", "")), "teste_cura")
	assert(bool(resultado_cura.get("ok", false)), "Habilidade de suporte deve ser aceita.")
	assert(int(resultado_cura.get("estado", {}).get("jogador", {}).get("vida", 0)) > 40, "Habilidade de suporte deve restaurar vida.")
	assert(resultado_cura.get("estado", {}).get("efeitoHabilidade", {}).get("tipoEfeito", "") == "cura", "A cura deve acionar seu efeito visual.")

	var habilidade_defesa := habilidade.duplicate(true)
	habilidade_defesa["id"] = "teste_defesa"
	habilidade_defesa["categoria"] = "defesa"
	var perfil_defesa := perfil.duplicate(true)
	perfil_defesa["habilidades"] = [habilidade_defesa]
	var estado_defesa := SistemaCombate.criar_estado(perfil_defesa, criatura)
	var resultado_defesa := SistemaCombate.executar_rodada(estado_defesa, SistemaCombate.ACAO_HABILIDADE, 123460, str(estado_defesa.get("inimigo", {}).get("id", "")), "teste_defesa")
	assert(bool(resultado_defesa.get("ok", false)), "Habilidade defensiva deve ser aceita.")
	assert(resultado_defesa.get("estado", {}).get("efeitoHabilidade", {}).get("tipoEfeito", "") == "defesa", "A defesa deve acionar seu efeito visual.")

	var grupo := SistemaCombate.criar_estado_grupo(perfil_ferido, [criatura, criatura.duplicate(true)])
	var resultado_grupo := SistemaCombate.executar_rodada(grupo, SistemaCombate.ACAO_HABILIDADE, 123461, str(grupo.get("alvoSelecionadoId", "")), "teste_cura")
	assert(bool(resultado_grupo.get("ok", false)), "A cura também deve funcionar contra grupos.")
	assert(int(resultado_grupo.get("estado", {}).get("jogador", {}).get("vida", 0)) > 40, "A cura deve funcionar no combate em grupo.")
	print("Teste de uso e validação da habilidade inicial aprovado.")
	quit()
