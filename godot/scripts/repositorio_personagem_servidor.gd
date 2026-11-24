extends RefCounted
## Armazenamento local do processo dedicado. Nunca é carregado pelo cliente.
## Adequado para desenvolvimento em um único servidor com disco persistente.

const CAMINHO := "user://dados/personagens_online.json"
const CAMINHO_BACKUP := "user://dados/personagens_online.json.bak"
const LIMITE_ARQUIVO := 16 * 1024 * 1024
const CATALOGO = preload("res://scripts/catalogo_criacao_personagem.gd")
const SistemaDrops = preload("res://scripts/sistema_drops.gd")
const SistemaEquipamentos = preload("res://scripts/sistema_equipamentos.gd")
const SistemaMigracao = preload("res://scripts/sistema_migracao_coordenadas.gd")
const SistemaHabilidadeInicial = preload("res://scripts/sistema_habilidade_inicial.gd")
const SistemaInvocacoes = preload("res://scripts/sistema_invocacoes.gd")
const SistemaMoedas = preload("res://scripts/sistema_moedas.gd")

func carregar_ou_criar(uid: String) -> Dictionary:
	if not _uid_valido(uid):
		return {}
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(CAMINHO):
		push_error("Banco local de personagens inválido; entrada bloqueada para evitar sobrescrita.")
		return {}
	var registros: Dictionary = banco.get("personagens", {})
	if registros.has(uid):
		var existente = registros[uid]
		if not (existente is Dictionary) or str(existente.get("uid", "")) != uid:
			return {}
		return existente.duplicate(true)

	var novo := {
		"uid": uid,
		"personagemId": uid,
		"nome": "",
		"personagemCriado": false,
		"nivel": 1,
		"experiencia": 0,
		"vida": 100,
		"vidaMaxima": 100,
		"mana": 50,
		"manaMaxima": 50,
		"forca": 5,
		"inteligencia": 5,
		"agilidade": 5,
		"vitalidade": 5,
		"espirito": 5,
		"pontoMundoId": "clareira_inicial",
		"x": 1190.0,
		"y": 1520.0,
		"aparenciaId": "",
		"inventario": [],
		"moedas": SistemaMoedas.criar_saldo_vazio(),
		"missoes": {},
		"missoesConcluidas": {},
		"encontrosRecompensados": [],
		"equipamentos": {"mao_principal":"","mao_secundaria":"","cabeca":"","torso":"","pernas":"","maos":"","pes":"","costas":"","anel":"","colar":"","bracelete":"","cinto":""},
		"sexo": "", "racaId": "", "classeId": "", "afinidadesFisicas": [], "afinidadesMagicas": [], "anatomiaRacial": {},
		"revisaoServidor": 1
	}
	registros[uid] = novo
	banco["personagens"] = registros
	if not _gravar_banco(banco):
		return {}
	return novo.duplicate(true)

## Atualiza somente o estado de missões do personagem, sempre partindo da revisão mais recente.
## Deve ser chamado exclusivamente pela lógica do servidor após validar os eventos do mundo.
func salvar_missoes(uid: String, missoes: Dictionary) -> Dictionary:
	if not _uid_valido(uid) or not _missoes_validas(missoes):
		return {"ok": false, "erro": "Estado de missões inválido."}
	var perfil: Dictionary = carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok": false, "erro": "Personagem não encontrado."}
	perfil["missoes"] = missoes.duplicate(true)
	if not salvar(uid, perfil):
		return {"ok": false, "erro": "Não foi possível persistir as missões."}
	return {"ok": true, "perfil": perfil.duplicate(true)}

