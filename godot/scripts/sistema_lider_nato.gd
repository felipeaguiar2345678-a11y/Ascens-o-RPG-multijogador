extends RefCounted
## Traço hereditário raro: 1% dos nascimentos gera um líder nato.
const CHANCE_NASCIMENTO := 0.01
const MULTIPLICADOR_ATRIBUTOS := 1.25
const ATRIBUTOS_COMBATE := ["vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"]

static func sortear(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < CHANCE_NASCIMENTO

static func aprimorar(atributos_base: Dictionary) -> Dictionary:
	var resultado := atributos_base.duplicate(true)
	for atributo in ATRIBUTOS_COMBATE:
		if resultado.has(atributo):
			resultado[atributo] = maxi(1, roundi(float(resultado[atributo]) * MULTIPLICADOR_ATRIBUTOS))
	return resultado
