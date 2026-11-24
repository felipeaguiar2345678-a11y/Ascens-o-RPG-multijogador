extends RefCounted
## Orquestra missões opcionais do mundo aberto com o perfil persistente.
## Instanciar e chamar somente na lógica autoritativa do servidor; não é RPC.

const SISTEMA_MISSOES = preload("res://scripts/sistema_missoes_mundo.gd")
const REPOSITORIO_PERFIL = preload("res://scripts/repositorio_personagem_servidor.gd")
const CAMINHO_CATALOGO_PADRAO := "user://dados/ofertas_missoes_mundo.json"
const LIMITE_CATALOGO_BYTES := 1024 * 1024
const LIMITE_OFERTAS := 500

var _repositorio
var _sistema = SISTEMA_MISSOES.new()
var _catalogo_ofertas: Dictionary = {}
var caminho_catalogo: String

func _init(repositorio: Object = null, caminho: String = CAMINHO_CATALOGO_PADRAO) -> void:
	_repositorio = repositorio if repositorio != null else REPOSITORIO_PERFIL.new()
	caminho_catalogo = caminho
	_carregar_catalogo()

func registrar_oferta(definicao: Dictionary) -> Dictionary:
	var id := str(definicao.get("id", "")).strip_edges()
	if id.is_empty() or _catalogo_ofertas.has(id) or _catalogo_ofertas.size() >= LIMITE_OFERTAS:
		return {"ok": false, "erro": "Identificação inválida, oferta duplicada ou catálogo cheio."}
	var novo_sistema = SISTEMA_MISSOES.new()
	for existente in _catalogo_ofertas.values():
		var resultado_existente: Dictionary = novo_sistema.registrar_oferta(existente)
		if not bool(resultado_existente.get("ok", false)):
			return {"ok": false, "erro": "O catálogo atual contém uma oferta inválida."}
	var validacao: Dictionary = novo_sistema.registrar_oferta(definicao)
	if not bool(validacao.get("ok", false)):
		return validacao
	var novas_ofertas := _catalogo_ofertas.duplicate(true)
	novas_ofertas[id] = definicao.duplicate(true)
	var salvo := _salvar_catalogo(novas_ofertas)
	if not bool(salvo.get("ok", false)):
		return salvo
	_catalogo_ofertas = novas_ofertas
	_sistema = novo_sistema
	return {"ok": true, "missaoId": id, "npcId": str(definicao.get("npcId", ""))}

