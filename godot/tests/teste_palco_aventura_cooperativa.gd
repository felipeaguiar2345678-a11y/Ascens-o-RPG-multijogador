extends SceneTree

const Palco = preload("res://scripts/palco_aventura_compartilhada.gd")

func _initialize() -> void:
	var palco := Palco.new()
	root.add_child(palco)
	palco.size = Vector2(640, 205)
	var participantes := [
		{"nome":"Aventureiro Um","visual":{"racaId":"humano","nivel":12,"vida":80,"vidaMaxima":100,"mana":40,"manaMaxima":50,"anatomiaRacial":{},"equipamentos":{}}},
		{"nome":"Aventureira Dois","visual":{"racaId":"elfo","nivel":18,"vida":65,"vidaMaxima":90,"mana":70,"manaMaxima":80,"anatomiaRacial":{"orelhas":"elficas_pontudas"},"equipamentos":{"torso":"armadura_arcana"}}},
		{"nome":"Aventureiro Três","visual":{"racaId":"orc","nivel":7,"vida":30,"vidaMaxima":60,"mana":10,"manaMaxima":20,"anatomiaRacial":{},"equipamentos":{}}},
		{"nome":"Aventureiro Quatro","visual":{"racaId":"draconiano","nivel":22,"vida":120,"vidaMaxima":120,"mana":25,"manaMaxima":40,"anatomiaRacial":{"chifres":"draconicos"},"equipamentos":{}}},
		{"nome":"Excedente","visual":{"racaId":"humano"}}
	]
	palco.configurar_participantes(participantes)
	palco.configurar_encontro({"ativo":true,"id":"sentinela","nome":"Sentinela do Bosque","rank":"C","nivel":12,"vidaAtual":180,"vidaMaxima":240})
	if str(palco._encontro.get("nome", "")) != "Sentinela do Bosque":
		_falhar("O palco não recebeu o encontro sincronizado.")
		return
	await process_frame
	if palco._avatares.size() != 4:
		_falhar("O palco não limitou a formação visual a quatro membros.")
		return
	if palco._nomes.size() != 4 or palco._nomes[1] != "Aventureira Dois":
		_falhar("Os nomes dos participantes não foram preservados.")
		return
	for avatar in palco._avatares:
		if str(avatar.get("raca_id")).is_empty():
			_falhar("Um avatar do grupo não recebeu a raça.")
			return
	palco.configurar_encontro({})
	if not palco._encontro.is_empty():
		_falhar("O palco manteve um encontro após a limpeza do estado.")
		return
	palco.configurar_participantes([])
	if not palco._avatares.is_empty():
		_falhar("O palco manteve avatares depois de esvaziar o grupo.")
		return
	print("TESTE DO PALCO COOPERATIVO: formação visual, limite de grupo e limpeza aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DO PALCO COOPERATIVO: " + mensagem)
	quit(1)
