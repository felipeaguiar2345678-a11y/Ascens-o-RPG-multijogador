extends SceneTree

const Salas = preload("res://scripts/sistema_salas_multiplayer.gd")

func _initialize() -> void:
	var sistema = Salas.new()
	var criada: Dictionary = sistema.criar_sala(1, "uid-anfitriao", "ABC234")
	if not bool(criada.get("sucesso", false)):
		_falhar("Não foi possível criar uma sala com código válido.")
		return
	if str(criada.get("codigo", "")) != "ABC234":
		_falhar("O código criado não foi preservado.")
		return
	if not bool(sistema.entrar_sala(2, "uid-dois", "abc234").get("sucesso", false)):
		_falhar("A entrada com código em minúsculas deveria funcionar.")
		return
	if not bool(sistema.entrar_sala(3, "uid-tres", "ABC234").get("sucesso", false)):
		_falhar("O terceiro jogador deveria conseguir entrar.")
		return
	if not bool(sistema.entrar_sala(4, "uid-quatro", "ABC234").get("sucesso", false)):
		_falhar("O quarto jogador deveria conseguir entrar.")
		return
	if bool(sistema.entrar_sala(5, "uid-cinco", "ABC234").get("sucesso", false)):
		_falhar("A sala aceitou um quinto jogador.")
		return
	if bool(sistema.criar_sala(1, "uid-anfitriao", "DEF456").get("sucesso", false)):
		_falhar("Um jogador conseguiu criar outra sala enquanto já pertence a uma.")
		return
	if bool(sistema.criar_sala(6, "uid-seis", "ABC234").get("sucesso", false)):
		_falhar("O sistema aceitou um código já utilizado.")
		return
	var saida: Dictionary = sistema.remover_jogador(1)
	if bool(saida.get("salaEncerrada", true)):
		_falhar("A sala foi encerrada mesmo com outros jogadores presentes.")
		return
	if int(sistema.obter_sala("ABC234").get("anfitriaoPeerId", -1)) != 2:
		_falhar("A liderança não foi transferida após a saída do anfitrião.")
		return
	sistema.remover_jogador(2)
	sistema.remover_jogador(3)
	sistema.remover_jogador(4)
	if sistema.quantidade_salas() != 0:
		_falhar("A sala vazia não foi removida.")
		return
	var gerada: Dictionary = sistema.criar_sala(7, "uid-sete")
	var codigo_gerado := str(gerada.get("codigo", ""))
	if not bool(gerada.get("sucesso", false)) or codigo_gerado.length() != Salas.TAMANHO_CODIGO:
		_falhar("A geração automática de código não produziu seis caracteres.")
		return
	print("TESTE DE SALAS MULTIPLAYER: criação, código, limite de quatro, anfitrião e limpeza aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE SALAS MULTIPLAYER: " + mensagem)
	quit(1)
