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
			"territorio":{"grupoId":"alcateia_teste","centro":{"x":400.0,"y":300.0},"raio":80.0},
			"rotasMigracao":[{"id":"rota_refugio_teste","ecossistemaId":"floresta_arcana","bioma":"bosque_refugio","habitat":"vale_seguro","territorio":{"grupoId":"alcateia_refugio","centro":{"x":800.0,"y":700.0},"raio":90.0}}]
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
	var fuga := grupos.fugir_da_devastacao("alcateia_teste", Vector2(400.0,300.0), 30.0, 87401)
	if not bool(fuga.get("ok", false)) or not bool(fuga.get("fugiu", false)):
		_falhar("O grupo não migrou coletivamente para um habitat seguro."); return
	grupo = grupos.obter_grupo("alcateia_teste")
	if str(grupo.get("bioma", "")) != "bosque_refugio" or grupo.get("retornoDevastacao", {}).is_empty():
		_falhar("A migração não preservou o habitat de origem para retorno."); return
	var marca_ainda_ativa := [{"x":400.0,"y":300.0,"raio":30.0,"expiraUnix":90000}]
	var retorno_bloqueado := grupos.retornar_da_devastacao("alcateia_teste", marca_ainda_ativa, 87402)
	if not bool(retorno_bloqueado.get("ok", false)) or bool(retorno_bloqueado.get("retornou", false)):
		_falhar("O grupo retornou enquanto o território ainda estava devastado."); return
	var retorno_sem_alimento := grupos.retornar_da_devastacao("alcateia_teste", [], 90000, 0.2)
	if not bool(retorno_sem_alimento.get("ok", false)) or bool(retorno_sem_alimento.get("retornou", false)) or str(retorno_sem_alimento.get("motivo", "")) != "alimento_insuficiente":
		_falhar("Grupo retornou a um habitat ainda sem oferta alimentar suficiente."); return
	var retorno := grupos.retornar_da_devastacao("alcateia_teste", [], 90001, 0.9)
	if not bool(retorno.get("ok", false)) or not bool(retorno.get("retornou", false)):
		_falhar("O grupo não retomou o território após a recuperação."); return
	grupo = grupos.obter_grupo("alcateia_teste")
	if str(grupo.get("bioma", "")) != "bosque_nevoento" or not grupo.get("retornoDevastacao", {}).is_empty():
		_falhar("O grupo não restaurou o habitat original corretamente."); return
	var duplicado := grupos.criar_grupo_para_criatura("especie_grupo_teste", 1000)
	if bool(duplicado.get("ok", false)):
		_falhar("Permitiu criar grupo duplicado."); return
	var avancado := grupos.avancar_grupo("alcateia_teste", 87400, 1.0)
	if not bool(avancado.get("ok", false)):
		_falhar("Falhou ao avançar a população."); return
	if int(avancado.get("quantidade", -1)) != 4 or int(avancado.get("nascimentos", 0)) != 1 or int(avancado.get("mortesNaturais", 0)) != 1:
		_falhar("Nascimentos e mortes não foram refletidos nos indivíduos."); return
	grupo = grupos.obter_grupo("alcateia_teste")
	var vivos := 0
	for individuo in grupo["individuos"]:
		if bool(individuo.get("vivo", true)):
			vivos += 1
	if vivos != 4:
		_falhar("Quantidade de indivíduos vivos não corresponde ao estado populacional."); return
	var lider_id := str(grupo["liderAtual"].get("individuoId", ""))
	if lider_id.is_empty():
		_falhar("Grupo deveria manter líder antes do teste de combate."); return
	var morte := grupos.aplicar_dano_ecologico("alcateia_teste", lider_id, 100000, 87401)
	if not bool(morte.get("ok", false)) or not bool(morte.get("morreu", false)):
		_falhar("Dano ecológico letal não foi aplicado."); return
	var grupo_apos_combate: Dictionary = grupos.obter_grupo("alcateia_teste")
	if int(grupo_apos_combate["populacaoEstado"]["quantidade"]) != 3:
		_falhar("Morte ecológica não reduziu a população."); return
	if str(grupo_apos_combate["liderAtual"].get("individuoId", "")) == lider_id:
		_falhar("Líder morto não foi substituído."); return
	var reaberto = RepositorioGrupos.new(caminho, repositorio_criaturas)
	var grupo_atual: Dictionary = reaberto.obter_grupo("alcateia_teste")
	var individuo_para_domesticar := ""
	for membro in grupo_atual.get("individuos", []):
		if bool(membro.get("vivo", true)):
			individuo_para_domesticar = str(membro.get("individuoId", ""))
			break
	var derrota_jogador := reaberto.registrar_derrota_em_combate("alcateia_teste", individuo_para_domesticar, "uid_teste", 87402)
	if not bool(derrota_jogador.get("ok", false)):
		_falhar("Não registrou criatura derrotada por jogador: " + str(derrota_jogador.get("erro", ""))); return
	var domesticar := reaberto.registrar_domesticacao_individuo("alcateia_teste", individuo_para_domesticar, 87403)
	if not bool(domesticar.get("ok", false)):
		_falhar("Não permitiu domesticar corpo derrotado: " + str(domesticar.get("erro", ""))); return
	if reaberto.obter_grupo("alcateia_teste").is_empty():
		_falhar("Grupo não persistiu após reabrir o repositório."); return
	var especie_aliada: Dictionary = criatura.duplicate(true)
	especie_aliada["id"] = "especie_aliada_teste"
	especie_aliada["nome"] = "Lobo Aliado"
	especie_aliada["ecologia"]["territorio"] = {"grupoId":"alcateia_aliada_teste","centro":{"x":430.0,"y":300.0},"raio":70.0}
	if not bool(repositorio_criaturas.registrar_criatura_gerada(especie_aliada).get("ok", false)):
		_falhar("Não registrou espécie aliada."); return
	var aliado_criado := reaberto.criar_grupo_para_criatura("especie_aliada_teste", 1000)
	if not bool(aliado_criado.get("ok", false)):
		_falhar("Não criou grupo aliado."); return
	var social := reaberto.registrar_interacao_social("alcateia_teste", "alcateia_aliada_teste", "cooperacao", 91000)
	if not bool(social.get("ok", false)):
		_falhar("Não registrou relação social para teste de alerta."); return
	var social_cultura_1 := reaberto.registrar_interacao_social("alcateia_teste", "alcateia_aliada_teste", "cooperacao", 92000)
	var social_cultura_2 := reaberto.registrar_interacao_social("alcateia_teste", "alcateia_aliada_teste", "cooperacao", 92001)
	var social_cultura_3 := reaberto.registrar_interacao_social("alcateia_teste", "alcateia_aliada_teste", "cooperacao", 92002)
	if not bool(social_cultura_1.get("ok", false)) or not bool(social_cultura_2.get("ok", false)) or not bool(social_cultura_3.get("ok", false)):
		_falhar("Não registrou experiências para formar tradição cultural."); return
	var grupo_cultural_reacao: Dictionary = reaberto.obter_grupo("alcateia_teste")
	grupo_cultural_reacao["culturaGrupo"] = {"tradicoes":[
		{"id":"vigilia_coletiva","forca":4,"criadaUnix":93000,"ultimaPraticaUnix":93000},
		{"id":"defesa_territorial","forca":3,"criadaUnix":93000,"ultimaPraticaUnix":93000}
	],"geracao":2}
	if reaberto._forca_tradicao_cultural(grupo_cultural_reacao, "vigilia_coletiva", 93001) != 4:
		_falhar("Tradição recente não foi reconhecida pelo sistema de comportamento."); return
	if reaberto._forca_tradicao_cultural(grupo_cultural_reacao, "vigilia_coletiva", 93000 + 1209601) != 0:
		_falhar("Tradição abandonada continuou ativa após o prazo de adaptação."); return
	var cultura_teste: Dictionary = reaberto.obter_grupo("alcateia_teste").get("culturaGrupo", {})
	var encontrou_tradicao := false
	for tradicao in cultura_teste.get("tradicoes", []):
		if str(tradicao.get("id", "")) == "caca_cooperativa":
			encontrou_tradicao = true
	if not encontrou_tradicao:
		_falhar("Grupo não desenvolveu tradição após cooperações repetidas."); return
	var agora_alerta := int(Time.get_unix_time_from_system())
	var alerta := reaberto.transmitir_alerta_perigo("alcateia_teste", "alcateia_aliada_teste", "predador", agora_alerta, 350.0)
	if not bool(alerta.get("entregue", false)):
		_falhar("Não entregou alerta a grupo conhecido e próximo: " + str(alerta.get("motivo", ""))); return
	var grupo_alertado := reaberto.obter_grupo("alcateia_aliada_teste")
	if grupo_alertado.get("alertasRecebidos", []).is_empty() or grupo_alertado.get("memoriaEcologica", []).is_empty():
		_falhar("Alerta não foi persistido na memória do grupo."); return
	var reacao := reaberto.processar_alertas_recebidos("alcateia_aliada_teste", agora_alerta)
	if not bool(reacao.get("ok", false)) or not bool(reacao.get("reagiu", false)) or str(reacao.get("acao", "")) != "fugir":
		_falhar("Grupo não reagiu fugindo ao alerta de predador."); return
	var grupo_em_fuga: Dictionary = reacao["grupo"]
	var movimento_fuga := MovimentoGrupos.avancar(grupo_em_fuga, 1.0, 123456)
	if not bool(movimento_fuga.get("ok", false)):
		_falhar("Movimento de fuga do alerta falhou."); return
	var estados_fuga := 0
	for membro_fuga in movimento_fuga["grupo"].get("individuos", []):
		if bool(membro_fuga.get("vivo", false)) and str(membro_fuga.get("estadoMundo", "")) == "recuando_de_perigo":
			estados_fuga += 1
	if estados_fuga == 0:
		_falhar("Alerta não alterou o comportamento de movimento dos indivíduos."); return
	var reacao_repetida := reaberto.processar_alertas_recebidos("alcateia_aliada_teste", agora_alerta + 1)
	if bool(reacao_repetida.get("reagiu", false)):
		_falhar("Reprocessou alerta que já tinha sido aplicado."); return
	var repetido := reaberto.transmitir_alerta_perigo("alcateia_teste", "alcateia_aliada_teste", "predador", agora_alerta + 1, 350.0)
	if bool(repetido.get("entregue", false)) or str(repetido.get("motivo", "")) != "alerta_repetido":
		_falhar("Não bloqueou repetição excessiva do mesmo alerta."); return
	var desconhecido := reaberto.transmitir_alerta_perigo("alcateia_teste", "grupo_desconhecido", "predador", agora_alerta + 2)
	if bool(desconhecido.get("ok", false)):
		_falhar("Aceitou destinatário inexistente."); return
	var fora_alcance := reaberto.transmitir_alerta_perigo("alcateia_teste", "alcateia_aliada_teste", "incendio", agora_alerta + 3, 10.0)
	if bool(fora_alcance.get("entregue", false)) or str(fora_alcance.get("motivo", "")) != "fora_do_alcance":
		_falhar("Enviou alerta além do alcance permitido."); return
	print("TESTE DE GRUPOS SELVAGENS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE GRUPOS SELVAGENS: " + mensagem)
	quit(1)
