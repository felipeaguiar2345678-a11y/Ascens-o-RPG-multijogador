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
			"id":"pet_teste","nome":"Lobo Astral","nivel":5,
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
	var estado_apos := rodada.estado
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
