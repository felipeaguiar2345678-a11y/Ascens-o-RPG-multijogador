extends SceneTree
const Movimento = preload("res://scripts/sistema_movimento_grupos.gd")

func _initialize() -> void:
	var grupo := {
		"territorio":{"centro":{"x":300.0,"y":240.0},"raio":90.0},
		"liderAtual":{"individuoId":"grupo_ind_1"},
		"individuos":[
			{"individuoId":"grupo_ind_1","vivo":true,"posicaoMundo":{"x":300.0,"y":240.0}},
			{"individuoId":"grupo_ind_2","vivo":true,"posicaoMundo":{"x":375.0,"y":240.0}},
			{"individuoId":"grupo_ind_3","vivo":false,"posicaoMundo":{"x":300.0,"y":240.0}}
		]
	}
	var resultado := Movimento.avancar(grupo, 1.0, 12345)
	if not bool(resultado.get("ok", false)):
		_falhar("Não avançou o movimento do grupo."); return
	var atualizado: Dictionary = resultado["grupo"]
	var vivos := 0
	var lider_marcado := false
	for individuo in atualizado["individuos"]:
		if not bool(individuo.get("vivo", true)):
			continue
		vivos += 1
		var p: Dictionary = individuo["posicaoMundo"]
		if not Movimento.posicao_dentro_do_territorio(atualizado, Vector2(float(p.x), float(p.y))):
			_falhar("Um indivíduo saiu do território."); return
		if str(individuo["individuoId"]) == "grupo_ind_1":
			lider_marcado = str(individuo.get("estadoMundo", "")) == "protegendo_grupo"
	if vivos != 2 or not lider_marcado:
		_falhar("Liderança ou estado de vida foi alterado incorretamente."); return
	if bool(Movimento.avancar(grupo, 6.0, 12345).get("ok", false)):
		_falhar("Aceitou intervalo excessivo."); return
	var offline_a := Movimento.avancar_offline(grupo, 3.0 * 86400.0, 98765)
	var offline_b := Movimento.avancar_offline(grupo, 3.0 * 86400.0, 98765)
	if not bool(offline_a.get("ok", false)) or int(offline_a.get("passos", 0)) != 24:
		_falhar("Não recuperou três dias offline com quantidade limitada de passos."); return
	if offline_a.get("grupo", {}).get("individuos", []) != offline_b.get("grupo", {}).get("individuos", []):
		_falhar("Recuperação offline não foi determinística."); return
	for membro_offline in offline_a.get("grupo", {}).get("individuos", []):
		if not bool(membro_offline.get("vivo", true)):
			continue
		var p_offline: Dictionary = membro_offline.get("posicaoMundo", {})
		if not Movimento.posicao_dentro_do_territorio(offline_a["grupo"], Vector2(float(p_offline.get("x", -1.0)), float(p_offline.get("y", -1.0)))):
			_falhar("Recuperação offline colocou indivíduo fora do território."); return
	if bool(Movimento.avancar_offline(grupo, 31.0 * 86400.0, 98765).get("ok", false)):
		_falhar("Aceitou recuperação offline acima do limite de 30 dias."); return
	print("TESTE DE MOVIMENTO DE GRUPOS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE MOVIMENTO DE GRUPOS: " + mensagem)
	quit(1)
