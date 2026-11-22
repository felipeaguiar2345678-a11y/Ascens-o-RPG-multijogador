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
	var registro := catalogo.registrar_criatura_gerada(criatura)
	if not bool(registro.get("ok", false)):
		_falhar("Não registrou espécie com rota alternativa: " + str(registro.get("erro", ""))); return
	var criado := grupos.criar_grupo_para_criatura("migrante_teste", 1000)
	if not bool(criado.get("ok", false)):
		_falhar("Não criou grupo para teste: " + str(criado.get("erro", ""))); return
	for instante in [1000, 1060, 1120]:
		var ciclo := grupos.avaliar_migracao_por_escassez("grupo_migrante_teste", 0.1, instante)
		if not bool(ciclo.get("ok", false)):
			_falhar("Falhou ao avaliar escassez: " + str(ciclo.get("erro", ""))); return
		if instante < 1120 and bool(ciclo.get("migrou", false)):
			_falhar("Migrou antes de três ciclos consecutivos de escassez."); return
	if not bool(ciclo.get("migrou", false)):
		_falhar("Não migrou após três ciclos consecutivos de escassez."); return
	var grupo: Dictionary = grupos.obter_grupo("grupo_migrante_teste")
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
	print("TESTE DE MIGRAÇÃO ECOLÓGICA: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE MIGRAÇÃO ECOLÓGICA: " + mensagem)
	quit(1)
