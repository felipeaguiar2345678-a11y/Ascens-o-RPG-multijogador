extends SceneTree
const Lideres = preload("res://scripts/sistema_lideres_criaturas.gd")

func _initialize() -> void:
	var grupo := {
		"grupoId":"alcateia_norte",
		"especieId":"lobo_arcano",
		"populacaoMinimaParaLider":3,
		"equipamentosLiderDisponiveis":["espada_ferro","peitoral_malha","anel_poder","item_inexistente"],
		"individuos":[
			{"individuoId":"lobo_a","atributos":{"vidaMaxima":100,"ataque":20,"defesa":10,"manaMaxima":5,"agilidade":25,"poderMagico":0},"equipamentoIds":["adaga_dupla"]},
			{"individuoId":"lobo_b","atributos":{"vidaMaxima":130,"ataque":30,"defesa":15,"manaMaxima":5,"agilidade":20,"poderMagico":0},"equipamentoIds":[]},
			{"individuoId":"lobo_c","atributos":{"vidaMaxima":90,"ataque":15,"defesa":8,"manaMaxima":5,"agilidade":35,"poderMagico":0},"equipamentoIds":[]}
		]
	}
	if not Lideres.validar_grupo(grupo):
		_falhar("Grupo válido foi rejeitado."); return
	var pequeno := grupo.duplicate(true)
	pequeno["individuos"] = [grupo["individuos"][0], grupo["individuos"][1]]
	var sem_lider := Lideres.avaliar_grupo(pequeno, 42)
	if not bool(sem_lider.get("ok", false)) or bool(sem_lider.get("temLider", true)):
		_falhar("Grupo abaixo do mínimo recebeu líder."); return
	var avaliacao := Lideres.avaliar_grupo(grupo, 42)
	if not bool(avaliacao.get("temLider", false)):
		_falhar("Não escolheu líder para grupo elegível."); return
	var lider: Dictionary = avaliacao["lider"]
	if str(lider["individuoId"]) != "lobo_b":
		_falhar("Não escolheu o indivíduo mais forte."); return
	if float(lider["multiplicadorAtributos"]) < 1.15 or float(lider["multiplicadorAtributos"]) > 1.35:
		_falhar("Multiplicador do líder saiu do intervalo permitido."); return
	for item_id in lider["equipamentoIds"]:
		if not ["espada_ferro","peitoral_malha","anel_poder","adaga_dupla"].has(item_id):
			_falhar("Líder recebeu equipamento inexistente."); return
	var tabela := [{"itemId":"presa_lobo","raridade":"raro","chance":0.1}]
	var melhorada := Lideres.melhorar_tabela_drops(tabela, 1.5)
	if absf(float(melhorada[0]["chance"]) - 0.15) > 0.0001:
		_falhar("Bônus de drops não foi aplicado corretamente."); return
	if float(Lideres.melhorar_tabela_drops(tabela, 2.1).size()) != 0.0:
		_falhar("Aceitou multiplicador de drops fora do limite."); return
	var sucessao := Lideres.suceder_lider(grupo, "lobo_b", 43)
	if not bool(sucessao.get("temLider", false)) or str(sucessao["lider"]["individuoId"]) == "lobo_b":
		_falhar("Não escolheu sucessor vivo após a morte do líder."); return
	if not bool(sucessao["lider"]["sucessao"]) or float(sucessao["lider"]["multiplicadorAtributos"]) > 1.20:
		_falhar("Sucessor não recebeu regra de sucessão."); return
	var invalido := grupo.duplicate(true)
	invalido["equipamentosLiderDisponiveis"] = ["item_falso"]
	if Lideres.validar_grupo(invalido):
		_falhar("Aceitou equipamento que não existe no catálogo."); return
	print("TESTE DE LIDERANÇA NATURAL: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE LIDERANÇA NATURAL: " + mensagem)
	quit(1)
