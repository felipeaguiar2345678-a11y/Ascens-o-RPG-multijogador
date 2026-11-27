extends RefCounted
## Avalia cuidado coletivo dos adultos sobre os filhotes do mesmo grupo.
const FILHOTES_POR_ADULTO := 4.0
const REDUCAO_MAXIMA_FOME_FILHOTES := 0.50

static func avaliar(grupo: Dictionary, agora_unix: int) -> Dictionary:
	var maturidade_dias := clampf(float(grupo.get("idadeMaturidadeDias", 7.0)), 1.0, 3650.0)
	var maturidade_segundos := maturidade_dias * 86400.0
	var adultos := 0
	var filhotes := 0
	var total_vivos := 0
	for individuo in grupo.get("individuos", []):
		if not bool(individuo.get("vivo", true)):
			continue
		total_vivos += 1
		var nascimento := int(individuo.get("nascimentoUnix", int(grupo.get("criadoUnix", agora_unix)) - int(maturidade_segundos)))
		if float(agora_unix - nascimento) >= maturidade_segundos:
			adultos += 1
		else:
			filhotes += 1
	var capacidade := float(adultos) * FILHOTES_POR_ADULTO
	var cobertura := 0.0
	if filhotes > 0:
		cobertura = minf(1.0, capacidade / float(filhotes))
	var proporcao_filhotes := float(filhotes) / float(maxi(1, total_vivos))
	var protecao := REDUCAO_MAXIMA_FOME_FILHOTES * cobertura * proporcao_filhotes
	return {
		"adultos":adultos,
		"filhotes":filhotes,
		"filhotesComCobertura":mini(filhotes, int(floor(capacidade))),
		"coberturaCuidado":cobertura,
		"protecaoFome":clampf(protecao, 0.0, REDUCAO_MAXIMA_FOME_FILHOTES * proporcao_filhotes)
	}
