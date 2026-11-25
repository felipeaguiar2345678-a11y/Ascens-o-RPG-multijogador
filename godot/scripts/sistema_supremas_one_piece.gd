extends RefCounted
class_name SistemaSupremasOnePiece

## Regras autoritativas das Supremas. A apresentação nunca decide dano ou alvos.
const CARGA_MAXIMA := 100
const CARGA_POR_TURNO := 12
const CARGA_EXTRA_POR_ACAO := 8
const DADOS := {
	"murakumogiri": {"nome":"Fúria da Gura Gura","raridade":"suprema","efeito":"terremoto_dimensional","elemento":"onda_de_choque","multiplicador":5.0,"alvo":"todos","descricao":"A lâmina golpeia o ar e a arena se rompe em ondas sísmicas."},
	"yoru": {"nome":"Corte do Horizonte Negro","raridade":"suprema","efeito":"corte_colossal","elemento":"corte_negro","multiplicador":4.8,"alvo":"todos","descricao":"Um corte negro colossal atravessa o campo de batalha."},
	"ace": {"nome":"Vontade do Rei","raridade":"suprema","efeito":"corte_haki","elemento":"haki_do_rei","multiplicador":4.7,"alvo":"alvo","descricao":"Um golpe de Haki concentrado explode no ponto de impacto."},
	"shodai_kitetsu": {"nome":"Maldição Carmesim","raridade":"suprema","efeito":"corte_maldito","elemento":"energia_carmesim","multiplicador":4.6,"alvo":"alvo","descricao":"A lâmina libera uma onda cortante de energia amaldiçoada."},
	"tripla_katana": {"nome":"Santoryu: Asura","raridade":"suprema","efeito":"asura_triplo","elemento":"haki_triplo","multiplicador":5.2,"alvo":"todos","descricao":"Três lâminas e a pressão do Haki convergem em uma investida devastadora."},
	"gryphon": {"nome":"Kamusari","raridade":"mitica","efeito":"golpe_do_rei","elemento":"haki_do_rei","multiplicador":4.5,"alvo":"alvo","descricao":"Uma descarga de Haki do Rei acompanha o corte veloz."},
	"kikoku": {"nome":"ROOM: Corte Espacial","raridade":"mitica","efeito":"sala_espacial","elemento":"energia_azul","multiplicador":4.4,"alvo":"todos","descricao":"Uma zona espacial envolve o campo e separa os alvos com precisão."},
	"enma": {"nome":"Oni Giri do Rei","raridade":"lendaria","efeito":"liberacao_enma","elemento":"haki_roxo","multiplicador":3.8,"alvo":"alvo","descricao":"Enma libera uma descarga intensa de Haki."}
}

static func obter_dados(arma_id: String) -> Dictionary:
	return DADOS.get(arma_id.strip_edges().to_lower(), {}).duplicate(true)

static func pode_usar(arma_id: String) -> bool:
	var dados := obter_dados(arma_id)
	return not dados.is_empty() and str(dados.get("raridade", "")) in ["mitica", "suprema"]

static func criar_estado(arma_id: String) -> Dictionary:
	if not pode_usar(arma_id):
		return {}
	return {"armaId":arma_id.strip_edges().to_lower(),"carga":0,"pronta":false,"turnosCarregados":0,"acoesCarregadas":0,"usos":0}

static func carregar_por_turno(estado_original: Dictionary) -> Dictionary:
	if estado_original.is_empty():
		return {}
	var estado := estado_original.duplicate(true)
	estado["carga"] = mini(CARGA_MAXIMA, int(estado.get("carga", 0)) + CARGA_POR_TURNO)
	estado["turnosCarregados"] = int(estado.get("turnosCarregados", 0)) + 1
	estado["pronta"] = int(estado["carga"]) >= CARGA_MAXIMA
	return estado

static func carregar_por_acao(estado_original: Dictionary) -> Dictionary:
	if estado_original.is_empty():
		return {}
	var estado := estado_original.duplicate(true)
	estado["carga"] = mini(CARGA_MAXIMA, int(estado.get("carga", 0)) + CARGA_EXTRA_POR_ACAO)
	estado["acoesCarregadas"] = int(estado.get("acoesCarregadas", 0)) + 1
	estado["pronta"] = int(estado["carga"]) >= CARGA_MAXIMA
	return estado

## Executar apenas no servidor após validar turno, equipamento e alvo.
static func executar(estado_original: Dictionary, inimigos_originais: Array, alvo_id: String) -> Dictionary:
	if estado_original.is_empty() or not bool(estado_original.get("pronta", false)):
		return {"ok":false,"erro":"A Suprema ainda não está carregada."}
	var dados := obter_dados(str(estado_original.get("armaId", "")))
	if dados.is_empty():
		return {"ok":false,"erro":"Arma sem Suprema disponível."}
	var inimigos := inimigos_originais.duplicate(true)
	var dano_por_alvo: Array = []
	var alvo_encontrado := false
	for indice in range(inimigos.size()):
		var inimigo: Dictionary = inimigos[indice]
		var selecionado := str(dados.get("alvo", "alvo")) == "todos" or str(inimigo.get("id", "")) == alvo_id
		if not selecionado or int(inimigo.get("vida", 0)) <= 0:
			continue
		if str(inimigo.get("id", "")) == alvo_id:
			alvo_encontrado = true
		var defesa := maxi(0, int(inimigo.get("defesa", 0)))
		var dano := maxi(1, int(round(float(maxi(1, int(inimigo.get("vidaMaxima", inimigo.get("vida", 1)))) * float(dados.get("multiplicador", 1.0)) - float(defesa) * 0.5)))
		inimigo["vida"] = maxi(0, int(inimigo.get("vida", 0)) - dano)
		inimigos[indice] = inimigo
		dano_por_alvo.append({"id":str(inimigo.get("id", "")),"dano":dano})
	if str(dados.get("alvo", "alvo")) != "todos" and not alvo_encontrado:
		return {"ok":false,"erro":"Alvo inválido para a Suprema."}
	var novo_estado := estado_original.duplicate(true)
	novo_estado["carga"] = 0
	novo_estado["pronta"] = false
	novo_estado["usos"] = int(novo_estado.get("usos", 0)) + 1
	return {"ok":true,"estadoSuprema":novo_estado,"inimigos":inimigos,"danos":dano_por_alvo,"efeitoVisual":dados.duplicate(true)}