func _missoes_validas(missoes: Dictionary) -> bool:
	if missoes.size() > 200:
		return false
	const status_permitidos := ["em_andamento", "objetivos_concluidos", "recompensada", "recusada", "abandonada"]
	const dificuldades_permitidas := ["facil", "fácil", "media", "média", "dificil", "difícil", "extrema"]
	const campos_permitidos := ["status", "dificuldade", "progresso", "iniciadaEmUnix", "npcId", "titulo", "abandonadaEmUnix", "recompensadaEmUnix"]
	for missao_id in missoes:
		if str(missao_id).strip_edges().is_empty() or str(missao_id).length() > 128 or not (missoes[missao_id] is Dictionary):
			return false
		var registro: Dictionary = missoes[missao_id]
		for campo in registro:
			if not campos_permitidos.has(str(campo)):
				return false
		var status := str(registro.get("status", ""))
		if not status_permitidos.has(status):
			return false
		if registro.has("npcId") and (str(registro["npcId"]).strip_edges().is_empty() or str(registro["npcId"]).length() > 128):
			return false
		if registro.has("titulo") and (str(registro["titulo"]).strip_edges().is_empty() or str(registro["titulo"]).length() > 120):
			return false
		if status in ["em_andamento", "objetivos_concluidos", "recompensada", "abandonada"]:
			var dificuldade := str(registro.get("dificuldade", "")).strip_edges().to_lower()
			if not dificuldades_permitidas.has(dificuldade):
				return false
			var progresso = registro.get("progresso", {})
			if not (progresso is Dictionary) or progresso.is_empty() or progresso.size() > 20:
				return false
			for objetivo_id in progresso:
				if str(objetivo_id).strip_edges().is_empty() or str(objetivo_id).length() > 128:
					return false
				if typeof(progresso[objetivo_id]) != TYPE_INT or int(progresso[objetivo_id]) < 0 or int(progresso[objetivo_id]) > 100000:
					return false
			if int(registro.get("iniciadaEmUnix", 0)) <= 0:
				return false
		if status == "abandonada" and int(registro.get("abandonadaEmUnix", 0)) <= 0:
			return false
		if status == "recompensada" and int(registro.get("recompensadaEmUnix", 0)) <= 0:
			return false
	return true

func criar_personagem(uid: String, nome: String, sexo: String, aparencia_id: String, raca_id: String, classe_id: String) -> Dictionary:
	var nome_limpo := nome.strip_edges()
	if not _uid_valido(uid) or nome_limpo.length() < 3 or nome_limpo.length() > 20:
		return {}
	var escolhas := CATALOGO.montar_perfil(sexo, aparencia_id, raca_id, classe_id)
	if escolhas.is_empty():
		return {}
	var perfil: Dictionary = carregar_ou_criar(uid)
	if perfil.is_empty() or bool(perfil.get("personagemCriado", false)):
		return {}
	perfil["nome"] = nome_limpo
	perfil["personagemCriado"] = true
	for chave in escolhas:
		perfil[chave] = escolhas[chave]
	# Gera uma habilidade inicial no servidor, uma única vez, conforme raça e classe.
	if not bool(perfil.get("habilidadesIniciaisGeradas", false)):
		var habilidade_inicial: Dictionary = SistemaHabilidadeInicial.gerar(escolhas, uid)
		if habilidade_inicial.is_empty():
			return {}
		perfil["habilidades"] = [habilidade_inicial]
		perfil["habilidadeInicialId"] = str(habilidade_inicial.get("id", ""))
		perfil["habilidadesIniciaisGeradas"] = true
		if classe_id == "invocador":
			var invocacao_inicial := SistemaInvocacoes.gerar_inicial(uid)
			if invocacao_inicial.is_empty():
				return {}
			perfil["invocacoes"] = [invocacao_inicial]
			perfil["invocacaoInicialId"] = str(invocacao_inicial.get("id", ""))
			perfil["invocacaoAtivaId"] = str(invocacao_inicial.get("id", ""))
			perfil["invocacaoInicialGerada"] = true
			habilidade_inicial["invocacaoId"] = str(invocacao_inicial.get("id", ""))
			habilidade_inicial["custoMana"] = 5
			perfil["habilidades"] = [habilidade_inicial]
	if not salvar(uid, perfil):
		return {}
	return perfil.duplicate(true)
func salvar(uid: String, snapshot: Dictionary) -> bool:
	if not _uid_valido(uid) or str(snapshot.get("uid", "")) != uid:
		return false
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(CAMINHO):
		return false
	var registros: Dictionary = banco.get("personagens", {})
	var atual: Dictionary = registros.get(uid, {})
	if atual.is_empty():
		return false

	# Impede que um snapshot antigo sobrescreva uma versão mais nova.
	var revisao_atual := int(atual.get("revisaoServidor", 0))
	if int(snapshot.get("revisaoServidor", -1)) != revisao_atual:
		push_warning("Gravação recusada: revisão de personagem desatualizada.")
		return false
	# Somente campos conhecidos são persistidos; a revisão é controlada aqui.
	var revisao := revisao_atual + 1
	var salvo := atual.duplicate(true)
	for chave in ["nome", "personagemCriado", "sexo", "racaId", "racaNome", "classeId", "classeNome", "descricaoRaca", "descricaoClasse", "afinidadesFisicas", "afinidadesMagicas", "anatomiaRacial", "nivel", "experiencia", "vida", "vidaMaxima", "mana", "manaMaxima", "forca", "inteligencia", "agilidade", "vitalidade", "espirito", "pontoMundoId", "x", "y", "aparenciaId", "inventario", "moedas", "missoes", "missoesConcluidas", "equipamentos", "habilidades", "habilidadeInicialId", "habilidadesIniciaisGeradas", "invocacoes", "invocacaoInicialId", "invocacaoAtivaId", "invocacaoInicialGerada", "tentativasDomesticacao", "encontrosRecompensados"]:
		if snapshot.has(chave):
			salvo[chave] = snapshot[chave]
	salvo["uid"] = uid
	salvo["revisaoServidor"] = revisao
	if not _snapshot_valido(salvo):
		return false
	registros[uid] = salvo
	banco["personagens"] = registros
	if not _gravar_banco(banco):
		return false
	snapshot["revisaoServidor"] = revisao
	return true


 
