extends SceneTree

const Interface = preload("res://scripts/interface_recompensas.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var interface = Interface.new()
	root.add_child(interface)
	interface._mostrar_eclosao({
		"nome":"Lobo Astral", "rank":"S", "raridade":"lendario",
		"vida":120, "vidaMaxima":120, "ataque":42, "defesa":25,
		"agilidade":31, "poderMagico":18,
		"habilidades":[{"id":"mordida_lunar","nome":"Mordida Lunar"}]
	}, "Eclosão concluída.")
	assert(interface.fundo.visible, "A revelação da eclosão deve abrir o painel.")
	assert(interface.nome_resultado.text == "Lobo Astral")
	assert(interface.detalhes.text.contains("RANK S"))
	interface._mostrar_roleta([
		{"nome":"Gema", "itemId":"gema", "obtido":true, "quantidade":2, "chanceFinal":1.0, "raridade":"raro"},
		{"nome":"Ovo", "itemId":"ovo", "obtido":false, "quantidade":0, "chanceFinal":0.04, "raridade":"comum"}
	])
	assert(interface.lista_resultados.get_child_count() == 2)
	assert(interface.lista_resultados.get_child(0).text.contains("girando"))
	print("TESTE DA INTERFACE DE RECOMPENSAS: eclosão e preparação da roleta aprovadas.")
	quit(0)
