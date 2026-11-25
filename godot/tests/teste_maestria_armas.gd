extends SceneTree

const Maestria = preload("res://scripts/sistema_maestria_armas.gd")
const Equipamentos = preload("res://scripts/sistema_equipamentos.gd")
const Combate = preload("res://scripts/sistema_combate.gd")

func _initialize() -> void:
	_testar_progressao_individual()
	_testar_bonus_de_dano()
	_testar_todas_as_raridades()
	print("TESTE DE MAESTRIA DE ARMAS: aprovado")
	quit(0)

func _testar_progressao_individual() -> void:
	var maestrias := {}
	for i in range(10):
		var resultado: Dictionary = Maestria.registrar_acerto(maestrias, "espada_ferro")
		maestrias = resultado["maestrias"]
	var ferro: Dictionary = Maestria.progresso(maestrias, "espada_ferro")
	assert(int(ferro["nivel"]) == 2)
	assert(int(ferro["experiencia"]) == 100)
	assert(int(ferro["experienciaNoNivel"]) == 0)
	assert(bool(Maestria.registrar_acerto(maestrias, "espada_ferro")["maestrias"].has("espada_ferro")))
	assert(int(Maestria.progresso(maestrias, "machado_batalha")["nivel"]) == 1)
	assert(int(Maestria.progresso(maestrias, "espada_ferro")["nivel"]) == 2)

func _testar_bonus_de_dano() -> void:
	assert(Maestria.aplicar_bonus_dano(100, 1) == 100)
	assert(Maestria.aplicar_bonus_dano(100, 2) == 101)
	assert(Maestria.aplicar_bonus_dano(100, 50) == 129)
	assert(is_equal_approx(Maestria.multiplicador_dano(50), 1.294))

func _testar_todas_as_raridades() -> void:
	var comum := Equipamentos.obter("espada_ferro")
	var rara := Equipamentos.obter("sandai_kitetsu")
	var lendaria := Equipamentos.obter("wado_ichimonji")
	var mitica := Equipamentos.obter("gryphon")
	var suprema := Equipamentos.obter("yoru")
	assert(not comum.is_empty() and int(comum.get("dano", 0)) > 0)
	assert(not rara.is_empty() and int(rara.get("dano", 0)) > 0)
	assert(not lendaria.is_empty() and int(lendaria.get("dano", 0)) > 0)
	assert(not mitica.is_empty() and int(mitica.get("dano", 0)) > 0)
	assert(not suprema.is_empty() and int(suprema.get("dano", 0)) > 0)
	var efeito_comum: Dictionary = Combate._obter_efeito_ataque_arma("espada_ferro", {"nivel":1})
	var efeito_comum_mestre: Dictionary = Combate._obter_efeito_ataque_arma("espada_ferro", {"nivel":50})
	assert(not efeito_comum.is_empty())
	assert(float(efeito_comum_mestre["intensidadeVisual"]) > float(efeito_comum["intensidadeVisual"]))
	assert(int(efeito_comum_mestre["bonusDanoPercentual"]) == 29)
