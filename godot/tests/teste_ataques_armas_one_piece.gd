extends SceneTree

const Equipamentos = preload("res://scripts/sistema_equipamentos.gd")
const Combate = preload("res://scripts/sistema_combate.gd")

func _initialize() -> void:
	_testar_armas_one_piece_equipaveis()
	_testar_efeitos_de_ataque_normal()
	print("TESTE DE EQUIPAMENTO E ATAQUE ONE PIECE: aprovado")
	quit(0)

func _testar_armas_one_piece_equipaveis() -> void:
	var gryphon: Dictionary = Equipamentos.obter("gryphon")
	assert(str(gryphon.get("origem", "")) == "one_piece")
	assert(str(gryphon.get("raridade", "")) == "mitica")
	assert(int(gryphon.get("dano", 0)) > 0)
	var equipamentos := {"mao_principal":"","mao_secundaria":""}
	var validacao: Dictionary = Equipamentos.validar_equipar(equipamentos, "gryphon", "guerreiro")
	assert(bool(validacao.get("ok", false)))
	assert(str(Equipamentos.equipar(equipamentos, "gryphon", "guerreiro").get("equipamentos", {}).get("mao_principal", "")) == "gryphon")
	var bisento: Dictionary = Equipamentos.obter("murakumogiri")
	assert(int(bisento.get("maos", 0)) == 2)

func _testar_efeitos_de_ataque_normal() -> void:
	assert(str(Combate._obter_efeito_ataque_arma("gryphon").get("efeito", "")) == "haki_do_rei")
	assert(str(Combate._obter_efeito_ataque_arma("murakumogiri").get("efeito", "")) == "tremor")
	assert(str(Combate._obter_efeito_ataque_arma("yoru").get("efeito", "")) == "corte_negro")
	assert(str(Combate._obter_efeito_ataque_arma("kikoku").get("efeito", "")) == "energia_espacial")
	assert(str(Combate._obter_efeito_ataque_arma("wado_ichimonji").get("raridade", "")) == "lendaria")
	assert(str(Combate._obter_efeito_ataque_arma("wado_ichimonji").get("efeito", "")) == "corte_dourado")
	assert(str(Combate._obter_efeito_ataque_arma("shusui").get("efeito", "")) == "aura_negra")
	assert(str(Combate._obter_efeito_ataque_arma("yakuza_kasen").get("raridade", "")) == "mitica")
	assert(str(Combate._obter_efeito_ataque_arma("yakuza_kasen").get("efeito", "")) == "gravidade")
	assert(float(Combate._obter_efeito_ataque_arma("wado_ichimonji").get("intensidadeVisual", 1.0)) < float(Combate._obter_efeito_ataque_arma("gryphon").get("intensidadeVisual", 1.0)))
	assert(Combate._obter_efeito_ataque_arma("espada_ferro").is_empty())