## Cada jogador possui três tentativas para cada indivíduo selvagem.
func registrar_tentativa_domesticacao(uid: String, individuo_id: String) -> Dictionary:
	if not _uid_valido(uid) or individuo_id.strip_edges().is_empty():
		return {"ok":false,"erro":"Identificação inválida da criatura."}
	var perfil: Dictionary = carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	var tentativas: Dictionary = perfil.get("tentativasDomesticacao", {})
	var usadas := int(tentativas.get(individuo_id, 0))
	if usadas >= SistemaInvocacoes.MAX_TENTATIVAS_DOMESTICACAO:
		return {"ok":false,"erro":"Você já usou as 3 tentativas para essa criatura."}
	usadas += 1
	tentativas[individuo_id] = usadas
	perfil["tentativasDomesticacao"] = tentativas
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível registrar a tentativa."}
	return {"ok":true,"usadas":usadas,"restantes":SistemaInvocacoes.MAX_TENTATIVAS_DOMESTICACAO-usadas,"perfil":perfil.duplicate(true)}

## Domesticação e progressão são operações do servidor; o cliente não escolhe atributos nem chance.
func registrar_domesticacao(uid: String, criatura_catalogada: Dictionary) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Jogador inválido."}
	var perfil: Dictionary = carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	var resultado: Dictionary = SistemaInvocacoes.domesticar(perfil, criatura_catalogada)
	if not bool(resultado.get("ok", false)):
		return resultado
	var colecao: Array = perfil.get("invocacoes", [])
	colecao.append(resultado["invocacao"])
	perfil["invocacoes"] = colecao
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar a criatura domesticada."}
	resultado["perfil"] = perfil.duplicate(true)
	return resultado

func selecionar_invocacao(uid: String, invocacao_id: String) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Jogador inválido."}
	var perfil: Dictionary = carregar_ou_criar(uid)
	if perfil.is_empty():
		return {"ok":false,"erro":"Personagem não encontrado."}
	if not SistemaInvocacoes.selecionar(perfil, invocacao_id):
		return {"ok":false,"erro":"Essa invocação não pertence à sua coleção."}
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar a seleção."}
	return {"ok":true,"invocacaoAtivaId":invocacao_id}

func alimentar_invocacao(uid: String, invocacao_id: String, monstro_derrotado: Dictionary) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Jogador inválido."}
	var perfil: Dictionary = carregar_ou_criar(uid)
	if perfil.is_empty():
		return {"ok":false,"erro":"Personagem não encontrado."}
	var colecao: Array = perfil.get("invocacoes", [])
	for indice in range(colecao.size()):
		if str(colecao[indice].get("id", "")) != invocacao_id:
			continue
		var resultado: Dictionary = SistemaInvocacoes.alimentar(colecao[indice], monstro_derrotado)
		if not bool(resultado.get("ok", false)):
			return resultado
		colecao[indice] = resultado["invocacao"]
		perfil["invocacoes"] = colecao
		if not salvar(uid, perfil):
			return {"ok":false,"erro":"Não foi possível salvar a evolução da invocação."}
		resultado["perfil"] = perfil.duplicate(true)
		return resultado
	return {"ok":false,"erro":"Invocação não encontrada na coleção."}

