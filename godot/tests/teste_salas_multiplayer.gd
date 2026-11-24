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
	var fila_publica = Salas.new()
	var publica_a: Dictionary = fila_publica.entrar_sala_publica(20, "uid-publico-a")
	var publica_b: Dictionary = fila_publica.entrar_sala_publica(21, "uid-publico-b")
	if not bool(publica_a.get("sucesso", false)) or str(publica_a.get("codigo", "")) != str(publica_b.get("codigo", "")):
		_falhar("A entrada pública automática não agrupou jogadores em uma sala disponível.")
		return
	# Salas diferentes isolam apenas a aventura; o mundo global permanece o mesmo.
	var outra_sala = Salas.new()
	var sala_global_a: Dictionary = outra_sala.criar_sala(30, "uid-global-a", "AAA234")
	var sala_global_b: Dictionary = outra_sala.criar_sala(31, "uid-global-b", "BBB234")
	if not bool(sala_global_a.get("sucesso", false)) or not bool(sala_global_b.get("sucesso", false)):
		_falhar("Não foi possível criar duas salas para validar o mundo compartilhado.")
		return
	var dados_a: Dictionary = outra_sala.obter_sala("AAA234")
	var dados_b: Dictionary = outra_sala.obter_sala("BBB234")
	if str(dados_a.get("mundoId", "")) != Salas.ID_MUNDO_COMPARTILHADO or str(dados_b.get("mundoId", "")) != Salas.ID_MUNDO_COMPARTILHADO:
		_falhar("Salas diferentes foram associadas a mundos distintos.")
		return
	if str(dados_a.get("mundoId", "")) != str(dados_b.get("mundoId", "")):
		_falhar("O identificador do mundo global divergiu entre salas.")
		return
	if (dados_a.get("jogadores", []) as Array).has(31) or (dados_b.get("jogadores", []) as Array).has(30):
		_falhar("A lista de jogadores de uma aventura vazou para outra sala.")
		return
	var atualizacao_a: Dictionary = outra_sala.atualizar_estado_aventura(30, {"missao":"bosque-antigo", "etapa":2})
	if not bool(atualizacao_a.get("sucesso", false)):
		_falhar("O membro não conseguiu atualizar o estado da própria aventura.")
		return
	if not outra_sala.obter_estado_aventura(31).get("estado", {}).is_empty():
		_falhar("O estado de missão de uma sala vazou para outra.")
		return
	if not outra_sala.obter_estado_aventura(30).get("estado", {}).has("missao"):
		_falhar("A sala não recuperou o próprio estado de aventura.")
		return
	if str(atualizacao_a.get("mundoId", "")) != Salas.ID_MUNDO_COMPARTILHADO:
		_falhar("A atualização da aventura perdeu a referência ao mundo global.")
		return
	if str(outra_sala.obter_sala("BBB234").get("mundoId", "")) != Salas.ID_MUNDO_COMPARTILHADO:
		_falhar("A atualização de uma aventura alterou a identidade global da outra sala.")
		return
	if bool(outra_sala.atualizar_estado_aventura(99, {"missao":"intrusao"}).get("sucesso", false)):
		_falhar("Um jogador fora de sala conseguiu alterar uma aventura.")
		return
	print("TESTE DE SALAS MULTIPLAYER: criação, código, limite de quatro, fila pública, anfitrião e limpeza aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE SALAS MULTIPLAYER: " + mensagem)
	quit(1)
