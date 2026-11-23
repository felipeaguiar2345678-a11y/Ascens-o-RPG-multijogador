extends RefCounted
## Simulação matemática de populações declaradas no catálogo.
## Não cria espécies: cada população pertence a um ID já registrado.
const SEGUNDOS_POR_DIA := 86400.0
const MAX_DIAS_POR_AVANCO := 3650.0

static func validar_configuracao(config: Variant) -> bool:
	if config == null:
		return true
	if not (config is Dictionary):
		return false
	var inicial := int(config.get("quantidadeInicial", -1))
	var minimo := int(config.get("minima", 0))
	var maximo := int(config.get("maxima", -1))
	var nascimentos := float(config.get("nascimentosPorDia", -1.0))
	var mortes := float(config.get("mortesPorDia", -1.0))
	if minimo < 0 or maximo < 1 or minimo > maximo:
		return false
	if inicial < minimo or inicial > maximo:
		return false
	if nascimentos < 0.0 or nascimentos > 100000.0 or mortes < 0.0 or mortes > 100000.0:
		return false
	return true

## Mede a ocupação real do habitat sem permitir ultrapassar a capacidade declarada.
static func calcular_ocupacao(quantidade: int, capacidade: int) -> float:
	if capacidade <= 0:
		return 1.0
	return clampf(float(maxi(0, quantidade)) / float(capacidade), 0.0, 1.0)

## Retorno ecológico só é permitido quando existe alimento suficiente e espaço populacional.
static func avaliar_condicoes_habitat(estado: Dictionary, alimento_disponivel: float, minimo_alimento: float = 0.65) -> Dictionary:
	if not _estado_valido(estado) or not is_finite(alimento_disponivel) or alimento_disponivel < 0.0 or alimento_disponivel > 1.0:
		return {"ok":false,"podeRetornar":false,"motivo":"dados_habitat_invalidos"}
	var quantidade := int(estado.get("quantidade", 0))
	var capacidade := int(estado.get("maxima", 0))
	var ocupacao := calcular_ocupacao(quantidade, capacidade)
	if alimento_disponivel < clampf(minimo_alimento, 0.0, 1.0):
		return {"ok":true,"podeRetornar":false,"motivo":"alimento_insuficiente","ocupacao":ocupacao}
	if quantidade > capacidade:
		return {"ok":true,"podeRetornar":false,"motivo":"capacidade_excedida","ocupacao":ocupacao}
	return {"ok":true,"podeRetornar":true,"motivo":"habitat_sustentavel","ocupacao":ocupacao}

static func criar_estado(config: Dictionary, agora_unix: int = -1) -> Dictionary:
	if not validar_configuracao(config):
		return {}
	var agora := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	return {
		"quantidade":int(config.get("quantidadeInicial", 0)),
		"minima":int(config.get("minima", 0)),
		"maxima":int(config.get("maxima", 1)),
		"nascimentosPorDia":float(config.get("nascimentosPorDia", 0.0)),
		"mortesPorDia":float(config.get("mortesPorDia", 0.0)),
		"restoNascimentos":0.0,
		"restoMortes":0.0,
		"restoMortesFome":0.0,
		"ultimaSimulacaoUnix":agora,
		"totalNascimentos":0,
		"totalMortesNaturais":0,
		"ultimaDisponibilidadeAlimentar":1.0,
		"ocupacaoCapacidade":float(config.get("quantidadeInicial", 0)) / maxf(1.0, float(config.get("maxima", 1)))
	}

## alimento_disponivel é um índice declarado pelo mundo entre 0 e 1.
## Sem informação de alimento, o mundo deve passar 1 apenas se a disponibilidade
## plena estiver confirmada; este módulo nunca presume dieta ou presas.
static func avancar(estado: Dictionary, agora_unix: int, alimento_disponivel: float = 1.0, protecao_fome: float = 0.0) -> Dictionary:
	if not _estado_valido(estado) or alimento_disponivel < 0.0 or alimento_disponivel > 1.0 or protecao_fome < 0.0 or protecao_fome > 0.625:
		return {"ok":false,"erro":"Estado populacional ou disponibilidade de alimento inválidos."}
	var ultima := int(estado.get("ultimaSimulacaoUnix", 0))
	if agora_unix < ultima:
		return {"ok":false,"erro":"O relógio da simulação não pode retroceder."}
	var dias := minf(float(agora_unix - ultima) / SEGUNDOS_POR_DIA, MAX_DIAS_POR_AVANCO)
	if dias <= 0.0:
		return {"ok":true,"alterou":false,"estado":estado.duplicate(true)}
	var atualizado := estado.duplicate(true)
	var quantidade := int(atualizado["quantidade"])
	var capacidade_restante := maxi(0, int(atualizado["maxima"]) - quantidade)
	var fator_capacidade := 1.0 if capacidade_restante > 0 else 0.0
	var nascimentos_brutos := float(atualizado["nascimentosPorDia"]) * alimento_disponivel * fator_capacidade * dias + float(atualizado.get("restoNascimentos", 0.0))
	var mortes_brutas := float(atualizado["mortesPorDia"]) * dias + float(atualizado.get("restoMortes", 0.0))
	var mortes_fome_brutas := float(quantidade) * 0.10 * (1.0 - alimento_disponivel) * (1.0 - protecao_fome) * dias + float(atualizado.get("restoMortesFome", 0.0))
	var nascimentos := maxi(0, floori(nascimentos_brutos))
	var mortes := maxi(0, floori(mortes_brutas))
	var mortes_fome := maxi(0, floori(mortes_fome_brutas))
	atualizado["restoNascimentos"] = nascimentos_brutos - floorf(nascimentos_brutos)
	atualizado["restoMortes"] = mortes_brutas - floorf(mortes_brutas)
	atualizado["restoMortesFome"] = mortes_fome_brutas - floorf(mortes_fome_brutas)
	var nascimentos_aplicados := mini(nascimentos, maxi(0, int(atualizado["maxima"]) - quantidade))
	quantidade += nascimentos_aplicados
	var mortes_aplicadas := mini(mortes + mortes_fome, maxi(0, quantidade - int(atualizado["minima"])))
	var mortes_fome_aplicadas := mini(mortes_fome, mortes_aplicadas)
	quantidade -= mortes_aplicadas
	atualizado["quantidade"] = quantidade
	atualizado["ultimaDisponibilidadeAlimentar"] = alimento_disponivel
	atualizado["ocupacaoCapacidade"] = calcular_ocupacao(quantidade, int(atualizado["maxima"]))
	atualizado["totalNascimentos"] = int(atualizado.get("totalNascimentos", 0)) + nascimentos_aplicados
	atualizado["totalMortesNaturais"] = int(atualizado.get("totalMortesNaturais", 0)) + mortes_aplicadas
	atualizado["ultimaSimulacaoUnix"] = agora_unix
	return {"ok":true,"alterou":true,"diasSimulados":dias,"nascimentos":nascimentos_aplicados,"mortesNaturais":mortes_aplicadas,"mortesPorFome":mortes_fome_aplicadas,"estado":atualizado}

static func _estado_valido(estado: Dictionary) -> bool:
	var quantidade := int(estado.get("quantidade", -1))
	var minimo := int(estado.get("minima", -1))
	var maximo := int(estado.get("maxima", -1))
	if minimo < 0 or maximo < minimo or quantidade < minimo or quantidade > maximo:
		return false
	if float(estado.get("nascimentosPorDia", -1.0)) < 0.0 or float(estado.get("mortesPorDia", -1.0)) < 0.0:
		return false
	if int(estado.get("ultimaSimulacaoUnix", -1)) < 0:
		return false
	return true
