extends RefCounted
## Relações ecológicas explícitas entre criaturas geradas e catalogadas.
## Não presume dieta por aparência, rank ou nome: só usa dados declarados pelo gerador.
const SISTEMA_POPULACAO = preload("res://scripts/sistema_populacao_criaturas.gd")
const SISTEMA_RECURSOS = preload("res://scripts/sistema_recursos_ecologicos.gd")

static func avaliar_relacao(a: Dictionary, b: Dictionary) -> Dictionary:
	var id_a := str(a.get("id", ""))
	var id_b := str(b.get("id", ""))
	if id_a.is_empty() or id_b.is_empty() or id_a == id_b:
		return {"tipo":"neutra","alvo":""}
	var ecologia_a: Dictionary = a.get("ecologia", {})
	var ecologia_b: Dictionary = b.get("ecologia", {})
	var presas_a: Array = ecologia_a.get("especiesPresas", [])
	var predadores_b: Array = ecologia_b.get("especiesPredadoras", [])
	var presas_b: Array = ecologia_b.get("especiesPresas", [])
	var predadores_a: Array = ecologia_a.get("especiesPredadoras", [])
	var a_caca_b := presas_a.has(id_b) or predadores_b.has(id_a)
	var b_caca_a := presas_b.has(id_a) or predadores_a.has(id_b)
	# Declarações opostas são ambíguas; o servidor não escolhe um vencedor por inferência.
	if a_caca_b == b_caca_a:
		return {"tipo":"neutra","alvo":"","motivo":"relacao_ausente_ou_contraditoria"}
	if a_caca_b:
		return {"tipo":"predador","predador":id_a,"presa":id_b}
	return {"tipo":"predador","predador":id_b,"presa":id_a}

static func esta_no_territorio(criatura: Dictionary, posicao: Vector2) -> bool:
	var ecologia: Dictionary = criatura.get("ecologia", {})
	var territorio: Dictionary = ecologia.get("territorio", {})
	if territorio.is_empty():
		return false
	var centro = territorio.get("centro", {})
	if not (centro is Dictionary):
		return false
	var x := float(centro.get("x", -1.0))
	var y := float(centro.get("y", -1.0))
	var raio := float(territorio.get("raio", 0.0))
	if x < 0.0 or y < 0.0 or raio <= 0.0 or raio > 1000.0:
		return false
	return posicao.distance_to(Vector2(x, y)) <= raio


## Constrói um contexto de interação entre duas criaturas próximas.
## A direção da relação é explícita; não inventa dieta ou hostilidade.
static func criar_contexto_interacao(criatura: Dictionary, vizinha: Dictionary, distancia: float, forca_criatura: float, forca_vizinha: float, posicao_vizinha: Vector2) -> Dictionary:
	if distancia < 0.0 or distancia > 180.0:
		return {}
	var relacao := avaliar_relacao(criatura, vizinha)
	var id_atual := str(criatura.get("id", ""))
	var id_predador := str(relacao.get("predador", ""))
	if relacao.get("tipo") == "predador":
		if id_predador == id_atual:
			if forca_criatura > forca_vizinha:
				return {"presaPresente":true,"forcaCriatura":forca_criatura,"forcaAmeaca":forca_vizinha,"posicaoAlvo":posicao_vizinha,"distanciaAmeaca":distancia}
			return {"ameacaPresente":true,"forcaCriatura":forca_criatura,"forcaAmeaca":forca_vizinha,"posicaoAlvo":posicao_vizinha,"distanciaAmeaca":distancia}
		return {"ameacaPresente":true,"forcaCriatura":forca_criatura,"forcaAmeaca":forca_vizinha,"posicaoAlvo":posicao_vizinha,"distanciaAmeaca":distancia}
	if esta_no_territorio(criatura, posicao_vizinha):
		return {"invasorTerritorio":true,"forcaCriatura":forca_criatura,"forcaAmeaca":forca_vizinha,"posicaoAlvo":posicao_vizinha,"distanciaAmeaca":distancia}
	return {}

