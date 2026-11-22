extends RefCounted
## Catálogo global de criaturas fornecidas pela geração confiável do servidor.
## Não contém inimigos predefinidos nem gera criaturas artificiais.
const CAMINHO_PADRAO := "user://dados/criaturas_online.json"
const LIMITE_ARQUIVO := 32 * 1024 * 1024
const SISTEMA_EVOLUCAO = preload("res://scripts/sistema_evolucao_criaturas.gd")
const SISTEMA_ECOLOGIA = preload("res://scripts/sistema_ecologia_criaturas.gd")
const RANKS := ["E", "D", "C", "B", "A", "S", "SS", "SSS"]
const RARIDADES := ["comum", "incomum", "raro", "epico", "lendario", "mitico", "divino", "transcendente", "unico"]
const ECOSSISTEMAS := ["montanhas_gelidas", "floresta_arcana", "imperio", "central", "sombras", "deserto_ancestral", "mar_eternal"]

var caminho_arquivo: String

func _init(caminho: String = CAMINHO_PADRAO) -> void:
	caminho_arquivo = caminho

func registrar_criatura_gerada(criatura: Dictionary) -> Dictionary:
	if not validar_criatura(criatura):
		return {"ok":false,"erro":"Dados da criatura gerada são inválidos."}
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(caminho_arquivo):
		return {"ok":false,"erro":"Catálogo inválido; registro bloqueado para proteger os dados."}
	var criaturas: Dictionary = banco.get("criaturas", {})
	var id := str(criatura.get("id", ""))
	if criaturas.has(id):
		return {"ok":false,"erro":"Já existe uma criatura registrada com esse identificador.","duplicada":true}
	var registro := SISTEMA_EVOLUCAO.preparar(criatura)
	registro["versao"] = maxi(1, int(registro.get("versao", 1)))
	registro["descobertaGlobal"] = false
	registro["totalDescobertas"] = 0
	registro["totalDerrotas"] = 0
	criaturas[id] = registro
	banco["criaturas"] = criaturas
	var estatisticas: Dictionary = banco.get("estatisticas", {})
	estatisticas[id] = {
		"primeiroDescobridorUid":"",
		"primeiraDescobertaUnix":0,
		"primeiroDerrotadorUid":"",
		"primeiraDerrotaUnix":0,
		"jogadoresQueDescobriram":[],
		"derrotasPorJogador":{}
	}
	banco["estatisticas"] = estatisticas
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível persistir a criatura."}
	return {"ok":true,"criatura":registro.duplicate(true)}

func validar_criatura(d: Dictionary) -> bool:
	var id := str(d.get("id", "")).strip_edges()
	var nome := str(d.get("nome", "")).strip_edges()
	var descricao := str(d.get("descricao", "")).strip_edges()
	var rank := str(d.get("rank", "")).to_upper()
	var raridade := str(d.get("raridade", "")).to_lower()
	var nivel := int(d.get("nivel", 0))
	var vida := int(d.get("vidaMaxima", 0))
	var ataque := int(d.get("ataque", 0))
	var defesa := int(d.get("defesa", 0))
	var mana := int(d.get("manaMaxima", 0))
	var agilidade := int(d.get("agilidade", 0))
	var poder_magico := int(d.get("poderMagico", 0))
	var experiencia := int(d.get("experienciaBase", -1))
	var perigo := int(d.get("perigo", -1))
	var ecossistema := str(d.get("ecossistemaId", ""))
	var bioma := str(d.get("bioma", "")).strip_edges()
	var habitat := str(d.get("habitat", "")).strip_edges()
	var habilidades = d.get("habilidades", [])
	var tabela_drops = d.get("tabelaDrops", [])
	if id.is_empty() or id.length() > 128 or not id.is_valid_filename():
		return false
	if nome.length() < 2 or nome.length() > 64 or descricao.is_empty() or descricao.length() > 2000:
		return false
	if not RANKS.has(rank) or not RARIDADES.has(raridade):
		return false
	if nivel < 1 or nivel > 100000 or vida < 1 or vida > 100000000:
		return false
	if ataque < 0 or defesa < 0 or mana < 0 or agilidade < 0 or poder_magico < 0:
		return false
	if experiencia < 0 or perigo < 0 or perigo > 100:
		return false
	if not ECOSSISTEMAS.has(ecossistema) or bioma.is_empty() or habitat.is_empty():
		return false
	if not (habilidades is Array) or habilidades.size() > 100:
		return false
	for habilidade in habilidades:
		if not (habilidade is Dictionary) or str(habilidade.get("id", "")).strip_edges().is_empty():
			return false
	if not (tabela_drops is Array) or tabela_drops.size() > 200:
		return false
	var SistemaDrops = preload("res://scripts/sistema_drops.gd")
	if not SistemaDrops.validar_tabela(tabela_drops):
		return false
	for campo_visual in ["imagemId", "iconePath", "detalhePath"]:
		var valor := str(d.get(campo_visual, ""))
		if valor.length() > 512:
			return false
	if d.has("chefe") and not (d["chefe"] is bool):
		return false
	if not SISTEMA_ECOLOGIA.validar_ecologia(d.get("ecologia", null)):
		return false
	return true

