extends RefCounted
## Seleção determinística de criaturas já geradas e registradas.
## Não cria inimigos nem decide sozinha o local do encontro.
const RARIDADES_PESO := {
	"comum": 1000, "incomum": 650, "raro": 350, "epico": 180,
	"lendario": 80, "mitico": 35, "divino": 12,
	"transcendente": 3, "unico": 1
}
const LIMIAR_FUGA_FAUNA := 0.85

static func calcular_influencia_destruicao(marcas: Array, posicao: Vector2, agora_unix: int) -> float:
	var maior_influencia := 0.0
	for marca in marcas:
		if not (marca is Dictionary):
			continue
		var expira := int(marca.get("expiraUnix", 0))
		var criado := int(marca.get("criadoUnix", 0))
		if expira <= agora_unix or criado <= 0 or expira <= criado:
			continue
		var raio := clampf(float(marca.get("raio", 0.0)), 0.0, 2000.0)
		if raio <= 0.0:
			continue
		var centro := Vector2(float(marca.get("x", -10000.0)), float(marca.get("y", -10000.0)))
		var distancia := posicao.distance_to(centro)
		if distancia >= raio:
			continue
		var progresso := clampf(float(agora_unix - criado) / float(expira - criado), 0.0, 1.0)
		var recuperacao := progresso * progresso * (3.0 - 2.0 * progresso)
		var intensidade := clampf(float(marca.get("intensidade", 1.0)), 0.1, 1.0)
		var influencia := (1.0 - distancia / raio) * intensidade * (1.0 - recuperacao)
		maior_influencia = maxf(maior_influencia, influencia)
	return clampf(maior_influencia, 0.0, 1.0)

static func selecionar(catalogo: Array, ecossistema_id: String, bioma: String, perigo: int, permitir_chefe: bool, semente: int, periodo: String = "dia", posicao_encontro: Vector2 = Vector2(-1.0, -1.0), marcas_destruicao: Array = [], agora_unix: int = -1) -> Dictionary:
	if ecossistema_id.strip_edges().is_empty() or bioma.strip_edges().is_empty():
		return {}
	if perigo < 0 or perigo > 100 or catalogo.is_empty():
		return {}
	var agora := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	var influencia := 0.0
	if posicao_encontro.x >= 0.0 and posicao_encontro.y >= 0.0 and not marcas_destruicao.is_empty():
		influencia = calcular_influencia_destruicao(marcas_destruicao, posicao_encontro, agora)
	var candidatas: Array = []
	var peso_total := 0
	for criatura in catalogo:
		if not (criatura is Dictionary):
			continue
		if not preload("res://scripts/sistema_ciclo_noturno.gd").criatura_disponivel(criatura, periodo):
			continue
		if str(criatura.get("ecossistemaId", "")) != ecossistema_id:
			continue
		if str(criatura.get("bioma", "")) != bioma:
			continue
		var nivel_perigo := int(criatura.get("perigo", -1))
		if nivel_perigo < 0 or nivel_perigo > perigo:
			continue
		var chefe := bool(criatura.get("chefe", false)) or bool(criatura.get("chefeMundial", false)) or str(criatura.get("categoria", "")).to_lower() == "chefe_mundial"
		if chefe and not permitir_chefe:
			continue
		# Chefes e eventos especiais não são apagados por uma cicatriz local.
		if influencia >= LIMIAR_FUGA_FAUNA and not chefe:
			continue
		var raridade := str(criatura.get("raridade", "comum")).to_lower()
		var peso := int(RARIDADES_PESO.get(raridade, 0))
		if peso <= 0:
			continue
		if not chefe and influencia > 0.0:
			peso = maxi(1, roundi(float(peso) * (1.0 - influencia * 0.85)))
		candidatas.append({"criatura":criatura,"peso":peso})
		peso_total += peso
	if candidatas.is_empty() or peso_total <= 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var sorteio := rng.randi_range(1, peso_total)
	for candidata in candidatas:
		sorteio -= int(candidata["peso"])
		if sorteio <= 0:
			return candidata["criatura"].duplicate(true)
	return {}
