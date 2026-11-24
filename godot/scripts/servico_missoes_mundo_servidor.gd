extends RefCounted
## Orquestra missões opcionais do mundo aberto com o perfil persistente.
## Instanciar e chamar somente na lógica autoritativa do servidor; não é RPC.

const SISTEMA_MISSOES = preload("res://scripts/sistema_missoes_mundo.gd")
const REPOSITORIO_PERFIL = preload("res://scripts/repositorio_personagem_servidor.gd")

var _repositorio
var _sistema = SISTEMA_MISSOES.new()

func _init(repositorio: Object = null) -> void:
	_repositorio = repositorio if repositorio != null else REPOSITORIO_PERFIL.new()

func registrar_oferta(definicao: Dictionary) -> Dictionary:
	return _sistema.registrar_oferta(definicao)

func listar_ofertas(uid: String, npc_id: String) -> Array:
	var perfil: Dictionary = _carregar_perfil(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return []
	return _sistema.listar_ofertas(npc_id, perfil)

## Retorna apenas missões já aceitas por este personagem e vinculadas ao NPC.
func missao_vinculada_ao_npc(uid: String, npc_id: String, missao_id: String, acao: String) -> bool:
	if acao in ["aceitar", "recusar"]:
		return _sistema.oferta_pertence_ao_npc(missao_id, npc_id)
	if acao == "abandonar":
		var perfil: Dictionary = _carregar_perfil(uid)
		var missoes: Dictionary = perfil.get("missoes", {})
		if not missoes.has(missao_id) or not (missoes[missao_id] is Dictionary):
			return false
		return str(missoes[missao_id].get("npcId", "")) == npc_id
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
