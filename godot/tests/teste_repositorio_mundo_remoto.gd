extends SceneTree

const REMOTO = preload("res://scripts/repositorio_mundo_remoto.gd")

func _initialize() -> void:
	if not REMOTO.chave_valida("world_boss") or not REMOTO.chave_valida("wildlife_groups"):
		push_error("Chaves válidas de documentos globais foram rejeitadas.")
		quit(1)
		return
	if REMOTO.chave_valida("players") or REMOTO.chave_valida("../world_boss"):
		push_error("A lista de documentos globais aceitou uma chave não autorizada.")
		quit(1)
		return
	if not REMOTO.endpoint_valido("https://ascensao.example.workers.dev"):
		push_error("Endpoint HTTPS válido foi rejeitado.")
		quit(1)
	if REMOTO.endpoint_valido("http://servidor-inseguro") or REMOTO.endpoint_valido("https://endpoint com espaço"):
		push_error("Endpoint inseguro ou malformado foi aceito.")
		quit(1)
	if not REMOTO.payload_valido({"vida":120,"fase":"ativa"}) or not REMOTO.payload_valido([{"id":"grupo_1"}]):
		push_error("Documento JSON válido foi rejeitado.")
		quit(1)
	if REMOTO.payload_valido("texto") or REMOTO.payload_valido(null):
		push_error("Payload não estruturado foi aceito.")
		quit(1)
	if REMOTO.payload_valido({"dados":"x".repeat(900001)}):
		push_error("Documento acima do limite de 900 KB foi aceito.")
		quit(1)
	var cliente := REMOTO.new()
	if cliente.configurar("http://inseguro", "token-de-teste-com-mais-de-trinta-e-dois-caracteres"):
		push_error("Cliente aceitou endpoint sem HTTPS.")
		quit(1)
	cliente.free()
	print("TESTE DE PERSISTÊNCIA REMOTA DO MUNDO: aprovado.")
	quit(0)
