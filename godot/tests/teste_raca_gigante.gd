extends SceneTree

const Catalogo = preload("res://scripts/catalogo_criacao_personagem.gd")
const Avatar = preload("res://scripts/avatar_personagem.gd")
const Combate = preload("res://scripts/sistema_combate.gd")

func _initialize() -> void:
	if not Catalogo.RACAS.has("gigante") or not Catalogo.ANATOMIA_RACAS.has("gigante"):
		_falhar("A raça Gigante não está cadastrada no catálogo e na anatomia.")
		return
	var perfil := Catalogo.montar_perfil("masculino", "masc_cabelo_curto", "gigante", "guerreiro")
	if perfil.is_empty() or str(perfil.get("racaId", "")) != "gigante":
		_falhar("A criação não gerou um perfil Gigante válido.")
		return
	if int(perfil.get("vidaMaxima", 0)) <= 0 or int(perfil.get("defesaPercentual", 0)) != 120:
		_falhar("O bônus de vida ou defesa racial não foi aplicado.")
		return
	if int(perfil.get("velocidadePercentual", 100)) != 88 or int(perfil.get("velocidadeAtaquePercentual", 100)) != 92:
		_falhar("As penalidades de mobilidade e velocidade de ataque não foram registradas.")
		return
	var avatar := Avatar.new()
	root.add_child(avatar)
	avatar.configurar(perfil)
	if avatar.raca_id != "gigante" or not is_equal_approx(avatar.scale.y, 1.35) or not is_equal_approx(avatar.scale.x, 1.32):
		_falhar("O avatar não recebeu a silhueta colossal.")
		return
	perfil["personagemCriado"] = true
	perfil["nome"] = "Teste Gigante"
	var estado := Combate.criar_estado(perfil, {"id":"lobo_teste","nome":"Lobo de teste","vida":50,"vidaMaxima":50,"ataque":10})
	if estado.is_empty() or int(estado.get("jogador", {}).get("defesa", 0)) < 1:
		_falhar("O combate não aplicou o modificador de defesa do Gigante.")
		return
	print("TESTE RAÇA GIGANTE: criação, vida, defesa, penalidades e anatomia aprovadas.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE RAÇA GIGANTE: " + mensagem)
	quit(1)
