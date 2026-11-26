extends SceneTree

const Combate = preload("res://scripts/sistema_combate_cooperativo.gd")
const Repositorio = preload("res://scripts/repositorio_personagem_servidor.gd")
const Drops = preload("res://scripts/sistema_drops.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var estado := {
		"status":Combate.VITORIA,
		"participantes":[
			{"uid":"uid-recompensa-a","danoCausado":12,"vida":0,"conectado":false,"elegivelRecompensas":true},
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
	var tabela_teste := [
		{"itemId":"material_teste_cooperativo","nome":"Material de teste","categoria":"material","raridade":"comum","chance":0.5,"quantidadeMinima":1,"quantidadeMaxima":3}
	]
	var semente_encontro := int("encontro-recompensa-teste".hash()) & 0x7fffffff
	var rolagem_inicial: Array = Drops.resolver_tabela(tabela_teste, "criatura_teste", {"semente":semente_encontro})
	var rolagem_repetida: Array = Drops.resolver_tabela(tabela_teste, "criatura_teste", {"semente":semente_encontro})
	if rolagem_inicial != rolagem_repetida:
		_falhar("A mesma batalha gerou resultados de drop diferentes ao repetir a rolagem.")
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
	# Simula uma interrupção depois de apenas dois integrantes receberem a recompensa.
	for i in range(2):
		var drops_parciais: Array = drop_garantido if bool(distribuicao[i].get("receberDrops", false)) else []
		var parcial: Dictionary = repositorio.conceder_recompensa_encontro(uids[i], id_encontro, int(distribuicao[i].get("experiencia", 0)), drops_parciais, 80, 20)
		if not bool(parcial.get("ok", false)) or bool(parcial.get("duplicada", true)):
			_falhar("Não persistiu a etapa parcial de recompensas.")
			return
	# Um novo objeto de repositório representa a retomada após reinício do servidor.
	var repositorio_recuperado = Repositorio.new()
	for i in range(3):
		var drops: Array = drop_garantido if bool(distribuicao[i].get("receberDrops", false)) else []
		var concessao: Dictionary = repositorio_recuperado.conceder_recompensa_encontro(uids[i], id_encontro, int(distribuicao[i].get("experiencia", 0)), drops, 80, 20)
		if not bool(concessao.get("ok", false)):
			_falhar("Não retomou a liquidação parcial das recompensas.")
			return
		if i < 2 and not bool(concessao.get("duplicada", false)):
			_falhar("A recuperação reaplicou recompensa já confirmada.")
			return
		if i == 2 and bool(concessao.get("duplicada", true)):
			_falhar("A recuperação não concluiu a recompensa que estava pendente.")
			return
		var perfil: Dictionary = repositorio_recuperado.carregar_ou_criar(uids[i])
		if int(perfil.get("experiencia", -1)) != int(distribuicao[i].get("experiencia", 0)):
			_falhar("A experiência individual não foi persistida corretamente.")
			return
		var inventario: Array = perfil.get("inventario", [])
		var deve_receber := bool(distribuicao[i].get("receberDrops", false))
		if deve_receber and (inventario.size() != 1 or int(inventario[0].get("quantidade", 0)) != 2):
			_falhar("O maior causador de dano não recebeu exatamente o drop garantido.")
			return
		if not deve_receber and not inventario.is_empty():
			_falhar("Um participante que não causou mais dano recebeu o drop.")
			return
		var perfil_final: Dictionary = repositorio_recuperado.carregar_ou_criar(uids[i])
		if int(perfil_final.get("experiencia", -1)) != int(distribuicao[i].get("experiencia", 0)) or (perfil_final.get("inventario", []) as Array).size() != inventario.size():
			_falhar("A retomada duplicou XP ou itens.") 
			return
	# A penalidade de derrota também precisa ser idempotente após uma retomada.
	var uid_derrota := "ci_recompensa_derrota_" + sufixo
	var perfil_derrota: Dictionary = repositorio_recuperado.criar_personagem(uid_derrota, "Teste Derrota", "masculino", "masc_cabelo_curto", "humano", "guerreiro")
	if perfil_derrota.is_empty():
		_falhar("Não criou o perfil para testar a penalidade de derrota.")
		return
	perfil_derrota["experiencia"] = 200
	if not repositorio_recuperado.salvar(uid_derrota, perfil_derrota):
		_falhar("Não preparou a experiência inicial do teste de derrota.")
		return
	var id_derrota := "derrota-cooperativa-" + sufixo
	var primeira_penalidade: Dictionary = repositorio_recuperado.processar_derrota_cooperativa(uid_derrota, id_derrota)
	var segunda_penalidade: Dictionary = Repositorio.new().processar_derrota_cooperativa(uid_derrota, id_derrota)
	var perfil_apos_derrota: Dictionary = repositorio_recuperado.carregar_ou_criar(uid_derrota)
	if not bool(primeira_penalidade.get("ok", false)) or bool(primeira_penalidade.get("duplicada", true)):
		_falhar("A primeira derrota cooperativa não foi registrada.")
		return
	if not bool(segunda_penalidade.get("ok", false)) or not bool(segunda_penalidade.get("duplicada", false)):
		_falhar("A repetição da derrota não foi reconhecida como duplicada.")
		return
	if int(perfil_apos_derrota.get("experiencia", -1)) != 100:
		_falhar("A repetição da derrota aplicou a perda de experiência mais de uma vez.")
		return
	print("OK: XP igualitário, drops ao maior dano e recibos idempotentes para vitória e derrota.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error(mensagem)
	quit(1)
