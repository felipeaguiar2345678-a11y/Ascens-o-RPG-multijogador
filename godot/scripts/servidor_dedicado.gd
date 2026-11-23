extends Node
## Entrada dedicada para hospedar o servidor principal de Ascensão do Soberano.
## Execute com: godot --headless --path godot res://scenes/servidor_dedicado.tscn

const PORTA_PADRAO := 2456
const LIMITE_JOGADORES_PADRAO := 40

func _ready() -> void:
	var porta := PORTA_PADRAO
	var limite := LIMITE_JOGADORES_PADRAO
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--porta="):
			porta = int(argumento.trim_prefix("--porta="))
		elif argumento.begins_with("--limite="):
			limite = int(argumento.trim_prefix("--limite="))

	var resultado := RedeMultiplayer.iniciar_servidor(porta, limite)
	if resultado != OK:
		push_error("Falha ao iniciar servidor dedicado: %s" % error_string(resultado))
		get_tree().quit(1)
		return

	print("Ascensão do Soberano — servidor principal ativo na porta UDP %d (limite %d jogadores)." % [porta, limite])
	print("Capacidade padrão: 40 jogadores simultâneos no mundo compartilhado.")
	print("Salas públicas de aventura: até 4 jogadores por sala (registro em memória; integração de rede ainda pendente).")
	print("Atenção: persistência ainda é local; hospedagem pública e descoberta automática de servidores ainda estão pendentes.")
