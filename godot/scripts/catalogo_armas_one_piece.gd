extends RefCounted
class_name CatalogoArmasOnePiece

## Catálogo-base. Números de dano, passivas e técnicas serão balanceados na etapa de combate.
const ARMAS := [
	{"id":"kiribachi","nome":"Kiribachi","personagem":"Arlong","raridade":"comum","categoria":"espada"},
	{"id":"same_kiri_bocho","nome":"Same-kiri Bocho","personagem":"Bastille","raridade":"comum","categoria":"espada"},
	{"id":"espadas_nakiri","nome":"Espadas Nakiri","personagem":"Johnny e Yosaku","raridade":"comum","categoria":"par_de_espadas"},
	{"id":"patas_de_gato","nome":"Patas de Gato","personagem":"Kuro","raridade":"comum","categoria":"garras"},
	{"id":"daisenso","nome":"Daisenso","personagem":"Krieg","raridade":"comum","categoria":"arma"},
	{"id":"bamboo","nome":"Bamboo","personagem":"T-Bone","raridade":"comum","categoria":"espada"},
	{"id":"nonosama_bo","nome":"Nonosama Bo","personagem":"Enel","raridade":"comum","categoria":"bastao"},
	{"id":"sukesan_kakusan","nome":"Sukesan e Kakusan","personagem":"Kin'emon","raridade":"comum","categoria":"espadas"},
	{"id":"franken","nome":"Franken","personagem":"Franky","raridade":"comum","categoria":"arma"},
	{"id":"eisen_whip","nome":"Eisen Whip","personagem":"Z","raridade":"comum","categoria":"chicote"},
	{"id":"bruiser_axe","nome":"Bruiser Axe","personagem":"Brogy","raridade":"comum","categoria":"machado"},
	{"id":"kashu","nome":"Kashu","personagem":"Tashigi","raridade":"rara","categoria":"espada"},
	{"id":"yubashiri","nome":"Yubashiri","personagem":"Zoro","raridade":"rara","categoria":"espada","observacao":"Destruída na história; disponível no jogo."},
	{"id":"yamaoroshi","nome":"Yamaoroshi","personagem":"Tashigi","raridade":"rara","categoria":"espada"},
	{"id":"shigure","nome":"Shigure","personagem":"Tashigi","raridade":"rara","categoria":"espada"},
	{"id":"sandai_kitetsu","nome":"Sandai Kitetsu","personagem":"Zoro","raridade":"rara","categoria":"espada"},
	{"id":"kirisame","nome":"Kirisame","personagem":"Hody Jones","raridade":"rara","categoria":"espada","observacao":"Destruída na história; disponível no jogo."},
	{"id":"terry_sword","nome":"Terry Sword","personagem":"Dorry","raridade":"rara","categoria":"espada"},
	{"id":"warabide","nome":"Warabide","personagem":"Basil Hawkins","raridade":"rara","categoria":"espada"},
	{"id":"kessui","nome":"Kessui","personagem":"Hannyabal","raridade":"rara","categoria":"arma"},
	{"id":"soto_muso","nome":"Soto Muso","personagem":"Kawamatsu","raridade":"rara","categoria":"espada"},
	{"id":"takeru","nome":"Takeru","personagem":"Yamato","raridade":"rara","categoria":"arma"},
	{"id":"mogura","nome":"Mogura","personagem":"Katakuri","raridade":"rara","categoria":"tridente"},
	{"id":"napoleon","nome":"Napoleon","personagem":"Big Mom","raridade":"rara","categoria":"espada_viva"},
	{"id":"punishers","nome":"Punishers","personagem":"Killer","raridade":"rara","categoria":"foices"},
	{"id":"wado_ichimonji","nome":"Wado Ichimonji","personagem":"Zoro","raridade":"lendaria","categoria":"espada"},
	{"id":"shusui","nome":"Shusui","personagem":"Zoro / Ryuma","raridade":"lendaria","categoria":"espada"},
	{"id":"nidai_kitetsu","nome":"Nidai Kitetsu","personagem":"Kozuki Sukiyaki","raridade":"lendaria","categoria":"espada"},
	{"id":"enma","nome":"Enma","personagem":"Zoro / Oden","raridade":"lendaria","categoria":"espada"},
	{"id":"ame_no_habakiri","nome":"Ame no Habakiri","personagem":"Oden","raridade":"lendaria","categoria":"espada"},
	{"id":"rai u","nome":"Raiu","personagem":"Shiryu","raridade":"lendaria","categoria":"espada"},
	{"id":"durandal","nome":"Durandal","personagem":"Cavendish","raridade":"lendaria","categoria":"espada"},
	{"id":"soul_solid","nome":"Soul Solid","personagem":"Brook","raridade":"lendaria","categoria":"bengala_espada"},
	{"id":"pretzel","nome":"Pretzel","personagem":"Cracker","raridade":"lendaria","categoria":"espada"},
	{"id":"shirauo","nome":"Shirauo","personagem":"Charlotte Amande","raridade":"lendaria","categoria":"espada"},
	{"id":"oto","nome":"Oto","personagem":"Shiki","raridade":"lendaria","categoria":"espada"},
	{"id":"kogarashi","nome":"Kogarashi","personagem":"Shiki","raridade":"lendaria","categoria":"espada"},
	{"id":"funkfreed","nome":"Funkfreed","personagem":"Spandam","raridade":"lendaria","categoria":"espada_zou"},
	{"id":"yakuza_kasen","nome":"Yakuza Kasen","personagem":"Fujitora","raridade":"mitica","categoria":"espada"},
	{"id":"espada_rayleigh","nome":"Espada de Silvers Rayleigh","personagem":"Silvers Rayleigh","raridade":"mitica","categoria":"espada","nomeOficialDesconhecido":true},
	{"id":"espadas_vista","nome":"Espadas de Vista","personagem":"Vista","raridade":"mitica","categoria":"par_de_espadas","nomeOficialDesconhecido":true},
	{"id":"espada_sukiyaki","nome":"Espada de Kozuki Sukiyaki","personagem":"Kozuki Sukiyaki","raridade":"mitica","categoria":"espada","nomeOficialDesconhecido":true},
	{"id":"gryphon","nome":"Gryphon","personagem":"Shanks","raridade":"mitica","categoria":"espada","especialSupremo":true},
	{"id":"kikoku","nome":"Kikoku","personagem":"Trafalgar Law","raridade":"mitica","categoria":"nodachi","especialSupremo":true},
	{"id":"murakumogiri","nome":"Murakumogiri (Bisento)","personagem":"Barba Branca","raridade":"suprema","categoria":"bisento","especialSupremo":true},
	{"id":"ace","nome":"Ace","personagem":"Gol D. Roger","raridade":"suprema","categoria":"espada","especialSupremo":true},
	{"id":"shodai_kitetsu","nome":"Shodai Kitetsu","personagem":"Portador não confirmado oficialmente","raridade":"suprema","categoria":"espada","especialSupremo":true},
	{"id":"yoru","nome":"Yoru","personagem":"Dracule Mihawk","raridade":"suprema","categoria":"espada_negra","especialSupremo":true},
	{"id":"tripla_katana","nome":"Tripla Katana","personagem":"Roronoa Zoro","raridade":"suprema","categoria":"conjunto_santoryu","especialSupremo":true,"obtencao":"combinacao","exige":["wado_ichimonji","sandai_kitetsu","enma"],"quantidadeEspacosInventario":1}
]

static func listar_todas() -> Array:
	return ARMAS.duplicate(true)

static func listar_para_drop() -> Array:
	var resultado: Array = []
	for arma in ARMAS:
		if str(arma.get("obtencao", "drop")) != "combinacao":
			resultado.append(arma.duplicate(true))
	return resultado

static func obter(id: String) -> Dictionary:
	for arma in ARMAS:
		if str(arma.get("id", "")) == id.strip_edges().to_lower():
			return arma.duplicate(true)
	return {}

## Valida a receita sem consumir itens. O consumo deve ser transacional no servidor.
static func validar_receita_tripla(inventario: Dictionary) -> Dictionary:
	var exigidas := ["wado_ichimonji", "sandai_kitetsu", "enma"]
	for id in exigidas:
		if int(inventario.get(id, 0)) < 1:
			return {"ok": false, "faltando": id, "mensagem": "Falta possuir %s para combinar a Tripla Katana." % str(obter(id).get("nome", id))}
	return {"ok": true, "consumir": exigidas, "equipamento": obter("tripla_katana")}
