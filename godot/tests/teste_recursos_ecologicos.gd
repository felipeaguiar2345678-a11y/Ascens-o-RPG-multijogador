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
	var territorio := {"centro":{"x":100.0,"y":100.0},"raio":20.0}
	var cicatriz := [{"x":100.0,"y":100.0,"raio":100.0,"intensidade":1.0,"criadoUnix":1000,"expiraUnix":87400}]
	var pressao_inicial := Recursos.calcular_pressao_habitat(cicatriz, territorio, 1000)
	if pressao_inicial < 0.99:
		_falhar("A devastação não reduziu a oferta do habitat atingido."); return
	var pressao_distante := Recursos.calcular_pressao_habitat(cicatriz, {"centro":{"x":1000.0,"y":1000.0},"raio":20.0}, 1000)
	if pressao_distante != 0.0:
		_falhar("A devastação afetou o estoque de um habitat distante."); return
	var pressao_recuperacao := Recursos.calcular_pressao_habitat(cicatriz, territorio, 44200)
	if pressao_recuperacao >= pressao_inicial:
		_falhar("A oferta natural não começou a se recuperar com o terreno."); return
	var pressao_expirada := Recursos.calcular_pressao_habitat(cicatriz, territorio, 87400)
	if pressao_expirada != 0.0:
		_falhar("A cicatriz expirada continua reduzindo alimento."); return
	var duplicado := configs.duplicate(true)
	duplicado.append(configs[0].duplicate(true))
	if Recursos.validar_configuracoes(duplicado):
		_falhar("Aceitou duas fontes com o mesmo ID."); return
	var nan_config := configs.duplicate(true)
	nan_config[0]["capacidade"] = NAN
	if Recursos.validar_configuracoes(nan_config):
		_falhar("Aceitou capacidade NaN na configuração."); return
	var nan_recuperacao := configs.duplicate(true)
	nan_recuperacao[0]["recuperacaoPorDia"] = NAN
	if Recursos.validar_configuracoes(nan_recuperacao):
		_falhar("Aceitou recuperação NaN na configuração."); return
	var estado_corrompido := estado.duplicate(true)
	estado_corrompido["recursos"]["frutos_da_floresta"]["quantidade"] = NAN
	if Recursos.validar_estado(estado_corrompido, configs):
		_falhar("Aceitou estoque persistido com quantidade NaN."); return
	if bool(Recursos.processar_periodo(estado_corrompido, configs, "cervo_florestal", 1, 87400).get("ok", false)):
		_falhar("Processou estoque persistido corrompido."); return
	if bool(Recursos.consumir_unidades(estado_corrompido, configs, "frutos_da_floresta", "cervo_florestal", 1.0).get("ok", false)):
		_falhar("Permitiu consumo a partir de estoque corrompido."); return
	print("TESTE DE RECURSOS ECOLÓGICOS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE RECURSOS ECOLÓGICOS: " + mensagem)
	quit(1)
