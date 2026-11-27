extends SceneTree

const Migracao = preload("res://scripts/sistema_migracao_coordenadas.gd")

func _initialize() -> void:
	var perfil := Migracao.migrar_perfil_legado({"uid":"jogador","x":1190.0,"y":1120.0})
	if perfil.get("x") != 1190.0 or perfil.get("y") != 1520.0:
		_falhar("Não migrou as coordenadas do perfil.")
		return
	var criatura := Migracao.migrar_criatura_legada({
		"id":"criatura",
		"posicaoMundo":{"x":300.0,"y":400.0},
		"origemMundo":{"x":280.0,"y":390.0},
		"alvoMundo":{"x":500.0,"y":600.0}
	})
	if criatura.is_empty() or criatura["posicaoMundo"]["y"] != 800.0 or criatura["origemMundo"]["y"] != 790.0 or criatura["alvoMundo"]["y"] != 1000.0:
		_falhar("Não migrou todas as posições da criatura.")
		return
	var grupo := Migracao.migrar_grupo_legado({
		"territorio":{"centro":{"x":700.0,"y":800.0},"raio":100.0},
		"individuos":[
			{"individuoId":"vivo","posicaoMundo":{"x":710.0,"y":810.0}},
			{"individuoId":"morto","posicaoMundo":{"x":690.0,"y":790.0},"carcaca":{"posicaoMundo":{"x":695.0,"y":795.0}}}
		]
	})
	if grupo.is_empty() or grupo["territorio"]["centro"]["y"] != 1200.0:
		_falhar("Não migrou o centro territorial do grupo.")
		return
	if grupo["individuos"][0]["posicaoMundo"]["y"] != 1210.0 or grupo["individuos"][1]["carcaca"]["posicaoMundo"]["y"] != 1195.0:
		_falhar("Não migrou posições de indivíduos e carcaças.")
		return
	if not Migracao.migrar_perfil_legado({"uid":"sem_posicao"}).has("uid"):
		_falhar("Um perfil sem coordenadas deveria permanecer intacto.")
		return
	if not Migracao.migrar_perfil_legado({"x":100.0,"y":1601.0}).is_empty():
		_falhar("Uma posição inválida deveria bloquear a migração.")
		return
	print("TESTE DE MIGRAÇÃO DE COORDENADAS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE MIGRAÇÃO DE COORDENADAS: " + mensagem)
	quit(1)
