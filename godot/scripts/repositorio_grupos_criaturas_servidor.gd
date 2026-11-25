extends RefCounted
## Persistência local no servidor para grupos selvagens derivados de criaturas já catalogadas.
## Cada indivíduo é uma instância independente; não gera novas espécies nem usa dados do cliente.
const REPOSITORIO_CRIATURAS = preload("res://scripts/repositorio_criaturas_servidor.gd")
const SISTEMA_POPULACAO = preload("res://scripts/sistema_populacao_criaturas.gd")
const SISTEMA_LIDERES = preload("res://scripts/sistema_lideres_criaturas.gd")
const SISTEMA_EQUIPAMENTOS = preload("res://scripts/sistema_equipamentos.gd")
const SISTEMA_COMPORTAMENTO = preload("res://scripts/sistema_comportamento_criaturas.gd")
const SISTEMA_CUIDADO_PARENTAL = preload("res://scripts/sistema_cuidado_parental.gd")
const SISTEMA_LIDER_NATO = preload("res://scripts/sistema_lider_nato.gd")
const SISTEMA_MIGRACAO = preload("res://scripts/sistema_migracao_coordenadas.gd")
const CAMINHO_PADRAO := "user://dados/grupos_criaturas.json"
const LIMITE_ARQUIVO := 32 * 1024 * 1024
const CAMPOS_ATRIBUTOS := ["vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"]

var caminho_arquivo: String
var repositorio_criaturas: Object

func _init(caminho: String = CAMINHO_PADRAO, repositorio: Object = null) -> void:
	caminho_arquivo = caminho
	repositorio_criaturas = repositorio if repositorio != null else REPOSITORIO_CRIATURAS.new()

## Cria um grupo somente a partir de criatura já registrada e com ecologia populacional/território.
func criar_grupo_para_criatura(criatura_id: String, agora_unix: int = -1) -> Dictionary:
	var criatura: Dictionary = repositorio_criaturas.obter_criatura(criatura_id)
	if criatura.is_empty():
		return {"ok":false,"erro":"A espécie ainda não existe no catálogo global."}
	var ecologia: Dictionary = criatura.get("ecologia", {})
	var config = ecologia.get("populacao", null)
	var territorio = ecologia.get("territorio", {})
	if not (config is Dictionary) or not SISTEMA_POPULACAO.validar_configuracao(config):
		return {"ok":false,"erro":"A espécie não declarou uma configuração populacional válida."}
	if not _territorio_valido(territorio):
		return {"ok":false,"erro":"A espécie precisa declarar um território válido antes de formar um grupo."}
	var grupo_id := str(territorio.get("grupoId", criatura_id + "_" + str(criatura.get("bioma", "")))).strip_edges()
	if grupo_id.is_empty() or grupo_id.length() > 160:
		return {"ok":false,"erro":"Identificador de grupo inválido."}
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(caminho_arquivo):
		return {"ok":false,"erro":"Arquivo de grupos inválido; criação bloqueada para proteger os dados."}
	var grupos: Dictionary = banco.get("grupos", {})
	if grupos.has(grupo_id):
		return {"ok":false,"erro":"Este grupo já foi criado.","duplicado":true}
	var agora := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	var estado := SISTEMA_POPULACAO.criar_estado(config, agora)
	if estado.is_empty():
		return {"ok":false,"erro":"Não foi possível iniciar a população."}
	var grupo := {
		"grupoId":grupo_id,
		"especieId":criatura_id,
		"ecossistemaId":str(criatura.get("ecossistemaId", "")),
		"bioma":str(criatura.get("bioma", "")),
		"habitat":str(criatura.get("habitat", "")),
		"territorio":territorio.duplicate(true),
		"rotasMigracao":ecologia.get("rotasMigracao", []).duplicate(true),
		"ciclosEscassezAlimentar":0,
		"ultimaMigracaoUnix":0,
		"populacaoEstado":estado,
		"idadeMaturidadeDias":clampf(float(ecologia.get("idadeMaturidadeDias", 7.0)), 1.0, 3650.0),
		"populacaoMinimaParaLider":int(ecologia.get("populacaoMinimaParaLider", 3)),
		"equipamentosLiderDisponiveis":_equipamentos_lider_validos(ecologia.get("equipamentosLider", [])),
		"individuos":[],
		"proximoNumeroIndividuo":1,
		"liderAtual":{},
		"personalidade":_gerar_personalidade_grupo(grupo_id),
		"relacoesGrupos":{},
		"historicoSocial":[],
		"culturaGrupo":{"tradicoes":[],"contagemExperiencias":{},"geracao":1},
		"criadoUnix":agora,
		"atualizadoUnix":agora
	}
	_inicializar_cultura_especie(grupo, criatura, agora)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(grupo_id + ":" + str(agora))
	for i in range(int(estado.get("quantidade", 0))):
		grupo["individuos"].append(_criar_individuo(grupo, criatura, rng, false))
	grupo["liderAtual"] = SISTEMA_LIDERES.avaliar_grupo(grupo, rng.randi()).get("lider", {})
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar o novo grupo no servidor."}
	return {"ok":true,"grupo":grupo.duplicate(true)}

## Avança o relógio ecológico e cria/remove indivíduos reais para refletir o resultado.
## alimento_disponivel precisa vir de uma avaliação confiável do mundo.
func avancar_grupo(grupo_id: String, agora_unix: int, alimento_disponivel: float = 1.0, protecao_fome: float = 0.0) -> Dictionary:
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var criatura: Dictionary = repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
	if criatura.is_empty():
		return {"ok":false,"erro":"A espécie de origem não está mais disponível no catálogo."}
	var cuidado_parental := SISTEMA_CUIDADO_PARENTAL.avaliar(grupo, agora_unix)
	var protecao_cuidado := float(cuidado_parental.get("protecaoFome", 0.0))
	var protecao_combinada := 1.0 - (1.0 - protecao_fome) * (1.0 - protecao_cuidado)
	var simulacao := SISTEMA_POPULACAO.avancar(grupo.get("populacaoEstado", {}), agora_unix, alimento_disponivel, protecao_combinada)
	if not bool(simulacao.get("ok", false)):
		return simulacao
	if not bool(simulacao.get("alterou", false)):
		var fases_alteradas := false
		var individuos_sem_ciclo: Array = grupo.get("individuos", [])
		for indice_sem_ciclo in range(individuos_sem_ciclo.size()):
			var membro_sem_ciclo: Dictionary = individuos_sem_ciclo[indice_sem_ciclo].duplicate(true)
			if bool(membro_sem_ciclo.get("vivo", true)):
				var fase_anterior := str(membro_sem_ciclo.get("faseVida", ""))
				_atualizar_fase_desenvolvimento_hibrido(membro_sem_ciclo, grupo, agora_unix)
				fases_alteradas = fases_alteradas or fase_anterior != str(membro_sem_ciclo.get("faseVida", ""))
			individuos_sem_ciclo[indice_sem_ciclo] = membro_sem_ciclo
		if fases_alteradas:
			grupo["individuos"] = individuos_sem_ciclo
			grupo["atualizadoUnix"] = agora_unix
			grupos[grupo_id] = grupo
			banco["grupos"] = grupos
			if not _gravar_banco(banco):
				return {"ok":false,"erro":"Não foi possível salvar o crescimento dos híbridos."}
			return {"ok":true,"alterou":true,"somenteDesenvolvimento":true,"grupo":grupo}
		return {"ok":true,"alterou":false,"grupo":grupo}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(grupo_id + ":" + str(agora_unix))
	var individuos: Array = grupo.get("individuos", [])
	var lider_anterior := str(grupo.get("liderAtual", {}).get("individuoId", ""))
	for i in range(int(simulacao.get("mortesNaturais", 0))):
		var vivos: Array = []
		for indice in range(individuos.size()):
			if bool(individuos[indice].get("vivo", true)):
				vivos.append(indice)
		if vivos.is_empty():
			break
		var indice_morto: int = vivos[rng.randi_range(0, vivos.size() - 1)]
		var individuo_morto: Dictionary = individuos[indice_morto]
		individuo_morto["vivo"] = false
		individuo_morto["morteNaturalUnix"] = agora_unix
		individuo_morto["carcaca"] = _criar_carcarca(individuo_morto, criatura, agora_unix)
		individuos[indice_morto] = individuo_morto
	grupo["atualizadoUnix"] = agora_unix
	var pares_formados_no_ciclo := {}
	for i in range(int(simulacao.get("nascimentos", 0))):
		var par_cultural := _selecionar_par_acasalamento_cultural(grupo, agora_unix, pares_formados_no_ciclo)
		var filhote_novo := _criar_individuo(grupo, criatura, rng, true)
		if not par_cultural.is_empty():
			filhote_novo["progenitores"] = par_cultural
			filhote_novo["ritualAcasalamentoUsado"] = str(par_cultural.get("ritual", ""))
			pares_formados_no_ciclo[str(par_cultural.get("chave", ""))] = true
			_registrar_pareamento_cultural(grupo, par_cultural, agora_unix)
		individuos.append(filhote_novo)
	for indice_fase in range(individuos.size()):
		var membro_fase: Dictionary = individuos[indice_fase].duplicate(true)
		if bool(membro_fase.get("vivo", true)):
			_atualizar_fase_desenvolvimento_hibrido(membro_fase, grupo, agora_unix)
		individuos[indice_fase] = membro_fase
	grupo["individuos"] = individuos
	grupo["populacaoEstado"] = simulacao["estado"]
	grupo["atualizadoUnix"] = agora_unix
	grupos[grupo_id] = grupo
	for individuo_natural in individuos:
		if not bool(individuo_natural.get("vivo", true)) and int(individuo_natural.get("morteNaturalUnix", -1)) == agora_unix:
			_registrar_luto_em_grupos(grupos, grupo_id, str(individuo_natural.get("individuoId", "")), agora_unix, "morte_natural")
	grupo = grupos[grupo_id]
	var lider_resultado: Dictionary = {}
	if not lider_anterior.is_empty():
		var ainda_vivo := false
		for individuo in individuos:
			if str(individuo.get("individuoId", "")) == lider_anterior and bool(individuo.get("vivo", true)):
				ainda_vivo = true
				break
		if not ainda_vivo:
			var cultura_sucessao: Dictionary = grupo.get("culturaGrupo", {}).duplicate(true)
			var disputas: Array = cultura_sucessao.get("disputasLideranca", [])
			var sucessor := SISTEMA_LIDERES.suceder_lider(grupo, lider_anterior, rng.randi())
			disputas.append({"liderAnteriorId":lider_anterior,"candidatoId":str(sucessor.get("lider", {}).get("individuoId", "")),"criterio":str(cultura_sucessao.get("perfilEspecie", {}).get("hierarquia", "lideranca_por_experiencia")),"horarioUnix":agora_unix,"resultado":"sucessao_apos_morte"})
			cultura_sucessao["disputasLideranca"] = disputas.slice(maxi(0, disputas.size() - 20))
			grupo["culturaGrupo"] = cultura_sucessao
			lider_resultado = sucessor
	if lider_resultado.is_empty() or not bool(lider_resultado.get("temLider", false)):
		lider_resultado = SISTEMA_LIDERES.avaliar_grupo(grupo, rng.randi())
	grupo["liderAtual"] = lider_resultado.get("lider", {})
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir a atualização do grupo."}
	return {
		"ok":true,
		"alterou":true,
		"nascimentos":int(simulacao.get("nascimentos", 0)),
		"mortesNaturais":int(simulacao.get("mortesNaturais", 0)),
		"cuidadoParental":cuidado_parental,
		"quantidade":int(grupo["populacaoEstado"].get("quantidade", 0)),
		"lider":grupo["liderAtual"].duplicate(true),
		"grupo":grupo.duplicate(true)
	}

