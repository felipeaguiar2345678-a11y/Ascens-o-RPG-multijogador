extends SceneTree
## Verifica a configuração Firebase sem depender de credenciais reais ou rede.

const Rede = preload("res://scripts/rede_multiplayer.gd")

func _initialize() -> void:
	var ausente := Rede.validar_configuracao_firebase({})
	if bool(ausente.get("ok", false)):
		_falhar("A configuração aceitou apiKey ausente.")
		return

	var exemplo := Rede.validar_configuracao_firebase({"apiKey": "COLE_A_CHAVE_WEB_DO_SEU_PROJETO_FIREBASE_AQUI"})
	if bool(exemplo.get("ok", false)):
		_falhar("A configuração aceitou a chave de exemplo.")
		return

	var tipo_invalido := Rede.validar_configuracao_firebase(["apiKey", "valor"])
	if bool(tipo_invalido.get("ok", false)):
		_falhar("A configuração aceitou JSON que não é um objeto.")
		return

	var chave_com_espaco := Rede.validar_configuracao_firebase({"apiKey": "AIzaSyDUMMY KEY FOR TEST"})
	if bool(chave_com_espaco.get("ok", false)):
		_falhar("A configuração aceitou uma chave com espaço.")
		return

	var chave_valida := Rede.validar_configuracao_firebase({"apiKey": "AIzaSyDUMMY_TEST_KEY_1234567890"})
	if not bool(chave_valida.get("ok", false)) or str(chave_valida.get("apiKey", "")) != "AIzaSyDUMMY_TEST_KEY_1234567890":
		_falhar("A configuração recusou uma chave de teste válida.")
		return

	print("TESTE CONFIGURAÇÃO FIREBASE: arquivo ausente, exemplo, tipo inválido e chave malformada são rejeitados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE CONFIGURAÇÃO FIREBASE: " + mensagem)
	quit(1)
