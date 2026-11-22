extends SceneTree
const LiderNato = preload("res://scripts/sistema_lider_nato.gd")
const Lideres = preload("res://scripts/sistema_lideres_criaturas.gd")
const SistemaDrops = preload("res://scripts/sistema_drops.gd")

func _initialize() -> void:
	var base := {"vidaMaxima":100,"ataque":40,"defesa":20,"manaMaxima":30,"agilidade":50,"poderMagico":10}
	var aprimorados := LiderNato.aprimorar(base)
	for atributo in base:
		if int(aprimorados[atributo]) != roundi(float(base[atributo]) * 1.25):
			_falhar("O atributo " + atributo + " não recebeu o aprimoramento de 25%."); return
	if int(base["ataque"]) != 40:
		_falhar("A função alterou os atributos originais."); return
	var rng := RandomNumberGenerator.new()
	rng.seed = 918273
	var nascimentos := 100000
	var lideres_natos := 0
	for i in range(nascimentos):
		if LiderNato.sortear(rng):
			lideres_natos += 1
	var proporcao := float(lideres_natos) / float(nascimentos)
	if proporcao < 0.008 or proporcao > 0.012:
		_falhar("A frequência de líderes natos desviou demais de 1%: " + str(proporcao)); return
	var grupo := {
		"grupoId":"grupo_teste",
		"especieId":"especie_teste",
		"populacaoMinimaParaLider":2,
		"individuos":[
			{"individuoId":"adulto_forte","faseVida":"adulto","atributos":base,"equipamentoIds":[]},
			{"individuoId":"adulto_apoio","faseVida":"adulto","atributos":base,"equipamentoIds":[]},
			{"individuoId":"filhote_nato","faseVida":"filhote","liderNato":true,"atributos":aprimorados,"equipamentoIds":[]}
		]
	}
	var antes := Lideres.avaliar_grupo(grupo, 7)
	if str(antes.get("lider", {}).get("individuoId", "")) != "adulto_apoio":
		_falhar("Um filhote não pode assumir a liderança antes de amadurecer."); return
	grupo["individuos"][2]["faseVida"] = "adulto"
	var depois := Lideres.avaliar_grupo(grupo, 7)
	if str(depois.get("lider", {}).get("individuoId", "")) != "filhote_nato":
		_falhar("O líder nato adulto não recebeu prioridade de liderança."); return
	if not bool(depois["lider"].get("liderNato", false)):
		_falhar("A condição de líder nato não foi registrada no líder."); return
	var tabela := [{"itemId":"presa_rara","nome":"Presa rara","categoria":"material","raridade":"comum","chance":1.0,"quantidadeMinima":2,"quantidadeMaxima":2}]
	var drop_normal := SistemaDrops.gerar_drops({"id":"fera","tabelaDrops":tabela},{"semente":123})
	var drop_nato := SistemaDrops.gerar_drops({"id":"fera","liderNato":true,"tabelaDrops":tabela},{"semente":123})
	if drop_normal.size() != 1 or int(drop_normal[0]["quantidade"]) != 2:
		_falhar("A tabela comum de drops deixou de respeitar a quantidade base."); return
	if drop_nato.size() != 1 or int(drop_nato[0]["quantidade"]) != 3 or not bool(drop_nato[0]["origemLiderNato"]):
		_falhar("O líder nato não concedeu quantidade superior de loot ao jogador."); return
	if not is_equal_approx(SistemaLiderNato.MULTIPLICADOR_CHANCE_DROPS, 2.0):
		_falhar("O bônus de chance de drop do líder nato não é 2x."); return
	print("TESTE DE LÍDER NATO: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE LÍDER NATO: " + mensagem)
	quit(1)
