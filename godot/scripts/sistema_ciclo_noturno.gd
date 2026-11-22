extends RefCounted
class_name SistemaCicloNoturno

## Regras determinísticas do ciclo diário. A hora deve vir do relógio autoritativo.
const MULTIPLICADOR_ATRIBUTOS_NOTURNOS := 1.5
const MULTIPLICADOR_XP_NOTURNO := 1.5
const MULTIPLICADOR_CHANCE_DROP_NOTURNO := 1.5
const MULTIPLICADOR_QUANTIDADE_DROP_NOTURNO := 1.25

static func periodo_por_hora(hora: int) -> String:
	if hora < 0 or hora > 23:
		return "indefinido"
	if hora >= 5 and hora < 18:
		return "dia"
	if hora >= 18 and hora < 20:
		return "crepusculo"
	if hora >= 20 or hora < 4:
		return "noite"
	return "madrugada"

static func esta_no_periodo_noturno(periodo: String) -> bool:
	return ["crepusculo", "noite", "madrugada"].has(periodo)

static func criatura_disponivel(criatura: Dictionary, periodo: String) -> bool:
	if periodo == "indefinido" or periodo.is_empty():
		return false
	var atividade := str(criatura.get("periodoAtividade", criatura.get("atividade", "qualquer"))).to_lower()
	var exclusiva_noturna := bool(criatura.get("exclusivaNoturna", false))
	if exclusiva_noturna and not esta_no_periodo_noturno(periodo):
		return false
	if atividade in ["noturna", "noite"] and not esta_no_periodo_noturno(periodo):
		return false
	if atividade in ["diurna", "dia"] and esta_no_periodo_noturno(periodo):
		return false
	if atividade in ["crepuscular", "crepusculo"] and not ["crepusculo", "madrugada"].has(periodo):
		return false
	return true

## Retorna uma cópia para que os atributos catalogados nunca sejam alterados.
## O marcador evita aplicar 1,5x duas vezes sobre a mesma cópia.
static func preparar_criatura_para_periodo(criatura: Dictionary, periodo: String) -> Dictionary:
	if criatura.is_empty() or not criatura_disponivel(criatura, periodo):
		return {}
	var copia := criatura.duplicate(true)
	if not esta_no_periodo_noturno(periodo) or bool(copia.get("_ajusteNoturnoAplicado", false)):
		return copia
	for campo in ["vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"]:
		if copia.has(campo):
			copia[campo] = maxi(1 if campo == "vidaMaxima" else 0, roundi(float(copia[campo]) * MULTIPLICADOR_ATRIBUTOS_NOTURNOS))
	if copia.has("vida"):
		copia["vida"] = maxi(1, roundi(float(copia["vida"]) * MULTIPLICADOR_ATRIBUTOS_NOTURNOS))
	copia["_ajusteNoturnoAplicado"] = true
	copia["periodoEncontro"] = periodo
	copia["multiplicadorNoturno"] = MULTIPLICADOR_ATRIBUTOS_NOTURNOS
	return copia

static func calcular_experiencia(base: int, periodo: String, criatura: Dictionary = {}) -> int:
	if base <= 0:
		return 0
	var bonus := MULTIPLICADOR_XP_NOTURNO if esta_no_periodo_noturno(periodo) else 1.0
	if bool(criatura.get("recompensaNoturnaEspecial", false)) and esta_no_periodo_noturno(periodo):
		bonus *= 1.25
	return maxi(0, roundi(float(base) * bonus))

static func criar_contexto(hora_autoritativa: int) -> Dictionary:
	var periodo := periodo_por_hora(hora_autoritativa)
	return {"hora":hora_autoritativa,"periodo":periodo,"noturno":esta_no_periodo_noturno(periodo)}


## Calendário celeste compartilhado: calendário de 28 dias, com fenômenos raros.
const CICLO_LUNAR_DIAS := 28
const CICLO_EVENTOS_RAROS_DIAS := 112

static func fase_lunar_por_dia(dia_mundo: int) -> String:
	if dia_mundo < 1:
		return "indefinida"
	match posmod(dia_mundo - 1, CICLO_LUNAR_DIAS) + 1:
		1: return "lua_nova"
		4: return "lua_crescente"
		8: return "quarto_crescente"
		11: return "lua_gibosa_crescente"
		14: return "lua_cheia"
		18: return "lua_gibosa_minguante"
		22: return "quarto_minguante"
		25: return "lua_minguante"
		_: return "fase_intermediaria"

static func evento_celeste_por_dia(dia_mundo: int) -> Dictionary:
	if dia_mundo < 1:
		return {"id":"nenhum","nome":"Céu comum","raridade":"comum","multiplicadorAparicao":1.0,"multiplicadorXP":1.0,"multiplicadorDrop":1.0}
	var dia_ciclo := posmod(dia_mundo - 1, CICLO_EVENTOS_RAROS_DIAS) + 1
	match dia_ciclo:
		14:
			return {"id":"lua_cheia","nome":"Lua Cheia","raridade":"incomum","multiplicadorAparicao":1.25,"multiplicadorXP":1.1,"multiplicadorDrop":1.15,"criaturas":"lunares"}
		28:
			return {"id":"lua_negra","nome":"Lua Negra","raridade":"rara","multiplicadorAparicao":1.3,"multiplicadorXP":1.2,"multiplicadorDrop":1.25,"criaturas":"sombras"}
		42:
			return {"id":"lua_de_sangue","nome":"Lua de Sangue","raridade":"muito_rara","multiplicadorAparicao":1.5,"multiplicadorXP":1.5,"multiplicadorDrop":1.5,"criaturas":"sanguinarias"}
		56:
			return {"id":"eclipse","nome":"Eclipse","raridade":"lendaria","multiplicadorAparicao":1.75,"multiplicadorXP":1.75,"multiplicadorDrop":1.75,"criaturas":"ancestrais"}
		70:
			return {"id":"lua_azul","nome":"Lua Azul","raridade":"muito_rara","multiplicadorAparicao":1.5,"multiplicadorXP":1.35,"multiplicadorDrop":1.75,"criaturas":"arcanas"}
		84:
			return {"id":"superlua","nome":"Superlua","raridade":"rara","multiplicadorAparicao":1.35,"multiplicadorXP":1.2,"multiplicadorDrop":1.4,"criaturas":"ancestrais"}
		98:
			return {"id":"chuva_de_estrelas","nome":"Chuva de Estrelas","raridade":"rara","multiplicadorAparicao":1.0,"multiplicadorXP":1.0,"multiplicadorDrop":1.5,"recurso":"fragmentos_celestes"}
		112:
			return {"id":"aurora_arcana","nome":"Aurora Arcana","raridade":"lendaria","multiplicadorAparicao":1.5,"multiplicadorXP":1.5,"multiplicadorDrop":1.75,"criaturas":"arcanas","recurso":"essencia_aurora"}
	return {"id":"nenhum","nome":"Céu comum","raridade":"comum","multiplicadorAparicao":1.0,"multiplicadorXP":1.0,"multiplicadorDrop":1.0}

static func criar_contexto(hora_autoritativa: int, dia_mundo: int = 1) -> Dictionary:
	var periodo := periodo_por_hora(hora_autoritativa)
	var evento := evento_celeste_por_dia(dia_mundo)
	return {
		"hora":hora_autoritativa,
		"dia":dia_mundo,
		"periodo":periodo,
		"noturno":esta_no_periodo_noturno(periodo),
		"faseLunar":fase_lunar_por_dia(dia_mundo),
		"eventoCeleste":evento
	}
