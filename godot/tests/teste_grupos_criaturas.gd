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
		"habilidades":[{"id":"uivo_sonico","nome":"Uivo Sônico","tipo":"som"},{"id":"passo_fantasma","nome":"Passo Fantasma","tipo":"movimento"}],"chefe":false,
		"tabelaDrops":[{"itemId":"pelo_lobo","raridade":"comum","chance":0.4}],
		"ecologia":{
			"grupoReprodutivoId":"canideos_arcana",
			"populacao":{"quantidadeInicial":4,"minima":2,"maxima":8,"nascimentosPorDia":2.0,"mortesPorDia":1.0},
			"populacaoMinimaParaLider":3,
			"equipamentosLider":["espada_ferro","peitoral_malha","anel_poder"],
			"territorio":{"grupoId":"alcateia_teste","centro":{"x":400.0,"y":300.0},"raio":80.0},
			"rotasMigracao":[{"id":"rota_refugio_teste","ecossistemaId":"floresta_arcana","bioma":"bosque_refugio","habitat":"vale_seguro","territorio":{"grupoId":"alcateia_refugio","centro":{"x":800.0,"y":700.0},"raio":90.0}}]
		}
	}
	if not bool(repositorio_criaturas.registrar_criatura_gerada(criatura).get("ok", false)):
		_falhar("Não registrou a espécie de teste."); return
	var individuo_referencia := {"especieId":"especie_grupo_teste","atributos":{"vidaMaxima":300,"ataque":40,"defesa":22,"manaMaxima":24,"agilidade":35,"poderMagico":9},"habilidadesHibridasPotenciais":[{"id":"origem::uivo_sonico","habilidade":{"id":"uivo_sonico","nome":"Uivo Sônico"}}],"assinaturaFenotipica":"fenotipo_teste","perfilGenetico":{"geracao":3}}
	var evidencias_estabilidade := {"especieEmergente":true,"geracoesObservadas":[1,2,3],"geracoesReprodutoras":[1,2],"paresReprodutivos":["par_1","par_2"],"ancestralidade":["especie_grupo_teste","especie_aliada_teste"],"nascimentosObservados":5}
	var especie_nascida := repositorio_criaturas.registrar_especie_emergente("especie_grupo_teste","linhagem_teste_123",individuo_referencia,evidencias_estabilidade)
	if not bool(especie_nascida.get("ok", false)):
		_falhar("Não registrou espécie emergente após estabilidade comprovada: " + str(especie_nascida.get("erro", ""))); return
	var especie_independente: Dictionary = repositorio_criaturas.obter_criatura(str(especie_nascida.get("criatura", {}).get("id", "")))
	if especie_independente.is_empty() or str(especie_independente.get("identidadeBiologica", "")) != "especie_independente" or str(especie_independente.get("ecologia", {}).get("grupoReprodutivoId", "")) != str(especie_independente.get("id", "")):
		_falhar("A espécie emergente não recebeu identidade ou grupo reprodutivo independente."); return
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
	var grupo_alianca: Dictionary = reaberto.obter_grupo("alcateia_teste")
	if grupo_alianca.get("culturaGrupo", {}).get("aliancas", []).is_empty():
		_falhar("Cooperações repetidas não formaram uma aliança cultural."); return
	var especie_comunidade: Dictionary = criatura.duplicate(true)
	especie_comunidade["id"] = "especie_comunidade_teste"
	especie_comunidade["nome"] = "Lobo da Comunidade"
	especie_comunidade["ecologia"]["territorio"] = {"grupoId":"alcateia_terceira_teste","centro":{"x":600.0,"y":300.0},"raio":65.0}
	if not bool(repositorio_criaturas.registrar_criatura_gerada(especie_comunidade).get("ok", false)):
		_falhar("Não registrou terceira espécie para teste de comunidade."); return
	var terceira_criada := reaberto.criar_grupo_para_criatura("especie_comunidade_teste", 1000)
	if not bool(terceira_criada.get("ok", false)):
		_falhar("Não criou terceiro grupo para comunidade cultural."); return
	for ciclo in range(2):
		var alianca_terceira := reaberto.registrar_interacao_social("alcateia_aliada_teste", "alcateia_terceira_teste", "cooperacao", 92500 + ciclo)
		if not bool(alianca_terceira.get("ok", false)):
			_falhar("Não estabeleceu aliança com o terceiro grupo."); return
	var comunidade_grupo: Dictionary = reaberto.obter_grupo("alcateia_terceira_teste")
	if comunidade_grupo.get("culturaGrupo", {}).get("comunidadeCultural", {}).is_empty():
		_falhar("Rede de três grupos aliados não fundou uma comunidade cultural."); return
	var grupo_a_uniao: Dictionary = reaberto.obter_grupo("alcateia_teste")
	var grupo_b_uniao: Dictionary = reaberto.obter_grupo("alcateia_aliada_teste")
	var adulto_a_id := ""
	var adulto_b_id := ""
	for adulto in grupo_a_uniao.get("individuos", []):
		if bool(adulto.get("vivo", false)) and str(adulto.get("faseVida", "")) == "adulto":
			adulto_a_id = str(adulto.get("individuoId", "")); break
	for adulto in grupo_b_uniao.get("individuos", []):
		if bool(adulto.get("vivo", false)) and str(adulto.get("faseVida", "")) == "adulto":
			adulto_b_id = str(adulto.get("individuoId", "")); break
	var uniao := reaberto.registrar_uniao_intergrupos("alcateia_teste", adulto_a_id, "alcateia_aliada_teste", adulto_b_id, 92600)
	if not bool(uniao.get("ok", false)):
		_falhar("Espécies com grupo reprodutivo explicitamente compartilhado não formaram união: " + str(uniao.get("erro", ""))); return
	var hibrido := reaberto.gerar_filhote_hibrido(str(uniao.get("uniao", {}).get("id", "")), "alcateia_teste", adulto_a_id, "alcateia_aliada_teste", adulto_b_id, 92601)
	if not bool(hibrido.get("ok", false)):
		_falhar("Não gerou descendente híbrido a partir da união registrada: " + str(hibrido.get("erro", ""))); return
	var dados_hibrido: Dictionary = hibrido.get("filhote", {})
	if str(dados_hibrido.get("identidadeBiologica", "")) != "hibrido" or dados_hibrido.get("linhagemHibrida", []).size() != 2 or dados_hibrido.get("progenitores", {}).is_empty():
		_falhar("Descendente híbrido não preservou identidade e linhagem dos dois progenitores."); return
	if str(dados_hibrido.get("linhagemHibridaId", "")).is_empty() or int(dados_hibrido.get("geracaoHibrida", 0)) != 1:
		_falhar("Híbrido não recebeu identidade persistente de linhagem e geração inicial."); return
	var banco_linhagens: Dictionary = reaberto._ler_banco().get("linhagensHibridas", {})
	var registro_linhagem: Dictionary = banco_linhagens.get(str(dados_hibrido.get("linhagemHibridaId", "")), {})
	if str(registro_linhagem.get("estado", "")) != "em_observacao" or bool(registro_linhagem.get("especieEmergente", true)) or registro_linhagem.get("geracoesObservadas", []).size() != 1:
		_falhar("Linhagem recém-formada foi promovida a espécie sem evidência de gerações sucessivas."); return
	var estabilidade_incompleta := {"geracoesObservadas":[1,2,3],"geracoesReprodutoras":[1,2],"paresReprodutivos":["par_a","par_b"],"individuosRegistrados":["a","b","c","d","e"]}
	if not reaberto._avaliar_estabilidade_linhagem(estabilidade_incompleta):
		_falhar("Não reconheceu estabilidade quando todas as evidências reprodutivas estão presentes."); return
	estabilidade_incompleta["geracoesReprodutoras"] = [1]
	if reaberto._avaliar_estabilidade_linhagem(estabilidade_incompleta):
		_falhar("Promoveu linhagem sem comprovar reprodução da geração F2."); return
	if str(dados_hibrido.get("assinaturaFenotipica", "")).is_empty() or dados_hibrido.get("perfilGenetico", {}).is_empty():
		_falhar("Híbrido inicial não registrou perfil genético e assinatura fenotípica."); return
	var reproducao_invalida := reaberto.gerar_filhote_linhagem_hibrida("alcateia_teste", str(dados_hibrido.get("individuoId", "")), str(dados_hibrido.get("individuoId", "")), 92602)
	if bool(reproducao_invalida.get("ok", false)):
		_falhar("Permitiu que um híbrido se reproduzisse consigo mesmo."); return
	var grupo_hibrido: Dictionary = reaberto.obter_grupo("alcateia_teste")
	if int(grupo_hibrido.get("populacaoEstado", {}).get("quantidade", 0)) != 4 or grupo_hibrido.get("culturaGrupo", {}).get("nascimentosHibridos", []).is_empty():
		_falhar("Nascimento híbrido não atualizou a população e o registro cultural."); return
	if dados_hibrido.get("habilidadesHibridasPotenciais", []).size() < 2 or not dados_hibrido.get("habilidadesHibridasDesbloqueadas", []).is_empty():
		_falhar("Híbrido não guardou habilidades das duas linhagens sem desbloqueá-las antes do crescimento."); return
	var crescimento_hibrido := reaberto.avancar_grupo("alcateia_teste", 92601 + 2 * 86400, 1.0, 0.0)
	if not bool(crescimento_hibrido.get("ok", false)):
		_falhar("Não avançou o desenvolvimento do híbrido: " + str(crescimento_hibrido.get("erro", ""))); return
	var grupo_crescido: Dictionary = reaberto.obter_grupo("alcateia_teste")
	var hibrido_crescido: Dictionary = {}
	for membro_crescido in grupo_crescido.get("individuos", []):
		if str(membro_crescido.get("individuoId", "")) == str(dados_hibrido.get("individuoId", "")):
			hibrido_crescido = membro_crescido
			break
	if str(hibrido_crescido.get("estagioHibrido", "")) != "juvenil" or hibrido_crescido.get("habilidadesHibridasDesbloqueadas", []).size() != 1:
		_falhar("Híbrido não evoluiu para juvenil e desbloqueou sua primeira habilidade herdada."); return
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
	reaberto._inicializar_cultura_especie(grupo_cultural_reacao, criatura, 93000)
	var perfil_cultural := grupo_cultural_reacao.get("culturaGrupo", {}).get("perfilEspecie", {})
	if perfil_cultural.is_empty():
		_falhar("Grupo não recebeu identidade cultural específica da espécie."); return
	if perfil_cultural.get("linguagemSinais", {}).is_empty() or str(perfil_cultural.get("hierarquia", "")).is_empty() or perfil_cultural.get("costumesEcossistema", []).is_empty():
		_falhar("Perfil cultural não definiu sinais, hierarquia e costumes ecológicos."); return
	var par_a := {"individuoId":"par_a","grupoId":"grupo_teste","vivo":true,"faseVida":"adulto","ritualPreferido":"canto_de_pareamento","tradicoesCulturaisHerdadas":[{"id":"vigilia_coletiva"}]}
	var par_b := {"individuoId":"par_b","grupoId":"grupo_teste","vivo":true,"faseVida":"adulto","ritualPreferido":"canto_de_pareamento","tradicoesCulturaisHerdadas":[{"id":"vigilia_coletiva"}]}
	var par_c := {"individuoId":"par_c","grupoId":"grupo_teste","vivo":true,"faseVida":"adulto","ritualPreferido":"oferta_de_alimento","tradicoesCulturaisHerdadas":[]}
	var afinidade_cultural := reaberto.avaliar_compatibilidade_cultural(par_a, par_b, perfil_cultural)
	var afinidade_diferente := reaberto.avaliar_compatibilidade_cultural(par_a, par_c, perfil_cultural)
	if not bool(afinidade_cultural.get("compativel", false)) or float(afinidade_cultural.get("pontuacao", 0.0)) <= float(afinidade_diferente.get("pontuacao", 0.0)):
		_falhar("Preferências rituais e tradições não influenciaram a compatibilidade de parceiros."); return
	var par_filhote := reaberto._selecionar_par_acasalamento_cultural({"individuos":[par_a,par_b,par_c],"culturaGrupo":grupo_cultural_reacao.get("culturaGrupo", {})}, 95000, {})
	if par_filhote.is_empty() or str(par_filhote.get("progenitorAId", "")) != "par_a" or str(par_filhote.get("progenitorBId", "")) != "par_b":
		_falhar("Seleção cultural não escolheu o par adulto mais compatível."); return
	var individuo_infantil := reaberto._criar_individuo(grupo_cultural_reacao, criatura, RandomNumberGenerator.new(), true)
	if str(individuo_infantil.get("ritualPreferido", "")).is_empty():
		_falhar("Indivíduo não recebeu preferência cultural de pareamento."); return
	var filhote_cultural := reaberto._criar_individuo(grupo_cultural_reacao, criatura, RandomNumberGenerator.new(), true)
	if str(filhote_cultural.get("ritualNascimento", "")).is_empty() or filhote_cultural.get("perfilCulturalHerdado", {}).is_empty():
		_falhar("Filhote não recebeu ritual e herança cultural da espécie."); return
	var reconhecedor := {"individuoId":"reconhecedor","vivo":true,"membrosReconhecidos":[]}
	var reconhecido := {"individuoId":"reconhecido","vivo":true}
	reaberto._registrar_reconhecimento_cultural(reconhecedor, reconhecido, "grupo_visitante", 94000)
	reaberto._registrar_reconhecimento_cultural(reconhecedor, reconhecido, "grupo_visitante", 94001)
	if reconhecedor.get("membrosReconhecidos", []).size() != 1 or int(reconhecedor["membrosReconhecidos"][0].get("encontros", 0)) != 2:
		_falhar("Reconhecimento de membro não acumulou encontros sem duplicar identidade."); return
	var grupo_lider_a: Dictionary = reaberto.obter_grupo("alcateia_teste")
	var grupo_lider_b: Dictionary = reaberto.obter_grupo("alcateia_aliada_teste")
	reaberto._registrar_confronto_liderancas_culturais(grupo_lider_a, grupo_lider_b, 94999)
	if grupo_lider_a.get("culturaGrupo", {}).get("disputasLideranca", []).is_empty() or str(grupo_lider_a["culturaGrupo"]["disputasLideranca"][-1].get("resultado", "")) != "conflito_registrado_sem_vencedor":
		_falhar("Conflito entre líderes não foi registrado sem presumir vencedor."); return
	var conflito_herdado_1 := reaberto.registrar_interacao_social("alcateia_teste", "alcateia_aliada_teste", "conflito", 94990)
	var conflito_herdado_2 := reaberto.registrar_interacao_social("alcateia_teste", "alcateia_aliada_teste", "conflito", 94991)
	if not bool(conflito_herdado_1.get("ok", false)) or not bool(conflito_herdado_2.get("ok", false)):
		_falhar("Não registrou rivalidade entre grupos para herança cultural."); return
	var grupo_rival: Dictionary = reaberto.obter_grupo("alcateia_teste")
	var filhote_rival := reaberto._criar_individuo(grupo_rival, criatura, RandomNumberGenerator.new(), true)
	if filhote_rival.get("rivalidadesHerdadas", []).is_empty():
		_falhar("Filhote não herdou memória cultural de rivalidades."); return
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
