extends RefCounted
## Redistribui disponibilidade alimentar já alocada, sem criar estoque.
const INTERVALO_APOIO_SEGUNDOS := 21600
const LIMITE_TRANSFERENCIA := 0.15
const RESERVA_MINIMA_DOADOR := 0.70
const LIMITE_DOADOR := 0.80
const LIMITE_RECEPTOR := 0.25
const DISTANCIA_MAXIMA := 60.0

static func aplicar_ajuda(grupos: Array, disponibilidade_por_grupo: Dictionary, ultimo_apoio_por_par: Dictionary, agora_unix: int) -> Dictionary:
	var resultado := disponibilidade_por_grupo.duplicate(true)
	var doadores_usados := {}
	var receptores_usados := {}
	var eventos: Array = []
	var ordenados := grupos.duplicate()
	ordenados.sort_custom(func(a, b): return str(a.get("grupoId", "")) < str(b.get("grupoId", "")))
	for receptor in ordenados:
		var receptor_id := str(receptor.get("grupoId", ""))
		if receptor_id.is_empty() or receptores_usados.has(receptor_id):
			continue
		var alimento_receptor := float(resultado.get(receptor_id, 1.0))
		if alimento_receptor > LIMITE_RECEPTOR:
			continue
		for doador in ordenados:
			var doador_id := str(doador.get("grupoId", ""))
			if doador_id.is_empty() or doador_id == receptor_id or doadores_usados.has(doador_id):
				continue
			if str(doador.get("ecossistemaId", "")) != str(receptor.get("ecossistemaId", "")):
				continue
			var relacao: Dictionary = receptor.get("relacoesGrupos", {}).get(doador_id, {})
			var reversa: Dictionary = doador.get("relacoesGrupos", {}).get(receptor_id, {})
			if str(relacao.get("estado", "")) != "aliado" or str(reversa.get("estado", "")) != "aliado":
				continue
			if float(relacao.get("confianca", 0.0)) < 0.50 or float(reversa.get("confianca", 0.0)) < 0.50:
				continue
			var chave := receptor_id + "|" + doador_id
			if agora_unix < int(ultimo_apoio_por_par.get(chave, 0)) + INTERVALO_APOIO_SEGUNDOS:
				continue
			var tr: Dictionary = receptor.get("territorio", {})
			var td: Dictionary = doador.get("territorio", {})
			var cr: Dictionary = tr.get("centro", {})
			var cd: Dictionary = td.get("centro", {})
			var pr := Vector2(float(cr.get("x", -10000.0)), float(cr.get("y", -10000.0)))
			var pd := Vector2(float(cd.get("x", -10000.0)), float(cd.get("y", -10000.0)))
			if pr.distance_to(pd) > float(tr.get("raio", 0.0)) + float(td.get("raio", 0.0)) + DISTANCIA_MAXIMA:
				continue
			var alimento_doador := float(resultado.get(doador_id, 1.0))
			if alimento_doador < LIMITE_DOADOR:
				continue
			var transferencia := minf(LIMITE_TRANSFERENCIA, alimento_doador - RESERVA_MINIMA_DOADOR)
			transferencia = minf(transferencia, 1.0 - alimento_receptor)
			if transferencia <= 0.0:
				continue
			resultado[doador_id] = alimento_doador - transferencia
			resultado[receptor_id] = alimento_receptor + transferencia
			ultimo_apoio_por_par[chave] = agora_unix
			doadores_usados[doador_id] = true
			receptores_usados[receptor_id] = true
			eventos.append({"grupoDoadorId":doador_id,"grupoReceptorId":receptor_id,"transferencia":transferencia,"horarioUnix":agora_unix})
			break
	return {"disponibilidadePorGrupo":resultado,"eventos":eventos}
