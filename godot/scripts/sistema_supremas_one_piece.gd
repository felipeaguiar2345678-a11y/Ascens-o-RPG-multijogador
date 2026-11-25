extends RefCounted

## Regras das Supremas. Somente o servidor deve executar este módulo.
const CARGA_MAXIMA: int = 100
const CARGA_POR_TURNO: int = 12
const CARGA_EXTRA_POR_ACAO: int = 8
const DADOS: Dictionary = {
	"murakumogiri": {"nome":"Fúria da Gura Gura","raridade":"suprema","efeito":"terremoto_dimensional","elemento":"onda_de_choque","multiplicador":5.0,"alvo":"todos","descricao":"A arena se rompe em ondas sísmicas."},
	"yoru": {"nome":"Corte do Horizonte Negro","raridade":"suprema","efeito":"corte_colossal","elemento":"corte_negro","multiplicador":4.8,"alvo":"todos","descricao":"Um corte negro colossal atravessa o campo."},
	"ace": {"nome":"Vontade do Rei","raridade":"suprema","efeito":"corte_haki","elemento":"haki_do_rei","multiplicador":4.7,"alvo":"alvo","descricao":"Haki concentrado explode no impacto."},
	"shodai_kitetsu": {"nome":"Maldição Carmesim","raridade":"suprema","efeito":"corte_maldito","elemento":"energia_carmesim","multiplicador":4.6,"alvo":"alvo","descricao":"Energia amaldiçoada acompanha o corte."},
	"tripla_katana": {"nome":"Santoryu: Asura","raridade":"suprema","efeito":"asura_triplo","elemento":"haki_triplo","multiplicador":5.2,"alvo":"todos","descricao":"Três lâminas convergem em uma investida."},
	"gryphon": {"nome":"Kamusari","raridade":"mitica","efeito":"golpe_do_rei","elemento":"haki_do_rei","multiplicador":4.5,"alvo":"alvo","descricao":"Uma descarga de Haki acompanha o corte."},
	"kikoku": {"nome":"ROOM: Corte Espacial","raridade":"mitica","efeito":"sala_espacial","elemento":"energia_azul","multiplicador":4.4,"alvo":"todos","descricao":"Uma zona espacial envolve o campo."},
	"enma": {"nome":"Oni Giri do Rei","raridade":"lendaria","efeito":"liberacao_enma","elemento":"haki_roxo","multiplicador":3.8,"alvo":"alvo","descricao":"Enma libera uma descarga intensa de Haki."}
}

static func obter_dados(arma_id: String) -> Dictionary:
	return DADOS.get(arma_id.strip_edges().to_lower(), {}).duplicate(true)

static func pode_usar(arma_id: String) -> bool:
	var dados: Dictionary = obter_dados(arma_id)
	return not dados.is_empty() and str(dados.get("raridade", "")) in ["mitica", "suprema"]

static func criar_estado(arma_id: String) -> Dictionary:
	if not pode_usar(arma_id):
		return {}
	return {"armaId":arma_id.strip_edges().to_lower(),"carga":0,"pronta":false,"turnosCarregados":0,"acoesCarregadas":0,"usos":0}

static func _carregar(estado_original: Dictionary, quantidade: int, campo: String) -> Dictionary:
	if estado_original.is_empty():
		return {}
	var estado: Dictionary = estado_original.duplicate(true)
	estado["carga"] = mini(CARGA_MAXIMA, int(estado.get("carga", 0)) + quantidade)
	estado[campo] = int(estado.get(campo, 0)) + 1
	estado["pronta"] = int(estado["carga"]) >= CARGA_MAXIMA
	return estado

static func carregar_por_turno(estado_original: Dictionary) -> Dictionary:
	return _carregar(estado_original, CARGA_POR_TURNO, "turnosCarregados")

static func carregar_por_acao(estado_original: Dictionary) -> Dictionary:
	return _carregar(estado_original, CARGA_EXTRA_POR_ACAO, "acoesCarregadas")

static func executar(estado_original: Dictionary, inimigos_originais: Array, alvo_id: String) -> Dictionary:
	if estado_original.is_empty() or not bool(estado_original.get("pronta", false)):
		return {"ok":false,"erro":"A Suprema ainda não está carregada."}
	var dados: Dictionary = obter_dados(str(estado_original.get("armaId", "")))
	if dados.is_empty() or not pode_usar(str(estado_original.get("armaId", ""))):
		return {"ok":false,"erro":"Arma sem Suprema disponível."}
	var inimigos: Array = inimigos_originais.duplicate(true)
	var danos: Array = []
	var alvo_encontrado := false
	for indice in range(inimigos.size()):
		var inimigo: Dictionary = inimigos[indice]
		var id_inimigo := str(inimigo.get("id", ""))
		var selecionado := str(dados.get("alvo", "alvo")) == "todos" or id_inimigo == alvo_id
		if not selecionado or int(inimigo.get("vida", 0)) <= 0:
			continue
		if id_inimigo == alvo_id:
			alvo_encontrado = true
		var defesa := maxi(0, int(inimigo.get("defesa", 0)))
		var vida_base := maxi(1, int(inimigo.get("vidaMaxima", inimigo.get("vida", 1))))
		var dano_calculado: float = float(vida_base) * float(dados.get("multiplicador", 1.0)) - float(defesa) * 0.5
		var dano := maxi(1, int(round(dano_calculado)))
		inimigo["vida"] = maxi(0, int(inimigo.get("vida", 0)) - dano)
		inimigos[indice] = inimigo
		danos.append({"id":id_inimigo,"dano":dano})
	if str(dados.get("alvo", "alvo")) != "todos" and not alvo_encontrado:
		return {"ok":false,"erro":"Alvo inválido para a Suprema."}
	var novo_estado: Dictionary = estado_original.duplicate(true)
	novo_estado["carga"] = 0
	novo_estado["pronta"] = false
	novo_estado["usos"] = int(novo_estado.get("usos", 0)) + 1
	return {"ok":true,"estadoSuprema":novo_estado,"inimigos":inimigos,"danos":danos,"efeitoVisual":dados.duplicate(true)}
