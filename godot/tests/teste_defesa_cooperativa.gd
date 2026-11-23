extends SceneTree
const Defesa = preload("res://scripts/sistema_defesa_cooperativa.gd")

func _initialize() -> void:
	var filhote := {"individuoId":"filhote_1","faseVida":"filhote","vivo":true,"vidaAtual":40.0,"atributos":{"vidaMaxima":100.0},"posicaoMundo":{"x":100.0,"y":100.0}}
	var grupo := {"grupoId":"grupo_a","ecossistemaId":"floresta_arcana","relacoesGrupos":{"grupo_b":{"estado":"aliado","confianca":0.8}},"individuos":[{"individuoId":"adulto_1","faseVida":"adulto","vivo":true,"posicaoMundo":{"x":110.0,"y":100.0}}]}
	var aliado := {"grupoId":"grupo_b","ecossistemaId":"floresta_arcana","individuos":[{"individuoId":"aliado_1","vivo":true,"posicaoMundo":{"x":120.0,"y":100.0}}]}
	var familiar := Defesa.avaliar_intervencao(grupo, [], filhote)
	if not bool(familiar.get("interveio", false)) or not bool(familiar.get("protecaoFamiliar", false)) or float(familiar.get("reducaoDano", 0.0)) < 0.40:
		_falhar("Adulto próximo não protegeu o filhote."); return
	var externo := Defesa.avaliar_intervencao(grupo, [aliado], filhote)
	if not bool(externo.get("interveio", false)) or str(externo.get("grupoAliadoId", "")) != "grupo_b":
		_falhar("Grupo aliado próximo não interveio."); return
	var hostil := aliado.duplicate(true)
	hostil["grupoId"] = "grupo_hostil"
	grupo["relacoesGrupos"]["grupo_hostil"] = {"estado":"rival","confianca":1.0}
	if bool(Defesa.avaliar_intervencao(grupo, [hostil], filhote).get("interveio", false)):
		_falhar("Grupo rival foi tratado como aliado."); return
	var desconfiado := aliado.duplicate(true)
	desconfiado["grupoId"] = "grupo_desconfiado"
	grupo["relacoesGrupos"]["grupo_desconfiado"] = {"estado":"aliado","confianca":0.2}
	if bool(Defesa.avaliar_intervencao(grupo, [desconfiado], filhote).get("interveio", false)):
		_falhar("Aliança sem confiança suficiente interveio."); return
	var outro_ecossistema := aliado.duplicate(true)
	outro_ecossistema["ecossistemaId"] = "deserto_ancestral"
	if bool(Defesa.avaliar_intervencao(grupo, [outro_ecossistema], filhote).get("interveio", false)):
		_falhar("Grupo de outro ecossistema interveio."); return
	var longe := aliado.duplicate(true)
	longe["individuos"][0]["posicaoMundo"] = {"x":300.0,"y":300.0}
	if bool(Defesa.avaliar_intervencao(grupo, [longe], filhote).get("interveio", false)):
		_falhar("Aliado distante interveio."); return
	var posicao_ruim := filhote.duplicate(true)
	posicao_ruim["posicaoMundo"] = {"x":NAN,"y":100.0}
	if bool(Defesa.avaliar_intervencao(grupo, [], posicao_ruim).get("interveio", false)):
		_falhar("Posição não finita foi aceita."); return
	var protegido := {"grupoId":"grupo_presa","individuos":[
		{"individuoId":"filhote","faseVida":"filhote","vivo":true,"vidaAtual":100.0,"atributos":{"vidaMaxima":100.0},"posicaoMundo":{"x":100.0,"y":100.0}},
		{"individuoId":"guardiao","faseVida":"adulto","vivo":true,"vidaAtual":100.0,"atributos":{"vidaMaxima":100.0},"posicaoMundo":{"x":110.0,"y":100.0}},
		{"individuoId":"adulto_isolado","faseVida":"adulto","vivo":true,"vidaAtual":60.0,"atributos":{"vidaMaxima":100.0},"posicaoMundo":{"x":230.0,"y":100.0}}
	]}
	var alvo := Defesa.selecionar_alvo_prioritario(protegido, Vector2(120.0,100.0))
	if str(alvo.get("individuoId","")) != "adulto_isolado":
		_falhar("Predador priorizou filhote protegido em vez de adulto isolado."); return
	print("TESTE DE DEFESA COOPERATIVA: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE DEFESA COOPERATIVA: " + mensagem)
	quit(1)
