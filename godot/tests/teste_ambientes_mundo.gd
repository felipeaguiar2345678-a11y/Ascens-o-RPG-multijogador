extends SceneTree
const Ambientes = preload("res://scripts/sistema_ambientes_mundo.gd")

func _initialize() -> void:
	var lago := Ambientes.obter_contexto(Vector2(1530, 820))
	if str(lago.get("habitat", "")) != "agua_doce" or str(lago.get("ecossistemaId", "")) != "central":
		_falhar("O lago não foi identificado como habitat de água doce.")
		return
	var montanha := Ambientes.obter_contexto(Vector2(1780, 580))
	if str(montanha.get("ecossistemaId", "")) != "montanhas_gelidas" or int(montanha.get("altitude", 0)) <= 0:
		_falhar("A altitude e o ecossistema das montanhas não foram reconhecidos.")
		return
	var pantano := Ambientes.obter_contexto(Vector2(1870, 1440))
	if str(pantano.get("habitat", "")) != "agua_pantanosa":
		_falhar("A lagoa do pântano não foi reconhecida como ambiente aquático.")
		return
	var floresta := Ambientes.obter_contexto(Vector2(400, 900))
	if str(floresta.get("ecossistemaId", "")) != "floresta_arcana":
		_falhar("A floresta não foi identificada no ecossistema correto.")
		return
	var deserto := Ambientes.obter_contexto(Vector2(650, 1740))
	if str(deserto.get("ecossistemaId", "")) != "deserto_ancestral":
		_falhar("As dunas não foram identificadas no ecossistema correto.")
		return
	var planicie := Ambientes.obter_contexto(Vector2(1200, 1520))
	if str(planicie.get("ecossistemaId", "")) != "central":
		_falhar("A região central/sul não foi classificada como planície.")
		return
	if not Ambientes.obter_contexto(Vector2(-1, 10)).is_empty():
		_falhar("Uma posição fora do mundo recebeu ambiente.")
		return
	if not Ambientes.obter_contexto(Vector2(1200, 100)).is_empty():
		_falhar("O oceano externo recebeu uma classificação terrestre.")
		return
	print("TESTE DE AMBIENTES DO MUNDO: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE AMBIENTES DO MUNDO: " + mensagem)
	quit(1)
