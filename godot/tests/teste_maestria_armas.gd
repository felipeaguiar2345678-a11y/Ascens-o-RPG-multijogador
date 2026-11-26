extends SceneTree

const Maestria = preload("res://scripts/sistema_maestria_armas.gd")
const Equipamentos = preload("res://scripts/sistema_equipamentos.gd")
const Combate = preload("res://scripts/sistema_combate.gd")

func _initialize() -> void:
	_testar_progressao_individual()
	_testar_bonus_de_dano()
	_testar_marcos_de_tecnica()
	_testar_todas_as_raridades()
	_testar_efeito_e_maestria_em_grupo()
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

func _testar_marcos_de_tecnica() -> void:
	var antes_do_primeiro: Dictionary = Maestria.obter_marco(4)
	assert(str(antes_do_primeiro["atual"]["nome"]) == "Aprendiz")
	assert(int(antes_do_primeiro["proximo"]["nivel"]) == 5)
	var golpe_refinado: Dictionary = Maestria.obter_marco(5)
	assert(str(golpe_refinado["atual"]["nome"]) == "Golpe Refinado")
	assert(int(golpe_refinado["desbloqueados"].size()) == 2)
	var tecnica_dominada: Dictionary = Maestria.obter_marco(20)
	assert(str(tecnica_dominada["atual"]["id"]) == "tecnica_dominada")
	var absoluta: Dictionary = Maestria.obter_marco(50)
	assert(str(absoluta["atual"]["id"]) == "maestria_absoluta")
	assert(absoluta["proximo"].is_empty())


func _testar_efeito_e_maestria_em_grupo() -> void:
	var perfil := {
		"personagemCriado":true,"nome":"Mestre de Armas",
		"vida":100,"vidaMaxima":100,"mana":20,"manaMaxima":20,
		"forca":12,"inteligencia":8,"agilidade":8,"vitalidade":8,"espirito":8,
		"equipamentos":{"mao_principal":"espada_ferro"}
	}
	var criatura := {
		"id":"alvo_maestria","nome":"Alvo de Treino","vida":1000,"vidaMaxima":1000,
		"ataque":1,"defesa":0,"agilidade":0,"manaMaxima":0,"poderMagico":0,
		"experienciaBase":1
	}
	var estado := Combate.criar_estado_grupo(perfil, [criatura, criatura.duplicate(true)])
	assert(not estado.is_empty(), "O combate em grupo para maestria deve iniciar.")
	var alvo_id := str(estado.get("alvoSelecionadoId", ""))
	var resultado: Dictionary = Combate.executar_rodada(estado, Combate.ACAO_ATAQUE, 54321, alvo_id)
	assert(bool(resultado.get("ok", false)), "O ataque básico em grupo deve ser aceito.")
	var estado_resultante: Dictionary = resultado.get("estado", {})
	assert(not estado_resultante.get("efeitoAtaqueArma", {}).is_empty(), "O ataque básico em grupo deve enviar o efeito visual da arma.")
	assert(str(estado_resultante.get("efeitoAtaqueArma", {}).get("armaId", "")) == "espada_ferro", "O efeito visual deve corresponder à arma equipada.")
	assert(int(estado_resultante.get("jogador", {}).get("armaMaestria", {}).get("experiencia", 0)) > 0, "Acertar no grupo deve conceder experiência de maestria.")
	assert(int(estado_resultante.get("jogador", {}).get("armaMaestria", {}).get("bonusDanoPercentual", 0)) == 0, "A primeira experiência não deve conceder bônus antes de subir de nível.")

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
	var efeito_raro: Dictionary = Combate._obter_efeito_ataque_arma("sandai_kitetsu", {"nivel":1})
	var efeito_lendario: Dictionary = Combate._obter_efeito_ataque_arma("wado_ichimonji", {"nivel":1})
	var efeito_mitico: Dictionary = Combate._obter_efeito_ataque_arma("gryphon", {"nivel":1})
	var efeito_supremo: Dictionary = Combate._obter_efeito_ataque_arma("yoru", {"nivel":1})
	assert(str(efeito_comum.get("raridade", "")) == "comum")
	assert(str(efeito_raro.get("raridade", "")) == "rara")
	assert(str(efeito_lendario.get("raridade", "")) == "lendaria")
	assert(str(efeito_mitico.get("raridade", "")) == "mitica")
	assert(str(efeito_supremo.get("raridade", "")) == "suprema")
	assert(float(efeito_comum["intensidadeVisual"]) < float(efeito_raro["intensidadeVisual"]), "Armas raras devem ter efeitos mais intensos que as comuns.")
	assert(float(efeito_raro["intensidadeVisual"]) < float(efeito_lendario["intensidadeVisual"]), "Armas lendárias devem ter efeitos mais intensos que as raras.")
	assert(float(efeito_lendario["intensidadeVisual"]) < float(efeito_mitico["intensidadeVisual"]), "Armas míticas devem ter efeitos mais intensos que as lendárias.")
	assert(float(efeito_mitico["intensidadeVisual"]) < float(efeito_supremo["intensidadeVisual"]), "Armas supremas devem ter efeitos mais intensos que as míticas.")
	assert(str(Combate._obter_efeito_ataque_arma("gryphon", {"nivel":1}).get("efeito", "")) == "haki_do_rei")
	assert(str(Combate._obter_efeito_ataque_arma("murakumogiri", {"nivel":1}).get("efeito", "")) == "tremor")
	assert(str(Combate._obter_efeito_ataque_arma("yoru", {"nivel":1}).get("efeito", "")) == "corte_negro")
