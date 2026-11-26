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

	var invocacao := {"id":"invocacao_teste","nome":"Rato Sombrio","nivel":1,"vida":20,"vidaMaxima":20,"ataque":8,"defesa":2,"agilidade":5,"ativa":false}
	var habilidade_invocacao := habilidade.duplicate(true)
	habilidade_invocacao["id"] = "chamar_rato"
	habilidade_invocacao["categoria"] = "invocacao"
	habilidade_invocacao["invocacaoId"] = "invocacao_teste"
	habilidade_invocacao["custoMana"] = 5
	var perfil_invocador := perfil.duplicate(true)
	perfil_invocador["classeId"] = "invocador"
	perfil_invocador["habilidades"] = [habilidade_invocacao]
	perfil_invocador["invocacoes"] = [invocacao]
	perfil_invocador["invocacaoAtivaId"] = "invocacao_teste"
	var estado_invocador := SistemaCombate.criar_estado(perfil_invocador, criatura)
	assert(not estado_invocador.is_empty(), "O combate do invocador deve iniciar.")
	var vida_inimigo_antes := int(estado_invocador.inimigo.vida)
	var chamada := SistemaCombate.executar_rodada(estado_invocador, SistemaCombate.ACAO_HABILIDADE, 123462, str(estado_invocador.inimigo.id), "chamar_rato")
	assert(bool(chamada.get("ok", false)), "A habilidade de invocação deve chamar a criatura vinculada.")
	var estado_chamado: Dictionary = chamada.estado
	assert(int(estado_chamado.jogador.mana) == 15, "Invocar deve consumir 5 PM.")
	assert(bool(estado_chamado.invocacao.ativa), "A criatura deve permanecer ativa durante o combate.")
	assert(int(estado_chamado.inimigo.vida) < vida_inimigo_antes, "A invocação deve atacar junto com o jogador.")
	var repetida := SistemaCombate.executar_rodada(estado_chamado, SistemaCombate.ACAO_HABILIDADE, 123463, str(estado_chamado.inimigo.id), "chamar_rato")
	assert(not bool(repetida.get("ok", false)), "Não deve chamar a mesma criatura duas vezes na batalha.")

	var habilidade_extra := habilidade.duplicate(true)
	habilidade_extra["id"] = "teste_acao_extra"
	habilidade_extra["nome"] = "Passo Relâmpago"
	habilidade_extra["concedeAcaoExtra"] = true
	var perfil_extra := perfil.duplicate(true)
	perfil_extra["habilidades"] = [habilidade_extra]
	var estado_extra := SistemaCombate.criar_estado(perfil_extra, criatura)
	var primeira_acao_extra := SistemaCombate.executar_rodada(estado_extra, SistemaCombate.ACAO_HABILIDADE, 123464, str(estado_extra.inimigo.id), "teste_acao_extra")
	assert(bool(primeira_acao_extra.get("ok", false)), "A habilidade de velocidade deve ser aceita.")
	var estado_apos_extra: Dictionary = primeira_acao_extra.estado
	assert(bool(estado_apos_extra.get("acaoExtraDisponivel", false)), "A habilidade deve conceder uma ação antes da resposta inimiga.")
	assert(str(estado_apos_extra.get("turno", "")) == "jogador", "O turno deve permanecer com o jogador durante a ação adicional.")
	var segunda_acao_extra := SistemaCombate.executar_rodada(estado_apos_extra, SistemaCombate.ACAO_ATAQUE, 123465, str(estado_apos_extra.inimigo.id))
	assert(bool(segunda_acao_extra.get("ok", false)), "O jogador deve conseguir executar a ação adicional.")
	assert(not bool(segunda_acao_extra.estado.get("acaoExtraDisponivel", false)), "A ação adicional deve ser consumida após uma jogada.")
	assert(not bool(segunda_acao_extra.estado.get("acaoExtraJaConcedida", false)), "O limite deve ser liberado depois da resposta dos inimigos.")

	var grupo_extra := SistemaCombate.criar_estado_grupo(perfil_extra, [criatura, criatura.duplicate(true)])
	var habilidade_extra_grupo := SistemaCombate.executar_rodada(grupo_extra, SistemaCombate.ACAO_HABILIDADE, 123466, str(grupo_extra.alvoSelecionadoId), "teste_acao_extra")
	assert(bool(habilidade_extra_grupo.get("ok", false)), "A ação adicional deve funcionar contra grupos.")
	assert(bool(habilidade_extra_grupo.estado.get("acaoExtraDisponivel", false)), "O grupo deve aguardar a ação adicional antes de atacar.")
	var ataque_extra_grupo := SistemaCombate.executar_rodada(habilidade_extra_grupo.estado, SistemaCombate.ACAO_ATAQUE, 123467, str(habilidade_extra_grupo.estado.alvoSelecionadoId))
	assert(bool(ataque_extra_grupo.get("ok", false)), "A segunda ação deve funcionar no combate em grupo.")

	print("Teste de uso e invocação em combate aprovado.")
	quit()
