extends SceneTree
const Recursos = preload("res://scripts/sistema_recursos_ecologicos.gd")
const RepositorioRecursos = preload("res://scripts/repositorio_recursos_ecologicos_servidor.gd")

class CatalogoCriaturasTeste:
	extends RefCounted
	func listar_todas_as_criaturas_catalogadas() -> Array:
		return [{
			"ecologia": {
				"recursosAmbientais": [{
					"id":"frutos_da_floresta","capacidade":100.0,"quantidadeInicial":20.0,
					"recuperacaoPorDia":10.0,"consumoPorIndividuoDia":2.0,
					"especiesConsumidoras":["cervo_florestal"]
				}]
			}
		}]

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
	var fonte_inesperada := estado.duplicate(true)
	fonte_inesperada["recursos"]["fonte_nao_declarada"] = {"quantidade": 10.0, "ultimaAtualizacaoUnix": 1000}
	if Recursos.validar_estado(fonte_inesperada, configs):
		_falhar("Aceitou fonte ambiental que não existe no catálogo."); return
	if bool(Recursos.processar_periodo(estado_corrompido, configs, "cervo_florestal", 1, 87400).get("ok", false)):
		_falhar("Processou estoque persistido corrompido."); return
	if bool(Recursos.consumir_unidades(estado_corrompido, configs, "frutos_da_floresta", "cervo_florestal", 1.0).get("ok", false)):
		_falhar("Permitiu consumo a partir de estoque corrompido."); return
	# O servidor pode ficar desligado por três dias: os estoques devem
	# recuperar e alimentar a população pelo intervalo real, sem duplicação.
	var caminho_offline := "user://teste_recursos_offline_tres_dias.json"
	for sufixo in ["", ".bak", ".tmp"]:
		var alvo_arquivo: String = caminho_offline + str(sufixo)
		if FileAccess.file_exists(alvo_arquivo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(alvo_arquivo))
	var repositorio_offline := RepositorioRecursos.new(caminho_offline, CatalogoCriaturasTeste.new())
	var grupo_consumidor := {"grupoId":"cervos_teste","especieId":"cervo_florestal","territorio":{"centro":{"x":100.0,"y":100.0},"raio":30.0},"individuos":[]}
	for indice in range(5):
		grupo_consumidor["individuos"].append({"vivo":true})
	var inicializacao_offline := repositorio_offline.processar_tick([grupo_consumidor], 1000)
	if not bool(inicializacao_offline.get("ok", false)):
		_falhar("Não inicializou o relógio persistente do recurso offline."); return
	var recuperacao_tres_dias := repositorio_offline.processar_tick([grupo_consumidor], 1000 + 3 * 86400)
	if not bool(recuperacao_tres_dias.get("ok", false)) or absf(float(recuperacao_tres_dias.get("diasProcessados", 0.0)) - 3.0) > 0.001:
		_falhar("O estoque ecológico não recuperou os três dias de ausência."); return
	var estoque_recuperado: Dictionary = recuperacao_tres_dias.get("estoques", {}).get("frutos_da_floresta", {})
	if absf(float(estoque_recuperado.get("quantidade", -1.0)) - 20.0) > 0.001:
		_falhar("A recuperação e o consumo da população durante os três dias foram calculados incorretamente."); return
	var repeticao_offline := repositorio_offline.processar_tick([grupo_consumidor], 1000 + 3 * 86400)
	if not bool(repeticao_offline.get("ok", false)) or float(repeticao_offline.get("diasProcessados", -1.0)) != 0.0 or absf(float(repeticao_offline.get("estoques", {}).get("frutos_da_floresta", {}).get("quantidade", -1.0)) - 20.0) > 0.001:
		_falhar("O mesmo intervalo de três dias foi aplicado duas vezes ao estoque."); return
	for sufixo in ["", ".bak", ".tmp"]:
		var alvo_limpeza: String = caminho_offline + str(sufixo)
		if FileAccess.file_exists(alvo_limpeza):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(alvo_limpeza))
	var caminho_estado_vazio := "user://teste_recursos_estado_vazio.json"
	if FileAccess.file_exists(caminho_estado_vazio):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_estado_vazio))
	var texto_estado_vazio := JSON.stringify({"versao": 1, "estado": {}})
	var arquivo_vazio := FileAccess.open(caminho_estado_vazio, FileAccess.WRITE)
	arquivo_vazio.store_string(texto_estado_vazio)
	arquivo_vazio.close()
	var repositorio := RepositorioRecursos.new(caminho_estado_vazio, CatalogoCriaturasTeste.new())
	var processamento_vazio := repositorio.processar_tick([], 2000)
	if bool(processamento_vazio.get("ok", false)):
		_falhar("Reinicializou um arquivo persistido com estado vazio."); return
	var leitura_preservada := FileAccess.open(caminho_estado_vazio, FileAccess.READ)
	var conteudo_preservado := leitura_preservada.get_as_text()
	leitura_preservada.close()
	if conteudo_preservado != texto_estado_vazio:
		_falhar("Sobrescreveu o arquivo ecológico vazio/corrompido."); return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_estado_vazio))
	print("TESTE DE RECURSOS ECOLÓGICOS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE RECURSOS ECOLÓGICOS: " + mensagem)
	quit(1)
