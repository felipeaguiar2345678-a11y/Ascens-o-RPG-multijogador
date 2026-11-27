extends Node
class_name RepositorioMundoRemoto
## Cliente servidor-servidor para documentos versionados do mundo global.
## Nunca instanciar no cliente do jogador; a credencial existe somente no host dedicado.

const MAX_DOCUMENTO_BYTES := 900000
const CHAVES_DOCUMENTOS := [
	"characters", "creatures", "wildlife_groups", "ecological_resources",
	"mimics", "mimic_pity", "cooperative_rooms", "allies", "world_boss",
	"world_clock", "world_events"
]

var endpoint_base := ""
var token_servidor := ""
var identificador_instancia := ""
var token_lease := ""
var lease_ativa := false

static func chave_valida(chave: String) -> bool:
	if CHAVES_DOCUMENTOS.has(chave):
		return true
	if chave.begins_with("character_") and chave.length() == "character_".length() + 64:
		var hash_uid := chave.substr("character_".length())
		for caractere in hash_uid:
			if not "0123456789abcdef".contains(caractere):
				return false
		return true
	if not chave.begins_with("wildlife_groups_") or chave.length() != "wildlife_groups_".length() + 2:
		return false
	return ["00","01","02","03","04","05","06","07","08","09","0a","0b","0c","0d","0e","0f"].has(chave.substr("wildlife_groups_".length()))

static func endpoint_valido(endpoint: String) -> bool:
	if not endpoint.begins_with("https://") or endpoint.length() > 300 or endpoint.contains("\n") or endpoint.contains("\r") or endpoint.contains(" ") or endpoint.contains("\t"):
		return false
	var host := endpoint.substr("https://".length())
	while host.ends_with("/"):
		host = host.substr(0, host.length() - 1)
	if host.is_empty() or host.contains("/") or host.contains("?") or host.contains("#") or host.contains("@") or host.contains(":") or not host.contains(".") or host.begins_with(".") or host.ends_with(".") or host.contains(".."):
		return false
	for rotulo in host.split("."):
		if rotulo.is_empty() or rotulo.length() > 63 or rotulo.begins_with("-") or rotulo.ends_with("-"):
			return false
		for caractere in rotulo:
			if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-".contains(caractere):
				return false
	return true

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

## Identidade efêmera do host. O token de lease nunca é enviado aos clientes do jogo.
func criar_identidade_lease() -> bool:
	var crypto := Crypto.new()
	var bytes_dono := crypto.generate_random_bytes(16)
	var bytes_lease := crypto.generate_random_bytes(32)
	if bytes_dono.size() != 16 or bytes_lease.size() != 32:
		return false
	identificador_instancia = "server_" + bytes_dono.hex_encode()
	token_lease = bytes_lease.hex_encode()
	return true

func adquirir_lease(ttl_segundos: int = 30) -> Dictionary:
	var resultado := await _executar_lease("acquire", ttl_segundos)
	lease_ativa = bool(resultado.get("ok", false))
	return resultado

func renovar_lease(ttl_segundos: int = 30) -> Dictionary:
	var resultado := await _executar_lease("renew", ttl_segundos)
	lease_ativa = bool(resultado.get("ok", false))
	return resultado

func liberar_lease() -> Dictionary:
	if identificador_instancia.is_empty() or token_lease.is_empty():
		return {"ok":false,"erro":"Identidade de lease não foi criada."}
	var resultado := await _executar_rota("POST", "/api/server/lease", JSON.stringify({
		"action":"release","ownerId":identificador_instancia,"leaseToken":token_lease
	}))
	lease_ativa = false
	return resultado

func _executar_lease(acao: String, ttl_segundos: int) -> Dictionary:
	if not esta_configurado() or identificador_instancia.is_empty() or token_lease.is_empty():
		return {"ok":false,"erro":"Cliente remoto ou identidade de lease não configurados."}
	return await _executar_rota("POST", "/api/server/lease", JSON.stringify({
		"action":acao,"ownerId":identificador_instancia,"leaseToken":token_lease,"ttlSeconds":ttl_segundos
	}))

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
	if not lease_ativa or identificador_instancia.is_empty() or token_lease.is_empty():
		return {"ok":false,"erro":"Gravação bloqueada: esta instância não possui a lease do mundo global."}
	var corpo := JSON.stringify({"expectedRevision":revisao_esperada,"payload":payload})
	var resposta := await _executar("PUT", chave, corpo)
	if int(resposta.get("status", 0)) == 409:
		var dados_conflito: Dictionary = resposta.get("dados", {})
		return {"ok":false,"conflito":true,"revisaoAtual":int(dados_conflito.get("currentRevision", -1)),"erro":"O documento global foi alterado por outro processo."}
	if not bool(resposta.get("ok", false)):
		return resposta
	var dados: Dictionary = resposta.get("dados", {})
	return {"ok":true,"revisao":int(dados.get("revision", -1))}

