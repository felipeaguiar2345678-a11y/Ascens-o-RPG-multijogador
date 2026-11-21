extends SceneTree

const Evolucao = preload("res://scripts/sistema_evolucao_criaturas.gd")

func _initialize() -> void:
	var agora := 2000000000
	var criatura := {
		"id":"fera_persistente_ci",
		"vidaMaxima":1000,"ataque":100,"defesa":80,
		"manaMaxima":200,"agilidade":60,"poderMagico":50
	}
	criatura = Evolucao.preparar(criatura, agora)
	var original_ataque := int(criatura["ataque"])
	var primeira_vitoria := Evolucao.registrar_vitoria(criatura, "jogador_a", agora + 10)
	if not bool(primeira_vitoria.get("ok", false)):
		_falhar("Não registrou vitória da criatura sobre o jogador.")
		return
	criatura = primeira_vitoria["criatura"]
	if int(criatura["evolucao"]["vitoriasSobreJogadores"]) != 1:
		_falhar("Não guardou o histórico de vitórias sobre jogadores.")
		return
	if not (criatura["evolucao"]["jogadoresDerrotados"] as Array).has("jogador_a"):
		_falhar("Não identificou o jogador derrotado.")
		return
	var depois_de_um_dia := Evolucao.aplicar_tempo(criatura, agora + 86400)
	if not bool(depois_de_um_dia.get("alterou", false)):
		_falhar("A criatura não evoluiu após um dia.")
		return
	criatura = depois_de_um_dia["criatura"]
	if int(criatura["ataque"]) <= original_ataque:
		_falhar("Os atributos não aumentaram com a evolução temporal.")
		return
	var sem_repetir := Evolucao.aplicar_tempo(criatura, agora + 86400)
	if bool(sem_repetir.get("alterou", true)):
		_falhar("Aplicou a mesma evolução temporal duas vezes.")
		return
	for i in range(14):
		var resultado := Evolucao.registrar_vitoria(criatura, "jogador_%d" % i, agora + 86400)
		criatura = resultado["criatura"]
	if (criatura["evolucao"]["mutacoes"] as Array).is_empty():
		_falhar("Não gerou mutação após vitórias suficientes.")
		return
	var mutacoes_antes := (criatura["evolucao"]["mutacoes"] as Array).size()
	for i in range(100):
		var resultado := Evolucao.registrar_vitoria(criatura, "outro_%d" % i, agora + 86400)
		criatura = resultado["criatura"]
	if (criatura["evolucao"]["mutacoes"] as Array).size() > Evolucao.MAX_MUTACOES:
		_falhar("Ultrapassou o limite de mutações.")
		return
	var limite := Evolucao.aplicar_tempo(criatura, agora + 365 * 86400)
	criatura = limite["criatura"]
	if int(criatura["evolucao"]["diasAplicados"]) > Evolucao.MAX_DIAS_EVOLUCAO:
		_falhar("A evolução temporal ultrapassou o limite configurado.")
		return
	print("TESTE DE EVOLUÇÃO PERSISTENTE DE CRIATURAS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE EVOLUÇÃO PERSISTENTE DE CRIATURAS: " + mensagem)
	quit(1)
