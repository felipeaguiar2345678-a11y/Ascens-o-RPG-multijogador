extends RefCounted
class_name SistemaInvocacoes

## Progressão de invocações vinculadas ao personagem. Todas as decisões são executadas no servidor.
const FORMAS_INICIAIS := [
 {"id":"rato_sombrio","nome":"Rato Sombrio","especie":"rato","vida":24,"ataque":5,"defesa":2,"agilidade":8,"poderMagico":1,"elemento":"sombra"},
 {"id":"esqueleto_errante","nome":"Esqueleto Errante","especie":"esqueleto","vida":30,"ataque":6,"defesa":3,"agilidade":5,"poderMagico":2,"elemento":"osso"},
 {"id":"goblin_jovem","nome":"Goblin Jovem","especie":"goblin","vida":28,"ataque":6,"defesa":2,"agilidade":7,"poderMagico":1,"elemento":"natureza"},
 {"id":"limo_pequeno","nome":"Limo Pequeno","especie":"limo","vida":26,"ataque":4,"defesa":4,"agilidade":3,"poderMagico":3,"elemento":"agua"}
]
const LIMITE_COLECA := 50
const MAX_TENTATIVAS_DOMESTICACAO := 3
const ID_SERPENTE_MUNDO := "serpente_do_mundo"

static func _eh_serpente_do_mundo(criatura: Dictionary) -> bool:
	return str(criatura.get("tipoChefeMundo", "")) == "serpente_mundo" or str(criatura.get("id", "")) in [ID_SERPENTE_MUNDO, "jormungandr", "serpente_mundo"]

static func _criar_filhote_serpente(perfil: Dictionary, criatura: Dictionary) -> Dictionary:
	var vida_chefe := maxi(1, int(criatura.get("vidaMaxima", criatura.get("vida", 1000))))
	var ataque_chefe := maxi(1, int(criatura.get("ataque", 100)))
	var defesa_chefe := maxi(1, int(criatura.get("defesa", 50)))
	var nova := {
		"id":"serpente_filhote_" + str(hash(str(perfil.get("uid", "")) + ":serpente_mundo")),
		"nome":"Serpente Filhote Primordial",
		"especie":"serpente_mundo",
		"criaturaOrigemId":str(criatura.get("id", ID_SERPENTE_MUNDO)),
		"nivel":1,
		"experiencia":0,
		"experienciaProximoNivel":100,
		"vida":maxi(250, int(round(float(vida_chefe) * 0.12))),
		"vidaMaxima":maxi(250, int(round(float(vida_chefe) * 0.12))),
		"ataque":maxi(35, int(round(float(ataque_chefe) * 0.18))),
		"defesa":maxi(25, int(round(float(defesa_chefe) * 0.20))),
		"agilidade":maxi(20, int(round(float(criatura.get("agilidade", 50)) * 0.35))),
		"poderMagico":maxi(30, int(round(float(criatura.get("poderMagico", 50)) * 0.25))),
		"rank":"SSS",
		"raridade":"unico",
		"origem":"filhote_serpente_mundo",
		"donoUid":str(perfil.get("uid", "")),
		"evolucao":0,
		"podeEvoluir":true,
		"crescimentoVisual":"filhote",
		"escalaVisual":0.7,
		"tipoInvocacao":"serpente_mundo"
	}
	return nova

static func _atualizar_crescimento_serpente(invocacao: Dictionary) -> Dictionary:
	var resultado := invocacao.duplicate(true)
	if str(resultado.get("tipoInvocacao", "")) != "serpente_mundo":
		return resultado
	var nivel := maxi(1, int(resultado.get("nivel", 1)))
	var fase := "filhote"
	var escala := 0.7
	if nivel >= 100:
		fase = "colossal"
		escala = 3.0
	elif nivel >= 50:
		fase = "adolescente"
		escala = 2.0
	elif nivel >= 25:
		fase = "jovem"
		escala = 1.4
	elif nivel >= 10:
		fase = "juvenil"
		escala = 1.0
	resultado["crescimentoVisual"] = fase
	resultado["escalaVisual"] = escala
	return resultado

static func gerar_inicial(uid: String) -> Dictionary:
 if uid.strip_edges().is_empty(): return {}
 var rng := RandomNumberGenerator.new()
 rng.seed = absi(hash("invocacao_inicial:" + uid)) + 1
 var base: Dictionary = FORMAS_INICIAIS[rng.randi_range(0, FORMAS_INICIAIS.size() - 1)].duplicate(true)
 base["id"] = "inv_" + str(hash(uid + ":" + str(base["id"])))
 base["nivel"] = 1
 base["experiencia"] = 0
 base["experienciaProximoNivel"] = 100
 base["raridade"] = "comum"
 base["rank"] = "E"
 base["origem"] = "inicial"
 base["donoUid"] = uid
 base["evolucao"] = 0
 base["podeEvoluir"] = true
 return base

