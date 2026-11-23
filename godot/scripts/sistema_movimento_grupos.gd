extends RefCounted
## Movimento determinístico e limitado dos indivíduos de um grupo selvagem.
## A função não causa dano nem inventa relações de caça: apenas desloca membros.
static func avancar(grupo: Dictionary, delta_segundos: float, semente: int) -> Dictionary:
	if delta_segundos <= 0.0 or delta_segundos > 5.0:
		return {"ok":false,"erro":"Intervalo de movimento inválido."}
	var territorio: Dictionary = grupo.get("territorio", {})
	var centro_dados: Dictionary = territorio.get("centro", {})
	var centro := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
	var raio := float(territorio.get("raio", 0.0))
	if centro.x < 0.0 or centro.y < 0.0 or raio <= 0.0 or raio > 1000.0:
		return {"ok":false,"erro":"Território do grupo inválido."}
	var individuos: Array = grupo.get("individuos", [])
	if individuos.size() > 500:
		return {"ok":false,"erro":"Grupo excede o limite seguro de indivíduos."}
	var copia := grupo.duplicate(true)
	var membros: Array = copia.get("individuos", [])
	var lider_id := str(copia.get("liderAtual", {}).get("individuoId", ""))
	var posicoes_vivas: Array[Vector2] = []
	for individuo in membros:
		if individuo is Dictionary and bool(individuo.get("vivo", true)):
			var p: Dictionary = individuo.get("posicaoMundo", {})
			posicoes_vivas.append(Vector2(float(p.get("x", centro.x)), float(p.get("y", centro.y))))
	var centro_grupo := centro
	if not posicoes_vivas.is_empty():
		centro_grupo = Vector2.ZERO
		for p in posicoes_vivas:
			centro_grupo += p
		centro_grupo /= float(posicoes_vivas.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var atualizacoes: Array = []
	var formacao: Dictionary = copia.get("formacaoTatica", {})
	var formacao_ativa := not formacao.is_empty() and int(formacao.get("expiraUnix", 0)) >= int(Time.get_unix_time_from_system())
	if not formacao_ativa:
		copia.erase("formacaoTatica")
	var tipo_formacao := str(formacao.get("tipo", ""))
	var centro_ameaca_dados: Dictionary = formacao.get("centroAmeaca", formacao.get("centroAlvo", {}))
	var centro_ameaca := Vector2(float(centro_ameaca_dados.get("x", centro_grupo.x)), float(centro_ameaca_dados.get("y", centro_grupo.y)))
	var quantidade_vivos := posicoes_vivas.size()
	var indice_vivo := 0
	var formacao_concluida := true
	for i in range(membros.size()):
		var individuo: Dictionary = membros[i]
		if not bool(individuo.get("vivo", true)):
			continue
		var p_dados: Dictionary = individuo.get("posicaoMundo", {})
		var posicao := Vector2(float(p_dados.get("x", centro.x)), float(p_dados.get("y", centro.y)))
		var e_lider := str(individuo.get("individuoId", "")) == lider_id
		var alvo := posicao
		var comportamento := "acompanhando_grupo"
		if formacao_ativa and tipo_formacao in ["cerco", "aproximacao_furtiva"]:
			var angulo := TAU * float(indice_vivo) / float(maxi(1, quantidade_vivos))
			var raio_formacao := clampf(float(formacao.get("raio", 34.0)), 18.0, 90.0)
			alvo = centro_ameaca + Vector2.RIGHT.rotated(angulo) * raio_formacao
			comportamento = "formando_cerco" if tipo_formacao == "cerco" else "aproximando_furtivamente"
		elif formacao_ativa and tipo_formacao == "defesa":
			if e_lider:
				alvo = centro_grupo
				comportamento = "protegendo_formacao"
			else:
				var direcao_ameaca := (centro_ameaca - centro_grupo).normalized()
				var quantidade_na_formacao := maxi(1, quantidade_vivos - (1 if not lider_id.is_empty() else 0))
				var indice_defensor := indice_vivo - (1 if not lider_id.is_empty() else 0)
				var angulo_defesa := direcao_ameaca.angle() + PI + TAU * float(maxi(0, indice_defensor)) / float(quantidade_na_formacao)
				alvo = centro_grupo + Vector2.RIGHT.rotated(angulo_defesa) * clampf(float(formacao.get("raio", 24.0)), 12.0, 55.0)
				comportamento = "protegendo_formacao"
		elif e_lider:
			comportamento = "protegendo_grupo"
			if posicao.distance_to(centro) > raio * 0.55 or posicao.distance_to(centro_grupo) > 65.0:
				alvo = centro_grupo
			elif rng.randf() < 0.18:
				alvo = centro + Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(12.0, minf(55.0, raio * 0.45))
		elif posicao.distance_to(centro_grupo) > 70.0:
			alvo = centro_grupo + Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, 24.0)
		elif rng.randf() < 0.12:
			alvo = posicao + Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(8.0, 28.0)
		var limite := maxf(8.0, raio - 5.0)
		var do_centro := alvo - centro
		if do_centro.length() > limite:
			alvo = centro + do_centro.normalized() * limite
		var deslocamento := alvo - posicao
		if formacao_ativa and deslocamento.length() > 6.0:
			formacao_concluida = false
		var velocidade_formacao := 8.0 if tipo_formacao == "aproximacao_furtiva" else 24.0 if formacao_ativa else 18.0
		var passo := velocidade_formacao * delta_segundos
		if deslocamento.length() > passo and passo > 0.0:
			posicao += deslocamento.normalized() * passo
		else:
			posicao = alvo
		var do_centro_pos := posicao - centro
		if do_centro_pos.length() > limite:
			posicao = centro + do_centro_pos.normalized() * limite
		individuo["posicaoMundo"] = {"x":posicao.x,"y":posicao.y}
		individuo["estadoMundo"] = comportamento
		membros[i] = individuo
		atualizacoes.append({"individuoId":str(individuo.get("individuoId", "")),"posicao":posicao,"comportamento":comportamento,"lider":e_lider})
		indice_vivo += 1
	copia["individuos"] = membros
	if formacao_ativa:
		var formacao_atualizada := formacao.duplicate(true)
		formacao_atualizada["concluida"] = formacao_concluida
		copia["formacaoTatica"] = formacao_atualizada
	copia["atualizadoUnix"] = int(Time.get_unix_time_from_system())
	return {"ok":true,"grupo":copia,"atualizacoes":atualizacoes}

static func posicao_dentro_do_territorio(grupo: Dictionary, posicao: Vector2) -> bool:
	var territorio: Dictionary = grupo.get("territorio", {})
	var centro_dados: Dictionary = territorio.get("centro", {})
	var centro := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
	var raio := float(territorio.get("raio", 0.0))
	return centro.x >= 0.0 and centro.y >= 0.0 and raio > 0.0 and posicao.distance_to(centro) <= raio + 0.01