## Consome um ovo e cria o companheiro em uma única gravação do perfil.
func chocar_ovo(uid: String, item_id: String) -> Dictionary:
	if not _uid_valido(uid) or item_id.strip_edges().is_empty():
		return {"ok":false,"erro":"Identificação do ovo inválida."}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	if str(perfil.get("classeId", "")) == "invocador":
		return {"ok":false,"erro":"Invocadores devem domesticar criaturas; ovos são para as demais classes."}
	var inventario: Array = perfil.get("inventario", [])
	var indice_ovo := -1
	for i in range(inventario.size()):
		var item: Dictionary = inventario[i]
		if str(item.get("itemId", "")) == item_id and str(item.get("categoria", "")).to_lower() == "ovo" and int(item.get("quantidade", 0)) > 0:
			indice_ovo = i
			break
	if indice_ovo < 0:
		return {"ok":false,"erro":"Você não possui esse ovo."}
	var ovo: Dictionary = inventario[indice_ovo]
	var resultado := SistemaInvocacoes.chocar_ovo(perfil, ovo)
	if not bool(resultado.get("ok", false)):
		return resultado
	var colecao: Array = perfil.get("invocacoes", [])
	colecao.append(resultado["invocacao"])
	perfil["invocacoes"] = colecao
	var quantidade := int(ovo.get("quantidade", 0)) - 1
	if quantidade <= 0:
		inventario.remove_at(indice_ovo)
	else:
		inventario[indice_ovo]["quantidade"] = quantidade
	perfil["inventario"] = inventario
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar a eclosão do ovo."}
	resultado["perfil"] = perfil.duplicate(true)
	return resultado

## Saldo de moedas e conversão são operações exclusivas do servidor.
func conceder_moedas(uid: String, denominacao: String, quantidade: int) -> Dictionary:
	if not _uid_valido(uid) or not SistemaMoedas.DENOMINACOES.has(denominacao):
		return {"ok":false,"erro":"Moeda ou conta inválida."}
	if quantidade <= 0 or quantidade > SistemaMoedas.LIMITE_SALDO:
		return {"ok":false,"erro":"Quantidade de moedas inválida."}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	var saldo := SistemaMoedas.normalizar(perfil.get("moedas", {}))
	var novo_saldo := int(saldo.get(denominacao, 0)) + quantidade
	if novo_saldo > SistemaMoedas.LIMITE_SALDO:
		return {"ok":false,"erro":"O limite dessa moeda seria ultrapassado."}
	saldo[denominacao] = novo_saldo
	perfil["moedas"] = saldo
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar as moedas."}
	return {"ok":true,"moedas":saldo.duplicate(true),"quantidadeRecebida":quantidade,"denominacao":denominacao}

func converter_moedas(uid: String, denominacao_origem: String, quantidade: int) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Conta inválida."}
	if quantidade < 100 or quantidade % 100 != 0:
		return {"ok":false,"erro":"A conversão exige múltiplos de 100 moedas."}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	var resultado := SistemaMoedas.converter(perfil.get("moedas", {}), denominacao_origem, quantidade)
	if not bool(resultado.get("ok", false)):
		return resultado
	perfil["moedas"] = resultado["moedas"]
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar a conversão."}
	resultado["perfil"] = perfil.duplicate(true)
	return resultado


## Conclui e paga uma missão uma única vez por personagem.
## A dificuldade e o valor são processados no servidor; o cliente não escolhe a quantia.
func concluir_missao(uid: String, missao_id: String, dificuldade: String) -> Dictionary:
	var id := missao_id.strip_edges()
	if not _uid_valido(uid) or id.is_empty() or id.length() > 128:
		return {"ok":false,"erro":"Identificação de missão inválida."}
	var chave_dificuldade := dificuldade.strip_edges().to_lower()
	var entrada := SistemaDrops.criar_entrada_moeda_missao(chave_dificuldade)
	if entrada.is_empty():
		return {"ok":false,"erro":"Dificuldade de missão inválida."}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	var concluidas: Dictionary = perfil.get("missoesConcluidas", {}).duplicate(true)
	if concluidas.has(id):
		return {"ok":false,"duplicada":true,"erro":"Esta missão já foi recompensada."}
	var missoes: Dictionary = perfil.get("missoes", {}).duplicate(true)
	if not missoes.has(id) or not (missoes[id] is Dictionary):
		return {"ok":false,"erro":"A missão não está registrada no personagem."}
	var registro_missao: Dictionary = missoes[id].duplicate(true)
	if str(registro_missao.get("status", "")) != "objetivos_concluidos":
		return {"ok":false,"erro":"Os objetivos da missão ainda não foram concluídos pelo servidor."}
	if str(registro_missao.get("dificuldade", "")).strip_edges().to_lower() != chave_dificuldade:
		return {"ok":false,"erro":"A dificuldade não corresponde à definição aceita pelo servidor."}
	if concluidas.size() >= 10000:
		return {"ok":false,"erro":"Limite de histórico de missões atingido."}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var quantidade := rng.randi_range(int(entrada["quantidadeMinima"]), int(entrada["quantidadeMaxima"]))
	var saldo := SistemaMoedas.normalizar(perfil.get("moedas", {}))
	var novo_total := int(saldo.get("bronze", 0)) + quantidade
	if novo_total > SistemaMoedas.LIMITE_SALDO:
		return {"ok":false,"erro":"Saldo máximo de Bronzhar atingido."}
	saldo["bronze"] = novo_total
	var recibo := {
		"missaoId":id,
		"dificuldade":chave_dificuldade,
		"concluidaEmUnix":int(Time.get_unix_time_from_system()),
		"recompensas":[
			{
				"denominacao":"bronze",
				"nome":SistemaMoedas.nome_com_simbolo("bronze"),
				"quantidade":quantidade
			}
		]
	}
	concluidas[id] = recibo
	registro_missao["status"] = "recompensada"
	registro_missao["recompensadaEmUnix"] = int(recibo["concluidaEmUnix"])
	missoes[id] = registro_missao
	perfil["moedas"] = saldo
	perfil["missoes"] = missoes
	perfil["missoesConcluidas"] = concluidas
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar a conclusão da missão."}
	return {
		"ok":true,"missaoId":id,"quantidadeRecebida":quantidade,
		"denominacao":"bronze","nomeMoeda":SistemaMoedas.nome_com_simbolo("bronze"),
		"moedas":saldo.duplicate(true),"perfil":perfil.duplicate(true)
	}

