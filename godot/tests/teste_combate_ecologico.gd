extends SceneTree
const CombateEcologico = preload("res://scripts/sistema_combate_ecologico.gd")
func _initialize() -> void:
	var predador := {"id":"lobo","ataque":50,"agilidade":20,"ecologia":{"especiesPresas":["cervo"]}}
	var presa := {"id":"cervo","ataque":5,"defesa":5,"vidaMaxima":100,"ecologia":{"especiesPredadoras":["lobo"]}}
	var atacante := {"especieId":"lobo","vivo":true,"atributos":{"ataque":50,"agilidade":20},"posicaoMundo":{"x":100.0,"y":100.0}}
	var alvo := {"individuoId":"cervo_1","especieId":"cervo","vivo":true,"vidaAtual":100.0,"atributos":{"defesa":5,"vidaMaxima":100},"posicaoMundo":{"x":100.0,"y":100.0}}
	var fora_de_alcance := alvo.duplicate(true)
	fora_de_alcance["posicaoMundo"] = {"x":500.0,"y":500.0}
	if bool(CombateEcologico.resolver_ataque(predador,presa,atacante,fora_de_alcance,123).get("ok",false)):
		_falhar("A caça foi permitida fora do alcance."); return
	var ecossistema_distante := presa.duplicate(true)
	ecossistema_distante["ecossistemaId"] = "deserto_ancestral"
	predador["ecossistemaId"] = "floresta_arcana"
	if bool(CombateEcologico.resolver_ataque(predador,ecossistema_distante,atacante,alvo,123).get("ok",false)):
		_falhar("A caça entre ecossistemas incompatíveis foi permitida."); return
	predador.erase("ecossistemaId")
	var sem_posicao := atacante.duplicate(true)
	sem_posicao.erase("posicaoMundo")
	if bool(CombateEcologico.resolver_ataque(predador,presa,sem_posicao,alvo,123).get("ok",false)):
		_falhar("A caça sem posição autoritativa foi permitida."); return
	var sem_lider := CombateEcologico.resolver_ataque(predador,presa,atacante,alvo,123)
	if not bool(sem_lider.get("ok",false)) or int(sem_lider.get("dano",0)) <= 0:
		_falhar("Não calculou dano para relação de caça explícita."); return
	var presa_com_lider := presa.duplicate(true)
	presa_com_lider["_grupo"] = {"liderAtual":{"individuoId":"cervo_lider"},"individuos":[{"individuoId":"cervo_lider","vivo":true,"posicaoMundo":{"x":110.0,"y":100.0}}]}
	var protegido := CombateEcologico.resolver_ataque(predador,presa_com_lider,atacante,alvo,123)
	if not bool(protegido.get("liderDefendeu",false)) or int(protegido.get("dano",0)) >= int(sem_lider.get("dano",0)):
		_falhar("Líder próximo não protegeu o membro."); return
	var grupo_moral := {"moralMultiplicador":1.2}
	var predador_com_moral := predador.duplicate(true)
	predador_com_moral["_grupo"] = grupo_moral
	var dano_com_moral := CombateEcologico.resolver_ataque(predador_com_moral,presa,atacante,alvo,123)
	if int(dano_com_moral.get("dano",0)) <= int(sem_lider.get("dano",0)):
		_falhar("A moral do grupo vencedor não aumentou o dano em combate posterior."); return
	var presa_moral := presa.duplicate(true)
	presa_moral["_grupo"] = {"moralMultiplicador":1.2}
	var alvo_com_defesa := alvo.duplicate(true)
	alvo_com_defesa["atributos"]["defesa"] = 50
	var dano_base_defesa := CombateEcologico.resolver_ataque(predador,presa,atacante,alvo_com_defesa,123)
	var dano_com_defesa_moral := CombateEcologico.resolver_ataque(predador,presa_moral,atacante,alvo_com_defesa,123)
	if int(dano_com_defesa_moral.get("dano",0)) >= int(dano_base_defesa.get("dano",0)):
		_falhar("A moral defensiva do grupo não reduziu o dano recebido."); return
	var neutra := {"id":"raposa","ecologia":{}}
	if bool(CombateEcologico.resolver_ataque(predador,neutra,atacante,{"especieId":"raposa","vivo":true,"atributos":{}},123).get("ok",false)):
		_falhar("Permitiu ataque sem relação ecológica declarada."); return
	print("TESTE DE COMBATE ECOLÓGICO: aprovado.")
	quit(0)
func _falhar(mensagem: String) -> void:
	push_error("TESTE DE COMBATE ECOLÓGICO: "+mensagem)
	quit(1)
