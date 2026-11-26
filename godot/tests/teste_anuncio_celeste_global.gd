extends SceneTree

const REDE = preload("res://scripts/rede_multiplayer.gd")
const SISTEMA_CICLO = preload("res://scripts/sistema_ciclo_noturno.gd")
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
	var relogio_invalido: Dictionary = SISTEMA_CICLO.criar_contexto_por_tempo_unix(1700000000, 123)
	relogio_invalido["mundoId"] = ID_MUNDO
	relogio_invalido["escopo"] = "global"
	var relogio_outro_mundo := relogio_invalido.duplicate(true)
	relogio_outro_mundo["mundoId"] = "mundo_secundario"
	var relogio_privado := relogio_invalido.duplicate(true)
	relogio_privado["escopo"] = "sala"
	var relogio_hora_invalida := relogio_invalido.duplicate(true)
	relogio_hora_invalida["hora"] = 24
	var relogio_periodo_invalido := relogio_invalido.duplicate(true)
	relogio_periodo_invalido["periodo"] = "eclipse"
	var relogio_evento_invalido := relogio_invalido.duplicate(true)
	relogio_evento_invalido["eventoCeleste"] = []
	rede._receber_relogio_mundo(relogio_outro_mundo)
	rede._receber_relogio_mundo(relogio_privado)
	rede._receber_relogio_mundo(relogio_hora_invalida)
	rede._receber_relogio_mundo(relogio_periodo_invalido)
	rede._receber_relogio_mundo(relogio_evento_invalido)
	if not recebidos.is_empty() or not relogios.is_empty():
		rede.free()
		_falhar("Um anúncio de outro mundo, escopo privado ou sem título foi aceito.")
		return
	rede._receber_anuncio_celeste(anuncio_valido)
	if recebidos.size() != 1 or recebidos[0] != anuncio_valido:
		rede.free()
		_falhar("O anúncio global válido não foi encaminhado integralmente.")
		return
	var relogio_valido: Dictionary = SISTEMA_CICLO.criar_contexto_por_tempo_unix(1700000000, 123)
	relogio_valido["mundoId"] = ID_MUNDO
	relogio_valido["escopo"] = "global"
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