func conceder_drops(uid: String, drops: Array) -> bool:
	if not _uid_valido(uid) or drops.is_empty() or drops.size() > 100:
		return false
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return false
	var inventario: Array = perfil.get("inventario", [])
	for drop in drops:
		if not (drop is Dictionary):
			return false
		var item_id := str(drop.get("itemId", "")).strip_edges()
		var quantidade := int(drop.get("quantidade", 0))
		var raridade := str(drop.get("raridade", ""))
		if item_id.is_empty() or item_id.length() > 128 or quantidade < 1 or quantidade > 999:
			return false
		if not SistemaDrops.RARIDADES.has(raridade):
			return false
		if str(drop.get("categoria", "material")) == "moeda":
			var denominacao := str(drop.get("denominacaoMoeda", ""))
			if not SistemaMoedas.DENOMINACOES.has(denominacao):
				return false
			var saldo_moedas := SistemaMoedas.normalizar(perfil.get("moedas", {}))
			var novo_total := int(saldo_moedas.get(denominacao, 0)) + quantidade
			if novo_total > SistemaMoedas.LIMITE_SALDO:
				return false
			saldo_moedas[denominacao] = novo_total
			perfil["moedas"] = saldo_moedas
			continue
		var encontrado := false
		for existente in inventario:
			if str(existente.get("itemId", "")) == item_id and str(existente.get("raridade", "")) == raridade:
				existente["quantidade"] = int(existente.get("quantidade", 0)) + quantidade
				encontrado = true
				break
		if not encontrado:
			inventario.append({
				"itemId": item_id,
				"nome": str(drop.get("nome", item_id)),
				"categoria": str(drop.get("categoria", "material")),
				"raridade": raridade,
				"quantidade": quantidade,
				"origemCriaturaId": str(drop.get("origemCriaturaId", "")),
				"modeloCompanheiro": drop.get("modeloCompanheiro", {})
			})
	perfil["inventario"] = inventario
	return salvar(uid, perfil)


## Operações chamadas pela lógica autoritativa do servidor; nunca expostas como RPC de cliente.
func equipar_item(uid: String, item_id: String) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Conta inválida."}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	var possui := false
	for item in perfil.get("inventario", []):
		if str(item.get("itemId", "")) == item_id and int(item.get("quantidade", 0)) > 0:
			possui = true
			break
	if not possui:
		return {"ok":false,"erro":"Esse item não está no inventário."}
	var equipamentos: Dictionary = perfil.get("equipamentos", {})
	var resultado := SistemaEquipamentos.equipar(equipamentos, item_id, str(perfil.get("classeId", "")))
	if not bool(resultado.get("ok", false)):
		return resultado
	perfil["equipamentos"] = resultado["equipamentos"]
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar o equipamento."}
	return {"ok":true,"equipamentos":resultado["equipamentos"]}

func desequipar_slot(uid: String, slot: String) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Conta inválida."}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	var resultado := SistemaEquipamentos.desequipar(perfil.get("equipamentos", {}), slot)
	if not bool(resultado.get("ok", false)):
		return resultado
	perfil["equipamentos"] = resultado["equipamentos"]
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar a alteração."}
	return {"ok":true,"equipamentos":resultado["equipamentos"]}