static func adicionar_experiencia(invocacao: Dictionary, quantidade: int) -> Dictionary:
 if invocacao.is_empty() or quantidade <= 0 or quantidade > 1000000:
  return {"ok":false,"erro":"Experiência de invocação inválida."}
 var resultado: Dictionary = invocacao.duplicate(true)
 var nivel := clampi(int(resultado.get("nivel", 1)), 1, 10000)
 var xp := maxi(0, int(resultado.get("experiencia", 0))) + quantidade
 var evoluiu := false
 while nivel < 10000 and xp >= nivel * 100:
  xp -= nivel * 100
  nivel += 1
  evoluiu = true
 resultado["nivel"] = nivel
 resultado["experiencia"] = xp
 resultado["experienciaProximoNivel"] = nivel * 100
 if evoluiu:
  resultado["vida"] = int(resultado.get("vida", 20)) + 3
  resultado["vidaMaxima"] = int(resultado.get("vidaMaxima", resultado["vida"] - 3)) + 3
  resultado["ataque"] = int(resultado.get("ataque", 3)) + 1
  resultado["defesa"] = int(resultado.get("defesa", 1)) + 1
  resultado["agilidade"] = int(resultado.get("agilidade", 1)) + 1
 resultado = _atualizar_crescimento_serpente(resultado)
 return {"ok":true,"invocacao":resultado,"subiuNivel":evoluiu}

static func alimentar(invocacao: Dictionary, monstro_derrotado: Dictionary) -> Dictionary:
 if invocacao.is_empty() or monstro_derrotado.is_empty():
  return {"ok":false,"erro":"É necessário informar a invocação e o monstro derrotado."}
 var rank := str(monstro_derrotado.get("rank", "E")).to_upper()
 var ranks := ["E","D","C","B","A","S","SS","SSS"]
 if not ranks.has(rank): return {"ok":false,"erro":"Rank do monstro inválido."}
 var nivel_monstro := clampi(int(monstro_derrotado.get("nivel", 1)), 1, 100000)
 var xp_rank := (ranks.find(rank) + 1) * 10
 var resultado: Dictionary = adicionar_experiencia(invocacao, xp_rank + nivel_monstro * 2)
 if not bool(resultado.get("ok", false)): return resultado
 var criatura: Dictionary = resultado["invocacao"]
 criatura["monstrosConsumidos"] = int(criatura.get("monstrosConsumidos", 0)) + 1
 var evolucao: Dictionary = _verificar_evolucao(criatura)
 resultado["invocacao"] = evolucao.get("invocacao", criatura)
 resultado["evoluiuForma"] = bool(evolucao.get("evoluiuForma", false))
 return resultado

static func _verificar_evolucao(invocacao: Dictionary) -> Dictionary:
 var resultado := invocacao.duplicate(true)
 var especie := str(resultado.get("especie", ""))
 var nivel := int(resultado.get("nivel", 1))
 var forma := int(resultado.get("evolucao", 0))
 if forma > 0 or nivel < 10: return {"invocacao":resultado,"evoluiuForma":false}
 var nomes := {
  "rato":{"nome":"Rato Abissal","id":"rato_abissal","vida":1.35,"ataque":1.5,"defesa":1.25},
  "esqueleto":{"nome":"Cavaleiro Ósseo","id":"cavaleiro_oseo","vida":1.5,"ataque":1.35,"defesa":1.6},
  "goblin":{"nome":"Goblin Caçador","id":"goblin_cacador","vida":1.3,"ataque":1.5,"defesa":1.25},
  "limo":{"nome":"Limo Arcano","id":"limo_arcano","vida":1.4,"ataque":1.3,"defesa":1.5}
 }
 if not nomes.has(especie): return {"invocacao":resultado,"evoluiuForma":false}
 var forma_dados: Dictionary = nomes[especie]
 resultado["nome"] = str(forma_dados["nome"])
 resultado["formaId"] = str(forma_dados["id"])
 resultado["vida"] = int(round(float(resultado.get("vida", 20)) * float(forma_dados["vida"])))
 resultado["ataque"] = int(round(float(resultado.get("ataque", 3)) * float(forma_dados["ataque"])))
 resultado["defesa"] = int(round(float(resultado.get("defesa", 1)) * float(forma_dados["defesa"])))
 resultado["evolucao"] = 1
 resultado["rank"] = "D"
 return {"invocacao":resultado,"evoluiuForma":true}

static func calcular_chance_domesticacao(criatura: Dictionary) -> float:
	var ranks := ["E", "D", "C", "B", "A", "S", "SS", "SSS"]
	var indice := ranks.find(str(criatura.get("rank", "E")).to_upper())
	if indice < 0:
		indice = 0
	var chance := 0.35 - float(indice) * 0.04
	if bool(criatura.get("liderNato", false)):
		chance -= 0.10
	# Chefes podem ser domesticados, mas exigem muito mais sorte.
	if bool(criatura.get("chefe", false)):
		chance *= 0.20
	return clampf(chance, 0.01, 0.35)

