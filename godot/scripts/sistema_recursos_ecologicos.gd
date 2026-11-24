extends RefCounted
## Recursos ambientais finitos e declarados pela ecologia das espécies.
## Não cria fontes de alimento nem permite consumo por espécies não autorizadas.
const SEGUNDOS_POR_DIA := 86400.0
const MAX_DIAS_POR_AVANCO := 3650.0
const MAXIMO_RECURSOS := 32

static func validar_configuracoes(configuracoes: Variant) -> bool:
	if not (configuracoes is Array) or configuracoes.size() > MAXIMO_RECURSOS:
		return false
	var ids := {}
	for config in configuracoes:
		if not (config is Dictionary):
			return false
		var id := str(config.get("id", "")).strip_edges()
		var capacidade := float(config.get("capacidade", -1.0))
		var inicial := float(config.get("quantidadeInicial", -1.0))
		var recuperacao := float(config.get("recuperacaoPorDia", -1.0))
		var consumo := float(config.get("consumoPorIndividuoDia", -1.0))
		var consumidores = config.get("especiesConsumidoras", [])
		if id.is_empty() or id.length() > 128 or ids.has(id):
			return false
		if not is_finite(capacidade) or not is_finite(inicial) or not is_finite(recuperacao) or not is_finite(consumo):
			return false
		if capacidade <= 0.0 or capacidade > 1000000000.0 or inicial < 0.0 or inicial > capacidade:
			return false
		if recuperacao < 0.0 or recuperacao > capacidade or consumo < 0.0 or consumo > capacidade:
			return false
		if not (consumidores is Array) or consumidores.size() > 128:
			return false
		var vistos := {}
		for especie_id in consumidores:
			var especie := str(especie_id)
			if especie.is_empty() or especie.length() > 128 or vistos.has(especie):
				return false
			vistos[especie] = true
		ids[id] = true
	return true

## Mede quanto uma cicatriz compromete a oferta natural dentro do território.
## A pressão cai junto com a recuperação temporal da marca.
static func calcular_pressao_habitat(marcas: Array, territorio: Dictionary, agora_unix: int) -> float:
	if territorio.is_empty():
		return 0.0
	var centro_dados: Dictionary = territorio.get("centro", {})
	var centro := Vector2(float(centro_dados.get("x", -10000.0)), float(centro_dados.get("y", -10000.0)))
	var raio_territorio := clampf(float(territorio.get("raio", 0.0)), 0.0, 1000.0)
	if centro.x < 0.0 or centro.y < 0.0 or raio_territorio <= 0.0:
		return 0.0
	var maior_pressao := 0.0
	for marca in marcas:
		if not (marca is Dictionary):
			continue
		var criado := int(marca.get("criadoUnix", 0))
		var expira := int(marca.get("expiraUnix", 0))
		if criado <= 0 or expira <= agora_unix or expira <= criado:
			continue
		var raio_marca := clampf(float(marca.get("raio", 0.0)), 0.0, 2000.0)
		if raio_marca <= 0.0:
			continue
		var centro_marca := Vector2(float(marca.get("x", -10000.0)), float(marca.get("y", -10000.0)))
		var distancia := maxf(0.0, centro.distance_to(centro_marca) - raio_territorio)
		if distancia >= raio_marca:
			continue
		var progresso := clampf(float(agora_unix - criado) / float(expira - criado), 0.0, 1.0)
		var recuperacao := progresso * progresso * (3.0 - 2.0 * progresso)
		var intensidade := clampf(float(marca.get("intensidade", 1.0)), 0.1, 1.0)
		var pressao := (1.0 - distancia / raio_marca) * intensidade * (1.0 - recuperacao)
		maior_pressao = maxf(maior_pressao, pressao)
	return clampf(maior_pressao, 0.0, 1.0)

## Confere também os dados persistidos; JSON válido não significa estado numérico íntegro.
static func validar_estado(estado: Variant, configuracoes: Array) -> bool:
	if not (estado is Dictionary) or not (estado.get("recursos", {}) is Dictionary) or not validar_configuracoes(configuracoes):
		return false
	var recursos: Dictionary = estado.get("recursos", {})
	if recursos.size() != configuracoes.size():
		return false
	for config in configuracoes:
		var id := str(config["id"])
		if not recursos.has(id) or not (recursos[id] is Dictionary):
			return false
		var fonte: Dictionary = recursos[id]
		var quantidade := float(fonte.get("quantidade", NAN))
		var ultima := int(fonte.get("ultimaAtualizacaoUnix", -1))
		if not is_finite(quantidade) or quantidade < 0.0 or quantidade > float(config["capacidade"]) or ultima < 0:
			return false
	return true

