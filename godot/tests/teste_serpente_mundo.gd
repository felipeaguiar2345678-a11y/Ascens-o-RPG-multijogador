extends SceneTree

const Sistema = preload("res://scripts/sistema_serpente_mundo.gd")
const Combate = preload("res://scripts/sistema_combate.gd")
const Colisoes = preload("res://scripts/sistema_colisoes_mundo.gd")

func _initialize() -> void:
	assert(Sistema.VIDA_TOTAL_PADRAO == Sistema.VIDA_BASE_NORMAL_REFERENCIA * 25, "A Serpente Mundial deve ter 25x a vida normal de referência.")
	var serpente_gerada := Sistema.preparar_criatura_gerada({"id":"serpente_marinha_teste","nome":"Serpente Marinha","familiaCriatura":"serpente","habitat":"mar profundo","bioma":"oceano","chefe":true,"vidaMaxima":1200,"ataque":40,"defesa":30})
	assert(int(serpente_gerada.vidaMaxima) == 30000, "Chefe serpente deve receber 25x a vida-base.")
	assert(int(serpente_gerada.ataque) == 80 and int(serpente_gerada.defesa) == 60, "Chefe serpente deve receber atributos ofensivos e defensivos reforçados.")
	assert(serpente_gerada.padroesAtaque.size() >= 4, "Serpentes geradas devem receber padrões de ataque adequados ao habitat.")
	var serpente_sem_chefe := Sistema.preparar_criatura_gerada({"id":"cobra_teste","nome":"Cobra das Cinzas","familiaCriatura":"cobra","habitat":"floresta","bioma":"floresta","chefe":false,"vidaMaxima":100})
	assert(int(serpente_sem_chefe.vidaMaxima) == 100, "Serpentes comuns não devem receber multiplicador de chefe.")
	var serpente_reprocessada := Sistema.preparar_criatura_gerada(serpente_gerada)
	assert(int(serpente_reprocessada.vidaMaxima) == 30000, "A escala de vida não pode ser aplicada duas vezes.")
	var inimigo_com_padroes := {"nome":"Serpente de Teste","rank":"E","padroesAtaque":serpente_sem_chefe.padroesAtaque,"turnoAtaqueEspecial":0}
	var historico_ataques: Array = []
	var primeiro_turno := Combate._obter_ataque_especial_para_impacto(inimigo_com_padroes, historico_ataques)
	assert(not bool(primeiro_turno.preparando), "A criatura não deve usar especial em toda resposta.")
	var segundo_turno := Combate._obter_ataque_especial_para_impacto(inimigo_com_padroes, historico_ataques)
	assert(bool(segundo_turno.preparando), "A serpente deve anunciar o especial antes de causar dano.")
	inimigo_com_padroes["ataqueEspecialPreparando"] = segundo_turno.duplicate(true)
	var impacto := Combate._obter_ataque_especial_para_impacto(inimigo_com_padroes, historico_ataques)
	assert(not bool(impacto.preparando), "O golpe anunciado deve atingir somente na resposta seguinte.")
	assert(float(impacto.multiplicador) > 1.0, "O ataque especial precisa aplicar o multiplicador do golpe e do rank.")
	assert(not inimigo_com_padroes.has("ataqueEspecialPreparando"), "O aviso pendente deve ser consumido no impacto.")
	assert(historico_ataques.size() >= 2, "O histórico deve anunciar e registrar o ataque especial.")
	var estado := Sistema.criar_estado(1000)
	var entrada_aviso := Sistema.entrar(estado, "uid_aviso", 4, Vector2(10, 10), Vector2.ZERO)
	var aviso := Sistema.iniciar_ataque_telegrafado(entrada_aviso.estado, 0)
	assert(aviso.has("ataquePreparando"), "A serpente deve anunciar o ataque antes do impacto.")
	var ataque_aviso: Dictionary = aviso.ataquePreparando
	assert(int(ataque_aviso.impactoUnix) > int(Time.get_unix_time_from_system()))
	var sopro := Sistema.PADROES_ATAQUE_MUNDIAL[3]
	assert(float(sopro.danoMultiplicador) >= 5.0 and bool(sopro.destruirCenario), "O sopro primordial deve ser devastador e destruir o cenário.")
	var dano_sopro := Sistema.calcular_dano_ataque({"vidaMaxima":100,"vitalidade":0}, sopro, "")
	var dano_sopro_esquiva := Sistema.calcular_dano_ataque({"vidaMaxima":100,"vitalidade":0}, sopro, "esquivar")
	assert(dano_sopro >= 60 and dano_sopro_esquiva < dano_sopro, "O sopro deve causar dano massivo em área, com esquiva reduzindo o impacto.")
	var chefe_teste := {"id":"chefe_teste","nome":"Titã Vulcânico","chefe":true,"rank":"SS","elemento":"fogo","padroesAtaque":[{"id":"erupcao_colossal","nome":"Erupção Colossal","efeito":"sopro_area","destruirCenario":true}]}
	var marca_chefe := Sistema.obter_configuracao_marca_chefe(chefe_teste, "Titã Vulcânico executa Erupção Colossal!")
	assert(not marca_chefe.is_empty() and str(marca_chefe.tipo) == "cratera_queimada" and str(marca_chefe.elemento) == "fogo", "Chefes de qualquer família devem gerar marcas com tipo e elemento do ataque.")
	assert(Sistema.obter_configuracao_marca_chefe({"nome":"Criatura comum","chefe":false,"padroesAtaque":chefe_teste.padroesAtaque}, "Criatura comum executa Erupção Colossal!").is_empty(), "Criaturas comuns não devem deixar cicatrizes de chefe.")
	assert(Sistema.obter_configuracao_marca_chefe(chefe_teste, "Titã Vulcânico executa Mordida!") .is_empty(), "Ataques sem efeito destrutivo não devem marcar o mapa.")
	var estado_devastado := Sistema.criar_estado(1000)
	var agora_marca := int(Time.get_unix_time_from_system())
	var estado_com_marca := Sistema.registrar_marca_destruicao(estado_devastado, {"x":1200.0,"y":285.0,"raio":120.0,"tipo":"cratera_queimada","elemento":"fogo","origem":"chefe_teste"}, agora_marca)
	estado_com_marca["revisaoSincronizacao"] = 7
	estado_com_marca["atualizadoUnix"] = agora_marca
	var snapshot_marca := Sistema.obter_estado_publico(estado_com_marca)
	var marcas_publicas: Array = snapshot_marca.get("marcasDestruicao", [])
	assert(marcas_publicas.size() == 1 and int(marcas_publicas[0].expiraUnix) == agora_marca + 1800, "Cicatriz deve ser compartilhada por 30 minutos em tempo real.")
	assert(int(snapshot_marca.get("revisaoSincronizacao", 0)) == 7 and int(snapshot_marca.get("atualizadoUnix", 0)) == agora_marca, "O snapshot de mundo deve carregar revisão e horário autoritativo para sincronização de entrada e recuperação.")
	var snapshot_global := Sistema.obter_snapshot_global(estado_com_marca, "mundo_principal")
	var snapshot_outra_sala := Sistema.obter_snapshot_global(estado_com_marca, "mundo_principal")
	assert(str(snapshot_global.get("escopo", "")) == "global" and str(snapshot_global.get("mundoId", "")) == "mundo_principal", "Toda sala deve receber o mesmo identificador de mundo e escopo global.")
	assert(snapshot_global == snapshot_outra_sala and int(snapshot_global.get("vida", 0)) == int(estado_com_marca.get("vida", 0)), "Salas diferentes devem consumir snapshots idênticos da mesma vida global da Serpente.")
	assert(not snapshot_global.has("participantesPorUid") and not snapshot_global.has("tentativasDomesticacao"), "O snapshot global não pode expor dados privados de participantes.")
	assert(Sistema.obter_snapshot_global({}, "mundo_principal").is_empty() and Sistema.obter_snapshot_global(estado_com_marca, "").is_empty(), "Snapshot global exige estado e identidade de mundo válidos.")
	assert(Sistema.obter_marcas_destruicao_ativas(estado_com_marca, agora_marca + 1799).size() == 1, "Marca deve continuar visível antes de completar 30 minutos.")
	assert(Sistema.obter_marcas_destruicao_ativas(estado_com_marca, agora_marca + 1800).is_empty(), "Marca deve expirar após 30 minutos.")
	assert(Sistema.registrar_marca_destruicao(estado_devastado, {"x":-1.0,"y":285.0,"raio":120.0,"tipo":"cratera"}, agora_marca).get("marcasDestruicao", []).is_empty(), "Coordenadas inválidas não podem criar marcas.")
	estado_devastado["cenarioDevastado"] = true
	estado_devastado["ultimaDevastacaoUnix"] = int(Time.get_unix_time_from_system())
	var publico_devastado := Sistema.obter_estado_publico(estado_devastado)
	assert(bool(publico_devastado.get("cenarioDevastado", false)) and int(publico_devastado.get("ultimaDevastacaoUnix", 0)) > 0, "A devastação e seu instante devem ser compartilhados com todos os clientes.")
	var zona := {"x": 789.0, "y": 1172.5, "raio": 45.0}
	var zona_em_recuperacao := {"x":789.0,"y":1172.5,"raio":45.0,"recuperacaoUnix":int(Time.get_unix_time_from_system()) + 60}
	var zona_recuperada := {"x":789.0,"y":1172.5,"raio":45.0,"recuperacaoUnix":int(Time.get_unix_time_from_system()) - 1}
	assert(not Colisoes.trajeto_valido(Vector2(789.0, 1172.5), Vector2(789.0, 1172.5)), "Árvore intacta deve continuar bloqueando a passagem.")
	assert(Colisoes.trajeto_valido(Vector2(789.0, 1172.5), Vector2(789.0, 1172.5), false, zona), "A área atingida pelo sopro deve remover o bloqueio da árvore destruída.")
	assert(Colisoes.trajeto_valido(Vector2(789.0, 1172.5), Vector2(789.0, 1172.5), false, zona_em_recuperacao), "O terreno deve permanecer livre durante a recuperação ambiental.")
	var marca_arvore_ativa := [{"x":789.0,"y":1172.5,"raio":45.0,"expiraUnix":int(Time.get_unix_time_from_system()) + 60}]
	var marca_arvore_expirada := [{"x":789.0,"y":1172.5,"raio":45.0,"expiraUnix":int(Time.get_unix_time_from_system()) - 1}]
	assert(Colisoes.trajeto_valido(Vector2(789.0, 1172.5), Vector2(789.0, 1172.5), false, {}, marca_arvore_ativa), "Cicatriz individual ativa deve liberar a colisão da árvore atingida.")
	assert(not Colisoes.trajeto_valido(Vector2(789.0, 1172.5), Vector2(789.0, 1172.5), false, {}, marca_arvore_expirada), "A colisão da árvore deve retornar quando a cicatriz individual expirar.")
	assert(not Colisoes.trajeto_valido(Vector2(789.0, 1172.5), Vector2(789.0, 1172.5), false, zona_recuperada), "Árvores e obstáculos devem voltar a bloquear a passagem após a recuperação.")
	var rocha_teste := Vector2(1040.0, 490.0)
	assert(not Colisoes.trajeto_valido(rocha_teste, rocha_teste), "Rocha intacta deve bloquear a passagem.")
	assert(Colisoes.trajeto_valido(rocha_teste, rocha_teste, false, {"x":1200.0,"y":285.0,"raio":480.0}), "O sopro deve remover a colisão das rochas atingidas.")
	var marca_rocha := [{"x":1040.0,"y":490.0,"raio":35.0,"expiraUnix":int(Time.get_unix_time_from_system()) + 60}]
	assert(Colisoes.trajeto_valido(rocha_teste, rocha_teste, false, {}, marca_rocha), "Cicatriz individual deve remover a colisão da rocha atingida.")
	var posto_teste := Vector2(970.0, 560.0)
	assert(not Colisoes.trajeto_valido(posto_teste, posto_teste), "Posto de vigia intacto deve bloquear a passagem.")
	assert(Colisoes.trajeto_valido(posto_teste, posto_teste, false, {"x":1200.0,"y":285.0,"raio":480.0}), "Estruturas fora de Aurelia atingidas pelo sopro devem ser destruídas.")
	var marca_estrutura := [{"x":970.0,"y":560.0,"raio":40.0,"expiraUnix":int(Time.get_unix_time_from_system()) + 60}]
	assert(Colisoes.trajeto_valido(posto_teste, posto_teste, false, {}, marca_estrutura), "Cicatriz individual deve remover a colisão da estrutura atingida.")
	var edificio_aurelia := Vector2(1260.0, 898.0)
	assert(not Colisoes.trajeto_valido(edificio_aurelia, edificio_aurelia, false, {"x":1200.0,"y":800.0,"raio":900.0}), "Estruturas de Aurelia devem continuar protegidas mesmo dentro de uma zona ampliada.")
	var estado_com_zona := estado_devastado.duplicate(true)
	estado_com_zona["zonaDevastada"] = {"x": 1200.0, "y": 285.0, "raio": 480.0, "tipo": "sopro_primordial"}
	var publico_com_zona := Sistema.obter_estado_publico(estado_com_zona)
	assert(float(publico_com_zona.zonaDevastada.raio) == 480.0, "A zona física destruída deve ser compartilhada com todos os clientes.")
	var zona_publicada := {"x":1200.0,"y":285.0,"raio":480.0,"recuperacaoUnix":int(Time.get_unix_time_from_system()) + Sistema.TEMPO_RECUPERACAO_CENARIO_SEGUNDOS}
	estado_com_zona["zonaDevastada"] = zona_publicada
	assert(int(Sistema.obter_estado_publico(estado_com_zona).zonaDevastada.recuperacaoUnix) == int(zona_publicada.recuperacaoUnix), "O prazo de recuperação deve ser compartilhado com todos os jogadores.")
	var dano_normal := Sistema.calcular_dano_ataque({"vidaMaxima":100,"vitalidade":5}, ataque_aviso, "")
	var dano_defesa := Sistema.calcular_dano_ataque({"vidaMaxima":100,"vitalidade":5}, ataque_aviso, "defender")
	var dano_esquiva := Sistema.calcular_dano_ataque({"vidaMaxima":100,"vitalidade":5}, ataque_aviso, "esquivar")
	assert(dano_esquiva < dano_defesa and dano_defesa < dano_normal, "Esquiva e defesa precisam reduzir o impacto.")
	assert(not estado.is_empty())
	var longe := Sistema.entrar(estado, "uid_a", 2, Vector2(1000, 1000), Vector2.ZERO)
	assert(not bool(longe.get("ok", false)), "Não pode entrar na incursão fora da arena.")
	var entrada_a := Sistema.entrar(estado, "uid_a", 2, Vector2(40, 30), Vector2.ZERO)
	assert(bool(entrada_a.get("ok", false)))
	var entrada_b := Sistema.entrar(entrada_a.estado, "uid_b", 3, Vector2(20, 20), Vector2.ZERO)
	assert(bool(entrada_b.get("ok", false)), "Outro jogador deve compartilhar a mesma incursão.")
	var perfil_a := {"forca": 20, "inteligencia": 5, "espirito": 5}
	var ataque_a := Sistema.aplicar_ataque(entrada_b.estado, "uid_a", 2, perfil_a, "ataque", 5000)
	assert(bool(ataque_a.get("ok", false)))
	assert(int(ataque_a.estado.vida) == 928)
	var repetido := Sistema.aplicar_ataque(ataque_a.estado, "uid_a", 2, perfil_a, "ataque", 5500)
	assert(not bool(repetido.get("ok", false)), "O intervalo por participante deve bloquear spam.")
	var perfil_b := {"forca": 30, "inteligencia": 5, "espirito": 5}
	var ataque_b := Sistema.aplicar_ataque(ataque_a.estado, "uid_b", 3, perfil_b, "ataque", 5500)
	assert(bool(ataque_b.get("ok", false)))
	assert(int(ataque_b.estado.vida) == 826)
	assert(Sistema.calcular_dano_serpente({"vidaMaxima": 100, "vitalidade": 5}) == 7, "Vitalidade reduz o dano do tremor.")
	var quase_morto: Dictionary = ataque_b.estado.duplicate(true)
	quase_morto["vida"] = 50
	var final := Sistema.aplicar_ataque(quase_morto, "uid_a", 2, perfil_a, "ataque", 7000)
	assert(bool(final.get("derrotada", false)))
	assert(str(final.estado.status) == Sistema.STATUS_DERROTADA)
	assert(int(final.estado.proximoRenascimentoUnix) == int(final.estado.derrotadaUnix) + Sistema.TEMPO_RENASCIMENTO_SEGUNDOS)
	assert(bool(final.estado.serpenteOriginalPreservada))
	assert(not bool(Sistema.registrar_tentativa_filhote(final.estado, "uid_c").get("ok", false)))
	var tentativa := Sistema.registrar_tentativa_filhote(final.estado, "uid_a")
	assert(bool(tentativa.get("ok", false)))
	assert(int(tentativa.get("restantes", -1)) == 2)
	var ciclo: Dictionary = tentativa.estado
	for i in range(2):
		ciclo = Sistema.registrar_tentativa_filhote(ciclo, "uid_a").estado
	assert(not bool(Sistema.registrar_tentativa_filhote(ciclo, "uid_a").get("ok", false)))
	assert(bool(Sistema.registrar_tentativa_filhote(final.estado, "uid_b").get("ok", false)))
	var renascido := Sistema.verificar_renascimento(final.estado, int(final.estado.proximoRenascimentoUnix))
	assert(str(renascido.status) == Sistema.STATUS_DISPONIVEL)
	assert(int(renascido.ciclos) == 2)
	assert(int(renascido.totalDerrotas) == 1)
	assert(renascido.tentativasDomesticacao.is_empty())
	var antes_da_hora := Sistema.verificar_renascimento(final.estado, int(final.estado.proximoRenascimentoUnix) - 1)
	assert(antes_da_hora == final.estado)
	print("OK: arena, vida compartilhada, tremor, defesa por vitalidade, derrota, filhote e renascimento.")
	quit()