func listar_ofertas(uid: String, npc_id: String) -> Array:
	var perfil: Dictionary = _carregar_perfil(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return []
	return _sistema.listar_ofertas(npc_id, perfil)

## Retorna apenas missões já aceitas por este personagem e vinculadas ao NPC.
func missao_vinculada_ao_npc(uid: String, npc_id: String, missao_id: String, acao: String) -> bool:
	if acao in ["aceitar", "recusar"]:
		return _sistema.oferta_pertence_ao_npc(missao_id, npc_id)
	if acao in ["abandonar", "concluir"]:
		var perfil: Dictionary = _carregar_perfil(uid)
		var missoes: Dictionary = perfil.get("missoes", {})
		if not missoes.has(missao_id) or not (missoes[missao_id] is Dictionary):
			return false
		var registro: Dictionary = missoes[missao_id]
		if str(registro.get("npcId", "")) != npc_id:
			return false
		if acao == "concluir" and str(registro.get("status", "")) != "objetivos_concluidos":
			return false
		return true
	return false

func listar_missoes_do_npc(uid: String, npc_id: String) -> Array:
	var perfil: Dictionary = _carregar_perfil(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return []
	var resultado: Array = []
	var missoes: Dictionary = perfil.get("missoes", {})
	for missao_id in missoes:
		var registro = missoes[missao_id]
		if not (registro is Dictionary) or str(registro.get("npcId", "")) != npc_id:
			continue
		var status := str(registro.get("status", ""))
		if status not in ["em_andamento", "objetivos_concluidos", "abandonada"]:
			continue
		resultado.append({
			"id": str(missao_id),
			"titulo": str(registro.get("titulo", "Missão")),
			"status": status,
			"progresso": registro.get("progresso", {}).duplicate(true),
			"objetivos": registro.get("objetivos", []).duplicate(true)
		})
	return resultado

func aceitar(uid: String, missao_id: String) -> Dictionary:
	var perfil: Dictionary = _carregar_perfil(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok": false, "erro": "Personagem não encontrado."}
	var resultado: Dictionary = _sistema.aceitar_missao(perfil, missao_id)
	return _persistir_resultado(uid, resultado)

func recusar(uid: String, missao_id: String) -> Dictionary:
	var perfil: Dictionary = _carregar_perfil(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok": false, "erro": "Personagem não encontrado."}
	var resultado: Dictionary = _sistema.recusar_oferta(perfil, missao_id)
	return _persistir_resultado(uid, resultado)

func abandonar(uid: String, missao_id: String) -> Dictionary:
	var perfil: Dictionary = _carregar_perfil(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok": false, "erro": "Personagem não encontrado."}
	var resultado: Dictionary = _sistema.abandonar_missao(perfil, missao_id)
	return _persistir_resultado(uid, resultado)

## O chamador só deve enviar eventos que já foram confirmados pelo servidor do jogo.
func registrar_evento_confirmado(uid: String, tipo_evento: String, alvo_id: String, quantidade: int = 1) -> Dictionary:
	var perfil: Dictionary = _carregar_perfil(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok": false, "erro": "Personagem não encontrado."}
	var resultado: Dictionary = _sistema.registrar_evento_autoritativo(perfil, tipo_evento, alvo_id, quantidade)
	if not bool(resultado.get("ok", false)):
		return resultado
	var alteradas: Array = resultado.get("missoesAlteradas", [])
	if alteradas.is_empty():
		return resultado
	return _persistir_resultado(uid, resultado)

## O cliente não informa dificuldade nem quantidade de moedas; ambos vêm do perfil e do repositório.
func concluir_e_pagar(uid: String, missao_id: String) -> Dictionary:
	var id := missao_id.strip_edges()
	var perfil: Dictionary = _carregar_perfil(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok": false, "erro": "Personagem não encontrado."}
	var missoes: Dictionary = perfil.get("missoes", {})
	if not missoes.has(id) or not (missoes[id] is Dictionary):
		return {"ok": false, "erro": "Missão não encontrada no personagem."}
	var registro: Dictionary = missoes[id]
	if str(registro.get("status", "")) != "objetivos_concluidos":
		return {"ok": false, "erro": "Os objetivos ainda não foram concluídos pelo servidor."}
	return _repositorio.concluir_missao(uid, id, str(registro.get("dificuldade", "")))

func _carregar_perfil(uid: String) -> Dictionary:
	if uid.strip_edges().is_empty() or uid.length() > 128:
		return {}
	return _repositorio.carregar_ou_criar(uid)

func _persistir_resultado(uid: String, resultado: Dictionary) -> Dictionary:
	if not bool(resultado.get("ok", false)):
		return resultado
	var estado: Dictionary = resultado.get("estado", {})
	var missoes: Dictionary = estado.get("missoes", {})
	var salvo: Dictionary = _repositorio.salvar_missoes(uid, missoes)
	if not bool(salvo.get("ok", false)):
		return {"ok": false, "erro": str(salvo.get("erro", "Não foi possível salvar o progresso da missão."))}
	resultado["perfil"] = salvo.get("perfil", {})
	resultado.erase("estado")
	return resultado


## O catálogo é global ao servidor e sobrevive a reinícios.
## Um arquivo inválido nunca é sobrescrito automaticamente.
func _carregar_catalogo() -> void:
	_catalogo_ofertas.clear()
	_sistema = SISTEMA_MISSOES.new()
	if not FileAccess.file_exists(caminho_catalogo):
		return
	var arquivo := FileAccess.open(caminho_catalogo, FileAccess.READ)
	if arquivo == null or arquivo.get_length() > LIMITE_CATALOGO_BYTES:
		push_error("Catálogo de missões não pôde ser lido; ofertas permanecem indisponíveis.")
		return
	var dados = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1 or not (dados.get("ofertas", []) is Array):
		push_error("Catálogo de missões inválido; ofertas permanecem indisponíveis.")
		return
	var ofertas: Array = dados.get("ofertas", [])
	if ofertas.size() > LIMITE_OFERTAS:
		push_error("Catálogo de missões excede o limite permitido.")
		return
	var sistema_carregado = SISTEMA_MISSOES.new()
	var carregadas := {}
	for definicao in ofertas:
		if not (definicao is Dictionary):
			push_error("Oferta inválida no catálogo de missões.")
			return
		var resultado: Dictionary = sistema_carregado.registrar_oferta(definicao)
		if not bool(resultado.get("ok", false)):
			push_error("Oferta do catálogo não passou pela validação: " + str(resultado.get("erro", "")))
			return
		carregadas[str(definicao.get("id", ""))] = definicao.duplicate(true)
	_sistema = sistema_carregado
	_catalogo_ofertas = carregadas

func _salvar_catalogo(ofertas: Dictionary) -> Dictionary:
	var diretorio := caminho_catalogo.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(diretorio)) != OK:
		return {"ok": false, "erro": "Não foi possível criar a pasta do catálogo de missões."}
	var lista: Array = []
	for definicao in ofertas.values():
		lista.append(definicao.duplicate(true))
	var temporario := caminho_catalogo + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return {"ok": false, "erro": "Não foi possível preparar o catálogo de missões."}
	arquivo.store_string(JSON.stringify({"versao": 1, "ofertas": lista}))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporario))
		return {"ok": false, "erro": "Não foi possível gravar o catálogo de missões."}
	var destino := ProjectSettings.globalize_path(caminho_catalogo)
	var origem_temp := ProjectSettings.globalize_path(temporario)
	var backup := destino + ".bak"
	if FileAccess.file_exists(caminho_catalogo):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(destino, backup) != OK:
			DirAccess.remove_absolute(origem_temp)
			return {"ok": false, "erro": "Não foi possível proteger a versão anterior do catálogo."}
	if DirAccess.rename_absolute(origem_temp, destino) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, destino)
		return {"ok": false, "erro": "Não foi possível ativar o novo catálogo de missões."}
	return {"ok": true}
