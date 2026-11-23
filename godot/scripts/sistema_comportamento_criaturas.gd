extends RefCounted
## Decide o comportamento de uma criatura errante usando apenas contexto confiável do servidor.
## Não inicia combate nem inventa presas, habitats ou invasores: recebe esses sinais de sistemas do mundo.
const VAGANDO := "vagando"
const FUGINDO := "fugindo"
const CACANDO := "cacando"
const BUSCANDO_HABITAT := "buscando_habitat"
const DEFENDENDO_TERRITORIO := "defendendo_territorio"
const PERSEGUINDO_INVASOR := "perseguindo_invasor"

static func decidir(criatura: Dictionary, contexto: Dictionary) -> Dictionary:
	var mutacoes := _atributos_mutacoes(criatura.get("evolucao", {}).get("mutacoes", []))
	var distancia := maxf(0.0, float(contexto.get("distanciaAmeaca", INF)))
	var forca_criatura := maxf(0.0, float(contexto.get("forcaCriatura", 0.0)))
	var forca_ameaca := maxf(0.0, float(contexto.get("forcaAmeaca", 0.0)))
	var ameaca_perto := bool(contexto.get("ameacaPresente", false)) and distancia <= 180.0
	var moral := clampf(float(contexto.get("moralMultiplicador", criatura.get("moralMultiplicador", 1.0))), 0.5, 2.0)
	var agressividade := 1.0 + float(mutacoes.get("ataque", 0.0)) * 0.08 + float(mutacoes.get("agilidade", 0.0)) * 0.04
	var resistencia := 1.0 + float(mutacoes.get("defesa", 0.0)) * 0.08 + float(mutacoes.get("vidaMaxima", 0.0)) * 0.04
	if ameaca_perto and forca_ameaca > forca_criatura * resistencia * (0.85 + moral * 0.15):
		return _resultado(FUGINDO, "Uma ameaça próxima é mais forte.", 1.0 + float(mutacoes.get("agilidade", 0.0)) * 0.08)
	if not bool(contexto.get("habitatAdequado", true)):
		return _resultado(BUSCANDO_HABITAT, "O ambiente atual não é adequado.", 1.0)
	if bool(contexto.get("invasorTerritorio", false)) and forca_criatura * agressividade * moral >= forca_ameaca:
		return _resultado(DEFENDENDO_TERRITORIO, "Um invasor entrou no território; a moral sustenta a defesa.", 1.0 + (moral - 1.0) * 0.12)
	if bool(contexto.get("invasorTerritorio", false)) and moral >= 1.25 and forca_criatura * agressividade * moral >= forca_ameaca * 0.8:
		return _resultado(PERSEGUINDO_INVASOR, "A moral elevada encoraja a perseguição do invasor.", 1.0 + (moral - 1.0) * 0.15)
	if bool(contexto.get("presaPresente", false)) and forca_criatura * agressividade * (0.9 + moral * 0.1) > forca_ameaca:
		return _resultado(CACANDO, "Uma presa foi detectada.", 1.0 + float(mutacoes.get("agilidade", 0.0)) * 0.05)
	if ameaca_perto and forca_criatura >= forca_ameaca * 1.15:
		return _resultado(CACANDO, "A criatura identificou uma presa mais fraca.", 1.0 + float(mutacoes.get("agilidade", 0.0)) * 0.05)
	if ameaca_perto:
		return _resultado(FUGINDO, "A criatura evita uma presença próxima.", 1.0)
	return _resultado(VAGANDO, "A criatura explora a região.", 1.0)