func obter_criatura(id: String) -> Dictionary:
	aplicar_evolucao_temporal(id)
	var banco := _ler_banco()
	var criatura: Dictionary = banco.get("criaturas", {}).get(id, {})
	return criatura.duplicate(true)

## Registra que a criatura sobreviveu e derrotou um jogador.
## A criatura continua no catálogo; não é removida ao fim do combate.
func registrar_vitoria_sobre_jogador(uid: String, criatura_id: String, posicao_mundo: Vector2 = Vector2(-1.0, -1.0)) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Jogador inválido."}
	var banco := _ler_banco()
	var criaturas: Dictionary = banco.get("criaturas", {})
	if not criaturas.has(criatura_id):
		return {"ok":false,"erro":"Criatura não encontrada no catálogo."}
	var criatura: Dictionary = criaturas[criatura_id]
	var resultado := SISTEMA_EVOLUCAO.registrar_vitoria(criatura, uid)
	if not bool(resultado.get("ok", false)):
		return resultado
	var criatura_atualizada: Dictionary = resultado["criatura"]
	if posicao_mundo.x >= 0.0 and posicao_mundo.y >= 0.0:
		var posicao := {"x":posicao_mundo.x,"y":posicao_mundo.y}
		criatura_atualizada["posicaoMundo"] = posicao.duplicate(true)
		criatura_atualizada["origemMundo"] = posicao.duplicate(true)
		criatura_atualizada["alvoMundo"] = posicao.duplicate(true)
		criatura_atualizada["estadoMundo"] = "vagando"
		criatura_atualizada["ultimaAtualizacaoMundoUnix"] = int(Time.get_unix_time_from_system())
	criaturas[criatura_id] = criatura_atualizada
	banco["criaturas"] = criaturas
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a evolução da criatura."}
	return {"ok":true,"vitoriasSobreJogadores":int(resultado.get("vitoriasSobreJogadores", 0)),"criatura":criatura_atualizada.duplicate(true)}

## Atualiza a evolução acumulada enquanto a criatura permaneceu viva no mundo.
func aplicar_evolucao_temporal(criatura_id: String, agora_unix: int = -1) -> bool:
	var banco := _ler_banco()
	var criaturas: Dictionary = banco.get("criaturas", {})
	if not criaturas.has(criatura_id):
		return false
	var criatura: Dictionary = criaturas[criatura_id]
	var resultado := SISTEMA_EVOLUCAO.aplicar_tempo(criatura, agora_unix)
	if not bool(resultado.get("ok", false)):
		return false
	if not bool(resultado.get("alterou", false)):
		return true
	criaturas[criatura_id] = resultado["criatura"]
	banco["criaturas"] = criaturas
	return _gravar_banco(banco)

func listar_criaturas_do_ecossistema(ecossistema_id: String) -> Array:
	var banco := _ler_banco()
	var ids_para_evoluir: Array = []
	for id in banco.get("criaturas", {}).keys():
		if str(banco["criaturas"][id].get("ecossistemaId", "")) == ecossistema_id:
			ids_para_evoluir.append(str(id))
	for id in ids_para_evoluir:
		aplicar_evolucao_temporal(id)
	banco = _ler_banco()
	var resultado: Array = []
	for criatura in banco.get("criaturas", {}).values():
		if str(criatura.get("ecossistemaId", "")) == ecossistema_id:
			resultado.append(criatura.duplicate(true))
	return resultado


