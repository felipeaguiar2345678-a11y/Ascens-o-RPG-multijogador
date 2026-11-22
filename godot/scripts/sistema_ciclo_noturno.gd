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