## Decide a reação coletiva após avaliar a força relativa e a moral do grupo.
## coragem_variavel deve ser gerada pelo servidor com RNG determinístico.
## Decide a reação da presa sem aleatoriedade oculta.
## A fuga só é escolhida quando a espécie possui rota segura declarada.
static func decidir_reacao_presa(forca_presa: float, forca_predador: float, coragem: float, agressividade: float, vida_media: float, tem_rota_segura: bool, tem_aliado_proximo: bool, prudencia: float = 1.0, protecao_social: float = 1.0) -> Dictionary:
	var presa := maxf(0.0, forca_presa)
	var predador := maxf(0.0, forca_predador)
	var coragem_valor := clampf(coragem, 0.70, 1.30)
	var agressividade_valor := clampf(agressividade, 0.70, 1.30)
	var prudencia_valor := clampf(prudencia, 0.70, 1.30)
	var protecao_valor := clampf(protecao_social, 0.70, 1.30)
	var vida := clampf(vida_media, 0.0, 1.0)
	var razao := presa / maxf(1.0, predador)
	var acuada := vida <= 0.35 or razao < 0.72
	if tem_rota_segura and acuada and (coragem_valor < 1.08 or prudencia_valor >= 1.12):
		return {"acao":"fugir","motivo":"A ameaça supera a capacidade atual; indivíduos prudentes priorizam uma rota segura."}
	if tem_aliado_proximo and (acuada or agressividade_valor < 0.95 or protecao_valor >= 1.12):
		return {"acao":"defender_com_aliados","motivo":"A proteção social incentiva o grupo a buscar apoio de aliados próximos."}
	if razao >= 0.72 or coragem_valor >= 1.08 or agressividade_valor >= 1.12:
		return {"acao":"defender","motivo":"O grupo decidiu resistir à ameaça."}
	if tem_rota_segura:
		return {"acao":"fugir","motivo":"O grupo escolheu recuar por uma rota segura."}
	return {"acao":"defender","motivo":"Sem rota segura disponível, o grupo protege seus indivíduos."}

## Um grupo que já sobreviveu a uma ameaça reconhecida reage mais cedo na próxima ocasião.
## Sem rota segura, prioriza aliados; nunca revela ameaças de outra espécie ou ecossistema.
static func ajustar_reacao_com_memoria(decisao_atual: Dictionary, tem_rota_segura: bool, tem_aliado_proximo: bool) -> Dictionary:
	var acao := "fugir" if tem_rota_segura else ("defender_com_aliados" if tem_aliado_proximo else "defender")
	return {
		"acao":acao,
		"motivo":"O grupo reconheceu uma ameaça encontrada anteriormente e mudou sua resposta com base na experiência."
	}

## Escolhe uma tática de caça usando força real, personalidade e sinais espaciais.
## Emboscada só é permitida quando a espécie declarou essa capacidade e o habitat é compatível.
static func decidir_estrategia_caca(razao_forca: float, agressividade: float, coragem: float, alvo_isolado: bool, distancia_isolamento: float, pode_emboscar: bool, habitat_compativel: bool, falhas_seguidas: int, perseguicao_segundos: float, quantidade_predadores: int = 1) -> Dictionary:
	var razao := maxf(0.0, razao_forca)
	var agressividade_valor := clampf(agressividade, 0.70, 1.30)
	var coragem_valor := clampf(coragem, 0.70, 1.30)
	if falhas_seguidas >= 3 or perseguicao_segundos >= 1800.0 or razao < 0.45:
		return {"estrategia":"desistir","motivo":"O custo e o risco da caça superaram a capacidade do grupo."}
	if alvo_isolado and distancia_isolamento >= 45.0 and (agressividade_valor >= 0.90 or razao >= 0.85):
		return {"estrategia":"atacar_isolado","motivo":"Um indivíduo está suficientemente afastado dos seus aliados."}
	if pode_emboscar and habitat_compativel and coragem_valor >= 0.85:
		return {"estrategia":"emboscar","motivo":"A espécie possui capacidade declarada de emboscada neste habitat."}
	if quantidade_predadores >= 3 and razao >= 0.72:
		return {"estrategia":"cercar","motivo":"O número e a força do bando permitem fechar rotas de fuga."}
	return {"estrategia":"perseguir","motivo":"O grupo mantém a perseguição direta da presa declarada."}