## Retorna apenas criaturas que já derrotaram jogadores e possuem posição persistida.
func listar_criaturas_persistentes() -> Array:
	var banco := _ler_banco()
	var resultado: Array = []
	for criatura in banco.get("criaturas", {}).values():
		var evolucao: Dictionary = criatura.get("evolucao", {})
		if int(evolucao.get("vitoriasSobreJogadores", 0)) <= 0:
			continue
		if not (criatura.get("posicaoMundo", {}) is Dictionary):
			continue
		resultado.append(criatura.duplicate(true))
	return resultado

## Salva várias posições de uma vez para evitar uma gravação por criatura.
func salvar_posicoes_mundo(atualizacoes: Array) -> bool:
	if atualizacoes.is_empty():
		return true
	var banco := _ler_banco()
	var criaturas: Dictionary = banco.get("criaturas", {})
	for atualizacao in atualizacoes:
		if not (atualizacao is Dictionary):
			continue
		var id := str(atualizacao.get("id", ""))
		if not criaturas.has(id):
			continue
		var posicao = atualizacao.get("posicaoMundo", {})
		var alvo = atualizacao.get("alvoMundo", {})
		var estado_mundo := str(atualizacao.get("estadoMundo", "vagando"))
		if not ["vagando", "fugindo", "cacando", "buscando_habitat", "defendendo_territorio"].has(estado_mundo):
			return false
		if not (posicao is Dictionary) or not (alvo is Dictionary):
			continue
		var x := float(posicao.get("x", -1.0))
		var y := float(posicao.get("y", -1.0))
		var alvo_x := float(alvo.get("x", -1.0))
		var alvo_y := float(alvo.get("y", -1.0))
		if x < 0.0 or x > 2400.0 or y < 0.0 or y > 1600.0 or alvo_x < 0.0 or alvo_x > 2400.0 or alvo_y < 0.0 or alvo_y > 1600.0:
			return false
		var criatura: Dictionary = criaturas[id]
		criatura["posicaoMundo"] = {"x":x,"y":y}
		criatura["alvoMundo"] = {"x":alvo_x,"y":alvo_y}
		criatura["estadoMundo"] = estado_mundo
		criatura["ultimaAtualizacaoMundoUnix"] = int(Time.get_unix_time_from_system())
		criaturas[id] = criatura
	banco["criaturas"] = criaturas
	return _gravar_banco(banco)

func registrar_descoberta(uid: String, criatura_id: String) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Jogador inválido."}
	var banco := _ler_banco()
	var criaturas: Dictionary = banco.get("criaturas", {})
	if not criaturas.has(criatura_id):
		return {"ok":false,"erro":"Criatura não encontrada no catálogo."}
	var criatura: Dictionary = criaturas[criatura_id]
	var estatisticas: Dictionary = banco.get("estatisticas", {})
	var dados: Dictionary = estatisticas.get(criatura_id, _estatistica_vazia())
	var descobridores: Array = dados.get("jogadoresQueDescobriram", [])
	if descobridores.has(uid):
		return {"ok":true,"novaDescoberta":false,"criatura":criatura.duplicate(true)}
	descobridores.append(uid)
	dados["jogadoresQueDescobriram"] = descobridores
	dados["totalDescobertas"] = int(dados.get("totalDescobertas", 0)) + 1
	if str(dados.get("primeiroDescobridorUid", "")).is_empty():
		dados["primeiroDescobridorUid"] = uid
		dados["primeiraDescobertaUnix"] = int(Time.get_unix_time_from_system())
	criatura["descobertaGlobal"] = true
	criatura["totalDescobertas"] = int(dados["totalDescobertas"])
	estatisticas[criatura_id] = dados
	criaturas[criatura_id] = criatura
	banco["estatisticas"] = estatisticas
	banco["criaturas"] = criaturas
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a descoberta."}
	return {"ok":true,"novaDescoberta":true,"criatura":criatura.duplicate(true)}