## Persiste recursos ao encerrar um combate.
## Derrota aplica recuperação total; XP e ouro ficam fora desta operação.
func registrar_recursos_combate(uid: String, vida: int, mana: int, derrotado: bool = false) -> bool:
	if not _uid_valido(uid):
		return false
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return false
	var base := {
		"forca": int(perfil.get("forca", 5)),
		"inteligencia": int(perfil.get("inteligencia", 5)),
		"agilidade": int(perfil.get("agilidade", 5)),
		"vitalidade": int(perfil.get("vitalidade", 5)),
		"espirito": int(perfil.get("espirito", 5)),
		"vidaMaxima": int(perfil.get("vidaMaxima", 100)),
		"manaMaxima": int(perfil.get("manaMaxima", 50))
	}
	var efetivos := SistemaEquipamentos.calcular_atributos_efetivos(base, perfil.get("equipamentos", {}))
	var vida_maxima := int(efetivos.get("vidaMaxima", base["vidaMaxima"]))
	var mana_maxima := int(efetivos.get("manaMaxima", base["manaMaxima"]))
	perfil["vida"] = vida_maxima if derrotado else clampi(vida, 0, vida_maxima)
	perfil["mana"] = mana_maxima if derrotado else clampi(mana, 0, mana_maxima)
	return salvar(uid, perfil)



## Acrescenta XP calculado pelo servidor sem aceitar valores enviados pelo cliente.
func conceder_experiencia(uid: String, quantidade: int) -> Dictionary:
	if not _uid_valido(uid) or quantidade <= 0 or quantidade > 100000000:
		return {"ok":false,"erro":"Quantidade de experiência inválida."}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	perfil["experiencia"] = int(perfil.get("experiencia", 0)) + quantidade
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar a experiência."}
	return {"ok":true,"experienciaConcedida":quantidade,"experienciaTotal":int(perfil.get("experiencia", 0)),"perfil":perfil.duplicate(true)}

## Aplica XP, drops e recursos finais do combate em uma única gravação do perfil.
## O identificador persistido torna a operação idempotente contra repetição/reconexão.
func conceder_recompensa_encontro(uid: String, encontro_id: String, experiencia: int, drops: Array, vida_final: int, mana_final: int) -> Dictionary:
	var id := encontro_id.strip_edges()
	if not _uid_valido(uid) or id.is_empty() or id.length() > 160 or experiencia < 0 or experiencia > 100000000 or drops.size() > 100:
		return {"ok":false,"erro":"Dados da recompensa do encontro inválidos."}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	var recibos: Array = perfil.get("encontrosRecompensados", []).duplicate()
	if recibos.has(id):
		return {"ok":true,"duplicada":true,"perfil":perfil.duplicate(true)}
	if recibos.size() >= 5000:
		return {"ok":false,"erro":"Limite do histórico de recompensas de encontros atingido."}
	var inventario: Array = perfil.get("inventario", []).duplicate(true)
	var moedas: Dictionary = SistemaMoedas.normalizar(perfil.get("moedas", {}))
	for drop in drops:
		if not (drop is Dictionary):
			return {"ok":false,"erro":"Drop inválido no recibo do encontro."}
		var item_id := str(drop.get("itemId", "")).strip_edges()
		var quantidade := int(drop.get("quantidade", 0))
		var raridade := str(drop.get("raridade", "comum")).to_lower()
		if item_id.is_empty() or item_id.length() > 128 or quantidade < 1 or quantidade > 999 or not SistemaDrops.RARIDADES.has(raridade):
			return {"ok":false,"erro":"Item ou quantidade de drop inválidos."}
		if str(drop.get("categoria", "material")) == "moeda":
			var denominacao := str(drop.get("denominacaoMoeda", ""))
			if not SistemaMoedas.DENOMINACOES.has(denominacao):
				return {"ok":false,"erro":"Denominação de moeda inválida."}
			var novo_total := int(moedas.get(denominacao, 0)) + quantidade
			if novo_total > SistemaMoedas.LIMITE_SALDO:
				return {"ok":false,"erro":"O limite de saldo seria ultrapassado."}
			moedas[denominacao] = novo_total
			continue
		var encontrado := false
		for item_existente in inventario:
			if str(item_existente.get("itemId", "")) == item_id and str(item_existente.get("raridade", "")) == raridade:
				item_existente["quantidade"] = int(item_existente.get("quantidade", 0)) + quantidade
				encontrado = true
				break
		if not encontrado:
			inventario.append({"itemId":item_id,"nome":str(drop.get("nome", item_id)),"categoria":str(drop.get("categoria", "material")),"raridade":raridade,"quantidade":quantidade,"origemCriaturaId":str(drop.get("origemCriaturaId", "")),"modeloCompanheiro":drop.get("modeloCompanheiro", {})})
	perfil["experiencia"] = int(perfil.get("experiencia", 0)) + experiencia
	perfil["inventario"] = inventario
	perfil["moedas"] = moedas
	var efetivos := SistemaEquipamentos.calcular_atributos_efetivos({"forca":int(perfil.get("forca",5)),"inteligencia":int(perfil.get("inteligencia",5)),"agilidade":int(perfil.get("agilidade",5)),"vitalidade":int(perfil.get("vitalidade",5)),"espirito":int(perfil.get("espirito",5)),"vidaMaxima":int(perfil.get("vidaMaxima",100)),"manaMaxima":int(perfil.get("manaMaxima",50))}, perfil.get("equipamentos", {}))
	perfil["vida"] = clampi(vida_final, 1, int(efetivos.get("vidaMaxima", perfil.get("vidaMaxima", 100))))
	perfil["mana"] = clampi(mana_final, 0, int(efetivos.get("manaMaxima", perfil.get("manaMaxima", 50))))
	recibos.append(id)
	perfil["encontrosRecompensados"] = recibos
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível persistir a recompensa do encontro."}
	return {"ok":true,"duplicada":false,"experienciaConcedida":experiencia,"perfil":perfil.duplicate(true)}

