extends RefCounted
class_name CatalogoVisualEquipamentos

## Registro visual único para todos os itens equipáveis cadastrados.
## Cada ID possui miniatura própria e, quando aplicável, arte de personagem equipada.
## Arquivos finais serão adicionados em assets/equipamentos; ausência não gera placeholder.

const RECURSOS := {
	"espada_ferro": {"inventario":"res://assets/equipamentos/inventario/espada_ferro.png","equipada":"res://assets/equipamentos/equipados/espada_ferro.png"},
	"machado_batalha": {"inventario":"res://assets/equipamentos/inventario/machado_batalha.png","equipada":"res://assets/equipamentos/equipados/machado_batalha.png"},
	"martelo_guerra": {"inventario":"res://assets/equipamentos/inventario/martelo_guerra.png","equipada":"res://assets/equipamentos/equipados/martelo_guerra.png"},
	"lanca_aco": {"inventario":"res://assets/equipamentos/inventario/lanca_aco.png","equipada":"res://assets/equipamentos/equipados/lanca_aco.png"},
	"adaga_dupla": {"inventario":"res://assets/equipamentos/inventario/adaga_dupla.png","equipada":"res://assets/equipamentos/equipados/adaga_dupla.png"},
	"arco_longo": {"inventario":"res://assets/equipamentos/inventario/arco_longo.png","equipada":"res://assets/equipamentos/equipados/arco_longo.png"},
	"manoplas_combate": {"inventario":"res://assets/equipamentos/inventario/manoplas_combate.png","equipada":"res://assets/equipamentos/equipados/manoplas_combate.png"},
	"foice_arcana": {"inventario":"res://assets/equipamentos/inventario/foice_arcana.png","equipada":"res://assets/equipamentos/equipados/foice_arcana.png"},
	"cajado_runico": {"inventario":"res://assets/equipamentos/inventario/cajado_runico.png","equipada":"res://assets/equipamentos/equipados/cajado_runico.png"},
	"varinha_luz": {"inventario":"res://assets/equipamentos/inventario/varinha_luz.png","equipada":"res://assets/equipamentos/equipados/varinha_luz.png"},
	"orbe_ancestral": {"inventario":"res://assets/equipamentos/inventario/orbe_ancestral.png","equipada":"res://assets/equipamentos/equipados/orbe_ancestral.png"},
	"grimorio_abissal": {"inventario":"res://assets/equipamentos/inventario/grimorio_abissal.png","equipada":"res://assets/equipamentos/equipados/grimorio_abissal.png"},
	"corrente_eterea": {"inventario":"res://assets/equipamentos/inventario/corrente_eterea.png","equipada":"res://assets/equipamentos/equipados/corrente_eterea.png"},
	"espada_runa": {"inventario":"res://assets/equipamentos/inventario/espada_runa.png","equipada":"res://assets/equipamentos/equipados/espada_runa.png"},
	"lanca_tempestade": {"inventario":"res://assets/equipamentos/inventario/lanca_tempestade.png","equipada":"res://assets/equipamentos/equipados/lanca_tempestade.png"},
	"arco_estelar": {"inventario":"res://assets/equipamentos/inventario/arco_estelar.png","equipada":"res://assets/equipamentos/equipados/arco_estelar.png"},
	"escudo_madeira": {"inventario":"res://assets/equipamentos/inventario/escudo_madeira.png","equipada":"res://assets/equipamentos/equipados/escudo_madeira.png"},
	"escudo_aco": {"inventario":"res://assets/equipamentos/inventario/escudo_aco.png","equipada":"res://assets/equipamentos/equipados/escudo_aco.png"},
	"escudo_baluarte": {"inventario":"res://assets/equipamentos/inventario/escudo_baluarte.png","equipada":"res://assets/equipamentos/equipados/escudo_baluarte.png"},
	"escudo_arcano": {"inventario":"res://assets/equipamentos/inventario/escudo_arcano.png","equipada":"res://assets/equipamentos/equipados/escudo_arcano.png"},
	"elmo_couro": {"inventario":"res://assets/equipamentos/inventario/elmo_couro.png","equipada":"res://assets/equipamentos/equipados/elmo_couro.png"},
	"elmo_placas": {"inventario":"res://assets/equipamentos/inventario/elmo_placas.png","equipada":"res://assets/equipamentos/equipados/elmo_placas.png"},
	"peitoral_couro": {"inventario":"res://assets/equipamentos/inventario/peitoral_couro.png","equipada":"res://assets/equipamentos/equipados/peitoral_couro.png"},
	"peitoral_malha": {"inventario":"res://assets/equipamentos/inventario/peitoral_malha.png","equipada":"res://assets/equipamentos/equipados/peitoral_malha.png"},
	"peitoral_placas": {"inventario":"res://assets/equipamentos/inventario/peitoral_placas.png","equipada":"res://assets/equipamentos/equipados/peitoral_placas.png"},
	"calcas_couro": {"inventario":"res://assets/equipamentos/inventario/calcas_couro.png","equipada":"res://assets/equipamentos/equipados/calcas_couro.png"},
	"grevas_aco": {"inventario":"res://assets/equipamentos/inventario/grevas_aco.png","equipada":"res://assets/equipamentos/equipados/grevas_aco.png"},
	"luvas_couro": {"inventario":"res://assets/equipamentos/inventario/luvas_couro.png","equipada":"res://assets/equipamentos/equipados/luvas_couro.png"},
	"manoplas_placas": {"inventario":"res://assets/equipamentos/inventario/manoplas_placas.png","equipada":"res://assets/equipamentos/equipados/manoplas_placas.png"},
	"botas_caminhante": {"inventario":"res://assets/equipamentos/inventario/botas_caminhante.png","equipada":"res://assets/equipamentos/equipados/botas_caminhante.png"},
	"botas_placas": {"inventario":"res://assets/equipamentos/inventario/botas_placas.png","equipada":"res://assets/equipamentos/equipados/botas_placas.png"},
	"manto_arcano": {"inventario":"res://assets/equipamentos/inventario/manto_arcano.png","equipada":"res://assets/equipamentos/equipados/manto_arcano.png"},
	"anel_poder": {"inventario":"res://assets/equipamentos/inventario/anel_poder.png","equipada":"res://assets/equipamentos/equipados/anel_poder.png"},
	"colar_mana": {"inventario":"res://assets/equipamentos/inventario/colar_mana.png","equipada":"res://assets/equipamentos/equipados/colar_mana.png"},
	"bracelete_runa": {"inventario":"res://assets/equipamentos/inventario/bracelete_runa.png","equipada":"res://assets/equipamentos/equipados/bracelete_runa.png"},
	"cinto_viajante": {"inventario":"res://assets/equipamentos/inventario/cinto_viajante.png","equipada":"res://assets/equipamentos/equipados/cinto_viajante.png"},
	"kiribachi": {"inventario":"res://assets/equipamentos/inventario/kiribachi.png","equipada":"res://assets/equipamentos/equipados/kiribachi.png"},
	"same_kiri_bocho": {"inventario":"res://assets/equipamentos/inventario/same_kiri_bocho.png","equipada":"res://assets/equipamentos/equipados/same_kiri_bocho.png"},
	"espadas_nakiri": {"inventario":"res://assets/equipamentos/inventario/espadas_nakiri.png","equipada":"res://assets/equipamentos/equipados/espadas_nakiri.png"},
	"patas_de_gato": {"inventario":"res://assets/equipamentos/inventario/patas_de_gato.png","equipada":"res://assets/equipamentos/equipados/patas_de_gato.png"},
	"daisenso": {"inventario":"res://assets/equipamentos/inventario/daisenso.png","equipada":"res://assets/equipamentos/equipados/daisenso.png"},
	"bamboo": {"inventario":"res://assets/equipamentos/inventario/bamboo.png","equipada":"res://assets/equipamentos/equipados/bamboo.png"},
	"nonosama_bo": {"inventario":"res://assets/equipamentos/inventario/nonosama_bo.png","equipada":"res://assets/equipamentos/equipados/nonosama_bo.png"},
	"sukesan_kakusan": {"inventario":"res://assets/equipamentos/inventario/sukesan_kakusan.png","equipada":"res://assets/equipamentos/equipados/sukesan_kakusan.png"},
	"franken": {"inventario":"res://assets/equipamentos/inventario/franken.png","equipada":"res://assets/equipamentos/equipados/franken.png"},
	"eisen_whip": {"inventario":"res://assets/equipamentos/inventario/eisen_whip.png","equipada":"res://assets/equipamentos/equipados/eisen_whip.png"},
	"bruiser_axe": {"inventario":"res://assets/equipamentos/inventario/bruiser_axe.png","equipada":"res://assets/equipamentos/equipados/bruiser_axe.png"},
	"kashu": {"inventario":"res://assets/equipamentos/inventario/kashu.png","equipada":"res://assets/equipamentos/equipados/kashu.png"},
	"yubashiri": {"inventario":"res://assets/equipamentos/inventario/yubashiri.png","equipada":"res://assets/equipamentos/equipados/yubashiri.png"},
	"yamaoroshi": {"inventario":"res://assets/equipamentos/inventario/yamaoroshi.png","equipada":"res://assets/equipamentos/equipados/yamaoroshi.png"},
	"shigure": {"inventario":"res://assets/equipamentos/inventario/shigure.png","equipada":"res://assets/equipamentos/equipados/shigure.png"},
	"sandai_kitetsu": {"inventario":"res://assets/equipamentos/inventario/sandai_kitetsu.png","equipada":"res://assets/equipamentos/equipados/sandai_kitetsu.png"},
	"kirisame": {"inventario":"res://assets/equipamentos/inventario/kirisame.png","equipada":"res://assets/equipamentos/equipados/kirisame.png"},
	"terry_sword": {"inventario":"res://assets/equipamentos/inventario/terry_sword.png","equipada":"res://assets/equipamentos/equipados/terry_sword.png"},
	"warabide": {"inventario":"res://assets/equipamentos/inventario/warabide.png","equipada":"res://assets/equipamentos/equipados/warabide.png"},
	"kessui": {"inventario":"res://assets/equipamentos/inventario/kessui.png","equipada":"res://assets/equipamentos/equipados/kessui.png"},
	"soto_muso": {"inventario":"res://assets/equipamentos/inventario/soto_muso.png","equipada":"res://assets/equipamentos/equipados/soto_muso.png"},
	"takeru": {"inventario":"res://assets/equipamentos/inventario/takeru.png","equipada":"res://assets/equipamentos/equipados/takeru.png"},
	"mogura": {"inventario":"res://assets/equipamentos/inventario/mogura.png","equipada":"res://assets/equipamentos/equipados/mogura.png"},
	"napoleon": {"inventario":"res://assets/equipamentos/inventario/napoleon.png","equipada":"res://assets/equipamentos/equipados/napoleon.png"},
	"punishers": {"inventario":"res://assets/equipamentos/inventario/punishers.png","equipada":"res://assets/equipamentos/equipados/punishers.png"},
	"wado_ichimonji": {"inventario":"res://assets/equipamentos/inventario/wado_ichimonji.png","equipada":"res://assets/equipamentos/equipados/wado_ichimonji.png"},
	"shusui": {"inventario":"res://assets/equipamentos/inventario/shusui.png","equipada":"res://assets/equipamentos/equipados/shusui.png"},
	"nidai_kitetsu": {"inventario":"res://assets/equipamentos/inventario/nidai_kitetsu.png","equipada":"res://assets/equipamentos/equipados/nidai_kitetsu.png"},
	"enma": {"inventario":"res://assets/equipamentos/inventario/enma.png","equipada":"res://assets/equipamentos/equipados/enma.png"},
	"ame_no_habakiri": {"inventario":"res://assets/equipamentos/inventario/ame_no_habakiri.png","equipada":"res://assets/equipamentos/equipados/ame_no_habakiri.png"},
	"raiu": {"inventario":"res://assets/equipamentos/inventario/raiu.png","equipada":"res://assets/equipamentos/equipados/raiu.png"},
	"durandal": {"inventario":"res://assets/equipamentos/inventario/durandal.png","equipada":"res://assets/equipamentos/equipados/durandal.png"},
	"soul_solid": {"inventario":"res://assets/equipamentos/inventario/soul_solid.png","equipada":"res://assets/equipamentos/equipados/soul_solid.png"},
	"pretzel": {"inventario":"res://assets/equipamentos/inventario/pretzel.png","equipada":"res://assets/equipamentos/equipados/pretzel.png"},
	"shirauo": {"inventario":"res://assets/equipamentos/inventario/shirauo.png","equipada":"res://assets/equipamentos/equipados/shirauo.png"},
	"oto": {"inventario":"res://assets/equipamentos/inventario/oto.png","equipada":"res://assets/equipamentos/equipados/oto.png"},
	"kogarashi": {"inventario":"res://assets/equipamentos/inventario/kogarashi.png","equipada":"res://assets/equipamentos/equipados/kogarashi.png"},
	"funkfreed": {"inventario":"res://assets/equipamentos/inventario/funkfreed.png","equipada":"res://assets/equipamentos/equipados/funkfreed.png"},
	"yakuza_kasen": {"inventario":"res://assets/equipamentos/inventario/yakuza_kasen.png","equipada":"res://assets/equipamentos/equipados/yakuza_kasen.png"},
	"espada_rayleigh": {"inventario":"res://assets/equipamentos/inventario/espada_rayleigh.png","equipada":"res://assets/equipamentos/equipados/espada_rayleigh.png"},
	"espadas_vista": {"inventario":"res://assets/equipamentos/inventario/espadas_vista.png","equipada":"res://assets/equipamentos/equipados/espadas_vista.png"},
	"espada_sukiyaki": {"inventario":"res://assets/equipamentos/inventario/espada_sukiyaki.png","equipada":"res://assets/equipamentos/equipados/espada_sukiyaki.png"},
	"gryphon": {"inventario":"res://assets/equipamentos/inventario/gryphon.png","equipada":"res://assets/equipamentos/equipados/gryphon.png"},
	"kikoku": {"inventario":"res://assets/equipamentos/inventario/kikoku.png","equipada":"res://assets/equipamentos/equipados/kikoku.png"},
	"murakumogiri": {"inventario":"res://assets/equipamentos/inventario/murakumogiri.png","equipada":"res://assets/equipamentos/equipados/murakumogiri.png"},
	"ace": {"inventario":"res://assets/equipamentos/inventario/ace.png","equipada":"res://assets/equipamentos/equipados/ace.png"},
	"shodai_kitetsu": {"inventario":"res://assets/equipamentos/inventario/shodai_kitetsu.png","equipada":"res://assets/equipamentos/equipados/shodai_kitetsu.png"},
	"yoru": {"inventario":"res://assets/equipamentos/inventario/yoru.png","equipada":"res://assets/equipamentos/equipados/yoru.png"},
	"tripla_katana": {"inventario":"res://assets/equipamentos/inventario/tripla_katana.png","equipada":"res://assets/equipamentos/equipados/tripla_katana.png"},
}

static func obter_caminho_miniatura(item_id: String) -> String:
	var dados: Dictionary = RECURSOS.get(item_id.strip_edges().to_lower(), {})
	return str(dados.get("inventario", ""))

static func obter_caminho_equipado(item_id: String) -> String:
	var dados: Dictionary = RECURSOS.get(item_id.strip_edges().to_lower(), {})
	return str(dados.get("equipada", ""))

static func possui_miniatura(item_id: String) -> bool:
	var caminho := obter_caminho_miniatura(item_id)
	return not caminho.is_empty() and ResourceLoader.exists(caminho)

static func possui_arte_equipada(item_id: String) -> bool:
	var caminho := obter_caminho_equipado(item_id)
	return not caminho.is_empty() and ResourceLoader.exists(caminho)

static func listar_ids() -> Array:
	return RECURSOS.keys()
