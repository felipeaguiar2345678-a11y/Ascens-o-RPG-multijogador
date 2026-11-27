extends RefCounted
class_name SistemaEquipamentos

const CatalogoArmasOnePiece = preload("res://scripts/catalogo_armas_one_piece.gd")
const CatalogoGerados = preload("res://scripts/catalogo_equipamentos_gerados.gd")

## Catálogo inicial de equipamento. IDs são estáveis para persistência e drops.
## Nenhum equipamento altera a anatomia racial do avatar.

const CATALOGO := {
	"espada_ferro": {"nome":"Espada de Ferro","tipo":"arma","categoria":"fisica","slot":"mao_principal","maos":1,"dano":12,"atributo":"forca"},
	"machado_batalha": {"nome":"Machado de Batalha","tipo":"arma","categoria":"fisica","slot":"mao_principal","maos":2,"dano":20,"atributo":"forca"},
	"martelo_guerra": {"nome":"Martelo de Guerra","tipo":"arma","categoria":"fisica","slot":"mao_principal","maos":2,"dano":22,"atributo":"forca"},
	"lanca_aco": {"nome":"Lança de Aço","tipo":"arma","categoria":"fisica","slot":"mao_principal","maos":2,"dano":17,"atributo":"forca"},
	"adaga_dupla": {"nome":"Adaga","tipo":"arma","categoria":"fisica","slot":"mao_principal","maos":1,"dano":8,"atributo":"agilidade"},
	"arco_longo": {"nome":"Arco Longo","tipo":"arma","categoria":"fisica","slot":"mao_principal","maos":2,"dano":15,"atributo":"agilidade"},
	"manoplas_combate": {"nome":"Manoplas de Combate","tipo":"arma","categoria":"fisica","slot":"mao_principal","maos":2,"dano":16,"atributo":"forca"},
	"foice_arcana": {"nome":"Foice Arcana","tipo":"arma","categoria":"magica","slot":"mao_principal","maos":2,"dano":24,"atributo":"inteligencia"},
	"cajado_runico": {"nome":"Cajado Rúnico","tipo":"arma","categoria":"magica","slot":"mao_principal","maos":2,"dano":18,"atributo":"inteligencia"},
	"varinha_luz": {"nome":"Varinha da Luz","tipo":"arma","categoria":"magica","slot":"mao_principal","maos":1,"dano":10,"atributo":"espirito"},
	"orbe_ancestral": {"nome":"Orbe Ancestral","tipo":"arma","categoria":"magica","slot":"mao_principal","maos":1,"dano":14,"atributo":"inteligencia"},
	"grimorio_abissal": {"nome":"Grimório Abissal","tipo":"arma","categoria":"magica","slot":"mao_principal","maos":1,"dano":13,"atributo":"inteligencia"},
	"corrente_eterea": {"nome":"Corrente Etérea","tipo":"arma","categoria":"magica","slot":"mao_principal","maos":2,"dano":19,"atributo":"espirito"},
	"espada_runa": {"nome":"Espada Rúnica","tipo":"arma","categoria":"hibrida","slot":"mao_principal","maos":1,"dano":17,"atributo":"forca"},
	"lanca_tempestade": {"nome":"Lança da Tempestade","tipo":"arma","categoria":"hibrida","slot":"mao_principal","maos":2,"dano":21,"atributo":"inteligencia"},
	"arco_estelar": {"nome":"Arco Estelar","tipo":"arma","categoria":"hibrida","slot":"mao_principal","maos":2,"dano":18,"atributo":"agilidade"},
	"escudo_madeira": {"nome":"Escudo de Madeira","tipo":"escudo","categoria":"leve","slot":"mao_secundaria","defesa":5,"classes":["guerreiro","cavaleiro","monge"]},
	"escudo_aco": {"nome":"Escudo de Aço","tipo":"escudo","categoria":"medio","slot":"mao_secundaria","defesa":12,"classes":["guerreiro","cavaleiro","monge"]},
	"escudo_baluarte": {"nome":"Escudo Baluarte","tipo":"escudo","categoria":"pesado","slot":"mao_secundaria","defesa":20,"classes":["guerreiro","cavaleiro"]},
	"escudo_arcano": {"nome":"Égide Arcana","tipo":"escudo","categoria":"magico","slot":"mao_secundaria","defesa":10,"classes":["guerreiro","cavaleiro","monge"]},
	"elmo_couro": {"nome":"Capuz de Couro","tipo":"armadura","categoria":"leve","slot":"cabeca","defesa":2,"peso":1},
	"elmo_placas": {"nome":"Elmo de Placas","tipo":"armadura","categoria":"pesado","slot":"cabeca","defesa":10,"peso":5},
	"peitoral_couro": {"nome":"Peitoral de Couro","tipo":"armadura","categoria":"leve","slot":"torso","defesa":5,"peso":2},
	"peitoral_malha": {"nome":"Cota de Malha","tipo":"armadura","categoria":"medio","slot":"torso","defesa":11,"peso":4},
	"peitoral_placas": {"nome":"Armadura de Placas","tipo":"armadura","categoria":"pesado","slot":"torso","defesa":20,"peso":8},
	"calcas_couro": {"nome":"Calças de Couro","tipo":"armadura","categoria":"leve","slot":"pernas","defesa":3,"peso":1},
	"grevas_aco": {"nome":"Grevas de Aço","tipo":"armadura","categoria":"pesado","slot":"pernas","defesa":9,"peso":5},
	"luvas_couro": {"nome":"Luvas de Couro","tipo":"armadura","categoria":"leve","slot":"maos","defesa":2,"peso":1},
	"manoplas_placas": {"nome":"Manoplas de Placas","tipo":"armadura","categoria":"pesado","slot":"maos","defesa":7,"peso":4},
	"botas_caminhante": {"nome":"Botas do Caminhante","tipo":"armadura","categoria":"leve","slot":"pes","defesa":2,"peso":1},
	"botas_placas": {"nome":"Botas de Placas","tipo":"armadura","categoria":"pesado","slot":"pes","defesa":8,"peso":4},
	"manto_arcano": {"nome":"Manto Arcano","tipo":"armadura","categoria":"medio","slot":"costas","defesa":6,"peso":2},
	"anel_poder": {"nome":"Anel do Poder","tipo":"acessorio","categoria":"anel","slot":"anel","bonus":{"forca":2}},
	"colar_mana": {"nome":"Colar de Mana","tipo":"acessorio","categoria":"colar","slot":"colar","bonus":{"manaMaxima":20}},
	"bracelete_runa": {"nome":"Bracelete Rúnico","tipo":"acessorio","categoria":"bracelete","slot":"bracelete","bonus":{"inteligencia":2}},
	"cinto_viajante": {"nome":"Cinto do Viajante","tipo":"acessorio","categoria":"cinto","slot":"cinto","bonus":{"vidaMaxima":10}}
}

