extends SceneTree

const COMBATE = preload("res://scripts/sistema_combate.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var perfil := {
		"personagemCriado":true,
		"classeId":"guerreiro",
		"nome":"Teste",
		"forca":5,"inteligencia":5,"agilidade":5,"vitalidade":5,"espirito":5,
		"vida":100,"vidaMaxima":100,"mana":30,"manaMaxima":30,
		"equipamentos":{},
		"invocacaoAtivaId":"pet_teste",
		"invocacoes":[{
			"id":"pet_teste","nome":"Lobo Astral","especie":"lobo","nivel":5,
			"vida":60,"vidaMaxima":60,"ataque":12,"defesa":6,"agilidade":10,
			"poderMagico":8,"habilidades":[{"id":"mordida_arcana","nome":"Mordida Arcana","categoria":"magica","custoMana":3,"multiplicadorDano":1.8}]
		}]
	}
	var criatura := {"id":"alvo_teste","nome":"Alvo de Treino","vidaMaxima":500,"ataque":1,"defesa":1,"agilidade":1,"manaMaxima":0,"poderMagico":0}
	var estado := COMBATE.criar_estado(perfil, criatura)
	assert(not estado.get("invocacao", {}).is_empty(), "Classes que não são Invocador também devem levar o companheiro ativo ao combate.")
	assert(bool(estado.invocacao.get("ativa", false)), "O companheiro ativo deve entrar automaticamente na batalha.")
	var vida_inicial := int(estado.inimigo.vida)
	var rodada := COMBATE.executar_rodada(estado, COMBATE.ACAO_DEFENDER, 12345)
	assert(bool(rodada.get("ok", false)), "A rodada deve ser aceita.")
	var estado_apos: Dictionary = rodada.estado
	assert(int(estado_apos.inimigo.vida) < vida_inicial, "O companheiro deve agir automaticamente mesmo quando o jogador defende.")
	assert(not estado_apos.historico.is_empty(), "A ação do companheiro deve aparecer no histórico.")
	var comando := COMBATE.aplicar_comando_companheiro(estado_apos, "defensivo", "proteger")
	assert(bool(comando.get("ok", false)), "O jogador deve conseguir ordenar proteção.")
	var rodada_protecao := COMBATE.executar_rodada(comando.estado, COMBATE.ACAO_DEFENDER, 12346)
	assert(bool(rodada_protecao.get("ok", false)), "O companheiro deve executar a ordem de proteção.")
	assert(not rodada_protecao.estado.invocacao.get("protegendoMestre", true), "A proteção pontual deve ser consumida ao interceptar um golpe.")
	var ordem_habilidade := COMBATE.aplicar_comando_companheiro(rodada_protecao.estado, "agressivo", "habilidade")
	var rodada_habilidade := COMBATE.executar_rodada(ordem_habilidade.estado, COMBATE.ACAO_DEFENDER, 12347)
	assert(bool(rodada_habilidade.get("ok", false)), "O companheiro deve aceitar a ordem de usar habilidade.")
	assert("\n".join(PackedStringArray(rodada_habilidade.estado.historico)).contains("Mordida Arcana"), "A habilidade herdada deve ser executada pelo companheiro.")
	var estado_combo := estado.duplicate(true)
	estado_combo["cargaCombo"] = 2
	estado_combo["modoCompanheiro"] = "equilibrado"
	estado_combo["contadorTurnosCompanheiro"] = 0
	var rodada_combo := COMBATE.executar_rodada(estado_combo, COMBATE.ACAO_ATAQUE, 12349)
	assert(bool(rodada_combo.get("ok", false)), "O ataque que completa o vínculo deve ser aceito.")
	assert(int(rodada_combo.estado.get("cargaCombo", -1)) == 0, "O combo deve consumir a carga acumulada.")
	assert(int(rodada_combo.estado.get("combosExecutados", 0)) == 1, "O contador de combos deve registrar a execução.")
	assert("\n".join(PackedStringArray(rodada_combo.estado.historico)).contains("COMBO DE VÍNCULO"), "O terceiro impacto do jogador deve liberar o combo sincronizado.")
	assert(str(rodada_combo.estado.get("efeitoHabilidade", {}).get("tipoEfeito", "")) == "combo_companheiro", "O combo deve gerar um efeito visual próprio.")
	assert(str(rodada_combo.estado.efeitoHabilidade.get("estiloCombo", "")) == "cacada", "O lobo deve executar um combo próprio de sua família.")
	assert(str(rodada_combo.estado.efeitoHabilidade.get("nomeCombo", "")) == "Caçada em Dupla", "O combo do lobo deve ter nome e identidade próprios.")
	var companheiro_serpente := estado.duplicate(true)
	companheiro_serpente.invocacao["especie"] = "serpente"
	companheiro_serpente.invocacao["elemento"] = "veneno"
	companheiro_serpente.cargaCombo = 2
	companheiro_serpente.contadorTurnosCompanheiro = 0
	var combo_serpente := COMBATE.executar_rodada(companheiro_serpente, COMBATE.ACAO_ATAQUE, 12350)
	assert(bool(combo_serpente.get("ok", false)), "O combo da serpente deve ser executado.")
	assert(str(combo_serpente.estado.efeitoHabilidade.get("estiloCombo", "")) == "constricao", "A serpente deve usar um combo constritor, sem depender de catálogo fixo.")
	assert(combo_serpente.estado.inimigo.efeitosStatus.any(func(e): return str(e.get("id", "")) == "lentidao"), "O combo constritor deve aplicar lentidão real ao inimigo.")
	var companheiro_fogo := estado.duplicate(true)
	companheiro_fogo.invocacao["elemento"] = "fogo"
	companheiro_fogo.cargaCombo = 2
	companheiro_fogo.contadorTurnosCompanheiro = 0
	var combo_fogo := COMBATE.executar_rodada(companheiro_fogo, COMBATE.ACAO_ATAQUE, 12351)
	assert(bool(combo_fogo.get("ok", false)), "O combo de fogo deve ser executado.")
	assert(combo_fogo.estado.inimigo.efeitosStatus.any(func(e): return str(e.get("id", "")) == "queimadura"), "O combo de fogo deve registrar queimadura com dano periódico.")
	var companheiro_raio := estado.duplicate(true)
	companheiro_raio.invocacao["elemento"] = "raio"
	companheiro_raio.cargaCombo = 2
	companheiro_raio.contadorTurnosCompanheiro = 0
	var combo_raio := COMBATE.executar_rodada(companheiro_raio, COMBATE.ACAO_ATAQUE, 12352)
	assert(bool(combo_raio.get("ok", false)), "O combo elétrico deve ser executado.")
	assert(combo_raio.estado.inimigo.efeitosStatus.any(func(e): return str(e.get("id", "")) == "atordoamento"), "O combo elétrico deve aplicar atordoamento real.")
	var interface_combate = preload("res://scripts/interface_combate.gd")
	var texto_status := interface_combate.formatar_efeitos_status([
		{"id":"queimadura","nome":"Queimadura","turnos":2,"danoPorTurno":14},
		{"id":"atordoamento","nome":"Atordoado","turnos":1,"danoPorTurno":0}
	])
	assert(texto_status.contains("Queimadura") and texto_status.contains("2 turno(s)"), "A interface deve mostrar o nome e os turnos restantes de cada efeito.")
	assert(texto_status.contains("14 dano/turno") and texto_status.contains("Atordoado"), "A interface deve mostrar o dano periódico e efeitos sem dano.")
	assert(interface_combate.formatar_efeitos_status([]).is_empty(), "A interface não deve exibir efeitos quando não há condições ativas.")
	var palco_combate = preload("res://scripts/palco_combate.gd")
	var indicadores := palco_combate.obter_indicadores_status([
		{"id":"veneno","turnos":3},
		{"id":"atordoamento","turnos":1},
		{"id":"queimadura","turnos":0}
	])
	assert(indicadores.size() == 2, "O palco deve desenhar apenas condições ainda ativas.")
	assert(indicadores[0].get("icone", "") == "☠" and int(indicadores[0].get("turnos", 0)) == 3, "O veneno deve ter ícone próprio e duração visível.")
	assert(indicadores[1].get("icone", "") == "⚡" and int(indicadores[1].get("turnos", 0)) == 1, "O atordoamento deve ter sinal visual e duração própria.")
	assert(palco_combate.obter_indicadores_status([]).is_empty(), "Sem efeitos ativos, nenhum indicador deve ser desenhado.")
	assert(palco_combate._cor_elemento("fogo") != palco_combate._cor_elemento("gelo"), "O sopro de fogo e o sopro de gelo devem ter assinaturas visuais diferentes.")
	var destruicao_fogo := palco_combate.obter_configuracao_destruicao("sopro_elemental", "fogo")
	var destruicao_gelo := palco_combate.obter_configuracao_destruicao("sopro_elemental", "gelo")
	assert(destruicao_fogo.forma == "queimadura" and destruicao_gelo.forma == "queimadura", "Sopros elementais devem deixar marcas da mesma família visual.")
	assert(destruicao_fogo.cor != destruicao_gelo.cor, "As cicatrizes devem preservar a cor elemental.")
	assert(palco_combate.obter_configuracao_destruicao("tremor_tectonico").forma == "fissura", "Tremores devem deixar fissuras no piso.")
	assert(palco_combate.obter_configuracao_destruicao("onda_abissal").forma == "erosao", "Ondas devem deixar marcas de erosão.")
	assert(palco_combate._cor_elemento("raio") != palco_combate._cor_elemento("sombra"), "O sopro elétrico e o sombrio devem manter cores distintas.")
	assert(palco_combate.obter_estilo_combo_companheiro({"estiloCombo":"cacada"}) == "cacada", "O combo de caça deve preservar sua identidade visual.")
	assert(palco_combate.obter_estilo_combo_companheiro({"especie":"serpente"}) == "constricao", "Serpentes devem receber visual constritor.")
	assert(palco_combate.obter_estilo_combo_companheiro({"especie":"ave"}) == "mergulho", "Companheiros alados devem receber visual de mergulho.")
	assert(palco_combate.obter_estilo_combo_companheiro({"elemento":"fogo"}) == "elemental", "Companheiros elementais devem herdar identidade do elemento.")
	var perfil_invocador := perfil.duplicate(true)
	perfil_invocador["classeId"] = "invocador"
	perfil_invocador["habilidades"] = [{"id":"comando_vinculo","nome":"Comando do Vínculo","categoria":"invocacao","invocacaoId":"pet_teste","custoMana":5}]
	var estado_invocador := COMBATE.criar_estado(perfil_invocador, criatura)
	var comando_invocador := COMBATE.executar_rodada(estado_invocador, COMBATE.ACAO_HABILIDADE, 12348, "alvo_teste", "comando_vinculo")
	assert(bool(comando_invocador.get("ok", false)), "A habilidade de vínculo do Invocador deve continuar funcionando com o pet já ativo.")
	assert("\n".join(PackedStringArray(comando_invocador.estado.historico)).contains("Mordida Arcana"), "A habilidade de vínculo deve ordenar uma habilidade do companheiro.")
	assert(int(comando_invocador.estado.jogador.mana) == 25, "O comando do Invocador deve consumir seu custo de mana.")
	print("TESTE DE COMBATE DO COMPANHEIRO: entrada automática, ataque autônomo, ordens, proteção, habilidades e comando do Invocador aprovados.")
	quit(0)
