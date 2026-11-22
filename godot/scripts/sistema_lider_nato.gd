extends RefCounted
## Traço hereditário raro: 1% dos nascimentos gera um líder nato.
const CHANCE_NASCIMENTO := 0.01
const MULTIPLICADOR_ATRIBUTOS := 1.25
const MULTIPLICADOR_CHANCE_DROPS := 2.0
const MULTIPLICADOR_QUANTIDADE_DROPS := 1.5
const MULTIPLICADOR_CARCACA := 1.5
const ATRIBUTOS_COMBATE := ["vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"]

static func sortear(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < CHANCE_NASCIMENTO

static func aprimorar(atributos_base: Dictionary) -> Dictionary:
	var resultado := atributos_base.duplicate(true)
	for atributo in ATRIBUTOS_COMBATE:
		if resultado.has(atributo):
			resultado[atributo] = maxi(1, roundi(float(resultado[atributo]) * MULTIPLICADOR_ATRIBUTOS))
	return resultado

## Líderes natos deixam mais recompensas e biomassa para o ecossistema.
static func calcular_rendimento_carcaca(unidades: float, decomposicao_por_dia: float, lider_nato: bool) -> Dictionary:
	var multiplicador := MULTIPLICADOR_CARCACA if lider_nato else 1.0
	return {
		"quantidade":clampf(unidades * multiplicador, 0.0, 1000000.0),
		"decomposicaoPorDia":clampf(decomposicao_por_dia * multiplicador, 0.0, 1000000.0),
		"qualidade":"superior" if lider_nato else "normal",
		"origemLiderNato":lider_nato
	}
