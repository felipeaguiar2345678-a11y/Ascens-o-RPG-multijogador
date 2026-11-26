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
	var fila_balanceada = Salas.new()
	fila_balanceada.criar_sala(60, "uid-fila-a", "FILA01")
	fila_balanceada.criar_sala(61, "uid-fila-b", "FILA02")
	fila_balanceada.entrar_sala(62, "uid-fila-a2", "FILA01")
	var entrada_fila: Dictionary = fila_balanceada.entrar_sala_publica(63, "uid-fila-c")
	if not bool(entrada_fila.get("sucesso", false)) or str(entrada_fila.get("codigo", "")) != "FILA01":
		_falhar("A fila pública não priorizou a sala disponível mais cheia para completar uma equipe.")
		return
	if (fila_balanceada.obter_sala("FILA01").get("jogadores", []) as Array).size() != 3 or (fila_balanceada.obter_sala("FILA02").get("jogadores", []) as Array).size() != 1:
		_falhar("O matchmaking espalhou jogadores entre salas quando poderia completar uma equipe existente.")
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
	# Um encontro marcado como ativo não pode ser restaurado sem um combate válido.
	var snapshot_sem_combate: Array = snapshot_duravel.duplicate(true)
	for registro_sem_combate in snapshot_sem_combate:
		if str(registro_sem_combate.get("codigo", "")) == "AAA234":
			var estado_sem_combate: Dictionary = registro_sem_combate.get("estadoAventura", {}).duplicate(true)
			var encontro_sem_combate: Dictionary = estado_sem_combate.get("encontro", {}).duplicate(true)
			encontro_sem_combate.erase("combate")
			estado_sem_combate["encontro"] = encontro_sem_combate
			registro_sem_combate["estadoAventura"] = estado_sem_combate
	var restauracao_sem_combate = Salas.new()
	var resultado_sem_combate: Dictionary = restauracao_sem_combate.restaurar_estado_persistente(snapshot_sem_combate)
	if bool(resultado_sem_combate.get("sucesso", false)) or restauracao_sem_combate.quantidade_salas() != 0:
		_falhar("A restauração aceitou um encontro ativo sem estado de combate.")
		return
	# Campos aninhados corrompidos devem ser rejeitados sem provocar erro de tipo.
	var snapshot_encontro_corrompido: Array = snapshot_duravel.duplicate(true)
	for registro_encontro_corrompido in snapshot_encontro_corrompido:
		if str(registro_encontro_corrompido.get("codigo", "")) == "AAA234":
			var estado_encontro_corrompido: Dictionary = registro_encontro_corrompido.get("estadoAventura", {}).duplicate(true)
			estado_encontro_corrompido["encontro"] = "dados-corrompidos"
			registro_encontro_corrompido["estadoAventura"] = estado_encontro_corrompido
	var restauracao_encontro_corrompido = Salas.new()
	var resultado_encontro_corrompido: Dictionary = restauracao_encontro_corrompido.restaurar_estado_persistente(snapshot_encontro_corrompido)
	if bool(resultado_encontro_corrompido.get("sucesso", false)) or restauracao_encontro_corrompido.quantidade_salas() != 0:
		_falhar("A restauração aceitou um encontro persistido com formato inválido.")
		return
	var snapshot_historico_corrompido: Array = snapshot_duravel.duplicate(true)
	for registro_historico_corrompido in snapshot_historico_corrompido:
		if str(registro_historico_corrompido.get("codigo", "")) == "AAA234":
			var estado_historico_corrompido: Dictionary = registro_historico_corrompido.get("estadoAventura", {}).duplicate(true)
			var encontro_historico_corrompido: Dictionary = estado_historico_corrompido.get("encontro", {}).duplicate(true)
			var combate_historico_corrompido: Dictionary = encontro_historico_corrompido.get("combate", {}).duplicate(true)
			combate_historico_corrompido["historico"] = "nao-e-uma-lista"
			encontro_historico_corrompido["combate"] = combate_historico_corrompido
			estado_historico_corrompido["encontro"] = encontro_historico_corrompido
			registro_historico_corrompido["estadoAventura"] = estado_historico_corrompido
	var restauracao_historico_corrompido = Salas.new()
	var resultado_historico_corrompido: Dictionary = restauracao_historico_corrompido.restaurar_estado_persistente(snapshot_historico_corrompido)
	if bool(resultado_historico_corrompido.get("sucesso", false)) or restauracao_historico_corrompido.quantidade_salas() != 0:
		_falhar("A restauração aceitou um histórico de combate com formato inválido.")
		return
	# Integrantes distantes permanecem na sala, mas não precisam entrar no combate.
	var sala_subconjunto = Salas.new()
	if not bool(sala_subconjunto.criar_sala(70, "uid-proximo-a", "SUB234").get("sucesso", false)):
		_falhar("Não foi possível preparar a sala para validar participantes próximos.")
		return
	if not bool(sala_subconjunto.entrar_sala(71, "uid-proximo-b", "SUB234").get("sucesso", false)) or not bool(sala_subconjunto.entrar_sala(72, "uid-distante", "SUB234").get("sucesso", false)):
		_falhar("Não foi possível adicionar os três integrantes da sala de teste.")
		return
	var criatura_subconjunto := {"id":"criatura-teste","nome":"Guardião de Teste","rank":"E","nivel":1,"vidaMaxima":40,"ataque":4,"defesa":1,"experienciaBase":20,"tabelaDrops":[]}
	var participantes_subconjunto := [
		{"uid":"uid-proximo-a","nome":"Aventureiro A","vida":30,"vidaMaxima":30,"ataque":8,"defesa":2},
		{"uid":"uid-proximo-b","nome":"Aventureiro B","vida":30,"vidaMaxima":30,"ataque":8,"defesa":2}
	]
	var encontro_subconjunto: Dictionary = sala_subconjunto.registrar_encontro(70, criatura_subconjunto, participantes_subconjunto)
	if not bool(encontro_subconjunto.get("sucesso", false)):
		_falhar("A sala recusou um encontro válido com dois integrantes próximos e um integrante distante.")
		return
	var snapshot_subconjunto: Dictionary = sala_subconjunto.obter_estado_aventura(70)
	var combate_subconjunto: Dictionary = snapshot_subconjunto.get("estado", {}).get("encontro", {}).get("combate", {})
	if (combate_subconjunto.get("participantes", []) as Array).size() != 2:
		_falhar("O combate incluiu um integrante que não foi selecionado como participante próximo.")
		return
	var sala_grupo = Salas.new()
	if not bool(sala_grupo.criar_sala(100, "uid-grupo-a", "GRP234").get("sucesso", false)) or not bool(sala_grupo.entrar_sala(101, "uid-grupo-b", "GRP234").get("sucesso", false)):
		_falhar("Não foi possível criar uma Ally para o encontro com três criaturas.")
		return
	var criaturas_grupo := [
		{"id":"especie_lobo","especieId":"especie_lobo","individuoId":"lobo-01","grupoId":"grupo-lobos","nome":"Lobo jovem","rank":"E","nivel":1,"vidaMaxima":20,"ataque":2,"defesa":0,"experienciaBase":10,"tabelaDrops":[{"itemId":"dente_lobo","nome":"Dente de lobo","categoria":"material","raridade":"comum","chance":1.0}]},
		{"id":"especie_lobo","especieId":"especie_lobo","individuoId":"lobo-02","grupoId":"grupo-lobos","nome":"Lobo caçador","rank":"D","nivel":2,"vidaMaxima":30,"ataque":3,"defesa":1,"experienciaBase":20,"tabelaDrops":[{"itemId":"pele_lobo","nome":"Pele de lobo","categoria":"material","raridade":"comum","chance":1.0}]},
		{"id":"especie_lobo","especieId":"especie_lobo","individuoId":"lobo-03","grupoId":"grupo-lobos","nome":"Lobo líder","rank":"C","nivel":3,"vidaMaxima":40,"ataque":4,"defesa":2,"experienciaBase":30,"tabelaDrops":[{"itemId":"presa_lobo","nome":"Presa do líder","categoria":"material","raridade":"raro","chance":1.0}]}
	]
	var encontro_grupo: Dictionary = sala_grupo.registrar_encontro(100, {"id":"especie_lobo","nome":"Lobo jovem","rank":"E","nivel":1,"vidaMaxima":20,"ataque":2,"defesa":0,"experienciaBase":60,"inimigos":criaturas_grupo}, [
		{"uid":"uid-grupo-a","nome":"Aventureiro A","vida":100,"vidaMaxima":100,"ataque":1000,"defesa":10,"agilidade":10},
		{"uid":"uid-grupo-b","nome":"Aventureiro B","vida":100,"vidaMaxima":100,"ataque":1000,"defesa":10,"agilidade":10}
	])
	if not bool(encontro_grupo.get("sucesso", false)):
		_falhar("A sala recusou o encontro cooperativo contra três indivíduos.")
		return
	var snapshot_grupo: Dictionary = sala_grupo.obter_estado_aventura(100)
	var encontro_grupo_salvo: Dictionary = snapshot_grupo.get("estado", {}).get("encontro", {})
	var combate_grupo: Dictionary = encontro_grupo_salvo.get("combate", {})
	if (combate_grupo.get("inimigos", []) as Array).size() != 3:
		_falhar("O estado compartilhado não preservou as três criaturas do grupo.")
		return
	if int(encontro_grupo_salvo.get("experienciaBase", 0)) != 60:
		_falhar("A experiência do grupo não foi somada a partir dos indivíduos.")
		return
	var drops_grupo: Array = encontro_grupo_salvo.get("dropsPrevistos", [])
	var nomes_drops_grupo: Array[String] = []
	for drop_grupo in drops_grupo:
		nomes_drops_grupo.append(str(drop_grupo.get("nome", "")))
	if not nomes_drops_grupo.has("Dente de lobo") or not nomes_drops_grupo.has("Pele de lobo") or not nomes_drops_grupo.has("Presa do líder"):
		_falhar("A prévia de recompensas não incluiu os drops dos três indivíduos.")
		return
	var acao_alvo_grupo: Dictionary = sala_grupo.executar_acao_encontro(100, "uid-grupo-a", "ataque", 4321, "lobo-03")
	if not bool(acao_alvo_grupo.get("sucesso", false)):
		_falhar("O servidor de salas não aceitou o alvo individual selecionado.")
		return
	var estado_alvo_grupo: Dictionary = acao_alvo_grupo.get("estado", {}).get("encontro", {}).get("combate", {})
	if str(estado_alvo_grupo.get("status", "")) != "em_andamento" or int(estado_alvo_grupo.get("inimigos", [])[2].get("vida", 1)) != 0:
		_falhar("O alvo escolhido não foi atingido sem encerrar a luta contra os outros indivíduos.")
		return
	if str(estado_alvo_grupo.get("alvoSelecionadoId", "")) == "lobo-03":
		_falhar("O alvo compartilhado permaneceu apontando para uma criatura derrotada.")
		return
	print("TESTE DE SALAS MULTIPLAYER: isolamento, revisão, desconexão, reconexão e participantes próximos aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE SALAS MULTIPLAYER: " + mensagem)
	quit(1)
