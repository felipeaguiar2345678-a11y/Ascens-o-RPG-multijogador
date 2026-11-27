extends SceneTree

const Interface = preload("res://scripts/interface_inventario_equipamentos.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var tela = Interface.new()
	root.add_child(tela)
	await process_frame
	tela._ao_receber_perfil({"uid":"teste","moedas":{"bronze":1250,"ferro":12,"ouro":3,"diamante":1,"jade":0},"inventario":[]})
	assert(tela.saldo_moedas.text.contains("Bronzhar ⛨: 1250"), "A carteira deve exibir o nome e símbolo de Bronzhar.")
	assert(tela.saldo_moedas.text.contains("Diamyr ◈: 1"), "A carteira deve exibir o nome e símbolo de Diamyr.")
	assert(tela.seletor_moeda.item_count == 4, "Jaderys não pode ser convertido para uma denominação superior.")
	assert(tela.seletor_moeda.get_item_text(0) == "Bronzhar ⛨", "O seletor deve usar o nome e símbolo aprovados.")
	assert(tela.quantidade_moeda.step == 100, "A interface deve selecionar múltiplos de 100.")
	print("TESTE DA CARTEIRA: saldo visível e opções de conversão manual aprovados.")
	quit(0)