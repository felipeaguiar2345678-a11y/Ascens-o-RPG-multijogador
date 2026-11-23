extends RefCounted
## Aliados próximos podem proteger um grupo sob ataque sem criar dano ou recursos do nada.
const DISTANCIA_PROTECAO := 42.0
const REDUCAO_DANO := 0.25

static func avaliar_intervencao(grupo_defendido: Dictionary, grupos: Array, individuo_ameacado: Dictionary) -> Dictionary:
	var id_defendido := str(grupo_defendido.get("grupoId", ""))
	var ecossistema := str(grupo_defendido.get("ecossistemaId", ""))
	var posicao_dados = individuo_ameacado.get("posicaoMundo", {})
	if not (posicao_dados is Dictionary):
		return {"interveio":false}
	var posicao := Vector2(float(posicao_dados.get("x", -9999.0)), float(posicao_dados.get("y", -9999.0)))
	if id_defendido.is_empty() or ecossistema.is_empty() or not _posicao_valida(posicao):
		return {"interveio":false}
	var relacoes: Dictionary = grupo_defendido.get("relacoesGrupos", {})
	var melhor_pontuacao := INF
	var melhor_grupo := ""
	var melhor_individuo := ""
	var atributos_alvo: Dictionary = individuo_ameacado.get("atributos", {})
	var vida_maxima_alvo := maxf(1.0, float(atributos_alvo.get("vidaMaxima", 1.0)))
	var proteger := str(individuo_ameacado.get("faseVida", "")) == "filhote" or float(individuo_ameacado.get("vidaAtual", vida_maxima_alvo)) / vida_maxima_alvo <= 0.55
	if proteger:
		for protetor in grupo_defendido.get("individuos", []):
			if not bool(protetor.get("vivo", false)) or str(protetor.get("individuoId", "")) == str(individuo_ameacado.get("individuoId", "")):
				continue
			var pp = protetor.get("posicaoMundo", {})
			if not (pp is Dictionary):
				continue
			var pos_protetor := Vector2(float(pp.get("x", -9999.0)), float(pp.get("y", -9999.0)))
			if not _posicao_valida(pos_protetor):
				continue
			var distancia_protetor := posicao.distance_to(pos_protetor)
			if distancia_protetor > DISTANCIA_PROTECAO:
				continue
			var afinidade := _afinidade_social(protetor, id_defendido, str(individuo_ameacado.get("individuoId", "")))
			var pontuacao_protecao := distancia_protetor - afinidade * 18.0
			if pontuacao_protecao < melhor_pontuacao:
				melhor_pontuacao = pontuacao_protecao
				melhor_grupo = id_defendido
				melhor_individuo = str(protetor.get("individuoId", ""))"
	for aliado in grupos:
		if not (aliado is Dictionary):
			continue
		var aliado_id := str(aliado.get("grupoId", ""))
		if aliado_id.is_empty() or aliado_id == id_defendido or str(aliado.get("ecossistemaId", "")) != ecossistema:
			continue
		var relacao: Dictionary = relacoes.get(aliado_id, {})
		if str(relacao.get("estado", "")) != "aliado" or float(relacao.get("confianca", 0.0)) < 0.50:
			continue
		for membro in aliado.get("individuos", []):
			if not bool(membro.get("vivo", false)):
				continue
			var membro_pos = membro.get("posicaoMundo", {})
			if not (membro_pos is Dictionary):
				continue
			var pos_membro := Vector2(float(membro_pos.get("x", -9999.0)), float(membro_pos.get("y", -9999.0)))
			if not _posicao_valida(pos_membro):
				continue
			var distancia := posicao.distance_to(pos_membro)
			if distancia > DISTANCIA_PROTECAO:
				continue
			var afinidade_aliada := _afinidade_social(membro, id_defendido, str(individuo_ameacado.get("individuoId", "")))
			var pontuacao_aliada := distancia - afinidade_aliada * 18.0
			if pontuacao_aliada < melhor_pontuacao:
				melhor_pontuacao = pontuacao_aliada
				melhor_grupo = aliado_id
				melhor_individuo = str(membro.get("individuoId", ""))
	if melhor_grupo.is_empty():
		return {"interveio":false}
	return {"interveio":true,"grupoAliadoId":melhor_grupo,"individuoAliadoId":melhor_individuo,"reducaoDano":(0.40 if melhor_grupo == id_defendido else REDUCAO_DANO),"protecaoFamiliar":melhor_grupo == id_defendido}


