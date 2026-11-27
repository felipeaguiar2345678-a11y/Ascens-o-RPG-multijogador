extends RefCounted
class_name PerfilPersonagem

## Snapshot local do personagem autenticado.
## A autoridade para XP, atributos, vida, mana, posição e recompensas é o servidor.
## Esta classe não grava dados nem aceita alterações como prova de progresso.

const NIVEL_MINIMO := 1
const NIVEL_MAXIMO := 10000
const LIMITE_ESTADO := 2_000_000_000

var uid: String = ""
var personagem_id: String = ""
var nome: String = ""
var nivel: int = 1
var experiencia: int = 0
var vida: int = 100
var vida_maxima: int = 100
var mana: int = 50
var mana_maxima: int = 50
var forca: int = 5
var inteligencia: int = 5
var agilidade: int = 5
var vitalidade: int = 5
var espirito: int = 5
var ponto_mundo_id: String = "clareira_inicial"
var posicao_mundo: Vector2 = Vector2(1190.0, 1120.0)
var aparencia_id: String = ""
var sexo: String = ""
var raca_id: String = ""
var classe_id: String = ""
var afinidades_fisicas: Array = []
var afinidades_magicas: Array = []
var anatomia_racial: Dictionary = {}
var revisao_servidor: int = 0

func carregar_snapshot(dados: Dictionary, uid_esperado: String) -> bool:
	var uid_recebido := str(dados.get("uid", ""))
	if uid_esperado.is_empty() or uid_recebido != uid_esperado:
		return false

	var nivel_recebido := int(dados.get("nivel", 0))
	var experiencia_recebida := int(dados.get("experiencia", -1))
	var vida_maxima_recebida := int(dados.get("vidaMaxima", 0))
	var mana_maxima_recebida := int(dados.get("manaMaxima", 0))
	var x := float(dados.get("x", -1.0))
	var y := float(dados.get("y", -1.0))
	if nivel_recebido < NIVEL_MINIMO or nivel_recebido > NIVEL_MAXIMO:
		return false
	if experiencia_recebida < 0 or experiencia_recebida > LIMITE_ESTADO:
		return false
	if vida_maxima_recebida < 1 or vida_maxima_recebida > LIMITE_ESTADO:
		return false
	if mana_maxima_recebida < 0 or mana_maxima_recebida > LIMITE_ESTADO:
		return false
	if x < 0.0 or y < 0.0 or x > 2400.0 or y > 1600.0:
		return false

	uid = uid_recebido
	personagem_id = str(dados.get("personagemId", uid))
	nome = str(dados.get("nome", "Aventureiro")).strip_edges()
	if nome.is_empty():
		nome = "Aventureiro"
	nivel = nivel_recebido
	experiencia = experiencia_recebida
	vida_maxima = vida_maxima_recebida
	vida = clampi(int(dados.get("vida", vida_maxima)), 0, vida_maxima)
	mana_maxima = mana_maxima_recebida
	mana = clampi(int(dados.get("mana", mana_maxima)), 0, mana_maxima)
	forca = _atributo_valido(dados, "forca")
	inteligencia = _atributo_valido(dados, "inteligencia")
	agilidade = _atributo_valido(dados, "agilidade")
	vitalidade = _atributo_valido(dados, "vitalidade")
	espirito = _atributo_valido(dados, "espirito")
	ponto_mundo_id = str(dados.get("pontoMundoId", "clareira_inicial"))
	posicao_mundo = Vector2(x, y)
	aparencia_id = str(dados.get("aparenciaId", ""))
	sexo = str(dados.get("sexo", ""))
	raca_id = str(dados.get("racaId", ""))
	classe_id = str(dados.get("classeId", ""))
	afinidades_fisicas = dados.get("afinidadesFisicas", [])
	afinidades_magicas = dados.get("afinidadesMagicas", [])
	anatomia_racial = dados.get("anatomiaRacial", {})
	revisao_servidor = maxi(0, int(dados.get("revisaoServidor", 0)))
	return true

func _atributo_valido(dados: Dictionary, chave: String) -> int:
	return clampi(int(dados.get(chave, 5)), 0, 1_000_000)

func criar_snapshot_local() -> Dictionary:
	return {
		"uid": uid,
		"personagemId": personagem_id,
		"nome": nome,
		"nivel": nivel,
		"experiencia": experiencia,
		"vida": vida,
		"vidaMaxima": vida_maxima,
		"mana": mana,
		"manaMaxima": mana_maxima,
		"forca": forca,
		"inteligencia": inteligencia,
		"agilidade": agilidade,
		"vitalidade": vitalidade,
		"espirito": espirito,
		"pontoMundoId": ponto_mundo_id,
		"x": posicao_mundo.x,
		"y": posicao_mundo.y,
		"aparenciaId": aparencia_id,
		"sexo": sexo, "racaId": raca_id, "classeId": classe_id,
		"afinidadesFisicas": afinidades_fisicas, "afinidadesMagicas": afinidades_magicas,
		"anatomiaRacial": anatomia_racial,
		"revisaoServidor": revisao_servidor
	}
