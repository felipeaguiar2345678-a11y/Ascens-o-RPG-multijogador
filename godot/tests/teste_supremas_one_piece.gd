extends SceneTree

const Sistema = preload("res://scripts/sistema_supremas_one_piece.gd")
const SistemaCombate = preload("res://scripts/sistema_combate.gd")

func _initialize() -> void:
	_testar_regras_de_acesso()
	_testar_carga_por_turnos_e_acoes()
	_testar_suprema_devastadora_em_area()
	_testar_suprema_de_alvo_unico()
	_testar_integracao_combate_autoritativo()
	_testar_suprema_em_combate_com_grupo()
	_testar_carga_por_acao_extra_no_combate()
	_testar_carga_normal_sem_bonus_extra()
	_testar_suprema_nao_recarrega_no_mesmo_turno()
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

func _testar_integracao_combate_autoritativo() -> void:
	var suprema: Dictionary = Sistema.criar_estado("gryphon")
	suprema["carga"] = 100
	suprema["pronta"] = true
	var estado_combate := {
		"status": "em_andamento",
		"turno": "jogador",
		"suprema": suprema,
		"jogador": {"nome":"Teste"},
		"invocacao": {"id":"pet-teste","ativa":true},
		"inimigo": {"id":"alvo","nome":"Alvo de teste","vida":100,"vidaMaxima":100,"defesa":0}
	}
	var resultado: Dictionary = SistemaCombate.executar_rodada(estado_combate, SistemaCombate.ACAO_SUPREMA, 123, "alvo")
	assert(bool(resultado.get("ok", false)))
	assert(str(resultado["estado"].get("status", "")) == SistemaCombate.STATUS_VITORIA)
	assert(resultado["estado"].has("supremaExecutada"))
	assert(int(resultado["estado"]["suprema"]["carga"]) == 0)
	assert(not bool(resultado["estado"].get("invocacao", {}).get("ativa", true)))

func _testar_suprema_em_combate_com_grupo() -> void:
	var suprema: Dictionary = Sistema.criar_estado("murakumogiri")
	suprema["carga"] = 100
	suprema["pronta"] = true
	var inimigos: Array = [
		{"id":"a","nome":"Alvo A","vida":100,"vidaMaxima":100,"defesa":0},
		{"id":"b","nome":"Alvo B","vida":100,"vidaMaxima":100,"defesa":0},
		{"id":"c","nome":"Alvo C","vida":100,"vidaMaxima":100,"defesa":0}
	]
	var estado := {"status":"em_andamento","turno":"jogador","suprema":suprema,"inimigos":inimigos,"jogador":{"nome":"Teste","vida":100,"vidaMaxima":100,"mana":20,"manaMaxima":20,"forca":10,"inteligencia":10,"agilidade":10,"espirito":10,"defesa":10,"habilidades":[],"defendendo":false,"esquivando":false},"historico":[]}
	var resultado: Dictionary = SistemaCombate.executar_rodada(estado, SistemaCombate.ACAO_SUPREMA, 321, "b")
	assert(bool(resultado.get("ok", false)))
	assert(bool(resultado["estado"].has("supremaExecutada")))
	assert(int(resultado["estado"]["inimigos"][0]["vida"]) == 0)
	assert(int(resultado["estado"]["inimigos"][1]["vida"]) == 0)
	assert(int(resultado["estado"]["inimigos"][2]["vida"]) == 0)

func _testar_carga_por_acao_extra_no_combate() -> void:
	var suprema: Dictionary = Sistema.criar_estado("gryphon")
	var estado := {"status":"em_andamento","turno":"jogador","suprema":suprema,"inimigo":{"id":"a","nome":"Alvo","vida":10000,"vidaMaxima":10000,"mana":0,"ataque":1,"poderMagico":0,"defesa":0,"agilidade":0,"padroesAtaque":[],"turnoAtaqueEspecial":0},"jogador":{"nome":"Teste","vida":100,"vidaMaxima":100,"mana":20,"manaMaxima":20,"forca":10,"inteligencia":10,"agilidade":10,"espirito":10,"defesa":10,"habilidades":[],"defendendo":false,"esquivando":false},"historico":[]}
	estado = SistemaCombate.registrar_acao_extra(estado)
	var resultado: Dictionary = SistemaCombate.executar_rodada(estado, SistemaCombate.ACAO_DEFENDER, 456)
	assert(bool(resultado.get("ok", false)))
	assert(int(resultado["estado"]["suprema"]["carga"]) == 20)
	assert(int(resultado["estado"].get("acoesExtrasPendentes", 0)) == 0)

func _testar_carga_normal_sem_bonus_extra() -> void:
	var suprema: Dictionary = Sistema.criar_estado("gryphon")
	var estado := {"status":"em_andamento","turno":"jogador","suprema":suprema,"inimigo":{"id":"a","nome":"Alvo","vida":10000,"vidaMaxima":10000,"mana":0,"ataque":1,"poderMagico":0,"defesa":0,"agilidade":0,"padroesAtaque":[],"turnoAtaqueEspecial":0},"jogador":{"nome":"Teste","vida":100,"vidaMaxima":100,"mana":20,"manaMaxima":20,"forca":10,"inteligencia":10,"agilidade":10,"espirito":10,"defesa":10,"habilidades":[],"defendendo":false,"esquivando":false},"historico":[]}
	var resultado: Dictionary = SistemaCombate.executar_rodada(estado, SistemaCombate.ACAO_DEFENDER, 789)
	assert(bool(resultado.get("ok", false)))
	assert(int(resultado["estado"]["suprema"]["carga"]) == 12)

func _testar_suprema_nao_recarrega_no_mesmo_turno() -> void:
	var suprema: Dictionary = Sistema.criar_estado("gryphon")
	suprema["carga"] = 100
	suprema["pronta"] = true
	var estado := {
		"status":"em_andamento","turno":"jogador","suprema":suprema,
		"inimigo":{"id":"a","nome":"Chefe de teste","vida":1000000,"vidaMaxima":1000000,"mana":0,"ataque":1,"poderMagico":0,"defesa":0,"agilidade":0,"padroesAtaque":[],"turnoAtaqueEspecial":0},
		"jogador":{"nome":"Teste","vida":100,"vidaMaxima":100,"mana":20,"manaMaxima":20,"forca":10,"inteligencia":10,"agilidade":10,"espirito":10,"defesa":10,"habilidades":[],"defendendo":false,"esquivando":false},
		"historico":[]
	}
	var resultado := SistemaCombate.executar_rodada(estado, SistemaCombate.ACAO_SUPREMA, 987)
	assert(bool(resultado.get("ok", false)), "A Suprema pronta deve ser aceita.")
	assert(int(resultado["estado"]["suprema"]["carga"]) == 0, "A Suprema não pode recarregar no turno em que foi usada.")
