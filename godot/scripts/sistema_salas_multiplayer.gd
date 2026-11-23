extends RefCounted
## Registro autoritativo de salas públicas de aventura. Cada sala comporta até quatro jogadores.
## A camada de rede deve chamar estes métodos somente no servidor.

const TAMANHO_CODIGO := 6
const MAXIMO_JOGADORES_POR_SALA := 4
const ALFABETO_CODIGO := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var _salas: Dictionary = {}
var _sala_por_jogador: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func criar_sala(peer_id: int, uid: String, codigo_preferido: String = "") -> Dictionary:
	if peer_id <= 0 or uid.strip_edges().is_empty():
		return {"sucesso": false, "erro": "Jogador inválido."}
	if _sala_por_jogador.has(peer_id):
		return {"sucesso": false, "erro": "O jogador já pertence a uma sala."}
	var codigo := codigo_preferido.strip_edges().to_upper()
	if codigo.is_empty():
		codigo = _gerar_codigo_unico()
	if not _codigo_valido(codigo):
		return {"sucesso": false, "erro": "Código de sala inválido."}
	if _salas.has(codigo):
		return {"sucesso": false, "erro": "Este código já está em uso."}
	var sala := {
		"codigo": codigo,
		"anfitriaoPeerId": peer_id,
		"anfitriaoUid": uid,
		"jogadores": [peer_id],
		"criadaEmUnix": Time.get_unix_time_from_system()
	}
	_salas[codigo] = sala
	_sala_por_jogador[peer_id] = codigo
	return {"sucesso": true, "codigo": codigo, "sala": sala.duplicate(true)}

func entrar_sala_publica(peer_id: int, uid: String) -> Dictionary:
	if peer_id <= 0 or uid.strip_edges().is_empty():
		return {"sucesso": false, "erro": "Jogador inválido."}
	if _sala_por_jogador.has(peer_id):
		return {"sucesso": false, "erro": "O jogador já pertence a uma sala."}
	var melhor_codigo := ""
	var menor_quantidade := MAXIMO_JOGADORES_POR_SALA + 1
	var codigos: Array = _salas.keys()
	codigos.sort()
	for codigo in codigos:
		var sala: Dictionary = _salas[codigo]
		var jogadores: Array = sala.get("jogadores", [])
		if jogadores.size() < MAXIMO_JOGADORES_POR_SALA and jogadores.size() < menor_quantidade:
			melhor_codigo = str(codigo)
			menor_quantidade = jogadores.size()
	if melhor_codigo.is_empty():
		return criar_sala(peer_id, uid)
	return entrar_sala(peer_id, uid, melhor_codigo)

func entrar_sala(peer_id: int, uid: String, codigo_recebido: String) -> Dictionary:
	if peer_id <= 0 or uid.strip_edges().is_empty():
		return {"sucesso": false, "erro": "Jogador inválido."}
	if _sala_por_jogador.has(peer_id):
		return {"sucesso": false, "erro": "O jogador já pertence a uma sala."}
	var codigo := codigo_recebido.strip_edges().to_upper()
	if not _codigo_valido(codigo) or not _salas.has(codigo):
		return {"sucesso": false, "erro": "Sala não encontrada. Confira o código."}
	var sala: Dictionary = _salas[codigo]
	var jogadores: Array = sala.get("jogadores", [])
	if jogadores.size() >= MAXIMO_JOGADORES_POR_SALA:
		return {"sucesso": false, "erro": "Esta sala já está completa."}
	jogadores.append(peer_id)
	sala["jogadores"] = jogadores
	_salas[codigo] = sala
	_sala_por_jogador[peer_id] = codigo
	return {"sucesso": true, "codigo": codigo, "sala": sala.duplicate(true)}

func remover_jogador(peer_id: int) -> Dictionary:
	if not _sala_por_jogador.has(peer_id):
		return {"removido": false, "salaEncerrada": false}
	var codigo := str(_sala_por_jogador[peer_id])
	_sala_por_jogador.erase(peer_id)
	if not _salas.has(codigo):
		return {"removido": true, "salaEncerrada": false, "codigo": codigo}
	var sala: Dictionary = _salas[codigo]
	var jogadores: Array = sala.get("jogadores", [])
	jogadores.erase(peer_id)
	if jogadores.is_empty():
		_salas.erase(codigo)
		return {"removido": true, "salaEncerrada": true, "codigo": codigo, "jogadores": []}
	sala["jogadores"] = jogadores
	if int(sala.get("anfitriaoPeerId", -1)) == peer_id:
		sala["anfitriaoPeerId"] = int(jogadores[0])
	_salas[codigo] = sala
	return {"removido": true, "salaEncerrada": false, "codigo": codigo, "sala": sala.duplicate(true)}

func obter_sala_do_jogador(peer_id: int) -> Dictionary:
	if not _sala_por_jogador.has(peer_id):
		return {}
	return obter_sala(str(_sala_por_jogador[peer_id]))

func obter_sala(codigo_recebido: String) -> Dictionary:
	var codigo := codigo_recebido.strip_edges().to_upper()
	if not _salas.has(codigo):
		return {}
	return (_salas[codigo] as Dictionary).duplicate(true)

func quantidade_salas() -> int:
	return _salas.size()

func _gerar_codigo_unico() -> String:
	for tentativa in range(128):
		var codigo := ""
		for indice in range(TAMANHO_CODIGO):
			codigo += ALFABETO_CODIGO[_rng.randi_range(0, ALFABETO_CODIGO.length() - 1)]
		if not _salas.has(codigo):
			return codigo
	return ""

func _codigo_valido(codigo: String) -> bool:
	if codigo.length() != TAMANHO_CODIGO:
		return false
	for caractere in codigo:
		if not ALFABETO_CODIGO.contains(caractere):
			return false
	return true
