extends RefCounted
class_name SistemaMaestriaArmas

## Maestria individual, calculada e validada no servidor.
const NIVEL_MAXIMO := 50
const XP_POR_ACERTO := 10
const BONUS_DANO_POR_NIVEL := 0.006
const BONUS_DANO_MAXIMO := 0.30

static func normalizar_registro(registro: Dictionary) -> Dictionary:
	var nivel := clampi(int(registro.get("nivel", 1)), 1, NIVEL_MAXIMO)
	var experiencia := clampi(int(registro.get("experiencia", 0)), 0, 100000000)
	var experiencia_nivel := experiencia
	for n in range(1, nivel):
		experiencia_nivel -= _xp_proximo_nivel(n)
	experiencia_nivel = clampi(experiencia_nivel, 0, _xp_proximo_nivel(nivel) - 1 if nivel < NIVEL_MAXIMO else 0)
	if nivel >= NIVEL_MAXIMO:
		experiencia_nivel = 0
		experiencia = _experiencia_total_para_nivel_maximo()
	return {"nivel":nivel,"experiencia":experiencia,"experienciaNoNivel":experiencia_nivel}

static func obter_registro(maestrias: Dictionary, arma_id: String) -> Dictionary:
	if arma_id.strip_edges().is_empty():
		return {"nivel":1,"experiencia":0,"experienciaNoNivel":0}
	var bruto: Variant = maestrias.get(arma_id, {})
	return normalizar_registro(bruto if bruto is Dictionary else {})

static func multiplicador_dano(nivel: int) -> float:
	var nivel_seguro := clampi(nivel, 1, NIVEL_MAXIMO)
	return 1.0 + minf(BONUS_DANO_MAXIMO, float(nivel_seguro - 1) * BONUS_DANO_POR_NIVEL)

static func aplicar_bonus_dano(dano_base: int, nivel: int) -> int:
	return maxi(1, int(round(float(maxi(1, dano_base)) * multiplicador_dano(nivel))))

static func registrar_acerto(maestrias_originais: Dictionary, arma_id: String) -> Dictionary:
	if arma_id.strip_edges().is_empty():
		return {"maestrias":maestrias_originais.duplicate(true),"registro":{"nivel":1,"experiencia":0,"experienciaNoNivel":0},"subiuNivel":false}
	var maestrias := maestrias_originais.duplicate(true)
	var antes := obter_registro(maestrias, arma_id)
	var registro := antes.duplicate(true)
	if int(registro["nivel"]) < NIVEL_MAXIMO:
		var experiencia_total := int(registro["experiencia"]) + XP_POR_ACERTO
		var experiencia_restante := experiencia_total
		var nivel := 1
		while nivel < NIVEL_MAXIMO and experiencia_restante >= _xp_proximo_nivel(nivel):
			experiencia_restante -= _xp_proximo_nivel(nivel)
			nivel += 1
		if nivel >= NIVEL_MAXIMO:
			experiencia_total = _experiencia_total_para_nivel_maximo()
			experiencia_restante = 0
		registro = {"nivel":nivel,"experiencia":experiencia_total,"experienciaNoNivel":experiencia_restante}
	maestrias[arma_id] = registro
	return {"maestrias":maestrias,"registro":registro,"subiuNivel":int(registro["nivel"]) > int(antes["nivel"])}

static func progresso(maestrias: Dictionary, arma_id: String) -> Dictionary:
	var registro := obter_registro(maestrias, arma_id)
	var nivel := int(registro["nivel"])
	var xp_atual := int(registro["experienciaNoNivel"])
	var xp_necessario := _xp_proximo_nivel(nivel) if nivel < NIVEL_MAXIMO else 0
	return {
		"armaId":arma_id,
		"nivel":nivel,
		"nivelMaximo":NIVEL_MAXIMO,
		"experiencia":int(registro["experiencia"]),
		"experienciaNoNivel":xp_atual,
		"experienciaProximoNivel":xp_necessario,
		"progresso":float(xp_atual) / float(maxi(1, xp_necessario)) if xp_necessario > 0 else 1.0,
		"multiplicadorDano":multiplicador_dano(nivel),
		"bonusDanoPercentual":int(round((multiplicador_dano(nivel) - 1.0) * 100.0)),
		"marcoMaestria":obter_marco(nivel)
	}

static func obter_marco(nivel: int) -> Dictionary:
	var nivel_seguro := clampi(nivel, 1, NIVEL_MAXIMO)
	var marcos := [
		{"nivel":1,"id":"aprendiz","nome":"Aprendiz","descricao":"Ataques básicos da arma"},
		{"nivel":5,"id":"golpe_refinado","nome":"Golpe Refinado","descricao":"Rastro de ataque mais definido"},
		{"nivel":10,"id":"cadencia","nome":"Cadência de Combate","descricao":"Golpes encadeados e cortes adicionais"},
		{"nivel":20,"id":"tecnica_dominada","nome":"Técnica Dominada","descricao":"Impactos com ondas de energia"},
		{"nivel":35,"id":"assinatura","nome":"Assinatura da Arma","descricao":"Efeito visual característico ampliado"},
		{"nivel":50,"id":"maestria_absoluta","nome":"Maestria Absoluta","descricao":"Aura e impacto visual no auge"}
	]
	var atual: Dictionary = marcos[0]
	var desbloqueados: Array = []
	var proximo: Dictionary = {}
	for marco in marcos:
		if nivel_seguro >= int(marco["nivel"]):
			atual = marco
			desbloqueados.append(marco.duplicate(true))
		elif proximo.is_empty():
			proximo = marco.duplicate(true)
	return {
		"nivel":nivel_seguro,
		"atual":atual.duplicate(true),
		"proximo":proximo,
		"desbloqueados":desbloqueados
	}

static func _xp_proximo_nivel(nivel: int) -> int:
	return 100 + maxi(0, nivel - 1) * 25

static func _experiencia_total_para_nivel_maximo() -> int:
	var total := 0
	for nivel in range(1, NIVEL_MAXIMO):
		total += _xp_proximo_nivel(nivel)
	return total
