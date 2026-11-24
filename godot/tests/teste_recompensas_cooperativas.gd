extends SceneTree

const Combate = preload("res://scripts/sistema_combate_cooperativo.gd")
const Repositorio = preload("res://scripts/repositorio_personagem_servidor.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var estado := {
		"status":Combate.VITORIA,
		"participantes":[
			{"uid":"uid-recompensa-a","danoCausado":12},
			{"uid":"uid-recompensa-b","danoCausado":40},
			{"uid":"uid-recompensa-c","danoCausado":20}
		]
	}
	var distribuicao: Array = Combate.calcular_distribuicao_recompensas(estado, 101)
	if distribuicao.size() != 3:
		_falhar("Não calculou a distribuição de recompensa para os três integrantes.")
		return
	if int(distribuicao[0].get("experiencia", -1)) != 34 or int(distribuicao[1].get("experiencia", -1)) != 34 or int(distribuicao[2].get("experiencia", -1)) != 33:
		_falhar("A experiência não foi dividida igualmente com o restante distribuído de forma determinística.")
		return
	if bool(distribuicao[0].get("receberDrops", true)) or not bool(distribuicao[1].get("receberDrops", false)) or bool(distribuicao[2].get("receberDrops", true)):
		_falhar("Os drops não foram destinados exclusivamente ao maior causador de dano.")
		return
	var repositorio = Repositorio.new()
	var sufixo := str(Time.get_ticks_usec())
	var uids := ["ci_recompensa_a_" + sufixo, "ci_recompensa_b_" + sufixo, "ci_recompensa_c_" + sufixo]
	for i in range(3):
		var criado: Dictionary = repositorio.criar_personagem(uids[i], "Teste Coop %d" % (i + 1), "masculino", "masc_cabelo_curto", "humano", "guerreiro")
		if criado.is_empty():
			_falhar("Não criou um perfil para testar as recompensas.")
			return
	var id_encontro := "encontro-recompensa-" + sufixo
	var drop_garantido := [{"itemId":"material_teste_cooperativo","nome":"Material de teste","categoria":"material","raridade":"comum","quantidade":2,"origemCriaturaId":"criatura_teste"}]
	for i in range(3):
		var drops: Array = drop_garantido if bool(distribuicao[i].get("receberDrops", false)) else []
		var concessao: Dictionary = repositorio.conceder_recompensa_encontro(uids[i], id_encontro, int(distribuicao[i].get("experiencia", 0)), drops, 80, 20)
		if not bool(concessao.get("ok", false)) or bool(concessao.get("duplicada", true)):
			_falhar("Não concedeu a primeira recompensa de um integrante.")
			return
		var perfil: Dictionary = repositorio.carregar_ou_criar(uids[i])
		if int(perfil.get("experiencia", -1)) != int(distribuicao[i].get("experiencia", 0)):
			_falhar("A experiência individual não foi persistida.")
			return
		var inventario: Array = perfil.get("inventario", [])
		var deve_receber := bool(distribuicao[i].get("receberDrops", false))
		if deve_receber and (inventario.size() != 1 or int(inventario[0].get("quantidade", 0)) != 2):
			_falhar("O maior causador de dano não recebeu o drop garantido.")
			return
		if not deve_receber and not inventario.is_empty():
			_falhar("Um participante que não causou mais dano recebeu o drop.")
			return
		var repetida: Dictionary = repositorio.conceder_recompensa_encontro(uids[i], id_encontro, 999, drop_garantido, 80, 20)
		if not bool(repetida.get("ok", false)) or not bool(repetida.get("duplicada", false)):
			_falhar("A repetição da recompensa não foi reconhecida como duplicada.")
			return
		var perfil_final: Dictionary = repositorio.carregar_ou_criar(uids[i])
		if int(perfil_final.get("experiencia", -1)) != int(distribuicao[i].get("experiencia", 0)) or (perfil_final.get("inventario", []) as Array).size() != inventario.size():
			_falhar("A reconexão/repetição duplicou XP ou itens.")
			return
	print("OK: XP igualitário, drops ao maior dano e recibos idempotentes.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error(mensagem)
	quit(1)
