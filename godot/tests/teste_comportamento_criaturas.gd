extends SceneTree
const Comportamento = preload("res://scripts/sistema_comportamento_criaturas.gd")
func _initialize() -> void:
	var criatura := {"evolucao":{"mutacoes":[]}}
	var resultado := Comportamento.decidir(criatura, {"ameacaPresente":true,"distanciaAmeaca":50.0,"forcaCriatura":10.0,"forcaAmeaca":20.0})
	if resultado.get("estado") != Comportamento.FUGINDO:
		_falhar("Não fugiu de ameaça mais forte."); return
	resultado = Comportamento.decidir(criatura, {"habitatAdequado":false})
	if resultado.get("estado") != Comportamento.BUSCANDO_HABITAT:
		_falhar("Não buscou habitat inadequado."); return
	resultado = Comportamento.decidir(criatura, {"invasorTerritorio":true,"forcaCriatura":10.0,"forcaAmeaca":5.0})
	if resultado.get("estado") != Comportamento.DEFENDENDO_TERRITORIO:
		_falhar("Não defendeu território."); return
	resultado = Comportamento.decidir(criatura, {"presaPresente":true,"forcaCriatura":10.0,"forcaAmeaca":5.0})
	if resultado.get("estado") != Comportamento.CACANDO:
		_falhar("Não selecionou caça."); return
	resultado = Comportamento.decidir(criatura, {"ameacaPresente":true,"distanciaAmeaca":40.0,"forcaCriatura":20.0,"forcaAmeaca":10.0})
	if resultado.get("estado") != Comportamento.CACANDO:
		_falhar("Criatura mais forte não perseguiu a presa."); return
	resultado = Comportamento.decidir(criatura, {})
	if resultado.get("estado") != Comportamento.VAGANDO:
		_falhar("Comportamento padrão incorreto."); return
	var mutante := {"evolucao":{"mutacoes":[{"id":"membros_predatorios","atributo":"agilidade"},{"id":"chifres_de_guerra","atributo":"ataque"}]}}
	var normal := Comportamento.decidir(criatura, {"presaPresente":true,"forcaCriatura":10.0,"forcaAmeaca":10.0})
	var evoluido := Comportamento.decidir(mutante, {"presaPresente":true,"forcaCriatura":10.0,"forcaAmeaca":10.0})
	if float(evoluido.get("multiplicadorVelocidade", 1.0)) <= float(normal.get("multiplicadorVelocidade", 1.0)):
		_falhar("Mutação de agilidade não influenciou perseguição."); return
	resultado = Comportamento.decidir(criatura, {"invasorTerritorio":true,"forcaCriatura":10.0,"forcaAmeaca":9.0,"moralMultiplicador":1.5})
	if resultado.get("estado") != Comportamento.DEFENDENDO_TERRITORIO:
		_falhar("Moral elevada não sustentou a defesa territorial."); return
	if not Comportamento.grupo_deve_continuar_confronto_razao(0.60, 1.8, 0.0):
		_falhar("Grupo com moral alta não demonstrou coragem suficiente."); return
	if Comportamento.grupo_deve_continuar_confronto_razao(0.60, 0.5, 0.0):
		_falhar("Grupo com moral baixa não recuou diante de força superior."); return
	var taticos := [
		{"individuoId":"filhote","faseVida":"filhote","vivo":true,"posicaoMundo":{"x":100.0,"y":100.0}},
		{"individuoId":"adulto_1","faseVida":"adulto","vivo":true,"posicaoMundo":{"x":110.0,"y":100.0}},
		{"individuoId":"adulto_2","faseVida":"adulto","vivo":true,"posicaoMundo":{"x":120.0,"y":100.0}},
		{"individuoId":"adulto_3","faseVida":"adulto","vivo":true,"posicaoMundo":{"x":150.0,"y":100.0}},
		{"individuoId":"morto","faseVida":"adulto","vivo":false,"posicaoMundo":{"x":105.0,"y":100.0}}
	]
	var formacao := Comportamento.distribuir_papeis_defensivos(taticos, "filhote", Vector2(200.0,100.0))
	var papeis := {}
	for membro in formacao:
		papeis[str(membro.get("individuoId",""))] = str(membro.get("papelDefensivoAtual",""))
	if papeis.get("filhote","") != "recuo_protegido" or papeis.get("adulto_1","") != "guardiao_dos_vulneraveis" or papeis.get("adulto_2","") != "guardiao_dos_vulneraveis" or papeis.get("adulto_3","") != "linha_defensiva":
		_falhar("Papéis defensivos não foram distribuídos por proximidade."); return
	if papeis.get("morto","") != "":
		_falhar("Indivíduo morto recebeu papel tático."); return
	print("TESTE DE COMPORTAMENTO DE CRIATURAS: aprovado.")
	quit(0)
func _falhar(mensagem: String) -> void:
	push_error("TESTE DE COMPORTAMENTO DE CRIATURAS: " + mensagem)
	quit(1)
