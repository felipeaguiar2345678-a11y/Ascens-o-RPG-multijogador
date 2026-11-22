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
	var melhor_distancia := DISTANCIA_PROTECAO
	var melhor_grupo := ""
	var melhor_individuo := ""
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
			if distancia < melhor_distancia:
				melhor_distancia = distancia
				melhor_grupo = aliado_id
				melhor_individuo = str(membro.get("individuoId", ""))
	if melhor_grupo.is_empty():
		return {"interveio":false}
	return {"interveio":true,"grupoAliadoId":melhor_grupo,"individuoAliadoId":melhor_individuo,"reducaoDano":REDUCAO_DANO}
