extends RefCounted
## Missões opcionais do mundo aberto, oferecidas por NPCs.
## O chamador deve executar este módulo no servidor após validar a identidade do jogador.
## Este módulo não inicia missões sozinho e não decide recompensas monetárias.

const MOTOR_MISSOES = preload("res://scripts/sistema_missoes_sala.gd")
const DIFICULDADES := ["facil", "fácil", "media", "média", "dificil", "difícil", "extrema"]

var _motor = MOTOR_MISSOES.new()
var _ofertas: Dictionary = {}

func registrar_oferta(definicao: Dictionary) -> Dictionary:
	var id := str(definicao.get("id", "")).strip_edges()
	var npc_id := str(definicao.get("npcId", "")).strip_edges()
	var titulo := str(definicao.get("titulo", "")).strip_edges()
	var descricao := str(definicao.get("descricao", "")).strip_edges()
	var dificuldade := str(definicao.get("dificuldade", "")).strip_edges().to_lower()
	if id.is_empty() or id.length() > 128 or npc_id.is_empty() or npc_id.length() > 128:
		return {"ok": false, "erro": "Missão ou NPC sem identificação válida."}
	if titulo.is_empty() or titulo.length() > 120 or descricao.is_empty() or descricao.length() > 1200:
		return {"ok": false, "erro": "Título ou descrição inválida."}
	if not DIFICULDADES.has(dificuldade) or _ofertas.has(id):
		return {"ok": false, "erro": "Dificuldade inválida ou missão já cadastrada."}
	var validacao := _motor.registrar_definicao(definicao)
	if not bool(validacao.get("ok", false)):
		return validacao
	_ofertas[id] = {
		"id": id,
		"npcId": npc_id,
		"titulo": titulo,
		"descricao": descricao,
		"dificuldade": dificuldade
	}
	return {"ok": true, "missaoId": id, "npcId": npc_id}

## Apenas lista ofertas daquele NPC. Consultar a lista nunca aceita nem inicia uma missão.
func oferta_pertence_ao_npc(missao_id: String, npc_id: String) -> bool:
	if not _ofertas.has(missao_id):
		return false
	return str(_ofertas[missao_id].get("npcId", "")) == npc_id

func listar_ofertas(npc_id: String, estado_jogador: Dictionary) -> Array:
	var resultado: Array = []
	var id_npc := npc_id.strip_edges()
	var missoes: Dictionary = estado_jogador.get("missoes", {})
	var concluidas: Dictionary = estado_jogador.get("missoesConcluidas", {})
	for id in _ofertas.keys():
		var oferta: Dictionary = _ofertas[id]
		if str(oferta.get("npcId", "")) != id_npc or concluidas.has(id):
			continue
		var status := str(missoes.get(id, {}).get("status", "disponivel"))
		if status == "em_andamento" or status == "objetivos_concluidos" or status == "recompensada":
			continue
		resultado.append(oferta.duplicate(true))
	return resultado

func aceitar_missao(estado_jogador: Dictionary, missao_id: String) -> Dictionary:
	var id := missao_id.strip_edges()
	if not _ofertas.has(id):
		return {"ok": false, "erro": "Oferta não encontrada."}
	var estado := estado_jogador.duplicate(true)
	var missoes: Dictionary = estado.get("missoes", {}).duplicate(true)
	var concluidas: Dictionary = estado.get("missoesConcluidas", {})
	if concluidas.has(id):
		return {"ok": false, "erro": "Esta missão já foi concluída."}
	if missoes.has(id):
		var status := str(missoes[id].get("status", ""))
		if status == "em_andamento" or status == "objetivos_concluidos" or status == "recompensada":
			return {"ok": false, "erro": "Esta missão já está ativa ou concluída."}
		missoes.erase(id)
		estado["missoes"] = missoes
	var inicio: Dictionary = _motor.iniciar_missao(estado, id)
	if not bool(inicio.get("ok", false)):
		return inicio
	var novo_estado: Dictionary = inicio["estado"]
	var ativas: Dictionary = novo_estado.get("missoes", {}).duplicate(true)
	var registro: Dictionary = ativas[id].duplicate(true)
	registro["npcId"] = str(_ofertas[id]["npcId"])
	registro["titulo"] = str(_ofertas[id]["titulo"])
	ativas[id] = registro
	novo_estado["missoes"] = ativas
	return {"ok": true, "estado": novo_estado, "missaoId": id}