const SLOTS := ["mao_principal","mao_secundaria","cabeca","torso","pernas","maos","pes","costas","anel","colar","bracelete","cinto"]
const CLASSES_CORPO_A_CORPO := ["guerreiro","cavaleiro","assassino","monge"]

static func obter(item_id: String) -> Dictionary:
	if CATALOGO.has(item_id):
		return CATALOGO[item_id].duplicate(true)
	var equipamento_gerado := CatalogoGerados.obter(item_id)
	if not equipamento_gerado.is_empty():
		return equipamento_gerado
	var arma_one_piece: Dictionary = CatalogoArmasOnePiece.obter(item_id)
	if arma_one_piece.is_empty():
		return {}
	var dano_por_raridade := {"comum":8,"rara":11,"lendaria":16,"mitica":22,"suprema":28}
	var categoria := str(arma_one_piece.get("categoria", "espada"))
	var maos := 2 if categoria in ["bisento", "conjunto_santoryu", "foices", "par_de_espadas"] else 1
	return {
		"nome":str(arma_one_piece.get("nome", item_id)),
		"tipo":"arma",
		"categoria":"fisica",
		"slot":"mao_principal",
		"maos":maos,
		"dano":int(dano_por_raridade.get(str(arma_one_piece.get("raridade", "comum")), 8)),
		"atributo":"forca",
		"origem":"one_piece",
		"raridade":str(arma_one_piece.get("raridade", "comum"))
	}

static func validar_equipar(equipamentos: Dictionary, item_id: String, classe_id: String) -> Dictionary:
	var item := obter(item_id)
	if item.is_empty():
		return {"ok":false,"erro":"Equipamento desconhecido."}
	var slot := str(item.get("slot", ""))
	if not SLOTS.has(slot):
		return {"ok":false,"erro":"Espaço de equipamento inválido."}
	if item.get("tipo") == "escudo":
		if not CLASSES_CORPO_A_CORPO.has(classe_id):
			return {"ok":false,"erro":"Somente classes de combate corpo a corpo podem usar escudos."}
		if not equipamentos.get("mao_principal", "").is_empty():
			var arma_principal := obter(str(equipamentos.get("mao_principal", "")))
			if arma_principal.is_empty() or int(arma_principal.get("maos", 1)) != 1:
				return {"ok":false,"erro":"Esse escudo exige uma arma de uma mão ou mão principal livre."}
	if item.get("tipo") == "arma":
		if int(item.get("maos", 1)) == 2 and not str(equipamentos.get("mao_secundaria", "")).is_empty():
			return {"ok":false,"erro":"Armas de duas mãos ocupam também a mão secundária."}
		if int(item.get("maos", 1)) == 1 and not str(equipamentos.get("mao_secundaria", "")).is_empty():
			var secundario := obter(str(equipamentos.get("mao_secundaria", "")))
			if secundario.get("tipo") != "escudo":
				return {"ok":false,"erro":"A mão secundária já está ocupada."}
	if slot == "mao_secundaria" and item.get("tipo") != "escudo":
		return {"ok":false,"erro":"A mão secundária é reservada para escudos."}
	if slot == "mao_principal" and int(item.get("maos", 1)) == 2 and not str(equipamentos.get("mao_secundaria", "")).is_empty():
		return {"ok":false,"erro":"Retire primeiro o escudo ou item da mão secundária."}
	return {"ok":true,"slot":slot,"item":item}

