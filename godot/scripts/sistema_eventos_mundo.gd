extends RefCounted
class_name SistemaEventosMundo
## Estado temporal de eventos do mundo. Todos os prazos usam Unix (segundos).

const VERSAO := 1
const LIMITE_EVENTOS := 256
const DURACAO_MAXIMA_SEGUNDOS := 30 * 24 * 60 * 60

static func documento_valido(payload: Variant) -> bool:
	if not (payload is Dictionary) or int(payload.get("versao", 0)) != VERSAO:
		return false
	var eventos = payload.get("eventos", null)
	if not (eventos is Array) or eventos.size() > LIMITE_EVENTOS:
		return false
	var ids := {}
	for evento in eventos:
		if not evento_valido(evento):
			return false
		var id := str(evento.get("id", ""))
		if ids.has(id):
			return false
		ids[id] = true
	return true

static func evento_valido(evento: Variant) -> bool:
	if not (evento is Dictionary):
		return false
	var id := str(evento.get("id", ""))
	var tipo := str(evento.get("tipo", ""))
	var inicio := int(evento.get("inicioUnix", 0))
	var fim := int(evento.get("fimUnix", 0))
	return not id.is_empty() and id.length() <= 128 and not tipo.is_empty() and tipo.length() <= 64 and inicio > 0 and fim > inicio and fim - inicio <= DURACAO_MAXIMA_SEGUNDOS

static func criar_documento(eventos: Array = []) -> Dictionary:
	return {"versao": VERSAO, "eventos": eventos.duplicate(true)}

static func listar_ativos(payload: Dictionary, agora_unix: int) -> Array:
	var ativos: Array = []
	if not documento_valido(payload):
		return ativos
	for evento in payload["eventos"]:
		if int(evento["inicioUnix"]) <= agora_unix and agora_unix < int(evento["fimUnix"]):
			ativos.append(evento.duplicate(true))
	return ativos

## Snapshot seguro para um jogador que acabou de entrar no mundo compartilhado.
## Eventos futuros e vencidos não são enviados como eventos em andamento.
static func criar_snapshot_inicial(payload: Dictionary, agora_unix: int) -> Array:
	return listar_ativos(payload, agora_unix)


static func expirar(payload: Dictionary, agora_unix: int) -> Dictionary:
	if not documento_valido(payload):
		return {"ok": false, "erro": "Documento de eventos inválido."}
	var restantes: Array = []
	var expirados: Array = []
	for evento in payload["eventos"]:
		if int(evento["fimUnix"]) <= agora_unix:
			expirados.append(str(evento["id"]))
		else:
			restantes.append(evento.duplicate(true))
	return {"ok": true, "payload": criar_documento(restantes), "expirados": expirados, "alterou": not expirados.is_empty()}

static func registrar(payload: Dictionary, evento: Dictionary, agora_unix: int) -> Dictionary:
	if not documento_valido(payload) or not evento_valido(evento):
		return {"ok": false, "erro": "Evento ou documento inválido."}
	if int(evento["inicioUnix"]) < agora_unix - 60 or int(evento["fimUnix"]) <= agora_unix:
		return {"ok": false, "erro": "Evento não pode ser registrado com prazo vencido."}
	var atualizados := expirar(payload, agora_unix)
	var eventos: Array = atualizados["payload"]["eventos"]
	for existente in eventos:
		if str(existente["id"]) == str(evento["id"]):
			return {"ok": false, "erro": "Já existe um evento com esse identificador."}
	if eventos.size() >= LIMITE_EVENTOS:
		return {"ok": false, "erro": "Limite de eventos simultâneos/pendentes atingido."}
	eventos.append(evento.duplicate(true))
	return {"ok": true, "payload": criar_documento(eventos)}
