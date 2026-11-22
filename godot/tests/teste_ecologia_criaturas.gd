extends SceneTree
const Ecologia = preload("res://scripts/sistema_ecologia_criaturas.gd")
func _initialize() -> void:
	var lobo := {"id":"lobo_nevoa","ecologia":{"especiesPresas":["cervo_lunar"],"especiesPredadoras":[],"territorio":{"centro":{"x":100.0,"y":120.0},"raio":80.0}}}
	var cervo := {"id":"cervo_lunar","ecologia":{"especiesPresas":[],"especiesPredadoras":["lobo_nevoa"],"territorio":{}}}
	var relacao := Ecologia.avaliar_relacao(lobo, cervo)
	if relacao.get("tipo") != "predador" or relacao.get("predador") != "lobo_nevoa":
		_falhar("Relação predador-presa declarada não foi reconhecida."); return
	if not Ecologia.esta_no_territorio(lobo, Vector2(150.0, 120.0)):
		_falhar("Posição dentro do território foi rejeitada."); return
	if Ecologia.esta_no_territorio(lobo, Vector2(300.0, 120.0)):
		_falhar("Posição fora do território foi aceita."); return
	if Ecologia.avaliar_relacao(lobo, {"id":"urso","ecologia":{}}).get("tipo") != "neutra":
		_falhar("Relação não declarada não deve ser presumida."); return
	if not Ecologia.validar_ecologia(lobo.get("ecologia")):
		_falhar("Ecologia válida foi rejeitada."); return
	var invalida := {"especiesPresas":["cervo","cervo"],"territorio":{}}
	if Ecologia.validar_ecologia(invalida):
		_falhar("Lista de presas duplicada deveria ser inválida."); return
	print("TESTE DE ECOLOGIA DE CRIATURAS: aprovado.")
	quit(0)
func _falhar(mensagem: String) -> void:
	push_error("TESTE DE ECOLOGIA DE CRIATURAS: " + mensagem)
	quit(1)
