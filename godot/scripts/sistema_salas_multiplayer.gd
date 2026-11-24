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
	if (sala.get("jogadores", []) as Array).size() < 2:
		return {"sucesso": false, "erro": "A aventura compartilhada começa quando pelo menos dois jogadores entram na sala."}
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

## Registra um encontro real fornecido pelo catálogo do servidor; nunca recebe dados do cliente.
func registrar_encontro(peer_id: int, encontro_servidor: Dictionary, participantes: Array = []) -> Dictionary:
	if not _sala_por_jogador.has(peer_id):
		return {"sucesso": false, "erro": "Jogador não pertence a uma sala cooperativa."}
	var sala := obter_sala_do_jogador(peer_id)
	if sala.is_empty() or (sala.get("jogadores", []) as Array).size() < 2:
		return {"sucesso": false, "erro": "O encontro cooperativo exige pelo menos dois participantes ativos."}
	var estado: Dictionary = sala.get("estadoAventura", {}).duplicate(true)
	var encontro_atual: Dictionary = estado.get("encontro", {})
	if bool(encontro_atual.get("ativo", false)):
		return {"sucesso": false, "erro": "Já existe um encontro ativo nesta aventura."}
	var id := str(encontro_servidor.get("id", "")).strip_edges()
	var nome := str(encontro_servidor.get("nome", "")).strip_edges()
	var rank := str(encontro_servidor.get("rank", "")).to_upper()
	var vida := int(encontro_servidor.get("vidaMaxima", encontro_servidor.get("vida", 0)))
	var nivel := int(encontro_servidor.get("nivel", 0))
	if id.is_empty() or id.length() > 128 or nome.length() < 2 or nome.length() > 64:
		return {"sucesso": false, "erro": "Identidade da criatura inválida."}
	if not ["E", "D", "C", "B", "A", "S", "SS", "SSS"].has(rank) or vida < 1 or vida > 100000000 or nivel < 1 or nivel > 100000:
		return {"sucesso": false, "erro": "Atributos da criatura inválidos."}
	var uids_ativos: Array = []
	for membro_peer in sala.get("jogadores", []):
		var uid_ativo := str(sala.get("uidPorPeer", {}).get(str(membro_peer), ""))
		if uid_ativo.is_empty():
			return {"sucesso": false, "erro": "A sala possui um participante sem identidade ativa."}
		uids_ativos.append(uid_ativo)
	var uids_informados: Array = []
	for participante in participantes:
		if not (participante is Dictionary):
			return {"sucesso": false, "erro": "Participante inválido."}
		var uid_participante := str(participante.get("uid", ""))
		if not uids_ativos.has(uid_participante) or uids_informados.has(uid_participante):
			return {"sucesso": false, "erro": "A equipe contém identidade que não pertence à sala."}
		uids_informados.append(uid_participante)
	if uids_informados.size() != uids_ativos.size():
		return {"sucesso": false, "erro": "Todos os participantes ativos devem entrar no combate compartilhado."}
	var combate := preload("res://scripts/sistema_combate_cooperativo.gd").criar_estado(encontro_servidor, participantes)
	if combate.is_empty():
		return {"sucesso": false, "erro": "Não foi possível preparar o combate da equipe. Confira os participantes e os atributos."}
	var drops_previstos: Array = []
	var tabela_drops: Array = encontro_servidor.get("tabelaDrops", []) if encontro_servidor.get("tabelaDrops", []) is Array else []
	for entrada_drop in tabela_drops:
		if not (entrada_drop is Dictionary):
			continue
		var nome_drop := str(entrada_drop.get("nome", entrada_drop.get("itemId", ""))).strip_edges()
		if nome_drop.is_empty():
			continue
		drops_previstos.append({"nome":nome_drop.substr(0, 64), "raridade":str(entrada_drop.get("raridade", "comum")).substr(0, 24), "categoria":str(entrada_drop.get("categoria", "material")).substr(0, 24)})
	var entrada_ovo: Dictionary = preload("res://scripts/sistema_drops.gd").criar_entrada_ovo(encontro_servidor)
	if not entrada_ovo.is_empty():
		drops_previstos.append({"nome":str(entrada_ovo.get("nome", "Ovo misterioso")).substr(0, 64), "raridade":str(entrada_ovo.get("raridade", "comum")).substr(0, 24), "categoria":"ovo"})
	var encontro := {
		"ativo": true,
		"dropsPrevistos": drops_previstos,
		"id": id,
		"nome": nome,
		"descricao": str(encontro_servidor.get("descricao", "")).substr(0, 500),
		"rank": rank,
		"raridade": str(encontro_servidor.get("raridade", "comum")).substr(0, 24),
		"nivel": nivel,
		"vidaAtual": vida,
		"vidaMaxima": vida,
		"imagemId": str(encontro_servidor.get("imagemId", "")).substr(0, 128),
		"iconePath": str(encontro_servidor.get("iconePath", "")).substr(0, 512),
		"detalhePath": str(encontro_servidor.get("detalhePath", "")).substr(0, 512),
		"ecossistemaId": str(encontro_servidor.get("ecossistemaId", "")).substr(0, 64),
		"bioma": str(encontro_servidor.get("bioma", "")).substr(0, 64),
		"combate": combate,
		"iniciadoEmUnix": int(Time.get_unix_time_from_system())
	}
	estado["encontro"] = encontro
	return atualizar_estado_aventura(peer_id, estado, int(sala.get("revisaoAventura", 0)))