## Recusar é uma escolha reversível: o jogador pode voltar ao NPC e aceitar depois.
func recusar_oferta(estado_jogador: Dictionary, missao_id: String) -> Dictionary:
	var id := missao_id.strip_edges()
	if not _ofertas.has(id):
		return {"ok": false, "erro": "Oferta não encontrada."}
	var estado := estado_jogador.duplicate(true)
	var missoes: Dictionary = estado.get("missoes", {}).duplicate(true)
	if missoes.has(id) and str(missoes[id].get("status", "")) in ["em_andamento", "objetivos_concluidos", "recompensada"]:
		return {"ok": false, "erro": "Não é possível recusar uma missão já aceita."}
	missoes[id] = {"status": "recusada", "npcId": str(_ofertas[id]["npcId"])}
	estado["missoes"] = missoes
	return {"ok": true, "estado": estado, "missaoId": id}

func abandonar_missao(estado_jogador: Dictionary, missao_id: String) -> Dictionary:
	var id := missao_id.strip_edges()
	var missoes: Dictionary = estado_jogador.get("missoes", {})
	if not _ofertas.has(id) or not missoes.has(id):
		return {"ok": false, "erro": "Missão não encontrada ou não aceita."}
	var status := str(missoes[id].get("status", ""))
	if status != "em_andamento" and status != "objetivos_concluidos":
		return {"ok": false, "erro": "Esta missão não pode ser abandonada agora."}
	var estado := estado_jogador.duplicate(true)
	var copia: Dictionary = estado.get("missoes", {}).duplicate(true)
	var registro: Dictionary = copia[id].duplicate(true)
	registro["status"] = "abandonada"
	registro["abandonadaEmUnix"] = int(Time.get_unix_time_from_system())
	copia[id] = registro
	estado["missoes"] = copia
	return {"ok": true, "estado": estado, "missaoId": id}

## Só chamar depois que o servidor confirmar a derrota, coleta, visita ou encontro.
func registrar_evento_autoritativo(estado_jogador: Dictionary, tipo_evento: String, alvo_id: String, quantidade: int = 1) -> Dictionary:
	var resultado: Dictionary = _motor.registrar_evento_autoritativo(estado_jogador, tipo_evento, alvo_id, quantidade)
	if not bool(resultado.get("ok", false)):
		return resultado
	return resultado

func preparar_conclusao(estado_jogador: Dictionary, missao_id: String) -> Dictionary:
	var validacao: Dictionary = _motor.preparar_conclusao(estado_jogador, missao_id)
	if not bool(validacao.get("ok", false)):
		return validacao
	if not _ofertas.has(missao_id):
		return {"ok": false, "erro": "Definição da missão não está disponível."}
	return validacao

## Marca a missão no estado de domínio. O pagamento persistente deve ser feito pelo repositório do servidor.
func marcar_recompensada(estado_jogador: Dictionary, missao_id: String) -> Dictionary:
	var validacao := preparar_conclusao(estado_jogador, missao_id)
	if not bool(validacao.get("ok", false)):
		return validacao
	var resultado: Dictionary = _motor.marcar_recompensada(estado_jogador, missao_id)
	if not bool(resultado.get("ok", false)):
		return resultado
	var estado: Dictionary = resultado["estado"]
	var concluidas: Dictionary = estado.get("missoesConcluidas", {}).duplicate(true)
	concluidas[missao_id] = {"status": "recompensada", "npcId": str(_ofertas[missao_id]["npcId"])}
	estado["missoesConcluidas"] = concluidas
	resultado["estado"] = estado
	return resultado
