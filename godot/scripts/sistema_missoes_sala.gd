extends RefCounted
## Motor autoritativo de objetivos. O estado retornado pertence à aventura da sala.
const DIFICULDADES := ["facil", "fácil", "media", "média", "dificil", "difícil", "extrema"]
const TIPOS_EVENTO := ["derrotar_criatura", "coletar_recurso", "visitar_local", "concluir_encontro"]
var _catalogo: Dictionary = {}

func registrar_definicao(definicao: Dictionary) -> Dictionary:
	var id := str(definicao.get("id", "")).strip_edges()
	var dificuldade := str(definicao.get("dificuldade", "")).strip_edges().to_lower()
	var objetivos: Array = definicao.get("objetivos", [])
	if id.is_empty() or id.length() > 128 or not DIFICULDADES.has(dificuldade) or objetivos.is_empty() or objetivos.size() > 20:
		return {"ok": false, "erro": "Identificação, dificuldade ou quantidade de objetivos inválida."}
	var vistos: Dictionary = {}
	var copia: Array = []
	for objetivo in objetivos:
		if not objetivo is Dictionary:
			return {"ok": false, "erro": "Objetivo inválido."}
		var oid := str(objetivo.get("id", "")).strip_edges()
		var tipo := str(objetivo.get("tipo", "")).strip_edges()
		var alvo := str(objetivo.get("alvoId", "")).strip_edges()
		var quantidade := int(objetivo.get("quantidade", 1))
		if oid.is_empty() or vistos.has(oid) or not TIPOS_EVENTO.has(tipo) or alvo.is_empty() or quantidade < 1 or quantidade > 100000:
			return {"ok": false, "erro": "Objetivo contém dados inválidos."}
		vistos[oid] = true
		copia.append({"id": oid, "tipo": tipo, "alvoId": alvo, "quantidade": quantidade})
	_catalogo[id] = {"id": id, "titulo": str(definicao.get("titulo", id)).strip_edges(), "dificuldade": dificuldade, "objetivos": copia}
	return {"ok": true, "missaoId": id}

func iniciar_missao(estado_sala: Dictionary, missao_id: String) -> Dictionary:
	var id := missao_id.strip_edges()
	if not _catalogo.has(id):
		return {"ok": false, "erro": "Missão não encontrada no catálogo do servidor."}
	var estado := estado_sala.duplicate(true)
	var missoes: Dictionary = estado.get("missoes", {}).duplicate(true)
	if missoes.has(id):
		return {"ok": false, "erro": "Esta missão já foi iniciada nesta aventura."}
	var progresso: Dictionary = {}
	for objetivo in _catalogo[id]["objetivos"]:
		progresso[str(objetivo["id"])] = 0
	missoes[id] = {"status": "em_andamento", "dificuldade": _catalogo[id]["dificuldade"], "progresso": progresso, "iniciadaEmUnix": int(Time.get_unix_time_from_system())}
	estado["missoes"] = missoes
	return {"ok": true, "estado": estado, "missaoId": id}

## Chamar somente após o servidor confirmar o evento real.
func registrar_evento_autoritativo(estado_sala: Dictionary, tipo_evento: String, alvo_id: String, quantidade: int = 1) -> Dictionary:
	if not TIPOS_EVENTO.has(tipo_evento) or alvo_id.strip_edges().is_empty() or quantidade < 1 or quantidade > 1000:
		return {"ok": false, "erro": "Evento de missão inválido."}
	var estado := estado_sala.duplicate(true)
	var missoes: Dictionary = estado.get("missoes", {}).duplicate(true)
	var alteradas: Array = []
	for missao_id in missoes.keys():
		var atual: Dictionary = missoes[missao_id].duplicate(true)
		if str(atual.get("status", "")) != "em_andamento" or not _catalogo.has(str(missao_id)):
			continue
		var progresso: Dictionary = atual.get("progresso", {}).duplicate(true)
		var mudou := false
		for objetivo in _catalogo[str(missao_id)]["objetivos"]:
			if str(objetivo["tipo"]) != tipo_evento or str(objetivo["alvoId"]) != alvo_id:
				continue
			var oid := str(objetivo["id"])
			var anterior := int(progresso.get(oid, 0))
			var novo := mini(int(objetivo["quantidade"]), anterior + quantidade)
			if novo > anterior:
				progresso[oid] = novo
				mudou = true
		if mudou:
			atual["progresso"] = progresso
			if _objetivos_concluidos(str(missao_id), progresso):
				atual["status"] = "objetivos_concluidos"
			missoes[missao_id] = atual
			alteradas.append(str(missao_id))
	estado["missoes"] = missoes
	return {"ok": true, "estado": estado, "missoesAlteradas": alteradas}

func preparar_conclusao(estado_sala: Dictionary, missao_id: String) -> Dictionary:
	var id := missao_id.strip_edges()
	var missoes: Dictionary = estado_sala.get("missoes", {})
	if not _catalogo.has(id) or not missoes.has(id):
		return {"ok": false, "erro": "Missão não iniciada ou inexistente."}
	if str(missoes[id].get("status", "")) != "objetivos_concluidos":
		return {"ok": false, "erro": "Ainda existem objetivos pendentes."}
	return {"ok": true, "missaoId": id, "dificuldade": str(_catalogo[id]["dificuldade"])}

func marcar_recompensada(estado_sala: Dictionary, missao_id: String) -> Dictionary:
	var validacao := preparar_conclusao(estado_sala, missao_id)
	if not bool(validacao.get("ok", false)):
		return validacao
	var estado := estado_sala.duplicate(true)
	var missoes: Dictionary = estado.get("missoes", {}).duplicate(true)
	var atual: Dictionary = missoes[missao_id].duplicate(true)
	atual["status"] = "recompensada"
	atual["recompensadaEmUnix"] = int(Time.get_unix_time_from_system())
	missoes[missao_id] = atual
	estado["missoes"] = missoes
	return {"ok": true, "estado": estado, "missaoId": missao_id}

func _objetivos_concluidos(missao_id: String, progresso: Dictionary) -> bool:
	if not _catalogo.has(missao_id):
		return false
	for objetivo in _catalogo[missao_id]["objetivos"]:
		if int(progresso.get(str(objetivo["id"]), 0)) < int(objetivo["quantidade"]):
			return false
	return true
