extends RefCounted
## Protege callbacks assíncronos contra reutilização de identificadores de conexão.

static func consumir_se_corresponder(pendentes: Dictionary, peer_id: int, requisicao: Object) -> bool:
	if not pendentes.has(peer_id) or pendentes[peer_id] != requisicao:
		return false
	pendentes.erase(peer_id)
	return true

## Confirma que o peer ainda representa a mesma sessão autenticada após um await.
static func sessao_ativa(peer_id: int, uid: String, geracao: int, peers_conectados: PackedInt32Array, uids_por_peer: Dictionary, geracoes_por_peer: Dictionary) -> bool:
	return peer_id > 0 and not uid.is_empty() and geracao > 0 and peers_conectados.has(peer_id) and str(uids_por_peer.get(peer_id, "")) == uid and int(geracoes_por_peer.get(peer_id, -1)) == geracao

## Valida o retorno do endpoint Secure Token antes de substituir credenciais.
static func validar_resposta_refresh(dados: Variant, uid_esperado: String) -> Dictionary:
	if not (dados is Dictionary):
		return {}
	var id_token := str(dados.get("id_token", ""))
	var refresh_token := str(dados.get("refresh_token", ""))
	var uid := str(dados.get("user_id", ""))
	var duracao := int(str(dados.get("expires_in", "0")))
	if id_token.is_empty() or refresh_token.is_empty() or uid.is_empty() or duracao < 300:
		return {}
	if not uid_esperado.is_empty() and uid != uid_esperado:
		return {}
	return {"id_token": id_token, "refresh_token": refresh_token, "uid": uid, "duracao": duracao}
