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
	if not cliente.criar_identidade_lease():
		push_error("Não foi possível criar identidade aleatória para lease.")
		quit(1)
	var dono := cliente.identificador_instancia
	var lease := cliente.token_lease
	var resultado_sem_lease: Dictionary = await cliente.salvar_documento("world_clock", {"dia":1}, 0)
	if resultado_sem_lease.get("ok", false):
		push_error("Cliente permitiu gravar sem adquirir a lease.")
		quit(1)
		return
	if dono.length() < 8 or dono.length() > 80 or lease.length() != 64:
		push_error("Identidade ou token de lease possui formato incorreto.")
		quit(1)
	if not cliente.criar_identidade_lease() or dono == cliente.identificador_instancia or lease == cliente.token_lease:
		push_error("Identidades de instância/lease não foram renovadas.")
		quit(1)
	cliente.free()
	print("TESTE DE PERSISTÊNCIA REMOTA DO MUNDO: aprovado.")
	quit(0)
