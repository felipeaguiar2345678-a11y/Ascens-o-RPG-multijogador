extends SceneTree

const REMOTO = preload("res://scripts/repositorio_mundo_remoto.gd")

func _initialize() -> void:
	if not REMOTO.chave_valida("world_boss") or not REMOTO.chave_valida("cooperative_rooms") or not REMOTO.chave_valida("allies") or not REMOTO.chave_valida("wildlife_groups") or not REMOTO.chave_valida("wildlife_groups_00") or not REMOTO.chave_valida("wildlife_groups_0f") or not REMOTO.chave_valida("character_" + "a".repeat(64)):
		push_error("Chaves válidas de documentos globais foram rejeitadas.")
		quit(1)
		return
	if REMOTO.chave_valida("players") or REMOTO.chave_valida("characters") or REMOTO.chave_valida("world_discoveries") or REMOTO.chave_valida("../world_boss") or REMOTO.chave_valida("wildlife_groups_10") or REMOTO.chave_valida("wildlife_groups_gg") or REMOTO.chave_valida("wildlife_groups_000") or REMOTO.chave_valida("character_" + "g".repeat(64)) or REMOTO.chave_valida("character_" + "a".repeat(63)):
		push_error("A lista de documentos globais aceitou uma chave não autorizada.")
		quit(1)
		return
	if not REMOTO.transporte_http_valido(HTTPRequest.RESULT_SUCCESS, 200) or not REMOTO.transporte_http_valido(HTTPRequest.RESULT_SUCCESS, 409):
		push_error("Resposta HTTP recebida foi classificada incorretamente.")
		quit(1)
		return
	if REMOTO.transporte_http_valido(HTTPRequest.RESULT_CANT_CONNECT, 0) or REMOTO.transporte_http_valido(HTTPRequest.RESULT_SUCCESS, 0):
		push_error("Falha de transporte foi tratada como resposta HTTP válida.")
		quit(1)
		return
	var chave_troca_a := "character_" + "a".repeat(64)
	var chave_troca_b := "character_" + "b".repeat(64)
	if not REMOTO.confirmacao_troca_valida({chave_troca_a:5,chave_troca_b:8}, chave_troca_a, 4, chave_troca_b, 7):
		push_error("Confirmação bilateral válida foi rejeitada.")
		quit(1)
		return
	for troca_invalida in [
		{chave_troca_a:5},
		{chave_troca_a:5,chave_troca_b:7},
		{chave_troca_a:5,chave_troca_b:8,"character_" + "c".repeat(64):9},
		{chave_troca_a:"5",chave_troca_b:8},
		{chave_troca_a:5,chave_troca_b:8}
	]:
		if REMOTO.confirmacao_troca_valida(troca_invalida, chave_troca_a, 4, chave_troca_b, 7):
			push_error("Confirmação bilateral incompleta ou inconsistente foi aceita.")
			quit(1)
			return
	if not REMOTO.endpoint_valido("https://ascensao.example.workers.dev"):
		push_error("Endpoint HTTPS válido foi rejeitado.")
		quit(1)
	for endpoint_invalido in ["http://servidor-inseguro", "https://endpoint com espaço", "https://", "https:///api", "https://.workers.dev", "https://workers..dev", "https://-workers.dev", "https://workers-.dev", "https://usuario@workers.dev", "https://workers.dev?chave=valor", "https://workers.dev/#fragmento", "https://workers.dev" + char(10), "https://workers.dev" + char(13), "https://workers.dev" + char(9)]:
		if REMOTO.endpoint_valido(endpoint_invalido):
			push_error("Endpoint inseguro ou malformado foi aceito: " + endpoint_invalido)
			quit(1)
	if not REMOTO.payload_valido({"vida":120,"fase":"ativa"}) or not REMOTO.payload_valido([{"id":"grupo_1"}]):
		push_error("Documento JSON válido foi rejeitado.")
		quit(1)
	if not REMOTO.confirmacao_gravacao_valida("world_clock", {"worldId":"ascensao_global","key":"world_clock","revision":4}, 3):
		push_error("Confirmação de gravação válida foi rejeitada.")
		quit(1)
		return
	for confirmacao_invalida in [
		{"worldId":"outro_mundo","key":"world_clock","revision":4},
		{"worldId":"ascensao_global","key":"allies","revision":4},
		{"worldId":"ascensao_global","key":"world_clock","revision":3},
		{"worldId":"ascensao_global","key":"world_clock","revision":-1},
		{"worldId":"ascensao_global","key":"world_clock","revision":"4"},
		{"key":"world_clock","revision":4}
	]:
		if REMOTO.confirmacao_gravacao_valida("world_clock", confirmacao_invalida, 3):
			push_error("Confirmação de gravação inconsistente foi aceita.")
			quit(1)
			return
	if REMOTO.payload_valido("texto") or REMOTO.payload_valido(null):
		push_error("Payload não estruturado foi aceito.")
		quit(1)

	if not REMOTO.documento_remoto_valido("world_boss", {"worldId":"ascensao_global","key":"world_boss","revision":0,"payload":null}):
		push_error("Documento remoto ausente válido foi rejeitado.")
		quit(1)
	if not REMOTO.documento_remoto_valido("world_boss", {"worldId":"ascensao_global","key":"world_boss","revision":3,"payload":{"vida":120}}):
		push_error("Documento remoto existente válido foi rejeitado.")
		quit(1)
	for documento_invalido in [
		{"worldId":"ascensao_global","key":"world_boss","revision":-1,"payload":null},
		{"worldId":"ascensao_global","key":"world_boss","revision":"3","payload":{"vida":120}},
		{"worldId":"ascensao_global","key":"allies","revision":3,"payload":{"vida":120}},
		{"worldId":"ascensao_global","key":"world_boss","revision":0,"payload":{"vida":120}},
		{"worldId":"ascensao_global","key":"world_boss","revision":3,"payload":"corrompido"},
		{"worldId":"outro_mundo","key":"world_boss","revision":3,"payload":{"vida":120}},
		{"key":"world_boss","revision":3,"payload":{"vida":120}}
	]:
		if REMOTO.documento_remoto_valido("world_boss", documento_invalido):
			push_error("Resposta remota inconsistente foi aceita.")
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
