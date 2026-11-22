extends SceneTree
const RepositorioCriaturas = preload("res://scripts/repositorio_criaturas_servidor.gd")
const RepositorioGrupos = preload("res://scripts/repositorio_grupos_criaturas_servidor.gd")
const MovimentoGrupos = preload("res://scripts/sistema_movimento_grupos.gd")

func _initialize() -> void:
	var sufixo := str(Time.get_ticks_usec())
	var repositorio_criaturas = RepositorioCriaturas.new("user://teste_especies_" + sufixo + ".json")
	var criatura := {
		"id":"especie_grupo_teste",
		"nome":"Lobo das Brumas",
		"descricao":"Espécie usada para testar grupos selvagens.",
		"rank":"C","raridade":"incomum","nivel":12,
		"vidaMaxima":240,"ataque":32,"defesa":18,"manaMaxima":20,
		"agilidade":28,"poderMagico":5,"experienciaBase":30,"perigo":20,
		"ecossistemaId":"floresta_arcana","bioma":"bosque_nevoento","habitat":"clareira",
		"habilidades":[],"chefe":false,
		"tabelaDrops":[{"itemId":"pelo_lobo","raridade":"comum","chance":0.4}],
		"ecologia":{
			"populacao":{"quantidadeInicial":4,"minima":2,"maxima":8,"nascimentosPorDia":2.0,"mortesPorDia":1.0},
			"populacaoMinimaParaLider":3,
			"equipamentosLider":["espada_ferro","peitoral_malha","anel_poder"],
			"territorio":{"grupoId":"alcateia_teste","centro":{"x":400.0,"y":300.0},"raio":80.0}
		}
	}
	if not bool(repositorio_criaturas.registrar_criatura_gerada(criatura).get("ok", false)):
		_falhar("Não registrou a espécie de teste."); return
	var caminho := "user://teste_grupos_" + sufixo + ".json"
	var grupos = RepositorioGrupos.new(caminho, repositorio_criaturas)
	var criado := grupos.criar_grupo_para_criatura("especie_grupo_teste", 1000)
	if not bool(criado.get("ok", false)):
		_falhar("Não criou grupo a partir da espécie registrada: " + str(criado.get("erro", ""))); return
	var grupo: Dictionary = criado["grupo"]
	if grupo["individuos"].size() != 4 or str(grupo["grupoId"]) != "alcateia_teste":
		_falhar("Quantidade inicial ou identidade do grupo incorreta."); return
	var ids := {}
	for individuo in grupo["individuos"]:
		var id := str(individuo.get("individuoId", ""))
		if id.is_empty() or ids.has(id) or not bool(individuo.get("vivo", false)):
			_falhar("Indivíduo inicial inválido ou duplicado."); return
		ids[id] = true
		var posicao: Dictionary = individuo["posicaoMundo"]
		if Vector2(posicao.x, posicao.y).distance_to(Vector2(400, 300)) > 80.01:
			_falhar("Indivíduo surgiu fora do território."); return
	if grupo["liderAtual"].is_empty():
		_falhar("Grupo elegível não recebeu líder natural."); return
	var movimento := MovimentoGrupos.avancar(grupo, 1.0, 54321)
	if not bool(movimento.get("ok", false)):
		_falhar("Não movimentou os indivíduos do grupo."); return
	grupo = movimento["grupo"]
	if not grupos.salvar_movimento_grupo("alcateia_teste", grupo["individuos"], 1001):
		_falhar("Não persistiu as posições atualizadas."); return
	var posicoes_invalidas: Array = grupo["individuos"].duplicate(true)
	var primeira_posicao: Dictionary = posicoes_invalidas[0]["posicaoMundo"]
	primeira_posicao["x"] = 1200.0
	posicoes_invalidas[0]["posicaoMundo"] = primeira_posicao
	if grupos.salvar_movimento_grupo("alcateia_teste", posicoes_invalidas, 1002):
		_falhar("Aceitou movimento fora do território."); return
	var duplicado := grupos.criar_grupo_para_criatura("especie_grupo_teste", 1000)
	if bool(duplicado.get("ok", false)):
		_falhar("Permitiu criar grupo duplicado."); return
	var avancado := grupos.avancar_grupo("alcateia_teste", 87400, 1.0)
	if not bool(avancado.get("ok", false)):
		_falhar("Falhou ao avançar a população."); return
	if int(avancado.get("quantidade", -1)) != 5 or int(avancado.get("nascimentos", 0)) != 2 or int(avancado.get("mortesNaturais", 0)) != 1:
		_falhar("Nascimentos e mortes não foram refletidos nos indivíduos."); return
	grupo = grupos.obter_grupo("alcateia_teste")
	var vivos := 0
	for individuo in grupo["individuos"]:
		if bool(individuo.get("vivo", true)):
			vivos += 1
	if vivos != 5:
		_falhar("Quantidade de indivíduos vivos não corresponde ao estado populacional."); return
	var lider_id := str(grupo["liderAtual"].get("individuoId", ""))
	if lider_id.is_empty():
		_falhar("Grupo deveria manter líder antes do teste de combate."); return
	var morte := grupos.aplicar_dano_ecologico("alcateia_teste", lider_id, 100000, 87401)
	if not bool(morte.get("ok", false)) or not bool(morte.get("morreu", false)):
		_falhar("Dano ecológico letal não foi aplicado."); return
	var grupo_apos_combate: Dictionary = grupos.obter_grupo("alcateia_teste")
	if int(grupo_apos_combate["populacaoEstado"]["quantidade"]) != 4:
		_falhar("Morte ecológica não reduziu a população."); return
	if str(grupo_apos_combate["liderAtual"].get("individuoId", "")) == lider_id:
		_falhar("Líder morto não foi substituído."); return
	var reaberto = RepositorioGrupos.new(caminho, repositorio_criaturas)
	if reaberto.obter_grupo("alcateia_teste").is_empty():
		_falhar("Grupo não persistiu após reabrir o repositório."); return
	print("TESTE DE GRUPOS SELVAGENS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE GRUPOS SELVAGENS: " + mensagem)
	quit(1)
