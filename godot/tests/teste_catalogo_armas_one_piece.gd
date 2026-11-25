extends SceneTree

const Catalogo = preload("res://scripts/catalogo_armas_one_piece.gd")

func _initialize() -> void:
	var todas := Catalogo.listar_todas()
	if todas.size() != 49:
		_falhar("O catálogo deve conter 49 entradas, incluindo a Tripla Katana combinada.")
		return
	var esperadas := {"comum":11, "rara":14, "lendaria":13, "mitica":6, "suprema":5}
	for raridade in esperadas:
		var quantidade := 0
		for arma in todas:
			if str(arma.get("raridade", "")) == raridade:
				quantidade += 1
		if quantidade != int(esperadas[raridade]):
			_falhar("Quantidade incorreta na raridade " + raridade + ".")
			return
	var drops := Catalogo.listar_para_drop()
	if drops.size() != 48:
		_falhar("A Tripla Katana deve ser excluída dos drops.")
		return
	if not Catalogo.obter("gryphon").get("especialSupremo", false) or not Catalogo.obter("kikoku").get("especialSupremo", false):
		_falhar("Gryphon e Kikoku devem ser míticas com Especial Supremo.")
		return
	var incompleto := Catalogo.validar_receita_tripla({"wado_ichimonji":1, "sandai_kitetsu":1})
	if bool(incompleto.get("ok", true)):
		_falhar("A receita não pode aceitar apenas duas espadas.")
		return
	var completo := Catalogo.validar_receita_tripla({"wado_ichimonji":1, "sandai_kitetsu":1, "enma":1})
	if not bool(completo.get("ok", false)) or completo.get("consumir", []).size() != 3 or int(completo.get("equipamento", {}).get("quantidadeEspacosInventario", 0)) != 1:
		_falhar("A receita da Tripla Katana não validou as três espadas ou o espaço único.")
		return
	print("TESTE DO CATÁLOGO ONE PIECE: 49 armas, raridades, exclusão da Tripla dos drops e receita aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DO CATÁLOGO ONE PIECE: " + mensagem)
	quit(1)