## Filhotes recebem predisposições de caça de experiências reais recentes do grupo.
## A herança não é repassada novamente: só memoriaCacada, vivida pelo grupo, é fonte.
static func selecionar_aprendizado_herdado(memoria: Array, agora_unix: int) -> Array:
	var selecionadas: Array = []
	var vistos := {}
	for indice in range(memoria.size() - 1, -1, -1):
		var registro = memoria[indice]
		if not (registro is Dictionary):
			continue
		if str(registro.get("origemAprendizado", "")) == "herdado":
			continue
		var horario := int(registro.get("horarioUnix", 0))
		var especie := str(registro.get("especiePresaId", ""))
		var ecossistema := str(registro.get("ecossistemaId", ""))
		var bioma := str(registro.get("bioma", ""))
		var resultado := str(registro.get("resultado", ""))
		if horario <= 0 or horario > agora_unix or agora_unix - horario > 604800:
			continue
		if especie.is_empty() or ecossistema.is_empty() or bioma.is_empty():
			continue
		if resultado not in ["perdeu_rastro", "presa_escapou_de_ecossistema"]:
			continue
		var chave := especie + "|" + ecossistema + "|" + bioma + "|" + str(registro.get("estrategiaAnterior", "")) + "|" + resultado
		if vistos.has(chave):
			continue
		vistos[chave] = true
		var herdado := registro.duplicate(true)
		herdado["origemAprendizado"] = "herdado"
		herdado["herdadoUnix"] = agora_unix
		selecionadas.append(herdado)
		if selecionadas.size() >= 3:
			break
	return selecionadas

## Filhotes herdam sinais defensivos reais recentes ou alertas recebidos pelo grupo.
## Alertas são conhecimento indireto: não são tratados como encontro direto com a ameaça.
static func selecionar_aprendizado_defensivo_herdado(memoria: Array, agora_unix: int) -> Array:
	var selecionadas: Array = []
	var vistos := {}
	for indice in range(memoria.size() - 1, -1, -1):
		var registro = memoria[indice]
		if not (registro is Dictionary) or str(registro.get("origemAprendizado", "")) == "herdado":
			continue
		var horario := int(registro.get("horarioUnix", 0))
		var ecossistema := str(registro.get("ecossistemaId", ""))
		var especie := str(registro.get("especiePredadoraId", ""))
		var perigo := str(registro.get("perigo", ""))
		var alerta_indireto := str(registro.get("tipo", "")) == "alerta_perigo" and perigo in ["predador", "incendio", "devastacao", "invasor"]
		if horario <= 0 or horario > agora_unix or agora_unix - horario > 604800 or ecossistema.is_empty():
			continue
		if especie.is_empty() and not alerta_indireto:
			continue
		var bioma := str(registro.get("bioma", ""))
		var chave := (especie if not especie.is_empty() else "alerta:" + perigo) + "|" + ecossistema + "|" + bioma
		if vistos.has(chave):
			continue
		vistos[chave] = true
		var herdado := registro.duplicate(true)
		herdado["origemAprendizado"] = "herdado"
		herdado["nivelConhecimento"] = "indireto" if alerta_indireto else "vivenciado"
		herdado["herdadoUnix"] = agora_unix
		selecionadas.append(herdado)
		if selecionadas.size() >= 3:
			break
	return selecionadas

## Só adultos vivos transmitem predisposições defensivas; filhotes não repassam lembranças herdadas.
static func combinar_memoria_defensiva_com_heranca(memoria_grupo: Array, individuos: Array, agora_unix: int) -> Array:
	var combinada: Array = []
	var vistos := {}
	for registro in memoria_grupo:
		if not (registro is Dictionary):
			continue
		var horario := int(registro.get("horarioUnix", 0))
		if horario <= 0 or horario > agora_unix or agora_unix - horario > 604800:
			continue
		var chave := str(registro.get("especiePredadoraId", "")) + "|" + str(registro.get("ecossistemaId", "")) + "|" + str(registro.get("bioma", "")) + "|" + str(horario)
		if vistos.has(chave):
			continue
		vistos[chave] = true
		combinada.append(registro.duplicate(true))
	for individuo in individuos:
		if not (individuo is Dictionary) or not bool(individuo.get("vivo", true)) or str(individuo.get("faseVida", "")) != "adulto":
			continue
		for registro in individuo.get("aprendizadoDefensivoHerdado", []):
			if not (registro is Dictionary):
				continue
			var herdado_em := int(registro.get("herdadoUnix", 0))
			if herdado_em <= 0 or herdado_em > agora_unix or agora_unix - herdado_em > 2592000:
				continue
			var chave_herdada := str(registro.get("especiePredadoraId", "")) + "|" + str(registro.get("ecossistemaId", "")) + "|" + str(registro.get("bioma", "")) + "|" + str(registro.get("horarioUnix", 0))
			if vistos.has(chave_herdada):
				continue
			vistos[chave_herdada] = true
			combinada.append(registro.duplicate(true))
	return combinada

