extends SceneTree

const Catalogo = preload("res://scripts/catalogo_visual_equipamentos.gd")
const Sistema = preload("res://scripts/sistema_equipamentos.gd")
const ArmasOnePiece = preload("res://scripts/catalogo_armas_one_piece.gd")

func _initialize() -> void:
	var ids: Array = Catalogo.listar_ids()
	if ids.size() < 80:
		_falhar("O catálogo visual não cobre todos os itens cadastrados. Encontrados: %d" % ids.size())
		return
	for id in ids:
		if Catalogo.obter_caminho_miniatura(str(id)).is_empty():
			_falhar("Item sem caminho de miniatura: " + str(id))
			return
		if Catalogo.obter_caminho_equipado(str(id)).is_empty():
			_falhar("Item sem caminho de arte equipada: " + str(id))
			return
	for item_id in ["espada_ferro", "escudo_aco", "peitoral_placas", "anel_poder", "kikoku", "gryphon", "tripla_katana"]:
		if Sistema.obter(item_id).is_empty():
			_falhar("Item do catálogo não resolve no sistema de equipamentos: " + item_id)
			return
	print("TESTE CATÁLOGO VISUAL: %d itens possuem caminhos individuais para inventário e equipamento." % ids.size())
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE CATÁLOGO VISUAL: " + mensagem)
	quit(1)
