extends SceneTree
## Garante que callbacks HTTP antigos não autentiquem uma conexão reutilizada.

const ValidacaoSessao = preload("res://scripts/sistema_validacao_sessao.gd")

func _initialize() -> void:
	var requisicao_atual := RefCounted.new()
	var pendentes := {17: requisicao_atual}

	var requisicao_antiga := RefCounted.new()
	if ValidacaoSessao.consumir_se_corresponder(pendentes, 17, requisicao_antiga):
		_falhar("Uma resposta antiga foi aceita para o peer reutilizado.")
		return
	if not pendentes.has(17) or pendentes[17] != requisicao_atual:
		_falhar("A resposta antiga removeu a requisição atual.")
		return

	if not ValidacaoSessao.consumir_se_corresponder(pendentes, 17, requisicao_atual):
		_falhar("A requisição atual correspondente foi recusada.")
		return
	if pendentes.has(17):
		_falhar("A requisição consumida permaneceu pendente.")
		return

	if ValidacaoSessao.consumir_se_corresponder(pendentes, 17, requisicao_atual):
		_falhar("Uma requisição já consumida foi aceita novamente.")
		return

	var uids := {17: "uid-original"}
	if not ValidacaoSessao.sessao_ativa(17, "uid-original", PackedInt32Array([17, 23]), uids):
		_falhar("Uma sessão conectada e com UID correspondente foi recusada.")
		return
	if ValidacaoSessao.sessao_ativa(17, "uid-original", PackedInt32Array([23]), uids):
		_falhar("Uma sessão desconectada foi considerada ativa.")
		return
	if ValidacaoSessao.sessao_ativa(17, "uid-original", PackedInt32Array([17]), {17: "uid-novo"}):
		_falhar("Um peer reutilizado por outra conta foi considerado a sessão antiga.")
		return
	if ValidacaoSessao.sessao_ativa(17, "", [17], uids):
		_falhar("Uma sessão sem UID foi considerada ativa.")
		return

	print("TESTE SESSÃO MULTIPLAYER: callbacks antigos, consumo único e identidade após await validados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE SESSÃO MULTIPLAYER: " + mensagem)
	quit(1)
