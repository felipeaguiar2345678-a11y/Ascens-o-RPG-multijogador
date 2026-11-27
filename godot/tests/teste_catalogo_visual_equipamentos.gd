extends SceneTree

const Catalogo = preload("res://scripts/catalogo_visual_equipamentos.gd")
const Sistema = preload("res://scripts/sistema_equipamentos.gd")

func _initialize() -> void:
	var ids: Array = Catalogo.listar_ids()
	if ids.size() < 80:
		_falhar("O catálogo visual não cobre todos os itens cadastrados. Encontrados: %d" % ids.size())
		return
	for id_bruto in ids:
		var item_id := str(id_bruto)
		if Catalogo.obter_caminho_miniatura(item_id).is_empty():
			_falhar("Item sem caminho de miniatura: " + item_id)
			return
		if Catalogo.obter_caminho_equipado(item_id).is_empty():
			_falhar("Item sem caminho de arte equipada: " + item_id)
			return
		if Sistema.obter(item_id).is_empty():
			_falhar("ID visual sem item correspondente no sistema de equipamentos: " + item_id)
			return
	print("TESTE CATÁLOGO VISUAL: %d itens possuem ID funcional e caminhos individuais para inventário e equipamento." % ids.size())
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE CATÁLOGO VISUAL: " + mensagem)
	quit(1)
