extends SceneTree
## Integra autenticação por geração de sessão, sala persistente e retomada de combate.
## Este teste cobre a corrida mais importante da etapa multiplayer: peer_id reutilizado.

const Salas = preload("res://scripts/sistema_salas_multiplayer.gd")
const Sessao = preload("res://scripts/sistema_validacao_sessao.gd")
const Combate = preload("res://scripts/sistema_combate_cooperativo.gd")

func _initialize() -> void:
	var salas = Salas.new()
	var criada: Dictionary = salas.criar_sala(501, "uid-integracao-a", "FJLA23")
	if not bool(criada.get("sucesso", false)):
		_falhar("Não foi possível criar a sala de integração: " + str(criada))
		return
	if not bool(salas.entrar_sala(502, "uid-integracao-b", "FJLA23").get("sucesso", false)):
		_falhar("O segundo integrante não conseguiu entrar na sala.")
		return

	var equipe := [
		{"uid":"uid-integracao-a","nome":"Aventureiro A","vida":100,"vidaMaxima":100,"ataque":20,"defesa":5,"agilidade":8},
		{"uid":"uid-integracao-b","nome":"Aventureiro B","vida":100,"vidaMaxima":100,"ataque":20,"defesa":5,"agilidade":7}
	]
	var encontro: Dictionary = salas.registrar_encontro(501, {
		"id":"guardiao_integracao",
		"nome":"Guardião da Integração",
		"rank":"E",
		"nivel":1,
		"vidaMaxima":500,
		"ataque":5,
		"defesa":1,
		"experienciaBase":40
	}, equipe)
	if not bool(encontro.get("sucesso", false)):
		_falhar("A sala não iniciou o encontro cooperativo.")
		return

	var snapshot_inicial: Dictionary = salas.obter_estado_aventura(501)
	var combate_inicial: Dictionary = snapshot_inicial.get("estado", {}).get("encontro", {}).get("combate", {})
	if str(snapshot_inicial.get("mundoId", "")) != Salas.ID_MUNDO_COMPARTILHADO:
		_falhar("A sala não permaneceu vinculada ao mundo único.")
		return
	if str(combate_inicial.get("status", "")) != Combate.EM_ANDAMENTO:
		_falhar("O encontro não começou em estado ativo.")
		return
	if (combate_inicial.get("participantes", []) as Array).size() != 2:
		_falhar("O encontro não preservou os dois participantes originais.")
		return

	var peers := PackedInt32Array([501, 502])
	var uids := {501:"uid-integracao-a", 502:"uid-integracao-b"}
	var geracoes := {501:101, 502:102}
	if not Sessao.sessao_ativa(501, "uid-integracao-a", 101, peers, uids, geracoes):
		_falhar("A sessão original válida foi recusada.")
		return

	var saida: Dictionary = salas.remover_jogador(501)
	if not bool(saida.get("removido", false)):
		_falhar("A saída do primeiro jogador não foi registrada.")
		return

	# A desconexão de um integrante não pode encerrar o encontro enquanto
	# outro membro autenticado da equipe continua conectado.
	var snapshot_com_um_ausente: Dictionary = salas.obter_estado_aventura(502)
	var combate_com_um_ausente: Dictionary = snapshot_com_um_ausente.get("estado", {}).get("encontro", {}).get("combate", {})
	if str(combate_com_um_ausente.get("status", "")) != Combate.EM_ANDAMENTO:
		_falhar("A desconexão individual encerrou o combate com outro integrante ativo.")
		return
	var segundo_integrante_ativo := false
	for participante in combate_com_um_ausente.get("participantes", []):
		if str(participante.get("uid", "")) == "uid-integracao-b":
			segundo_integrante_ativo = bool(participante.get("conectado", false))
			break
	if not segundo_integrante_ativo:
		_falhar("O integrante sobrevivente perdeu sua participação após a desconexão do aliado.")
		return
	peers.erase(501)
	uids.erase(501)
	geracoes.erase(501)
	if Sessao.sessao_ativa(501, "uid-integracao-a", 101, peers, uids, geracoes):
		_falhar("A sessão desconectada continuou autorizada.")
		return

	# Simula o ENet reutilizando o mesmo peer_id para uma conta diferente.
	peers.append(501)
	uids[501] = "uid-intruso"
	geracoes[501] = 103
	if Sessao.sessao_ativa(501, "uid-integracao-a", 101, peers, uids, geracoes):
		_falhar("Uma sessão antiga foi aceita após reutilização do peer_id.")
		return
	if bool(salas.entrar_sala(503, "uid-intruso", "FJLA23").get("sucesso", false)):
		_falhar("Uma conta desconhecida entrou em um combate ativo.")
		return

	# A conta original retorna com outro peer_id e recebe sua participação de volta.
	var retorno: Dictionary = salas.entrar_sala(503, "uid-integracao-a", "FJLA23")
	if not bool(retorno.get("sucesso", false)):
		_falhar("O integrante original não conseguiu retomar a sala.")
		return
	peers.erase(501)
	uids.erase(501)
	geracoes.erase(501)
	peers.append(503)
	uids[503] = "uid-integracao-a"
	geracoes[503] = 104
	if not Sessao.sessao_ativa(503, "uid-integracao-a", 104, peers, uids, geracoes):
		_falhar("A nova sessão autenticada não foi reconhecida.")
		return

	var snapshot_retomado: Dictionary = salas.obter_estado_aventura(503)
	var combate_retomado: Dictionary = snapshot_retomado.get("estado", {}).get("encontro", {}).get("combate", {})
	var participante_reencontrado := false
	for participante in combate_retomado.get("participantes", []):
		if str(participante.get("uid", "")) == "uid-integracao-a":
			participante_reencontrado = bool(participante.get("conectado", false))
			break
	if not participante_reencontrado:
		_falhar("A reconexão não restaurou a participação do UID original.")
		return
	if str(combate_retomado.get("status", "")) != Combate.EM_ANDAMENTO:
		_falhar("A batalha foi encerrada indevidamente durante a reconexão.")
		return
	if int(snapshot_retomado.get("revisao", 0)) <= int(snapshot_inicial.get("revisao", 0)):
		_falhar("A reconexão não avançou a revisão do estado compartilhado.")
		return

	print("OK: sessão, peer_id reutilizado, sala compartilhada e retomada de combate validados em conjunto.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE INTEGRADO MULTIPLAYER: " + mensagem)
	quit(1)
