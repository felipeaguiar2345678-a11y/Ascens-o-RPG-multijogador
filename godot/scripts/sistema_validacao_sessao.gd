extends RefCounted
## Protege callbacks assíncronos contra reutilização de identificadores de conexão.

static func consumir_se_corresponder(pendentes: Dictionary, peer_id: int, requisicao: Object) -> bool:
	if not pendentes.has(peer_id) or pendentes[peer_id] != requisicao:
		return false
	pendentes.erase(peer_id)
	return true