func _snapshot_valido(d: Dictionary) -> bool:
	var missoes: Dictionary = d.get("missoes", {})
	if not _missoes_validas(missoes):
		return false
	var moedas: Dictionary = d.get("moedas", SistemaMoedas.criar_saldo_vazio())
	for denominacao in SistemaMoedas.DENOMINACOES:
		var saldo_moeda := int(moedas.get(denominacao, 0))
		if saldo_moeda < 0 or saldo_moeda > SistemaMoedas.LIMITE_SALDO:
			return false
	var nivel := int(d.get("nivel", 0))
	var experiencia := int(d.get("experiencia", -1))
	var vida_maxima := int(d.get("vidaMaxima", 0))
	var vida := int(d.get("vida", -1))
	var mana_maxima := int(d.get("manaMaxima", -1))
	var mana := int(d.get("mana", -1))
	var x := float(d.get("x", -1.0))
	var y := float(d.get("y", -1.0))
	if nivel < 1 or nivel > 10000 or experiencia < 0:
		return false
	var base_recursos := {"forca":int(d.get("forca",5)),"inteligencia":int(d.get("inteligencia",5)),"agilidade":int(d.get("agilidade",5)),"vitalidade":int(d.get("vitalidade",5)),"espirito":int(d.get("espirito",5)),"vidaMaxima":vida_maxima,"manaMaxima":mana_maxima}
	var efetivos_recursos := SistemaEquipamentos.calcular_atributos_efetivos(base_recursos, d.get("equipamentos", {}))
	var vida_maxima_efetiva := int(efetivos_recursos.get("vidaMaxima", vida_maxima))
	var mana_maxima_efetiva := int(efetivos_recursos.get("manaMaxima", mana_maxima))
	if vida_maxima < 1 or vida_maxima > 100000000 or vida < 0 or vida > vida_maxima_efetiva:
		return false
	if mana_maxima < 0 or mana_maxima > 100000000 or mana < 0 or mana > mana_maxima_efetiva:
		return false
	if not is_finite(x) or not is_finite(y):
		return false
	if x < 0.0 or x > 2400.0 or y < 0.0 or y > 2400.0:
		return false
	for atributo in ["forca", "inteligencia", "agilidade", "vitalidade", "espirito"]:
		var valor := int(d.get(atributo, -1))
		if valor < 0 or valor > 1000000:
			return false
	var nome := str(d.get("nome", ""))
	if bool(d.get("personagemCriado", false)) and (nome.strip_edges().length() < 3 or nome.length() > 20):
		return false
	if bool(d.get("personagemCriado", false)) and not CATALOGO.validar(str(d.get("sexo","")), str(d.get("aparenciaId","")), str(d.get("racaId","")), str(d.get("classeId",""))):
		return false
	var equipamentos: Dictionary = d.get("equipamentos", {})
	if not equipamentos.is_empty():
		for slot in equipamentos:
			if not SistemaEquipamentos.SLOTS.has(str(slot)):
				return false
			var item_id := str(equipamentos[slot])
			if item_id.is_empty():
				continue
			var definicao := SistemaEquipamentos.obter(item_id)
			if definicao.is_empty() or str(definicao.get("slot", "")) != str(slot):
				return false
		var mao_principal := SistemaEquipamentos.obter(str(equipamentos.get("mao_principal", "")))
		if int(mao_principal.get("maos", 1)) == 2 and not str(equipamentos.get("mao_secundaria", "")).is_empty():
			return false
		var secundario := SistemaEquipamentos.obter(str(equipamentos.get("mao_secundaria", "")))
		if not secundario.is_empty() and secundario.get("tipo") != "escudo":
			return false
		if not secundario.is_empty() and not SistemaEquipamentos.CLASSES_CORPO_A_CORPO.has(str(d.get("classeId", ""))):
			return false
	return true