static func domesticar(perfil: Dictionary, criatura: Dictionary) -> Dictionary:
	if str(perfil.get("classeId", "")) != "invocador":
		return {"ok":false,"erro":"Somente a classe Invocador pode domesticar criaturas."}
 if not bool(criatura.get("derrotadoEmCombate", false)) and not bool(criatura.get("domesticacaoAposDerrota", false)):
  return {"ok":false,"erro":"A criatura precisa ser derrotada antes da domesticação."}
 var colecao: Array = perfil.get("invocacoes", [])
 var criatura_id: String = str(criatura.get("id", ""))
 if criatura_id.is_empty() or colecao.size() >= LIMITE_COLECA:
  return {"ok":false,"erro":"Não foi possível adicionar essa criatura à coleção."}
 for existente in colecao:
  if str(existente.get("criaturaOrigemId", "")) == criatura_id:
   return {"ok":false,"erro":"Essa criatura já foi domesticada."}
 if _eh_serpente_do_mundo(criatura):
  var filhote := _criar_filhote_serpente(perfil, criatura)
  return {"ok":true,"invocacao":filhote,"chance":calcular_chance_domesticacao(criatura),"mensagem":"A Serpente do Mundo reconheceu seu vínculo. Você recebeu uma Serpente Filhote Primordial!"}
 var nova: Dictionary = {
  "id":"dom_" + str(hash(str(perfil.get("uid","")) + ":" + criatura_id)),
  "nome":str(criatura.get("nome","Criatura domesticada")),
  "especie":str(criatura.get("especieId", criatura.get("familia","criatura"))),
  "criaturaOrigemId":criatura_id,
  "nivel":1,"experiencia":0,"experienciaProximoNivel":100,
  "vida":maxi(10,int(int(criatura.get("vidaMaxima",20)) / 4)),
  "ataque":maxi(2,int(int(criatura.get("ataque",4)) / 4)),
  "defesa":maxi(1,int(int(criatura.get("defesa",2)) / 4)),
  "agilidade":maxi(1,int(int(criatura.get("agilidade",2)) / 4)),
  "poderMagico":maxi(0,int(int(criatura.get("poderMagico",0)) / 4)),
  "rank":str(criatura.get("rank","E")),
  "raridade":str(criatura.get("raridade","comum")),
  "origem":"domesticada","evolucao":0,"podeEvoluir":true
 }
 return {"ok":true,"invocacao":nova}

## Ovos são o caminho de obtenção de companheiros para classes que não são Invocador.
static func chocar_ovo(perfil: Dictionary, ovo: Dictionary) -> Dictionary:
	if str(perfil.get("classeId", "")) == "invocador":
		return {"ok":false,"erro":"Invocadores obtêm criaturas por domesticação, não por ovos."}
	var modelo: Dictionary = ovo.get("modeloCompanheiro", {})
	if modelo.is_empty():
		return {"ok":false,"erro":"Este ovo não possui um companheiro válido definido."}
	var colecao: Array = perfil.get("invocacoes", [])
	if colecao.size() >= LIMITE_COLECA:
		return {"ok":false,"erro":"Sua coleção de companheiros está cheia."}
	var origem_id := str(ovo.get("itemId", "")).strip_edges()
	if origem_id.is_empty():
		return {"ok":false,"erro":"O ovo não possui identificação válida."}
	var especie := str(modelo.get("especieId", modelo.get("especie", "criatura")))
	var companheiro := {
		"id":"ovo_" + str(hash(str(perfil.get("uid", "")) + ":" + origem_id + ":" + str(colecao.size()))),
		"nome":str(modelo.get("nome", "Companheiro recém-nascido")),
		"especie":especie,
		"criaturaOrigemId":str(modelo.get("criaturaOrigemId", especie)),
		"nivel":1,
		"experiencia":0,
		"experienciaProximoNivel":100,
		"vida":maxi(10, int(modelo.get("vida", 30))),
		"vidaMaxima":maxi(10, int(modelo.get("vidaMaxima", modelo.get("vida", 30)))),
		"ataque":maxi(1, int(modelo.get("ataque", 5))),
		"defesa":maxi(1, int(modelo.get("defesa", 3))),
		"agilidade":maxi(1, int(modelo.get("agilidade", 3))),
		"poderMagico":maxi(0, int(modelo.get("poderMagico", 0))),
		"rank":str(modelo.get("rank", "E")),
		"raridade":str(modelo.get("raridade", ovo.get("raridade", "comum"))),
		"origem":"ovo",
		"ovoOrigemId":origem_id,
		"donoUid":str(perfil.get("uid", "")),
		"evolucao":0,
		"podeEvoluir":true
	}
	return {"ok":true,"invocacao":companheiro,"mensagem":"O ovo chocou! Um novo companheiro entrou para sua coleção."}

static func selecionar(perfil: Dictionary, invocacao_id: String) -> bool:
 for invocacao in perfil.get("invocacoes", []):
  if str(invocacao.get("id","")) == invocacao_id:
   perfil["invocacaoAtivaId"] = invocacao_id
   return true
 return false
