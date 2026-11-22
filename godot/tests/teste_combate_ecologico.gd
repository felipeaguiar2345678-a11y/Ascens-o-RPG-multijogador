extends SceneTree
const CombateEcologico = preload("res://scripts/sistema_combate_ecologico.gd")
func _initialize() -> void:
	var predador := {"id":"lobo","ataque":50,"agilidade":20,"ecologia":{"especiesPresas":["cervo"]}}
	var presa := {"id":"cervo","ataque":5,"defesa":5,"vidaMaxima":100,"ecologia":{"especiesPredadoras":["lobo"]}}
	var atacante := {"especieId":"lobo","vivo":true,"atributos":{"ataque":50,"agilidade":20}}
	var alvo := {"individuoId":"cervo_1","especieId":"cervo","vivo":true,"vidaAtual":100.0,"atributos":{"defesa":5,"vidaMaxima":100},"posicaoMundo":{"x":100.0,"y":100.0}}
	var sem_lider := CombateEcologico.resolver_ataque(predador,presa,atacante,alvo,123)
	if not bool(sem_lider.get("ok",false)) or int(sem_lider.get("dano",0)) <= 0:
		_falhar("Não calculou dano para relação de caça explícita."); return
	var presa_com_lider := presa.duplicate(true)
	presa_com_lider["_grupo"] = {"liderAtual":{"individuoId":"cervo_lider"},"individuos":[{"individuoId":"cervo_lider","vivo":true,"posicaoMundo":{"x":110.0,"y":100.0}}]}
	var protegido := CombateEcologico.resolver_ataque(predador,presa_com_lider,atacante,alvo,123)
	if not bool(protegido.get("liderDefendeu",false)) or int(protegido.get("dano",0)) >= int(sem_lider.get("dano",0)):
		_falhar("Líder próximo não protegeu o membro."); return
	var neutra := {"id":"raposa","ecologia":{}}
	if bool(CombateEcologico.resolver_ataque(predador,neutra,atacante,{"especieId":"raposa","vivo":true,"atributos":{}},123).get("ok",false)):
		_falhar("Permitiu ataque sem relação ecológica declarada."); return
	print("TESTE DE COMBATE ECOLÓGICO: aprovado.")
	quit(0)
func _falhar(mensagem: String) -> void:
	push_error("TESTE DE COMBATE ECOLÓGICO: "+mensagem)
	quit(1)
