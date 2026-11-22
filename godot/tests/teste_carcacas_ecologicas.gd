extends SceneTree
const RepositorioCriaturas = preload("res://scripts/repositorio_criaturas_servidor.gd")
const RepositorioGrupos = preload("res://scripts/repositorio_grupos_criaturas_servidor.gd")
const SistemaLiderNato = preload("res://scripts/sistema_lider_nato.gd")

func _initialize() -> void:
	var rendimento_normal := SistemaLiderNato.calcular_rendimento_carcaca(4.0, 1.0, false)
	var rendimento_nato := SistemaLiderNato.calcular_rendimento_carcaca(4.0, 1.0, true)
	if not is_equal_approx(float(rendimento_normal["quantidade"]), 4.0):
		_falhar("A carcaça normal foi alterada pelo bônus de líder nato."); return
	if not is_equal_approx(float(rendimento_nato["quantidade"]), 6.0) or not is_equal_approx(float(rendimento_nato["decomposicaoPorDia"]), 1.5) or str(rendimento_nato["qualidade"]) != "superior":
		_falhar("A carcaça do líder nato não forneceu 50% mais alimento às outras espécies."); return
	var sufixo := str(Time.get_ticks_usec())
	var criaturas = RepositorioCriaturas.new("user://teste_catalogo_carcacas_" + sufixo + ".json")
	var grupos = RepositorioGrupos.new("user://teste_grupos_carcacas_" + sufixo + ".json", criaturas)
	var presa := _criar_especie("presa_carcaca", "grupo_presa_carcaca", {})
	presa["ecologia"]["carcaca"] = {"unidades":4.0,"decomposicaoPorDia":1.0}
	var necrófago := _criar_especie("necro_carcaca", "grupo_necro_carcaca", {
		"especiesNecrófagas":["presa_carcaca"],
		"consumoCarcacaPorIndividuoDia":3.0
	})
	if not bool(criaturas.registrar_criatura_gerada(presa).get("ok", false)):
		_falhar("Não registrou a espécie que gera carcaças."); return
	if not bool(criaturas.registrar_criatura_gerada(necrófago).get("ok", false)):
		_falhar("Não registrou a dieta necrófaga."); return
	var grupo_presa := grupos.criar_grupo_para_criatura("presa_carcaca", 1000)
	var grupo_necro := grupos.criar_grupo_para_criatura("necro_carcaca", 1000)
	if not bool(grupo_presa.get("ok", false)) or not bool(grupo_necro.get("ok", false)):
		_falhar("Não criou os grupos ecológicos de teste."); return
	var individuo_presa: Dictionary = grupo_presa["grupo"]["individuos"][0]
	var morte := grupos.aplicar_dano_ecologico("grupo_presa_carcaca", str(individuo_presa["individuoId"]), 100000, 1000)
	if not bool(morte.get("ok", false)) or not bool(morte.get("morreu", false)):
		_falhar("A morte não gerou uma carcaça persistente."); return
	var ciclo := grupos.processar_carcacas_ecologicas(87400)
	if not bool(ciclo.get("ok", false)):
		_falhar("Falhou ao processar decomposição e consumo."); return
	var disponibilidade: Dictionary = ciclo.get("disponibilidadePorEspecie", {})
	if absf(float(disponibilidade.get("necro_carcaca", -1.0)) - 0.5) > 0.001:
		_falhar("A competição não calculou a oferta limitada de carcaça."); return
	var grupo_salvo := grupos.obter_grupo("grupo_presa_carcaca")
	var individuo_salvo: Dictionary = grupo_salvo["individuos"][0]
	var carcaca: Dictionary = individuo_salvo.get("carcaca", {})
	if absf(float(carcaca.get("quantidade", -1.0))) > 0.001:
		_falhar("A carcaça não foi consumida pela demanda combinada."); return
	var reaberto = RepositorioGrupos.new("user://teste_grupos_carcacas_" + sufixo + ".json", criaturas)
	if absf(float(reaberto.obter_grupo("grupo_presa_carcaca")["individuos"][0]["carcaca"]["quantidade"])) > 0.001:
		_falhar("O consumo da carcaça não persistiu após reabrir o repositório."); return
	var sem_alimento := reaberto.processar_carcacas_ecologicas(87400)
	if absf(float(sem_alimento["disponibilidadePorEspecie"].get("necro_carcaca", -1.0))) > 0.001:
		_falhar("O necrófago recebeu alimento mesmo sem carcaças disponíveis."); return
	print("TESTE DE CARCAÇAS ECOLÓGICAS: aprovado.")
	quit(0)

func _criar_especie(id: String, grupo_id: String, dieta: Dictionary) -> Dictionary:
	var ecologia := {
		"populacao":{"quantidadeInicial":2,"minima":0,"maxima":8,"nascimentosPorDia":0.0,"mortesPorDia":0.0},
		"territorio":{"grupoId":grupo_id,"centro":{"x":100.0,"y":100.0},"raio":50.0}
	}
	for chave in dieta:
		ecologia[chave] = dieta[chave]
	return {
		"id":id,"nome":id,"descricao":"Espécie de teste de carcaças.","rank":"E","raridade":"comum",
		"nivel":1,"vidaMaxima":20,"ataque":2,"defesa":2,"manaMaxima":0,"agilidade":3,
		"poderMagico":0,"experienciaBase":1,"perigo":1,"ecossistemaId":"floresta_arcana",
		"bioma":"bosque","habitat":"clareira","habilidades":[],"chefe":false,"tabelaDrops":[],
		"ecologia":ecologia
	}

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE CARCAÇAS ECOLÓGICAS: " + mensagem)
	quit(1)
