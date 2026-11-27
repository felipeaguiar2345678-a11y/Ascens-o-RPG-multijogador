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
	var cervo_contraditorio := {"id":"cervo_lunar","ecologia":{"especiesPresas":["lobo_nevoa"],"especiesPredadoras":[]}}
	var relacao_inversa := Ecologia.avaliar_relacao(lobo, cervo_contraditorio)
	if relacao_inversa.get("tipo") != "neutra" or str(relacao_inversa.get("motivo", "")) != "relacao_ausente_ou_contraditoria":
		_falhar("Declarações alimentares opostas deveriam ser bloqueadas como ambíguas."); return
	var dieta_duplicada := {"especiesPresas":["cervo"],"especiesPredadoras":["cervo"],"territorio":{}}
	if Ecologia.validar_ecologia(dieta_duplicada):
		_falhar("A mesma espécie não pode ser presa e predadora na própria dieta."); return
	var auto_caca := {"especiesPresas":["lobo_nevoa"],"especiesPredadoras":[],"territorio":{}}
	if Ecologia.validar_ecologia(auto_caca, "lobo_nevoa"):
		_falhar("A espécie não pode declarar a si própria como presa."); return
	var invalida := {"especiesPresas":["cervo","cervo"],"territorio":{}}
	if Ecologia.validar_ecologia(invalida):
		_falhar("Lista de presas duplicada deveria ser inválida."); return
	var caca := Ecologia.criar_contexto_interacao(lobo, cervo, 40.0, 80.0, 20.0, Vector2(130.0, 120.0))
	if not bool(caca.get("presaPresente", false)) or caca.get("posicaoAlvo") != Vector2(130.0, 120.0):
		_falhar("Predador forte não recebeu contexto para perseguir a presa."); return
	var fuga := Ecologia.criar_contexto_interacao(cervo, lobo, 40.0, 20.0, 80.0, Vector2(100.0, 120.0))
	if not bool(fuga.get("ameacaPresente", false)):
		_falhar("Presa não reconheceu seu predador."); return
	var defesa := Ecologia.criar_contexto_interacao(lobo, {"id":"urso","ecologia":{}}, 30.0, 80.0, 40.0, Vector2(110.0, 120.0))
	if not bool(defesa.get("invasorTerritorio", false)):
		_falhar("Invasor dentro do território não foi detectado."); return
	var com_populacao := {"especiesPresas":[],"especiesPredadoras":[],"territorio":{},"populacao":{"quantidadeInicial":12,"minima":3,"maxima":30,"nascimentosPorDia":1.5,"mortesPorDia":0.5}}
	if not Ecologia.validar_ecologia(com_populacao):
		_falhar("Parâmetros populacionais válidos foram rejeitados."); return
	var populacao_invalida := {"populacao":{"quantidadeInicial":40,"minima":2,"maxima":20,"nascimentosPorDia":1.0,"mortesPorDia":0.2}}
	if Ecologia.validar_ecologia(populacao_invalida):
		_falhar("População inicial acima da capacidade deveria ser inválida."); return
	print("TESTE DE ECOLOGIA DE CRIATURAS: aprovado.")
	quit(0)
func _falhar(mensagem: String) -> void:
	push_error("TESTE DE ECOLOGIA DE CRIATURAS: " + mensagem)
	quit(1)
