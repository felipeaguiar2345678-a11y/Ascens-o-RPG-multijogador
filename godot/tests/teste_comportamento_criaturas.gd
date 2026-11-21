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
	resultado = Comportamento.decidir(criatura, {})
	if resultado.get("estado") != Comportamento.VAGANDO:
		_falhar("Comportamento padrão incorreto."); return
	var mutante := {"evolucao":{"mutacoes":[{"id":"membros_predatorios","atributo":"agilidade"},{"id":"chifres_de_guerra","atributo":"ataque"}]}}
	var normal := Comportamento.decidir(criatura, {"presaPresente":true,"forcaCriatura":10.0,"forcaAmeaca":10.0})
	var evoluido := Comportamento.decidir(mutante, {"presaPresente":true,"forcaCriatura":10.0,"forcaAmeaca":10.0})
	if float(evoluido.get("multiplicadorVelocidade", 1.0)) <= float(normal.get("multiplicadorVelocidade", 1.0)):
		_falhar("Mutação de agilidade não influenciou perseguição."); return
	print("TESTE DE COMPORTAMENTO DE CRIATURAS: aprovado.")
	quit(0)
func _falhar(mensagem: String) -> void:
	push_error("TESTE DE COMPORTAMENTO DE CRIATURAS: " + mensagem)
	quit(1)
