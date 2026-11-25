extends SceneTree

const Sistema = preload("res://scripts/sistema_supremas_one_piece.gd")

func _initialize() -> void:
	_testar_regras_de_acesso()
	_testar_carga_por_turnos_e_acoes()
	_testar_suprema_devastadora_em_area()
	_testar_suprema_de_alvo_unico()
	print("TESTE DAS SUPREMAS ONE PIECE: aprovado")
	quit()

func _testar_regras_de_acesso() -> void:
	assert(Sistema.pode_usar("murakumogiri"))
	assert(Sistema.pode_usar("gryphon"))
	assert(not Sistema.pode_usar("wado_ichimonji"))
	assert(Sistema.criar_estado("arma_inexistente").is_empty())

func _testar_carga_por_turnos_e_acoes() -> void:
	var estado: Dictionary = Sistema.criar_estado("murakumogiri")
	for i in range(7):
		estado = Sistema.carregar_por_turno(estado)
	assert(int(estado["carga"]) == 84)
	estado = Sistema.carregar_por_acao(estado)
	assert(int(estado["carga"]) == 92)
	estado = Sistema.carregar_por_acao(estado)
	assert(int(estado["carga"]) == 100)
	assert(bool(estado["pronta"]))

func _testar_suprema_devastadora_em_area() -> void:
	var estado: Dictionary = Sistema.criar_estado("murakumogiri")
	estado["carga"] = 100
	estado["pronta"] = true
	var inimigos: Array = [
		{"id":"a","vida":100,"vidaMaxima":100,"defesa":0},
		{"id":"b","vida":100,"vidaMaxima":100,"defesa":0},
		{"id":"c","vida":100,"vidaMaxima":100,"defesa":0}
	]
	var resultado: Dictionary = Sistema.executar(estado, inimigos, "a")
	assert(bool(resultado.get("ok", false)))
	assert(resultado["danos"].size() == 3)
	assert(int(resultado["inimigos"][0]["vida"]) == 0)
	assert(int(resultado["estadoSuprema"]["carga"]) == 0)
	assert(str(resultado["efeitoVisual"]["efeito"]) == "terremoto_dimensional")

func _testar_suprema_de_alvo_unico() -> void:
	var estado: Dictionary = Sistema.criar_estado("gryphon")
	estado["carga"] = 100
	estado["pronta"] = true
	var inimigos: Array = [{"id":"a","vida":100,"vidaMaxima":100,"defesa":0},{"id":"b","vida":100,"vidaMaxima":100,"defesa":0}]
	var resultado: Dictionary = Sistema.executar(estado, inimigos, "b")
	assert(bool(resultado.get("ok", false)))
	assert(resultado["danos"].size() == 1)
	assert(int(resultado["inimigos"][0]["vida"]) == 100)
	assert(int(resultado["inimigos"][1]["vida"]) == 0)
