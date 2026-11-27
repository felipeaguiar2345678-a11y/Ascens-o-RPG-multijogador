extends SceneTree
## Verifica o comparador utilizado para repetir flushes quando snapshots mudam durante I/O.

const Rede = preload("res://scripts/rede_multiplayer.gd")

func _initialize() -> void:
	var snapshot := {"versao": 1, "criaturas": [{"id": "lobo_1", "vida": 20}]}
	var confirmado := JSON.stringify(snapshot)
	if not Rede.snapshot_global_confirmado(snapshot, confirmado):
		_falhar("Snapshot idêntico ao D1 foi rejeitado.")
		return

	var alterado := {"versao": 1, "criaturas": [{"id": "lobo_1", "vida": 19}]}
	if Rede.snapshot_global_confirmado(alterado, confirmado):
		_falhar("Snapshot alterado foi considerado confirmado.")
		return

	if Rede.snapshot_global_confirmado(snapshot, ""):
		_falhar("Snapshot sem confirmação remota foi aceito.")
		return

	if Rede.snapshot_global_confirmado("texto inválido", confirmado):
		_falhar("Tipo de snapshot inválido foi aceito.")
		return

	if not Rede.servidor_aceita_operacoes(true, false):
		_falhar("O servidor ativo rejeitou operações fora do encerramento.")
		return
	if Rede.servidor_aceita_operacoes(true, true):
		_falhar("O servidor aceitou novas operações durante o flush final.")
		return
	if Rede.servidor_aceita_operacoes(false, false):
		_falhar("Um processo sem autoridade de servidor aceitou operações.")
		return

	if not Rede.renovacao_lease_permitida(false, false, false):
		_falhar("A renovação periódica normal foi bloqueada.")
		return
	if not Rede.renovacao_lease_permitida(true, true, false):
		_falhar("A lease deixou de renovar durante o flush final.")
		return
	if Rede.renovacao_lease_permitida(true, false, false):
		_falhar("A lease continuou renovando depois do fim do flush.")
		return
	if Rede.renovacao_lease_permitida(false, true, true):
		_falhar("Uma segunda renovação foi permitida enquanto a primeira estava em andamento.")
		return

	var lista := [{"id": "grupo_1", "individuos": 5}]
	if not Rede.snapshot_global_confirmado(lista, JSON.stringify(lista)):
		_falhar("Snapshot em lista não foi reconhecido.")
		return

	print("TESTE FLUSH GLOBAL: snapshots, bloqueio de novas operações e renovação da lease durante o encerramento foram verificados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE FLUSH GLOBAL: " + mensagem)
	quit(1)
