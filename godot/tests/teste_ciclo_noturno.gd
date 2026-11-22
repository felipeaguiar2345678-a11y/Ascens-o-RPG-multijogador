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
	var mesmo_sorteio_a := Ciclo.evento_celeste_por_dia(42, 987654)
	var mesmo_sorteio_b := Ciclo.evento_celeste_por_dia(42, 987654)
	if mesmo_sorteio_a != mesmo_sorteio_b:
		_falhar("O mesmo mundo e dia precisam compartilhar o mesmo sorteio.")
		return
	var encontrou_combinacao := false
	var encontrou_sangue := false
	for semente in range(1, 20000):
		var evento := Ciclo.evento_celeste_por_dia(42, semente)
		if bool(evento.get("combinado", false)):
			encontrou_combinacao = true
			if evento.get("quantidadeFenomenos", 0) >= 2 and evento.get("multiplicadorXP", 1.0) <= 2.5:
				encontrou_sangue = true
				break
	if not encontrou_combinacao or not encontrou_sangue:
		_falhar("O sistema não produziu combinações celestes ou respeitou os limites.")
		return
	var vazio := Ciclo.evento_celeste_por_dia(42, 0)
	if not vazio.has("eventos") or float(vazio.get("multiplicadorDrop", 0.0)) < 1.0:
		_falhar("O céu comum não retornou contexto consistente.")
		return
	var contexto := Ciclo.criar_contexto(23, 42, 987654)
	if contexto.get("faseLunar") != "lua_gibosa_minguante" or not contexto.has("eventoCeleste"):
		_falhar("O contexto não combinou horário, fase lunar e evento.")
		return
	var contexto_especial: Dictionary = {}
	for semente_anuncio in range(1, 20000):
		contexto_especial = Ciclo.criar_contexto(20, 42, semente_anuncio)
		if str(contexto_especial.get("eventoCeleste", {}).get("id", "nenhum")) != "nenhum":
			break
	var anuncio := Ciclo.criar_anuncio_inicio_noite(contexto_especial, "dia")
	if not bool(anuncio.get("deveAnunciar", false)) or str(anuncio.get("titulo", "")).is_empty() or str(anuncio.get("mensagem", "")).is_empty():
		_falhar("O início de uma noite especial precisa gerar título e anúncio narrativo.")
		return
	var repetido := Ciclo.criar_anuncio_inicio_noite(contexto_especial, "noite")
	if bool(repetido.get("deveAnunciar", false)):
		_falhar("O anúncio não pode se repetir durante a mesma noite.")
		return
	print("TESTE DO CICLO NOTURNO E EVENTOS CELESTES: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DO CICLO NOTURNO: " + mensagem)
	quit(1)