## Reúne experiência própria recente e predisposições de indivíduos adultos.
## Duplicatas herdadas são contadas uma única vez para não inflar o aprendizado.
static func combinar_memoria_cacada_com_heranca(memoria_grupo: Array, individuos: Array, agora_unix: int) -> Array:
	var combinada: Array = []
	var vistos := {}
	for registro in memoria_grupo:
		if not (registro is Dictionary):
			continue
		var horario := int(registro.get("horarioUnix", 0))
		if horario <= 0 or horario > agora_unix or agora_unix - horario > 604800:
			continue
		var chave := str(registro.get("especiePresaId", "")) + "|" + str(registro.get("ecossistemaId", "")) + "|" + str(registro.get("bioma", "")) + "|" + str(registro.get("estrategiaAnterior", "")) + "|" + str(registro.get("resultado", "")) + "|" + str(horario)
		if vistos.has(chave):
			continue
		vistos[chave] = true
		combinada.append(registro.duplicate(true))
	for individuo in individuos:
		if not (individuo is Dictionary) or not bool(individuo.get("vivo", true)):
			continue
		if str(individuo.get("faseVida", "")) != "adulto":
			continue
		for registro in individuo.get("aprendizadoHerdado", []):
			if not (registro is Dictionary):
				continue
			var herdado_em := int(registro.get("herdadoUnix", 0))
			if herdado_em <= 0 or herdado_em > agora_unix or agora_unix - herdado_em > 2592000:
				continue
			var chave_herdada := str(registro.get("especiePresaId", "")) + "|" + str(registro.get("ecossistemaId", "")) + "|" + str(registro.get("bioma", "")) + "|" + str(registro.get("estrategiaAnterior", "")) + "|" + str(registro.get("resultado", "")) + "|" + str(registro.get("horarioUnix", 0))
			if vistos.has(chave_herdada):
				continue
			vistos[chave_herdada] = true
			combinada.append(registro.duplicate(true))
	return combinada

## Evita repetir a estratégia que falhou contra a mesma espécie no mesmo ambiente.
static func ajustar_estrategia_com_memoria(estrategia_atual: Dictionary, memoria: Array, especie_presa_id: String, ecossistema_id: String, bioma: String, quantidade_predadores: int, agora_unix: int) -> Dictionary:
	var falhas_recentes := 0
	var ultima_estrategia := ""
	for registro in memoria:
		if not (registro is Dictionary):
			continue
		var horario := int(registro.get("horarioUnix", 0))
		var herdado := str(registro.get("origemAprendizado", "")) == "herdado"
		var referencia_tempo := int(registro.get("herdadoUnix", horario)) if herdado else horario
		var validade := 2592000 if herdado else 604800
		if referencia_tempo <= 0 or referencia_tempo > agora_unix or agora_unix - referencia_tempo > validade:
			continue
		if str(registro.get("especiePresaId", "")) != especie_presa_id or str(registro.get("ecossistemaId", "")) != ecossistema_id or str(registro.get("bioma", "")) != bioma:
			continue
		if str(registro.get("resultado", "")) not in ["perdeu_rastro", "presa_escapou_de_ecossistema"]:
			continue
		falhas_recentes += 1
		ultima_estrategia = str(registro.get("estrategiaAnterior", ""))
	if falhas_recentes == 0:
		return estrategia_atual.duplicate(true)
	var ajustada := estrategia_atual.duplicate(true)
	var estrategia := str(ajustada.get("estrategia", "perseguir"))
	if estrategia == ultima_estrategia or estrategia == "emboscar":
		estrategia = "cercar" if quantidade_predadores >= 3 else "perseguir"
	elif falhas_recentes >= 2 and quantidade_predadores >= 2:
		estrategia = "cercar"
	ajustada["estrategia"] = estrategia
	ajustada["motivo"] = "O bando adaptou a caça após aprender com uma tentativa anterior que falhou."
	ajustada["aprendeuComFalha"] = true
	ajustada["falhasAprendidas"] = falhas_recentes
	return ajustada

