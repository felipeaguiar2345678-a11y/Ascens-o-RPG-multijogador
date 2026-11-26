extends SceneTree

const REDE = preload("res://scripts/rede_multiplayer.gd")
const ID_MUNDO := "mundo_principal"

func _initialize() -> void:
	var rede = REDE.new()
	var recebidos: Array = []
	var relogios: Array = []
	rede.anuncio_celeste_recebido.connect(func(anuncio: Dictionary) -> void:
		recebidos.append(anuncio.duplicate(true))
	)
	rede.relogio_mundo_atualizado.connect(func(contexto: Dictionary) -> void:
		relogios.append(contexto.duplicate(true))
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
	rede._receber_anuncio_celeste({ "mundoId": ID_MUNDO, "escopo": "global", "titulo": "Título válido", "mensagem": "x".repeat(1201) })
	rede._receber_relogio_mundo({ "mundoId": "mundo_secundario", "escopo": "global", "hora": 12 })
	rede._receber_relogio_mundo({ "mundoId": ID_MUNDO, "escopo": "sala", "hora": 12 })
	if not recebidos.is_empty() or not relogios.is_empty():
		rede.free()
		_falhar("Um anúncio de outro mundo, escopo privado ou sem título foi aceito.")
		return
	rede._receber_anuncio_celeste(anuncio_valido)
	if recebidos.size() != 1 or recebidos[0] != anuncio_valido:
		rede.free()
		_falhar("O anúncio global válido não foi encaminhado integralmente.")
		return
	var relogio_valido := { "mundoId": ID_MUNDO, "escopo": "global", "hora": 12, "dia": 4, "periodo": "dia" }
	rede._receber_relogio_mundo(relogio_valido)
	if relogios.size() != 1 or relogios[0] != relogio_valido:
		rede.free()
		_falhar("O relógio global válido não foi encaminhado integralmente.")
		return
	rede.free()
	print("TESTE DE ESCOPO DOS ANÚNCIOS E DO RELÓGIO GLOBAL: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE ANÚNCIO CELESTE: " + mensagem)
	quit(1)