## Faz a fauna abandonar uma área devastada, usando somente rotas de migração declaradas pela espécie.
func fugir_da_devastacao(grupo_id: String, centro_zona: Vector2, raio_zona: float, agora_unix: int) -> Dictionary:
	if grupo_id.is_empty() or raio_zona <= 0.0 or raio_zona > 2000.0:
		return {"ok":false,"erro":"Zona de devastação inválida."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var territorio_atual: Dictionary = grupo.get("territorio", {})
	var centro_atual_dados: Dictionary = territorio_atual.get("centro", {})
	var centro_atual := Vector2(float(centro_atual_dados.get("x", -1.0)), float(centro_atual_dados.get("y", -1.0)))
	var raio_atual := float(territorio_atual.get("raio", 0.0))
	if centro_atual.x < 0.0 or centro_atual.y < 0.0 or centro_atual.distance_to(centro_zona) > raio_zona + raio_atual:
		return {"ok":true,"fugiu":false,"motivo":"fora_da_area"}
	for rota in grupo.get("rotasMigracao", []):
		if not (rota is Dictionary):
			continue
		var destino: Dictionary = rota.get("territorio", {})
		var centro_dados: Dictionary = destino.get("centro", {})
		var centro_novo := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
		var raio_novo := float(destino.get("raio", 0.0))
		var ecossistema_novo := str(rota.get("ecossistemaId", ""))
		var bioma_novo := str(rota.get("bioma", ""))
		var habitat_novo := str(rota.get("habitat", ""))
		var rota_id := str(rota.get("id", ""))
		if rota_id.is_empty() or ecossistema_novo.is_empty() or bioma_novo.is_empty() or habitat_novo.is_empty():
			continue
		if centro_novo.x < 0.0 or centro_novo.x > 2400.0 or centro_novo.y < 0.0 or centro_novo.y > 1600.0 or raio_novo < 20.0 or raio_novo > 1000.0:
			continue
		if centro_novo.distance_to(centro_zona) <= raio_zona + raio_novo:
			continue
		var ocupado := false
		for outro_id in grupos:
			if str(outro_id) == grupo_id:
				continue
			var outro: Dictionary = grupos[outro_id]
			if str(outro.get("ecossistemaId", "")) != ecossistema_novo:
				continue
			var outro_territorio: Dictionary = outro.get("territorio", {})
			var outro_centro_dados: Dictionary = outro_territorio.get("centro", {})
			var outro_centro := Vector2(float(outro_centro_dados.get("x", -10000.0)), float(outro_centro_dados.get("y", -10000.0)))
			if outro_centro.distance_to(centro_novo) < float(outro_territorio.get("raio", 0.0)) + raio_novo:
				ocupado = true
				break
		if ocupado:
			continue
		var individuos: Array = grupo.get("individuos", [])
		for indice in range(individuos.size()):
			var individuo: Dictionary = individuos[indice].duplicate(true)
			var posicao: Dictionary = individuo.get("posicaoMundo", {})
			var deslocamento := Vector2(float(posicao.get("x", centro_atual.x)), float(posicao.get("y", centro_atual.y))) - centro_atual
			if deslocamento.length() > raio_novo - 5.0:
				deslocamento = deslocamento.normalized() * (raio_novo - 5.0)
			var nova_posicao := centro_novo + deslocamento
			individuo["posicaoMundo"] = {"x":nova_posicao.x,"y":nova_posicao.y}
			if bool(individuo.get("vivo", true)):
				individuo["estadoMundo"] = "fugindo_da_devastacao"
			individuos[indice] = individuo
		grupo["individuos"] = individuos
		var territorio_origem := territorio_atual.duplicate(true)
		var ecossistema_anterior := str(grupo.get("ecossistemaId", ""))
		var retorno_existente: Dictionary = grupo.get("retornoDevastacao", {})
		if retorno_existente.is_empty():
			grupo["retornoDevastacao"] = {
				"territorio":territorio_origem,
				"ecossistemaId":ecossistema_anterior,
				"bioma":str(grupo.get("bioma", "")),
				"habitat":str(grupo.get("habitat", "")),
				"iniciadoUnix":agora_unix
			}
		grupo["territorio"] = destino.duplicate(true)
		grupo["ecossistemaId"] = ecossistema_novo
		grupo["bioma"] = bioma_novo
		grupo["habitat"] = habitat_novo
		grupo["ultimaMigracaoUnix"] = agora_unix
		grupo["atualizadoUnix"] = agora_unix
		grupo["ultimaMigracao"] = {"rotaId":rota_id,"motivo":"sopro_primordial","ecossistemaAnterior":ecossistema_anterior,"horarioUnix":agora_unix}
		grupos[grupo_id] = grupo
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível persistir a fuga da fauna."}
		return {"ok":true,"fugiu":true,"rotaId":rota_id,"grupo":grupo.duplicate(true)}
	return {"ok":true,"fugiu":false,"motivo":"sem_rota_segura"}


## Reocupa o território de origem quando todas as cicatrizes que o atingiam expiraram.
## A área só é retomada se continuar livre e segura; não expulsa outro grupo.
func retornar_da_devastacao(grupo_id: String, marcas_ativas: Array, agora_unix: int, alimento_disponivel: float = 1.0) -> Dictionary:
	if grupo_id.is_empty() or agora_unix < 0:
		return {"ok":false,"erro":"Identificador ou horário inválido."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var retorno: Dictionary = grupo.get("retornoDevastacao", {})
	if retorno.is_empty():
		return {"ok":true,"retornou":false,"motivo":"sem_territorio_de_origem"}
	var condicoes_habitat := SISTEMA_POPULACAO.avaliar_condicoes_habitat(
		grupo.get("populacaoEstado", {}),
		alimento_disponivel,
		0.65
	)
	if not bool(condicoes_habitat.get("ok", false)):
		return {"ok":false,"erro":"Estado populacional inválido; retorno bloqueado."}
	if not bool(condicoes_habitat.get("podeRetornar", false)):
		return {"ok":true,"retornou":false,"motivo":str(condicoes_habitat.get("motivo", "habitat_sem_condicoes")),"ocupacaoCapacidade":float(condicoes_habitat.get("ocupacao", 0.0))}
	if alimento_disponivel < 0.0 or alimento_disponivel > 1.0 or not is_finite(alimento_disponivel):
		return {"ok":false,"erro":"Índice alimentar inválido; retorno bloqueado."}
	var destino: Dictionary = retorno.get("territorio", {})
	var centro_dados: Dictionary = destino.get("centro", {})
	var centro_destino := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
	var raio_destino := float(destino.get("raio", 0.0))
	if centro_destino.x < 0.0 or centro_destino.x > 2400.0 or centro_destino.y < 0.0 or centro_destino.y > 1600.0 or raio_destino < 20.0 or raio_destino > 1000.0:
		return {"ok":false,"erro":"Território original inválido; retorno bloqueado."}
	for marca in marcas_ativas:
		if not (marca is Dictionary) or int(marca.get("expiraUnix", 0)) <= agora_unix:
			continue
		var centro_marca := Vector2(float(marca.get("x", -10000.0)), float(marca.get("y", -10000.0)))
		var raio_marca := clampf(float(marca.get("raio", 0.0)), 0.0, 2000.0)
		if centro_marca.distance_to(centro_destino) <= raio_marca + raio_destino:
			return {"ok":true,"retornou":false,"motivo":"territorio_ainda_devastado"}
	var ecossistema_destino := str(retorno.get("ecossistemaId", ""))
	if ecossistema_destino.is_empty():
		return {"ok":false,"erro":"Ecossistema original ausente; retorno bloqueado."}
	for outro_id in grupos:
		if str(outro_id) == grupo_id:
			continue
		var outro: Dictionary = grupos[outro_id]
		if str(outro.get("ecossistemaId", "")) != ecossistema_destino:
			continue
		var territorio_outro: Dictionary = outro.get("territorio", {})
		var centro_outro_dados: Dictionary = territorio_outro.get("centro", {})
		var centro_outro := Vector2(float(centro_outro_dados.get("x", -10000.0)), float(centro_outro_dados.get("y", -10000.0)))
		if centro_outro.distance_to(centro_destino) < float(territorio_outro.get("raio", 0.0)) + raio_destino:
			return {"ok":true,"retornou":false,"motivo":"territorio_ocupado"}
	var territorio_atual: Dictionary = grupo.get("territorio", {})
	var centro_atual_dados: Dictionary = territorio_atual.get("centro", {})
	var centro_atual := Vector2(float(centro_atual_dados.get("x", centro_destino.x)), float(centro_atual_dados.get("y", centro_destino.y)))
	var raio_atual := maxf(1.0, float(territorio_atual.get("raio", raio_destino)))
	var individuos: Array = grupo.get("individuos", [])
	for indice in range(individuos.size()):
		var individuo: Dictionary = individuos[indice].duplicate(true)
		var posicao_dados: Dictionary = individuo.get("posicaoMundo", {})
		var deslocamento := Vector2(float(posicao_dados.get("x", centro_atual.x)), float(posicao_dados.get("y", centro_atual.y))) - centro_atual
		if deslocamento.length() > raio_destino - 5.0:
			deslocamento = deslocamento.normalized() * (raio_destino - 5.0)
		var nova_posicao := centro_destino + deslocamento * minf(1.0, raio_destino / raio_atual)
		individuo["posicaoMundo"] = {"x":nova_posicao.x,"y":nova_posicao.y}
		if bool(individuo.get("vivo", true)):
			individuo["estadoMundo"] = "retornando_ao_habitat"
		individuos[indice] = individuo
	grupo["individuos"] = individuos
	grupo["territorio"] = destino.duplicate(true)
	grupo["ecossistemaId"] = ecossistema_destino
	grupo["bioma"] = str(retorno.get("bioma", grupo.get("bioma", "")))
	grupo["habitat"] = str(retorno.get("habitat", grupo.get("habitat", "")))
	grupo["ultimaMigracao"] = {"motivo":"retorno_apos_recuperacao","horarioUnix":agora_unix}
	grupo["ultimaMigracaoUnix"] = agora_unix
	grupo.erase("retornoDevastacao")
	grupo["atualizadoUnix"] = agora_unix
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir o retorno ao habitat."}
	return {"ok":true,"retornou":true,"grupo":grupo.duplicate(true)}


## Predadores só perseguem grupos deslocados quando a relação presa/predador foi
## declarada pela espécie no catálogo. A perseguição fica registrada no servidor;
## este método não teletransporta grupos nem inicia combate automaticamente.
func registrar_perseguicao_de_fauna_migrante(grupo_presa_id: String, agora_unix: int) -> Dictionary:
	if grupo_presa_id.is_empty() or agora_unix < 0:
		return {"ok":false,"erro":"Alvo ou horário de perseguição inválido."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_presa_id):
		return {"ok":false,"erro":"Grupo deslocado não encontrado."}
	var presa: Dictionary = grupos[grupo_presa_id].duplicate(true)
	var especie_presa: Dictionary = repositorio_criaturas.obter_criatura(str(presa.get("especieId", "")))
	if especie_presa.is_empty() or presa.get("ultimaMigracao", {}).is_empty():
		return {"ok":true,"perseguidores":[]}
	var ecossistema_origem := str(presa.get("ultimaMigracao", {}).get("ecossistemaAnterior", ""))
	var centro_destino_dados: Dictionary = presa.get("territorio", {}).get("centro", {})
	var centro_destino := Vector2(float(centro_destino_dados.get("x", -1.0)), float(centro_destino_dados.get("y", -1.0)))
	if ecossistema_origem.is_empty() or centro_destino.x < 0.0 or centro_destino.y < 0.0:
		return {"ok":true,"perseguidores":[]}
	var ids_perseguidores: Array = []
	for predador_id_var in grupos.keys():
		var predador_id := str(predador_id_var)
		if predador_id == grupo_presa_id:
			continue
		var predador: Dictionary = grupos[predador_id].duplicate(true)
		if str(predador.get("ecossistemaId", "")) != ecossistema_origem:
			continue
		var especie_predadora: Dictionary = repositorio_criaturas.obter_criatura(str(predador.get("especieId", "")))
		if especie_predadora.is_empty():
			continue
		var ecologia_predador: Dictionary = especie_predadora.get("ecologia", {})
		var ecologia_presa: Dictionary = especie_presa.get("ecologia", {})
		var dieta: Array = ecologia_predador.get("especiesPresas", [])
		var declaracao_reversa: Array = ecologia_presa.get("especiesPredadoras", [])
		var relacao_declarada := dieta.has(str(especie_presa.get("id", ""))) or declaracao_reversa.has(str(especie_predadora.get("id", "")))
		if not relacao_declarada:
			continue
		var perseguicao_atual: Dictionary = predador.get("perseguicaoAtual", {})
		if str(perseguicao_atual.get("grupoAlvoId", "")) == grupo_presa_id:
			continue
		var centro_predador_dados: Dictionary = predador.get("territorio", {}).get("centro", {})
		var centro_predador := Vector2(float(centro_predador_dados.get("x", -10000.0)), float(centro_predador_dados.get("y", -10000.0)))
		if centro_predador.distance_to(centro_destino) > 1800.0:
			continue
		predador["perseguicaoAtual"] = {
			"grupoAlvoId":grupo_presa_id,
			"especieAlvoId":str(especie_presa.get("id", "")),
			"centroAlvo":{"x":centro_destino.x,"y":centro_destino.y},
			"motivo":"presa_deslocada_pela_devastacao",
			"iniciadaUnix":agora_unix,
			"estado":"rastreando"
		}
		predador["atualizadoUnix"] = agora_unix
		grupos[predador_id] = predador
		ids_perseguidores.append(predador_id)
	if not ids_perseguidores.is_empty():
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível persistir a perseguição dos predadores."}
	var atualizados: Array = []
	for id in ids_perseguidores:
		atualizados.append(grupos[id].duplicate(true))
	return {"ok":true,"perseguidores":atualizados}


## Move predadores em direção a presas deslocadas. O deslocamento é gradual,
## limitado por velocidade ecológica e persistido pelo servidor.
func avancar_perseguicoes(delta_segundos: float, agora_unix: int) -> Dictionary:
	if delta_segundos <= 0.0 or delta_segundos > 5.0 or agora_unix < 0:
		return {"ok":false,"erro":"Intervalo de perseguição inválido."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	var atualizados: Array = []
	var houve_mudanca := false
	for predador_id_var in grupos.keys():
		var predador_id := str(predador_id_var)
		var predador: Dictionary = grupos[predador_id].duplicate(true)
		var perseguicao: Dictionary = predador.get("perseguicaoAtual", {})
		if str(perseguicao.get("estado", "")) not in ["rastreando", "seguindo"]:
			continue
		var alvo_id := str(perseguicao.get("grupoAlvoId", ""))
		if alvo_id.is_empty() or not grupos.has(alvo_id):
			perseguicao["estado"] = "perdeu_rastro"
			perseguicao["encerradaUnix"] = agora_unix
			predador["perseguicaoAtual"] = perseguicao
			if grupos.has(alvo_id):
				_registrar_aprendizado_cacada(predador, grupos[alvo_id], "perdeu_rastro", agora_unix)
			grupos[predador_id] = predador
			houve_mudanca = true
			continue
		var presa: Dictionary = grupos[alvo_id]
		if str(presa.get("ecossistemaId", "")) != str(predador.get("ecossistemaId", "")):
			perseguicao["estado"] = "presa_escapou_de_ecossistema"
			perseguicao["encerradaUnix"] = agora_unix
			predador["perseguicaoAtual"] = perseguicao
			_registrar_aprendizado_cacada(predador, presa, "presa_escapou_de_ecossistema", agora_unix)
			grupos[predador_id] = predador
			houve_mudanca = true
			continue
		var presa_viva := false
		for individuo_presa in presa.get("individuos", []):
			if bool(individuo_presa.get("vivo", true)):
				presa_viva = true
				break
		if not presa_viva:
			perseguicao["estado"] = "presa_indisponivel"
			perseguicao["encerradaUnix"] = agora_unix
			predador["perseguicaoAtual"] = perseguicao
			grupos[predador_id] = predador
			houve_mudanca = true
			continue
		var centro_alvo_dados: Dictionary = presa.get("territorio", {}).get("centro", {})
		var centro_alvo := Vector2(float(centro_alvo_dados.get("x", -1.0)), float(centro_alvo_dados.get("y", -1.0)))
		var territorio: Dictionary = predador.get("territorio", {}).duplicate(true)
		var centro_dados: Dictionary = territorio.get("centro", {})
		var centro_atual := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
		var raio := float(territorio.get("raio", 0.0))
		if centro_alvo.x < 0.0 or centro_alvo.x > 2400.0 or centro_alvo.y < 0.0 or centro_alvo.y > 1600.0 or centro_atual.x < 0.0 or raio < 20.0:
			continue
		var distancia := centro_atual.distance_to(centro_alvo)
		var distancia_alcance := raio + float(presa.get("territorio", {}).get("raio", 0.0)) + 20.0
		if distancia <= distancia_alcance:
			perseguicao["estado"] = "alcancou_alvo"
			perseguicao["centroAlvo"] = {"x":centro_alvo.x,"y":centro_alvo.y}
			perseguicao["alcancouUnix"] = int(perseguicao.get("alcancouUnix", agora_unix))
			predador["perseguicaoAtual"] = perseguicao
			grupos[predador_id] = predador
			houve_mudanca = true
			atualizados.append(predador.duplicate(true))
			continue
		var especie: Dictionary = repositorio_criaturas.obter_criatura(str(predador.get("especieId", "")))
		var velocidade := clampf(float(especie.get("ecologia", {}).get("velocidadePerseguicao", 48.0)), 8.0, 120.0)
		var passo := minf(distancia - distancia_alcance, velocidade * delta_segundos)
		var deslocamento := (centro_alvo - centro_atual).normalized() * passo
		var novo_centro := centro_atual + deslocamento
		territorio["centro"] = {"x":novo_centro.x,"y":novo_centro.y}
		predador["territorio"] = territorio
		var individuos: Array = predador.get("individuos", [])
		for indice in range(individuos.size()):
			var individuo: Dictionary = individuos[indice].duplicate(true)
			var posicao_dados: Dictionary = individuo.get("posicaoMundo", {})
			var posicao := Vector2(float(posicao_dados.get("x", centro_atual.x)), float(posicao_dados.get("y", centro_atual.y))) + deslocamento
			individuo["posicaoMundo"] = {"x":posicao.x,"y":posicao.y}
			if bool(individuo.get("vivo", true)):
				individuo["estadoMundo"] = "perseguindo_presa"
			individuos[indice] = individuo
		predador["individuos"] = individuos
		perseguicao["estado"] = "seguindo"
		perseguicao["centroAlvo"] = {"x":centro_alvo.x,"y":centro_alvo.y}
		perseguicao["ultimaAtualizacaoUnix"] = agora_unix
		predador["perseguicaoAtual"] = perseguicao
		predador["atualizadoUnix"] = agora_unix
		grupos[predador_id] = predador
		houve_mudanca = true
		atualizados.append(predador.duplicate(true))
	if houve_mudanca:
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível persistir o avanço das perseguições."}
	return {"ok":true,"grupos":atualizados}

## Registra o primeiro ataque de uma perseguição que já alcançou a presa.
## A relação alimentar e o estado de alcance são revalidados no servidor.
func registrar_confronto_ecologico(grupo_predador_id: String, grupo_presa_id: String, individuo_alvo_id: String, agora_unix: int) -> Dictionary:
	if grupo_predador_id.is_empty() or grupo_presa_id.is_empty() or individuo_alvo_id.is_empty() or agora_unix < 0:
		return {"ok":false,"erro":"Dados do confronto ecológico inválidos."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_predador_id) or not grupos.has(grupo_presa_id):
		return {"ok":false,"erro":"Um dos grupos do confronto não existe."}
	var predador: Dictionary = grupos[grupo_predador_id].duplicate(true)
	var presa: Dictionary = grupos[grupo_presa_id].duplicate(true)
	var perseguicao: Dictionary = predador.get("perseguicaoAtual", {})
	if str(perseguicao.get("grupoAlvoId", "")) != grupo_presa_id or str(perseguicao.get("estado", "")) != "alcancou_alvo":
		return {"ok":false,"erro":"O predador ainda não alcançou esta presa."}
	var especie_predadora: Dictionary = repositorio_criaturas.obter_criatura(str(predador.get("especieId", "")))
	var especie_presa: Dictionary = repositorio_criaturas.obter_criatura(str(presa.get("especieId", "")))
	if especie_predadora.is_empty() or especie_presa.is_empty():
		return {"ok":false,"erro":"Espécie do confronto não encontrada no catálogo."}
	var ecologia_predador: Dictionary = especie_predadora.get("ecologia", {})
	var ecologia_presa: Dictionary = especie_presa.get("ecologia", {})
	var relacao_declarada: bool = ecologia_predador.get("especiesPresas", []).has(str(especie_presa.get("id", ""))) or ecologia_presa.get("especiesPredadoras", []).has(str(especie_predadora.get("id", "")))
	if not relacao_declarada or str(predador.get("ecossistemaId", "")) != str(presa.get("ecossistemaId", "")):
		return {"ok":false,"erro":"A relação predador-presa não autoriza este confronto."}
	var alvo_encontrado := false
	for individuo in presa.get("individuos", []):
		if str(individuo.get("individuoId", "")) == individuo_alvo_id:
			alvo_encontrado = true
			break
	if not alvo_encontrado:
		return {"ok":false,"erro":"O alvo não pertence ao grupo da presa."}
	perseguicao["estado"] = "confronto_iniciado"
	perseguicao["confrontoUnix"] = agora_unix
	perseguicao["ultimoAlvoIndividuoId"] = individuo_alvo_id
	perseguicao["ultimoAtaqueUnix"] = agora_unix
	predador["perseguicaoAtual"] = perseguicao
	predador["atualizadoUnix"] = agora_unix
	presa["ultimoConfrontoEcologico"] = {"grupoPredadorId":grupo_predador_id,"individuoAlvoId":individuo_alvo_id,"horarioUnix":agora_unix}
	presa["atualizadoUnix"] = agora_unix
	grupos[grupo_predador_id] = predador
	grupos[grupo_presa_id] = presa
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir o confronto ecológico."}
	return {"ok":true,"predador":predador.duplicate(true),"presa":presa.duplicate(true)}

## Aplica a decisão coletiva da presa ao encontrar um predador declarado.
## A migração só usa rotas seguras presentes no registro persistido da espécie.
func reagir_ameaca_ecologica(grupo_presa_id: String, grupo_predador_id: String, tem_aliado_proximo: bool, agora_unix: int) -> Dictionary:
	if grupo_presa_id.is_empty() or grupo_predador_id.is_empty() or grupo_presa_id == grupo_predador_id or agora_unix < 0:
		return {"ok":false,"erro":"Dados da ameaça ecológica inválidos."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_presa_id) or not grupos.has(grupo_predador_id):
		return {"ok":false,"erro":"Grupo ameaçado ou predador não encontrado."}
	var presa: Dictionary = grupos[grupo_presa_id].duplicate(true)
	var predador: Dictionary = grupos[grupo_predador_id]
	if str(presa.get("ecossistemaId", "")) != str(predador.get("ecossistemaId", "")):
		return {"ok":false,"erro":"Grupos de ecossistemas diferentes não podem se enfrentar."}
	var especie_presa: Dictionary = repositorio_criaturas.obter_criatura(str(presa.get("especieId", "")))
	var especie_predadora: Dictionary = repositorio_criaturas.obter_criatura(str(predador.get("especieId", "")))
	if especie_presa.is_empty() or especie_predadora.is_empty():
		return {"ok":false,"erro":"Espécie não encontrada no catálogo."}
	var ecologia_presa: Dictionary = especie_presa.get("ecologia", {})
	var ecologia_predadora: Dictionary = especie_predadora.get("ecologia", {})
	var dieta_valida: bool = ecologia_predadora.get("especiesPresas", []).has(str(especie_presa.get("id", ""))) or ecologia_presa.get("especiesPredadoras", []).has(str(especie_predadora.get("id", "")))
	if not dieta_valida:
		return {"ok":false,"erro":"A relação predador-presa não está declarada."}
	var reacao_anterior: Dictionary = presa.get("reacaoAmeacaAtual", {})
	if str(reacao_anterior.get("grupoPredadorId", "")) == grupo_predador_id and agora_unix - int(reacao_anterior.get("horarioUnix", 0)) < 30:
		return {"ok":true,"acao":str(reacao_anterior.get("acao", "defender")),"grupo":presa.duplicate(true),"repetida":true}
	var rotas: Array = presa.get("rotasMigracao", ecologia_presa.get("rotasMigracao", []))
	var tem_rota := not rotas.is_empty()
	var forca_presa := _calcular_forca_territorial(presa)
	var forca_predador := _calcular_forca_territorial(predador)
	var personalidade: Dictionary = presa.get("personalidade", {})
	var vida_total := 0.0
	var vida_maxima_total := 0.0
	var vivos := 0
	for individuo in presa.get("individuos", []):
		if not bool(individuo.get("vivo", false)):
			continue
		var atributos: Dictionary = individuo.get("atributos", {})
		var vida_maxima := maxf(1.0, float(atributos.get("vidaMaxima", 1)))
		vida_total += clampf(float(individuo.get("vidaAtual", vida_maxima)), 0.0, vida_maxima)
		vida_maxima_total += vida_maxima
		vivos += 1
	if vivos == 0:
		return {"ok":false,"erro":"O grupo ameaçado não possui sobreviventes."}
	var vida_media := vida_total / maxf(1.0, vida_maxima_total)
	var memoria_ecologica_base: Array = SISTEMA_COMPORTAMENTO.combinar_memoria_defensiva_com_heranca(
		presa.get("memoriaEcologica", []), presa.get("individuos", []), agora_unix
	)
	var memoria_ecologica := _limpar_memoria_ecologica(memoria_ecologica_base, agora_unix)
	var estrategia_predador: Dictionary = predador.get("estrategiaCacaAtual", {})
	var assinatura_tatica := str(estrategia_predador.get("estrategia", ""))
	var memoria_reconhecida := _memoria_reconhece_ameaca(memoria_ecologica, str(especie_predadora.get("id", "")), str(presa.get("ecossistemaId", "")), str(presa.get("bioma", "")))
	var prudencia_media := 1.0
	var protecao_social_media := 1.0
	var coragem_individual_media := 1.0
	var agressividade_individual_media := 1.0
	var contagem_personalidades := 0
	for individuo in presa.get("individuos", []):
		if not bool(individuo.get("vivo", false)):
			continue
		var temperamento: Dictionary = individuo.get("personalidadeIndividual", {})
		prudencia_media += float(temperamento.get("prudencia", 1.0)) - 1.0
		protecao_social_media += float(temperamento.get("protecaoSocial", 1.0)) - 1.0
		coragem_individual_media += float(temperamento.get("coragem", 1.0)) - 1.0
		agressividade_individual_media += float(temperamento.get("agressividade", 1.0)) - 1.0
		contagem_personalidades += 1
	if contagem_personalidades > 0:
		prudencia_media = 1.0 + (prudencia_media - 1.0) / float(contagem_personalidades)
		protecao_social_media = 1.0 + (protecao_social_media - 1.0) / float(contagem_personalidades)
		coragem_individual_media = 1.0 + (coragem_individual_media - 1.0) / float(contagem_personalidades)
		agressividade_individual_media = 1.0 + (agressividade_individual_media - 1.0) / float(contagem_personalidades)
	var vigilia_cultural := _forca_tradicao_cultural(presa, "vigilia_coletiva", agora_unix)
	var caca_cooperativa_cultural := _forca_tradicao_cultural(presa, "caca_cooperativa", agora_unix)
	var defesa_cultural := _forca_tradicao_cultural(presa, "defesa_territorial", agora_unix)
	prudencia_media = minf(1.30, prudencia_media + float(vigilia_cultural) * 0.025)
	protecao_social_media = minf(1.30, protecao_social_media + float(maxi(caca_cooperativa_cultural, defesa_cultural)) * 0.025)
	var decisao: Dictionary = SISTEMA_COMPORTAMENTO.decidir_reacao_presa(
		forca_presa, forca_predador,
		float(personalidade.get("coragem", 1.0)) * coragem_individual_media,
		float(personalidade.get("agressividade", 1.0)) * agressividade_individual_media,
		vida_media, tem_rota, tem_aliado_proximo,
		prudencia_media, protecao_social_media
	)
	if memoria_reconhecida:
		decisao = SISTEMA_COMPORTAMENTO.ajustar_reacao_com_memoria(decisao, tem_rota, tem_aliado_proximo)
	var acao := str(decisao.get("acao", "defender"))
	if acao == "fugir":
		var centro_atual_dados: Dictionary = presa.get("territorio", {}).get("centro", {})
		var centro_atual := Vector2(float(centro_atual_dados.get("x", -1.0)), float(centro_atual_dados.get("y", -1.0)))
		for rota in rotas:
			if not (rota is Dictionary):
				continue
			var destino: Dictionary = rota.get("territorio", {})
			var centro_dados: Dictionary = destino.get("centro", {})
			var centro_novo := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
			var raio_novo := float(destino.get("raio", 0.0))
			var novo_ecossistema := str(rota.get("ecossistemaId", ""))
			if str(rota.get("id", "")).is_empty() or novo_ecossistema.is_empty() or str(rota.get("bioma", "")).is_empty() or str(rota.get("habitat", "")).is_empty():
				continue
			if centro_novo.x < 0.0 or centro_novo.x > 2400.0 or centro_novo.y < 0.0 or centro_novo.y > 1600.0 or raio_novo < 20.0 or raio_novo > 1000.0:
				continue
			var ocupado := false
			for outro_id in grupos:
				if str(outro_id) == grupo_presa_id:
					continue
				var outro: Dictionary = grupos[outro_id]
				if str(outro.get("ecossistemaId", "")) != novo_ecossistema:
					continue
				var t: Dictionary = outro.get("territorio", {})
				var c: Dictionary = t.get("centro", {})
				if Vector2(float(c.get("x", -10000.0)), float(c.get("y", -10000.0))).distance_to(centro_novo) < float(t.get("raio", 0.0)) + raio_novo:
					ocupado = true
					break
			if ocupado:
				continue
			var individuos: Array = presa.get("individuos", [])
			for i in range(individuos.size()):
				var membro: Dictionary = individuos[i].duplicate(true)
				var p: Dictionary = membro.get("posicaoMundo", {})
				var deslocamento := Vector2(float(p.get("x", centro_atual.x)), float(p.get("y", centro_atual.y))) - centro_atual
				if deslocamento.length() > raio_novo - 5.0:
					deslocamento = deslocamento.normalized() * (raio_novo - 5.0)
				var nova_posicao := centro_novo + deslocamento
				membro["posicaoMundo"] = {"x":nova_posicao.x,"y":nova_posicao.y}
				if bool(membro.get("vivo", false)):
					membro["estadoMundo"] = "fugindo_de_predador"
				individuos[i] = membro
			presa["individuos"] = individuos
			presa["territorio"] = destino.duplicate(true)
			presa["ecossistemaId"] = novo_ecossistema
			presa["bioma"] = str(rota.get("bioma", ""))
			presa["habitat"] = str(rota.get("habitat", ""))
			presa["ultimaMigracaoUnix"] = agora_unix
			presa["ultimaMigracao"] = {"rotaId":str(rota.get("id", "")),"motivo":"ameaca_predador","ecossistemaAnterior":str(grupos[grupo_presa_id].get("ecossistemaId", "")),"horarioUnix":agora_unix}
			break
		if str(presa.get("ecossistemaId", "")) == str(predador.get("ecossistemaId", "")):
			acao = "defender"
			for i in range(presa.get("individuos", []).size()):
				var membro: Dictionary = presa["individuos"][i].duplicate(true)
				if bool(membro.get("vivo", false)):
					membro["estadoMundo"] = "defendendo_grupo"
				presa["individuos"][i] = membro
	else:
		for i in range(presa.get("individuos", []).size()):
			var membro: Dictionary = presa["individuos"][i].duplicate(true)
			if bool(membro.get("vivo", false)):
				membro["estadoMundo"] = "defendendo_com_aliados" if acao == "defender_com_aliados" else "defendendo_grupo"
			presa["individuos"][i] = membro
	if acao in ["defender", "defender_com_aliados"]:
		var centro_predador_dados: Dictionary = predador.get("territorio", {}).get("centro", {})
		var individuo_vulneravel: Dictionary = {}
		for membro in presa.get("individuos", []):
			if not bool(membro.get("vivo", false)):
				continue
			var atributos_membro: Dictionary = membro.get("atributos", {})
			var vida_max_membro := maxf(1.0, float(atributos_membro.get("vidaMaxima", 1.0)))
			var vida_relativa := float(membro.get("vidaAtual", vida_max_membro)) / vida_max_membro
			if str(membro.get("faseVida", "")) == "filhote" or vida_relativa <= 0.55:
				individuo_vulneravel = membro
				break
		if not individuo_vulneravel.is_empty():
			var centro_protegido: Dictionary = individuo_vulneravel.get("posicaoMundo", {})
			presa["individuos"] = SISTEMA_COMPORTAMENTO.distribuir_papeis_defensivos(
				presa.get("individuos", []),
				str(individuo_vulneravel.get("individuoId", "")),
				Vector2(float(centro_predador_dados.get("x", -1.0)), float(centro_predador_dados.get("y", -1.0)))
			)
			presa["formacaoTatica"] = {
				"tipo":"proteger_vulneraveis",
				"centroProtegido":{"x":float(centro_protegido.get("x", -1.0)),"y":float(centro_protegido.get("y", -1.0))},
				"individuoProtegidoId":str(individuo_vulneravel.get("individuoId", "")),
				"centroAmeaca":{"x":float(centro_predador_dados.get("x", -1.0)),"y":float(centro_predador_dados.get("y", -1.0))},
				"raio":clampf(24.0 + float(defesa_cultural) * 2.0, 24.0, 34.0),"expiraUnix":agora_unix + 45 + defesa_cultural * 9
			}
		else:
			presa["formacaoTatica"] = {
				"tipo":"defesa",
				"centroAmeaca":{"x":float(centro_predador_dados.get("x", -1.0)),"y":float(centro_predador_dados.get("y", -1.0))},
				"raio":26.0,"expiraUnix":agora_unix + 45
			}
	else:
		presa.erase("formacaoTatica")
	memoria_ecologica.append({
		"especiePredadoraId":str(especie_predadora.get("id", "")),
		"ecossistemaId":str(grupos[grupo_presa_id].get("ecossistemaId", "")),
		"bioma":str(grupos[grupo_presa_id].get("bioma", "")),
		"estrategiaObservada":assinatura_tatica if not assinatura_tatica.is_empty() else "tática_nao_identificada",
		"respostaAprendida":acao,
		"horarioUnix":agora_unix
	})
	while memoria_ecologica.size() > 10:
		memoria_ecologica.pop_front()
	presa["memoriaEcologica"] = memoria_ecologica
	_aplicar_experiencia_temperamento(presa, "ameaca", grupo_predador_id, agora_unix)
	_registrar_experiencia_cultural(presa, "ameaca", grupo_predador_id, agora_unix)
	_registrar_vinculos_coletivos(presa, "ameaca", grupo_predador_id, agora_unix)
	presa["reacaoAmeacaAtual"] = {"grupoPredadorId":grupo_predador_id,"acao":acao,"motivo":str(decisao.get("motivo", "")),"horarioUnix":agora_unix,"forcaRelativa":snappedf(forca_presa / maxf(1.0, forca_predador), 0.01),"ameacaReconhecida":memoria_reconhecida}
	presa["atualizadoUnix"] = agora_unix
	grupos[grupo_presa_id] = presa
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir a reação da presa."}
	return {"ok":true,"acao":acao,"grupo":presa.duplicate(true),"reacao":decisao}


## Registra aprendizado somente após uma caçada real que terminou em fuga ou perda de rastro.
func _registrar_aprendizado_cacada(predador: Dictionary, presa: Dictionary, resultado: String, agora_unix: int) -> void:
	var memoria: Array = []
	for registro in predador.get("memoriaCacada", []):
		if not (registro is Dictionary):
			continue
		var horario_memoria := int(registro.get("horarioUnix", 0))
		if horario_memoria <= 0 or horario_memoria > agora_unix or agora_unix - horario_memoria > 604800:
			continue
		if str(registro.get("especiePresaId", "")).is_empty():
			continue
		memoria.append(registro.duplicate(true))
	memoria.append({
		"especiePresaId":str(presa.get("especieId", "")),
		"ecossistemaId":str(predador.get("ecossistemaId", "")),
		"bioma":str(predador.get("bioma", "")),
		"estrategiaAnterior":str(predador.get("estrategiaCacaAtual", {}).get("estrategia", "perseguir")),
		"resultado":resultado,
		"horarioUnix":agora_unix
	})
	while memoria.size() > 10:
		memoria.pop_front()
	predador["memoriaCacada"] = memoria

## Mantém apenas lembranças recentes e válidas; o grupo não conhece ameaças que nunca encontrou.
func _limpar_memoria_ecologica(memoria: Array, agora_unix: int) -> Array:
	var limpa: Array = []
	for registro in memoria:
		if not (registro is Dictionary):
			continue
		var horario := int(registro.get("horarioUnix", 0))
		var herdado := str(registro.get("origemAprendizado", "")) == "herdado"
		var referencia_tempo := int(registro.get("herdadoUnix", horario)) if herdado else horario
		var validade := 2592000 if herdado else 604800
		if referencia_tempo <= 0 or referencia_tempo > agora_unix or agora_unix - referencia_tempo > validade:
			continue
		if str(registro.get("especiePredadoraId", "")).is_empty() or str(registro.get("ecossistemaId", "")).is_empty():
			continue
		limpa.append(registro.duplicate(true))
	while limpa.size() > 10:
		limpa.pop_front()
	return limpa

func _memoria_reconhece_ameaca(memoria: Array, especie_predadora_id: String, ecossistema_id: String, bioma: String) -> bool:
	for registro in memoria:
		if str(registro.get("especiePredadoraId", "")) == especie_predadora_id and str(registro.get("ecossistemaId", "")) == ecossistema_id and str(registro.get("bioma", "")) == bioma:
			return true
	return false

## Persiste posições calculadas pelo servidor sem aceitar criação, remoção ou alteração de vida dos indivíduos.
func salvar_movimento_grupo(grupo_id: String, individuos_atualizados: Array, agora_unix: int = -1) -> bool:
	if individuos_atualizados.size() > 500:
		return false
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return false
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var existentes: Dictionary = {}
	for individuo in grupo.get("individuos", []):
		existentes[str(individuo.get("individuoId", ""))] = individuo
	if individuos_atualizados.size() != existentes.size():
		return false
	var novos: Array = []
	for individuo_novo in individuos_atualizados:
		if not (individuo_novo is Dictionary):
			return false
		var id := str(individuo_novo.get("individuoId", ""))
		if not existentes.has(id):
			return false
		var original: Dictionary = existentes[id]
		if bool(individuo_novo.get("vivo", true)) != bool(original.get("vivo", true)):
			return false
		var posicao: Dictionary = individuo_novo.get("posicaoMundo", {})
		if not (posicao is Dictionary):
			return false
		var ponto := Vector2(float(posicao.get("x", -1.0)), float(posicao.get("y", -1.0)))
		if ponto.x < 0.0 or ponto.x > 2400.0 or ponto.y < 0.0 or ponto.y > 1600.0:
			return false
		var territorio: Dictionary = grupo.get("territorio", {})
		var centro_dados: Dictionary = territorio.get("centro", {})
		var centro := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
		if ponto.distance_to(centro) > float(territorio.get("raio", 0.0)) + 0.01:
			return false
		var atualizado: Dictionary = original.duplicate(true)
		atualizado["posicaoMundo"] = {"x":ponto.x,"y":ponto.y}
		atualizado["estadoMundo"] = str(individuo_novo.get("estadoMundo", "acompanhando_grupo"))
		novos.append(atualizado)
	grupo["individuos"] = novos
	grupo["atualizadoUnix"] = agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	return _gravar_banco(banco)

## Retira um indivíduo domesticado do grupo, preservando o registro histórico.
func registrar_domesticacao_individuo(grupo_id: String, individuo_id: String, agora_unix: int = -1) -> Dictionary:
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo selvagem não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var individuos: Array = grupo.get("individuos", [])
	var indice_alvo := -1
	for indice in range(individuos.size()):
		if str(individuos[indice].get("individuoId", "")) == individuo_id:
			indice_alvo = indice
			break
	if indice_alvo < 0:
		return {"ok":false,"erro":"A criatura não está mais no grupo."}
	var alvo: Dictionary = individuos[indice_alvo].duplicate(true)
	var derrotado_em_combate := bool(alvo.get("derrotadoEmCombate", false))
	if (not bool(alvo.get("vivo", false)) and not derrotado_em_combate) or bool(alvo.get("domesticado", false)):
		return {"ok":false,"erro":"Essa criatura não está mais disponível para domesticação."}
	alvo["vivo"] = false
	alvo["domesticado"] = true
	alvo["causaSaida"] = "domesticacao"
	alvo["domesticadoUnix"] = agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	individuos[indice_alvo] = alvo
	grupo["individuos"] = individuos
	if not derrotado_em_combate:
		var populacao: Dictionary = grupo.get("populacaoEstado", {})
		populacao["quantidade"] = maxi(0, int(populacao.get("quantidade", individuos.size())) - 1)
		grupo["populacaoEstado"] = populacao
	if str(grupo.get("liderAtual", {}).get("individuoId", "")) == individuo_id:
		var sucessao := SISTEMA_LIDERES.suceder_lider(grupo, individuo_id, hash(grupo_id + ":" + individuo_id + ":domesticado"))
		grupo["liderAtual"] = sucessao.get("lider", {}) if bool(sucessao.get("temLider", false)) else {}
	grupo["atualizadoUnix"] = int(alvo["domesticadoUnix"])
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a saída da criatura do grupo."}
	return {"ok":true,"grupo":grupo.duplicate(true),"individuo":alvo.duplicate(true)}

## Registra a derrota de um indivíduo por jogador e mantém o corpo para domesticação.
## Registra luto em todos os grupos que tinham um vínculo positivo com quem morreu.
## O efeito é individual, persistente e só atinge sobreviventes que realmente conheciam a criatura.
func _registrar_luto_em_grupos(grupos: Dictionary, grupo_morto_id: String, individuo_morto_id: String, instante: int, causa: String) -> void:
	if grupo_morto_id.is_empty() or individuo_morto_id.is_empty():
		return
	for id_grupo in grupos.keys():
		var grupo: Dictionary = grupos[id_grupo].duplicate(true)
		var individuos: Array = grupo.get("individuos", [])
		var alterou := false
		for indice in range(individuos.size()):
			var sobrevivente: Dictionary = individuos[indice].duplicate(true)
			if not bool(sobrevivente.get("vivo", false)) or str(sobrevivente.get("individuoId", "")) == individuo_morto_id:
				continue
			var vinculo_encontrado: Dictionary = {}
			for vinculo in sobrevivente.get("vinculosIndividuais", []):
				if str(vinculo.get("grupoId", "")) == grupo_morto_id and str(vinculo.get("individuoId", "")) == individuo_morto_id:
					vinculo_encontrado = vinculo
					break
			if vinculo_encontrado.is_empty():
				continue
			var amizade := clampf(float(vinculo_encontrado.get("amizade", 0.0)), 0.0, 1.0)
			var confianca := clampf(float(vinculo_encontrado.get("confianca", 0.0)), 0.0, 1.0)
			var rivalidade := clampf(float(vinculo_encontrado.get("rivalidade", 0.0)), 0.0, 1.0)
			var afinidade := amizade * 0.45 + confianca * 0.55 - rivalidade * 0.65
			if afinidade < 0.35:
				continue
			var memorias: Array = sobrevivente.get("memoriasLuto", [])
			var ja_registrado := false
			for memoria in memorias:
				if str(memoria.get("individuoPerdidoId", "")) == individuo_morto_id and str(memoria.get("grupoPerdidoId", "")) == grupo_morto_id:
					ja_registrado = true
					break
			if ja_registrado:
				continue
			var personalidade: Dictionary = sobrevivente.get("personalidadeIndividual", _gerar_personalidade_individual(str(sobrevivente.get("individuoId", "")))).duplicate(true)
			personalidade["prudencia"] = clampf(float(personalidade.get("prudencia", 1.0)) + 0.08 * afinidade, 0.70, 1.30)
			personalidade["agressividade"] = clampf(float(personalidade.get("agressividade", 1.0)) + 0.06 * afinidade, 0.70, 1.30)
			personalidade["protecaoSocial"] = clampf(float(personalidade.get("protecaoSocial", 1.0)) + 0.05 * afinidade, 0.70, 1.30)
			personalidade["coragem"] = clampf(float(personalidade.get("coragem", 1.0)) - 0.04 * afinidade, 0.70, 1.30)
			sobrevivente["personalidadeIndividual"] = personalidade
			sobrevivente["estadoEmocional"] = "enlutado"
			sobrevivente["intensidadeLuto"] = 1.0
			sobrevivente["apoiosEmocionaisRecebidos"] = 0
			sobrevivente["ultimaPerdaUnix"] = instante
			memorias.append({"grupoPerdidoId":grupo_morto_id,"individuoPerdidoId":individuo_morto_id,"horarioUnix":instante,"causa":causa,"afinidade":afinidade})
			if memorias.size() > 10:
				memorias = memorias.slice(memorias.size() - 10, memorias.size())
			sobrevivente["memoriasLuto"] = memorias
			individuos[indice] = sobrevivente
			alterou = true
		if alterou:
			grupo["individuos"] = individuos
			grupo["atualizadoUnix"] = instante
			grupos[id_grupo] = grupo

func registrar_derrota_em_combate(grupo_id: String, individuo_id: String, uid_vencedor: String, agora_unix: int = -1) -> Dictionary:
	if grupo_id.is_empty() or individuo_id.is_empty() or uid_vencedor.is_empty() or uid_vencedor.length() > 128:
		return {"ok":false,"erro":"Identificação da derrota inválida."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo da criatura derrotada não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var individuos: Array = grupo.get("individuos", [])
	var indice_alvo := -1
	for i in range(individuos.size()):
		if str(individuos[i].get("individuoId", "")) == individuo_id:
			indice_alvo = i
			break
	if indice_alvo < 0:
		return {"ok":false,"erro":"Indivíduo derrotado não pertence ao grupo."}
	var alvo: Dictionary = individuos[indice_alvo].duplicate(true)
	if bool(alvo.get("domesticado", false)):
		return {"ok":false,"erro":"Esse indivíduo já foi domesticado."}
	if bool(alvo.get("derrotadoEmCombate", false)):
		return {"ok":true,"grupo":grupo.duplicate(true),"individuo":alvo.duplicate(true),"duplicado":true}
	if not bool(alvo.get("vivo", true)):
		return {"ok":false,"erro":"O indivíduo já estava morto antes do combate."}
	var instante := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	alvo["vivo"] = false
	alvo["vidaAtual"] = 0
	alvo["derrotadoEmCombate"] = true
	alvo["derrotadoPorUid"] = uid_vencedor
	alvo["derrotadoEmCombateUnix"] = instante
	alvo["causaMorte"] = "combate_jogador"
	var especie: Dictionary = repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
	alvo["carcaca"] = _criar_carcarca(alvo, especie, instante)
	individuos[indice_alvo] = alvo
	grupo["individuos"] = individuos
	var populacao: Dictionary = grupo.get("populacaoEstado", {})
	populacao["quantidade"] = maxi(0, int(populacao.get("quantidade", 0)) - 1)
	grupo["populacaoEstado"] = populacao
	if str(grupo.get("liderAtual", {}).get("individuoId", "")) == individuo_id:
		var sucessao := SISTEMA_LIDERES.suceder_lider(grupo, individuo_id, hash(individuo_id + ":derrotado:" + str(instante)))
		grupo["liderAtual"] = sucessao.get("lider", {}) if bool(sucessao.get("temLider", false)) else {}
	grupo["atualizadoUnix"] = instante
	grupos[grupo_id] = grupo
	_registrar_luto_em_grupos(grupos, grupo_id, individuo_id, instante, "combate_jogador")
	grupo = grupos[grupo_id]
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a criatura derrotada."}
	return {"ok":true,"grupo":grupo.duplicate(true),"individuo":alvo.duplicate(true)}

## Aplica dano calculado pelo servidor; morte ecológica reduz a população e pode trocar o líder.
func aplicar_dano_ecologico(grupo_id: String, individuo_id: String, dano: int, agora_unix: int = -1) -> Dictionary:
	if dano <= 0 or dano > 100000000:
		return {"ok":false,"erro":"Dano ecológico inválido."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo da presa não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var individuos: Array = grupo.get("individuos", [])
	var indice_alvo := -1
	for i in range(individuos.size()):
		if str(individuos[i].get("individuoId", "")) == individuo_id:
			indice_alvo = i
			break
	if indice_alvo < 0:
		return {"ok":false,"erro":"Indivíduo alvo não pertence ao grupo."}
	var alvo: Dictionary = individuos[indice_alvo].duplicate(true)
	if not bool(alvo.get("vivo", false)):
		return {"ok":false,"erro":"Indivíduo já está morto."}
	var atributos: Dictionary = alvo.get("atributos", {})
	var vida_maxima := maxi(1, int(atributos.get("vidaMaxima", 1)))
	var vida_atual := clampi(int(alvo.get("vidaAtual", vida_maxima)), 1, vida_maxima)
	var vida_restante := maxi(0, vida_atual - dano)
	alvo["vidaAtual"] = vida_restante
	alvo["ultimoDanoEcologicoUnix"] = agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	if vida_restante <= 0:
		alvo["vivo"] = false
		alvo["causaMorte"] = "combate_ecologico"
		alvo["morteUnix"] = int(alvo["ultimoDanoEcologicoUnix"])
		var especie_morta: Dictionary = repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
		alvo["carcaca"] = _criar_carcarca(alvo, especie_morta, int(alvo["morteUnix"]))
		var estado: Dictionary = grupo.get("populacaoEstado", {})
		estado["quantidade"] = maxi(0, int(estado.get("quantidade", 0)) - 1)
		estado["minima"] = mini(int(estado.get("minima", 0)), int(estado["quantidade"]))
		estado["totalMortesEcologicas"] = int(estado.get("totalMortesEcologicas", 0)) + 1
		grupo["populacaoEstado"] = estado
	individuos[indice_alvo] = alvo
	grupo["individuos"] = individuos
	var lider_anterior := str(grupo.get("liderAtual", {}).get("individuoId", ""))
	if vida_restante <= 0 and lider_anterior == individuo_id:
		var sucessao := SISTEMA_LIDERES.suceder_lider(grupo, individuo_id, hash(individuo_id + ":" + str(alvo["morteUnix"])))
		grupo["liderAtual"] = sucessao.get("lider", {}) if bool(sucessao.get("temLider", false)) else {}
	elif vida_restante <= 0 and lider_anterior.is_empty():
		var avaliacao := SISTEMA_LIDERES.avaliar_grupo(grupo, hash(grupo_id + ":" + str(alvo["morteUnix"])))
		grupo["liderAtual"] = avaliacao.get("lider", {})
	grupo["atualizadoUnix"] = int(alvo.get("ultimoDanoEcologicoUnix", 0))
	grupos[grupo_id] = grupo
	if vida_restante <= 0:
		_registrar_luto_em_grupos(grupos, grupo_id, individuo_id, int(alvo["morteUnix"]), "combate_ecologico")
		grupo = grupos[grupo_id]
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Falha ao persistir dano ecológico."}
	return {"ok":true,"morreu":vida_restante <= 0,"vidaRestante":vida_restante,"grupo":grupo.duplicate(true),"individuo":alvo.duplicate(true)}

## Conta ciclos de escassez e migra o grupo inteiro para um habitat alternativo declarado pela espécie.
func avaliar_migracao_por_escassez(grupo_id: String, alimento_disponivel: float, agora_unix: int) -> Dictionary:
	if alimento_disponivel < 0.0 or alimento_disponivel > 1.0:
		return {"ok":false,"erro":"Índice alimentar inválido."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	if alimento_disponivel <= 0.25:
		grupo["ciclosEscassezAlimentar"] = int(grupo.get("ciclosEscassezAlimentar", 0)) + 1
	else:
		grupo["ciclosEscassezAlimentar"] = 0
	if int(grupo["ciclosEscassezAlimentar"]) < 3:
		grupos[grupo_id] = grupo
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível salvar o estado de escassez."}
		return {"ok":true,"migrou":false,"grupo":grupo}
	if int(grupo.get("ultimaMigracaoUnix", 0)) > 0 and agora_unix < int(grupo.get("ultimaMigracaoUnix", 0)) + 86400:
		grupos[grupo_id] = grupo
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível salvar o intervalo de migração."}
		return {"ok":true,"migrou":false,"grupo":grupo}
	var rotas: Array = grupo.get("rotasMigracao", [])
	var territorio_atual: Dictionary = grupo.get("territorio", {})
	var centro_atual_dados: Dictionary = territorio_atual.get("centro", {})
	var centro_atual := Vector2(float(centro_atual_dados.get("x", -1.0)), float(centro_atual_dados.get("y", -1.0)))
	for rota in rotas:
		if not (rota is Dictionary):
			continue
		var destino: Dictionary = rota.get("territorio", {})
		var centro_dados: Dictionary = destino.get("centro", {})
		var centro_novo := Vector2(float(centro_dados.get("x", -1.0)), float(centro_dados.get("y", -1.0)))
		var raio_novo := float(destino.get("raio", 0.0))
		var ecossistema_novo := str(rota.get("ecossistemaId", ""))
		var bioma_novo := str(rota.get("bioma", ""))
		var habitat_novo := str(rota.get("habitat", ""))
		var rota_id := str(rota.get("id", ""))
		if rota_id.is_empty() or ecossistema_novo.is_empty() or bioma_novo.is_empty() or habitat_novo.is_empty():
			continue
		if centro_novo.x < 0.0 or centro_novo.x > 2400.0 or centro_novo.y < 0.0 or centro_novo.y > 1600.0 or raio_novo < 20.0 or raio_novo > 1000.0:
			continue
		if centro_novo.distance_to(centro_atual) < 1.0:
			continue
		var grupo_ocupante_id := ""
		for outro_id in grupos:
			if str(outro_id) == grupo_id:
				continue
			var outro: Dictionary = grupos[outro_id]
			if str(outro.get("ecossistemaId", "")) != ecossistema_novo:
				continue
			var t: Dictionary = outro.get("territorio", {})
			var c: Dictionary = t.get("centro", {})
			var centro_outro := Vector2(float(c.get("x", -10000.0)), float(c.get("y", -10000.0)))
			if centro_outro.distance_to(centro_novo) < float(t.get("raio", 0.0)) + raio_novo:
				grupo_ocupante_id = str(outro_id)
				break
		if not grupo_ocupante_id.is_empty():
			var defensor: Dictionary = grupos[grupo_ocupante_id].duplicate(true)
			var disputa := _resolver_disputa_territorial(grupo, defensor, agora_unix)
			if not bool(disputa.get("ok", false)):
				return disputa
			grupo = disputa.get("grupoDesafiante", grupo)
			defensor = disputa.get("grupoDefensor", defensor)
			var vencedor_id := str(disputa.get("vencedorGrupoId", ""))
			var registro_disputa := {
				"grupoDesafiante":grupo_id,
				"grupoDefensor":grupo_ocupante_id,
				"resultado":str(disputa.get("resultado", "")),
				"representantes":disputa.get("representantes", {}),
				"turnosDuelo":disputa.get("turnosDuelo", []),
				"decisaoDerrotado":str(disputa.get("decisaoDerrotado", "")),
				"turnosConfrontoColetivo":disputa.get("turnosConfrontoColetivo", []),
				"moralVencedorAposDuelo":float(disputa.get("moralVencedorAposDuelo", 1.0)),
				"horarioUnix":agora_unix
			}
			_registrar_relacao_conflito(grupo, defensor, agora_unix, vencedor_id)
			var historico_defensor: Array = defensor.get("disputasTerritoriais", [])
			historico_defensor.append(registro_disputa)
			defensor["disputasTerritoriais"] = historico_defensor.slice(maxi(0, historico_defensor.size() - 20))
			defensor["ultimaDisputaTerritorial"] = registro_disputa
			grupo["ultimaDisputaTerritorial"] = registro_disputa
			grupo["ciclosEscassezAlimentar"] = 0
			if vencedor_id != grupo_id:
				grupos[grupo_ocupante_id] = defensor
				grupos[grupo_id] = grupo
				banco["grupos"] = grupos
				if not _gravar_banco(banco):
					return {"ok":false,"erro":"Não foi possível salvar a disputa territorial."}
				return {"ok":true,"migrou":false,"disputaTerritorial":true,"vencedor":vencedor_id,"resultado":str(disputa.get("resultado", "defensor_manteve_territorio")),"decisaoDerrotado":str(disputa.get("decisaoDerrotado", "")),"grupo":grupo.duplicate(true)}
			var centro_defensor_dados: Dictionary = defensor.get("territorio", {}).get("centro", {})
			var centro_defensor := Vector2(float(centro_defensor_dados.get("x", -1.0)), float(centro_defensor_dados.get("y", -1.0)))
			var direcao := centro_defensor - centro_novo
			if direcao.length() < 0.01:
				var angulo := float(abs(hash(grupo_id + "|" + grupo_ocupante_id)) % 6283) / 1000.0
				direcao = Vector2(cos(angulo), sin(angulo))
			else:
				direcao = direcao.normalized()
			var raio_defensor := float(defensor.get("territorio", {}).get("raio", 0.0))
			var centro_recuo := centro_novo + direcao * (raio_novo + raio_defensor + 12.0)
			var pode_recuar := centro_recuo.x >= raio_defensor and centro_recuo.x <= 2400.0 - raio_defensor and centro_recuo.y >= raio_defensor and centro_recuo.y <= 1600.0 - raio_defensor
			if not pode_recuar or _territorio_tem_conflito(grupos, grupo_id, grupo_ocupante_id, ecossistema_novo, centro_recuo, raio_defensor):
				grupos[grupo_ocupante_id] = defensor
				grupos[grupo_id] = grupo
				banco["grupos"] = grupos
				if not _gravar_banco(banco):
					return {"ok":false,"erro":"Não foi possível salvar a disputa territorial."}
				return {"ok":true,"migrou":false,"disputaTerritorial":true,"vencedor":grupo_id,"resultado":"invasor_venceu_mas_sem_recuo_seguro","grupo":grupo.duplicate(true)}
			var deslocamento_recuo := centro_recuo - centro_defensor
			var individuos_defensor: Array = defensor.get("individuos", [])
			for indice_defensor in range(individuos_defensor.size()):
				var membro: Dictionary = individuos_defensor[indice_defensor].duplicate(true)
				var pos_membro: Dictionary = membro.get("posicaoMundo", {})
				var pos_nova := Vector2(float(pos_membro.get("x", centro_defensor.x)), float(pos_membro.get("y", centro_defensor.y)) + 0.0) + deslocamento_recuo
				membro["posicaoMundo"] = {"x":pos_nova.x,"y":pos_nova.y}
				if bool(membro.get("vivo", false)):
					membro["estadoMundo"] = "recuando_apos_disputa"
				individuos_defensor[indice_defensor] = membro
			defensor["individuos"] = individuos_defensor
			var territorio_defensor: Dictionary = defensor.get("territorio", {}).duplicate(true)
			territorio_defensor["centro"] = {"x":centro_recuo.x,"y":centro_recuo.y}
			defensor["territorio"] = territorio_defensor
			grupos[grupo_ocupante_id] = defensor
		var individuos: Array = grupo.get("individuos", [])
		for indice in range(individuos.size()):
			var individuo: Dictionary = individuos[indice].duplicate(true)
			var p: Dictionary = individuo.get("posicaoMundo", {})
			var deslocamento := Vector2(float(p.get("x", centro_atual.x)), float(p.get("y", centro_atual.y))) - centro_atual
			if deslocamento.length() > raio_novo - 5.0:
				deslocamento = deslocamento.normalized() * (raio_novo - 5.0)
			var nova_posicao := centro_novo + deslocamento
			individuo["posicaoMundo"] = {"x":nova_posicao.x,"y":nova_posicao.y}
			individuo["estadoMundo"] = "migrando"
			individuos[indice] = individuo
		grupo["individuos"] = individuos
		var ecossistema_anterior := str(grupo.get("ecossistemaId", ""))
		grupo["territorio"] = destino.duplicate(true)
		grupo["ecossistemaId"] = ecossistema_novo
		grupo["bioma"] = bioma_novo
		grupo["habitat"] = habitat_novo
		grupo["ultimaMigracaoUnix"] = agora_unix
		grupo["ciclosEscassezAlimentar"] = 0
		grupo["atualizadoUnix"] = agora_unix
		grupo["ultimaMigracao"] = {"rotaId":rota_id,"ecossistemaAnterior":ecossistema_anterior,"horarioUnix":agora_unix}
		grupos[grupo_id] = grupo
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível persistir a migração."}
		return {"ok":true,"migrou":true,"rotaId":rota_id,"disputaTerritorial":not grupo_ocupante_id.is_empty(),"resultadoDisputa":"invasor_conquistou_territorio" if not grupo_ocupante_id.is_empty() else "sem_disputa","grupo":grupo.duplicate(true)}
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a tentativa de migração."}
	return {"ok":true,"migrou":false,"semDestinoDisponivel":true,"grupo":grupo}



## Resolve primeiro um duelo entre representantes; depois permite ao derrotado optar por guerra coletiva.
## Toda a resolução é determinística e executada pelo repositório autoritativo do servidor.
func _resolver_disputa_territorial(desafiante_in: Dictionary, defensor_in: Dictionary, agora_unix: int) -> Dictionary:
	var desafiante: Dictionary = desafiante_in.duplicate(true)
	var defensor: Dictionary = defensor_in.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(desafiante.get("grupoId", "")) + "|" + str(defensor.get("grupoId", "")) + "|" + str(agora_unix))
	var fila_a := _ordenar_representantes(desafiante)
	var fila_d := _ordenar_representantes(defensor)
	if fila_a.is_empty() or fila_d.is_empty():
		var vencedor_sem_duelo := str(defensor.get("grupoId", "")) if fila_a.is_empty() else str(desafiante.get("grupoId", ""))
		return {"ok":true,"grupoDesafiante":desafiante,"grupoDefensor":defensor,"vencedorGrupoId":vencedor_sem_duelo,"resultado":"grupo_sem_combatentes_vivos","representantes":{},"turnosDuelo":[],"decisaoDerrotado":"sem_combatentes"}
	var representante_a_id := str(fila_a[0].get("individuoId", ""))
	var representante_d_id := str(fila_d[0].get("individuoId", ""))
	var turnos_duelo: Array = []
	var indice_a := 0
	var indice_d := 0
	var turnos := 0
	while indice_a < fila_a.size() and indice_d < fila_d.size() and turnos < 500:
		var id_a := str(fila_a[indice_a].get("individuoId", ""))
		var id_d := str(fila_d[indice_d].get("individuoId", ""))
		var membro_a := _obter_individuo(desafiante, id_a)
		var membro_d := _obter_individuo(defensor, id_d)
		if membro_a.is_empty() or not bool(membro_a.get("vivo", false)):
			indice_a += 1
			continue
		if membro_d.is_empty() or not bool(membro_d.get("vivo", false)):
			indice_d += 1
			continue
		var agilidade_a := _atributo_com_equipamento(membro_a, "agilidade")
		var agilidade_d := _atributo_com_equipamento(membro_d, "agilidade")
		var a_comeca := agilidade_a > agilidade_d or (is_equal_approx(agilidade_a, agilidade_d) and str(desafiante.get("grupoId", "")) < str(defensor.get("grupoId", "")))
		for atacante_lado in (["a", "d"] if a_comeca else ["d", "a"]):
			var atacante_grupo: Dictionary = desafiante if atacante_lado == "a" else defensor
			var alvo_grupo: Dictionary = defensor if atacante_lado == "a" else desafiante
			var atacante_id := id_a if atacante_lado == "a" else id_d
			var alvo_id := id_d if atacante_lado == "a" else id_a
			var atacante := _obter_individuo(atacante_grupo, atacante_id)
			var alvo := _obter_individuo(alvo_grupo, alvo_id)
			if atacante.is_empty() or alvo.is_empty() or not bool(atacante.get("vivo", false)) or not bool(alvo.get("vivo", false)):
				continue
			var ataque := _atributo_com_equipamento(atacante, "ataque")
			var defesa := _atributo_com_equipamento(alvo, "defesa")
			if atacante_lado == "a":
				defesa *= 1.15
			var moral := float(atacante_grupo.get("moralMultiplicador", 1.0))
			var dano := maxi(1, roundi(maxf(1.0, ataque * moral * rng.randf_range(0.82, 1.12) - defesa * 0.30)))
			var dano_aplicado := _aplicar_dano_local(alvo_grupo, alvo_id, dano, agora_unix)
			turnos_duelo.append({"atacante":atacante_id,"alvo":alvo_id,"dano":dano_aplicado,"morreu":not bool(_obter_individuo(alvo_grupo, alvo_id).get("vivo", false))})
			if atacante_lado == "a":
				desafiante = atacante_grupo
				defensor = alvo_grupo
			else:
				defensor = atacante_grupo
				desafiante = alvo_grupo
			if not bool(_obter_individuo(alvo_grupo, alvo_id).get("vivo", false)):
				if atacante_lado == "a":
					indice_d += 1
				else:
					indice_a += 1
			turnos += 1
			if turnos >= 500:
				break
		if indice_a >= fila_a.size() or indice_d >= fila_d.size():
			break
	var vencedor_duelo_id := str(desafiante.get("grupoId", "")) if indice_d >= fila_d.size() else str(defensor.get("grupoId", ""))
	var vencedor_duelo: Dictionary = desafiante if vencedor_duelo_id == str(desafiante.get("grupoId", "")) else defensor
	var perdedor_duelo: Dictionary = defensor if vencedor_duelo_id == str(desafiante.get("grupoId", "")) else desafiante
	_aplicar_bonus_moral(vencedor_duelo, agora_unix)
	var moral_pos_duelo := float(vencedor_duelo.get("moralMultiplicador", 1.0))
	var continuar := _decidir_guerra_coletiva(perdedor_duelo, vencedor_duelo, rng)
	var decisao := "continuar_com_todo_o_grupo" if continuar else "aceitar_derrota_e_recuar"
	var turnos_coletivos: Array = []
	var vencedor_final_id := vencedor_duelo_id
	if continuar:
		var guerra := _resolver_confronto_coletivo(desafiante, defensor, agora_unix, rng)
		desafiante = guerra.get("grupoDesafiante", desafiante)
		defensor = guerra.get("grupoDefensor", defensor)
		vencedor_final_id = str(guerra.get("vencedorGrupoId", ""))
		turnos_coletivos = guerra.get("turnos", [])
		if vencedor_final_id.is_empty():
			vencedor_final_id = vencedor_duelo_id
	_reavaliar_lideranca(desafiante, agora_unix)
	_reavaliar_lideranca(defensor, agora_unix)
	var vencedor_nome := "invasor_conquistou_territorio" if vencedor_final_id == str(desafiante.get("grupoId", "")) else "defensor_manteve_territorio"
	return {"ok":true,"grupoDesafiante":desafiante,"grupoDefensor":defensor,"vencedorGrupoId":vencedor_final_id,"resultado":vencedor_nome,"representantes":{"desafiante":representante_a_id,"defensor":representante_d_id},"turnosDuelo":turnos_duelo.slice(0, 1000),"decisaoDerrotado":decisao,"turnosConfrontoColetivo":turnos_coletivos.slice(0, 1000),"moralVencedorAposDuelo":moral_pos_duelo}

func _ordenar_representantes(grupo: Dictionary) -> Array:
	var vivos: Array = []
	for individuo in grupo.get("individuos", []):
		if bool(individuo.get("vivo", false)):
			vivos.append(individuo.duplicate(true))
	vivos.sort_custom(func(a, b):
		var id_a := str(a.get("individuoId", ""))
		var id_b := str(b.get("individuoId", ""))
		var lider_id := str(grupo.get("liderAtual", {}).get("individuoId", ""))
		if id_a == lider_id:
			return true
		if id_b == lider_id:
			return false
		var poder_a := _poder_individual(a)
		var poder_b := _poder_individual(b)
		if is_equal_approx(poder_a, poder_b):
			return id_a < id_b
		return poder_a > poder_b
	)
	return vivos

func _poder_individual(individuo: Dictionary) -> float:
	var ataque := _atributo_com_equipamento(individuo, "ataque")
	var defesa := _atributo_com_equipamento(individuo, "defesa")
	var vida := float(individuo.get("vidaAtual", individuo.get("atributos", {}).get("vidaMaxima", 1)))
	var agilidade := _atributo_com_equipamento(individuo, "agilidade")
	var magia := float(individuo.get("atributos", {}).get("poderMagico", 0))
	return ataque * 1.5 + defesa + vida * 0.1 + agilidade * 0.5 + magia

func _atributo_com_equipamento(individuo: Dictionary, atributo: String) -> float:
	var atributos: Dictionary = individuo.get("_atributosCombate", individuo.get("atributos", {}))
	var valor := float(atributos.get(atributo, 1 if atributo == "ataque" else 0))
	var equipamentos: Array = individuo.get("_equipamentosCombate", individuo.get("equipamentoIds", []))
	for item_id in equipamentos:
		var item := SISTEMA_EQUIPAMENTOS.obter(str(item_id))
		if atributo == "ataque":
			valor += float(item.get("dano", 0)) * 0.25
		elif atributo == "defesa":
			valor += float(item.get("defesa", 0))
	return valor

func _obter_individuo(grupo: Dictionary, individuo_id: String) -> Dictionary:
	for individuo in grupo.get("individuos", []):
		if str(individuo.get("individuoId", "")) == individuo_id:
			var copia: Dictionary = individuo.duplicate(true)
			var lider: Dictionary = grupo.get("liderAtual", {})
			if str(lider.get("individuoId", "")) == individuo_id:
				copia["_atributosCombate"] = lider.get("atributosLider", copia.get("atributos", {})).duplicate(true)
				copia["_equipamentosCombate"] = lider.get("equipamentoIds", copia.get("equipamentoIds", [])).duplicate(true)
			return copia
	return {}

func _aplicar_dano_local(grupo: Dictionary, individuo_id: String, dano: int, agora_unix: int) -> int:
	var individuos: Array = grupo.get("individuos", [])
	for indice in range(individuos.size()):
		if str(individuos[indice].get("individuoId", "")) != individuo_id:
			continue
		var alvo: Dictionary = individuos[indice].duplicate(true)
		if not bool(alvo.get("vivo", false)):
			return 0
		var vida_maxima := maxi(1, int(alvo.get("atributos", {}).get("vidaMaxima", 1)))
		var vida := clampi(int(alvo.get("vidaAtual", vida_maxima)), 0, vida_maxima)
		var restante := maxi(0, vida - maxi(1, dano))
		alvo["vidaAtual"] = restante
		alvo["ultimoDanoEcologicoUnix"] = agora_unix
		if restante == 0:
			alvo["vivo"] = false
			alvo["causaMorte"] = "disputa_territorial"
			alvo["morteUnix"] = agora_unix
			var especie: Dictionary = repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
			alvo["carcaca"] = _criar_carcarca(alvo, especie, agora_unix)
			var estado: Dictionary = grupo.get("populacaoEstado", {})
			estado["quantidade"] = maxi(0, int(estado.get("quantidade", 0)) - 1)
			estado["minima"] = mini(int(estado.get("minima", 0)), int(estado["quantidade"]))
			estado["totalMortesEcologicas"] = int(estado.get("totalMortesEcologicas", 0)) + 1
			grupo["populacaoEstado"] = estado
		individuos[indice] = alvo
		grupo["individuos"] = individuos
		return mini(maxi(1, dano), vida)
	return 0

func _reavaliar_lideranca(grupo: Dictionary, agora_unix: int) -> void:
	var avaliacao := SISTEMA_LIDERES.avaliar_grupo(grupo, hash(str(grupo.get("grupoId", "")) + ":" + str(agora_unix)))
	grupo["liderAtual"] = avaliacao.get("lider", {}) if bool(avaliacao.get("temLider", false)) else {}

func _aplicar_bonus_moral(grupo: Dictionary, agora_unix: int) -> void:
	var moral_anterior := clampf(float(grupo.get("moralMultiplicador", 1.0)), 0.25, 2.0)
	var moral_nova := minf(2.0, moral_anterior * 1.20)
	grupo["moralMultiplicador"] = moral_nova
	grupo["moralAtualizadaUnix"] = agora_unix
	var individuos: Array = grupo.get("individuos", [])
	for indice in range(individuos.size()):
		var membro: Dictionary = individuos[indice].duplicate(true)
		if bool(membro.get("vivo", false)):
			membro["moralMultiplicador"] = minf(2.0, float(membro.get("moralMultiplicador", moral_anterior)) * 1.20)
		individuos[indice] = membro
	grupo["individuos"] = individuos

func _decidir_guerra_coletiva(perdedor: Dictionary, vencedor: Dictionary, rng: RandomNumberGenerator) -> bool:
	var poder_perdedor := 0.0
	var poder_vencedor := 0.0
	var vivos_perdedor := 0
	var vivos_vencedor := 0
	var saude_perdedor := 0.0
	var saude_vencedor := 0.0
	for membro in perdedor.get("individuos", []):
		if bool(membro.get("vivo", false)):
			vivos_perdedor += 1
			poder_perdedor += _poder_individual(membro) * float(perdedor.get("moralMultiplicador", 1.0))
			saude_perdedor += float(membro.get("vidaAtual", 1)) / maxf(1.0, float(membro.get("atributos", {}).get("vidaMaxima", 1)))
	for membro in vencedor.get("individuos", []):
		if bool(membro.get("vivo", false)):
			vivos_vencedor += 1
			poder_vencedor += _poder_individual(membro) * float(vencedor.get("moralMultiplicador", 1.0))
			saude_vencedor += float(membro.get("vidaAtual", 1)) / maxf(1.0, float(membro.get("atributos", {}).get("vidaMaxima", 1)))
	if vivos_perdedor <= 0:
		return false
	if vivos_vencedor <= 0:
		return true
	var razao := (poder_perdedor + saude_perdedor * 10.0) / maxf(1.0, poder_vencedor + saude_vencedor * 10.0)
	var coragem := rng.randf_range(0.0, 0.20)
	return SISTEMA_COMPORTAMENTO.grupo_deve_continuar_confronto_razao(razao, float(perdedor.get("moralMultiplicador", 1.0)), coragem)

func _resolver_confronto_coletivo(desafiante_in: Dictionary, defensor_in: Dictionary, agora_unix: int, rng: RandomNumberGenerator) -> Dictionary:
	var desafiante: Dictionary = desafiante_in.duplicate(true)
	var defensor: Dictionary = defensor_in.duplicate(true)
	var registros: Array = []
	var rodada := 0
	while rodada < 30:
		var ataques_a: Array = []
		var ataques_d: Array = []
		for membro in desafiante.get("individuos", []):
			if bool(membro.get("vivo", false)):
				var alvos := _listar_vivos(defensor)
				if not alvos.is_empty():
					alvos.sort_custom(func(a, b): return float(a.get("vidaAtual", 1)) < float(b.get("vidaAtual", 1)))
					ataques_a.append({"atacante":str(membro.get("individuoId", "")),"alvo":str(alvos[0].get("individuoId", "")),"dano":_calcular_dano(membro, alvos[0], desafiante, rng, true)})
		for membro in defensor.get("individuos", []):
			if bool(membro.get("vivo", false)):
				var alvos_d := _listar_vivos(desafiante)
				if not alvos_d.is_empty():
					alvos_d.sort_custom(func(a, b): return float(a.get("vidaAtual", 1)) < float(b.get("vidaAtual", 1)))
					ataques_d.append({"atacante":str(membro.get("individuoId", "")),"alvo":str(alvos_d[0].get("individuoId", "")),"dano":_calcular_dano(membro, alvos_d[0], defensor, rng, false)})
		for ataque in ataques_a:
			_aplicar_dano_local(defensor, str(ataque["alvo"]), int(ataque["dano"]), agora_unix)
		for ataque in ataques_d:
			_aplicar_dano_local(desafiante, str(ataque["alvo"]), int(ataque["dano"]), agora_unix)
		registros.append({"rodada":rodada + 1,"ataquesDesafiante":ataques_a.size(),"ataquesDefensor":ataques_d.size(),"sobreviventesDesafiante":_listar_vivos(desafiante).size(),"sobreviventesDefensor":_listar_vivos(defensor).size()})
		rodada += 1
		if _listar_vivos(desafiante).is_empty() or _listar_vivos(defensor).is_empty():
			break
	var vivos_a := _listar_vivos(desafiante).size()
	var vivos_d := _listar_vivos(defensor).size()
	var vencedor_id := str(desafiante.get("grupoId", "")) if vivos_a > vivos_d else str(defensor.get("grupoId", "")) if vivos_d > vivos_a else ""
	if vencedor_id.is_empty():
		var poder_a := _calcular_forca_territorial(desafiante)
		var poder_d := _calcular_forca_territorial(defensor)
		vencedor_id = str(desafiante.get("grupoId", "")) if poder_a > poder_d else str(defensor.get("grupoId", "")) if poder_d > poder_a else ""
	return {"grupoDesafiante":desafiante,"grupoDefensor":defensor,"vencedorGrupoId":vencedor_id,"turnos":registros}

func _calcular_dano(atacante: Dictionary, alvo: Dictionary, grupo_atacante: Dictionary, rng: RandomNumberGenerator, alvo_defende_territorio: bool = false) -> int:
	var ataque := _atributo_com_equipamento(atacante, "ataque")
	var defesa := _atributo_com_equipamento(alvo, "defesa")
	if alvo_defende_territorio:
		defesa *= 1.15
	var moral := float(grupo_atacante.get("moralMultiplicador", 1.0))
	return maxi(1, roundi(maxf(1.0, ataque * moral * rng.randf_range(0.75, 1.08) - defesa * 0.30)))

func _listar_vivos(grupo: Dictionary) -> Array:
	var vivos: Array = []
	for membro in grupo.get("individuos", []):
		if bool(membro.get("vivo", false)):
			vivos.append(membro.duplicate(true))
	return vivos

## A força considera apenas indivíduos vivos e dá vantagem defensiva a quem já ocupa o território.
func _calcular_forca_territorial(grupo: Dictionary) -> float:
	var total := 0.0
	var lider_id := str(grupo.get("liderAtual", {}).get("individuoId", ""))
	for individuo in grupo.get("individuos", []):
		if not bool(individuo.get("vivo", false)):
			continue
		var atributos: Dictionary = individuo.get("atributos", {})
		var forca := float(atributos.get("ataque", 1)) * 1.5
		forca += float(atributos.get("defesa", 0)) + float(atributos.get("vidaMaxima", 1)) * 0.1
		forca += float(atributos.get("agilidade", 0)) * 0.5 + float(atributos.get("poderMagico", 0))
		if str(individuo.get("individuoId", "")) == lider_id:
			forca *= 1.15
		total += forca
	return total

## Verifica se o recuo do grupo derrotado não invade um terceiro território.
func _territorio_tem_conflito(grupos: Dictionary, ignorar_a: String, ignorar_b: String, ecossistema_id: String, centro: Vector2, raio: float) -> bool:
	for outro_id in grupos:
		var id_texto := str(outro_id)
		if id_texto == ignorar_a or id_texto == ignorar_b:
			continue
		var outro: Dictionary = grupos[outro_id]
		if str(outro.get("ecossistemaId", "")) != ecossistema_id:
			continue
		var territorio: Dictionary = outro.get("territorio", {})
		var dados_centro: Dictionary = territorio.get("centro", {})
		var centro_outro := Vector2(float(dados_centro.get("x", -10000.0)), float(dados_centro.get("y", -10000.0)))
		if centro.distance_to(centro_outro) < raio + float(territorio.get("raio", 0.0)):
			return true
	return false


## Personalidade estável por grupo: mesma semente sempre produz o mesmo temperamento.
func _gerar_personalidade_grupo(grupo_id: String) -> Dictionary:
	return {
		"agressividade":_valor_personalidade(grupo_id, "agressividade"),
		"sociabilidade":_valor_personalidade(grupo_id, "sociabilidade"),
		"territorialidade":_valor_personalidade(grupo_id, "territorialidade"),
		"coragem":_valor_personalidade(grupo_id, "coragem")
	}

func _valor_personalidade(grupo_id: String, atributo: String) -> float:
	var semente: int = absi(hash(grupo_id + "|" + atributo))
	return snappedf(0.70 + float(posmod(semente, 601)) / 1000.0, 0.001)

## Cada indivíduo recebe temperamento próprio, estável e limitado; não substitui a personalidade do grupo.
func _gerar_personalidade_individual(individuo_id: String) -> Dictionary:
	return {
		"prudencia":_valor_personalidade(individuo_id, "prudencia"),
		"protecaoSocial":_valor_personalidade(individuo_id, "protecaoSocial"),
		"agressividade":_valor_personalidade(individuo_id, "agressividade"),
		"coragem":_valor_personalidade(individuo_id, "coragem"),
		"curiosidade":_valor_personalidade(individuo_id, "curiosidade")
	}

## Experiências reais alteram o temperamento aos poucos, sem apagar a personalidade de nascimento.
## O mesmo evento no mesmo instante não pode conceder aprendizado repetido.
func _aplicar_experiencia_temperamento(grupo: Dictionary, tipo: String, referencia: String, horario: int) -> void:
	if not ["ameaca", "cooperacao", "conflito"].has(tipo) or referencia.is_empty() or horario < 0:
		return
	var historico: Array = grupo.get("aprendizadoTemperamental", [])
	for registro in historico:
		if str(registro.get("tipo", "")) == tipo and str(registro.get("referenciaId", "")) == referencia and int(registro.get("horarioUnix", -1)) == horario:
			return
	var alteracoes := {
		"ameaca":{"prudencia":0.018,"protecaoSocial":0.012,"coragem":0.006},
		"cooperacao":{"protecaoSocial":0.018,"curiosidade":0.010,"agressividade":-0.004},
		"conflito":{"agressividade":0.015,"coragem":0.012,"prudencia":0.006}
	}
	var ajustes: Dictionary = alteracoes[tipo]
	var individuos: Array = grupo.get("individuos", [])
	var afetados := 0
	for indice in range(individuos.size()):
		var individuo: Dictionary = individuos[indice].duplicate(true)
		if not bool(individuo.get("vivo", true)):
			continue
		var individuo_id := str(individuo.get("individuoId", ""))
		if individuo_id.is_empty():
			continue
		var temperamento: Dictionary = individuo.get("personalidadeIndividual", _gerar_personalidade_individual(individuo_id)).duplicate(true)
		for atributo in ajustes.keys():
			var atual := clampf(float(temperamento.get(atributo, 1.0)), 0.70, 1.30)
			var variacao := float(ajustes[atributo])
			var modulacao := 0.85 + float(posmod(absi(hash(individuo_id + "|" + tipo + "|" + referencia)), 31)) / 100.0
			temperamento[atributo] = snappedf(clampf(atual + variacao * modulacao, 0.70, 1.30), 0.001)
		individuo["personalidadeIndividual"] = temperamento
		individuo["ultimaExperienciaTemperamental"] = {"tipo":tipo,"referenciaId":referencia,"horarioUnix":horario}
		individuos[indice] = individuo
		afetados += 1
	grupo["individuos"] = individuos
	if afetados > 0:
		historico.append({"tipo":tipo,"referenciaId":referencia,"horarioUnix":horario,"individuosAfetados":afetados})
		grupo["aprendizadoTemperamental"] = historico.slice(maxi(0, historico.size() - 30))

## Retorna a força de uma tradição ainda praticada; costumes abandonados perdem influência.
## Cria uma identidade cultural determinística por espécie e ecossistema, sem depender de serviços externos.
func _inicializar_cultura_especie(grupo: Dictionary, criatura: Dictionary, horario: int) -> void:
	var cultura: Dictionary = grupo.get("culturaGrupo", {"tradicoes":[],"contagemExperiencias":{},"geracao":1}).duplicate(true)
	if not cultura.get("perfilEspecie", {}).is_empty():
		return
	var especie_id := str(criatura.get("id", grupo.get("especieId", "especie")))
	var ecossistema_id := str(grupo.get("ecossistemaId", ""))
	var bioma := str(grupo.get("bioma", ""))
	var semente := absi(hash(especie_id + "|" + ecossistema_id + "|" + bioma))
	var sinais := [
		{"som":"chamado_grave","gesto":"cabeca_baixa","rastro":"odor_resina"},
		{"som":"estalido_curto","gesto":"cauda_erguida","rastro":"odor_terroso"},
		{"som":"canto_duplo","gesto":"asas_abertas","rastro":"marcacao_vegetal"},
		{"som":"vibracao_gutural","gesto":"postura_lateral","rastro":"odor_musgoso"}
	]
	var hierarquias := ["lideranca_por_experiencia","lideranca_por_forca","lideranca_compartilhada","lideranca_por_parentesco"]
	var rituais := [
		{"nome":"dança_de_aproximacao","etapas":["aproximacao","exibicao","aceitacao"]},
		{"nome":"oferta_de_alimento","etapas":["oferta","avaliacao","aceitacao"]},
		{"nome":"canto_de_pareamento","etapas":["chamado","resposta","sincronizacao"]},
		{"nome":"exibicao_de_territorio","etapas":["marcacao","demonstracao","aceitacao"]}
	]
	var costumes_por_bioma := {
		"floresta_arcana":["marcacao_de_trilhas","vigilia_ao_crepusculo","abrigo_compartilhado"],
		"montanhas_gelidas":["revezamento_de_calor","rotas_de_abrigo","chamados_de_nevasca"],
		"deserto_ancestral":["economia_de_agua","travessia_noturna","sombra_compartilhada"],
		"mar_eternal":["rotas_de_mare","sinais_de_superficie","descanso_em_correnteza"]
	}
	var costumes: Array = costumes_por_bioma.get(ecossistema_id, costumes_por_bioma.get(bioma, ["marcacao_de_territorio","reuniao_sazonal","cuidado_coletivo"]))
	cultura["perfilEspecie"] = {
		"especieId":especie_id,
		"ecossistemaId":ecossistema_id,
		"linguagemSinais":sinais[posmod(semente, sinais.size())].duplicate(true),
		"hierarquia":hierarquias[posmod(semente >> 3, hierarquias.size())],
		"costumesEcossistema":costumes.duplicate(true),
		"criadoUnix":horario
	}
	cultura["ritualAcasalamento"] = rituais[posmod(semente >> 6, rituais.size())].duplicate(true)
	cultura["disputasLideranca"] = cultura.get("disputasLideranca", [])
	cultura["membrosReconhecidos"] = cultura.get("membrosReconhecidos", [])
	grupo["culturaGrupo"] = cultura

## Mede afinidade de pareamento sem obrigar indivíduos a escolher parceiros incompatíveis.
## A compatibilidade considera preferências rituais, tradições herdadas e vínculos sociais reais.
func avaliar_compatibilidade_cultural(individuo_a: Dictionary, individuo_b: Dictionary, cultura: Dictionary) -> Dictionary:
	if str(individuo_a.get("individuoId", "")).is_empty() or str(individuo_b.get("individuoId", "")).is_empty() or str(individuo_a.get("individuoId", "")) == str(individuo_b.get("individuoId", "")):
		return {"compativel":false,"pontuacao":0.0,"motivo":"individuos_invalidos"}
	if not bool(individuo_a.get("vivo", true)) or not bool(individuo_b.get("vivo", true)) or str(individuo_a.get("faseVida", "adulto")) != "adulto" or str(individuo_b.get("faseVida", "adulto")) != "adulto":
		return {"compativel":false,"pontuacao":0.0,"motivo":"nao_sao_adultos_vivos"}
	var ritual_a := str(individuo_a.get("ritualPreferido", cultura.get("ritualAcasalamento", {}).get("nome", "")))
	var ritual_b := str(individuo_b.get("ritualPreferido", cultura.get("ritualAcasalamento", {}).get("nome", "")))
	var pontuacao := 0.35 if not ritual_a.is_empty() and ritual_a == ritual_b else 0.12
	var tradicoes_a: Array = individuo_a.get("tradicoesCulturaisHerdadas", [])
	var tradicoes_b: Array = individuo_b.get("tradicoesCulturaisHerdadas", [])
	var tradicoes_compartilhadas := 0
	for tradicao_a in tradicoes_a:
		for tradicao_b in tradicoes_b:
			if str(tradicao_a.get("id", "")) == str(tradicao_b.get("id", "")) and not str(tradicao_a.get("id", "")).is_empty():
				tradicoes_compartilhadas += 1
	pontuacao += minf(0.25, float(tradicoes_compartilhadas) * 0.05)
	var vinculo := _obter_vinculo_individual(individuo_a, str(individuo_b.get("individuoId", "")), str(individuo_b.get("grupoId", individuo_a.get("grupoId", ""))))
	pontuacao += clampf(float(vinculo.get("amizade", 0.0)) * 0.20 + float(vinculo.get("confianca", 0.0)) * 0.20 - float(vinculo.get("rivalidade", 0.0)) * 0.30, -0.30, 0.40)
	pontuacao = clampf(pontuacao, 0.0, 1.0)
	return {"compativel":pontuacao >= 0.15,"pontuacao":pontuacao,"ritualCompartilhado":ritual_a == ritual_b and not ritual_a.is_empty(),"tradicoesCompartilhadas":tradicoes_compartilhadas,"ritualA":ritual_a,"ritualB":ritual_b}

func _obter_vinculo_individual(individuo: Dictionary, outro_id: String, outro_grupo_id: String) -> Dictionary:
	for vinculo in individuo.get("vinculosIndividuais", []):
		if str(vinculo.get("individuoId", "")) == outro_id and str(vinculo.get("grupoId", outro_grupo_id)) == outro_grupo_id:
			return vinculo
	return {}

## Escolhe o par adulto com maior afinidade cultural e social; cada par só gera um filhote por ciclo.
func _selecionar_par_acasalamento_cultural(grupo: Dictionary, horario: int, usados: Dictionary) -> Dictionary:
	var individuos: Array = grupo.get("individuos", [])
	var cultura: Dictionary = grupo.get("culturaGrupo", {})
	var melhor: Dictionary = {}
	var maior_pontuacao := -1.0
	for i in range(individuos.size()):
		var a: Dictionary = individuos[i]
		if not bool(a.get("vivo", true)) or str(a.get("faseVida", "adulto")) != "adulto":
			continue
		for j in range(i + 1, individuos.size()):
			var b: Dictionary = individuos[j]
			if not bool(b.get("vivo", true)) or str(b.get("faseVida", "adulto")) != "adulto":
				continue
			var id_a := str(a.get("individuoId", ""))
			var id_b := str(b.get("individuoId", ""))
			var chave := id_a + "|" + id_b
			if usados.has(chave):
				continue
			var avaliacao := avaliar_compatibilidade_cultural(a, b, cultura)
			var pontuacao := float(avaliacao.get("pontuacao", 0.0))
			if bool(avaliacao.get("compativel", false)) and pontuacao > maior_pontuacao:
				maior_pontuacao = pontuacao
				melhor = {"progenitorAId":id_a,"progenitorBId":id_b,"ritual":str(avaliacao.get("ritualA", "")) if bool(avaliacao.get("ritualCompartilhado", false)) else str(cultura.get("ritualAcasalamento", {}).get("nome", "")),"pontuacao":pontuacao,"chave":chave,"horarioUnix":horario}
	return melhor

func _registrar_pareamento_cultural(grupo: Dictionary, par: Dictionary, horario: int) -> void:
	var cultura: Dictionary = grupo.get("culturaGrupo", {}).duplicate(true)
	var historico: Array = cultura.get("historicoPareamentos", [])
	historico.append(par.duplicate(true))
	cultura["historicoPareamentos"] = historico.slice(maxi(0, historico.size() - 40))
	var contagens: Dictionary = cultura.get("contagemRituaisAcasalamento", {}).duplicate(true)
	var ritual := str(par.get("ritual", ""))
	if not ritual.is_empty():
		contagens[ritual] = int(contagens.get(ritual, 0)) + 1
		if int(contagens[ritual]) >= 3:
			var tradicoes: Array = cultura.get("tradicoes", [])
			var encontrada := false
			for tradicao in tradicoes:
				if str(tradicao.get("id", "")) == "ritual_" + ritual:
					tradicao["forca"] = mini(5, int(tradicao.get("forca", 1)) + 1)
					tradicao["ultimaPraticaUnix"] = horario
					encontrada = true
					break
			if not encontrada:
				tradicoes.append({"id":"ritual_" + ritual,"forca":1,"criadaUnix":horario,"ultimaPraticaUnix":horario})
			cultura["tradicoes"] = tradicoes.slice(maxi(0, tradicoes.size() - 12))
	cultura["contagemRituaisAcasalamento"] = contagens
	grupo["culturaGrupo"] = cultura

## Conflitos entre grupos deixam memória política dos líderes envolvidos; não inventa vencedor sem resultado de combate.
func _registrar_confronto_liderancas_culturais(a: Dictionary, b: Dictionary, horario: int) -> void:
	for grupo in [a, b]:
		var cultura: Dictionary = grupo.get("culturaGrupo", {}).duplicate(true)
		var disputas: Array = cultura.get("disputasLideranca", [])
		var outro_id := str(b.get("grupoId", "")) if str(grupo.get("grupoId", "")) == str(a.get("grupoId", "")) else str(a.get("grupoId", ""))
		var lider_proprio := str(grupo.get("liderAtual", {}).get("individuoId", ""))
		var lider_outro := str(b.get("liderAtual", {}).get("individuoId", "")) if str(grupo.get("grupoId", "")) == str(a.get("grupoId", "")) else str(a.get("liderAtual", {}).get("individuoId", ""))
		disputas.append({"tipo":"conflito_entre_lideres","grupoRivalId":outro_id,"liderProprioId":lider_proprio,"liderRivalId":lider_outro,"hierarquia":str(cultura.get("perfilEspecie", {}).get("hierarquia", "lideranca_por_experiencia")),"horarioUnix":horario,"resultado":"conflito_registrado_sem_vencedor"})
		cultura["disputasLideranca"] = disputas.slice(maxi(0, disputas.size() - 20))
		grupo["culturaGrupo"] = cultura

## Converte confiança acumulada em alianças culturais e conflitos repetidos em rivalidades herdáveis.
func _atualizar_diplomacia_cultural(a: Dictionary, b: Dictionary, tipo: String, horario: int) -> void:
	var id_a := str(a.get("grupoId", ""))
	var id_b := str(b.get("grupoId", ""))
	var relacao_a: Dictionary = a.get("relacoesGrupos", {}).get(id_b, {})
	var relacao_b: Dictionary = b.get("relacoesGrupos", {}).get(id_a, {})
	for grupo in [a, b]:
		var outro_id := id_b if str(grupo.get("grupoId", "")) == id_a else id_a
		var relacao: Dictionary = relacao_a if str(grupo.get("grupoId", "")) == id_a else relacao_b
		var cultura: Dictionary = grupo.get("culturaGrupo", {}).duplicate(true)
		var aliancas: Array = cultura.get("aliancas", [])
		var rivalidades: Array = cultura.get("rivalidadesHereditarias", [])
		if tipo == "cooperacao" and float(relacao.get("confianca", 0.0)) >= 0.5 and int(relacao.get("interacoes", 0)) >= 2:
			var encontrou_alianca := false
			for alianca in aliancas:
				if str(alianca.get("grupoParceiroId", "")) == outro_id:
					alianca["ultimaRenovacaoUnix"] = horario
					alianca["confianca"] = float(relacao.get("confianca", 0.0))
					encontrou_alianca = true
					break
			if not encontrou_alianca:
				aliancas.append({"grupoParceiroId":outro_id,"criadaUnix":horario,"ultimaRenovacaoUnix":horario,"confianca":float(relacao.get("confianca", 0.0)),"estado":"alianca_cultural"})
		elif tipo == "conflito" and float(relacao.get("rivalidade", 0.0)) >= 0.5:
			var encontrou_rival := false
			for rivalidade in rivalidades:
				if str(rivalidade.get("grupoRivalId", "")) == outro_id:
					rivalidade["intensidade"] = float(relacao.get("rivalidade", 0.0))
					rivalidade["ultimaOcorrenciaUnix"] = horario
					rivalidade["geracoes"] = maxi(1, int(rivalidade.get("geracoes", 1)))
					encontrou_rival = true
					break
			if not encontrou_rival:
				rivalidades.append({"grupoRivalId":outro_id,"especieRivalId":str(b.get("especieId", "")) if str(grupo.get("grupoId", "")) == id_a else str(a.get("especieId", "")),"intensidade":float(relacao.get("rivalidade", 0.0)),"criadaUnix":horario,"ultimaOcorrenciaUnix":horario,"geracoes":1})
		for rivalidade in rivalidades:
			if str(rivalidade.get("grupoRivalId", "")) == outro_id and tipo == "cooperacao" and float(relacao.get("rivalidade", 0.0)) < 0.2:
				rivalidade["estado"] = "reconciliada"
		cultura["aliancas"] = aliancas.slice(maxi(0, aliancas.size() - 30))
		cultura["rivalidadesHereditarias"] = rivalidades.slice(maxi(0, rivalidades.size() - 30))
		grupo["culturaGrupo"] = cultura

## Forma uma comunidade quando pelo menos três grupos mantêm uma rede conectada de alianças.
func _atualizar_comunidades_culturais(grupos: Dictionary, horario: int) -> void:
	for grupo_id in grupos.keys():
		var grupo: Dictionary = grupos[grupo_id]
		var cultura: Dictionary = grupo.get("culturaGrupo", {}).duplicate(true)
		cultura["comunidadeCultural"] = {}
		grupo["culturaGrupo"] = cultura
		grupos[grupo_id] = grupo
	var visitados := {}
	for origem_id in grupos.keys():
		if visitados.has(str(origem_id)):
			continue
		var componente: Array = []
		var fila: Array = [str(origem_id)]
		visitados[str(origem_id)] = true
		while not fila.is_empty():
			var atual_id := str(fila.pop_front())
			if not grupos.has(atual_id):
				continue
			componente.append(atual_id)
			var atual: Dictionary = grupos[atual_id]
			for parceiro_id in atual.get("relacoesGrupos", {}).keys():
				var relacao: Dictionary = atual.get("relacoesGrupos", {}).get(parceiro_id, {})
				if str(relacao.get("estado", "")) != "aliado" or visitados.has(str(parceiro_id)) or not grupos.has(str(parceiro_id)):
					continue
				if str(grupos[str(parceiro_id)].get("ecossistemaId", "")) != str(atual.get("ecossistemaId", "")):
					continue
				visitados[str(parceiro_id)] = true
				fila.append(str(parceiro_id))
		if componente.size() < 3:
			continue
		componente.sort()
		var chave_comunidade := ""
		for membro_id in componente:
			chave_comunidade += str(membro_id) + "|"
		var comunidade_id := "comunidade_cultural_" + str(absi(hash(chave_comunidade)))
		var tradicoes_comuns: Array = []
		for tradicao in grupos[componente[0]].get("culturaGrupo", {}).get("tradicoes", []):
			var presente_em_todos := true
			for membro_id in componente.slice(1):
				var possui := false
				for tradicao_membro in grupos[membro_id].get("culturaGrupo", {}).get("tradicoes", []):
					if str(tradicao_membro.get("id", "")) == str(tradicao.get("id", "")):
						possui = true
						break
				if not possui:
					presente_em_todos = false
					break
			if presente_em_todos:
				tradicoes_comuns.append(str(tradicao.get("id", "")))
		for membro_id in componente:
			var membro: Dictionary = grupos[membro_id]
			var cultura_membro: Dictionary = membro.get("culturaGrupo", {}).duplicate(true)
			cultura_membro["comunidadeCultural"] = {"id":comunidade_id,"membrosGrupoIds":componente.duplicate(),"tradicoesCompartilhadas":tradicoes_comuns,"fundadaUnix":horario}
			cultura_membro["geracao"] = int(cultura_membro.get("geracao", 1)) + 1
			membro["culturaGrupo"] = cultura_membro
			grupos[membro_id] = membro

## Une indivíduos adultos de espécies explicitamente declaradas como reprodutivamente compatíveis.
## Não infere compatibilidade pela aparência, nome ou proximidade ecológica.
func registrar_uniao_intergrupos(grupo_a_id: String, individuo_a_id: String, grupo_b_id: String, individuo_b_id: String, horario: int = -1) -> Dictionary:
	if grupo_a_id == grupo_b_id or grupo_a_id.is_empty() or grupo_b_id.is_empty():
		return {"ok":false,"erro":"União precisa envolver dois grupos distintos."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_a_id) or not grupos.has(grupo_b_id):
		return {"ok":false,"erro":"Um dos grupos não existe."}
	var a: Dictionary = grupos[grupo_a_id].duplicate(true)
	var b: Dictionary = grupos[grupo_b_id].duplicate(true)
	if str(a.get("ecossistemaId", "")) != str(b.get("ecossistemaId", "")):
		return {"ok":false,"erro":"União intergrupos exige ecossistema compartilhado."}
	var especie_a: Dictionary = repositorio_criaturas.obter_criatura(str(a.get("especieId", "")))
	var especie_b: Dictionary = repositorio_criaturas.obter_criatura(str(b.get("especieId", "")))
	var ecologia_a: Dictionary = especie_a.get("ecologia", {})
	var ecologia_b: Dictionary = especie_b.get("ecologia", {})
	var grupo_reprodutivo_a := str(ecologia_a.get("grupoReprodutivoId", ""))
	var grupo_reprodutivo_b := str(ecologia_b.get("grupoReprodutivoId", ""))
	if grupo_reprodutivo_a.is_empty() or grupo_reprodutivo_a != grupo_reprodutivo_b:
		return {"ok":false,"erro":"As espécies não declararam compatibilidade reprodutiva entre si."}
	if ecologia_a.get("especiesPresas", []).has(str(b.get("especieId", ""))) or ecologia_a.get("especiesPredadoras", []).has(str(b.get("especieId", ""))) or ecologia_b.get("especiesPresas", []).has(str(a.get("especieId", ""))) or ecologia_b.get("especiesPredadoras", []).has(str(a.get("especieId", ""))):
		return {"ok":false,"erro":"Relação predador-presa impede união reprodutiva."}
	var membro_a: Dictionary = _buscar_adulto_vivo(a, individuo_a_id)
	var membro_b: Dictionary = _buscar_adulto_vivo(b, individuo_b_id)
	if membro_a.is_empty() or membro_b.is_empty():
		return {"ok":false,"erro":"Os dois indivíduos precisam estar vivos e adultos."}
	var afinidade := avaliar_compatibilidade_cultural(membro_a, membro_b, a.get("culturaGrupo", {}))
	if float(afinidade.get("pontuacao", 0.0)) < 0.10:
		return {"ok":false,"erro":"A afinidade cultural ainda é insuficiente para a união."}
	var relacao_ab: Dictionary = a.get("relacoesGrupos", {}).get(grupo_b_id, {})
	var relacao_ba: Dictionary = b.get("relacoesGrupos", {}).get(grupo_a_id, {})
	if maxf(float(relacao_ab.get("rivalidade", 0.0)), float(relacao_ba.get("rivalidade", 0.0))) >= 0.75:
		return {"ok":false,"erro":"Rivalidade intensa impede a união neste momento."}
	var instante := horario if horario >= 0 else int(Time.get_unix_time_from_system())
	var uniao_id := "uniao_" + str(absi(hash(grupo_a_id + "|" + individuo_a_id + "|" + grupo_b_id + "|" + individuo_b_id)))
	var registro := {"id":uniao_id,"grupoParceiroId":grupo_b_id,"individuoParceiroId":individuo_b_id,"grupoReprodutivoId":grupo_reprodutivo_a,"ritual":"ritual_de_convergencia" if not bool(afinidade.get("ritualCompartilhado", false)) else str(afinidade.get("ritualA", "")),"afinidadeCultural":float(afinidade.get("pontuacao", 0.0)),"iniciadaUnix":instante,"estado":"uniao_reconhecida"}
	var cultura_a: Dictionary = a.get("culturaGrupo", {}).duplicate(true)
	var cultura_b: Dictionary = b.get("culturaGrupo", {}).duplicate(true)
	var unioes_a: Array = cultura_a.get("unioesIntergrupos", [])
	var unioes_b: Array = cultura_b.get("unioesIntergrupos", [])
	for existente in unioes_a:
		if str(existente.get("id", "")) == uniao_id:
			return {"ok":false,"erro":"Esta união já foi registrada."}
	unioes_a.append(registro)
	var registro_inverso := registro.duplicate(true)
	registro_inverso["grupoParceiroId"] = grupo_a_id
	registro_inverso["individuoParceiroId"] = individuo_a_id
	unioes_b.append(registro_inverso)
	cultura_a["unioesIntergrupos"] = unioes_a.slice(maxi(0, unioes_a.size() - 40))
	cultura_b["unioesIntergrupos"] = unioes_b.slice(maxi(0, unioes_b.size() - 40))
	a["culturaGrupo"] = cultura_a
	b["culturaGrupo"] = cultura_b
	grupos[grupo_a_id] = a
	grupos[grupo_b_id] = b
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir a união intergrupos."}
	return {"ok":true,"uniao":registro.duplicate(true)}

## Gera um descendente híbrido a partir de uma união já registrada e de dois progenitores vivos.
## O híbrido permanece como indivíduo da população hospedeira, com linhagem explícita; não cria uma espécie global falsa.
func gerar_filhote_hibrido(uniao_id: String, grupo_a_id: String, individuo_a_id: String, grupo_b_id: String, individuo_b_id: String, agora_unix: int = -1) -> Dictionary:
	if uniao_id.is_empty() or grupo_a_id.is_empty() or grupo_b_id.is_empty() or grupo_a_id == grupo_b_id:
		return {"ok":false,"erro":"Identificação da união ou dos grupos inválida."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_a_id) or not grupos.has(grupo_b_id):
		return {"ok":false,"erro":"Um dos grupos progenitores não existe."}
	var grupo_a: Dictionary = grupos[grupo_a_id].duplicate(true)
	var grupo_b: Dictionary = grupos[grupo_b_id].duplicate(true)
	var registro_uniao: Dictionary = {}
	for registro in grupo_a.get("culturaGrupo", {}).get("unioesIntergrupos", []):
		if str(registro.get("id", "")) == uniao_id and str(registro.get("grupoParceiroId", "")) == grupo_b_id and str(registro.get("individuoParceiroId", "")) == individuo_b_id:
			registro_uniao = registro
			break
	if registro_uniao.is_empty():
		return {"ok":false,"erro":"Não existe união reconhecida entre estes progenitores."}
	var registro_inverso_encontrado := false
	for registro in grupo_b.get("culturaGrupo", {}).get("unioesIntergrupos", []):
		if str(registro.get("id", "")) == uniao_id and str(registro.get("grupoParceiroId", "")) == grupo_a_id and str(registro.get("individuoParceiroId", "")) == individuo_a_id:
			registro_inverso_encontrado = true
			break
	if not registro_inverso_encontrado:
		return {"ok":false,"erro":"A união não está confirmada nos dois grupos."}
	var progenitor_a := _buscar_adulto_vivo(grupo_a, individuo_a_id)
	var progenitor_b := _buscar_adulto_vivo(grupo_b, individuo_b_id)
	if progenitor_a.is_empty() or progenitor_b.is_empty():
		return {"ok":false,"erro":"Os dois progenitores precisam continuar vivos e adultos."}
	var especie_a: Dictionary = repositorio_criaturas.obter_criatura(str(grupo_a.get("especieId", "")))
	var especie_b: Dictionary = repositorio_criaturas.obter_criatura(str(grupo_b.get("especieId", "")))
	var ecologia_a: Dictionary = especie_a.get("ecologia", {})
	var ecologia_b: Dictionary = especie_b.get("ecologia", {})
	var grupo_reprodutivo := str(registro_uniao.get("grupoReprodutivoId", ""))
	if grupo_reprodutivo.is_empty() or grupo_reprodutivo != str(ecologia_a.get("grupoReprodutivoId", "")) or grupo_reprodutivo != str(ecologia_b.get("grupoReprodutivoId", "")):
		return {"ok":false,"erro":"Compatibilidade genética não está mais declarada pelas duas espécies."}
	var estado_populacao: Dictionary = grupo_a.get("populacaoEstado", {}).duplicate(true)
	var quantidade := int(estado_populacao.get("quantidade", -1))
	var capacidade := int(estado_populacao.get("maxima", 0))
	if quantidade < 0 or capacidade <= 0 or quantidade >= capacidade:
		return {"ok":false,"erro":"O território hospedeiro atingiu sua capacidade populacional."}
	var instante := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(uniao_id + ":hibrido:" + str(instante))
	var filhote := _criar_individuo(grupo_a, especie_a, rng, true)
	var atributos_a: Dictionary = progenitor_a.get("atributos", {})
	var atributos_b: Dictionary = progenitor_b.get("atributos", {})
	var atributos_hibridos := {}
	for campo in CAMPOS_ATRIBUTOS:
		var valor_a := int(atributos_a.get(campo, especie_a.get(campo, 1)))
		var valor_b := int(atributos_b.get(campo, especie_b.get(campo, 1)))
		var media := int(round((float(valor_a) + float(valor_b)) / 2.0))
		var variacao := rng.randi_range(-1, 1) if rng.randf() < 0.08 else 0
		atributos_hibridos[campo] = maxi(1, media + variacao)
	filhote["atributos"] = atributos_hibridos
	filhote["vidaAtual"] = int(atributos_hibridos.get("vidaMaxima", 1))
	filhote["identidadeBiologica"] = "hibrido"
	var especies_linhagem: Array = [str(especie_a.get("id", "")), str(especie_b.get("id", ""))]
	especies_linhagem.sort()
	var chave_linhagem := str(especies_linhagem[0]) + "|" + str(especies_linhagem[1])
	filhote["linhagemHibrida"] = especies_linhagem
	filhote["linhagemHibridaId"] = "linhagem_hibrida_" + str(hash(chave_linhagem))
	filhote["geracaoHibrida"] = maxi(int(progenitor_a.get("geracaoHibrida", 0)), int(progenitor_b.get("geracaoHibrida", 0))) + 1
	var habilidades_potenciais: Array = []
	for especie_origem in [especie_a, especie_b]:
		var lista_habilidades: Array = especie_origem.get("habilidades", [])
		for habilidade_origem in lista_habilidades:
			if habilidades_potenciais.size() >= 4:
				break
			var habilidade_dados: Dictionary = habilidade_origem.duplicate(true)
			habilidades_potenciais.append({"id":str(especie_origem.get("id", "")) + "::" + str(habilidade_dados.get("id", "")),"origemEspecieId":str(especie_origem.get("id", "")),"habilidade":habilidade_dados})
	filhote["habilidadesHibridasPotenciais"] = habilidades
	filhote["assinaturaFenotipica"] = _gerar_assinatura_fenotipica(atributos, ancestralidade, habilidades)_potenciais
	filhote["habilidadesHibridasDesbloqueadas"] = []
	filhote["ancestralidade"] = {str(especie_a.get("id", "")):0.5,str(especie_b.get("id", "")):0.5}
	filhote["especieId"] = str(especie_a.get("id", ""))
	filhote["perfilGenetico"] = _combinar_perfil_genetico(progenitor_a, progenitor_b, atributos_hibridos, filhote["ancestralidade"], rng)
	filhote["assinaturaFenotipica"] = _gerar_assinatura_fenotipica(atributos_hibridos, filhote["ancestralidade"], habilidades_potenciais)
	filhote["progenitores"] = {"progenitorAId":individuo_a_id,"grupoAId":grupo_a_id,"especieAId":str(especie_a.get("id", "")),"progenitorBId":individuo_b_id,"grupoBId":grupo_b_id,"especieBId":str(especie_b.get("id", "")),"uniaoId":uniao_id}
	filhote["ritualNascimento"] = str(registro_uniao.get("ritual", "ritual_de_convergencia"))
	var tradicoes_hibridas: Array = []
	for origem in [grupo_a, grupo_b]:
		for tradicao in origem.get("culturaGrupo", {}).get("tradicoes", []):
			var tradicao_id := str(tradicao.get("id", ""))
			var ja_herdada := false
			for tradicao_existente in tradicoes_hibridas:
				if str(tradicao_existente.get("id", "")) == tradicao_id:
					ja_herdada = true
					break
			if not tradicao_id.is_empty() and not ja_herdada:
				tradicoes_hibridas.append(tradicao.duplicate(true))
	filhote["tradicoesCulturaisHerdadas"] = tradicoes_hibridas
	filhote["perfisCulturaisHerdados"] = [grupo_a.get("culturaGrupo", {}).get("perfilEspecie", {}).duplicate(true),grupo_b.get("culturaGrupo", {}).get("perfilEspecie", {}).duplicate(true)]
	filhote["rivalidadesHerdadas"] = grupo_a.get("culturaGrupo", {}).get("rivalidadesHereditarias", []).duplicate(true) + grupo_b.get("culturaGrupo", {}).get("rivalidadesHereditarias", []).duplicate(true)
	filhote["nascimentoUnix"] = instante
	filhote["faseVida"] = "filhote"
	var individuos: Array = grupo_a.get("individuos", [])
	individuos.append(filhote)
	grupo_a["individuos"] = individuos
	estado_populacao["quantidade"] = quantidade + 1
	estado_populacao["totalNascimentos"] = int(estado_populacao.get("totalNascimentos", 0)) + 1
	estado_populacao["ocupacaoCapacidade"] = SISTEMA_POPULACAO.calcular_ocupacao(quantidade + 1, capacidade)
	grupo_a["populacaoEstado"] = estado_populacao
	grupo_a["atualizadoUnix"] = instante
	var cultura_a: Dictionary = grupo_a.get("culturaGrupo", {}).duplicate(true)
	var nascimentos_a: Array = cultura_a.get("nascimentosHibridos", [])
	nascimentos_a.append({"individuoId":str(filhote.get("individuoId", "")),"uniaoId":uniao_id,"grupoParceiroId":grupo_b_id,"horarioUnix":instante})
	cultura_a["nascimentosHibridos"] = nascimentos_a.slice(maxi(0, nascimentos_a.size() - 40))
	grupo_a["culturaGrupo"] = cultura_a
	var cultura_b: Dictionary = grupo_b.get("culturaGrupo", {}).duplicate(true)
	var nascimentos_b: Array = cultura_b.get("nascimentosHibridos", [])
	nascimentos_b.append({"individuoId":str(filhote.get("individuoId", "")),"uniaoId":uniao_id,"grupoParceiroId":grupo_a_id,"horarioUnix":instante})
	cultura_b["nascimentosHibridos"] = nascimentos_b.slice(maxi(0, nascimentos_b.size() - 40))
	grupo_b["culturaGrupo"] = cultura_b
	grupos[grupo_a_id] = grupo_a
	grupos[grupo_b_id] = grupo_b
	banco["grupos"] = grupos
	_registrar_nascimento_linhagem_hibrida(banco, filhote, instante)
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir o nascimento híbrido."}
	return {"ok":true,"filhote":filhote.duplicate(true),"grupo":grupo_a.duplicate(true)}



## Permite a continuidade reprodutiva de uma linhagem híbrida dentro do mesmo grupo.
func gerar_filhote_linhagem_hibrida(grupo_id: String, progenitor_a_id: String, progenitor_b_id: String, agora_unix: int = -1) -> Dictionary:
	if grupo_id.is_empty() or progenitor_a_id.is_empty() or progenitor_b_id.is_empty() or progenitor_a_id == progenitor_b_id:
		return {"ok":false,"erro":"Identificação dos progenitores inválida."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo da linhagem não encontrado."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var a := _buscar_adulto_vivo(grupo, progenitor_a_id)
	var b := _buscar_adulto_vivo(grupo, progenitor_b_id)
	if a.is_empty() or b.is_empty():
		return {"ok":false,"erro":"Os dois híbridos precisam estar vivos e adultos no mesmo grupo."}
	var linhagem_id := str(a.get("linhagemHibridaId", ""))
	if linhagem_id.is_empty() or linhagem_id != str(b.get("linhagemHibridaId", "")) or str(a.get("identidadeBiologica", "")) != "hibrido" or str(b.get("identidadeBiologica", "")) != "hibrido":
		return {"ok":false,"erro":"Os progenitores precisam pertencer à mesma linhagem híbrida."}
	var pais_a: Dictionary = a.get("progenitores", {})
	var pais_b: Dictionary = b.get("progenitores", {})
	for chave_a in ["progenitorAId", "progenitorBId"]:
		for chave_b in ["progenitorAId", "progenitorBId"]:
			var id_a := str(pais_a.get(chave_a, ""))
			if not id_a.is_empty() and id_a == str(pais_b.get(chave_b, "")):
				return {"ok":false,"erro":"Progenitores aparentados não podem formar este par de reprodução."}
	var estado: Dictionary = grupo.get("populacaoEstado", {}).duplicate(true)
	var quantidade := int(estado.get("quantidade", -1))
	var capacidade := int(estado.get("maxima", 0))
	if quantidade < 0 or capacidade <= 0 or quantidade >= capacidade:
		return {"ok":false,"erro":"O território atingiu sua capacidade populacional."}
	var especie: Dictionary = repositorio_criaturas.obter_criatura(str(grupo.get("especieId", "")))
	if especie.is_empty():
		return {"ok":false,"erro":"Espécie-base da linhagem indisponível."}
	var instante := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(linhagem_id + ":" + progenitor_a_id + ":" + progenitor_b_id + ":" + str(instante))
	var filhote := _criar_individuo(grupo, especie, rng, true)
	var atributos_a: Dictionary = a.get("atributos", {})
	var atributos_b: Dictionary = b.get("atributos", {})
	var atributos := {}
	for campo in CAMPOS_ATRIBUTOS:
		var media := int(round((float(atributos_a.get(campo, especie.get(campo, 1))) + float(atributos_b.get(campo, especie.get(campo, 1)))) / 2.0))
		var variacao := rng.randi_range(-1, 1) if rng.randf() < 0.08 else 0
		atributos[campo] = maxi(1, media + variacao)
	filhote["atributos"] = atributos
	filhote["vidaAtual"] = int(atributos.get("vidaMaxima", 1))
	filhote["identidadeBiologica"] = "hibrido"
	filhote["linhagemHibrida"] = a.get("linhagemHibrida", []).duplicate(true)
	filhote["linhagemHibridaId"] = linhagem_id
	filhote["geracaoHibrida"] = maxi(int(a.get("geracaoHibrida", 1)), int(b.get("geracaoHibrida", 1))) + 1
	filhote["especieId"] = str(grupo.get("especieId", ""))
	var ancestralidade_a: Dictionary = a.get("ancestralidade", {})
	var ancestralidade_b: Dictionary = b.get("ancestralidade", {})
	var ancestralidade := {}
	for origem in ancestralidade_a.keys():
		ancestralidade[str(origem)] = float(ancestralidade_a[origem]) * 0.5
	for origem in ancestralidade_b.keys():
		ancestralidade[str(origem)] = float(ancestralidade.get(str(origem), 0.0)) + float(ancestralidade_b[origem]) * 0.5
	var soma_ancestralidade := 0.0
	for valor in ancestralidade.values():
		soma_ancestralidade += float(valor)
	if soma_ancestralidade > 0.0:
		for origem in ancestralidade.keys():
			ancestralidade[origem] = float(ancestralidade[origem]) / soma_ancestralidade
	filhote["ancestralidade"] = ancestralidade
	filhote["perfilGenetico"] = _combinar_perfil_genetico(a, b, atributos, ancestralidade, rng)
	var habilidades: Array = []
	for progenitor in [a, b]:
		for habilidade in progenitor.get("habilidadesHibridasPotenciais", []):
			var habilidade_id := str(habilidade.get("id", ""))
			var repetida := false
			for existente in habilidades:
				if str(existente.get("id", "")) == habilidade_id:
					repetida = true
					break
			if not habilidade_id.is_empty() and not repetida and habilidades.size() < 4:
				habilidades.append(habilidade.duplicate(true))
	filhote["habilidadesHibridasPotenciais"] = habilidades
	filhote["habilidadesHibridasDesbloqueadas"] = []
	filhote["perfilGenetico"] = _combinar_perfil_genetico(a, b, atributos, ancestralidade, rng)
	filhote["assinaturaFenotipica"] = _gerar_assinatura_fenotipica(atributos, ancestralidade, habilidades)
	filhote["progenitores"] = {"progenitorAId":progenitor_a_id,"grupoAId":grupo_id,"progenitorBId":progenitor_b_id,"grupoBId":grupo_id,"geracaoProgenitores":maxi(int(a.get("geracaoHibrida", 1)), int(b.get("geracaoHibrida", 1)))}
	filhote["ritualNascimento"] = str(grupo.get("culturaGrupo", {}).get("ritualAcasalamento", {}).get("nome", "ritual_de_convergencia"))
	filhote["nascimentoUnix"] = instante
	filhote["faseVida"] = "filhote"
	var individuos: Array = grupo.get("individuos", [])
	individuos.append(filhote)
	grupo["individuos"] = individuos
	estado["quantidade"] = quantidade + 1
	estado["totalNascimentos"] = int(estado.get("totalNascimentos", 0)) + 1
	estado["ocupacaoCapacidade"] = SISTEMA_POPULACAO.calcular_ocupacao(quantidade + 1, capacidade)
	grupo["populacaoEstado"] = estado
	grupo["atualizadoUnix"] = instante
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	_registrar_nascimento_linhagem_hibrida(banco, filhote, instante)
	_registrar_reproducao_linhagem_hibrida(banco, linhagem_id, a, b, instante)
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir o descendente da linhagem híbrida."}
	var promocao := _promover_linhagem_hibrida(linhagem_id, filhote, instante) if bool(banco.get("linhagensHibridas", {}).get(linhagem_id, {}).get("especieEmergente", false)) else {"ok":false,"aguardandoEstabilidade":true}
	return {"ok":true,"filhote":filhote.duplicate(true),"grupo":grupo.duplicate(true),"promocaoEspecie":promocao}


## Mantém um registro persistente por ancestralidade; uma linhagem só é estável após três gerações observadas.
func _registrar_nascimento_linhagem_hibrida(banco: Dictionary, individuo: Dictionary, horario: int) -> void:
	var linhagem_id := str(individuo.get("linhagemHibridaId", ""))
	var geracao := int(individuo.get("geracaoHibrida", 0))
	if linhagem_id.is_empty() or geracao < 1:
		return
	var linhagens: Dictionary = banco.get("linhagensHibridas", {}).duplicate(true)
	var registro: Dictionary = linhagens.get(linhagem_id, {
		"id":linhagem_id,
		"ancestralidade":individuo.get("linhagemHibrida", []).duplicate(true),
		"nascimentosObservados":0,
		"geracoesObservadas":[],
		"geracoesReprodutoras":[],
		"paresReprodutivos":[],
		"perfisFenotipicosPorGeracao":{},
		"individuosRegistrados":[],
		"estado":"em_observacao",
		"especieEmergente":false,
		"criadaUnix":horario
	}).duplicate(true)
	var individuo_id := str(individuo.get("individuoId", ""))
	var ids: Array = registro.get("individuosRegistrados", [])
	if not individuo_id.is_empty() and not ids.has(individuo_id):
		ids.append(individuo_id)
		registro["nascimentosObservados"] = int(registro.get("nascimentosObservados", 0)) + 1
	var geracoes: Array = registro.get("geracoesObservadas", [])
	if not geracoes.has(geracao):
		geracoes.append(geracao)
		geracoes.sort()
	registro["individuosRegistrados"] = ids.slice(maxi(0, ids.size() - 200))
	registro["geracoesObservadas"] = geracoes
	var perfis: Dictionary = registro.get("perfisFenotipicosPorGeracao", {}).duplicate(true)
	var perfis_geracao: Array = perfis.get(str(geracao), [])
	var assinatura := str(individuo.get("assinaturaFenotipica", ""))
	if not assinatura.is_empty() and not perfis_geracao.has(assinatura):
		perfis_geracao.append(assinatura)
	perfis[str(geracao)] = perfis_geracao.slice(maxi(0, perfis_geracao.size() - 30))
	registro["perfisFenotipicosPorGeracao"] = perfis
	registro["ultimaObservacaoUnix"] = horario
	var estavel := _avaliar_estabilidade_linhagem(registro)
	registro["estado"] = "estavel" if estavel else "em_observacao"
	registro["especieEmergente"] = estavel
	registro["criteriosEstabilidade"] = {
		"geracoesObservadas":geracoes.duplicate(true),
		"geracoesQueJaSeReproduziram":registro.get("geracoesReprodutoras", []).duplicate(true),
		"paresReprodutivosDistintos":registro.get("paresReprodutivos", []).size(),
		"nascimentosObservados":int(registro.get("nascimentosObservados", 0))
	}
	linhagens[linhagem_id] = registro
	banco["linhagensHibridas"] = linhagens

## Uma geração só conta como reprodutora quando gera descendente real registrado.
func _registrar_reproducao_linhagem_hibrida(banco: Dictionary, linhagem_id: String, progenitor_a: Dictionary, progenitor_b: Dictionary, horario: int) -> void:
	var linhagens: Dictionary = banco.get("linhagensHibridas", {}).duplicate(true)
	if not linhagens.has(linhagem_id):
		return
	var registro: Dictionary = linhagens[linhagem_id].duplicate(true)
	var geracao_a := int(progenitor_a.get("geracaoHibrida", 0))
	var geracao_b := int(progenitor_b.get("geracaoHibrida", 0))
	if geracao_a < 1 or geracao_b < 1:
		return
	var geracoes: Array = registro.get("geracoesReprodutoras", [])
	for geracao_progenitor in [geracao_a, geracao_b]:
		if not geracoes.has(geracao_progenitor):
			geracoes.append(geracao_progenitor)
	geracoes.sort()
	registro["geracoesReprodutoras"] = geracoes
	var ids := [str(progenitor_a.get("individuoId", "")), str(progenitor_b.get("individuoId", ""))]
	ids.sort()
	var chave_par: String = ids[0] + "|" + ids[1]
	var pares: Array = registro.get("paresReprodutivos", [])
	if not pares.has(chave_par):
		pares.append(chave_par)
	registro["paresReprodutivos"] = pares.slice(maxi(0, pares.size() - 100))
	registro["ultimaReproducaoUnix"] = horario
	registro["estado"] = "estavel" if _avaliar_estabilidade_linhagem(registro) else "em_observacao"
	registro["especieEmergente"] = str(registro["estado"]) == "estavel"
	linhagens[linhagem_id] = registro
	banco["linhagensHibridas"] = linhagens

## Exige F1, F2 e F3 observadas, reprodução real de F1 e F2 e pares independentes.
func _avaliar_estabilidade_linhagem(registro: Dictionary) -> bool:
	var geracoes: Array = registro.get("geracoesObservadas", [])
	var reprodutoras: Array = registro.get("geracoesReprodutoras", [])
	var pares: Array = registro.get("paresReprodutivos", [])
	var ids: Array = registro.get("individuosRegistrados", [])
	return geracoes.has(1) and geracoes.has(2) and geracoes.has(3) and reprodutoras.has(1) and reprodutoras.has(2) and pares.size() >= 2 and ids.size() >= 5

func _combinar_perfil_genetico(a: Dictionary, b: Dictionary, atributos: Dictionary, ancestralidade: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var perfil_a: Dictionary = a.get("perfilGenetico", {})
	var perfil_b: Dictionary = b.get("perfilGenetico", {})
	var marcadores := {}
	for campo in CAMPOS_ATRIBUTOS:
		var valor_a := float(perfil_a.get(campo, a.get("atributos", {}).get(campo, 1)))
		var valor_b := float(perfil_b.get(campo, b.get("atributos", {}).get(campo, 1)))
		var desvio := rng.randf_range(-0.03, 0.03)
		marcadores[campo] = snappedf((valor_a + valor_b) * 0.5 * (1.0 + desvio), 0.01)
	return {"marcadores":marcadores,"ancestralidade":ancestralidade.duplicate(true),"geracao":maxi(int(a.get("geracaoHibrida", 0)), int(b.get("geracaoHibrida", 0))) + 1}

func _gerar_assinatura_fenotipica(atributos: Dictionary, ancestralidade: Dictionary, habilidades: Array) -> String:
	var partes: Array = []
	for campo in CAMPOS_ATRIBUTOS:
		partes.append(str(campo) + ":" + str(int(atributos.get(campo, 0)) / 5))
	var origens: Array = ancestralidade.keys()
	origens.sort()
	for origem in origens:
		partes.append(str(origem) + ":" + str(snappedf(float(ancestralidade[origem]), 0.05)))
	var ids_habilidades: Array = []
	for habilidade in habilidades:
		var id_habilidade := str(habilidade.get("id", ""))
		if not id_habilidade.is_empty():
			ids_habilidades.append(id_habilidade)
	ids_habilidades.sort()
	partes.append_array(ids_habilidades)
	return str(hash("|".join(partes)))

## Converte uma linhagem estável em espécie catalogada e tenta fundar sua população.
func _promover_linhagem_hibrida(linhagem_id: String, individuo_referencia: Dictionary, horario: int) -> Dictionary:
	var banco := _ler_banco()
	var linhagens: Dictionary = banco.get("linhagensHibridas", {}).duplicate(true)
	if not linhagens.has(linhagem_id):
		return {"ok":false,"erro":"Registro da linhagem não encontrado."}
	var registro: Dictionary = linhagens[linhagem_id].duplicate(true)
	if not bool(registro.get("especieEmergente", false)):
		return {"ok":false,"erro":"A linhagem ainda está em observação."}
	var especie_id := str(registro.get("especieId", ""))
	var especie: Dictionary = {}
	if especie_id.is_empty():
		var base_id := str(individuo_referencia.get("especieId", ""))
		var resultado: Dictionary = repositorio_criaturas.registrar_especie_emergente(base_id, linhagem_id, individuo_referencia, registro)
		if not bool(resultado.get("ok", false)):
			registro["erroRegistroEspecie"] = str(resultado.get("erro", "Falha ao registrar espécie emergente."))
			linhagens[linhagem_id] = registro
			banco["linhagensHibridas"] = linhagens
			_gravar_banco(banco)
			return resultado
		especie = resultado.get("criatura", {}).duplicate(true)
		especie_id = str(especie.get("id", ""))
		registro["especieId"] = especie_id
		registro["especieRegistradaUnix"] = horario
		registro["estado"] = "especie_independente"
		registro["erroRegistroEspecie"] = ""
		linhagens[linhagem_id] = registro
		banco["linhagensHibridas"] = linhagens
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Espécie criada, mas o vínculo com a linhagem não foi persistido."}
	else:
		especie = repositorio_criaturas.obter_criatura(especie_id)
		if especie.is_empty():
			return {"ok":false,"erro":"A espécie registrada não foi encontrada no catálogo."}
	var grupo_resultado := criar_grupo_para_criatura(especie_id, horario)
	if bool(grupo_resultado.get("ok", false)):
		var banco_atual := _ler_banco()
		var linhagens_atual: Dictionary = banco_atual.get("linhagensHibridas", {}).duplicate(true)
		if linhagens_atual.has(linhagem_id):
			var registro_atual: Dictionary = linhagens_atual[linhagem_id].duplicate(true)
			registro_atual["grupoIndependenteId"] = str(grupo_resultado.get("grupo", {}).get("grupoId", ""))
			registro_atual["populacaoIndependenteCriadaUnix"] = horario
			registro_atual["estado"] = "especie_independente"
			linhagens_atual[linhagem_id] = registro_atual
			banco_atual["linhagensHibridas"] = linhagens_atual
			_gravar_banco(banco_atual)
	elif not bool(grupo_resultado.get("duplicado", false)):
		return {"ok":false,"especieRegistrada":true,"criatura":especie,"erroPopulacao":str(grupo_resultado.get("erro", "Não foi possível fundar a população independente."))}
	return {"ok":true,"criatura":especie,"grupo":grupo_resultado.get("grupo", {})}

## Atualiza crescimento por idade; híbridos desbloqueiam habilidades herdadas gradualmente.
func _atualizar_fase_desenvolvimento_hibrido(individuo: Dictionary, grupo: Dictionary, agora_unix: int) -> void:
	var nascimento := int(individuo.get("nascimentoUnix", agora_unix))
	var maturidade := maxf(86400.0, float(grupo.get("idadeMaturidadeDias", 7.0)) * 86400.0)
	var progresso := clampf(float(agora_unix - nascimento) / maturidade, 0.0, 1.0)
	if str(individuo.get("identidadeBiologica", "")) != "hibrido":
		individuo["faseVida"] = "adulto" if progresso >= 1.0 else "filhote"
		return
	var fase := "adulto" if progresso >= 1.0 else ("subadulto" if progresso >= 0.65 else ("juvenil" if progresso >= 0.25 else "filhote"))
	individuo["faseVida"] = fase
	individuo["progressoDesenvolvimento"] = progresso
	individuo["estagioHibrido"] = fase
	var potenciais: Array = individuo.get("habilidadesHibridasPotenciais", [])
	var quantidade_desbloqueada := 0
	if fase == "juvenil":
		quantidade_desbloqueada = 1
	elif fase == "subadulto":
		quantidade_desbloqueada = 2
	elif fase == "adulto":
		quantidade_desbloqueada = potenciais.size()
	var desbloqueadas: Array = []
	for indice in range(mini(quantidade_desbloqueada, potenciais.size())):
		desbloqueadas.append(potenciais[indice].duplicate(true))
	individuo["habilidadesHibridasDesbloqueadas"] = desbloqueadas

func _buscar_adulto_vivo(grupo: Dictionary, individuo_id: String) -> Dictionary:
	for individuo in grupo.get("individuos", []):
		if str(individuo.get("individuoId", "")) == individuo_id and bool(individuo.get("vivo", false)) and str(individuo.get("faseVida", "")) == "adulto":
			return individuo.duplicate(true)
	return {}

## Registra reconhecimento individual após contato social real; mantém apenas os vínculos mais recentes.
func _registrar_reconhecimento_cultural(individuo: Dictionary, outro: Dictionary, grupo_outro_id: String, horario: int) -> void:
	var outro_id := str(outro.get("individuoId", ""))
	if outro_id.is_empty() or not bool(outro.get("vivo", false)):
		return
	var reconhecidos: Array = individuo.get("membrosReconhecidos", [])
	var encontrado := false
	for registro in reconhecidos:
		if str(registro.get("individuoId", "")) == outro_id and str(registro.get("grupoId", "")) == grupo_outro_id:
			registro["encontros"] = mini(100, int(registro.get("encontros", 0)) + 1)
			registro["ultimoContatoUnix"] = horario
			encontrado = true
			break
	if not encontrado:
		reconhecidos.append({"individuoId":outro_id,"grupoId":grupo_outro_id,"encontros":1,"reconhecidoUnix":horario,"ultimoContatoUnix":horario})
	individuo["membrosReconhecidos"] = reconhecidos.slice(maxi(0, reconhecidos.size() - 30))

func _forca_tradicao_cultural(grupo: Dictionary, tradicao_id: String, agora_unix: int) -> int:
	var cultura: Dictionary = grupo.get("culturaGrupo", {})
	for tradicao in cultura.get("tradicoes", []):
		if str(tradicao.get("id", "")) != tradicao_id:
			continue
		var ultima_pratica := int(tradicao.get("ultimaPraticaUnix", tradicao.get("criadaUnix", 0)))
		if ultima_pratica <= 0 or ultima_pratica > agora_unix or agora_unix - ultima_pratica > 1209600:
			return 0
		return clampi(int(tradicao.get("forca", 1)), 1, 5)
	return 0

## Registra costumes coletivos apenas após experiências reais e repetidas.
func _registrar_experiencia_cultural(grupo: Dictionary, tipo: String, referencia: String, horario: int) -> void:
	if not ["ameaca", "cooperacao", "conflito"].has(tipo) or referencia.is_empty() or horario < 0:
		return
	var cultura: Dictionary = grupo.get("culturaGrupo", {"tradicoes":[],"contagemExperiencias":{},"geracao":1}).duplicate(true)
	var historico: Array = cultura.get("historicoExperiencias", [])
	for evento in historico:
		if str(evento.get("tipo", "")) == tipo and str(evento.get("referenciaId", "")) == referencia and int(evento.get("horarioUnix", -1)) == horario:
			return
	historico.append({"tipo":tipo,"referenciaId":referencia,"horarioUnix":horario})
	while historico.size() > 60:
		historico.pop_front()
	cultura["historicoExperiencias"] = historico
	var contagens: Dictionary = cultura.get("contagemExperiencias", {}).duplicate(true)
	contagens[tipo] = int(contagens.get(tipo, 0)) + 1
	cultura["contagemExperiencias"] = contagens
	var nomes := {"ameaca":"vigilia_coletiva","cooperacao":"caca_cooperativa","conflito":"defesa_territorial"}
	var limites := {"ameaca":3,"cooperacao":3,"conflito":3}
	var tradicoes: Array = cultura.get("tradicoes", [])
	if int(contagens[tipo]) >= int(limites[tipo]):
		var id_tradicao: String = nomes[tipo]
		var encontrada := false
		for tradicao in tradicoes:
			if str(tradicao.get("id", "")) == id_tradicao:
				encontrada = true
				tradicao["forca"] = mini(5, int(tradicao.get("forca", 1)) + 1)
				tradicao["ultimaPraticaUnix"] = horario
				break
		if not encontrada:
			tradicoes.append({"id":id_tradicao,"forca":1,"criadaUnix":horario,"ultimaPraticaUnix":horario})
	cultura["tradicoes"] = tradicoes.slice(maxi(0, tradicoes.size() - 12))
	cultura["geracao"] = maxi(1, int(cultura.get("geracao", 1)))
	grupo["culturaGrupo"] = cultura

## Registra laços recíprocos entre criaturas de grupos que realmente cooperaram ou entraram em conflito.
func _registrar_vinculos_entre_grupos(grupo_a: Dictionary, grupo_b: Dictionary, tipo: String, horario: int) -> void:
	var membros_a: Array = grupo_a.get("individuos", [])
	var membros_b: Array = grupo_b.get("individuos", [])
	var id_grupo_a := str(grupo_a.get("grupoId", ""))
	var id_grupo_b := str(grupo_b.get("grupoId", ""))
	var pares := 0
	for indice_a in range(membros_a.size()):
		var membro_a: Dictionary = membros_a[indice_a].duplicate(true)
		if not bool(membro_a.get("vivo", false)):
			continue
		var pos_a: Dictionary = membro_a.get("posicaoMundo", {})
		var ponto_a := Vector2(float(pos_a.get("x", 0.0)), float(pos_a.get("y", 0.0)))
		var melhor_indice_b := -1
		var menor_distancia := INF
		for indice_b in range(membros_b.size()):
			var membro_b: Dictionary = membros_b[indice_b]
			if not bool(membro_b.get("vivo", false)):
				continue
			var pos_b: Dictionary = membro_b.get("posicaoMundo", {})
			var ponto_b := Vector2(float(pos_b.get("x", 0.0)), float(pos_b.get("y", 0.0)))
			var distancia := ponto_a.distance_squared_to(ponto_b)
			if distancia < menor_distancia:
				menor_distancia = distancia
				melhor_indice_b = indice_b
		if melhor_indice_b < 0:
			continue
		var membro_b: Dictionary = membros_b[melhor_indice_b].duplicate(true)
		_registrar_vinculo_unilateral(membro_a, id_grupo_b, str(membro_b.get("individuoId", "")), tipo, horario)
		_registrar_vinculo_unilateral(membro_b, id_grupo_a, str(membro_a.get("individuoId", "")), tipo, horario)
		_registrar_reconhecimento_cultural(membro_a, membro_b, id_grupo_b, horario)
		_registrar_reconhecimento_cultural(membro_b, membro_a, id_grupo_a, horario)
		membros_a[indice_a] = membro_a
		membros_b[melhor_indice_b] = membro_b
		pares += 1
		if pares >= 30:
			break
	grupo_a["individuos"] = membros_a
	grupo_b["individuos"] = membros_b

## Sobreviver juntos a uma ameaça fortalece confiança entre companheiros próximos.
func _registrar_vinculos_coletivos(grupo: Dictionary, tipo: String, referencia: String, horario: int) -> void:
	if tipo != "ameaca":
		return
	var individuos: Array = grupo.get("individuos", [])
	var pares := 0
	for indice_a in range(individuos.size()):
		var a: Dictionary = individuos[indice_a].duplicate(true)
		if not bool(a.get("vivo", false)):
			continue
		var pos_a: Dictionary = a.get("posicaoMundo", {})
		var ponto_a := Vector2(float(pos_a.get("x", 0.0)), float(pos_a.get("y", 0.0)))
		for indice_b in range(indice_a + 1, individuos.size()):
			var b: Dictionary = individuos[indice_b].duplicate(true)
			if not bool(b.get("vivo", false)):
				continue
			var pos_b: Dictionary = b.get("posicaoMundo", {})
			var ponto_b := Vector2(float(pos_b.get("x", 0.0)), float(pos_b.get("y", 0.0)))
			if ponto_a.distance_to(ponto_b) > 120.0:
				continue
			_registrar_vinculo_unilateral(a, str(grupo.get("grupoId", "")), str(b.get("individuoId", "")), "ameaca", horario)
			_registrar_vinculo_unilateral(b, str(grupo.get("grupoId", "")), str(a.get("individuoId", "")), "ameaca", horario)
			individuos[indice_a] = a
			individuos[indice_b] = b
			pares += 1
			if pares >= 30:
				grupo["individuos"] = individuos
				return
	grupo["individuos"] = individuos

func _registrar_vinculo_unilateral(individuo: Dictionary, grupo_relacionado_id: String, outro_individuo_id: String, tipo: String, horario: int) -> void:
	if outro_individuo_id.is_empty() or str(individuo.get("individuoId", "")) == outro_individuo_id:
		return
	var vinculos: Array = individuo.get("vinculosIndividuais", [])
	var indice := -1
	for i in range(vinculos.size()):
		if str(vinculos[i].get("individuoId", "")) == outro_individuo_id and str(vinculos[i].get("grupoId", "")) == grupo_relacionado_id:
			indice = i
			break
	if indice < 0:
		vinculos.append({"individuoId":outro_individuo_id,"grupoId":grupo_relacionado_id,"amizade":0.0,"confianca":0.0,"rivalidade":0.0,"interacoes":0})
		indice = vinculos.size() - 1
	var vinculo: Dictionary = vinculos[indice].duplicate(true)
	if tipo == "cooperacao":
		vinculo["amizade"] = minf(1.0, float(vinculo.get("amizade", 0.0)) + 0.15)
		vinculo["confianca"] = minf(1.0, float(vinculo.get("confianca", 0.0)) + 0.20)
		vinculo["rivalidade"] = maxf(0.0, float(vinculo.get("rivalidade", 0.0)) - 0.10)
	elif tipo == "conflito":
		vinculo["rivalidade"] = minf(1.0, float(vinculo.get("rivalidade", 0.0)) + 0.25)
		vinculo["confianca"] = maxf(0.0, float(vinculo.get("confianca", 0.0)) - 0.10)
		vinculo["amizade"] = maxf(0.0, float(vinculo.get("amizade", 0.0)) - 0.08)
	else:
		vinculo["confianca"] = minf(1.0, float(vinculo.get("confianca", 0.0)) + 0.12)
	vinculo["estado"] = "rival" if float(vinculo.get("rivalidade", 0.0)) >= 0.35 else "amigo" if float(vinculo.get("amizade", 0.0)) >= 0.30 else "confiavel" if float(vinculo.get("confianca", 0.0)) >= 0.30 else "conhecido"
	vinculo["interacoes"] = int(vinculo.get("interacoes", 0)) + 1
	vinculo["ultimaInteracaoUnix"] = horario
	vinculo["ultimoTipoInteracao"] = tipo
	vinculos[indice] = vinculo
	if vinculos.size() > 20:
		vinculos.sort_custom(func(x, y): return int(x.get("ultimaInteracaoUnix", 0)) > int(y.get("ultimaInteracaoUnix", 0)))
		vinculos = vinculos.slice(0, 20)
	individuo["vinculosIndividuais"] = vinculos
	var melhor: Dictionary = {}
	var melhor_pontuacao := -INF
	for relacao in vinculos:
		var pontuacao := float(relacao.get("amizade", 0.0)) + float(relacao.get("confianca", 0.0)) - float(relacao.get("rivalidade", 0.0))
		if pontuacao > melhor_pontuacao:
			melhor_pontuacao = pontuacao
			melhor = relacao
	if not melhor.is_empty() and melhor_pontuacao > 0.0:
		individuo["companheiroPreferidoId"] = str(melhor.get("individuoId", ""))
		individuo["companheiroPreferidoGrupoId"] = str(melhor.get("grupoId", ""))

## A cooperação real entre grupos oferece apoio aos sobreviventes enlutados.
## Três experiências positivas reduzem gradualmente o luto, sem apagar a memória da perda.
func _aplicar_apoio_emocional(grupo: Dictionary, horario: int, referencia: String) -> void:
	if horario < 0 or referencia.is_empty():
		return
	var individuos: Array = grupo.get("individuos", [])
	for indice in range(individuos.size()):
		var individuo: Dictionary = individuos[indice].duplicate(true)
		if not bool(individuo.get("vivo", false)) or not ["enlutado", "em_recuperacao"].has(str(individuo.get("estadoEmocional", ""))):
			continue
		var apoios := int(individuo.get("apoiosEmocionaisRecebidos", 0))
		if apoios >= 3:
			continue
		apoios += 1
		individuo["apoiosEmocionaisRecebidos"] = apoios
		var intensidade := clampf(float(individuo.get("intensidadeLuto", 1.0)) - 0.34, 0.0, 1.0)
		individuo["intensidadeLuto"] = intensidade
		var personalidade: Dictionary = individuo.get("personalidadeIndividual", {}).duplicate(true)
		personalidade["agressividade"] = snappedf(clampf(float(personalidade.get("agressividade", 1.0)) - 0.015, 0.70, 1.30), 0.001)
		personalidade["coragem"] = snappedf(clampf(float(personalidade.get("coragem", 1.0)) + 0.02, 0.70, 1.30), 0.001)
		individuo["personalidadeIndividual"] = personalidade
		individuo["ultimoApoioEmocional"] = {"referenciaGrupoId":referencia,"horarioUnix":horario,"numero":apoios}
		individuo["estadoEmocional"] = "recuperado" if intensidade <= 0.0 else "em_recuperacao"
		individuos[indice] = individuo
	grupo["individuos"] = individuos

## Registra memória social recíproca. Cooperação explícita pode construir aliança; conflito gera rivalidade.
func registrar_interacao_social(grupo_a_id: String, grupo_b_id: String, tipo: String, agora_unix: int = -1) -> Dictionary:
	if grupo_a_id == grupo_b_id or not ["cooperacao", "conflito"].has(tipo):
		return {"ok":false,"erro":"Interação social inválida."}
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_a_id) or not grupos.has(grupo_b_id):
		return {"ok":false,"erro":"Um dos grupos não existe."}
	var a: Dictionary = grupos[grupo_a_id].duplicate(true)
	var b: Dictionary = grupos[grupo_b_id].duplicate(true)
	if str(a.get("ecossistemaId", "")) != str(b.get("ecossistemaId", "")):
		return {"ok":false,"erro":"Grupos de ecossistemas diferentes não podem registrar interação direta."}
	_atualizar_relacao_social(a, b, tipo, agora_unix)
	var instante_interacao := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	_aplicar_experiencia_temperamento(a, tipo, grupo_b_id, instante_interacao)
	_registrar_experiencia_cultural(a, tipo, grupo_b_id, instante_interacao)
	_registrar_experiencia_cultural(b, tipo, grupo_a_id, instante_interacao)
	_aplicar_experiencia_temperamento(b, tipo, grupo_a_id, instante_interacao)
	_registrar_vinculos_entre_grupos(a, b, tipo, instante_interacao)
	if tipo == "conflito":
		_registrar_confronto_liderancas_culturais(a, b, instante_interacao)
	_atualizar_diplomacia_cultural(a, b, tipo, instante_interacao)
	if tipo == "cooperacao":
		_aplicar_apoio_emocional(a, instante_interacao, grupo_b_id)
		_aplicar_apoio_emocional(b, instante_interacao, grupo_a_id)
	grupos[grupo_a_id] = a
	grupos[grupo_b_id] = b
	_atualizar_comunidades_culturais(grupos, instante_interacao)
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a memória social."}
	return {"ok":true,"grupoA":a.duplicate(true),"grupoB":b.duplicate(true)}

func _registrar_relacao_conflito(a: Dictionary, b: Dictionary, agora_unix: int, vencedor_id: String) -> void:
	_atualizar_relacao_social(a, b, "conflito", agora_unix, vencedor_id)

func _atualizar_relacao_social(a: Dictionary, b: Dictionary, tipo: String, agora_unix: int, vencedor_id: String = "") -> void:
	var id_a := str(a.get("grupoId", ""))
	var id_b := str(b.get("grupoId", ""))
	var horario := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	_atualizar_relacao_unilateral(a, id_b, tipo, horario, vencedor_id)
	_atualizar_relacao_unilateral(b, id_a, tipo, horario, vencedor_id)

func _atualizar_relacao_unilateral(grupo: Dictionary, outro_id: String, tipo: String, horario: int, vencedor_id: String) -> void:
	var relacoes: Dictionary = grupo.get("relacoesGrupos", {}).duplicate(true)
	var relacao: Dictionary = relacoes.get(outro_id, {"confianca":0.0,"rivalidade":0.0,"interacoes":0,"historico":[]})
	if tipo == "cooperacao":
		relacao["confianca"] = minf(1.0, float(relacao.get("confianca", 0.0)) + 0.25)
		relacao["rivalidade"] = maxf(0.0, float(relacao.get("rivalidade", 0.0)) - 0.10)
	else:
		relacao["rivalidade"] = minf(1.0, float(relacao.get("rivalidade", 0.0)) + 0.25)
		relacao["confianca"] = maxf(0.0, float(relacao.get("confianca", 0.0)) - 0.10)
	relacao["estado"] = "aliado" if float(relacao.get("confianca", 0.0)) >= 0.50 else "rival" if float(relacao.get("rivalidade", 0.0)) >= 0.35 else "neutro"
	relacao["interacoes"] = int(relacao.get("interacoes", 0)) + 1
	relacao["ultimaInteracaoUnix"] = horario
	relacao["ultimoTipoInteracao"] = tipo
	if not vencedor_id.is_empty():
		relacao["ultimoVencedorGrupoId"] = vencedor_id
	var historico: Array = relacao.get("historico", [])
	historico.append({"tipo":tipo,"horarioUnix":horario,"vencedorGrupoId":vencedor_id})
	relacao["historico"] = historico.slice(maxi(0, historico.size() - 20))
	relacoes[outro_id] = relacao
	grupo["relacoesGrupos"] = relacoes
	var memoria: Array = grupo.get("historicoSocial", [])
	memoria.append({"grupoRelacionadoId":outro_id,"tipo":tipo,"horarioUnix":horario,"vencedorGrupoId":vencedor_id})
	grupo["historicoSocial"] = memoria.slice(maxi(0, memoria.size() - 50))

## Compartilha um alerta apenas com grupos conhecidos e próximos no mesmo ecossistema.
## O servidor calcula a proximidade; o cliente não escolhe destinatários nem localização.
func transmitir_alerta_perigo(grupo_origem_id: String, grupo_destino_id: String, tipo_perigo: String, agora_unix: int = -1, alcance: float = 350.0) -> Dictionary:
	if grupo_origem_id == grupo_destino_id or tipo_perigo not in ["predador", "incendio", "devastacao", "invasor"]:
		return {"ok":false,"entregue":false,"erro":"Alerta inválido."}
	if not is_finite(alcance) or alcance <= 0.0 or alcance > 1000.0:
		return {"ok":false,"entregue":false,"erro":"Alcance inválido."}
	var instante := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_origem_id) or not grupos.has(grupo_destino_id):
		return {"ok":false,"entregue":false,"erro":"Grupo inexistente."}
	var origem: Dictionary = grupos[grupo_origem_id].duplicate(true)
	var destino: Dictionary = grupos[grupo_destino_id].duplicate(true)
	if str(origem.get("ecossistemaId", "")) != str(destino.get("ecossistemaId", "")):
		return {"ok":true,"entregue":false,"motivo":"ecossistema_diferente"}
	var relacao: Dictionary = origem.get("relacoesGrupos", {}).get(grupo_destino_id, {})
	var relacao_inversa: Dictionary = destino.get("relacoesGrupos", {}).get(grupo_origem_id, {})
	if relacao.is_empty() and relacao_inversa.is_empty():
		return {"ok":true,"entregue":false,"motivo":"grupo_desconhecido"}
	var centro_origem := _centro_grupo_alerta(origem)
	var centro_destino := _centro_grupo_alerta(destino)
	if not bool(centro_origem.get("valido", false)) or not bool(centro_destino.get("valido", false)):
		return {"ok":true,"entregue":false,"motivo":"localizacao_indisponivel"}
	var distancia := Vector2(centro_origem["x"], centro_origem["y"]).distance_to(Vector2(centro_destino["x"], centro_destino["y"]))
	if distancia > alcance:
		return {"ok":true,"entregue":false,"motivo":"fora_do_alcance","distancia":distancia}
	var alertas: Array = destino.get("alertasRecebidos", [])
	for alerta in alertas:
		if str(alerta.get("grupoOrigemId", "")) == grupo_origem_id and str(alerta.get("tipo", "")) == tipo_perigo and instante - int(alerta.get("horarioUnix", 0)) < 60:
			return {"ok":true,"entregue":false,"motivo":"alerta_repetido"}
	alertas = alertas.filter(func(a): return instante - int(a.get("horarioUnix", 0)) <= 600)
	var perfil_origem: Dictionary = origem.get("culturaGrupo", {}).get("perfilEspecie", {})
	var sinal_emitido: Dictionary = perfil_origem.get("linguagemSinais", {}).duplicate(true)
	alertas.append({"grupoOrigemId":grupo_origem_id,"especieOrigemId":str(origem.get("especieId", "")),"tipo":tipo_perigo,"sinalCultural":sinal_emitido,"centro":{"x":centro_origem["x"],"y":centro_origem["y"]},"distancia":snappedf(distancia, 0.1),"horarioUnix":instante,"expiraUnix":instante + 600})
	destino["alertasRecebidos"] = alertas.slice(maxi(0, alertas.size() - 20))
	var memoria: Array = destino.get("memoriaEcologica", [])
	memoria.append({"tipo":"alerta_perigo","grupoOrigemId":grupo_origem_id,"perigo":tipo_perigo,"horarioUnix":instante,"centroConhecido":centro_origem})
	destino["memoriaEcologica"] = memoria.slice(maxi(0, memoria.size() - 50))
	destino["atualizadoUnix"] = instante
	grupos[grupo_destino_id] = destino
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"entregue":false,"erro":"Não foi possível persistir o alerta."}
	return {"ok":true,"entregue":true,"distancia":distancia,"alerta":alertas.back().duplicate(true)}


## Converte um alerta recebido em uma reação tática persistente; cada alerta só é aplicado uma vez.
func processar_alertas_recebidos(grupo_id: String, agora_unix: int = -1) -> Dictionary:
	var instante := agora_unix if agora_unix >= 0 else int(Time.get_unix_time_from_system())
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if not grupos.has(grupo_id):
		return {"ok":false,"erro":"Grupo inexistente."}
	var grupo: Dictionary = grupos[grupo_id].duplicate(true)
	var alertas_originais: Array = grupo.get("alertasRecebidos", [])
	var alertas: Array = alertas_originais.filter(func(a):
		var horario := int(a.get("horarioUnix", -1))
		var expira := int(a.get("expiraUnix", -1))
		return horario >= 0 and horario <= instante and expira >= instante and instante - horario <= 600
	)
	grupo["alertasRecebidos"] = alertas
	if alertas.is_empty():
		if alertas_originais.is_empty():
			return {"ok":true,"reagiu":false,"motivo":"sem_alerta_ativo","grupo":grupo}
		grupos[grupo_id] = grupo
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível atualizar alertas expirados."}
		return {"ok":true,"reagiu":false,"motivo":"alertas_expirados","grupo":grupo}
	alertas.sort_custom(func(a, b): return int(a.get("horarioUnix", 0)) > int(b.get("horarioUnix", 0)))
	var alerta: Dictionary = alertas[0]
	var origem_id := str(alerta.get("grupoOrigemId", ""))
	var tipo := str(alerta.get("tipo", ""))
	var chave := origem_id + "|" + tipo + "|" + str(alerta.get("horarioUnix", 0))
	if str(grupo.get("ultimoAlertaProcessadoId", "")) == chave:
		return {"ok":true,"reagiu":false,"motivo":"ja_processado","grupo":grupo}
	var centro_dados: Dictionary = alerta.get("centro", {})
	var x := float(centro_dados.get("x", -1.0))
	var y := float(centro_dados.get("y", -1.0))
	if not is_finite(x) or not is_finite(y) or x < 0.0 or y < 0.0 or x > 2400.0 or y > 1600.0:
		return {"ok":true,"reagiu":false,"motivo":"localizacao_invalida","grupo":grupo}
	var centro_grupo := _centro_grupo_alerta(grupo)
	if not bool(centro_grupo.get("valido", false)):
		return {"ok":true,"reagiu":false,"motivo":"grupo_sem_posicao","grupo":grupo}
	var territorio: Dictionary = grupo.get("territorio", {})
	var raio := clampf(float(territorio.get("raio", 30.0)), 20.0, 1000.0)
	var ponto_grupo := Vector2(float(centro_grupo["x"]), float(centro_grupo["y"]))
	var ponto_perigo := Vector2(x, y)
	var direcao := (ponto_grupo - ponto_perigo).normalized()
	if direcao.length_squared() < 0.001:
		direcao = Vector2.RIGHT.rotated(float(posmod(absi(hash(grupo_id + chave)), 6283)) / 1000.0)
	var sinal_interpretado := SISTEMA_COMPORTAMENTO.interpretar_sinal_cultural(
		str(alerta.get("especieOrigemId", "")),
		str(grupo.get("especieId", "")),
		alerta.get("sinalCultural", {}),
		tipo
	)
	grupo["ultimoSinalCulturalRecebido"] = {"origemId":origem_id,"interpretacao":sinal_interpretado,"horarioUnix":instante}
	var fugir := tipo in ["predador", "incendio", "devastacao"]
	var destino := ponto_grupo + direcao * minf(raio * 0.60, 90.0) if fugir else ponto_grupo
	var centro_territorio_dados: Dictionary = territorio.get("centro", {})
	var centro_territorio := Vector2(float(centro_territorio_dados.get("x", ponto_grupo.x)), float(centro_territorio_dados.get("y", ponto_grupo.y)))
	var limite := maxf(8.0, raio - 5.0)
	var deslocamento := destino - centro_territorio
	if deslocamento.length() > limite:
		destino = centro_territorio + deslocamento.normalized() * limite
	grupo["formacaoTatica"] = {
		"tipo":"alerta_fuga" if fugir else "alerta_defesa",
		"centroDestino":{"x":destino.x,"y":destino.y},
		"centroAmeaca":{"x":x,"y":y},
		"raio":clampf(raio * 0.35 + float(_forca_tradicao_cultural(grupo, "vigilia_coletiva", instante)) * 1.5 + float(_forca_tradicao_cultural(grupo, "defesa_territorial", instante)) * 2.0, 12.0, 65.0),
		"alertaId":chave,
		"sinalInterpretado":sinal_interpretado,
		"expiraUnix":mini(int(alerta.get("expiraUnix", instante + 600)), instante + 600),
		"concluida":false
	}
	grupo["ultimoAlertaProcessadoId"] = chave
	grupo["estadoAlertaAtual"] = "fugindo_de_perigo" if fugir else "reforcando_defesa"
	grupos[grupo_id] = grupo
	banco["grupos"] = grupos
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir a reação ao alerta."}
	return {"ok":true,"reagiu":true,"acao":"fugir" if fugir else "defender","grupo":grupo}


func _centro_grupo_alerta(grupo: Dictionary) -> Dictionary:
	var soma := Vector2.ZERO
	var quantidade := 0
	for individuo in grupo.get("individuos", []):
		if not bool(individuo.get("vivo", false)):
			continue
		var dados = individuo.get("posicaoMundo", {})
		if not (dados is Dictionary):
			continue
		var x := float(dados.get("x", -1.0))
		var y := float(dados.get("y", -1.0))
		if not is_finite(x) or not is_finite(y) or x < 0.0 or y < 0.0 or x > 2400.0 or y > 1600.0:
			continue
		soma += Vector2(x, y)
		quantidade += 1
	if quantidade == 0:
		return {"valido":false}
	var centro := soma / float(quantidade)
	return {"valido":true,"x":centro.x,"y":centro.y}


func obter_grupo(grupo_id: String) -> Dictionary:
	var banco := _ler_banco()
	return banco.get("grupos", {}).get(grupo_id, {}).duplicate(true)

func listar_grupos_do_ecossistema(ecossistema_id: String) -> Array:
	var resultado: Array = []
	var banco := _ler_banco()
	for grupo in banco.get("grupos", {}).values():
		if str(grupo.get("ecossistemaId", "")) == ecossistema_id:
			resultado.append(grupo.duplicate(true))
	return resultado

func listar_todos_grupos() -> Array:
	var resultado: Array = []
	for grupo in _ler_banco().get("grupos", {}).values():
		resultado.append(grupo.duplicate(true))
	return resultado

## Decompõe carcaças e distribui o alimento entre necrófagos com dieta explicitamente declarada.
func processar_carcacas_ecologicas(agora_unix: int) -> Dictionary:
	var banco := _ler_banco()
	var grupos: Dictionary = banco.get("grupos", {})
	if grupos.is_empty():
		return {"ok":true,"disponibilidadePorEspecie":{},"grupos":[]}
	var especies: Dictionary = {}
	for criatura in repositorio_criaturas.listar_todas_as_criaturas_catalogadas():
		especies[str(criatura.get("id", ""))] = criatura
	var consumidores_por_ecossistema := {}
	for grupo in grupos.values():
		var especie_id := str(grupo.get("especieId", ""))
		var especie: Dictionary = especies.get(especie_id, {})
		var ecologia: Dictionary = especie.get("ecologia", {})
		var dieta: Array = ecologia.get("especiesNecrófagas", [])
		var vivos := 0
		for individuo in grupo.get("individuos", []):
			if bool(individuo.get("vivo", false)):
				vivos += 1
		if vivos <= 0 or dieta.is_empty():
			continue
		var ecossistema := str(grupo.get("ecossistemaId", ""))
		if not consumidores_por_ecossistema.has(ecossistema):
			consumidores_por_ecossistema[ecossistema] = []
		consumidores_por_ecossistema[ecossistema].append({
			"especieId":especie_id,
			"quantidade":vivos,
			"dieta":dieta,
			"consumoDia":maxf(0.0, float(ecologia.get("consumoCarcacaPorIndividuoDia", 0.0)))
		})
	var quantidade_carcacas_por_consumidor := {}
	for grupo in grupos.values():
		var ecossistema := str(grupo.get("ecossistemaId", ""))
		for individuo in grupo.get("individuos", []):
			var carcaca: Dictionary = individuo.get("carcaca", {})
			if carcaca.is_empty() or float(carcaca.get("quantidade", 0.0)) <= 0.0:
				continue
			var especie_presa := str(carcaca.get("especieId", individuo.get("especieId", "")))
			for consumidor in consumidores_por_ecossistema.get(ecossistema, []):
				if consumidor["dieta"].has(especie_presa):
					var chave := ecossistema + "|" + str(consumidor["especieId"])
					quantidade_carcacas_por_consumidor[chave] = int(quantidade_carcacas_por_consumidor.get(chave, 0)) + 1
	var disponibilidade := {}
	var encontrou_carcaca := {}
	for consumidores in consumidores_por_ecossistema.values():
		for consumidor in consumidores:
			disponibilidade[str(consumidor["especieId"])] = 1.0
			encontrou_carcaca[str(consumidor["especieId"])] = false
	var alterou := false
	for grupo_id in grupos.keys():
		var grupo: Dictionary = grupos[grupo_id].duplicate(true)
		var individuos: Array = grupo.get("individuos", [])
		var ecossistema := str(grupo.get("ecossistemaId", ""))
		for indice in range(individuos.size()):
			var individuo: Dictionary = individuos[indice].duplicate(true)
			var carcaca: Dictionary = individuo.get("carcaca", {})
			if carcaca.is_empty() or float(carcaca.get("quantidade", 0.0)) <= 0.0:
				continue
			var ultima := int(carcaca.get("ultimaAtualizacaoUnix", -1))
			if ultima < 0 or agora_unix < ultima:
				return {"ok":false,"erro":"Relógio de decomposição das carcaças retrocedeu."}
			var dias := minf(float(agora_unix - ultima) / 86400.0, 3650.0)
			var quantidade := maxf(0.0, float(carcaca.get("quantidade", 0.0)) - float(carcaca.get("decomposicaoPorDia", 0.0)) * dias)
			var especie_presa := str(carcaca.get("especieId", individuo.get("especieId", "")))
			var consumidores: Array = []
			var demanda_total := 0.0
			for consumidor in consumidores_por_ecossistema.get(ecossistema, []):
				if consumidor["dieta"].has(especie_presa) and float(consumidor["consumoDia"]) > 0.0:
					var chave_consumidor := ecossistema + "|" + str(consumidor["especieId"])
					var total_carcacas := maxi(1, int(quantidade_carcacas_por_consumidor.get(chave_consumidor, 1)))
					var demanda := float(consumidor["quantidade"]) * float(consumidor["consumoDia"]) * dias / float(total_carcacas)
					demanda_total += demanda
					consumidores.append({"especieId":consumidor["especieId"],"demanda":demanda})
			var indice_alimento := 1.0 if demanda_total <= 0.0 else clampf(quantidade / demanda_total, 0.0, 1.0)
			for consumidor in consumidores:
				var id_consumidor := str(consumidor["especieId"])
				if bool(encontrou_carcaca.get(id_consumidor, false)):
					disponibilidade[id_consumidor] = minf(float(disponibilidade.get(id_consumidor, 1.0)), indice_alimento)
				else:
					disponibilidade[id_consumidor] = indice_alimento
					encontrou_carcaca[id_consumidor] = true
			var consumido := minf(quantidade, demanda_total)
			carcaca["quantidade"] = maxf(0.0, quantidade - consumido)
			carcaca["ultimaAtualizacaoUnix"] = agora_unix
			individuo["carcaca"] = carcaca
			individuos[indice] = individuo
			alterou = true
		grupo["individuos"] = individuos
		grupos[grupo_id] = grupo
	for id_consumidor in disponibilidade.keys():
		if not bool(encontrou_carcaca.get(id_consumidor, false)):
			disponibilidade[id_consumidor] = 0.0
	if alterou:
		banco["grupos"] = grupos
		if not _gravar_banco(banco):
			return {"ok":false,"erro":"Não foi possível salvar a decomposição e o consumo das carcaças."}
	var lista: Array = []
	for grupo in grupos.values():
		lista.append(grupo.duplicate(true))
	return {"ok":true,"disponibilidadePorEspecie":disponibilidade,"grupos":lista}

func _criar_carcarca(individuo: Dictionary, criatura: Dictionary, agora_unix: int) -> Dictionary:
	if criatura.is_empty():
		return {}
	var ecologia: Dictionary = criatura.get("ecologia", {})
	var config: Dictionary = ecologia.get("carcaca", {})
	var atributos: Dictionary = individuo.get("atributos", {})
	var vida := maxf(1.0, float(atributos.get("vidaMaxima", criatura.get("vidaMaxima", 1))))
	var unidades := clampf(float(config.get("unidades", vida * 0.5)), 1.0, 1000000.0)
	var decomposicao := clampf(float(config.get("decomposicaoPorDia", unidades * 0.1)), 0.0, unidades)
	var rendimento := SISTEMA_LIDER_NATO.calcular_rendimento_carcaca(unidades, decomposicao, bool(individuo.get("liderNato", false)))
	unidades = float(rendimento["quantidade"])
	decomposicao = float(rendimento["decomposicaoPorDia"])
	var posicao: Dictionary = individuo.get("posicaoMundo", {})
	return {
		"especieId":str(criatura.get("id", "")),
		"quantidade":unidades,
		"quantidadeInicial":unidades,
		"qualidade":str(rendimento["qualidade"]),
		"origemLiderNato":bool(rendimento["origemLiderNato"]),
		"decomposicaoPorDia":decomposicao,
		"criadaUnix":agora_unix,
		"ultimaAtualizacaoUnix":agora_unix,
		"posicaoMundo":posicao.duplicate(true)
	}

func _criar_individuo(grupo: Dictionary, criatura: Dictionary, rng: RandomNumberGenerator, filhote: bool = true) -> Dictionary:
	var territorio: Dictionary = grupo.get("territorio", {})
	var centro: Dictionary = territorio.get("centro", {})
	var raio := float(territorio.get("raio", 1.0))
	var angulo := rng.randf_range(0.0, TAU)
	var distancia := sqrt(rng.randf()) * raio
	var numero := int(grupo.get("proximoNumeroIndividuo", 1))
	grupo["proximoNumeroIndividuo"] = numero + 1
	var atributos := {}
	for campo in CAMPOS_ATRIBUTOS:
		atributos[campo] = int(criatura.get(campo, 0))
	var lider_nato := filhote and SISTEMA_LIDER_NATO.sortear(rng)
	if lider_nato:
		atributos = SISTEMA_LIDER_NATO.aprimorar(atributos)
	var agora_heranca := int(grupo.get("atualizadoUnix", grupo.get("criadoUnix", 0)))
	var aprendizado_herdado := SISTEMA_COMPORTAMENTO.selecionar_aprendizado_herdado(
		grupo.get("memoriaCacada", []), agora_heranca
	) if filhote else []
	var aprendizado_defensivo_herdado := SISTEMA_COMPORTAMENTO.selecionar_aprendizado_defensivo_herdado(
		grupo.get("memoriaEcologica", []), agora_heranca
	) if filhote else []
	var individuo_id := str(grupo.get("grupoId", "grupo")) + "_ind_" + str(numero)
	var rituais_preferidos := ["dança_de_aproximacao", "oferta_de_alimento", "canto_de_pareamento", "exibicao_de_territorio"]
	var semente_ritual := absi(hash(individuo_id + ":ritual:" + str(grupo.get("culturaGrupo", {}).get("perfilEspecie", {}).get("especieId", ""))))
	var ritual_preferido: String = rituais_preferidos[posmod(semente_ritual, rituais_preferidos.size())]
	var personalidade_individual := _gerar_personalidade_individual(individuo_id)
	if filhote:
		personalidade_individual = SISTEMA_COMPORTAMENTO.herdar_tendencias_temperamentais(
			personalidade_individual, grupo.get("individuos", []),
			grupo.get("aprendizadoTemperamental", []), agora_heranca
		)
	return {
		"individuoId":individuo_id,
		"grupoId":str(grupo.get("grupoId", "")),
		"ritualPreferido":ritual_preferido,
		"personalidadeIndividual":personalidade_individual,
		"especieId":str(criatura.get("id", "")),
		"atributos":atributos,
		"liderNato":lider_nato,
		"vidaAtual":int(atributos.get("vidaMaxima", 1)),
		"equipamentoIds":[],
		"vivo":true,
		"posicaoMundo":{
			"x":clampf(float(centro.get("x", 0.0)) + cos(angulo) * distancia, 0.0, 2400.0),
			"y":clampf(float(centro.get("y", 0.0)) + sin(angulo) * distancia, 0.0, 1600.0)
		},
		"nascimentoUnix":int(grupo.get("atualizadoUnix", grupo.get("criadoUnix", 0))) if filhote else int(grupo.get("criadoUnix", 0)) - int(float(grupo.get("idadeMaturidadeDias", 7.0)) * 86400.0),
		"faseVida":"filhote" if filhote else "adulto",
		"aprendizadoHerdado":aprendizado_herdado,
		"aprendizadoDefensivoHerdado":aprendizado_defensivo_herdado,
		"tradicoesCulturaisHerdadas":grupo.get("culturaGrupo", {}).get("tradicoes", []).duplicate(true),
		"rivalidadesHerdadas":grupo.get("culturaGrupo", {}).get("rivalidadesHereditarias", []).duplicate(true),
		"perfilCulturalHerdado":grupo.get("culturaGrupo", {}).get("perfilEspecie", {}).duplicate(true),
		"ritualNascimento":str(grupo.get("culturaGrupo", {}).get("ritualAcasalamento", {}).get("nome", "")) if filhote else "",
		"geracaoCultural":int(grupo.get("culturaGrupo", {}).get("geracao", 1)) + (1 if filhote else 0)
	}

func _equipamentos_lider_validos(valor: Variant) -> Array:
	if not (valor is Array):
		return []
	var resultado: Array = []
	var catalogo := SISTEMA_EQUIPAMENTOS.CATALOGO
	for item_id in valor:
		var id := str(item_id)
		if catalogo.has(id) and not resultado.has(id):
			resultado.append(id)
		if resultado.size() >= 6:
			break
	return resultado

func _territorio_valido(territorio: Variant) -> bool:
	if not (territorio is Dictionary):
		return false
	var centro = territorio.get("centro", {})
	if not (centro is Dictionary):
		return false
	var x := float(centro.get("x", -1.0))
	var y := float(centro.get("y", -1.0))
	var raio := float(territorio.get("raio", 0.0))
	return x >= 0.0 and x <= 2400.0 and y >= 0.0 and y <= 1600.0 and raio > 0.0 and raio <= 1000.0

func _ler_banco() -> Dictionary:
	if not FileAccess.file_exists(caminho_arquivo):
		return {"versao":1,"versaoCoordenadas":SISTEMA_MIGRACAO.VERSAO_COORDENADAS,"grupos":{}}
	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.READ)
	if arquivo == null or arquivo.get_length() > LIMITE_ARQUIVO:
		return {}
	var texto := arquivo.get_as_text()
	arquivo.close()
	var dados = JSON.parse_string(texto)
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1 or not (dados.get("grupos", {}) is Dictionary):
		return {}
	return _migrar_coordenadas_banco(dados)

func _migrar_coordenadas_banco(banco: Dictionary) -> Dictionary:
	if int(banco.get("versaoCoordenadas", 0)) >= SISTEMA_MIGRACAO.VERSAO_COORDENADAS:
		return banco
	var grupos: Dictionary = banco.get("grupos", {})
	for grupo_id in grupos.keys():
		if not (grupos[grupo_id] is Dictionary):
			return {}
		var migrado := SISTEMA_MIGRACAO.migrar_grupo_legado(grupos[grupo_id])
		if migrado.is_empty():
			return {}
		grupos[grupo_id] = migrado
	banco["grupos"] = grupos
	banco["versaoCoordenadas"] = SISTEMA_MIGRACAO.VERSAO_COORDENADAS
	if not _gravar_banco(banco):
		push_error("Migração de coordenadas dos grupos não foi persistida; grupos bloqueados.")
		return {}
	return banco

func _gravar_banco(banco: Dictionary) -> bool:
	var diretorio := caminho_arquivo.get_base_dir()
	var caminho_absoluto := ProjectSettings.globalize_path(diretorio)
	if DirAccess.make_dir_recursive_absolute(caminho_absoluto) != OK:
		return false
	var temporario := caminho_arquivo + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(banco))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporario))
		return false
	if FileAccess.file_exists(caminho_arquivo):
		var backup := caminho_arquivo + ".bak"
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho_arquivo), ProjectSettings.globalize_path(backup)) != OK:
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporario), ProjectSettings.globalize_path(caminho_arquivo)) != OK:
		return false
	return true
