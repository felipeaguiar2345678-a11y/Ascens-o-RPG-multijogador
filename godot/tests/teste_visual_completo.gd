extends SceneTree

const Tema = preload("res://scripts/tema_visual.gd")
const Palco = preload("res://scripts/palco_combate.gd")
const CriaturaVisual = preload("res://scripts/criatura_errante_visual.gd")
const Avatar = preload("res://scripts/avatar_personagem.gd")

func _initialize() -> void:
	var tema := Tema.criar_tema()
	if tema == null:
		_falhar("O tema global não foi criado.")
		return
	var arena := Palco.new()
	root.add_child(arena)
	arena.size = Vector2(640, 112)
	arena.configurar({"nome":"Aventureiro"}, {"nome":"Fera Arcana","chefe":true})
	arena.registrar_evento("O aventureiro lança uma magia arcana!")
	if arena.nome_heroi != "Aventureiro" or arena.nome_inimigo != "Fera Arcana" or not arena.chefe or arena._tipo_efeito != "magia":
		_falhar("A arena não recebeu os dados dos combatentes.")
		return
	var criatura := CriaturaVisual.new()
	root.add_child(criatura)
	criatura.configurar({
		"nome":"Draco das Cinzas",
		"especieId":"dragao",
		"habitat":"montanhas",
		"bioma":"gelido",
		"chefe":true,
		"lider":true,
		"mutacoes":[{"id":"chifres_de_guerra"}]
	})
	if criatura.especie_id != "dragao" or criatura.habitat != "montanhas" or not criatura.eh_chefe:
		_falhar("A criatura não preservou espécie, habitat e identidade de chefe.")
		return
	var avatar := Avatar.new()
	root.add_child(avatar)
	avatar.configurar({
		"racaId":"draconiano",
		"sexo":"masculino",
		"aparenciaId":"cabelo_prateado",
		"anatomiaRacial":{"altura":1.1,"porte":"robusto","orelhas":"draconicas","chifres":"draconicos"},
		"equipamentos":{"torso":"peitoral_placas","mao_principal":"cajado_runico"}
	})
	if avatar.raca_id != "draconiano" or avatar.equipamentos.get("torso", "") != "peitoral_placas":
		_falhar("O avatar não preservou raça e equipamento.")
		return
	await process_frame
	print("TESTE VISUAL COMPLETO: tema, arena, magia, avatar e silhueta ecológica aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE VISUAL COMPLETO: " + mensagem)
	quit(1)