static func validar_ecologia(ecologia: Variant) -> bool:
	if ecologia == null:
		return true
	if not (ecologia is Dictionary):
		return false
	var presas = ecologia.get("especiesPresas", [])
	var predadores = ecologia.get("especiesPredadoras", [])
	if not (presas is Array) or not (predadores is Array):
		return false
	if presas.size() > 64 or predadores.size() > 64:
		return false
	var vistos_presas := {}
	var vistos_predadores := {}
	for entrada in presas:
		var id_presa := str(entrada).strip_edges()
		if id_presa.is_empty() or id_presa.length() > 128 or vistos_presas.has(id_presa):
			return false
		vistos_presas[id_presa] = true
	for entrada in predadores:
		var id_predador := str(entrada).strip_edges()
		if id_predador.is_empty() or id_predador.length() > 128 or vistos_predadores.has(id_predador):
			return false
		vistos_predadores[id_predador] = true
	# Uma espécie não pode declarar a si própria como presa/predadora,
	# nem ocupar os dois lados da mesma relação alimentar.
	for id_relacionado in vistos_presas:
		if vistos_predadores.has(id_relacionado):
			return false
	if not SISTEMA_POPULACAO.validar_configuracao(ecologia.get("populacao", null)):
		return false
	var recursos = ecologia.get("recursosAmbientais", [])
	if not (recursos is Array) or not SISTEMA_RECURSOS.validar_configuracoes(recursos):
		return false
	var necrofagos = ecologia.get("especiesNecrófagas", [])
	var consumo_carcaca := float(ecologia.get("consumoCarcacaPorIndividuoDia", 0.0))
	if not is_finite(consumo_carcaca) or not (necrofagos is Array) or necrofagos.size() > 64 or consumo_carcaca < 0.0 or consumo_carcaca > 1000000.0:
		return false
	if not necrofagos.is_empty() and consumo_carcaca <= 0.0:
		return false
	var vistos_necrofagos := {}
	for especie_id in necrofagos:
		var id_necrofago := str(especie_id)
		if id_necrofago.is_empty() or id_necrofago.length() > 128 or vistos_necrofagos.has(id_necrofago) or vistos_presas.has(id_necrofago) or vistos_predadores.has(id_necrofago):
			return false
		vistos_necrofagos[id_necrofago] = true
	var carcaca = ecologia.get("carcaca", {})
	if not (carcaca is Dictionary):
		return false
	if not carcaca.is_empty():
		var unidades := float(carcaca.get("unidades", 1.0))
		var decomposicao := float(carcaca.get("decomposicaoPorDia", unidades * 0.1))
		if unidades < 1.0 or unidades > 1000000.0 or decomposicao < 0.0 or decomposicao > unidades:
			return false
	var rotas = ecologia.get("rotasMigracao", [])
	if not (rotas is Array) or rotas.size() > 16:
		return false
	var ids_rotas := {}
	for rota in rotas:
		if not (rota is Dictionary):
			return false
		var rota_id := str(rota.get("id", ""))
		var ecossistema_rota := str(rota.get("ecossistemaId", ""))
		var bioma_rota := str(rota.get("bioma", ""))
		var habitat_rota := str(rota.get("habitat", ""))
		var territorio_rota = rota.get("territorio", {})
		if rota_id.is_empty() or rota_id.length() > 128 or ids_rotas.has(rota_id):
			return false
		if ecossistema_rota.is_empty() or bioma_rota.is_empty() or habitat_rota.is_empty() or not (territorio_rota is Dictionary):
			return false
		var centro_rota = territorio_rota.get("centro", {})
		if not (centro_rota is Dictionary):
			return false
		var x_rota := float(centro_rota.get("x", -1.0))
		var y_rota := float(centro_rota.get("y", -1.0))
		var raio_rota := float(territorio_rota.get("raio", 0.0))
		if x_rota < 0.0 or x_rota > 2400.0 or y_rota < 0.0 or y_rota > 1600.0 or raio_rota < 20.0 or raio_rota > 1000.0:
			return false
		ids_rotas[rota_id] = true
	var territorio = ecologia.get("territorio", {})
	if not (territorio is Dictionary):
		return false
	if not territorio.is_empty():
		var centro = territorio.get("centro", {})
		if not (centro is Dictionary):
			return false
		var x := float(centro.get("x", -1.0))
		var y := float(centro.get("y", -1.0))
		var raio := float(territorio.get("raio", 0.0))
		if x < 0.0 or x > 2400.0 or y < 0.0 or y > 1600.0 or raio <= 0.0 or raio > 1000.0:
			return false
	return true