func registrar_derrota(uid: String, criatura_id: String) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Jogador inválido."}
	var banco := _ler_banco()
	var criaturas: Dictionary = banco.get("criaturas", {})
	if not criaturas.has(criatura_id):
		return {"ok":false,"erro":"Criatura não encontrada no catálogo."}
	var criatura: Dictionary = criaturas[criatura_id]
	var estatisticas: Dictionary = banco.get("estatisticas", {})
	var dados: Dictionary = estatisticas.get(criatura_id, _estatistica_vazia())
	var derrotas: Dictionary = dados.get("derrotasPorJogador", {})
	derrotas[uid] = int(derrotas.get(uid, 0)) + 1
	dados["derrotasPorJogador"] = derrotas
	dados["totalDerrotas"] = int(dados.get("totalDerrotas", 0)) + 1
	if str(dados.get("primeiroDerrotadorUid", "")).is_empty():
		dados["primeiroDerrotadorUid"] = uid
		dados["primeiraDerrotaUnix"] = int(Time.get_unix_time_from_system())
	criatura["totalDerrotas"] = int(dados["totalDerrotas"])
	estatisticas[criatura_id] = dados
	criaturas[criatura_id] = criatura
	banco["estatisticas"] = estatisticas
	banco["criaturas"] = criaturas
	if not _gravar_banco(banco):
		return {"ok":false,"erro":"Não foi possível salvar a derrota."}
	return {"ok":true,"totalDerrotas":int(dados["totalDerrotas"])}

func obter_estatisticas(criatura_id: String) -> Dictionary:
	var banco := _ler_banco()
	return banco.get("estatisticas", {}).get(criatura_id, {}).duplicate(true)

func _estatistica_vazia() -> Dictionary:
	return {
		"primeiroDescobridorUid":"",
		"primeiraDescobertaUnix":0,
		"primeiroDerrotadorUid":"",
		"primeiraDerrotaUnix":0,
		"jogadoresQueDescobriram":[],
		"derrotasPorJogador":{},
		"totalDescobertas":0,
		"totalDerrotas":0
	}

func _uid_valido(uid: String) -> bool:
	return not uid.is_empty() and uid.length() <= 128 and uid.is_valid_filename()

func _ler_banco() -> Dictionary:
	var backup := caminho_arquivo + ".bak"
	if FileAccess.file_exists(caminho_arquivo):
		var principal := _ler_arquivo(caminho_arquivo)
		if not principal.is_empty():
			return principal
		var copia := _ler_arquivo(backup)
		if not copia.is_empty():
			push_warning("Catálogo de criaturas inválido; usando backup.")
			return copia
		return {}
	if FileAccess.file_exists(backup):
		return _ler_arquivo(backup)
	return {"versao":1,"criaturas":{},"estatisticas":{}}

func _ler_arquivo(caminho: String) -> Dictionary:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null or arquivo.get_length() > LIMITE_ARQUIVO:
		return {}
	var dados = JSON.parse_string(arquivo.get_as_text())
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1:
		return {}
	if not (dados.get("criaturas", {}) is Dictionary) or not (dados.get("estatisticas", {}) is Dictionary):
		return {}
	return dados

func _gravar_banco(banco: Dictionary) -> bool:
	var diretorio := caminho_arquivo.get_base_dir()
	var caminho_final := ProjectSettings.globalize_path(caminho_arquivo)
	var caminho_backup := ProjectSettings.globalize_path(caminho_arquivo + ".bak")
	var caminho_temporario := caminho_final + ".tmp"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(diretorio)) != OK and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(diretorio)):
		return false
	var arquivo := FileAccess.open(caminho_temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(banco))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		return false
	if FileAccess.file_exists(caminho_arquivo):
		if FileAccess.file_exists(caminho_arquivo + ".bak"):
			if DirAccess.remove_absolute(caminho_backup) != OK:
				return false
		if DirAccess.rename_absolute(caminho_final, caminho_backup) != OK:
			return false
	if DirAccess.rename_absolute(caminho_temporario, caminho_final) != OK:
		if not FileAccess.file_exists(caminho_arquivo) and FileAccess.file_exists(caminho_arquivo + ".bak"):
			DirAccess.rename_absolute(caminho_backup, caminho_final)
		return false
	return true
