extends RefCounted
class_name GeradorEquipamentosCriaturas

## Gera projetos determinísticos de equipamento a partir dos traços de uma criatura.
## A rolagem e os atributos são calculados no servidor; não chama serviços pagos.
## O cache em memória evita recriar o mesmo projeto durante a sessão do processo.

const CatalogoGerados = preload("res://scripts/catalogo_equipamentos_gerados.gd")
static var CACHE: Dictionary = {}

const ELEMENTOS := {
	"fogo": {"material":"escama ígnea","prefixo":"Flamejante","atributo":"forca","efeito":"brasas"},
	"gelo": {"material":"cristal glacial","prefixo":"Glacial","atributo":"inteligencia","efeito":"congelamento"},
	"veneno": {"material":"quitina tóxica","prefixo":"Peçonhento","atributo":"agilidade","efeito":"veneno"},
	"raio": {"material":"núcleo elétrico","prefixo":"Tempestuoso","atributo":"agilidade","efeito":"eletricidade"},
	"terra": {"material":"minério pétreo","prefixo":"Rochedo","atributo":"vitalidade","efeito":"impacto"},
	"arcano": {"material":"cristal arcano","prefixo":"Rúnico","atributo":"inteligencia","efeito":"energia_arcana"},
	"sombra": {"material":"essência umbral","prefixo":"Umbral","atributo":"espirito","efeito":"dreno"},
	"agua": {"material":"pérola abissal","prefixo":"Abissal","atributo":"espirito","efeito":"maré"}
}

const FORMAS := {
	"arma": {"nome":"Lâmina","tipo":"arma","categoria":"fisica","slot":"mao_principal","maos":1,"dano":10},
	"armadura": {"nome":"Couraça","tipo":"armadura","categoria":"medio","slot":"torso","defesa":6,"peso":2},
	"escudo": {"nome":"Égide","tipo":"escudo","categoria":"medio","slot":"mao_secundaria","defesa":7},
	"acessorio": {"nome":"Relicário","tipo":"acessorio","categoria":"reliquia","slot":"bracelete","bonus":{}}
}

static func criar_projeto(criatura: Dictionary, nivel_jogador: int, semente: int = 0, forma: String = "arma") -> Dictionary:
	var criatura_id := str(criatura.get("id", "")).strip_edges().to_lower()
	if criatura_id.is_empty() or not FORMAS.has(forma):
		return {}
	var elemento := str(criatura.get("elemento", criatura.get("afinidade", "fisico"))).to_lower()
	if not ELEMENTOS.has(elemento):
		elemento = "arcano" if str(criatura.get("tipo", "")) == "magico" else "terra"
	var rank := str(criatura.get("rank", "E")).to_upper()
	var raridade := _raridade_por_rank(rank)
	var nivel := clampi(nivel_jogador, 1, 100)
	var chave := "%s|%s|%s|%s|%d|%d" % [criatura_id, elemento, forma, raridade, nivel, semente]
	if CACHE.has(chave):
		return CACHE[chave].duplicate(true)
	var traco: Dictionary = ELEMENTOS[elemento]
	var base: Dictionary = FORMAS[forma].duplicate(true)
	var multiplicador := _multiplicador_raridade(raridade)
	var escala := 1.0 + float(nivel - 1) * 0.035
	var atributo := str(traco["atributo"])
	var nome_criatura := str(criatura.get("nome", "Criatura"))
	var nome := "%s %s de %s" % [str(traco["prefixo"]), str(base["nome"]), nome_criatura]
	var id := "gerado_%s_%s_%s_%s" % [_slug(criatura_id), elemento, forma, raridade]
	var item := base.duplicate(true)
	item["id"] = id
	item["nome"] = nome
	item["raridade"] = raridade
	item["nivelRequerido"] = maxi(1, nivel - 2)
	item["origemCriaturaId"] = criatura_id
	item["origemEspecieId"] = str(criatura.get("especieId", criatura_id))
	item["elemento"] = elemento
	item["materialOrigem"] = str(traco["material"])
	item["atributoPrincipal"] = atributo
	item["efeitoEspecial"] = str(traco["efeito"])
	item["sementeProjeto"] = semente
	item["bonus"] = {}
	if forma == "arma":
		item["categoria"] = "hibrida" if elemento in ["fogo","gelo","raio","arcano","sombra","agua"] else "fisica"
		item["dano"] = clampi(roundi(float(base["dano"]) * escala * multiplicador), 1, 250)
		item["bonus"] = {atributo: maxi(1, roundi(float(nivel) * 0.08 * multiplicador))}
	elif forma == "armadura" or forma == "escudo":
		item["defesa"] = clampi(roundi(float(base["defesa"]) * escala * multiplicador), 1, 200)
		item["bonus"] = {atributo: maxi(1, roundi(float(nivel) * 0.04 * multiplicador))}
	else:
		item["bonus"] = {atributo: maxi(1, roundi(float(nivel) * 0.10 * multiplicador))}
	item["chaveCache"] = chave
	CACHE[chave] = item.duplicate(true)
	CatalogoGerados.registrar(item)
	return item


static func limpar_cache_sessao() -> void:
	CACHE.clear()


static func _raridade_por_rank(rank: String) -> String:
	match rank:
		"SSS", "SS": return "mitica"
		"S": return "lendaria"
		"A", "B": return "epica"
		"C", "D": return "rara"
		_: return "comum"


static func _multiplicador_raridade(raridade: String) -> float:
	match raridade:
		"comum": return 1.0
		"rara": return 1.25
		"epica": return 1.55
		"lendaria": return 1.9
		"mitica": return 2.3
		_: return 1.0


static func _slug(valor: String) -> String:
	var resultado := ""
	for caractere in valor:
		var codigo := caractere.unicode_at(0)
		if (codigo >= 48 and codigo <= 57) or (codigo >= 97 and codigo <= 122) or codigo == 95:
			resultado += caractere
		elif codigo >= 65 and codigo <= 90:
			resultado += caractere.to_lower()
		elif not resultado.ends_with("_"):
			resultado += "_"
	return resultado.trim_prefix("_").trim_suffix("_")
