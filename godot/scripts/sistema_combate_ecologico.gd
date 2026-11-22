extends RefCounted
## Resolve ataques ecológicos exclusivamente entre espécies com relação predador-presa declarada.
const ECOLOGIA = preload("res://scripts/sistema_ecologia_criaturas.gd")
static func resolver_ataque(predador: Dictionary, presa: Dictionary, individuo_predador: Dictionary, individuo_presa: Dictionary, semente: int) -> Dictionary:
	var relacao := ECOLOGIA.avaliar_relacao(predador, presa)
	if relacao.get("tipo") != "predador" or str(relacao.get("predador", "")) != str(predador.get("id", "")):
		return {"ok":false,"erro":"Relação de caça não declarada."}
	if str(individuo_predador.get("especieId", "")) != str(predador.get("id", "")) or str(individuo_presa.get("especieId", "")) != str(presa.get("id", "")):
		return {"ok":false,"erro":"Indivíduos não correspondem às espécies."}
	if not bool(individuo_predador.get("vivo", false)) or not bool(individuo_presa.get("vivo", false)):
		return {"ok":false,"erro":"Indivíduo morto não pode participar do combate."}
	var ap: Dictionary = individuo_predador.get("atributos", {})
	var ad: Dictionary = individuo_presa.get("atributos", {})
	var grupo_predador: Dictionary = predador.get("_grupo", {})
	var grupo_presa: Dictionary = presa.get("_grupo", {})
	var moral_atacante := clampf(float(individuo_predador.get("moralMultiplicador", grupo_predador.get("moralMultiplicador", 1.0))), 0.25, 2.0)
	var moral_defensiva := clampf(float(individuo_presa.get("moralMultiplicador", grupo_presa.get("moralMultiplicador", 1.0))), 0.25, 2.0)
	var ataque := maxf(1.0, (float(ap.get("ataque", predador.get("ataque", 1))) + float(ap.get("agilidade", predador.get("agilidade", 0))) * 0.15) * moral_atacante)
	var defesa := maxf(0.0, float(ad.get("defesa", presa.get("defesa", 0))) * moral_defensiva)
	var vida_maxima := maxf(1.0, float(ad.get("vidaMaxima", presa.get("vidaMaxima", 1))))
	var vida_atual := clampf(float(individuo_presa.get("vidaAtual", vida_maxima)), 0.0, vida_maxima)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var dano := maxf(1.0, ataque * rng.randf_range(0.72, 1.08) - defesa * 0.28)
	var lider_defendeu := false
	var lider_id := str(grupo_presa.get("liderAtual", {}).get("individuoId", ""))
	if not lider_id.is_empty() and lider_id != str(individuo_presa.get("individuoId", "")):
		for membro in grupo_presa.get("individuos", []):
			if str(membro.get("individuoId", "")) == lider_id and bool(membro.get("vivo", false)):
				var pl: Dictionary = membro.get("posicaoMundo", {})
				var pv: Dictionary = individuo_presa.get("posicaoMundo", {})
				var distancia := Vector2(float(pl.get("x", -9999.0)), float(pl.get("y", -9999.0))).distance_to(Vector2(float(pv.get("x", 0.0)), float(pv.get("y", 0.0))))
				if distancia <= 42.0:
					lider_defendeu = true
				break
	if lider_defendeu:
		dano *= 0.65
	dano = minf(vida_atual, maxf(1.0, dano))
	var restante := maxf(0.0, vida_atual - dano)
	return {"ok":true,"dano":roundi(dano),"vidaRestante":roundi(restante),"morreu":restante <= 0.0,"liderDefendeu":lider_defendeu,"alvoIndividuoId":str(individuo_presa.get("individuoId", ""))}
