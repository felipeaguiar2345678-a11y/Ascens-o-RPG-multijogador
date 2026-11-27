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

	var lista := [{"id": "grupo_1", "individuos": 5}]
	if not Rede.snapshot_global_confirmado(lista, JSON.stringify(lista)):
		_falhar("Snapshot em lista não foi reconhecido.")
		return

	print("TESTE FLUSH GLOBAL: snapshots iguais, divergentes, ausentes e tipos inválidos foram verificados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE FLUSH GLOBAL: " + mensagem)
	quit(1)
