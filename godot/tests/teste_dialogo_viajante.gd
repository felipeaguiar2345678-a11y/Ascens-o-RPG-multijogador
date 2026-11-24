extends SceneTree

const Dialogo = preload("res://scripts/sistema_dialogo_viajante.gd")

func _initialize() -> void:
	var primeira: Dictionary = Dialogo.avancar(0)
	if not bool(primeira.get("continuar", false)) or int(primeira.get("etapa", 0)) != 1:
		_falhar("A conversa não inicia corretamente.")
		return
	if not str(primeira.get("texto", "")).contains("Aurelia"):
		_falhar("A primeira fala perdeu a informação sobre Aurelia.")
		return

	var segunda: Dictionary = Dialogo.avancar(int(primeira.get("etapa", 0)))
	if int(segunda.get("etapa", 0)) != 2 or not str(segunda.get("texto", "")).contains("chuvas"):
		_falhar("O assunto sobre a Floresta Arcana não avançou corretamente.")
		return

	var terceira: Dictionary = Dialogo.avancar(int(segunda.get("etapa", 0)))
	if int(terceira.get("etapa", 0)) != 3 or not str(terceira.get("texto", "")).contains("conhecer lugares"):
		_falhar("O assunto sobre as viagens de Iren não foi apresentado.")
		return

	var fim: Dictionary = Dialogo.avancar(int(terceira.get("etapa", 0)))
	if bool(fim.get("continuar", true)) or int(fim.get("etapa", -1)) != 0:
		_falhar("A conversa não oferece um encerramento limpo.")
		return

	print("TESTE DO DIÁLOGO DE IREN: três assuntos opcionais e encerramento aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DO DIÁLOGO DE IREN: " + mensagem)
	quit(1)
