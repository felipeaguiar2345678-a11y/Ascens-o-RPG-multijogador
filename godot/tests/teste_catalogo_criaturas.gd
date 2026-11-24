extends SceneTree

const RepositorioCriaturas = preload("res://scripts/repositorio_criaturas_servidor.gd")

func _initialize() -> void:
	var caminho := "user://teste_criaturas_%s.json" % str(Time.get_ticks_usec())
	var repositorio = RepositorioCriaturas.new(caminho)
	var criatura := {
		"id":"criatura_ci_unica",
		"nome":"Guardião de Cinzas",
		"descricao":"Uma criatura gerada para validar o catálogo global.",
		"rank":"A",
		"raridade":"lendario",
		"nivel":42,
		"vidaMaxima":1800,
		"ataque":95,
		"defesa":60,
		"manaMaxima":120,
		"agilidade":75,
		"poderMagico":110,
		"experienciaBase":450,
		"perigo":78,
		"ecossistemaId":"floresta_arcana",
		"bioma":"bosque_queimado",
		"habitat":"ruinas_soterradas",
		"imagemId":"visual_guardiao_cinzas",
		"iconePath":"user://criaturas/icone.png",
		"detalhePath":"user://criaturas/detalhe.png",
		"habilidades":[{"id":"brasa_viva","nome":"Brasa Viva"}],
		"chefe":true,
		"tabelaDrops":[{"itemId":"cinza_teste","nome":"Cinza","raridade":"comum","chance":0.5}]
	}
	if not repositorio.validar_criatura(criatura):
		_falhar("Rejeitou uma criatura gerada com dados válidos.")
		return
	var registro := repositorio.registrar_criatura_gerada(criatura)
	if not bool(registro.get("ok", false)):
		_falhar("Não registrou a criatura gerada.")
		return
	if repositorio.registrar_criatura_gerada(criatura).get("ok", false):
		_falhar("Permitiu registrar duas criaturas com o mesmo ID.")
		return
	var carregada := repositorio.obter_criatura("criatura_ci_unica")
	if str(carregada.get("nome", "")) != "Guardião de Cinzas" or int(carregada.get("totalDerrotas", -1)) != 0:
		_falhar("Não recuperou os dados globais da criatura.")
		return
	var descoberta_a := repositorio.registrar_descoberta("jogador_ci_a", "criatura_ci_unica")
	var descoberta_repetida := repositorio.registrar_descoberta("jogador_ci_a", "criatura_ci_unica")
	var descoberta_b := repositorio.registrar_descoberta("jogador_ci_b", "criatura_ci_unica")
	if not bool(descoberta_a.get("novaDescoberta", false)) or bool(descoberta_repetida.get("novaDescoberta", true)) or not bool(descoberta_b.get("novaDescoberta", false)):
		_falhar("Não controlou a descoberta individual e global.")
		return
	var estatisticas := repositorio.obter_estatisticas("criatura_ci_unica")
	if int(estatisticas.get("totalDescobertas", 0)) != 2 or str(estatisticas.get("primeiroDescobridorUid", "")) != "jogador_ci_a":
		_falhar("Não registrou primeiro descobridor e total global.")
		return
	if not repositorio.registrar_derrota("jogador_ci_b", "criatura_ci_unica").get("ok", false):
		_falhar("Não registrou a primeira derrota.")
		return
	repositorio.registrar_derrota("jogador_ci_b", "criatura_ci_unica")
	estatisticas = repositorio.obter_estatisticas("criatura_ci_unica")
	if int(estatisticas.get("totalDerrotas", 0)) != 2 or int(estatisticas.get("derrotasPorJogador", {}).get("jogador_ci_b", 0)) != 2:
		_falhar("Não acumulou as derrotas globais e individuais.")
	if str(estatisticas.get("primeiroDerrotadorUid", "")) != "jogador_ci_b":
		_falhar("Não guardou o primeiro derrotador.")
		return
	var derrota_individual := repositorio.registrar_derrota_individuo("jogador_ci_b", "criatura_ci_unica", "grupo-lobo:individuo-001")
	var derrota_individual_repetida := repositorio.registrar_derrota_individuo("jogador_ci_b", "criatura_ci_unica", "grupo-lobo:individuo-001")
	var segunda_derrota_individual := repositorio.registrar_derrota_individuo("jogador_ci_a", "criatura_ci_unica", "grupo-lobo:individuo-002")
	if not bool(derrota_individual.get("ok", false)) or bool(derrota_individual.get("duplicado", true)):
		_falhar("Não registrou a primeira derrota com identidade individual.")
		return
	if not bool(derrota_individual_repetida.get("ok", false)) or not bool(derrota_individual_repetida.get("duplicado", false)):
		_falhar("Uma tentativa retomada duplicou a derrota do mesmo indivíduo.")
		return
	if not bool(segunda_derrota_individual.get("ok", false)):
		_falhar("Não registrou a derrota de um segundo indivíduo da mesma espécie.")
		return
	estatisticas = repositorio.obter_estatisticas("criatura_ci_unica")
	if int(estatisticas.get("totalDerrotas", 0)) != 4 or int(estatisticas.get("derrotasPorJogador", {}).get("jogador_ci_b", 0)) != 3 or int(estatisticas.get("derrotasPorJogador", {}).get("jogador_ci_a", 0)) != 1:
		_falhar("O registro idempotente não preservou a contagem global e por jogador.")
		return
	var invalida := criatura.duplicate(true)
	invalida["rank"] = "Z"
	if repositorio.validar_criatura(invalida):
		_falhar("Aceitou rank inexistente.")
		return
	invalida = criatura.duplicate(true)
	invalida["ecossistemaId"] = "bioma_inventado"
	if repositorio.validar_criatura(invalida):
		_falhar("Aceitou ecossistema fora da lista oficial.")
		return
	var derrota_do_jogador := repositorio.registrar_vitoria_sobre_jogador("jogador_ci_a", "criatura_ci_unica")
	if not bool(derrota_do_jogador.get("ok", false)):
		_falhar("Não persistiu a vitória da criatura sobre o jogador.")
		return
	carregada = repositorio.obter_criatura("criatura_ci_unica")
	if int(carregada.get("evolucao", {}).get("vitoriasSobreJogadores", 0)) != 1:
		_falhar("Não persistiu o estado evolutivo da criatura sobrevivente.")
		return
	print("TESTE DE CATÁLOGO DE CRIATURAS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE CATÁLOGO DE CRIATURAS: " + mensagem)
	quit(1)
