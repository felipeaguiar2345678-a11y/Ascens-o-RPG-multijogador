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

const CARGA_POR_TURNO := 12
const CARGA_POR_ACAO := 8
const SistemaSupremasArmas = preload("res://scripts/sistema_supremas_one_piece.gd")

static func carregar_por_turno(estado_original: Dictionary) -> Dictionary:
	return _carregar(estado_original, CARGA_POR_TURNO)

static func carregar_por_acao(estado_original: Dictionary) -> Dictionary:
	return _carregar(estado_original, CARGA_POR_ACAO)

static func _carregar(estado_original: Dictionary, quantidade: int) -> Dictionary:
	if estado_original.is_empty():
		return {}
	var estado := estado_original.duplicate(true)
	for chave in ["suprema", "avancada"]:
		var habilidade: Dictionary = estado.get(chave, {}).duplicate(true)
		if habilidade.is_empty() or not bool(habilidade.get("desbloqueada", false)):
			continue
		habilidade["carga"] = mini(int(habilidade.get("cargaMaxima", 100)), int(habilidade.get("carga", 0)) + quantidade)
		habilidade["pronta"] = int(habilidade["carga"]) >= int(habilidade.get("cargaMaxima", 100))
		estado[chave] = habilidade
	return estado

## Executa a Suprema de classe escolhida. A combinada consome também a Suprema
## da arma; as duas cargas permanecem independentes das demais habilidades.
static func executar(estado_original: Dictionary, tipo: String, inimigos_originais: Array, alvo_id: String, suprema_arma: Dictionary = {}) -> Dictionary:
	if estado_original.is_empty() or inimigos_originais.is_empty():
		return {"ok":false,"erro":"Estado de Suprema inválido."}
	var estado := estado_original.duplicate(true)
	var chave := "suprema" if tipo == "suprema_classe" else ("avancada" if tipo == "suprema_avancada" else "combinacao")
	var habilidade: Dictionary = estado.get(chave, {}).duplicate(true)
	var dados: Dictionary = habilidade
	var estado_arma_resultado: Dictionary = suprema_arma.duplicate(true)
	if chave == "combinacao":
		dados = estado.get("combinacao", {}).duplicate(true)
		if dados.is_empty():
			return {"ok":false,"erro":"Esta classe e arma não possuem uma combinação especial."}
		if not bool(estado.get("suprema", {}).get("pronta", false)):
			return {"ok":false,"erro":"Carregue a Suprema da classe antes da combinação."}
		if suprema_arma.is_empty() or not bool(suprema_arma.get("pronta", false)):
			return {"ok":false,"erro":"A Suprema da arma também precisa estar carregada."}
		var arma_id := str(suprema_arma.get("armaId", ""))
		if SistemaSupremasArmas.obter_dados(arma_id).is_empty():
			return {"ok":false,"erro":"A arma equipada não possui uma Suprema própria."}
		estado_arma_resultado = suprema_arma.duplicate(true)
		estado_arma_resultado["carga"] = 0
		estado_arma_resultado["pronta"] = false
		estado_arma_resultado["usos"] = int(estado_arma_resultado.get("usos", 0)) + 1
	else:
		if habilidade.is_empty() or not bool(habilidade.get("desbloqueada", false)):
			return {"ok":false,"erro":"Esta Suprema ainda não foi desbloqueada."}
		if not bool(habilidade.get("pronta", false)):
			return {"ok":false,"erro":"A Suprema ainda não está carregada."}
	var inimigos: Array = inimigos_originais.duplicate(true)
	var danos: Array = []
	var alvo_encontrado := false
	var tipo_efeito := str(dados.get("tipo", ""))
	var causa_dano := tipo_efeito in ["dano_area", "dano_unico_critico", "invocacao_colossal"] or chave == "combinacao"
	var alvo_tipo := "todos" if tipo_efeito in ["dano_area", "invocacao_colossal"] or chave == "combinacao" else "alvo"
	var cura_jogador := 0
	var escudo_jogador := 0
	var invocacao_suprema: Dictionary = {}
	if tipo_efeito == "cura_protecao_grupo":
		cura_jogador = 45
		escudo_jogador = 20
	elif tipo_efeito in ["defesa_grupo", "defesa_contra_ataque"]:
		escudo_jogador = 45 if tipo_efeito == "defesa_grupo" else 35
	elif tipo_efeito == "invocacao_colossal":
		invocacao_suprema = {"id":"entidade_suprema_%s" % str(dados.get("id", "")), "nome":str(dados.get("nome", "Entidade Suprema")), "vida":100, "vidaMaxima":100, "ataque":int(round(float(dados.get("multiplicador", 5.0)) * 10.0)), "ativa":true, "origem":"suprema_classe"}
	if causa_dano:
		for i in range(inimigos.size()):
			var inimigo: Dictionary = inimigos[i]
			if int(inimigo.get("vida", 0)) <= 0:
				continue
			var id_inimigo := str(inimigo.get("id", ""))
			if alvo_tipo == "alvo" and id_inimigo != alvo_id:
				continue
			if id_inimigo == alvo_id:
				alvo_encontrado = true
			var vida_base := maxi(1, int(inimigo.get("vidaMaxima", inimigo.get("vida", 1))))
			var defesa := maxi(0, int(inimigo.get("defesa", 0)))
			var multiplicador := float(dados.get("multiplicador", 1.0))
			var dano := maxi(1, int(round(float(vida_base) * multiplicador - float(defesa) * 0.5)))
			if chave == "combinacao":
				dano = mini(maxi(1, dano), maxi(1, int(inimigo.get("vida", 1))))
			var aplicado := mini(dano, int(inimigo.get("vida", 0)))
			inimigo["vida"] = maxi(0, int(inimigo.get("vida", 0)) - aplicado)
			inimigos[i] = inimigo
			danos.append({"id":id_inimigo,"dano":aplicado})
	if causa_dano and alvo_tipo == "alvo" and not alvo_encontrado:
		return {"ok":false,"erro":"Alvo inválido para esta Suprema."}
	if chave == "combinacao":
		habilidade = estado.get("suprema", {}).duplicate(true)
	else:
		habilidade["carga"] = 0
		habilidade["pronta"] = false
		habilidade["usos"] = int(habilidade.get("usos", 0)) + 1
		estado[chave] = habilidade
	if chave == "combinacao":
		habilidade["carga"] = 0
		habilidade["pronta"] = false
		habilidade["usos"] = int(habilidade.get("usos", 0)) + 1
		estado["suprema"] = habilidade
	return {
		"ok":true,"estadoSupremasClasse":estado,"estadoSupremaArma":estado_arma_resultado,
		"inimigos":inimigos,"danos":danos,"efeitoVisual":dados.duplicate(true),
		"curaJogador":cura_jogador,"escudoJogador":escudo_jogador,"invocacaoSuprema":invocacao_suprema
	}

static func _criar_carga(dados: Dictionary) -> Dictionary:
	var estado := dados.duplicate(true)
	estado["carga"] = 0
	estado["cargaMaxima"] = 100
	estado["pronta"] = false
	estado["usos"] = 0
	return estado