## Confirma dois perfis em uma única transação D1. Repetir o mesmo ID é idempotente.
func salvar_troca_personagens_atomica(transacao_id: String, chave_a: String, payload_a: Dictionary, revisao_a: int, chave_b: String, payload_b: Dictionary, revisao_b: int) -> Dictionary:
	if not esta_configurado() or not lease_ativa or identificador_instancia.is_empty() or token_lease.is_empty():
		return {"ok":false,"erro":"Troca global bloqueada: lease do mundo indisponível."}
	if transacao_id.length() != 32 or not transacao_id.is_valid_hex_number(false):
		return {"ok":false,"erro":"Identificador de transação inválido."}
	if not chave_valida(chave_a) or not chave_valida(chave_b) or chave_a == chave_b or revisao_a < 1 or revisao_b < 1:
		return {"ok":false,"erro":"Perfis ou revisões inválidos para a troca."}
	if not payload_valido(payload_a) or not payload_valido(payload_b):
		return {"ok":false,"erro":"Snapshot de personagem excede o limite ou é inválido."}
	var corpo := JSON.stringify({
		"transactionId":transacao_id,
		"playerA":{"key":chave_a,"expectedRevision":revisao_a,"payload":payload_a},
		"playerB":{"key":chave_b,"expectedRevision":revisao_b,"payload":payload_b}
	})
	var resposta := await _executar_rota("POST", "/api/server/character-trade", corpo)
	if not bool(resposta.get("ok", false)):
		return {"ok":false,"erro":str(resposta.get("erro","Falha na transação bilateral.")),"status":int(resposta.get("status",0))}
	var dados: Dictionary = resposta.get("dados", {})
	var revisoes: Dictionary = dados.get("revisions", {})
	var nova_a := int(revisoes.get(chave_a, -1))
	var nova_b := int(revisoes.get(chave_b, -1))
	if nova_a <= revisao_a or nova_b <= revisao_b:
		return {"ok":false,"erro":"A transação não retornou as duas revisões confirmadas."}
	return {"ok":true,"revisaoA":nova_a,"revisaoB":nova_b,"replayed":bool(dados.get("replayed",false))}


## Confirma recursos e os 16 fragmentos da fauna em uma única transação D1.
## O identificador deve ser estável durante retries do mesmo ciclo.
func salvar_ciclo_ecologico_atomico(transacao_id: String, payload_recursos: Dictionary, revisao_recursos: int, documentos_fauna: Array) -> Dictionary:
	if not esta_configurado() or not lease_ativa or identificador_instancia.is_empty() or token_lease.is_empty():
		return {"ok":false,"erro":"Ciclo ecológico bloqueado: lease do mundo indisponível."}
	if transacao_id.length() != 32 or not transacao_id.is_valid_hex_number(false):
		return {"ok":false,"erro":"Identificador do ciclo ecológico inválido."}
	if revisao_recursos < 0 or not payload_valido(payload_recursos) or documentos_fauna.size() != 16:
		return {"ok":false,"erro":"Snapshot de recursos ou quantidade de fragmentos inválida."}
	var documentos: Array = [{
		"key":"ecological_resources",
		"expectedRevision":revisao_recursos,
		"payload":payload_recursos
	}]
	var chaves_vistas := {}
	for documento in documentos_fauna:
		if not (documento is Dictionary):
			return {"ok":false,"erro":"Documento de fauna inválido."}
		var chave := str(documento.get("key", ""))
		var revisao := int(documento.get("expectedRevision", -1))
		var payload: Variant = documento.get("payload", null)
		if not chave_valida(chave) or not chave.begins_with("wildlife_groups_") or chaves_vistas.has(chave) or revisao < 0 or not payload_valido(payload):
			return {"ok":false,"erro":"Fragmento de fauna inválido ou duplicado: " + chave}
		chaves_vistas[chave] = true
		documentos.append({"key":chave,"expectedRevision":revisao,"payload":payload})
	for indice in range(16):
		var chave_esperada := "wildlife_groups_%02x" % indice
		if not chaves_vistas.has(chave_esperada):
			return {"ok":false,"erro":"Fragmento obrigatório ausente: " + chave_esperada}
	var corpo := JSON.stringify({"transactionId":transacao_id,"documents":documentos})
	var resposta := await _executar_rota("POST", "/api/server/world-cycle", corpo)
	if not bool(resposta.get("ok", false)):
		return {"ok":false,"erro":str(resposta.get("erro","Falha ao confirmar ciclo ecológico.")),"status":int(resposta.get("status",0)),"conflito":int(resposta.get("status",0)) == 409}
	var dados: Dictionary = resposta.get("dados", {})
	var revisoes: Dictionary = dados.get("revisions", {})
	if revisoes.size() != 17:
		return {"ok":false,"erro":"A transação não retornou as 17 revisões confirmadas."}
	var nova_revisao_recursos := int(revisoes.get("ecological_resources", -1))
	if nova_revisao_recursos <= revisao_recursos:
		return {"ok":false,"erro":"A revisão dos recursos não avançou após o commit."}
	for documento in documentos_fauna:
		var chave := str(documento["key"])
		if int(revisoes.get(chave, -1)) <= int(documento["expectedRevision"]):
			return {"ok":false,"erro":"A revisão do fragmento não avançou: " + chave}
	return {"ok":true,"revisaoRecursos":nova_revisao_recursos,"revisoesFauna":revisoes,"replayed":bool(dados.get("replayed",false))}

func _executar(metodo: String, chave: String, corpo: String) -> Dictionary:
	return await _executar_rota(metodo, "/api/server/world-state/" + chave, corpo)

func _executar_rota(metodo: String, rota: String, corpo: String) -> Dictionary:
	var requisicao := HTTPRequest.new()
	requisicao.timeout = 20.0
	add_child(requisicao)
	var cabecalhos := PackedStringArray([
		"Authorization: Bearer " + token_servidor,
		"Content-Type: application/json"
	])
	if not identificador_instancia.is_empty() and not token_lease.is_empty():
		cabecalhos.append("X-World-Server-ID: " + identificador_instancia)
		cabecalhos.append("X-World-Lease-Token: " + token_lease)
	var verbo := HTTPClient.METHOD_GET if metodo == "GET" else (HTTPClient.METHOD_POST if metodo == "POST" else HTTPClient.METHOD_PUT)
	var erro_inicio := requisicao.request(endpoint_base + rota, cabecalhos, verbo, corpo)
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
