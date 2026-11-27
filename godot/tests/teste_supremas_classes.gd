extends SceneTree

const Sistema = preload("res://scripts/sistema_supremas_classes.gd")
const SistemaCombate = preload("res://scripts/sistema_combate.gd")

func _initialize() -> void:
	_testar_catalogo_completo()
	_testar_desbloqueio_por_nivel()
	_testar_sinergias_sem_substituir_supremas()
	_testar_estado_de_combate()
	print("TESTE DAS SUPREMAS DE CLASSE: aprovado")
	quit()

func _testar_catalogo_completo() -> void:
	var classes := ["guerreiro","cavaleiro","assassino","arqueiro","mago","curandeiro","monge","invocador","espadachim"]
	for classe_id in classes:
		var dados: Dictionary = Sistema.obter_dados(classe_id)
		assert(not dados.is_empty(), "Classe sem Suprema: %s" % classe_id)
		assert(not str(dados.get("suprema", {}).get("nome", "")).is_empty())
		assert(not str(dados.get("avancada", {}).get("nome", "")).is_empty())

func _testar_desbloqueio_por_nivel() -> void:
	var estado := Sistema.criar_estado("espadachim", 49, "enma")
	assert(not bool(estado["suprema"]["desbloqueada"]))
	assert(not bool(estado["avancada"]["desbloqueada"]))
	estado = Sistema.atualizar_nivel(estado, 50)
	assert(bool(estado["suprema"]["desbloqueada"]))
	assert(not bool(estado["avancada"]["desbloqueada"]))
	estado = Sistema.atualizar_nivel(estado, 80)
	assert(bool(estado["suprema"]["desbloqueada"]))
	assert(bool(estado["avancada"]["desbloqueada"]))

func _testar_sinergias_sem_substituir_supremas() -> void:
	var enma := Sistema.criar_estado("espadachim", 80, "enma")
	assert(str(enma["combinacao"].get("id", "")) == "dominio_enma")
	assert(str(enma["suprema"]["id"]) == "dominio_absoluto")
	assert(str(enma["avancada"]["id"]) == "corte_do_horizonte")
	var tripla := Sistema.criar_estado("espadachim", 80, "tripla_katana")
	assert(str(tripla["combinacao"].get("id", "")) == "santoryu_asura_absoluto")
	var guerreiro_enma := Sistema.criar_estado("guerreiro", 80, "enma")
	assert(guerreiro_enma["combinacao"].is_empty(), "A sinergia de Espadachim não deve ser liberada para outra classe")
	var espada_comum := Sistema.criar_estado("espadachim", 80, "espada_ferro")
	assert(espada_comum["combinacao"].is_empty(), "Armas comuns não devem liberar fusões especiais")

func _testar_estado_de_combate() -> void:
	var perfil := {
		"personagemCriado":true,"nivel":80,"classeId":"espadachim",
		"forca":10,"inteligencia":5,"agilidade":10,"vitalidade":8,"espirito":6,
		"vida":176,"vidaMaxima":176,"mana":98,"manaMaxima":98,
		"equipamentos":{"mao_principal":"enma"}
	}
	var criatura := {"id":"lobo_teste","nome":"Lobo de teste","vida":100,"vidaMaxima":100,"ataque":5}
	var estado: Dictionary = SistemaCombate.criar_estado(perfil, criatura)
	assert(not estado.is_empty())
	assert(bool(estado["supremasClasse"]["suprema"]["desbloqueada"]))
	assert(bool(estado["supremasClasse"]["avancada"]["desbloqueada"]))
	assert(str(estado["supremasClasse"]["combinacao"].get("id", "")) == "dominio_enma")
	assert(str(estado["suprema"].get("armaId", "")) == "enma" or estado["suprema"].is_empty())
