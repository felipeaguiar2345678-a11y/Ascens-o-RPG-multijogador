extends RefCounted
## Liderança natural por grupo. Não cria espécies nem indivíduos.
## O mundo deve fornecer grupos e indivíduos persistidos pelo servidor.
const EQUIPAMENTOS = preload("res://scripts/sistema_equipamentos.gd")
const MULTIPLICADOR_MINIMO := 1.15
const MULTIPLICADOR_MAXIMO := 1.35
const MAX_EQUIPAMENTOS_LIDER := 6
const ATRIBUTOS := ["vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"]
const PADROES_CORPORAIS := ["listras de liderança", "manchas contrastantes", "faixa dorsal", "marcas ao redor dos olhos", "placas ou escamas ornamentadas", "crista natural"]
const MARCAS_DISTINTIVAS := ["marca na testa", "cicatriz cerimonial", "pontas brilhantes", "padrão facial exclusivo", "marca no peito", "ornamento natural"]
const ADERECOS_NATURAIS := ["crista elevada", "juba mais volumosa", "chifres ornamentados", "penas alongadas", "cauda com ponta luminosa", "escamas de destaque"]
const AURAS := ["brasa", "névoa", "faíscas", "ondas arcanas", "partículas", "halo pulsante"]
const CORES_AURA := ["#F2A65A", "#75D6C6", "#9B8CFF", "#E77FA8", "#8CCB75", "#78BCE8"]

static func validar_grupo(grupo: Variant) -> bool:
	return str(validar_grupo_detalhado(grupo).get("erro", "")).is_empty()

static func validar_grupo_detalhado(grupo: Variant) -> Dictionary:
	if not (grupo is Dictionary):
		return {"erro":"grupo_nao_e_dicionario"}
	var grupo_id := str(grupo.get("grupoId", "")).strip_edges()
	var especie_id := str(grupo.get("especieId", "")).strip_edges()
	var minimo := int(grupo.get("populacaoMinimaParaLider", 3))
	var individuos = grupo.get("individuos", [])
	if grupo_id.is_empty() or especie_id.is_empty() or minimo < 2 or minimo > 100000:
		return {"erro":"identidade_ou_minimo_invalido"}
	if not (individuos is Array) or individuos.size() > 10000:
		return {"erro":"lista_individuos_invalida"}
	var equipamentos_disponiveis = grupo.get("equipamentosLiderDisponiveis", [])
	if not (equipamentos_disponiveis is Array) or equipamentos_disponiveis.size() > 100:
		return {"erro":"lista_equipamentos_disponiveis_invalida"}
	for item_disponivel in equipamentos_disponiveis:
		if not EQUIPAMENTOS.CATALOGO.has(str(item_disponivel)):
			return {"erro":"equipamento_disponivel_desconhecido:" + str(item_disponivel)}
	var ids := {}
	for individuo in individuos:
		if not (individuo is Dictionary):
			return {"erro":"individuo_nao_e_dicionario"}
		var id := str(individuo.get("individuoId", "")).strip_edges()
		var atributos = individuo.get("atributos", {})
		var itens = individuo.get("equipamentoIds", [])
		if id.is_empty() or ids.has(id) or not (atributos is Dictionary) or not (itens is Array):
			return {"erro":"identidade_atributos_ou_itens_invalidos:" + id}
		ids[id] = true
		for atributo in ATRIBUTOS:
			var valor := int(atributos.get(atributo, 0))
			if valor < 0 or valor > 100000000:
				return {"erro":"atributo_invalido:" + atributo}
		if itens.size() > MAX_EQUIPAMENTOS_LIDER:
			return {"erro":"limite_de_equipamentos_excedido"}
		for item_id in itens:
			if not EQUIPAMENTOS.CATALOGO.has(str(item_id)):
				return {"erro":"equipamento_individual_desconhecido:" + str(item_id)}
	return {}

## Escolhe o indivíduo elegível de maior força total. Empates são resolvidos por ID.
## Uma população pequena não recebe líder artificialmente.
static func avaliar_grupo(grupo: Dictionary, semente: int = 0) -> Dictionary:
	if not validar_grupo(grupo):
		return {"ok":false,"erro":"Grupo ou indivíduos inválidos."}
	var individuos: Array = grupo.get("individuos", [])
	var minimo := int(grupo.get("populacaoMinimaParaLider", 3))
	var candidatos: Array = []
	for individuo in individuos:
		if bool(individuo.get("vivo", true)) and bool(individuo.get("elegivelParaLider", true)) and str(individuo.get("faseVida", "adulto")) != "filhote":
			candidatos.append(individuo)
	if candidatos.size() < minimo:
		return {"ok":true,"temLider":false,"motivo":"populacao_insuficiente","grupoId":str(grupo["grupoId"])}
	candidatos.sort_custom(func(a, b):
		var nato_a := bool(a.get("liderNato", false))
		var nato_b := bool(b.get("liderNato", false))
		if nato_a != nato_b:
			return nato_a
		var poder_a := _poder_total(a.get("atributos", {}))
		var poder_b := _poder_total(b.get("atributos", {}))
		if poder_a == poder_b:
			return str(a.get("individuoId", "")) < str(b.get("individuoId", ""))
		return poder_a > poder_b
	)
	var escolhido: Dictionary = candidatos[0].duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente if semente != 0 else hash(str(grupo["grupoId"]) + ":" + str(escolhido["individuoId"]))
	var multiplicador := rng.randf_range(MULTIPLICADOR_MINIMO, MULTIPLICADOR_MAXIMO)
	var atributos: Dictionary = escolhido.get("atributos", {}).duplicate(true)
	var atributos_base := atributos.duplicate(true)
	for atributo in ATRIBUTOS:
		if atributos.has(atributo):
			atributos[atributo] = maxi(1, roundi(float(atributos[atributo]) * multiplicador))
	var equipamento_ids := _selecionar_equipamentos(grupo.get("equipamentosLiderDisponiveis", []), escolhido.get("equipamentoIds", []))
	var dados_lider := {
		"grupoId":str(grupo["grupoId"]),
		"especieId":str(grupo["especieId"]),
		"individuoId":str(escolhido["individuoId"]),
		"atributosBase":atributos_base,
		"atributosLider":atributos,
		"multiplicadorAtributos":multiplicador,
		"equipamentoIds":equipamento_ids,
		"multiplicadorChanceDrops":1.5,
		"liderDesdeUnix":int(grupo.get("agoraUnix", 0)),
		"liderNato":bool(escolhido.get("liderNato", false)),
		"sucessao":false,
		"identidadeVisual":criar_identidade_visual(str(grupo["grupoId"]), str(escolhido["individuoId"]), bool(escolhido.get("liderNato", false)))
	}
	return {"ok":true,"temLider":true,"lider":dados_lider}

