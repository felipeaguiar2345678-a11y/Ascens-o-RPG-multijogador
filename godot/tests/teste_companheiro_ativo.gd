extends SceneTree

const CENA_COMPANHEIRO = preload("res://scenes/companheiro.tscn")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var companheiro = CENA_COMPANHEIRO.instantiate()
	root.add_child(companheiro)
	companheiro.configurar_companheiro({
		"id":"companheiro_teste", "nome":"Lobo Astral", "nivel":4,
		"raridade":"raro", "agilidade":100
	})
	assert(companheiro.velocidade >= 280.0, "A agilidade deve influenciar a velocidade de seguimento.")
	assert(companheiro.distancia_seguimento >= 25.0)
	var corpo := companheiro.get_node("CorpoProvisorio") as Polygon2D
	assert(corpo != null and corpo.color == Color("#72b7ed"), "A raridade rara deve refletir-se na identidade visual.")
	companheiro.queue_free()
	print("TESTE DO COMPANHEIRO ATIVO: velocidade, seguimento e cor de raridade aprovados.")
	quit(0)
