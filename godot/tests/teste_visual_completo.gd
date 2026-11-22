extends SceneTree

const Tema = preload("res://scripts/tema_visual.gd")
const Palco = preload("res://scripts/palco_combate.gd")

func _initialize() -> void:
	var tema := Tema.criar_tema()
	if tema == null:
		_falhar("O tema global não foi criado.")
		return
	var arena := Palco.new()
	root.add_child(arena)
	arena.size = Vector2(640, 112)
	arena.configurar({"nome":"Aventureiro"}, {"nome":"Fera Arcana","chefe":true})
	arena.registrar_evento("A Fera Arcana desfere um golpe!")
	if arena.nome_heroi != "Aventureiro" or arena.nome_inimigo != "Fera Arcana" or not arena.chefe:
		_falhar("A arena não recebeu os dados dos combatentes.")
		return
	await process_frame
	print("TESTE VISUAL COMPLETO: tema global e palco de combate aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE VISUAL COMPLETO: " + mensagem)
	quit(1)
