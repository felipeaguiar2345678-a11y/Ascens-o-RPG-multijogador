extends RefCounted
## Registro autoritativo de salas públicas de aventura. Cada sala comporta até quatro jogadores.
## A camada de rede deve chamar estes métodos somente no servidor.

const TAMANHO_CODIGO := 6
const MAXIMO_JOGADORES_POR_SALA := 4
const MAXIMO_SALAS_PERSISTENTES := 10000
## Todas as salas pertencem ao mesmo mundo persistente; sala nunca cria uma cópia do mundo.
const ID_MUNDO_COMPARTILHADO := "mundo_principal"
const ALFABETO_CODIGO := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var _salas: Dictionary = {}
var _sala_por_jogador: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func criar_sala(peer_id: int, uid: String, codigo_preferido: String = "") -> Dictionary:
	if peer_id <= 0 or uid.strip_edges().is_empty() or uid.strip_edges().length() > 256:
		return {"sucesso": false, "erro": "Jogador inválido."}
	if _sala_por_jogador.has(peer_id):
		return {"sucesso": false, "erro": "O jogador já pertence a uma sala."}
	if _salas.size() >= MAXIMO_SALAS_PERSISTENTES:
		return {"sucesso": false, "erro": "O limite de salas persistentes foi atingido."}
	var codigo := codigo_preferido.strip_edges().to_upper()
	if codigo.is_empty():
		codigo = _gerar_codigo_unico()
	if not _codigo_valido(codigo):
		return {"sucesso": false, "erro": "Código de sala inválido."}
	if _salas.has(codigo):
		return {"sucesso": false, "erro": "Este código já está em uso."}
	var uid_por_peer: Dictionary = {}
	uid_por_peer[str(peer_id)] = uid.strip_edges()
	var sala := {
		"codigo": codigo,
		"mundoId": ID_MUNDO_COMPARTILHADO,
		"anfitriaoPeerId": peer_id,
		"anfitriaoUid": uid.strip_edges(),
		"jogadores": [peer_id],
		"uidPorPeer": uid_por_peer,
		"membrosUid": [uid.strip_edges()],
		"criadaEmUnix": Time.get_unix_time_from_system(),
		"estadoAventura": {},
		"revisaoAventura": 0
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
		if not jogadores.is_empty() and jogadores.size() < MAXIMO_JOGADORES_POR_SALA and jogadores.size() < menor_quantidade:
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
	var uid_por_peer: Dictionary = sala.get("uidPorPeer", {}).duplicate(true)
	for membro in jogadores:
		if str(uid_por_peer.get(str(membro), "")) == uid.strip_edges():
			return {"sucesso": false, "erro": "Esta conta já está conectada a esta sala."}
	jogadores.append(peer_id)
	uid_por_peer[str(peer_id)] = uid.strip_edges()
	sala["uidPorPeer"] = uid_por_peer
	var membros_uid: Array = sala.get("membrosUid", []).duplicate()
	if not membros_uid.has(uid.strip_edges()):
		if membros_uid.size() >= 1000:
			return {"sucesso": false, "erro": "Esta sala atingiu o limite de contas históricas registradas."}
		membros_uid.append(uid.strip_edges())
	sala["membrosUid"] = membros_uid
	if int(sala.get("anfitriaoPeerId", -1)) <= 0:
		sala["anfitriaoPeerId"] = peer_id
		sala["anfitriaoUid"] = uid.strip_edges()
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
	var uid_por_peer: Dictionary = sala.get("uidPorPeer", {}).duplicate(true)
	uid_por_peer.erase(str(peer_id))
	sala["uidPorPeer"] = uid_por_peer
	sala["jogadores"] = jogadores
	if int(sala.get("anfitriaoPeerId", -1)) == peer_id:
		sala["anfitriaoPeerId"] = int(jogadores[0]) if not jogadores.is_empty() else -1
		sala["anfitriaoUid"] = str(uid_por_peer.get(str(jogadores[0]), "")) if not jogadores.is_empty() else ""
	_salas[codigo] = sala
	return {"removido": true, "salaEncerrada": false, "codigo": codigo, "sala": sala.duplicate(true)}

## Atualiza a aventura somente se a revisão recebida ainda for a atual.
## expected_revision=-1 mantém compatibilidade com chamadas internas antigas.
## Isso impede que uma tela atrasada sobrescreva o progresso narrativo mais recente.
func atualizar_estado_aventura(peer_id: int, novo_estado: Dictionary, expected_revision: int = -1) -> Dictionary:
	if not _sala_por_jogador.has(peer_id):
		return {"sucesso": false, "erro": "Jogador não pertence a uma sala de aventura."}
	var codigo := str(_sala_por_jogador[peer_id])
	if not _salas.has(codigo):
		return {"sucesso": false, "erro": "Sala de aventura não encontrada."}
	var sala: Dictionary = _salas[codigo]
	var revisao_atual := int(sala.get("revisaoAventura", 0))
	if expected_revision >= 0 and expected_revision != revisao_atual:
		return {
			"sucesso": false,
			"conflito": true,
			"erro": "A aventura foi atualizada por outro integrante. Sincronize antes de tentar novamente.",
			"revisaoAtual": revisao_atual,
			"estadoAtual": (sala.get("estadoAventura", {}) as Dictionary).duplicate(true)
		}
	sala["estadoAventura"] = novo_estado.duplicate(true)
	sala["revisaoAventura"] = revisao_atual + 1
	_salas[codigo] = sala
	return {
		"sucesso": true,
		"codigo": codigo,
		"mundoId": ID_MUNDO_COMPARTILHADO,
		"revisao": int(sala["revisaoAventura"]),
		"estado": (sala["estadoAventura"] as Dictionary).duplicate(true)
	}

## Retorna uma cópia isolada do estado narrativo/missões da sala atual.
## Registra uma fala enviada por um membro autenticado, sem aceitar UID do cliente.
func registrar_mensagem(peer_id: int, uid: String, nome: String, texto_recebido: String) -> Dictionary:
	if not _sala_por_jogador.has(peer_id):
		return {"sucesso": false, "erro": "Você não pertence a uma sala cooperativa."}
	var codigo := str(_sala_por_jogador[peer_id])
	if not _salas.has(codigo):
		return {"sucesso": false, "erro": "Sala não encontrada."}
	var sala: Dictionary = _salas[codigo]
	var uid_ativo := str(sala.get("uidPorPeer", {}).get(str(peer_id), ""))
	if uid_ativo.is_empty() or uid_ativo != uid.strip_edges():
		return {"sucesso": false, "erro": "A sessão não corresponde a um membro ativo da sala."}
	var nome_seguro := nome.strip_edges()
	var texto := texto_recebido.strip_edges()
	if nome_seguro.is_empty() or nome_seguro.length() > 24 or texto.is_empty() or texto.length() > 300:
		return {"sucesso": false, "erro": "A mensagem deve ter de 1 a 300 caracteres."}
	var estado: Dictionary = sala.get("estadoAventura", {}).duplicate(true)
	var mensagens: Array = estado.get("mensagens", []).duplicate(true)
	mensagens.append({"autor": nome_seguro, "texto": texto, "enviadaEmUnix": int(Time.get_unix_time_from_system())})
	while mensagens.size() > 100:
		mensagens.pop_front()
	estado["mensagens"] = mensagens
	var revisao := int(sala.get("revisaoAventura", 0)) + 1
	sala["estadoAventura"] = estado
	sala["revisaoAventura"] = revisao
	_salas[codigo] = sala
	return {"sucesso": true, "codigo": codigo, "revisao": revisao, "estado": estado.duplicate(true)}

func obter_estado_aventura(peer_id: int) -> Dictionary:
	if not _sala_por_jogador.has(peer_id):
		return {}
	var sala := obter_sala_do_jogador(peer_id)
	if sala.is_empty():
		return {}
	return {"codigo": str(sala.get("codigo", "")), "mundoId": str(sala.get("mundoId", ID_MUNDO_COMPARTILHADO)), "revisao": int(sala.get("revisaoAventura", 0)), "estado": (sala.get("estadoAventura", {}) as Dictionary).duplicate(true)}

func obter_sala_do_jogador(peer_id: int) -> Dictionary:
	if not _sala_por_jogador.has(peer_id):
		return {}
	return obter_sala(str(_sala_por_jogador[peer_id]))

func obter_sala(codigo_recebido: String) -> Dictionary:
	var codigo := codigo_recebido.strip_edges().to_upper()
	if not _salas.has(codigo):
		return {}
	return (_salas[codigo] as Dictionary).duplicate(true)


## Exporta somente dados duráveis; IDs de conexão nunca são restaurados após reinício.
func exportar_estado_persistente() -> Array:
	var resultado: Array = []
	for codigo in _salas.keys():
		var sala: Dictionary = _salas[codigo]
		resultado.append({"codigo": str(codigo), "membrosUid": (sala.get("membrosUid", []) as Array).duplicate(), "criadaEmUnix": int(sala.get("criadaEmUnix", 0)), "estadoAventura": (sala.get("estadoAventura", {}) as Dictionary).duplicate(true), "revisaoAventura": int(sala.get("revisaoAventura", 0))})
	return resultado

## Restaura salas sem peers ativos; participantes autenticados podem voltar com o código.
func restaurar_estado_persistente(registros: Array) -> Dictionary:
	_salas.clear()
	_sala_por_jogador.clear()
	if registros.size() > 10000:
		return {"sucesso": false, "erro": "Arquivo contém salas demais."}
	for registro in registros:
		if not (registro is Dictionary):
			_salas.clear()
			return {"sucesso": false, "erro": "Registro de sala inválido."}
		var codigo := str(registro.get("codigo", "")).to_upper()
		var membros_uid = registro.get("membrosUid", [])
		var estado_aventura = registro.get("estadoAventura", {})
		var revisao := int(registro.get("revisaoAventura", 0))
		if not _codigo_valido(codigo) or _salas.has(codigo) or not (membros_uid is Array) or membros_uid.size() > 1000 or not (estado_aventura is Dictionary) or revisao < 0:
			_salas.clear()
			return {"sucesso": false, "erro": "Dados persistidos da sala são inválidos."}
		var membros_validos: Array = []
		for uid in membros_uid:
			if not (uid is String) or uid.strip_edges().is_empty() or uid.length() > 256 or membros_validos.has(uid):
				_salas.clear()
				return {"sucesso": false, "erro": "Lista de participantes persistida é inválida."}
			membros_validos.append(uid)
		_salas[codigo] = {"codigo": codigo, "mundoId": ID_MUNDO_COMPARTILHADO, "anfitriaoPeerId": -1, "anfitriaoUid": str(membros_validos[0]) if not membros_validos.is_empty() else "", "jogadores": [], "uidPorPeer": {}, "membrosUid": membros_validos, "criadaEmUnix": max(0, int(registro.get("criadaEmUnix", 0))), "estadoAventura": estado_aventura.duplicate(true), "revisaoAventura": revisao}
	return {"sucesso": true, "quantidade": _salas.size()}

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
