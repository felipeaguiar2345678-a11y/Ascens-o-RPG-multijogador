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
	# O snapshot público da Serpente também precisa ser íntegro e monotônico.
	var estado_serpente: Dictionary = REDE.SISTEMA_SERPENTE_MUNDO.criar_estado()
	estado_serpente["revisaoSincronizacao"] = 5
	estado_serpente["atualizadoUnix"] = 1700000000
	var snapshot_serpente: Dictionary = REDE.SISTEMA_SERPENTE_MUNDO.obter_snapshot_global(estado_serpente, ID_MUNDO)
	var snapshots: Array = []
	rede.estado_serpente_mundo_atualizado.connect(func(snapshot: Dictionary) -> void:
		snapshots.append(snapshot.duplicate(true))
	)
	var snapshot_outro_mundo := snapshot_serpente.duplicate(true)
	snapshot_outro_mundo["mundoId"] = "mundo_secundario"
	var snapshot_vida_invalida := snapshot_serpente.duplicate(true)
	snapshot_vida_invalida["vida"] = "vida adulterada"
	var snapshot_status_invalido := snapshot_serpente.duplicate(true)
	snapshot_status_invalido["status"] = "invencivel"
	var snapshot_marcas_invalidas := snapshot_serpente.duplicate(true)
	snapshot_marcas_invalidas["marcasDestruicao"] = [{"x": -999, "y": 20, "raio": 50, "tipo": "cratera"}]
	rede._receber_estado_serpente_mundo(snapshot_outro_mundo)
	rede._receber_estado_serpente_mundo(snapshot_vida_invalida)
	rede._receber_estado_serpente_mundo(snapshot_status_invalido)
	rede._receber_estado_serpente_mundo(snapshot_marcas_invalidas)
	if not snapshots.is_empty():
		rede.free()
		_falhar("Aceitou snapshot da Serpente com mundo, vida, status ou marcas inválidas.")
		return
	rede._receber_estado_serpente_mundo(snapshot_serpente)
	if snapshots.size() != 1 or snapshots[0] != snapshot_serpente:
		rede.free()
		_falhar("Não aceitou o snapshot global válido da Serpente.")
		return
	var snapshot_repetido := snapshot_serpente.duplicate(true)
	snapshot_repetido["vida"] = 1
	var snapshot_antigo := snapshot_serpente.duplicate(true)
	snapshot_antigo["revisaoSincronizacao"] = 4
	rede._receber_estado_serpente_mundo(snapshot_repetido)
	rede._receber_estado_serpente_mundo(snapshot_antigo)
	if snapshots.size() != 1 or int(rede.obter_estado_serpente_mundo_publico().get("vida", 0)) != int(snapshot_serpente["vida"]):
		rede.free()
		_falhar("Uma revisão repetida ou atrasada alterou o estado público da Serpente.")
		return
	var snapshot_novo := snapshot_serpente.duplicate(true)
	snapshot_novo["revisaoSincronizacao"] = 6
	snapshot_novo["vida"] = int(snapshot_novo["vida"]) - 1
	rede._receber_estado_serpente_mundo(snapshot_novo)
	if snapshots.size() != 2 or int(rede.obter_estado_serpente_mundo_publico().get("vida", 0)) != int(snapshot_novo["vida"]):
		rede.free()
		_falhar("Não aceitou uma revisão global mais recente e válida da Serpente.")
		return
	rede.free()
	print("TESTE DE ESCOPO DOS ANÚNCIOS E DO RELÓGIO GLOBAL: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE ANÚNCIO CELESTE: " + mensagem)
	quit(1)
