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
	var cooperacao := grupos.registrar_interacao_social("grupo_migrante_teste", "grupo_guardiao_teste", "cooperacao", 1200)
	if not bool(cooperacao.get("ok", false)):
		_falhar("Não registrou cooperação social."); return
	var segunda_cooperacao := grupos.registrar_interacao_social("grupo_migrante_teste", "grupo_guardiao_teste", "cooperacao", 1260)
	if not bool(segunda_cooperacao.get("ok", false)):
		_falhar("Não registrou a segunda cooperação social."); return
	var grupo_cooperante: Dictionary = grupos.obter_grupo("grupo_migrante_teste")
	var relacao_cooperativa: Dictionary = grupo_cooperante.get("relacoesGrupos", {}).get("grupo_guardiao_teste", {})
	if int(relacao_cooperativa.get("interacoes", 0)) < 2 or str(relacao_cooperativa.get("estado", "")) != "aliado":
		_falhar("Não reconheceu aliança após cooperação repetida."); return
	if grupo_cooperante.get("personalidade", {}).is_empty():
		_falhar("Grupo não recebeu personalidade própria."); return
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
	print("TESTE DE MIGRAÇÃO ECOLÓGICA: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE MIGRAÇÃO ECOLÓGICA: " + mensagem)
	quit(1)