static func selecionar_alvo_prioritario(grupo_presa: Dictionary, posicao_predador: Vector2) -> Dictionary:
	var melhor: Dictionary = {}
	var maior_pontuacao := -INF
	for individuo in grupo_presa.get("individuos", []):
		if not bool(individuo.get("vivo", false)):
			continue
		var p = individuo.get("posicaoMundo", {})
		if not (p is Dictionary):
			continue
		var pos := Vector2(float(p.get("x", -9999.0)), float(p.get("y", -9999.0)))
		if not _posicao_valida(pos):
			continue
		var atributos: Dictionary = individuo.get("atributos", {})
		var vida_max := maxf(1.0, float(atributos.get("vidaMaxima", 1.0)))
		var vida := clampf(float(individuo.get("vidaAtual", vida_max)) / vida_max, 0.0, 1.0)
		var fase := str(individuo.get("faseVida", ""))
		var isolamento := 0.0
		for outro in grupo_presa.get("individuos", []):
			if not bool(outro.get("vivo", false)) or str(outro.get("individuoId", "")) == str(individuo.get("individuoId", "")):
				continue
			var op = outro.get("posicaoMundo", {})
			if not (op is Dictionary):
				continue
			var pos_outro := Vector2(float(op.get("x", -9999.0)), float(op.get("y", -9999.0)))
			if _posicao_valida(pos_outro):
				isolamento = maxf(isolamento, pos.distance_to(pos_outro))
		var distancia := posicao_predador.distance_to(pos)
		var pontuacao := (1.0 - vida) * 65.0 + (35.0 if fase == "filhote" else 0.0) + minf(isolamento, 100.0) * 0.20 - distancia * 0.15
		var guardioes_proximos := 0
		for guardiao in grupo_presa.get("individuos", []):
			if not bool(guardiao.get("vivo", false)) or str(guardiao.get("individuoId", "")) == str(individuo.get("individuoId", "")):
				continue
			if str(guardiao.get("faseVida", "adulto")) == "filhote":
				continue
			var gp = guardiao.get("posicaoMundo", {})
			if not (gp is Dictionary):
				continue
			var pos_guardiao := Vector2(float(gp.get("x", -9999.0)), float(gp.get("y", -9999.0)))
			if _posicao_valida(pos_guardiao) and pos.distance_to(pos_guardiao) <= DISTANCIA_PROTECAO:
				guardioes_proximos += 1
		# Filhotes cercados por adultos deixam de ser alvos preferenciais.
		pontuacao -= float(guardioes_proximos) * 42.0
		var protecao_por_amigos := 0.0
		for companheiro in grupo_presa.get("individuos", []):
			if not bool(companheiro.get("vivo", false)) or str(companheiro.get("individuoId", "")) == str(individuo.get("individuoId", "")):
				continue
			var cp = companheiro.get("posicaoMundo", {})
			if not (cp is Dictionary):
				continue
			var pos_companheiro := Vector2(float(cp.get("x", -9999.0)), float(cp.get("y", -9999.0)))
			if not _posicao_valida(pos_companheiro):
				continue
			var distancia_amigo := pos.distance_to(pos_companheiro)
			if distancia_amigo <= 100.0:
				protecao_por_amigos = maxf(protecao_por_amigos, _afinidade_social(companheiro, str(grupo_presa.get("grupoId", "")), str(individuo.get("individuoId", ""))))
		pontuacao -= protecao_por_amigos * 22.0
		if fase == "filhote" or vida <= 0.55:
			pontuacao += 18.0
		if pontuacao > maior_pontuacao:
			maior_pontuacao = pontuacao
			melhor = individuo.duplicate(true)
	return melhor


## Afinidade social de um indivíduo com outro; rivais não recebem bônus de proteção.
static func _posicao_valida(posicao: Vector2) -> bool:
	return is_finite(posicao.x) and is_finite(posicao.y) and posicao.x >= 0.0 and posicao.y >= 0.0 and posicao.x <= 2400.0 and posicao.y <= 1600.0


static func _afinidade_social(individuo: Dictionary, grupo_id: String, outro_individuo_id: String) -> float:
	for vinculo in individuo.get("vinculosIndividuais", []):
		if str(vinculo.get("grupoId", "")) != grupo_id or str(vinculo.get("individuoId", "")) != outro_individuo_id:
			continue
		var amizade := clampf(float(vinculo.get("amizade", 0.0)), 0.0, 1.0)
		var confianca := clampf(float(vinculo.get("confianca", 0.0)), 0.0, 1.0)
		var rivalidade := clampf(float(vinculo.get("rivalidade", 0.0)), 0.0, 1.0)
		return clampf(amizade * 0.45 + confianca * 0.55 - rivalidade * 0.65, 0.0, 1.0)
	return 0.0
