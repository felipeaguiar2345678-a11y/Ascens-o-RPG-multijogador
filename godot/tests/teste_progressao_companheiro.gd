extends SceneTree

const INVOCACOES = preload("res://scripts/sistema_invocacoes.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var companheiro := {
		"id":"pet_teste","nome":"Lobo Cinzento","especie":"lobo",
		"nivel":9,"experiencia":899,"experienciaProximoNivel":900,
		"vida":80,"vidaMaxima":80,"ataque":20,"defesa":12,"agilidade":15,"poderMagico":8,
		"rank":"C","monstrosConsumidos":0,"evolucao":0
	}
	var alimentado := INVOCACOES.alimentar(companheiro, {"id":"criatura_teste","rank":"SSS","nivel":10})
	assert(bool(alimentado.get("ok", false)), "A essência de uma criatura derrotada deve alimentar o companheiro.")
	var resultado: Dictionary = alimentado.invocacao
	assert(int(resultado.nivel) >= 10, "A experiência absorvida deve aumentar o nível.")
	assert(int(resultado.monstrosConsumidos) == 1, "O contador de essências absorvidas deve ser atualizado.")
	assert(int(resultado.evolucao) >= 1, "O companheiro deve despertar sua primeira forma ao alcançar o nível 10.")
	assert(str(resultado.formaNome).contains("Desperto"), "Criaturas sem forma personalizada devem receber uma evolução coerente.")
	assert(int(resultado.ataque) > 20 and int(resultado.vidaMaxima) > 80, "A evolução deve ampliar atributos reais.")
	var personalizado := {
		"id":"pet_ancestral","nome":"Fera","especie":"fera","nivel":25,"experiencia":0,
		"vida":100,"vidaMaxima":100,"ataque":30,"defesa":20,"agilidade":20,"poderMagico":10,
		"rank":"B","evolucao":0,
		"evolucoes":[{"nome":"Fera Solar","id":"fera_solar","rank":"A","multiplicadores":{"vida":1.5,"ataque":1.6}}]
	}
	var evolucao_personalizada := INVOCACOES._verificar_evolucao(personalizado)
	assert(bool(evolucao_personalizada.evoluiuForma), "O sistema deve aceitar formas definidas nos dados gerados da criatura.")
	assert(str(evolucao_personalizada.invocacao.nome) == "Fera Solar", "A forma definida pela criatura deve ser preservada.")
	print("TESTE DE PROGRESSÃO: absorção de essência, crescimento de atributos e evolução de formas aprovados.")
	quit(0)