## Remove o líder morto e escolhe o sucessor mais forte entre os sobreviventes.
## O bônus de sucessão é menor que o de um líder que se desenvolveu naturalmente.
static func suceder_lider(grupo: Dictionary, lider_morto_id: String, semente: int = 0) -> Dictionary:
	if not validar_grupo(grupo):
		return {"ok":false,"erro":"Grupo ou indivíduos inválidos."}
	var atualizado := grupo.duplicate(true)
	var individuos: Array = atualizado.get("individuos", [])
	var encontrados := 0
	for i in range(individuos.size()):
		var individuo: Dictionary = individuos[i]
		if str(individuo.get("individuoId", "")) == lider_morto_id:
			individuo["vivo"] = false
			individuos[i] = individuo
			encontrados += 1
	if encontrados != 1:
		return {"ok":false,"erro":"Líder morto não pertence exclusivamente a este grupo."}
	atualizado["individuos"] = individuos
	var resultado := avaliar_grupo(atualizado, semente)
	if not bool(resultado.get("ok", false)) or not bool(resultado.get("temLider", false)):
		return resultado
	var lider: Dictionary = resultado["lider"]
	lider["sucessao"] = true
	lider["multiplicadorAtributos"] = minf(float(lider["multiplicadorAtributos"]), 1.20)
	var atributos: Dictionary = lider["atributosBase"].duplicate(true)
	for atributo in ATRIBUTOS:
		if atributos.has(atributo):
			atributos[atributo] = maxi(1, roundi(float(atributos[atributo]) * float(lider["multiplicadorAtributos"])))
	lider["atributosLider"] = atributos
	resultado["lider"] = lider
	resultado["grupoAtualizado"] = atualizado
	return resultado

## Gera traços cosméticos estáveis para diferenciar qualquer líder do restante do grupo.
## A aura é visual e não altera atributos, dano ou chances de combate.
static func criar_identidade_visual(grupo_id: String, individuo_id: String, lider_nato: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(grupo_id + ":identidade_lider:" + individuo_id)
	return {
		"tipo":"lider_nato" if lider_nato else "lider_comum",
		"padraoCorporal":PADROES_CORPORAIS[rng.randi_range(0, PADROES_CORPORAIS.size() - 1)],
		"marcaDistintiva":MARCAS_DISTINTIVAS[rng.randi_range(0, MARCAS_DISTINTIVAS.size() - 1)],
		"aderecoNatural":ADERECOS_NATURAIS[rng.randi_range(0, ADERECOS_NATURAIS.size() - 1)],
		"auraAtiva":true,
		"auraTipo":AURAS[rng.randi_range(0, AURAS.size() - 1)],
		"auraCor":CORES_AURA[rng.randi_range(0, CORES_AURA.size() - 1)],
		"auraIntensidade":1.35 if lider_nato else 1.0,
		"auraEscala":1.25 if lider_nato else 1.0,
		"efeitoParticulas":true
	}

## Aplica bônus apenas às chances declaradas pela criatura líder; nunca garante item.
static func melhorar_tabela_drops(tabela: Array, multiplicador: float = 1.5) -> Array:
	if multiplicador < 1.0 or multiplicador > 2.0:
		return []
	var resultado: Array = []
	for entrada in tabela:
		if not (entrada is Dictionary):
			return []
		var copia: Dictionary = entrada.duplicate(true)
		copia["chance"] = clampf(float(copia.get("chance", 0.0)) * multiplicador, 0.0, 1.0)
		resultado.append(copia)
	return resultado

static func _poder_total(atributos: Dictionary) -> int:
	var total := 0
	for atributo in ATRIBUTOS:
		total += int(atributos.get(atributo, 0))
	return total

static func _selecionar_equipamentos(disponiveis: Variant, atuais: Variant) -> Array:
	var resultado: Array = []
	if atuais is Array:
		for item_id in atuais:
			if EQUIPAMENTOS.CATALOGO.has(str(item_id)) and not resultado.has(str(item_id)):
				resultado.append(str(item_id))
	if disponiveis is Array:
		for item_id in disponiveis:
			var id := str(item_id)
			if EQUIPAMENTOS.CATALOGO.has(id) and not resultado.has(id):
				resultado.append(id)
			if resultado.size() >= MAX_EQUIPAMENTOS_LIDER:
				break
	return resultado.slice(0, MAX_EQUIPAMENTOS_LIDER)