## Distribui funções táticas entre adultos vivos durante a defesa do grupo.
static func distribuir_papeis_defensivos(individuos: Array, individuo_protegido_id: String, centro_ameaca: Vector2) -> Array:
	var resultado: Array = []
	var candidatos: Array = []
	var posicao_protegida := Vector2.ZERO
	for individuo in individuos:
		if not (individuo is Dictionary):
			continue
		var copia: Dictionary = individuo.duplicate(true)
		copia.erase("papelDefensivoAtual")
		var dados = copia.get("posicaoMundo", {})
		if str(copia.get("individuoId", "")) == individuo_protegido_id and dados is Dictionary:
			posicao_protegida = Vector2(float(dados.get("x", 0.0)), float(dados.get("y", 0.0)))
		if bool(copia.get("vivo", false)) and str(copia.get("faseVida", "adulto")) != "filhote" and str(copia.get("individuoId", "")) != individuo_protegido_id and dados is Dictionary:
			var pos := Vector2(float(dados.get("x", -1.0)), float(dados.get("y", -1.0)))
			if is_finite(pos.x) and is_finite(pos.y) and pos.x >= 0.0 and pos.y >= 0.0 and pos.x <= 2400.0 and pos.y <= 1600.0:
				candidatos.append({"id":str(copia.get("individuoId", "")), "distancia":pos.distance_to(posicao_protegida), "ameaca":pos.distance_to(centro_ameaca)})
		resultado.append(copia)
	candidatos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("distancia", INF)) < float(b.get("distancia", INF)))
	var papeis := {}
	for indice in range(candidatos.size()):
		var id := str(candidatos[indice].get("id", ""))
		if id.is_empty():
			continue
		if indice < 2:
			papeis[id] = "guardiao_dos_vulneraveis"
		elif float(candidatos[indice].get("ameaca", 0.0)) > float(candidatos[indice].get("distancia", 0.0)):
			papeis[id] = "linha_defensiva"
		else:
			papeis[id] = "retaguarda"
	for indice in range(resultado.size()):
		var membro: Dictionary = resultado[indice]
		var id_membro := str(membro.get("individuoId", ""))
		if id_membro == individuo_protegido_id and bool(membro.get("vivo", false)):
			membro["papelDefensivoAtual"] = "recuo_protegido"
		elif papeis.has(id_membro):
			membro["papelDefensivoAtual"] = papeis[id_membro]
		elif bool(membro.get("vivo", false)):
			membro["papelDefensivoAtual"] = "apoio"
		resultado[indice] = membro
	return resultado


static func grupo_deve_continuar_confronto_razao(razao_forca: float, moral_multiplicador: float, coragem_variavel: float) -> bool:
	var moral := clampf(moral_multiplicador, 0.5, 2.0)
	var coragem := clampf(coragem_variavel, 0.0, 0.20)
	var limiar := clampf(0.72 - (moral - 1.0) * 0.20, 0.45, 0.85)
	return razao_forca + coragem >= limiar

static func _atributos_mutacoes(lista: Array) -> Dictionary:
	var resultado := {"ataque":0.0,"defesa":0.0,"agilidade":0.0,"vidaMaxima":0.0,"poderMagico":0.0,"manaMaxima":0.0}
	for mutacao in lista:
		if not (mutacao is Dictionary):
			continue
		var atributo := str(mutacao.get("atributo", ""))
		if resultado.has(atributo):
			resultado[atributo] = float(resultado[atributo]) + 1.0
	return resultado

static func _resultado(estado: String, motivo: String, multiplicador_velocidade: float) -> Dictionary:
	return {"estado":estado,"motivo":motivo,"multiplicadorVelocidade":clampf(multiplicador_velocidade, 0.75, 1.25)}
