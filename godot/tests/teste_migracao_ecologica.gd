extends SceneTree
const RepositorioCriaturas = preload("res://scripts/repositorio_criaturas_servidor.gd")
const RepositorioGrupos = preload("res://scripts/repositorio_grupos_criaturas_servidor.gd")

func _initialize() -> void:
	var sufixo := str(Time.get_ticks_usec())
	var caminho_catalogo := "user://teste_catalogo_migracao_" + sufixo + ".json"
	var caminho_grupos := "user://teste_grupos_migracao_" + sufixo + ".json"
	var catalogo = RepositorioCriaturas.new(caminho_catalogo)
	var grupos = RepositorioGrupos.new(caminho_grupos, catalogo)
	var criatura := {
		"id":"migrante_teste","nome":"Migrante","descricao":"Espécie de teste de migração.",
		"rank":"E","raridade":"comum","nivel":1,"vidaMaxima":20,"ataque":2,
		"defesa":2,"manaMaxima":0,"agilidade":3,"poderMagico":0,
		"experienciaBase":1,"perigo":1,"ecossistemaId":"floresta_arcana",
		"bioma":"bosque","habitat":"clareira","habilidades":[],"chefe":false,"tabelaDrops":[],
		"ecologia":{
			"populacao":{"quantidadeInicial":3,"minima":1,"maxima":8,"nascimentosPorDia":0.0,"mortesPorDia":0.0},
			"territorio":{"grupoId":"grupo_migrante_teste","centro":{"x":100.0,"y":100.0},"raio":60.0},
			"rotasMigracao":[{
				"id":"rota_bosque_leste","ecossistemaId":"floresta_arcana","bioma":"bosque_leste","habitat":"vale_umido",
				"territorio":{"grupoId":"grupo_migrante_teste_leste","centro":{"x":500.0,"y":500.0},"raio":70.0}
			}]
		}
	}
	var guardiao := {
		"id":"guardiao_teste","nome":"Guardião","descricao":"Espécie residente fraca para teste de disputa.",
		"rank":"E","raridade":"comum","nivel":1,"vidaMaxima":1,"ataque":1,
		"defesa":0,"manaMaxima":0,"agilidade":0,"poderMagico":0,
		"experienciaBase":1,"perigo":1,"ecossistemaId":"floresta_arcana",
		"bioma":"bosque_leste","habitat":"vale_umido","habilidades":[],"chefe":false,"tabelaDrops":[],
		"ecologia":{
			"populacao":{"quantidadeInicial":3,"minima":1,"maxima":8,"nascimentosPorDia":0.0,"mortesPorDia":0.0},
			"territorio":{"grupoId":"grupo_guardiao_teste","centro":{"x":500.0,"y":500.0},"raio":70.0}
		}
	}
	for especie in [criatura, guardiao]:
		var registro := catalogo.registrar_criatura_gerada(especie)
		if not bool(registro.get("ok", false)):
			_falhar("Não registrou espécie de teste: " + str(registro.get("erro", ""))); return
	var criado := grupos.criar_grupo_para_criatura("migrante_teste", 1000)
	if not bool(criado.get("ok", false)):
		_falhar("Não criou grupo migrante: " + str(criado.get("erro", ""))); return
	var criado_guardiao := grupos.criar_grupo_para_criatura("guardiao_teste", 1000)
	if not bool(criado_guardiao.get("ok", false)):
		_falhar("Não criou grupo residente: " + str(criado_guardiao.get("erro", ""))); return
	var ciclo: Dictionary = {}
	for instante in [1000, 1060, 1120]:
		ciclo = grupos.avaliar_migracao_por_escassez("grupo_migrante_teste", 0.1, instante)
		if not bool(ciclo.get("ok", false)):
			_falhar("Falhou ao avaliar escassez: " + str(ciclo.get("erro", ""))); return
		if instante < 1120 and bool(ciclo.get("migrou", false)):
			_falhar("Migrou antes de três ciclos consecutivos de escassez."); return
	if not bool(ciclo.get("migrou", false)):
		_falhar("Não migrou após três ciclos consecutivos de escassez."); return
	if not bool(ciclo.get("disputaTerritorial", false)) or str(ciclo.get("resultadoDisputa", "")) != "invasor_conquistou_territorio":
		_falhar("Não registrou a disputa e a vitória do grupo migrante."); return
	var grupo_residente: Dictionary = grupos.obter_grupo("grupo_guardiao_teste")
	var centro_residente: Dictionary = grupo_residente.get("territorio", {}).get("centro", {})
	if Vector2(float(centro_residente.get("x", 500.0)), float(centro_residente.get("y", 500.0))).distance_to(Vector2(500.0, 500.0)) < 100.0:
		_falhar("O grupo residente não recuou após perder a disputa."); return
	var relacao_migrante: Dictionary = grupos.obter_grupo("grupo_migrante_teste").get("relacoesGrupos", {}).get("grupo_guardiao_teste", {})
	if str(relacao_migrante.get("estado", "")) != "neutro" and str(relacao_migrante.get("estado", "")) != "rival":
		_falhar("Não guardou a memória do conflito territorial."); return
	var temperamento_antes_cooperacao: Dictionary = grupos.obter_grupo("grupo_migrante_teste").get("individuos", [])[0].get("personalidadeIndividual", {}).duplicate(true)
	var cooperacao := grupos.registrar_interacao_social("grupo_migrante_teste", "grupo_guardiao_teste", "cooperacao", 1200)
	if not bool(cooperacao.get("ok", false)):
		_falhar("Não registrou cooperação social."); return
	var grupo_apos_cooperacao: Dictionary = grupos.obter_grupo("grupo_migrante_teste")
	var temperamento_apos_cooperacao: Dictionary = grupo_apos_cooperacao.get("individuos", [])[0].get("personalidadeIndividual", {})
	if float(temperamento_apos_cooperacao.get("protecaoSocial", 1.0)) <= float(temperamento_antes_cooperacao.get("protecaoSocial", 1.0)):
		_falhar("A cooperação não fortaleceu gradualmente a proteção social individual."); return
	if grupo_apos_cooperacao.get("aprendizadoTemperamental", []).is_empty():
		_falhar("Não registrou a experiência que alterou o temperamento."); return
	var segunda_cooperacao := grupos.registrar_interacao_social("grupo_migrante_teste", "grupo_guardiao_teste", "cooperacao", 1260)
	if not bool(segunda_cooperacao.get("ok", false)):
		_falhar("Não registrou a segunda cooperação social."); return
	var grupo_cooperante: Dictionary = grupos.obter_grupo("grupo_migrante_teste")
	var relacao_cooperativa: Dictionary = grupo_cooperante.get("relacoesGrupos", {}).get("grupo_guardiao_teste", {})
	if int(relacao_cooperativa.get("interacoes", 0)) < 2 or str(relacao_cooperativa.get("estado", "")) != "aliado":
		_falhar("Não reconheceu aliança após cooperação repetida."); return
	var individuo_com_vinculo: Dictionary = grupo_cooperante.get("individuos", [])[0]
	var vinculos_individuais: Array = individuo_com_vinculo.get("vinculosIndividuais", [])
	if vinculos_individuais.is_empty():
		_falhar("A cooperação entre grupos não criou vínculos individuais."); return
	var primeiro_vinculo: Dictionary = vinculos_individuais[0]
	if float(primeiro_vinculo.get("amizade", 0.0)) <= 0.0 or float(primeiro_vinculo.get("confianca", 0.0)) <= 0.0:
		_falhar("O vínculo individual não desenvolveu amizade e confiança."); return
	if str(individuo_com_vinculo.get("companheiroPreferidoId", "")).is_empty():
		_falhar("A criatura não identificou um companheiro preferido."); return
	var conflito_vincular := grupos.registrar_interacao_social("grupo_migrante_teste", "grupo_guardiao_teste", "conflito", 1320)
	if not bool(conflito_vincular.get("ok", false)):
		_falhar("Não registrou conflito para testar rivalidade individual."); return
	var grupo_apos_conflito: Dictionary = grupos.obter_grupo("grupo_migrante_teste")
	var rivalidades: Array = grupo_apos_conflito.get("individuos", [])[0].get("vinculosIndividuais", [])
	var encontrou_rival := false
	for relacao_individual in rivalidades:
		if str(relacao_individual.get("grupoId", "")) == "grupo_guardiao_teste" and float(relacao_individual.get("rivalidade", 0.0)) > 0.0:
			encontrou_rival = true
	if not encontrou_rival:
		_falhar("O conflito não registrou rivalidade individual."); return
	if grupo_cooperante.get("personalidade", {}).is_empty():
		_falhar("Grupo não recebeu personalidade própria."); return
	var individuos_temperamento: Array = grupo_cooperante.get("individuos", [])
	if individuos_temperamento.size() < 2:
		_falhar("Grupo de teste precisa de indivíduos suficientes para comparar temperamentos."); return
	var primeiro_temperamento: Dictionary = individuos_temperamento[0].get("personalidadeIndividual", {})
	var segundo_temperamento: Dictionary = individuos_temperamento[1].get("personalidadeIndividual", {})
	if primeiro_temperamento.is_empty() or segundo_temperamento.is_empty():
		_falhar("Indivíduos não receberam temperamentos próprios."); return
	if primeiro_temperamento == segundo_temperamento:
		_falhar("Todos os indivíduos receberam exatamente a mesma personalidade."); return
	for temperamento in [primeiro_temperamento, segundo_temperamento]:
		for atributo_temperamento in ["prudencia", "protecaoSocial", "agressividade", "coragem", "curiosidade"]:
			var valor_temperamento := float(temperamento.get(atributo_temperamento, 0.0))
			if valor_temperamento < 0.70 or valor_temperamento > 1.30:
				_falhar("Temperamento individual saiu dos limites permitidos."); return
	var comportamento_individual = load("res://scripts/sistema_comportamento_criaturas.gd")
	var prudente_foge: Dictionary = comportamento_individual.decidir_reacao_presa(10.0, 40.0, 1.0, 1.0, 0.25, true, false, 1.25, 1.0)
	if str(prudente_foge.get("acao", "")) != "fugir":
		_falhar("Indivíduo prudente não influenciou o grupo a usar rota segura."); return
	var protetor_chama_aliados: Dictionary = comportamento_individual.decidir_reacao_presa(10.0, 40.0, 1.0, 1.0, 0.25, false, true, 1.0, 1.25)
	if str(protetor_chama_aliados.get("acao", "")) != "defender_com_aliados":
		_falhar("Temperamento protetor não priorizou apoio dos aliados."); return
	var grupo: Dictionary = grupos.obter_grupo("grupo_migrante_teste")
	var disputa: Dictionary = grupo.get("ultimaDisputaTerritorial", {})
	if float(grupo.get("moralMultiplicador", 1.0)) < 1.19:
		_falhar("O grupo vencedor não recebeu o bônus de moral de 20%."); return
	if disputa.get("turnosDuelo", []).is_empty():
		_falhar("A disputa não registrou os turnos do duelo entre representantes."); return
	if not ["aceitar_derrota_e_recuar", "continuar_com_todo_o_grupo"].has(str(disputa.get("decisaoDerrotado", ""))):
		_falhar("A IA do grupo derrotado não registrou uma decisão válida."); return
	for membro_vencedor in grupo.get("individuos", []):
		if bool(membro_vencedor.get("vivo", false)) and float(membro_vencedor.get("moralMultiplicador", 1.0)) < 1.19:
			_falhar("Um integrante vivo não recebeu o aumento individual de moral."); return
	if str(grupo.get("bioma", "")) != "bosque_leste" or str(grupo.get("habitat", "")) != "vale_umido":
		_falhar("Não atualizou o bioma e habitat de destino."); return
	for individuo in grupo.get("individuos", []):
		var p: Dictionary = individuo.get("posicaoMundo", {})
		var distancia := Vector2(float(p.get("x", -1.0)), float(p.get("y", -1.0))).distance_to(Vector2(500.0, 500.0))
		if distancia > 65.1:
			_falhar("Um indivíduo ficou fora do novo território."); return
	var reaberto = RepositorioGrupos.new(caminho_grupos, catalogo)
	if str(reaberto.obter_grupo("grupo_migrante_teste").get("bioma", "")) != "bosque_leste":
		_falhar("A migração não persistiu após reabrir o repositório."); return
	var recuperacao := reaberto.avaliar_migracao_por_escassez("grupo_migrante_teste", 1.0, 1180)
	if int(recuperacao["grupo"].get("ciclosEscassezAlimentar", -1)) != 0:
		_falhar("A recuperação alimentar não zerou o contador de escassez."); return
	var grupo_com_filhote := {"grupoId":"grupo_com_filhote","ecossistemaId":"floresta_arcana","individuos":[{"individuoId":"filhote_ferido","vivo":true,"faseVida":"filhote","vidaAtual":3,"atributos":{"vidaMaxima":20},"posicaoMundo":{"x":500.0,"y":500.0}},{"individuoId":"adulto_protetor","vivo":true,"faseVida":"adulto","vidaAtual":20,"atributos":{"vidaMaxima":20},"posicaoMundo":{"x":515.0,"y":500.0}}]}
	var sistema_defesa = load("res://scripts/sistema_defesa_cooperativa.gd")
	var alvo_bando: Dictionary = sistema_defesa.selecionar_alvo_prioritario(grupo_com_filhote, Vector2(490.0, 500.0))
	if str(alvo_bando.get("individuoId", "")) != "filhote_ferido":
		_falhar("Predadores coordenados não priorizaram o filhote vulnerável."); return
	var grupo_com_amizade := {"grupoId":"grupo_amizade","individuos":[
		{"individuoId":"criatura_amparada","vivo":true,"vidaAtual":12,"atributos":{"vidaMaxima":20},"posicaoMundo":{"x":500.0,"y":500.0}},
		{"individuoId":"amigo_guardiao","vivo":true,"vidaAtual":20,"atributos":{"vidaMaxima":20},"posicaoMundo":{"x":510.0,"y":500.0},"vinculosIndividuais":[{"grupoId":"grupo_amizade","individuoId":"criatura_amparada","amizade":0.9,"confianca":0.9,"rivalidade":0.0}]},
		{"individuoId":"criatura_isolada","vivo":true,"vidaAtual":12,"atributos":{"vidaMaxima":20},"posicaoMundo":{"x":530.0,"y":500.0}}
	]}
	var alvo_com_amigos: Dictionary = sistema_defesa.selecionar_alvo_prioritario(grupo_com_amizade, Vector2(490.0, 500.0))
	if str(alvo_com_amigos.get("individuoId", "")) != "criatura_isolada":
		_falhar("A proteção de amigos não influenciou a escolha de alvo dos predadores."); return
	var amigo_escolhido: Dictionary = sistema_defesa.avaliar_intervencao(grupo_com_amizade, [grupo_com_amizade], grupo_com_amizade["individuos"][0])
	if str(amigo_escolhido.get("individuoAliadoId", "")) != "amigo_guardiao":
		_falhar("A criatura não priorizou proteger seu amigo próximo."); return
	var protecao_filhote: Dictionary = sistema_defesa.avaliar_intervencao(grupo_com_filhote, [grupo_com_filhote], grupo_com_filhote["individuos"][0])
	if not bool(protecao_filhote.get("interveio", false)) or not bool(protecao_filhote.get("protecaoFamiliar", false)) or str(protecao_filhote.get("individuoAliadoId", "")) != "adulto_protetor":
		_falhar("Adulto próximo não protegeu o filhote vulnerável."); return
	var aliado_defensor := {
		"grupoId":"grupo_aliado_teste",
		"ecossistemaId":"floresta_arcana",
		"individuos":[{"individuoId":"protetor_1","vivo":true,"posicaoMundo":{"x":510.0,"y":510.0}}]
	}
	var grupo_sob_ataque := {
		"grupoId":"grupo_protegido_teste",
		"ecossistemaId":"floresta_arcana",
		"relacoesGrupos":{"grupo_aliado_teste":{"estado":"aliado","confianca":0.50}}
	}
	var ameacado := {"individuoId":"ameacado_1","vivo":true,"posicaoMundo":{"x":500.0,"y":500.0}}
	var defesa_conjunta = load("res://scripts/sistema_defesa_cooperativa.gd").avaliar_intervencao(grupo_sob_ataque, [grupo_sob_ataque, aliado_defensor], ameacado)
	if not bool(defesa_conjunta.get("interveio", false)) or str(defesa_conjunta.get("individuoAliadoId", "")) != "protetor_1" or absf(float(defesa_conjunta.get("reducaoDano", 0.0)) - 0.25) > 0.001:
		_falhar("Aliado próximo não interveio com redução defensiva correta."); return
	aliado_defensor["ecossistemaId"] = "deserto_ancestral"
	var aliado_distante = load("res://scripts/sistema_defesa_cooperativa.gd").avaliar_intervencao(grupo_sob_ataque, [grupo_sob_ataque, aliado_defensor], ameacado)
	if bool(aliado_distante.get("interveio", false)):
		_falhar("Grupo de outro ecossistema interferiu na defesa."); return
	var especie_fuga: Dictionary = criatura.duplicate(true)
	especie_fuga["id"] = "fauna_fuga_devastacao_teste"
	especie_fuga["nome"] = "Fauna de Fuga"
	especie_fuga["ecologia"] = especie_fuga["ecologia"].duplicate(true)
	especie_fuga["ecologia"]["territorio"] = {"grupoId":"grupo_fuga_devastacao_teste","centro":{"x":100.0,"y":100.0},"raio":60.0}
	especie_fuga["ecologia"]["rotasMigracao"] = [{
		"id":"rota_refugio_teste","ecossistemaId":"floresta_arcana","bioma":"refugio","habitat":"vale_seguro",
		"territorio":{"grupoId":"grupo_fuga_devastacao_teste_refugio","centro":{"x":900.0,"y":900.0},"raio":70.0}
	}]
	if not bool(catalogo.registrar_criatura_gerada(especie_fuga).get("ok", false)):
		_falhar("Não registrou espécie de teste para fuga da devastação."); return
	if not bool(grupos.criar_grupo_para_criatura("fauna_fuga_devastacao_teste", 2000).get("ok", false)):
		_falhar("Não criou grupo de fauna para testar fuga."); return
	var especie_predadora := criatura.duplicate(true)
	especie_predadora["id"] = "predador_rastreador_teste"
	especie_predadora["nome"] = "Predador Rastreador"
	especie_predadora["ecologia"] = {
		"populacao":{"quantidadeInicial":2,"minima":1,"maxima":6,"nascimentosPorDia":0.0,"mortesPorDia":0.0},
		"territorio":{"grupoId":"grupo_predador_rastreador_teste","centro":{"x":300.0,"y":100.0},"raio":50.0},
		"especiesPresas":["fauna_fuga_devastacao_teste"]
	}
	if not bool(catalogo.registrar_criatura_gerada(especie_predadora).get("ok", false)):
		_falhar("Não registrou predador rastreador no catálogo."); return
	if not bool(grupos.criar_grupo_para_criatura("predador_rastreador_teste", 2050).get("ok", false)):
		_falhar("Não criou grupo de predadores rastreadores."); return
	var fuga := grupos.fugir_da_devastacao("grupo_fuga_devastacao_teste", Vector2(100.0, 100.0), 120.0, 2100)
	if not bool(fuga.get("ok", false)) or not bool(fuga.get("fugiu", false)):
		_falhar("Grupo selvagem não fugiu por uma rota segura declarada."); return
	var grupo_fugido: Dictionary = fuga.get("grupo", {})
	if str(grupo_fugido.get("bioma", "")) != "refugio" or str(grupo_fugido.get("ultimaMigracao", {}).get("motivo", "")) != "sopro_primordial":
		_falhar("A fuga não atualizou o habitat e o motivo da migração."); return
	for individuo_fugido in grupo_fugido.get("individuos", []):
		if bool(individuo_fugido.get("vivo", true)) and str(individuo_fugido.get("estadoMundo", "")) != "fugindo_da_devastacao":
			_falhar("Os indivíduos vivos não receberam o estado de fuga."); return
	var rastreamento := grupos.registrar_perseguicao_de_fauna_migrante("grupo_fuga_devastacao_teste", 2150)
	if not bool(rastreamento.get("ok", false)) or rastreamento.get("perseguidores", []).size() != 1:
		_falhar("O predador com dieta declarada não iniciou o rastreamento da presa deslocada."); return
	var predador_atualizado: Dictionary = grupos.obter_grupo("grupo_predador_rastreador_teste")
	var perseguicao: Dictionary = predador_atualizado.get("perseguicaoAtual", {})
	if str(perseguicao.get("grupoAlvoId", "")) != "grupo_fuga_devastacao_teste" or str(perseguicao.get("estado", "")) != "rastreando":
		_falhar("O estado persistente de perseguição não aponta para o grupo deslocado."); return
	var antes_perseguicao: Dictionary = grupos.obter_grupo("grupo_predador_rastreador_teste")
	var centro_antes: Dictionary = antes_perseguicao.get("territorio", {}).get("centro", {})
	var avancou_perseguicao := grupos.avancar_perseguicoes(2.0, 2200)
	if not bool(avancou_perseguicao.get("ok", false)) or avancou_perseguicao.get("grupos", []).is_empty():
		_falhar("O predador não avançou em direção à presa."); return
	var depois_perseguicao: Dictionary = grupos.obter_grupo("grupo_predador_rastreador_teste")
	var centro_depois: Dictionary = depois_perseguicao.get("territorio", {}).get("centro", {})
	if Vector2(float(centro_depois.get("x", 0.0)), float(centro_depois.get("y", 0.0))).distance_to(Vector2(float(centro_antes.get("x", 0.0)), float(centro_antes.get("y", 0.0)))) <= 0.0:
		_falhar("O território do predador não avançou durante a perseguição."); return
	if str(depois_perseguicao.get("perseguicaoAtual", {}).get("estado", "")) != "seguindo":
		_falhar("O predador não registrou o estado de seguimento."); return
	var confronto_antecipado := reaberto.registrar_confronto_ecologico(
		"grupo_predador_rastreador_teste", "grupo_fuga_devastacao_teste", "alvo_inexistente", 2250
	)
	if bool(confronto_antecipado.get("ok", false)):
		_falhar("O servidor aceitou um confronto antes de o predador alcançar a presa."); return

	var comportamento = load("res://scripts/sistema_comportamento_criaturas.gd")
	var decisao_fuga: Dictionary = comportamento.decidir_reacao_presa(10.0, 40.0, 0.75, 0.80, 0.25, true, false)
	if str(decisao_fuga.get("acao", "")) != "fugir":
		_falhar("Presa fraca e acuada não escolheu fugir pela rota segura."); return
	var decisao_aliados: Dictionary = comportamento.decidir_reacao_presa(10.0, 40.0, 0.75, 0.80, 0.25, false, true)
	if str(decisao_aliados.get("acao", "")) != "defender_com_aliados":
		_falhar("Presa sem rota não pediu apoio de aliados próximos."); return
	var decisao_defesa: Dictionary = comportamento.decidir_reacao_presa(80.0, 40.0, 1.20, 1.15, 0.90, true, false)
	if str(decisao_defesa.get("acao", "")) != "defender":
		_falhar("Presa forte e corajosa não sustentou a defesa."); return

	var reacao_aprendida_fuga: Dictionary = comportamento.ajustar_reacao_com_memoria(decisao_defesa, true, false)
	if str(reacao_aprendida_fuga.get("acao", "")) != "fugir":
		_falhar("Grupo que reconheceu ameaça anterior não escolheu fuga segura."); return
	var reacao_aprendida_aliados: Dictionary = comportamento.ajustar_reacao_com_memoria(decisao_defesa, false, true)
	if str(reacao_aprendida_aliados.get("acao", "")) != "defender_com_aliados":
		_falhar("Grupo sem rota segura não priorizou aliados após reconhecer ameaça."); return
	var reacao_sem_recursos: Dictionary = comportamento.ajustar_reacao_com_memoria(decisao_defesa, false, false)
	if str(reacao_sem_recursos.get("acao", "")) != "defender":
		_falhar("Aprendizado ordenou fuga sem rota segura."); return

	var cacada_desiste: Dictionary = comportamento.decidir_estrategia_caca(0.30, 1.0, 1.0, false, 0.0, false, false, 0, 30.0)
	if str(cacada_desiste.get("estrategia", "")) != "desistir":
		_falhar("Predador muito mais fraco não desistiu da caça."); return
	var cacada_isolado: Dictionary = comportamento.decidir_estrategia_caca(1.0, 1.0, 1.0, true, 80.0, false, false, 0, 30.0)
	if str(cacada_isolado.get("estrategia", "")) != "atacar_isolado":
		_falhar("Predador não priorizou indivíduo isolado."); return
	var cacada_emboscada_bloqueada: Dictionary = comportamento.decidir_estrategia_caca(1.2, 1.0, 1.0, false, 0.0, true, false, 0, 30.0)
	if str(cacada_emboscada_bloqueada.get("estrategia", "")) != "perseguir":
		_falhar("Emboscada foi permitida fora do habitat declarado."); return
	var cacada_emboscada: Dictionary = comportamento.decidir_estrategia_caca(1.2, 1.0, 1.0, false, 0.0, true, true, 0, 30.0)
	if str(cacada_emboscada.get("estrategia", "")) != "emboscar":
		_falhar("Predador com capacidade e habitat compatíveis não escolheu emboscada."); return

	var memoria_predador := [{"especiePresaId":"presa_teste","ecossistemaId":"floresta_teste","bioma":"mata","estrategiaAnterior":"emboscar","resultado":"perdeu_rastro","horarioUnix":100}]
	var estrategia_base := {"estrategia":"emboscar","motivo":"teste"}
	var estrategia_aprendida: Dictionary = comportamento.ajustar_estrategia_com_memoria(estrategia_base, memoria_predador, "presa_teste", "floresta_teste", "mata", 1, 101)
	if str(estrategia_aprendida.get("estrategia", "")) != "perseguir" or not bool(estrategia_aprendida.get("aprendeuComFalha", false)):
		_falhar("Predador repetiu emboscada que já falhou contra a mesma presa."); return
	var estrategia_sem_memoria: Dictionary = comportamento.ajustar_estrategia_com_memoria(estrategia_base, [], "presa_teste", "floresta_teste", "mata", 4, 101)
	if str(estrategia_sem_memoria.get("estrategia", "")) != "emboscar":
		_falhar("Predador mudou a estratégia sem experiência anterior."); return
	var estrategia_outro_bioma: Dictionary = comportamento.ajustar_estrategia_com_memoria(estrategia_base, memoria_predador, "presa_teste", "floresta_teste", "deserto", 1, 101)
	if str(estrategia_outro_bioma.get("estrategia", "")) != "emboscar":
		_falhar("Memória de caça contaminou outro bioma."); return

	var memorias_para_herdar := [
		{"especiePresaId":"presa_antiga","ecossistemaId":"floresta_teste","bioma":"mata","estrategiaAnterior":"emboscar","resultado":"perdeu_rastro","horarioUnix":1},
		{"especiePresaId":"presa_teste_3","ecossistemaId":"floresta_teste","bioma":"mata","estrategiaAnterior":"atacar_isolado","resultado":"perdeu_rastro","horarioUnix":98},
		{"especiePresaId":"presa_teste_2","ecossistemaId":"floresta_teste","bioma":"mata","estrategiaAnterior":"perseguir","resultado":"presa_escapou_de_ecossistema","horarioUnix":99},
		{"especiePresaId":"presa_teste","ecossistemaId":"floresta_teste","bioma":"mata","estrategiaAnterior":"emboscar","resultado":"perdeu_rastro","horarioUnix":100}
	]
	var heranca := comportamento.selecionar_aprendizado_herdado(memorias_para_herdar, 101)
	if heranca.size() != 3 or str(heranca[0].get("origemAprendizado", "")) != "herdado":
		_falhar("Filhote não herdou até três experiências recentes válidas."); return
	var memoria_geracional := comportamento.combinar_memoria_cacada_com_heranca([], [
		{"vivo":true,"faseVida":"filhote","aprendizadoHerdado":heranca},
		{"vivo":true,"faseVida":"adulto","aprendizadoHerdado":heranca}
	], 200)
	if memoria_geracional.size() != 3:
		_falhar("A herança só deveria influenciar a estratégia depois da maturidade."); return
	var estrategia_geracional: Dictionary = comportamento.ajustar_estrategia_com_memoria(
		estrategia_base, memoria_geracional, "presa_teste", "floresta_teste", "mata", 1, 200
	)
	if str(estrategia_geracional.get("estrategia", "")) != "perseguir":
		_falhar("A geração adulta não aplicou o aprendizado herdado."); return
	var heranca_sem_repassar := comportamento.selecionar_aprendizado_herdado(heranca, 200)
	if not heranca_sem_repassar.is_empty():
		_falhar("Aprendizado herdado foi repassado como se fosse experiência vivida."); return
	var estrategia_heranca_expirada: Dictionary = comportamento.ajustar_estrategia_com_memoria(
		estrategia_base, memoria_geracional, "presa_teste", "floresta_teste", "mata", 1, 2600102
	)
	if str(estrategia_heranca_expirada.get("estrategia", "")) != "emboscar":
		_falhar("Predisposição herdada continuou ativa além de 30 dias."); return

	var memorias_defensivas := [
		{"especiePredadoraId":"lobo_teste","ecossistemaId":"floresta_teste","bioma":"mata","respostaAprendida":"defender_com_aliados","horarioUnix":100},
		{"especiePredadoraId":"felino_teste","ecossistemaId":"floresta_teste","bioma":"mata","respostaAprendida":"fugir","horarioUnix":99},
		{"especiePredadoraId":"ave_teste","ecossistemaId":"floresta_teste","bioma":"mata","respostaAprendida":"defender","horarioUnix":98},
		{"especiePredadoraId":"ameaca_antiga","ecossistemaId":"floresta_teste","bioma":"mata","respostaAprendida":"fugir","horarioUnix":1}
	]
	var defesa_herdada := comportamento.selecionar_aprendizado_defensivo_herdado(memorias_defensivas, 101)
	if defesa_herdada.size() != 3 or str(defesa_herdada[0].get("origemAprendizado", "")) != "herdado":
		_falhar("Filhote não herdou até três ameaças defensivas recentes."); return
	var memoria_defesa_geracional := comportamento.combinar_memoria_defensiva_com_heranca([], [
		{"vivo":true,"faseVida":"filhote","aprendizadoDefensivoHerdado":defesa_herdada},
		{"vivo":true,"faseVida":"adulto","aprendizadoDefensivoHerdado":defesa_herdada}
	], 200)
	if memoria_defesa_geracional.size() != 3:
		_falhar("Aprendizado defensivo só deveria ser transmitido por adulto vivo."); return
	var memoria_defesa_sem_adulto := comportamento.combinar_memoria_defensiva_com_heranca([], [
		{"vivo":true,"faseVida":"filhote","aprendizadoDefensivoHerdado":defesa_herdada}
	], 200)
	if not memoria_defesa_sem_adulto.is_empty():
		_falhar("Filhote transmitiu aprendizado defensivo antes da maturidade."); return
	var memoria_defesa_expirada := comportamento.combinar_memoria_defensiva_com_heranca([], [
		{"vivo":true,"faseVida":"adulto","aprendizadoDefensivoHerdado":defesa_herdada}
	], 2600102)
	if not memoria_defesa_expirada.is_empty():
		_falhar("Aprendizado defensivo herdado durou mais de 30 dias."); return

	var cacada_cerco: Dictionary = comportamento.decidir_estrategia_caca(1.0, 1.0, 1.0, false, 0.0, false, false, 0, 30.0, 4)
	if str(cacada_cerco.get("estrategia", "")) != "cercar":
		_falhar("Bando forte com quatro predadores não escolheu cercar."); return

	var movimento_grupos = load("res://scripts/sistema_movimento_grupos.gd")
	var instante_formacao := int(Time.get_unix_time_from_system())
	var grupo_formacao := {
		"territorio":{"centro":{"x":100.0,"y":100.0},"raio":100.0},
		"liderAtual":{"individuoId":"lider_formacao"},
		"formacaoTatica":{"tipo":"defesa","centroAmeaca":{"x":180.0,"y":100.0},"raio":24.0,"expiraUnix":instante_formacao + 60},
		"individuos":[
			{"individuoId":"lider_formacao","vivo":true,"posicaoMundo":{"x":100.0,"y":100.0}},
			{"individuoId":"defensor_1","vivo":true,"posicaoMundo":{"x":110.0,"y":100.0}},
			{"individuoId":"defensor_2","vivo":true,"posicaoMundo":{"x":90.0,"y":100.0}}
		]
	}
	var movimento_defesa: Dictionary = movimento_grupos.avancar(grupo_formacao, 1.0, 123)
	if not bool(movimento_defesa.get("ok", false)):
		_falhar("Não calculou a formação defensiva."); return
	var viu_defesa := false
	for atualizacao in movimento_defesa.get("atualizacoes", []):
		if str(atualizacao.get("comportamento", "")) == "protegendo_formacao":
			viu_defesa = true
		var posicao_atualizada: Vector2 = atualizacao.get("posicao", Vector2.ZERO)
		if posicao_atualizada.distance_to(Vector2(100.0, 100.0)) > 100.01:
			_falhar("Formação defensiva ultrapassou o território do grupo."); return
	if not viu_defesa:
		_falhar("Integrantes não assumiram a formação para proteger o grupo."); return
	var grupo_protecao := grupo_formacao.duplicate(true)
	grupo_protecao["formacaoTatica"] = {"tipo":"proteger_vulneraveis","centroProtegido":{"x":100.0,"y":100.0},"individuoProtegidoId":"filhote","raio":24.0,"expiraUnix":instante_formacao + 60}
	grupo_protecao["individuos"] = [
		{"individuoId":"filhote","vivo":true,"faseVida":"filhote","posicaoMundo":{"x":100.0,"y":100.0}},
		{"individuoId":"adulto_a","vivo":true,"faseVida":"adulto","posicaoMundo":{"x":110.0,"y":100.0}},
		{"individuoId":"adulto_b","vivo":true,"faseVida":"adulto","posicaoMundo":{"x":90.0,"y":100.0}}
	]
	var movimento_protecao: Dictionary = movimento_grupos.avancar(grupo_protecao, 1.0, 321)
	if not bool(movimento_protecao.get("ok", false)):
		_falhar("Não calculou a formação de proteção dos vulneráveis."); return
	var protegeu_centro := false
	var guardou_anel := 0
	for atualizacao_protecao in movimento_protecao.get("atualizacoes", []):
		if str(atualizacao_protecao.get("individuoId", "")) == "filhote":
			protegeu_centro = str(atualizacao_protecao.get("comportamento", "")) == "protegido_no_centro"
		elif str(atualizacao_protecao.get("comportamento", "")) == "guardando_individuo_vulneravel":
			guardou_anel += 1
	if not protegeu_centro or guardou_anel != 2:
		_falhar("Adultos não formaram um anel protetor ao redor do filhote."); return

	var grupo_cerco := grupo_formacao.duplicate(true)
	grupo_cerco["formacaoTatica"] = {"tipo":"cerco","centroAlvo":{"x":130.0,"y":100.0},"raio":30.0,"expiraUnix":instante_formacao + 60}
	var movimento_cerco: Dictionary = movimento_grupos.avancar(grupo_cerco, 1.0, 456)
	if not bool(movimento_cerco.get("ok", false)):
		_falhar("Não calculou a formação de cerco."); return
	var viu_cerco := false
	for atualizacao_cerco in movimento_cerco.get("atualizacoes", []):
		if str(atualizacao_cerco.get("comportamento", "")) == "formando_cerco":
			viu_cerco = true
	if not viu_cerco:
		_falhar("Predadores não assumiram posições de cerco."); return

	var grupo_furtivo := grupo_formacao.duplicate(true)
	grupo_furtivo["formacaoTatica"] = {"tipo":"aproximacao_furtiva","centroAlvo":{"x":130.0,"y":100.0},"raio":26.0,"expiraUnix":instante_formacao + 60}
	var movimento_furtivo: Dictionary = movimento_grupos.avancar(grupo_furtivo, 1.0, 789)
	if not bool(movimento_furtivo.get("ok", false)):
		_falhar("Não calculou a aproximação furtiva."); return
	for atualizacao_furtiva in movimento_furtivo.get("atualizacoes", []):
		if str(atualizacao_furtiva.get("comportamento", "")) != "aproximando_furtivamente":
			_falhar("Predadores não receberam estado de aproximação furtiva."); return
		var posicao_original_furtiva := Vector2.ZERO
		for membro_original_furtivo in grupo_furtivo.get("individuos", []):
			if str(membro_original_furtivo.get("individuoId", "")) == str(atualizacao_furtiva.get("individuoId", "")):
				var dados_posicao_original: Dictionary = membro_original_furtivo.get("posicaoMundo", {})
				posicao_original_furtiva = Vector2(float(dados_posicao_original.get("x", 0.0)), float(dados_posicao_original.get("y", 0.0)))
				break
		var deslocamento_furtivo: Vector2 = atualizacao_furtiva.get("posicao", Vector2.ZERO) - posicao_original_furtiva
		if deslocamento_furtivo.length() > 8.1:
			_falhar("A aproximação furtiva excedeu sua velocidade gradual."); return
	print("TESTE DE MIGRAÇÃO ECOLÓGICA: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE MIGRAÇÃO ECOLÓGICA: " + mensagem)
	quit(1)