func _uid_valido(uid: String) -> bool:
	return not uid.is_empty() and uid.length() <= 128 and uid.is_valid_filename()

func _ler_banco() -> Dictionary:
	if FileAccess.file_exists(CAMINHO):
		var principal := _ler_arquivo_banco(CAMINHO)
		if not principal.is_empty():
			return _migrar_coordenadas_banco(principal)
		var backup := _ler_arquivo_banco(CAMINHO_BACKUP)
		if not backup.is_empty():
			push_warning("Banco principal inválido; usando a cópia de segurança.")
			return _migrar_coordenadas_banco(backup)
		return {}
	if FileAccess.file_exists(CAMINHO_BACKUP):
		var backup := _ler_arquivo_banco(CAMINHO_BACKUP)
		return _migrar_coordenadas_banco(backup) if not backup.is_empty() else {}
	return {"versao": 1, "versaoCoordenadas": SistemaMigracao.VERSAO_COORDENADAS, "personagens": {}}

func _migrar_coordenadas_banco(banco: Dictionary) -> Dictionary:
	if int(banco.get("versaoCoordenadas", 0)) >= SistemaMigracao.VERSAO_COORDENADAS:
		return banco
	var personagens: Dictionary = banco.get("personagens", {})
	for uid in personagens.keys():
		if not (personagens[uid] is Dictionary):
			return {}
		var migrado := SistemaMigracao.migrar_perfil_legado(personagens[uid])
		if migrado.is_empty():
			return {}
		personagens[uid] = migrado
	banco["personagens"] = personagens
	banco["versaoCoordenadas"] = SistemaMigracao.VERSAO_COORDENADAS
	if not _gravar_banco(banco):
		push_error("Migração de coordenadas dos personagens não foi persistida; acesso bloqueado.")
		return {}
	return banco

func _ler_arquivo_banco(caminho: String) -> Dictionary:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null or arquivo.get_length() > LIMITE_ARQUIVO:
		return {}
	var dados = JSON.parse_string(arquivo.get_as_text())
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1:
		return {}
	if not (dados.get("personagens", {}) is Dictionary):
		return {}
	return dados

func _gravar_banco(banco: Dictionary) -> bool:
	var diretorio := ProjectSettings.globalize_path("user://dados")
	var caminho_final := ProjectSettings.globalize_path(CAMINHO)
	var caminho_backup := ProjectSettings.globalize_path(CAMINHO_BACKUP)
	var caminho_temporario := caminho_final + ".tmp"
	if DirAccess.make_dir_recursive_absolute(diretorio) != OK and not DirAccess.dir_exists_absolute(diretorio):
		return false
	var arquivo := FileAccess.open(caminho_temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(banco))
	arquivo.flush()
	var erro_arquivo := arquivo.get_error()
	arquivo.close()
	if erro_arquivo != OK:
		return false
	# Se o arquivo principal estiver corrompido, recupera primeiro o backup válido.
	if FileAccess.file_exists(CAMINHO) and _ler_arquivo_banco(CAMINHO).is_empty() and not _ler_arquivo_banco(CAMINHO_BACKUP).is_empty():
		if DirAccess.remove_absolute(caminho_final) != OK:
			return false
		if DirAccess.rename_absolute(caminho_backup, caminho_final) != OK:
			return false
	# Mantém a última versão válida antes de promover o arquivo temporário.
	if FileAccess.file_exists(CAMINHO):
		if FileAccess.file_exists(CAMINHO_BACKUP):
			if DirAccess.remove_absolute(caminho_backup) != OK:
				return false
		if DirAccess.rename_absolute(caminho_final, caminho_backup) != OK:
			return false
	if DirAccess.rename_absolute(caminho_temporario, caminho_final) != OK:
		if not FileAccess.file_exists(CAMINHO) and FileAccess.file_exists(CAMINHO_BACKUP):
			DirAccess.rename_absolute(caminho_backup, caminho_final)
		return false
	return true
