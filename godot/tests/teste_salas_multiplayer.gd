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
	var uid_excessivo := "u".repeat(257)
	if bool(sistema.entrar_sala(99, uid_excessivo, "ABC234").get("sucesso", false)):
		_falhar("A sala aceitou um UID maior que o limite persistível.")
		return
	if (sistema.obter_sala("ABC234").get("jogadores", []) as Array).size() != 1:
		_falhar("Uma entrada recusada por UID inválido deixou uma vaga ocupada.")
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
	if bool(sistema.registrar_mensagem(7, "uid-sete", "Aventureiro", "Ainda estou sozinho.").get("sucesso", false)):
		_falhar("A aventura compartilhada começou com apenas um jogador.")
		return
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
	var entrada_a: Dictionary = outra_sala.entrar_sala(32, "uid-global-a2", "AAA234")
	var entrada_b: Dictionary = outra_sala.entrar_sala(33, "uid-global-b2", "BBB234")
	if not bool(entrada_a.get("sucesso", false)) or not bool(entrada_b.get("sucesso", false)):
		_falhar("Não foi possível formar dois grupos para testar a conversa cooperativa.")
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
	var encontro_ok: Dictionary = outra_sala.registrar_encontro(30, {
		"id":"criatura_teste_catalogada",
		"nome":"Sentinela do Bosque",
		"descricao":"Uma criatura de teste registrada no catálogo.",
		"rank":"C",
		"raridade":"raro",
		"nivel":12,
		"experienciaBase":90,
		"periodoRecompensa":"noite",
		"vidaMaxima":240,
		"iconePath":"res://arte/sentinela.png",
		"ecossistemaId":"floresta_arcana",
		"bioma":"bosque",
		"ataque":8,
		"defesa":2,
		"tabelaDrops":[{"itemId":"escama_sentinela","nome":"Escama da Sentinela","categoria":"material","raridade":"raro","chance":0.5,"quantidadeMinima":1,"quantidadeMaxima":2}]
	}, [
		{"uid":"uid-global-a","nome":"Aventureiro","vida":100,"vidaMaxima":100,"ataque":20,"defesa":5,"agilidade":10},
		{"uid":"uid-global-a2","nome":"Aliado","vida":100,"vidaMaxima":100,"ataque":18,"defesa":4,"agilidade":15}
	])
	if not bool(encontro_ok.get("sucesso", false)):
		_falhar("O servidor de salas não registrou o encontro para o grupo ativo.")
		return
	var encontro_a: Dictionary = outra_sala.obter_estado_aventura(30).get("estado", {}).get("encontro", {})
	if not bool(encontro_a.get("ativo", false)) or str(encontro_a.get("nome", "")) != "Sentinela do Bosque" or int(encontro_a.get("vidaAtual", 0)) != 240:
		_falhar("O encontro não preservou os dados visuais e de vida da criatura.")
		return
	if str(encontro_a.get("idRecompensa", "")).is_empty() or int(encontro_a.get("experienciaBase", 0)) != 90 or int(encontro_a.get("dadosRecompensa", {}).get("experienciaBase", 0)) != 90:
		_falhar("O encontro não preservou o ID único e os dados necessários para calcular recompensas.")
		return
	if str(encontro_a.get("dadosRecompensa", {}).get("periodoRecompensa", "")) != "noite":
		_falhar("O encontro não preservou o período original para calcular os drops após uma reconexão.")
		return
	var drops_previstos: Array = encontro_a.get("dropsPrevistos", [])
	if drops_previstos.is_empty() or str(drops_previstos[0].get("nome", "")) != "Escama da Sentinela":
		_falhar("O encontro não publicou a prévia dos drops catalogados para a interface.")
		return
	var previa_moeda_encontrada := false
	for drop_previsto in drops_previstos:
		if str(drop_previsto.get("categoria", "")) == "moeda":
			previa_moeda_encontrada = true
	if not previa_moeda_encontrada:
		_falhar("A prévia do encontro não incluiu as moedas geradas pelo rank da criatura.")
		return
	var combate_inicial: Dictionary = encontro_a.get("combate", {})
	if str(combate_inicial.get("status", "")) != "em_andamento" or str(combate_inicial.get("participantes", [])[0].get("uid", "")) != "uid-global-a":
		_falhar("O combate compartilhado não preservou os participantes e o primeiro turno.")
		return
	var acao_inicial: Dictionary = outra_sala.executar_acao_encontro(30, "uid-global-a", "ataque", 12345)
	if not bool(acao_inicial.get("sucesso", false)):
		_falhar("O primeiro integrante não conseguiu executar sua ação no turno.")
		return
	var turno_atual: Dictionary = acao_inicial.get("estado", {}).get("encontro", {}).get("combate", {})
	if str(turno_atual.get("participantes", [])[turno_atual.get("indiceTurno", 0)].get("uid", "")) != "uid-global-a2":
		_falhar("O turno não avançou para o próximo integrante da equipe.")
		return
	if bool(outra_sala.executar_acao_encontro(30, "uid-global-a", "ataque", 12346).get("sucesso", false)):
		_falhar("O servidor aceitou uma ação fora do turno do jogador.")
		return
	if bool(outra_sala.registrar_encontro(30, {"id":"outro","nome":"Outra criatura","rank":"E","nivel":1,"vidaMaxima":10}, []).get("sucesso", false)):
		_falhar("A sala aceitou iniciar um segundo encontro enquanto o primeiro está ativo.")
		return
	if not outra_sala.obter_estado_aventura(31).get("estado", {}).is_empty():
		_falhar("O encontro de uma sala vazou para a outra.")
		return
	# Uma segunda tela ainda na revisão zero não pode sobrescrever a etapa mais recente.
	var conflito: Dictionary = outra_sala.atualizar_estado_aventura(30, {"missao":"bosque-antigo", "etapa":1}, 0)
	if bool(conflito.get("sucesso", false)) or not bool(conflito.get("conflito", false)) or int(conflito.get("revisaoAtual", 0)) != 3:
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
	if str(snapshot_a.get("codigo", "")) != "AAA234" or int(snapshot_a.get("revisao", 0)) != 4:
		_falhar("O snapshot da aventura não preservou sala e revisão.")
		return
	var snapshot_duravel: Array = outra_sala.exportar_estado_persistente()
	var servidor_reiniciado = Salas.new()
	var restauracao_duravel: Dictionary = servidor_reiniciado.restaurar_estado_persistente(snapshot_duravel)
	if not bool(restauracao_duravel.get("sucesso", false)):
		_falhar("O servidor não restaurou o arquivo de salas válido.")
		return
	var combate_antes_reconectar: Dictionary = servidor_reiniciado.obter_sala("AAA234").get("estadoAventura", {}).get("encontro", {}).get("combate", {})
	if int(combate_antes_reconectar.get("indiceTurno", 0)) != -1 or not bool(combate_antes_reconectar.get("aguardandoReconexao", false)):
		_falhar("O combate não ficou aguardando reconexão após reinício.")
		return
	for membro_offline in combate_antes_reconectar.get("participantes", []):
		if bool(membro_offline.get("conectado", true)):
			_falhar("O estado persistido manteve um participante fantasma conectado.")
			return
	var jogador_reconectado: Dictionary = servidor_reiniciado.entrar_sala(60, "uid-global-a", "AAA234")
	if not bool(jogador_reconectado.get("sucesso", false)):
		_falhar("O jogador não conseguiu reabrir sua sala após reinício.")
		return
	var aventura_reconectada: Dictionary = servidor_reiniciado.obter_estado_aventura(60)
	if int(aventura_reconectada.get("revisao", 0)) != 5 or int(aventura_reconectada.get("estado", {}).get("etapa", 0)) != 2 or not bool(aventura_reconectada.get("estado", {}).get("encontro", {}).get("ativo", false)):
		_falhar("O progresso narrativo não sobreviveu ao reinício simulado.")
		return
	if not servidor_reiniciado.obter_estado_aventura(61).is_empty():
		_falhar("A restauração expôs a aventura a um peer não autenticado na sala.")
		return
	var segundo_membro_reconectado: Dictionary = servidor_reiniciado.entrar_sala(61, "uid-global-a2", "AAA234")
	if not bool(segundo_membro_reconectado.get("sucesso", false)):
		_falhar("O segundo integrante não conseguiu retornar ao combate após o reinício.")
		return
	var combate_apos_dois_retorno: Dictionary = servidor_reiniciado.obter_estado_aventura(60).get("estado", {}).get("encontro", {}).get("combate", {})
	if int(combate_apos_dois_retorno.get("indiceTurno", -1)) != 0 or not bool(combate_apos_dois_retorno.get("participantes", [])[1].get("conectado", false)):
		_falhar("A reconexão de mais de um integrante não preservou o turno e os estados individuais.")
		return
	var restauracao_invalida = Salas.new()
	var dados_corrompidos: Dictionary = restauracao_invalida.restaurar_estado_persistente([{"codigo":"INVÁLIDO","membrosUid":[],"estadoAventura":{},"revisaoAventura":0}])
	if bool(dados_corrompidos.get("sucesso", false)) or restauracao_invalida.quantidade_salas() != 0:
		_falhar("O sistema aceitou dados persistidos de sala inválidos.")
		return
	var sala_desconexao := Salas.new()
	sala_desconexao.criar_sala(70, "uid-volta-a", "CCC234")
	sala_desconexao.entrar_sala(71, "uid-continua-b", "CCC234")
	var encontro_desconexao: Dictionary = sala_desconexao.registrar_encontro(70, {"id":"criatura_desconexao","nome":"Guardião de Teste","rank":"E","nivel":1,"vidaMaxima":100,"ataque":1}, [
		{"uid":"uid-volta-a","nome":"Retornante","vida":100,"vidaMaxima":100,"ataque":10,"defesa":2,"agilidade":5},
		{"uid":"uid-continua-b","nome":"Companheiro","vida":100,"vidaMaxima":100,"ataque":10,"defesa":2,"agilidade":5}
	])
	if not bool(encontro_desconexao.get("sucesso", false)):
		_falhar("Não foi possível preparar o encontro para testar desconexão.")
		return
	var limpeza_ativa: Dictionary = sala_desconexao.limpar_encontro(70)
	if bool(limpeza_ativa.get("sucesso", false)) or not bool(sala_desconexao.obter_estado_aventura(70).get("estado", {}).get("encontro", {}).get("ativo", false)):
		_falhar("O sistema removeu um encontro antes da conclusão da batalha.")
		return
	sala_desconexao.remover_jogador(70)
	if bool(sala_desconexao.entrar_sala(73, "uid-novo", "CCC234").get("sucesso", false)):
		_falhar("Um novo integrante entrou no meio de uma batalha em andamento.")
		return
	var matchmaking_durante_batalha: Dictionary = sala_desconexao.entrar_sala_publica(74, "uid-matchmaking")
	if not bool(matchmaking_durante_batalha.get("sucesso", false)) or str(matchmaking_durante_batalha.get("codigo", "")) == "CCC234":
		_falhar("O matchmaking público tentou colocar um novo jogador em uma batalha ativa.")
		return
	var estado_apos_saida: Dictionary = sala_desconexao.obter_estado_aventura(71).get("estado", {}).get("encontro", {}).get("combate", {})
	if int(estado_apos_saida.get("indiceTurno", -1)) != 1 or bool(estado_apos_saida.get("participantes", [])[0].get("conectado", true)):
		_falhar("A sala não pulou o turno do participante desconectado preservando seu registro.")
		return
	var retorno_combate: Dictionary = sala_desconexao.entrar_sala(72, "uid-volta-a", "CCC234")
	var estado_apos_retorno: Dictionary = retorno_combate.get("sala", {}).get("estadoAventura", {}).get("encontro", {}).get("combate", {})
	if not bool(retorno_combate.get("sucesso", false)) or not bool(estado_apos_retorno.get("participantes", [])[0].get("conectado", false)):
		_falhar("A sala não reativou a participação do jogador que retornou.")
		return
	var snapshot_limpeza: Dictionary = sala_desconexao.obter_estado_aventura(72)
	var estado_limpeza: Dictionary = snapshot_limpeza.get("estado", {}).duplicate(true)
	var encontro_limpeza: Dictionary = estado_limpeza.get("encontro", {}).duplicate(true)
	encontro_limpeza["ativo"] = false
	encontro_limpeza["resultado"] = "vitoria"
	encontro_limpeza["recompensasConcluidas"] = false
	estado_limpeza["encontro"] = encontro_limpeza
	var salvar_vitoria_pendente: Dictionary = sala_desconexao.atualizar_estado_aventura(72, estado_limpeza, int(snapshot_limpeza.get("revisao", -1)))
	if not bool(salvar_vitoria_pendente.get("sucesso", false)) or bool(sala_desconexao.limpar_encontro(72).get("sucesso", false)):
		_falhar("O sistema removeu a vitória antes de confirmar as recompensas.")
		return
	encontro_limpeza["recompensasConcluidas"] = true
	estado_limpeza["encontro"] = encontro_limpeza
	var snapshot_recompensado: Dictionary = sala_desconexao.obter_estado_aventura(72)
	var salvar_vitoria_concluida: Dictionary = sala_desconexao.atualizar_estado_aventura(72, estado_limpeza, int(snapshot_recompensado.get("revisao", -1)))
	if not bool(salvar_vitoria_concluida.get("sucesso", false)) or not bool(sala_desconexao.limpar_encontro(72).get("sucesso", false)):
		_falhar("O sistema não limpou a batalha após confirmar as recompensas.")
		return
	# A derrota coletiva também precisa concluir penalidades e restauração antes da limpeza.
	var sala_derrota := Salas.new()
	sala_derrota.criar_sala(90, "uid-derrota-a", "EEE234")
	sala_derrota.entrar_sala(91, "uid-derrota-b", "EEE234")
	var encontro_derrota: Dictionary = sala_derrota.registrar_encontro(90, {"id":"criatura_derrota","nome":"Guardião da Derrota","rank":"E","nivel":1,"vidaMaxima":50,"ataque":1}, [
		{"uid":"uid-derrota-a","nome":"Aventureiro A","vida":100,"vidaMaxima":100,"ataque":10},
		{"uid":"uid-derrota-b","nome":"Aventureiro B","vida":100,"vidaMaxima":100,"ataque":10}
	])
	if not bool(encontro_derrota.get("sucesso", false)):
		_falhar("Não foi possível preparar a sala para testar a liquidação da derrota.")
		return
	var snapshot_derrota: Dictionary = sala_derrota.obter_estado_aventura(90)
	var estado_derrota: Dictionary = snapshot_derrota.get("estado", {}).duplicate(true)
	var encontro_final_derrota: Dictionary = estado_derrota.get("encontro", {}).duplicate(true)
	encontro_final_derrota["ativo"] = false
	encontro_final_derrota["resultado"] = "derrota"
	encontro_final_derrota["recursosDerrotaConcluidos"] = false
	estado_derrota["encontro"] = encontro_final_derrota
	var salvar_derrota_pendente: Dictionary = sala_derrota.atualizar_estado_aventura(90, estado_derrota, int(snapshot_derrota.get("revisao", -1)))
	if not bool(salvar_derrota_pendente.get("sucesso", false)):
		_falhar("Não foi possível registrar a derrota coletiva pendente.")
		return
	if bool(sala_derrota.limpar_encontro(90).get("sucesso", false)):
		_falhar("O sistema removeu a derrota antes de aplicar penalidades e restaurar HP/Mana.")
		return
	var snapshot_derrota_liquidada: Dictionary = sala_derrota.obter_estado_aventura(90)
	estado_derrota = snapshot_derrota_liquidada.get("estado", {}).duplicate(true)
	encontro_final_derrota = estado_derrota.get("encontro", {}).duplicate(true)
	encontro_final_derrota["recursosDerrotaConcluidos"] = true
	estado_derrota["encontro"] = encontro_final_derrota
	var salvar_derrota_concluida: Dictionary = sala_derrota.atualizar_estado_aventura(90, estado_derrota, int(snapshot_derrota_liquidada.get("revisao", -1)))
	if not bool(salvar_derrota_concluida.get("sucesso", false)) or not bool(sala_derrota.limpar_encontro(90).get("sucesso", false)):
		_falhar("O sistema não liberou a limpeza após confirmar a liquidação da derrota.")
		return
	if bool(sala_derrota.obter_estado_aventura(90).get("estado", {}).get("encontro", {}).get("ativo", true)):
		_falhar("A limpeza confirmada não retornou a sala ao estado sem encontro ativo.")
		return
	var ovo_previsto := false
	for drop_previsto in drops_previstos:
		if str(drop_previsto.get("categoria", "")) == "ovo":
			ovo_previsto = true
	if not ovo_previsto:
		_falhar("A prévia não mostrou o ovo quando há integrantes não invocadores elegíveis.")
		return
	var sala_invocadores := Salas.new()
	sala_invocadores.criar_sala(80, "uid-invocador-a", "DDD234")
	sala_invocadores.entrar_sala(81, "uid-invocador-b", "DDD234")
	var encontro_invocadores: Dictionary = sala_invocadores.registrar_encontro(80, {"id":"criatura_sem_ovo","nome":"Guardião Arcano","rank":"E","nivel":1,"vidaMaxima":20,"ataque":1}, [
		{"uid":"uid-invocador-a","nome":"Invocador A","vida":100,"vidaMaxima":100,"ataque":10,"classeId":"invocador"},
		{"uid":"uid-invocador-b","nome":"Invocador B","vida":100,"vidaMaxima":100,"ataque":10,"classeId":"invocador"}
	])
	if not bool(encontro_invocadores.get("sucesso", false)):
		_falhar("Não foi possível preparar a prévia de uma equipe só de invocadores.")
		return
	var preview_invocadores: Array = sala_invocadores.obter_estado_aventura(80).get("estado", {}).get("encontro", {}).get("dropsPrevistos", [])
	for drop_invocador in preview_invocadores:
		if str(drop_invocador.get("categoria", "")) == "ovo":
			_falhar("A prévia anunciou ovo para uma equipe composta apenas por invocadores.")
			return
	# Um arquivo persistido não pode introduzir no combate uma conta que nunca pertenceu à sala.
	var snapshot_combat_invalido: Array = snapshot_duravel.duplicate(true)
	for registro_combate_invalido in snapshot_combat_invalido:
		if str(registro_combate_invalido.get("codigo", "")) == "AAA234":
			var estado_combate_invalido: Dictionary = registro_combate_invalido.get("estadoAventura", {}).duplicate(true)
			var encontro_combate_invalido: Dictionary = estado_combate_invalido.get("encontro", {}).duplicate(true)
			var combate_invalido: Dictionary = encontro_combate_invalido.get("combate", {}).duplicate(true)
			var participantes_invalidos: Array = combate_invalido.get("participantes", []).duplicate(true)
			if not participantes_invalidos.is_empty():
				participantes_invalidos[0]["uid"] = "uid-fora-da-sala"
			combate_invalido["participantes"] = participantes_invalidos
			encontro_combate_invalido["combate"] = combate_invalido
			estado_combate_invalido["encontro"] = encontro_combate_invalido
			registro_combate_invalido["estadoAventura"] = estado_combate_invalido
	var restauracao_combate_invalido = Salas.new()
	var resultado_combate_invalido: Dictionary = restauracao_combate_invalido.restaurar_estado_persistente(snapshot_combat_invalido)
	if bool(resultado_combate_invalido.get("sucesso", false)) or restauracao_combate_invalido.quantidade_salas() != 0:
		_falhar("A restauração aceitou um participante de combate que não pertence ao histórico da sala.")
		return
	print("TESTE DE SALAS MULTIPLAYER: isolamento, revisão, desconexão e reconexão aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE SALAS MULTIPLAYER: " + mensagem)
	quit(1)
