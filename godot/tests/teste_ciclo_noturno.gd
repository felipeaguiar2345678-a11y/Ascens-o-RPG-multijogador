extends SceneTree

const Ciclo = preload("res://scripts/sistema_ciclo_noturno.gd")

func _initialize() -> void:
	if Ciclo.periodo_por_hora(12) != "dia":
		_falhar("Meio-dia deve ser diurno.")
		return
	if Ciclo.periodo_por_hora(19) != "crepusculo":
		_falhar("19h deve ser crepúsculo.")
		return
	if Ciclo.periodo_por_hora(23) != "noite" or Ciclo.periodo_por_hora(3) != "noite":
		_falhar("A noite deve atravessar a meia-noite.")
		return
	var exclusiva := {"id":"fera_lunar","exclusivaNoturna":true,"vidaMaxima":100,"ataque":20,"defesa":10,"manaMaxima":30,"agilidade":12,"poderMagico":8}
	if Ciclo.criatura_disponivel(exclusiva, "dia"):
		_falhar("Criatura exclusiva noturna apareceu durante o dia.")
		return
	var ajustada := Ciclo.preparar_criatura_para_periodo(exclusiva, "noite")
	if int(ajustada.get("ataque", 0)) != 30 or int(ajustada.get("vidaMaxima", 0)) != 150:
		_falhar("Atributos noturnos não receberam multiplicador 1,5x.")
		return
	var duplicada := Ciclo.preparar_criatura_para_periodo(ajustada, "noite")
	if int(duplicada.get("ataque", 0)) != 30:
		_falhar("Multiplicador noturno foi aplicado mais de uma vez.")
		return
	if Ciclo.calcular_experiencia(100, "noite") != 150 or Ciclo.calcular_experiencia(100, "dia") != 100:
		_falhar("Cálculo de XP por período incorreto.")
		return
	if Ciclo.fase_lunar_por_dia(14) != "lua_cheia":
		_falhar("O calendário lunar não identificou a lua cheia.")
		return
	var sangue := Ciclo.evento_celeste_por_dia(42)
	if sangue.get("id") != "lua_de_sangue" or float(sangue.get("multiplicadorXP", 0.0)) != 1.5:
		_falhar("A lua de sangue não entregou seus modificadores.")
		return
	var eclipse := Ciclo.evento_celeste_por_dia(56)
	if eclipse.get("id") != "eclipse" or float(eclipse.get("multiplicadorAparicao", 0.0)) <= 1.5:
		_falhar("O eclipse não foi identificado como evento lendário.")
		return
	var azul := Ciclo.evento_celeste_por_dia(70)
	if azul.get("id") != "lua_azul" or azul.get("criaturas") != "arcanas":
		_falhar("A lua azul não habilitou o tema de criaturas arcanas.")
		return
	var contexto := Ciclo.criar_contexto(23, 42)
	if contexto.get("faseLunar") != "lua_gibosa_minguante" or contexto.get("eventoCeleste", {}).get("id") != "lua_de_sangue":
		_falhar("O contexto não combinou horário, fase lunar e evento.")
		return
	print("TESTE DO CICLO NOTURNO E EVENTOS CELESTES: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DO CICLO NOTURNO: " + mensagem)
	quit(1)
