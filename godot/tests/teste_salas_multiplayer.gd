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
	if sistema.quantidade_salas() != 1:
		_falhar("A sala vazia deveria permanecer registrada para permitir retorno após desconexão.")
		return
	var estado_persistido := sistema.exportar_estado_persistente()
	var restaurado = Salas.new()
	var resultado_restauracao: Dictionary = restaurado.restaurar_estado_persistente(estado_persistido)
	if not bool(resultado_restauracao.get("sucesso", false)) or restaurado.quantidade_salas() != 1:
		_falhar("A sala não foi restaurada após simular reinicialização do servidor.")
		return
	var retorno: Dictionary = restaurado.entrar_sala(50, "uid-anfitriao", "ABC234")
	if not bool(retorno.get("sucesso", false)) or int(retorno.get("sala", {}).get("anfitriaoPeerId", -1)) != 50:
		_falhar("O participante original não conseguiu retornar à sala persistida.")
		return
	if bool(restaurado.entrar_sala(51, "uid-anfitriao", "ABC234").get("sucesso", false)):
		_falhar("A mesma conta conseguiu entrar duas vezes simultaneamente na sala.")
		return
	var snapshot_retorno: Dictionary = restaurado.obter_estado_aventura(50)
	if str(snapshot_retorno.get("codigo", "")) != "ABC234":
		_falhar("A sala restaurada não preservou seu código.")
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
	var atualizacao_a: Dictionary = outra_sala.atualizar_estado_aventura(30, {"missao":"bosque-antigo", "etapa":2}, 0)
	if not bool(atualizacao_a.get("sucesso", false)):
		_falhar("O membro não conseguiu atualizar o estado da própria aventura.")
		return
	if int(atualizacao_a.get("revisao", 0)) != 1:
		_falhar("A primeira atualização não avançou a revisão para um.")
		return
	# Uma segunda tela ainda na revisão zero não pode sobrescrever a etapa mais recente.
	var conflito: Dictionary = outra_sala.atualizar_estado_aventura(30, {"missao":"bosque-antigo", "etapa":1}, 0)
	if bool(conflito.get("sucesso", false)) or not bool(conflito.get("conflito", false)) or int(conflito.get("revisaoAtual", 0)) != 1:
		_falhar("Uma atualização atrasada sobrescreveu o progresso mais recente.")
		return
	if int(outra_sala.obter_estado_aventura(30).get("estado", {}).get("etapa", 0)) != 2:
		_falhar("O conflito alterou indevidamente a etapa atual da missão.")
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
	var membros_a: Array = outra_sala.obter_sala_do_jogador(30).get("jogadores", [])
	var membros_b: Array = outra_sala.obter_sala_do_jogador(31).get("jogadores", [])
	if not membros_a.has(30) or membros_a.has(31) or not membros_b.has(31) or membros_b.has(30):
		_falhar("A lista de destinatários da aventura misturou membros de salas diferentes.")
		return
	var fala_ok: Dictionary = outra_sala.registrar_mensagem(30, "uid-global-a", "Aventureiro", "A trilha segue para o norte.")
	if not bool(fala_ok.get("sucesso", false)):
		_falhar("Um membro autenticado não conseguiu registrar uma mensagem narrativa.")
		return
	var fala_b: Dictionary = outra_sala.registrar_mensagem(31, "uid-global-b", "Outro", "Estou na outra aventura.")
	if not bool(fala_b.get("sucesso", false)):
		_falhar("O segundo membro não conseguiu falar na própria sala.")
		return
	var mensagens_b: Array = outra_sala.obter_estado_aventura(31).get("estado", {}).get("mensagens", [])
	if mensagens_b.size() != 1 or str(mensagens_b[0].get("texto", "")) != "Estou na outra aventura.":
		_falhar("A mensagem da segunda sala não permaneceu isolada.")
		return
	if bool(outra_sala.registrar_mensagem(30, "uid-invasor", "Intruso", "Fala indevida.").get("sucesso", false)):
		_falhar("Uma identidade diferente da sessão ativa conseguiu falar.")
		return
	var mensagens_salvas: Array = outra_sala.obter_estado_aventura(30).get("estado", {}).get("mensagens", [])
	if mensagens_salvas.size() != 1 or str(mensagens_salvas[0].get("texto", "")) != "A trilha segue para o norte.":
		_falhar("O histórico narrativo não preservou a mensagem correta.")
		return
	if bool(outra_sala.registrar_mensagem(30, "uid-global-a", "Aventureiro", "x".repeat(301)).get("sucesso", false)):
		_falhar("O sistema aceitou mensagem acima do limite de 300 caracteres.")
		return
	var snapshot_a: Dictionary = outra_sala.obter_estado_aventura(30)
	if str(snapshot_a.get("codigo", "")) != "AAA234" or int(snapshot_a.get("revisao", 0)) != 2:
		_falhar("O snapshot da aventura não preservou sala e revisão.")
		return
	var snapshot_duravel: Array = outra_sala.exportar_estado_persistente()
	var servidor_reiniciado = Salas.new()
	var restauracao_duravel: Dictionary = servidor_reiniciado.restaurar_estado_persistente(snapshot_duravel)
	if not bool(restauracao_duravel.get("sucesso", false)):
		_falhar("O servidor não restaurou o arquivo de salas válido.")
		return
	var jogador_reconectado: Dictionary = servidor_reiniciado.entrar_sala(60, "uid-global-a", "AAA234")
	if not bool(jogador_reconectado.get("sucesso", false)):
		_falhar("O jogador não conseguiu reabrir sua sala após reinício.")
		return
	var aventura_reconectada: Dictionary = servidor_reiniciado.obter_estado_aventura(60)
	if int(aventura_reconectada.get("revisao", 0)) != 2 or int(aventura_reconectada.get("estado", {}).get("etapa", 0)) != 2:
		_falhar("O progresso narrativo não sobreviveu ao reinício simulado.")
		return
	if not servidor_reiniciado.obter_estado_aventura(61).is_empty():
		_falhar("A restauração expôs a aventura a um peer não autenticado na sala.")
		return
	var restauracao_invalida = Salas.new()
	var dados_corrompidos: Dictionary = restauracao_invalida.restaurar_estado_persistente([{"codigo":"INVÁLIDO","membrosUid":[],"estadoAventura":{},"revisaoAventura":0}])
	if bool(dados_corrompidos.get("sucesso", false)) or restauracao_invalida.quantidade_salas() != 0:
		_falhar("O sistema aceitou dados persistidos de sala inválidos.")
		return
	print("TESTE DE SALAS MULTIPLAYER: criação, isolamento, revisão e proteção contra atualização atrasada aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE SALAS MULTIPLAYER: " + mensagem)
	quit(1)