static func criar_estado(configuracoes: Array, agora_unix: int = -1) -> Dictionary:
	if not validar_configuracoes(configuracoes):
		return {}
	var agora := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	var recursos := {}
	for config in configuracoes:
		var id := str(config["id"])
		recursos[id] = {
			"quantidade":float(config["quantidadeInicial"]),
			"ultimaAtualizacaoUnix":agora
		}
	return {"recursos":recursos}

## Recupera os recursos e desconta a demanda declarada por indivíduo vivo.
## Retorna um índice de alimentação de 0..1 para modular a reprodução.
static func processar_periodo(estado: Dictionary, configuracoes: Array, especie_id: String, individuos_vivos: int, agora_unix: int) -> Dictionary:
	if not validar_estado(estado, configuracoes) or individuos_vivos < 0:
		return {"ok":false,"erro":"Estado ou configuração de recursos inválidos."}
	var atualizado := estado.duplicate(true)
	var recursos: Dictionary = atualizado.get("recursos", {})
	var demanda_total := 0.0
	var oferta_total := 0.0
	for config in configuracoes:
		var id := str(config["id"])
		if not recursos.has(id) or not (recursos[id] is Dictionary):
			return {"ok":false,"erro":"Fonte ambiental ausente no estado persistido."}
		var fonte: Dictionary = recursos[id].duplicate(true)
		var ultima := int(fonte.get("ultimaAtualizacaoUnix", -1))
		if ultima < 0 or agora_unix < ultima:
			return {"ok":false,"erro":"O relógio dos recursos não pode retroceder."}
		var dias := minf(float(agora_unix - ultima) / SEGUNDOS_POR_DIA, MAX_DIAS_POR_AVANCO)
		var capacidade := float(config["capacidade"])
		var quantidade := minf(capacidade, float(fonte.get("quantidade", -1.0)) + float(config["recuperacaoPorDia"]) * dias)
		var demanda := 0.0
		if config["especiesConsumidoras"].has(especie_id):
			demanda = float(config["consumoPorIndividuoDia"]) * float(individuos_vivos) * dias
			demanda_total += demanda
			oferta_total += quantidade
		var consumido := minf(quantidade, demanda)
		fonte["quantidade"] = maxf(0.0, quantidade - consumido)
		fonte["ultimaAtualizacaoUnix"] = agora_unix
		recursos[id] = fonte
	atualizado["recursos"] = recursos
	var disponibilidade := 1.0
	if demanda_total > 0.0:
		disponibilidade = clampf(oferta_total / demanda_total, 0.0, 1.0)
	return {"ok":true,"estado":atualizado,"disponibilidade":disponibilidade,"demanda":demanda_total,"oferta":oferta_total}

static func consumir_unidades(estado: Dictionary, configuracoes: Array, recurso_id: String, especie_id: String, quantidade: float) -> Dictionary:
	if quantidade <= 0.0 or not is_finite(quantidade) or not validar_configuracoes(configuracoes):
		return {"ok":false,"erro":"Consumo inválido."}
	var config_encontrada: Dictionary = {}
	for config in configuracoes:
		if str(config["id"]) == recurso_id:
			config_encontrada = config
			break
	if config_encontrada.is_empty() or not config_encontrada["especiesConsumidoras"].has(especie_id):
		return {"ok":false,"erro":"Esta espécie não tem autorização para consumir o recurso."}
	if not validar_estado(estado, configuracoes):
		return {"ok":false,"erro":"Estado ambiental persistido inválido."}
	var atualizado := estado.duplicate(true)
	var recursos: Dictionary = atualizado.get("recursos", {})
	if not recursos.has(recurso_id):
		return {"ok":false,"erro":"Recurso não encontrado."}
	var fonte: Dictionary = recursos[recurso_id].duplicate(true)
	var atual := float(fonte.get("quantidade", -1.0))
	if atual < quantidade or atual < 0.0:
		return {"ok":false,"erro":"Recurso insuficiente."}
	fonte["quantidade"] = atual - quantidade
	recursos[recurso_id] = fonte
	atualizado["recursos"] = recursos
	return {"ok":true,"estado":atualizado,"consumido":quantidade}
