extends RefCounted
class_name SistemaSupremasClasses

## Catálogo autoritativo das Supremas de classe e sinergias.
## As Supremas de classe, de arma e combinadas são registros independentes.
const NIVEL_SUPREMA := 50
const NIVEL_SUPREMA_AVANCADA := 80

const DADOS: Dictionary = {
	"guerreiro": {
		"suprema": {"id":"ruptura_colossal","nome":"Ruptura Colossal","efeito":"impacto_terrestre","tipo":"dano_area","multiplicador":5.0,"descricao":"Um golpe brutal abre fissuras pelo campo de batalha."},
		"avancada": {"id":"juizo_do_tita","nome":"Juízo do Titã","efeito":"onda_sismica","tipo":"dano_area","multiplicador":7.0,"descricao":"Uma sequência de impactos culmina em uma onda sísmica devastadora."}
	},
	"cavaleiro": {
		"suprema": {"id":"fortaleza_celestial","nome":"Fortaleza Celestial","efeito":"barreira_celestial","tipo":"defesa_grupo","multiplicador":3.0,"descricao":"Ergue uma proteção colossal para todo o grupo."},
		"avancada": {"id":"baluarte_do_eterno","nome":"Baluarte do Eterno","efeito":"contra_ataque_sagrado","tipo":"defesa_contra_ataque","multiplicador":5.5,"descricao":"Absorve o impacto inimigo e o devolve em uma contraofensiva."}
	},
	"assassino": {
		"suprema": {"id":"execucao_fantasma","nome":"Execução Fantasma","efeito":"sequencia_invisivel","tipo":"dano_unico_critico","multiplicador":5.2,"descricao":"Uma sequência quase invisível de golpes atinge um único alvo."},
		"avancada": {"id":"mil_cortes_silenciosos","nome":"Mil Cortes Silenciosos","efeito":"ecos_sombrios","tipo":"dano_unico_critico","multiplicador":7.5,"descricao":"Ecos sombrios repetem os cortes antes que o alvo perceba o primeiro."}
	},
	"arqueiro": {
		"suprema": {"id":"chuva_do_apocalipse","nome":"Chuva do Apocalipse","efeito":"chuva_de_flechas","tipo":"dano_area","multiplicador":4.8,"descricao":"Uma flecha colossal se divide em uma tempestade de projéteis."},
		"avancada": {"id":"firmamento_estilhacado","nome":"Firmamento Estilhaçado","efeito":"firmamento_de_flechas","tipo":"dano_area","multiplicador":7.2,"descricao":"Uma salva cobre o céu e cai sobre todos os inimigos."}
	},
	"mago": {
		"suprema": {"id":"cataclismo_elemental","nome":"Cataclismo Elemental","efeito":"colisao_elemental","tipo":"dano_area","multiplicador":5.4,"descricao":"Elementos convergem em uma explosão arcana de grande escala."},
		"avancada": {"id":"colapso_dos_elementos","nome":"Colapso dos Elementos","efeito":"singularidade_elemental","tipo":"dano_area","multiplicador":7.8,"descricao":"Os elementos entram em colapso e liberam uma ruptura de energia."}
	},
	"curandeiro": {
		"suprema": {"id":"milagre_divino","nome":"Milagre Divino","efeito":"aurora_restauradora","tipo":"cura_protecao_grupo","multiplicador":3.5,"descricao":"Uma luz restaura o grupo e concede proteção sagrada."},
		"avancada": {"id":"renascimento_primordial","nome":"Renascimento Primordial","efeito":"renascimento_luminoso","tipo":"cura_protecao_grupo","multiplicador":5.5,"descricao":"Uma onda vital restaura profundamente os aliados e os protege."}
	},
	"monge": {
		"suprema": {"id":"punho_do_dragao_ancestral","nome":"Punho do Dragão Ancestral","efeito":"onda_de_chi_draconica","tipo":"dano_area","multiplicador":5.1,"descricao":"A energia interior assume a forma de um dragão e atravessa o campo."},
		"avancada": {"id":"coracao_do_dragao","nome":"Coração do Dragão","efeito":"explosao_de_chi","tipo":"dano_area","multiplicador":7.4,"descricao":"Todo o chi é liberado em uma onda que rompe o terreno."}
	},
	"invocador": {
		"suprema": {"id":"legiao_dos_condenados","nome":"Legião dos Condenados","efeito":"legiao_espiritual","tipo":"invocacao_colossal","multiplicador":5.0,"descricao":"Uma entidade colossal convoca espíritos para lutar ao seu lado."},
		"avancada": {"id":"soberano_das_mil_almas","nome":"Soberano das Mil Almas","efeito":"exercito_ancestral","tipo":"invocacao_colossal","multiplicador":7.3,"descricao":"Uma presença ancestral comanda uma legião de espíritos."}
	},
	"espadachim": {
		"suprema": {"id":"dominio_absoluto","nome":"Domínio Absoluto","efeito":"tempestade_de_laminas","tipo":"dano_area","multiplicador":5.3,"descricao":"Uma sequência perfeita de cortes rasga o campo de batalha; o estilo visual acompanha a espada equipada."},
		"avancada": {"id":"corte_do_horizonte","nome":"Corte do Horizonte","efeito":"fenda_do_horizonte","tipo":"dano_area","multiplicador":7.8,"descricao":"Um único movimento abre uma fenda de energia que atravessa o campo."}
	}
}

