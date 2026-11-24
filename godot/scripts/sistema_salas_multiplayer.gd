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
		var encontro_atual: Dictionary = sala.get("estadoAventura", {}).get("encontro", {})
		if bool(encontro_atual.get("ativo", false)):
			continue
		var jogadores: Array = sala.get("jogadores", [])
		if not jogadores.is_empty() and jogadores.size() < MAXIMO_JOGADORES_POR_SALA and jogadores.size() < menor_quantidade:
			melhor_codigo = str(codigo)
			menor_quantidade = jogadores.size()
	if melhor_codigo.is_empty():
		return criar_sala(peer_id, uid)
	return entrar_sala(peer_id, uid, melhor_codigo)

func entrar_sala(peer_id: int, uid: String, codigo_recebido: String) -> Dictionary:
	if peer_id <= 0 or uid.strip_edges().is_empty() or uid.strip_edges().length() > 256:
		return {"sucesso": false, "erro": "Jogador inválido."}
	if _sala_por_jogador.has(peer_id):
		return {"sucesso": false, "erro": "O jogador já pertence a uma sala."}
	var codigo := codigo_recebido.strip_edges().to_upper()
	if not _codigo_valido(codigo) or not _salas.has(codigo):
		return {"sucesso": false, "erro": "Sala não encontrada. Confira o código."}
	var sala: Dictionary = _salas[codigo]
	var encontro_em_andamento: Dictionary = sala.get("estadoAventura", {}).get("encontro", {})
	if bool(encontro_em_andamento.get("ativo", false)):
		var combate_em_andamento: Dictionary = encontro_em_andamento.get("combate", {})
		var uid_participa_do_encontro := false
		for participante_encontro in combate_em_andamento.get("participantes", []):
			if str(participante_encontro.get("uid", "")) == uid.strip_edges():
				uid_participa_do_encontro = true
				break
		if not uid_participa_do_encontro:
			return {"sucesso": false, "erro": "Um encontro está em andamento. Somente os participantes originais podem reconectar até o fim da batalha."}
	var jogadores: Array = sala.get("jogadores", [])
	if jogadores.size() >= MAXIMO_JOGADORES_POR_SALA:
		return {"sucesso": false, "erro": "Esta sala já está completa."}
	var uid_por_peer: Dictionary = sala.get("uidPorPeer", {}).duplicate(true)
	for membro in jogadores:
		if str(uid_por_peer.get(str(membro), "")) == uid.strip_edges():
			return {"sucesso": false, "erro": "Esta conta já está conectada a esta sala."}
	var membros_uid: Array = sala.get("membrosUid", []).duplicate()
	if not membros_uid.has(uid.strip_edges()):
		# Validar o limite antes de alterar o array compartilhado de jogadores evita
		# deixar um peer fantasma ocupando vaga quando a entrada é recusada.
		if membros_uid.size() >= 1000:
			return {"sucesso": false, "erro": "Esta sala atingiu o limite de contas históricas registradas."}
		membros_uid.append(uid.strip_edges())
	jogadores.append(peer_id)
	uid_por_peer[str(peer_id)] = uid.strip_edges()
	sala["uidPorPeer"] = uid_por_peer
	sala["membrosUid"] = membros_uid
	if int(sala.get("anfitriaoPeerId", -1)) <= 0:
		sala["anfitriaoPeerId"] = peer_id
		sala["anfitriaoUid"] = uid.strip_edges()
	sala["jogadores"] = jogadores
	var estado_retorno: Dictionary = sala.get("estadoAventura", {}).duplicate(true)
	var encontro_retorno: Dictionary = estado_retorno.get("encontro", {}).duplicate(true)
	var combate_retorno: Dictionary = encontro_retorno.get("combate", {}).duplicate(true)
	if bool(encontro_retorno.get("ativo", false)) and not combate_retorno.is_empty():
		combate_retorno = preload("res://scripts/sistema_combate_cooperativo.gd").marcar_reconectado(combate_retorno, uid.strip_edges())
		encontro_retorno["combate"] = combate_retorno
		estado_retorno["encontro"] = encontro_retorno
		sala["estadoAventura"] = estado_retorno
		sala["revisaoAventura"] = int(sala.get("revisaoAventura", 0)) + 1
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
	var estado_saida: Dictionary = sala.get("estadoAventura", {}).duplicate(true)
	var encontro_saida: Dictionary = estado_saida.get("encontro", {}).duplicate(true)
	var combate_saida: Dictionary = encontro_saida.get("combate", {}).duplicate(true)
	var uid_saida := str(sala.get("uidPorPeer", {}).get(str(peer_id), ""))
	if bool(encontro_saida.get("ativo", false)) and not combate_saida.is_empty() and not uid_saida.is_empty():
		combate_saida = preload("res://scripts/sistema_combate_cooperativo.gd").marcar_desconectado(combate_saida, uid_saida)
		encontro_saida["combate"] = combate_saida
		estado_saida["encontro"] = encontro_saida
		sala["estadoAventura"] = estado_saida
		sala["revisaoAventura"] = int(sala.get("revisaoAventura", 0)) + 1
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
	var inimigos_encontro: Array = encontro_servidor.get("inimigos", []) if encontro_servidor.get("inimigos", []) is Array else []
	var encontro_em_grupo := not inimigos_encontro.is_empty()
	var criatura_principal: Dictionary = inimigos_encontro[0] if encontro_em_grupo and inimigos_encontro[0] is Dictionary else encontro_servidor
	if encontro_em_grupo and inimigos_encontro.size() > 3:
		return {"sucesso": false, "erro": "Um encontro cooperativo pode conter no máximo três criaturas."}
	var id := str(criatura_principal.get("id", "")).strip_edges()
	var nome := str(criatura_principal.get("nome", "")).strip_edges()
	var rank := str(criatura_principal.get("rank", "")).to_upper()
	var vida := int(criatura_principal.get("vidaMaxima", criatura_principal.get("vida", 0)))
	var nivel := int(criatura_principal.get("nivel", 0))
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
	if uids_informados.size() < 2 or uids_informados.size() > uids_ativos.size():
		return {"sucesso": false, "erro": "O combate exige pelo menos dois integrantes ativos da mesma sala."}
	var combate: Dictionary = preload("res://scripts/sistema_combate_cooperativo.gd").criar_estado_grupo(inimigos_encontro, participantes) if encontro_em_grupo else preload("res://scripts/sistema_combate_cooperativo.gd").criar_estado(encontro_servidor, participantes)
	if combate.is_empty():
		return {"sucesso": false, "erro": "Não foi possível preparar o combate da equipe. Confira os participantes e os atributos."}
	var drops_previstos: Array = []
	var criaturas_para_drops: Array = inimigos_encontro if encontro_em_grupo else [encontro_servidor]
	for criatura_drop in criaturas_para_drops:
		if not (criatura_drop is Dictionary):
			continue
		var tabela_drops: Array = criatura_drop.get("tabelaDrops", []) if criatura_drop.get("tabelaDrops", []) is Array else []
		for entrada_drop in tabela_drops:
			if not (entrada_drop is Dictionary):
				continue
			var nome_drop := str(entrada_drop.get("nome", entrada_drop.get("itemId", ""))).strip_edges()
			if nome_drop.is_empty():
				continue
			drops_previstos.append({"nome":nome_drop.substr(0, 64), "raridade":str(entrada_drop.get("raridade", "comum")).substr(0, 24), "categoria":str(entrada_drop.get("categoria", "material")).substr(0, 24)})
		var entrada_moeda: Dictionary = preload("res://scripts/sistema_drops.gd").criar_entrada_moeda_criatura(criatura_drop)
		if not entrada_moeda.is_empty():
			drops_previstos.append({"nome":str(entrada_moeda.get("nome", "Moedas")).substr(0, 64), "raridade":"comum", "categoria":"moeda"})
	# A prévia só anuncia ovos se houver ao menos um integrante elegível na equipe.
	# O destinatário real continua sendo decidido pelo maior dano ao fim da batalha.
	var equipe_pode_receber_ovo := false
	for participante_ovo in participantes:
		if str(participante_ovo.get("classeId", "")).strip_edges().to_lower() != "invocador":
			equipe_pode_receber_ovo = true
			break
	if equipe_pode_receber_ovo:
		for criatura_ovo in criaturas_para_drops:
			if criatura_ovo is Dictionary:
				var entrada_ovo: Dictionary = preload("res://scripts/sistema_drops.gd").criar_entrada_ovo(criatura_ovo)
				if not entrada_ovo.is_empty():
					drops_previstos.append({"nome":str(entrada_ovo.get("nome", "Ovo misterioso")).substr(0, 64), "raridade":str(entrada_ovo.get("raridade", "comum")).substr(0, 24), "categoria":"ovo"})
	var encontro := {
		"ativo": true,
		"idRecompensa": "%s-%d" % [str(sala.get("codigo", "SALA")), int(Time.get_ticks_usec())],
		"experienciaBase": clampi(int(encontro_servidor.get("experienciaBase", 0)) if not encontro_em_grupo else _somar_experiencia_grupo(inimigos_encontro), 0, 100000000),
		"dadosRecompensa": encontro_servidor.duplicate(true),
		"recompensasConcluidas": false,
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

static func _somar_experiencia_grupo(criaturas: Array) -> int:
	var total := 0
	for criatura in criaturas:
		if criatura is Dictionary:
			total = mini(100000000, total + maxi(0, int(criatura.get("experienciaBase", 0))))
	return total

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
	if bool(encontro.get("ativo", false)):
		return {"sucesso": false, "erro": "O encontro ainda está em andamento e não pode ser removido."}
	var resultado := str(encontro.get("resultado", ""))
	if resultado == "vitoria" and not bool(encontro.get("recompensasConcluidas", false)):
		return {"sucesso": false, "erro": "As recompensas da vitória ainda não foram confirmadas."}
	if resultado == "derrota" and not bool(encontro.get("recursosDerrotaConcluidos", false)):
		return {"sucesso": false, "erro": "A restauração e as penalidades da derrota ainda não foram confirmadas."}
	if not ["vitoria", "derrota"].has(resultado):
		return {"sucesso": false, "erro": "Somente um encontro finalizado e resolvido pode ser removido."}
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

		var estado_recuperado: Dictionary = estado_aventura.duplicate(true)
		var encontro_bruto = estado_recuperado.get("encontro", {})
		if not (encontro_bruto is Dictionary):
			_salas.clear()
			return {"sucesso": false, "erro": "O encontro persistido possui formato inválido."}
		var encontro_recuperado: Dictionary = encontro_bruto.duplicate(true)
		if bool(encontro_recuperado.get("ativo", false)):
			var combate_bruto = encontro_recuperado.get("combate", null)
			if not (combate_bruto is Dictionary):
				_salas.clear()
				return {"sucesso": false, "erro": "O encontro ativo persistido não contém um combate válido."}
			var combate_recuperado: Dictionary = combate_bruto.duplicate(true)
			if str(combate_recuperado.get("status", "")) != "em_andamento":
				_salas.clear()
				return {"sucesso": false, "erro": "O encontro ativo persistido possui um estado de combate inválido."}
			var participantes_recuperados = combate_recuperado.get("participantes", [])
			if not (participantes_recuperados is Array) or participantes_recuperados.size() < 2 or participantes_recuperados.size() > MAXIMO_JOGADORES_POR_SALA:
				_salas.clear()
				return {"sucesso": false, "erro": "Participantes do combate persistido são inválidos."}
			var uids_combate_recuperados: Array = []
			for participante_recuperado in participantes_recuperados:
				if not (participante_recuperado is Dictionary):
					_salas.clear()
					return {"sucesso": false, "erro": "Um participante do combate persistido é inválido."}
				var uid_combate_recuperado = participante_recuperado.get("uid", null)
				if not (uid_combate_recuperado is String) or uid_combate_recuperado.strip_edges().is_empty() or uid_combate_recuperado.length() > 256 or not membros_validos.has(uid_combate_recuperado) or uids_combate_recuperados.has(uid_combate_recuperado):
					_salas.clear()
					return {"sucesso": false, "erro": "O combate persistido contém participante sem vínculo válido com a sala."}
				uids_combate_recuperados.append(uid_combate_recuperado)
				participante_recuperado["conectado"] = false
			combate_recuperado["indiceTurno"] = -1
			combate_recuperado["aguardandoReconexao"] = true
			var historico_bruto = combate_recuperado.get("historico", [])
			if not (historico_bruto is Array):
				_salas.clear()
				return {"sucesso": false, "erro": "O histórico do combate persistido é inválido."}
			var historico_recuperado: Array = historico_bruto.duplicate()
			historico_recuperado.append("O servidor foi reiniciado. A batalha aguarda a reconexão de um integrante.")
			while historico_recuperado.size() > 60:
				historico_recuperado.pop_front()
			combate_recuperado["historico"] = historico_recuperado
			encontro_recuperado["combate"] = combate_recuperado
		estado_recuperado["encontro"] = encontro_recuperado
		_salas[codigo] = {"codigo": codigo, "mundoId": ID_MUNDO_COMPARTILHADO, "anfitriaoPeerId": -1, "anfitriaoUid": str(membros_validos[0]) if not membros_validos.is_empty() else "", "jogadores": [], "uidPorPeer": {}, "membrosUid": membros_validos, "criadaEmUnix": max(0, int(registro.get("criadaEmUnix", 0))), "estadoAventura": estado_recuperado, "revisaoAventura": revisao}
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
