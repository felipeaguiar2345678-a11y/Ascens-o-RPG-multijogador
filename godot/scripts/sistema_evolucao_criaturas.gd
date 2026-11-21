extends RefCounted
## Evolução persistente e limitada de criaturas que sobrevivem aos encontros.

const SEGUNDOS_POR_DIA := 86400
const MAX_DIAS_EVOLUCAO := 15
const BONUS_POR_DIA := 2.0
const BONUS_MAXIMO_VITORIAS := 20.0
const MAX_MUTACOES := 3

const ATRIBUTOS_BASE := [
	"vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"
]

const MUTACOES := [
	{"id":"carapaca_reforcada","nome":"Carapaça reforçada","atributo":"defesa"},
	{"id":"olhos_arcanos","nome":"Olhos arcanos","atributo":"poderMagico"},
	{"id":"membros_predatorios","nome":"Membros predatórios","atributo":"agilidade"},
	{"id":"chifres_de_guerra","nome":"Chifres de guerra","atributo":"ataque"},
	{"id":"coracao_vital","nome":"Coração vital","atributo":"vidaMaxima"},
	{"id":"nucleo_mistico","nome":"Núcleo místico","atributo":"manaMaxima"}
]

static func preparar(criatura: Dictionary, agora_unix: int = -1) -> Dictionary:
	var resultado := criatura.duplicate(true)
	var agora := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	var evolucao: Dictionary = resultado.get("evolucao", {})
	if evolucao.is_empty():
		var base := {}
		for atributo in ATRIBUTOS_BASE:
			base[atributo] = maxi(0, int(resultado.get(atributo, 0)))
		evolucao = {
			"inicioUnix":agora,
			"ultimoCalculoUnix":agora,
			"diasAplicados":0,
			"vitoriasSobreJogadores":0,
			"jogadoresDerrotados":[],
			"mutacoes":[],
			"mutacoesPorTempo":0,
			"mutacoesPorVitorias":0,
			"atributosBase":base
		}
	resultado["evolucao"] = evolucao
	_recalcular_atributos(resultado)
	return resultado

static func registrar_vitoria(criatura: Dictionary, uid: String, agora_unix: int = -1) -> Dictionary:
	if uid.strip_edges().is_empty() or uid.length() > 128:
		return {"ok":false,"erro":"Jogador inválido."}
	var resultado := preparar(criatura, agora_unix)
	var evolucao: Dictionary = resultado["evolucao"]
	var derrotados: Array = evolucao.get("jogadoresDerrotados", [])
	var novas_vitorias := int(evolucao.get("vitoriasSobreJogadores", 0)) + 1
	evolucao["vitoriasSobreJogadores"] = novas_vitorias
	if not derrotados.has(uid):
		derrotados.append(uid)
	evolucao["jogadoresDerrotados"] = derrotados
	while int(evolucao.get("mutacoesPorVitorias", 0)) < 3 and novas_vitorias >= (int(evolucao.get("mutacoesPorVitorias", 0)) + 1) * 5 and (evolucao.get("mutacoes", []) as Array).size() < MAX_MUTACOES:
		_adicionar_mutacao(evolucao, str(resultado.get("id", "")))
		evolucao["mutacoesPorVitorias"] = int(evolucao.get("mutacoesPorVitorias", 0)) + 1
	resultado["evolucao"] = evolucao
	_recalcular_atributos(resultado)
	return {"ok":true,"criatura":resultado,"vitoriasSobreJogadores":novas_vitorias}

static func aplicar_tempo(criatura: Dictionary, agora_unix: int = -1) -> Dictionary:
	var agora := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	var resultado := preparar(criatura, agora)
	var evolucao: Dictionary = resultado["evolucao"]
	var inicio := int(evolucao.get("inicioUnix", agora))
	var dias := clampi(int(maxi(0, agora - inicio) / SEGUNDOS_POR_DIA), 0, MAX_DIAS_EVOLUCAO)
	var dias_anteriores := int(evolucao.get("diasAplicados", 0))
	var alterou := dias > dias_anteriores
	evolucao["diasAplicados"] = maxi(dias_anteriores, dias)
	evolucao["ultimoCalculoUnix"] = maxi(int(evolucao.get("ultimoCalculoUnix", 0)), agora)
	while int(evolucao.get("mutacoesPorTempo", 0)) < 3 and dias >= (int(evolucao.get("mutacoesPorTempo", 0)) + 1) * 7 and (evolucao.get("mutacoes", []) as Array).size() < MAX_MUTACOES:
		_adicionar_mutacao(evolucao, str(resultado.get("id", "")))
		evolucao["mutacoesPorTempo"] = int(evolucao.get("mutacoesPorTempo", 0)) + 1
		alterou = true
	resultado["evolucao"] = evolucao
	_recalcular_atributos(resultado)
	return {"ok":true,"alterou":alterou,"criatura":resultado}

static func _adicionar_mutacao(evolucao: Dictionary, criatura_id: String) -> void:
	var mutacoes: Array = evolucao.get("mutacoes", [])
	if mutacoes.size() >= MAX_MUTACOES:
		return
	var indice := int(abs(hash(criatura_id)) + mutacoes.size() * 7) % MUTACOES.size()
	mutacoes.append(MUTACOES[indice].duplicate(true))
	evolucao["mutacoes"] = mutacoes

static func _recalcular_atributos(criatura: Dictionary) -> void:
	var evolucao: Dictionary = criatura.get("evolucao", {})
	var base: Dictionary = evolucao.get("atributosBase", {})
	var dias := mini(MAX_DIAS_EVOLUCAO, int(evolucao.get("diasAplicados", 0)))
	var vitorias := int(evolucao.get("vitoriasSobreJogadores", 0))
	var bonus_total := minf(50.0, float(dias) * BONUS_POR_DIA + minf(BONUS_MAXIMO_VITORIAS, float(vitorias) * 0.5))
	var bonus_mutacoes: Dictionary = {}
	for mutacao in evolucao.get("mutacoes", []):
		var atributo := str(mutacao.get("atributo", ""))
		bonus_mutacoes[atributo] = float(bonus_mutacoes.get(atributo, 0.0)) + 8.0
	for atributo in ATRIBUTOS_BASE:
		var valor_base := int(base.get(atributo, criatura.get(atributo, 0)))
		var multiplicador := 1.0 + (bonus_total + float(bonus_mutacoes.get(atributo, 0.0))) / 100.0
		criatura[atributo] = maxi(0, int(round(float(valor_base) * multiplicador)))
	criatura["evolucao"] = evolucao