## Executa uma ação apenas para o UID cujo turno está ativo; o dano é calculado no motor do servidor.
func executar_acao_encontro(peer_id: int, uid: String, acao: String, semente: int) -> Dictionary:
	if not _sala_por_jogador.has(peer_id):
		return {"sucesso": false, "erro": "Jogador não pertence a uma sala cooperativa."}
	var sala := obter_sala_do_jogador(peer_id)
	var uid_ativo := str(sala.get("uidPorPeer", {}).get(str(peer_id), ""))
	if uid_ativo.is_empty() or uid_ativo != uid.strip_edges():
		return {"sucesso": false, "erro": "A sessão não corresponde a um integrante ativo da sala."}
	var estado: Dictionary = sala.get("estadoAventura", {}).duplicate(true)
	var encontro: Dictionary = estado.get("encontro", {}).duplicate(true)
	if not bool(encontro.get("ativo", false)):
		return {"sucesso": false, "erro": "Não existe encontro ativo."}
	var combate: Dictionary = encontro.get("combate", {})
	var resultado: Dictionary = preload("res://scripts/sistema_combate_cooperativo.gd").executar_acao(combate, uid, acao, semente)
	if not bool(resultado.get("ok", false)):
		return {"sucesso": false, "erro": str(resultado.get("erro", "Ação recusada."))}
	combate = resultado.get("estado", {})
	encontro["combate"] = combate
	var criatura: Dictionary = combate.get("criatura", {})
	encontro["vidaAtual"] = int(criatura.get("vida", encontro.get("vidaAtual", 0)))
	encontro["vidaMaxima"] = int(criatura.get("vidaMaxima", encontro.get("vidaMaxima", 1)))
	if str(combate.get("status", "")) != "em_andamento":
		encontro["ativo"] = false
		encontro["resultado"] = str(combate.get("status", "encerrado"))
	estado["encontro"] = encontro
	var atualizado := atualizar_estado_aventura(peer_id, estado, int(sala.get("revisaoAventura", 0)))
	if not bool(atualizado.get("sucesso", false)):
		return atualizado
	return {"sucesso": true, "estado": estado, "revisao": atualizado.get("revisao", 0)}

## Limpa o encontro após uma resolução autoritativa do servidor.
func limpar_encontro(peer_id: int) -> Dictionary:
	if not _sala_por_jogador.has(peer_id):
		return {"sucesso": false, "erro": "Jogador não pertence a uma sala cooperativa."}
	var sala := obter_sala_do_jogador(peer_id)
	var estado: Dictionary = sala.get("estadoAventura", {}).duplicate(true)
	var encontro: Dictionary = estado.get("encontro", {})
	if not bool(encontro.get("ativo", false)) and str(encontro.get("resultado", "")).is_empty():
		return {"sucesso": false, "erro": "Não existe encontro para limpar."}
	estado["encontro"] = {"ativo": false}
	return atualizar_estado_aventura(peer_id, estado, int(sala.get("revisaoAventura", 0)))

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
