extends SceneTree

const Palco = preload("res://scripts/palco_aventura_compartilhada.gd")

func _initialize() -> void:
	var palco := Palco.new()
	root.add_child(palco)
	var encontro := {
		"ativo": true,
		"combate": {
			"supremaEventoId": "evento-001",
			"supremaExecutada": {"nome":"Fúria da Gura Gura","efeito":"terremoto_dimensional"},
			"supremaParticipanteNome": "Portador da Bisento"
		}
	}
	palco.call("configurar_encontro", encontro)
	assert(bool(palco.get("_suprema_ativa")), "O palco deve iniciar o efeito quando recebe um evento novo do servidor.")
	assert(str(palco.get("_suprema_efeito")) == "terremoto_dimensional", "O palco deve usar a identidade visual da arma.")
	palco.call("_process", 0.8)
	var tempo_apos_inicio := float(palco.get("_suprema_tempo"))
	palco.call("configurar_encontro", encontro)
	assert(is_equal_approx(float(palco.get("_suprema_tempo")), tempo_apos_inicio), "Snapshots repetidos do mesmo evento não podem reiniciar a animação.")
	var novo_encontro := encontro.duplicate(true)
	novo_encontro.combate.supremaEventoId = "evento-002"
	novo_encontro.combate.supremaExecutada.efeito = "corte_colossal"
	palco.call("configurar_encontro", novo_encontro)
	assert(is_equal_approx(float(palco.get("_suprema_tempo")), 0.0), "Um evento novo deve iniciar uma nova animação.")
	assert(str(palco.get("_suprema_efeito")) == "corte_colossal", "O próximo evento deve trocar para o efeito próprio da nova arma.")
	palco.call("_process", 3.0)
	assert(not bool(palco.get("_suprema_ativa")), "A animação deve terminar e não permanecer presa na tela.")
	palco.queue_free()
	print("OK: evento visual de Suprema sincronizado e reproduzido uma única vez por identificador.")
	quit(0)
