extends SceneTree

const REDE = preload("res://scripts/rede_multiplayer.gd")
const ID_MUNDO := "mundo_principal"

func _initialize() -> void:
	var rede = REDE.new()
	var recebidos: Array = []
	rede.anuncio_celeste_recebido.connect(func(anuncio: Dictionary) -> void:
		recebidos.append(anuncio.duplicate(true))
	)
	var anuncio_valido := {
		"mundoId": ID_MUNDO,
		"escopo": "global",
		"titulo": "Lua Carmesim",
		"mensagem": "A noite mudou. Criaturas incomuns despertaram."
	}
	rede._receber_anuncio_celeste({ "mundoId": "mundo_secundario", "escopo": "global", "titulo": "Falso", "mensagem": "Não deve aparecer." })
	rede._receber_anuncio_celeste({ "mundoId": ID_MUNDO, "escopo": "sala", "titulo": "Falso", "mensagem": "Não deve aparecer." })
	rede._receber_anuncio_celeste({ "mundoId": ID_MUNDO, "escopo": "global", "titulo": "", "mensagem": "Sem título." })
	if not recebidos.is_empty():
		rede.free()
		_falhar("Um anúncio de outro mundo, escopo privado ou sem título foi aceito.")
		return
	rede._receber_anuncio_celeste(anuncio_valido)
	if recebidos.size() != 1 or recebidos[0] != anuncio_valido:
		rede.free()
		_falhar("O anúncio global válido não foi encaminhado integralmente.")
		return
	rede.free()
	print("TESTE DE ESCOPO DOS ANÚNCIOS CELESTES: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE ANÚNCIO CELESTE: " + mensagem)
	quit(1)
