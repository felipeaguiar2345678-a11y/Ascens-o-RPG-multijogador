extends RefCounted
## Protege callbacks assíncronos contra reutilização de identificadores de conexão.

static func consumir_se_corresponder(pendentes: Dictionary, peer_id: int, requisicao: Object) -> bool:
	if not pendentes.has(peer_id) or pendentes[peer_id] != requisicao:
		return false
	pendentes.erase(peer_id)
	return true

## Confirma que o peer ainda representa a mesma sessão autenticada após um await.
static func sessao_ativa(peer_id: int, uid: String, peers_conectados: PackedInt32Array, uids_por_peer: Dictionary) -> bool:
	return peer_id > 0 and not uid.is_empty() and peers_conectados.has(peer_id) and str(uids_por_peer.get(peer_id, "")) == uid