static func equipar(equipamentos: Dictionary, item_id: String, classe_id: String) -> Dictionary:
	var validacao := validar_equipar(equipamentos, item_id, classe_id)
	if not bool(validacao.get("ok", false)):
		return {"ok":false,"erro":str(validacao.get("erro", "Não foi possível equipar."))}
	var atualizado := equipamentos.duplicate(true)
	var item: Dictionary = validacao["item"]
	var slot := str(validacao["slot"])
	if slot == "mao_principal" and int(item.get("maos", 1)) == 2:
		atualizado["mao_secundaria"] = ""
	atualizado[slot] = item_id
	return {"ok":true,"equipamentos":atualizado,"slot":slot}

static func desequipar(equipamentos: Dictionary, slot: String) -> Dictionary:
	if not SLOTS.has(slot):
		return {"ok":false,"erro":"Espaço de equipamento inválido."}
	var atualizado := equipamentos.duplicate(true)
	atualizado[slot] = ""
	return {"ok":true,"equipamentos":atualizado}


## Calcula atributos derivados sem alterar os atributos-base persistidos.
## O servidor deve executar este cálculo antes de aplicar efeitos em combate.
static func calcular_atributos_efetivos(atributos_base: Dictionary, equipamentos: Dictionary) -> Dictionary:
	var efetivos := {
		"forca": maxi(0, int(atributos_base.get("forca", 5))),
		"inteligencia": maxi(0, int(atributos_base.get("inteligencia", 5))),
		"agilidade": maxi(0, int(atributos_base.get("agilidade", 5))),
		"vitalidade": maxi(0, int(atributos_base.get("vitalidade", 5))),
		"espirito": maxi(0, int(atributos_base.get("espirito", 5))),
		"vidaMaxima": maxi(1, int(atributos_base.get("vidaMaxima", 100))),
		"manaMaxima": maxi(0, int(atributos_base.get("manaMaxima", 50)))
	}
	var defesa_acessorios := 0
	for slot in SLOTS:
		var item_id := str(equipamentos.get(slot, ""))
		if item_id.is_empty():
			continue
		var item := obter(item_id)
		if item.is_empty():
			continue
		var bonus: Dictionary = item.get("bonus", {})
		for atributo in bonus:
			if efetivos.has(atributo):
				efetivos[atributo] = maxi(0, int(efetivos[atributo]) + int(bonus[atributo]))
		defesa_acessorios += int(item.get("bonus", {}).get("defesa", 0))
	var penalidades := calcular_penalidades(equipamentos, efetivos)
	efetivos["agilidade"] = int(penalidades["agilidade_efetiva"])
	efetivos["defesaEquipamento"] = int(penalidades["defesa"]) + defesa_acessorios
	efetivos["pesoEquipamento"] = int(penalidades["peso_total"])
	efetivos["penalidadeAgilidade"] = int(penalidades["penalidade_agilidade"])
	efetivos["velocidadePercentual"] = int(penalidades["velocidade_percentual"])
	return efetivos

static func calcular_penalidades(equipamentos: Dictionary, atributos: Dictionary) -> Dictionary:
	var defesa := 0
	var peso := 0
	var forca := int(atributos.get("forca", 5))
	var agilidade := int(atributos.get("agilidade", 5))
	var classe_bonus := 0
	for slot in SLOTS:
		var item := obter(str(equipamentos.get(slot, "")))
		if item.is_empty():
			continue
		defesa += int(item.get("defesa", 0))
		peso += int(item.get("peso", 0))
		if item.get("tipo") == "armadura":
			match str(item.get("categoria", "")):
				"leve":
					peso += 0
				"medio":
					peso += 1
				"pesado":
					peso += 3
	var limite := maxi(1, forca)
	var excesso := maxi(0, peso - limite)
	var penalidade_agilidade := mini(agilidade, excesso * 2)
	return {"defesa":defesa,"peso_total":peso,"penalidade_agilidade":penalidade_agilidade,"agilidade_efetiva":agilidade-penalidade_agilidade,"velocidade_percentual":maxi(50,100-excesso*5),"bonus_classe":classe_bonus}
