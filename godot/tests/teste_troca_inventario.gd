extends SceneTree

const Repositorio = preload("res://scripts/repositorio_personagem_servidor.gd")

func _initialize() -> void:
	var repositorio = Repositorio.new()
	var modelo := {"itemId":"madeira_arcana","nome":"Madeira Arcana","categoria":"material","raridade":"rara","quantidade":1}

	# Uma pilha parcialmente ocupada deve ser completada e o excedente separado.
	var inventario := [{"itemId":"madeira_arcana","nome":"Madeira Arcana","categoria":"material","raridade":"rara","quantidade":900}]
	repositorio._adicionar_item_transferido(inventario, modelo, 250)
	if inventario.size() != 2 or int(inventario[0].get("quantidade", 0)) != 999 or int(inventario[1].get("quantidade", 0)) != 151:
		_falhar("A transferência não dividiu o excedente quando a primeira pilha chegou a 999.")
		return

	# Quando existem várias pilhas, todas devem ser preenchidas antes de criar outra.
	var varias_pilhas := [
		{"itemId":"madeira_arcana","nome":"Madeira Arcana","categoria":"material","raridade":"rara","quantidade":800},
		{"itemId":"madeira_arcana","nome":"Madeira Arcana","categoria":"material","raridade":"rara","quantidade":950}
	]
	repositorio._adicionar_item_transferido(varias_pilhas, modelo, 300)
	if varias_pilhas.size() != 3 or int(varias_pilhas[0].get("quantidade", 0)) != 999 or int(varias_pilhas[1].get("quantidade", 0)) != 999 or int(varias_pilhas[2].get("quantidade", 0)) != 52:
		_falhar("O excedente não foi distribuído entre as pilhas existentes e uma nova pilha.")
		return

	var total := 0
	for pilha in varias_pilhas:
		var quantidade := int(pilha.get("quantidade", 0))
		if quantidade < 1 or quantidade > 999:
			_falhar("Uma pilha ficou fora do limite permitido de 1 a 999.")
			return
		total += quantidade
	if total != 2050:
		_falhar("A quantidade total de itens foi alterada durante a distribuição.")
		return

	print("TESTE DE TROCA DE INVENTÁRIO: limite de pilha, excedentes e conservação da quantidade aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE TROCA DE INVENTÁRIO: " + mensagem)
	quit(1)
