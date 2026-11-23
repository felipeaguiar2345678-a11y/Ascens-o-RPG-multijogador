extends RefCounted
## Aliados próximos podem proteger um grupo sob ataque sem criar dano ou recursos do nada.
const DISTANCIA_PROTECAO := 42.0
const REDUCAO_DANO := 0.25

static func avaliar_intervencao(grupo_defendido: Dictionary, grupos: Array, individuo_ameacado: Dictionary) -> Dictionary:
	var id_defendido := str(grupo_defendido.get("grupoId", ""))
	var ecossistema := str(grupo_defendido.get("ecossistemaId", ""))
	var posicao_dados: Dictionary = individuo_ameacado.get("posicaoMundo", {})
	var posicao := Vector2(float(posicao_dados.get("x", -9999.0)), float(posicao_dados.get("y", -9999.0)))
	if id_defendido.is_empty() or ecossistema.is_empty() or posicao.x < 0.0 or posicao.y < 0.0:
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
			var pp: Dictionary = protetor.get("posicaoMundo", {})
			var distancia_protetor := posicao.distance_to(Vector2(float(pp.get("x", -9999.0)), float(pp.get("y", -9999.0))))
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
			var membro_pos: Dictionary = membro.get("posicaoMundo", {})
			var distancia := posicao.distance_to(Vector2(float(membro_pos.get("x", -9999.0)), float(membro_pos.get("y", -9999.0))))
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
		var p: Dictionary = individuo.get("posicaoMundo", {})
		var pos := Vector2(float(p.get("x", -9999.0)), float(p.get("y", -9999.0)))
		if pos.x < 0.0 or pos.y < 0.0:
			continue
		var atributos: Dictionary = individuo.get("atributos", {})
		var vida_max := maxf(1.0, float(atributos.get("vidaMaxima", 1.0)))
		var vida := clampf(float(individuo.get("vidaAtual", vida_max)) / vida_max, 0.0, 1.0)
		var fase := str(individuo.get("faseVida", ""))
		var isolamento := 0.0
		for outro in grupo_presa.get("individuos", []):
			if not bool(outro.get("vivo", false)) or str(outro.get("individuoId", "")) == str(individuo.get("individuoId", "")):
				continue
			var op: Dictionary = outro.get("posicaoMundo", {})
			isolamento = maxf(isolamento, pos.distance_to(Vector2(float(op.get("x", -9999.0)), float(op.get("y", -9999.0)))))
		var distancia := posicao_predador.distance_to(pos)
		var pontuacao := (1.0 - vida) * 65.0 + (35.0 if fase == "filhote" else 0.0) + minf(isolamento, 100.0) * 0.20 - distancia * 0.15
		var protecao_por_amigos := 0.0
		for companheiro in grupo_presa.get("individuos", []):
			if not bool(companheiro.get("vivo", false)) or str(companheiro.get("individuoId", "")) == str(individuo.get("individuoId", "")):
				continue
			var cp: Dictionary = companheiro.get("posicaoMundo", {})
			var distancia_amigo := pos.distance_to(Vector2(float(cp.get("x", -9999.0)), float(cp.get("y", -9999.0))))
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
static func _afinidade_social(individuo: Dictionary, grupo_id: String, outro_individuo_id: String) -> float:
	for vinculo in individuo.get("vinculosIndividuais", []):
		if str(vinculo.get("grupoId", "")) != grupo_id or str(vinculo.get("individuoId", "")) != outro_individuo_id:
			continue
		var amizade := clampf(float(vinculo.get("amizade", 0.0)), 0.0, 1.0)
		var confianca := clampf(float(vinculo.get("confianca", 0.0)), 0.0, 1.0)
		var rivalidade := clampf(float(vinculo.get("rivalidade", 0.0)), 0.0, 1.0)
		return clampf(amizade * 0.45 + confianca * 0.55 - rivalidade * 0.65, 0.0, 1.0)
	return 0.0
