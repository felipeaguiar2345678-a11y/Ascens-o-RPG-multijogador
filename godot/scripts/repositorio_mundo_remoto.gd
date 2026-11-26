extends Node
class_name RepositorioMundoRemoto
## Cliente servidor-servidor para documentos versionados do mundo global.
## Nunca instanciar no cliente do jogador; a credencial existe somente no host dedicado.

const MAX_DOCUMENTO_BYTES := 900000
const CHAVES_DOCUMENTOS := [
	"characters", "creatures", "wildlife_groups", "ecological_resources",
	"mimics", "mimic_pity", "cooperative_rooms", "world_boss",
	"world_clock", "world_events", "world_discoveries"
]

var endpoint_base := ""
var token_servidor := ""

static func chave_valida(chave: String) -> bool:
	return CHAVES_DOCUMENTOS.has(chave)

static func endpoint_valido(endpoint: String) -> bool:
	return endpoint.begins_with("https://") and endpoint.length() <= 300 and not endpoint.contains(" ") and not endpoint.contains("\n")

static func payload_valido(payload: Variant) -> bool:
	if not (payload is Dictionary or payload is Array):
		return false
	var serializado := JSON.stringify(payload)
	return serializado.to_utf8_buffer().size() <= MAX_DOCUMENTO_BYTES

func configurar(url_override: String = "", token_override: String = "") -> bool:
	endpoint_base = url_override if not url_override.is_empty() else OS.get_environment("ASCENSAO_WORLD_STORAGE_URL")
	token_servidor = token_override if not token_override.is_empty() else OS.get_environment("ASCENSAO_WORLD_STORAGE_TOKEN")
	while endpoint_base.ends_with("/"):
		endpoint_base = endpoint_base.substr(0, endpoint_base.length() - 1)
	return endpoint_valido(endpoint_base) and token_servidor.length() >= 32 and token_servidor.length() <= 512

func esta_configurado() -> bool:
	return endpoint_valido(endpoint_base) and token_servidor.length() >= 32 and token_servidor.length() <= 512

func carregar_documento(chave: String) -> Dictionary:
	if not esta_configurado() or not chave_valida(chave):
		return {"ok":false,"erro":"Persistência remota não configurada ou chave inválida."}
	var resposta := await _executar("GET", chave, "")
	if not bool(resposta.get("ok", false)):
		return resposta
	var documento: Dictionary = resposta.get("dados", {})
	if str(documento.get("key", "")) != chave or not (documento.get("revision", -1) is int):
		return {"ok":false,"erro":"Resposta remota inválida."}
	return {"ok":true,"revisao":int(documento.get("revision", 0)),"payload":documento.get("payload", null)}

func salvar_documento(chave: String, payload: Variant, revisao_esperada: int) -> Dictionary:
	if not esta_configurado() or not chave_valida(chave) or revisao_esperada < 0 or not payload_valido(payload):
		return {"ok":false,"erro":"Persistência remota não configurada ou documento inválido."}
	var corpo := JSON.stringify({"expectedRevision":revisao_esperada,"payload":payload})
	var resposta := await _executar("PUT", chave, corpo)
	if int(resposta.get("status", 0)) == 409:
		var dados_conflito: Dictionary = resposta.get("dados", {})
		return {"ok":false,"conflito":true,"revisaoAtual":int(dados_conflito.get("currentRevision", -1)),"erro":"O documento global foi alterado por outro processo."}
	if not bool(resposta.get("ok", false)):
		return resposta
	var dados: Dictionary = resposta.get("dados", {})
	return {"ok":true,"revisao":int(dados.get("revision", -1))}

func _executar(metodo: String, chave: String, corpo: String) -> Dictionary:
	var requisicao := HTTPRequest.new()
	requisicao.timeout = 20.0
	add_child(requisicao)
	var cabecalhos := PackedStringArray([
		"Authorization: Bearer " + token_servidor,
		"Content-Type: application/json"
	])
	var verbo := HTTPClient.METHOD_GET if metodo == "GET" else HTTPClient.METHOD_PUT
	var erro_inicio := requisicao.request(endpoint_base + "/api/server/world-state/" + chave, cabecalhos, verbo, corpo)
	if erro_inicio != OK:
		requisicao.queue_free()
		return {"ok":false,"erro":"Não foi possível iniciar a conexão com a persistência global."}
	var retorno: Array = await requisicao.request_completed
	requisicao.queue_free()
	var status := int(retorno[1])
	var bytes: PackedByteArray = retorno[3]
	var dados = JSON.parse_string(bytes.get_string_from_utf8())
	if not (dados is Dictionary):
		return {"ok":false,"status":status,"erro":"A persistência global retornou uma resposta inválida."}
	if status < 200 or status >= 300:
		return {"ok":false,"status":status,"dados":dados,"erro":str(dados.get("message", dados.get("error", "Falha na persistência global.")))}
	return {"ok":true,"status":status,"dados":dados}
