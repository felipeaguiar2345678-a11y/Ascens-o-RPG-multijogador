extends SceneTree
const Recursos = preload("res://scripts/sistema_recursos_ecologicos.gd")

func _initialize() -> void:
	var configs := [{
		"id":"frutos_da_floresta","capacidade":100.0,"quantidadeInicial":20.0,
		"recuperacaoPorDia":10.0,"consumoPorIndividuoDia":2.0,
		"especiesConsumidoras":["cervo_florestal","raposa"]
	}]
	if not Recursos.validar_configuracoes(configs):
		_falhar("Configuração ambiental válida foi rejeitada."); return
	var estado := Recursos.criar_estado(configs, 1000)
	var proibido := Recursos.consumir_unidades(estado, configs, "frutos_da_floresta", "lobo", 1.0)
	if bool(proibido.get("ok", false)):
		_falhar("Espécie sem dieta declarada consumiu o recurso."); return
	var consumo := Recursos.consumir_unidades(estado, configs, "frutos_da_floresta", "cervo_florestal", 5.0)
	if not bool(consumo.get("ok", false)) or absf(float(consumo["estado"]["recursos"]["frutos_da_floresta"]["quantidade"]) - 15.0) > 0.001:
		_falhar("Consumo autorizado não foi descontado."); return
	var periodo := Recursos.processar_periodo(estado, configs, "cervo_florestal", 5, 87400)
	if not bool(periodo.get("ok", false)):
		_falhar("Avanço do recurso falhou."); return
	var fonte: Dictionary = periodo["estado"]["recursos"]["frutos_da_floresta"]
	if absf(float(fonte["quantidade"]) - 20.0) > 0.001:
		_falhar("Recuperação e consumo do período foram calculados incorretamente."); return
	if float(periodo["disponibilidade"]) < 0.99:
		_falhar("Oferta suficiente não foi reconhecida."); return
	var insuficiente := Recursos.consumir_unidades(estado, configs, "frutos_da_floresta", "raposa", 1000.0)
	if bool(insuficiente.get("ok", false)):
		_falhar("Permitiu consumir mais do que o estoque disponível."); return
	var duplicado := configs.duplicate(true)
	duplicado.append(configs[0].duplicate(true))
	if Recursos.validar_configuracoes(duplicado):
		_falhar("Aceitou duas fontes com o mesmo ID."); return
	print("TESTE DE RECURSOS ECOLÓGICOS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE RECURSOS ECOLÓGICOS: " + mensagem)
	quit(1)
