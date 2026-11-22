extends SceneTree

const Tema = preload("res://scripts/tema_visual.gd")
const Palco = preload("res://scripts/palco_combate.gd")
const CriaturaVisual = preload("res://scripts/criatura_errante_visual.gd")

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
	var criatura := CriaturaVisual.new()
	root.add_child(criatura)
	criatura.configurar({
		"nome":"Draco das Cinzas",
		"especieId":"dragao",
		"habitat":"montanhas",
		"bioma":"gelido",
		"chefe":true,
		"lider":true,
		"mutacoes":[{"id":"chifres_de_guerra"}]
	})
	if criatura.especie_id != "dragao" or criatura.habitat != "montanhas" or not criatura.eh_chefe:
		_falhar("A criatura não preservou espécie, habitat e identidade de chefe.")
		return
	await process_frame
	print("TESTE VISUAL COMPLETO: tema, arena e silhueta ecológica aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE VISUAL COMPLETO: " + mensagem)
	quit(1)
