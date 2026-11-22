extends SceneTree
const RepositorioCriaturas = preload("res://scripts/repositorio_criaturas_servidor.gd")
const RepositorioRecursos = preload("res://scripts/repositorio_recursos_ecologicos_servidor.gd")

func _initialize() -> void:
	var sufixo := str(Time.get_ticks_usec())
	var catalogo = RepositorioCriaturas.new("user://teste_catalogo_recursos_" + sufixo + ".json")
	var fonte := {
		"id":"frutos_compartilhados","capacidade":100.0,"quantidadeInicial":10.0,
		"recuperacaoPorDia":0.0,"consumoPorIndividuoDia":4.0,
		"especiesConsumidoras":["herbivoro_a","herbivoro_b"]
	}
	for especie_id in ["herbivoro_a","herbivoro_b"]:
		var criatura := {
			"id":especie_id,"nome":"Herbívoro " + especie_id,"descricao":"Espécie de teste.",
			"rank":"E","raridade":"comum","nivel":1,"vidaMaxima":20,"ataque":2,
			"defesa":2,"manaMaxima":0,"agilidade":3,"poderMagico":0,
			"experienciaBase":1,"perigo":1,"ecossistemaId":"floresta_arcana",
			"bioma":"bosque","habitat":"clareira","habilidades":[],"chefe":false,
			"tabelaDrops":[],"ecologia":{
				"populacao":{"quantidadeInicial":2,"minima":0,"maxima":10,"nascimentosPorDia":1.0,"mortesPorDia":0.0},
				"territorio":{"grupoId":"grupo_" + especie_id,"centro":{"x":100.0,"y":100.0},"raio":50.0},
				"recursosAmbientais":[fonte.duplicate(true)]
			}
		}
		var registro := catalogo.registrar_criatura_gerada(criatura)
		if not bool(registro.get("ok", false)):
			_falhar("Não registrou espécie com dieta ambiental: " + str(registro.get("erro", ""))); return
	var repositorio = RepositorioRecursos.new("user://teste_recursos_compartilhados_" + sufixo + ".json", catalogo)
	var grupos := [
		{"especieId":"herbivoro_a","individuos":[{"vivo":true},{"vivo":true}]},
		{"especieId":"herbivoro_b","individuos":[{"vivo":true},{"vivo":true}]}
	]
	var resultado := repositorio.processar_tick(grupos, 1000)
	if not bool(resultado.get("ok", false)):
		_falhar("Falhou ao inicializar estoque compartilhado."); return
	resultado = repositorio.processar_tick(grupos, 87400)
	if not bool(resultado.get("ok", false)):
		_falhar("Falhou ao processar competição pelo alimento."); return
	var disponibilidade: Dictionary = resultado["disponibilidadePorEspecie"]
	for id in ["herbivoro_a","herbivoro_b"]:
		if absf(float(disponibilidade.get(id, -1.0)) - 0.625) > 0.001:
			_falhar("A competição não dividiu a disponibilidade entre as duas espécies."); return
	var estoque: Dictionary = resultado["estoques"]["frutos_compartilhados"]
	if absf(float(estoque["quantidade"])) > 0.001:
		_falhar("O estoque compartilhado não foi consumido pela demanda combinada."); return
	var reaberto = RepositorioRecursos.new("user://teste_recursos_compartilhados_" + sufixo + ".json", catalogo)
	if absf(float(reaberto.obter_estado()["recursos"]["frutos_compartilhados"]["quantidade"])) > 0.001:
		_falhar("O estoque ambiental não persistiu após reabrir o repositório."); return
	print("TESTE DE ALIMENTAÇÃO COMPARTILHADA: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE ALIMENTAÇÃO COMPARTILHADA: " + mensagem)
	quit(1)