## Combinações deliberadamente explícitas: possuir uma arma Suprema não libera
## automaticamente uma fusão; é necessária uma sinergia definida para a classe.
const COMBINACOES: Array = [
	{"id":"dominio_enma","classe":"espadachim","arma":"enma","nome":"Domínio Absoluto: Liberação de Enma","efeito":"tempestade_haki_roxo","multiplicador":9.0,"descricao":"O Domínio Absoluto se une à liberação de Haki de Enma."},
	{"id":"santoryu_asura_absoluto","classe":"espadachim","arma":"tripla_katana","nome":"Santoryu: Asura Absoluto","efeito":"asura_triplo_dimensional","multiplicador":10.0,"descricao":"O Domínio Absoluto converge nas três lâminas do Santoryu."},
	{"id":"dominio_yoru","classe":"espadachim","arma":"yoru","nome":"Domínio Absoluto: Eclipse Negro","efeito":"eclipse_de_laminas","multiplicador":9.2,"descricao":"O corte do Espadachim é ampliado pela lâmina negra Yoru."}
]

static func obter_dados(classe_id: String) -> Dictionary:
	return DADOS.get(classe_id.strip_edges().to_lower(), {}).duplicate(true)

static func obter_combinacao(classe_id: String, arma_id: String) -> Dictionary:
	for combinacao in COMBINACOES:
		if str(combinacao.get("classe", "")) == classe_id.strip_edges().to_lower() and str(combinacao.get("arma", "")) == arma_id.strip_edges().to_lower():
			return combinacao.duplicate(true)
	return {}

static func criar_estado(classe_id: String, nivel: int, arma_id: String = "") -> Dictionary:
	var dados := obter_dados(classe_id)
	if dados.is_empty():
		return {}
	var nivel_seguro := maxi(1, nivel)
	var primeira: Dictionary = dados["suprema"].duplicate(true)
	var avancada: Dictionary = dados["avancada"].duplicate(true)
	primeira["nivelDesbloqueio"] = NIVEL_SUPREMA
	primeira["desbloqueada"] = nivel_seguro >= NIVEL_SUPREMA
	avancada["nivelDesbloqueio"] = NIVEL_SUPREMA_AVANCADA
	avancada["desbloqueada"] = nivel_seguro >= NIVEL_SUPREMA_AVANCADA
	return {
		"classeId":classe_id,
		"nivelPersonagem":nivel_seguro,
		"suprema":_criar_carga(primeira),
		"avancada":_criar_carga(avancada),
		"combinacao":obter_combinacao(classe_id, arma_id),
		"armaId":arma_id
	}

static func atualizar_nivel(estado_original: Dictionary, nivel: int) -> Dictionary:
	if estado_original.is_empty():
		return {}
	var estado := estado_original.duplicate(true)
	var dados := obter_dados(str(estado.get("classeId", "")))
	if dados.is_empty():
		return {}
	var nivel_seguro := maxi(1, nivel)
	estado["nivelPersonagem"] = nivel_seguro
	var primeira: Dictionary = estado.get("suprema", {}).duplicate(true)
	var avancada: Dictionary = estado.get("avancada", {}).duplicate(true)
	primeira["desbloqueada"] = nivel_seguro >= NIVEL_SUPREMA
	avancada["desbloqueada"] = nivel_seguro >= NIVEL_SUPREMA_AVANCADA
	estado["suprema"] = primeira
	estado["avancada"] = avancada
	return estado

static func _criar_carga(dados: Dictionary) -> Dictionary:
	var estado := dados.duplicate(true)
	estado["carga"] = 0
	estado["cargaMaxima"] = 100
	estado["pronta"] = false
	estado["usos"] = 0
	return estado
