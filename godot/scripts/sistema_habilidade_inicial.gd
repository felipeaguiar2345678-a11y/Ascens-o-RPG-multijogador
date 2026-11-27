extends RefCounted
class_name SistemaHabilidadeInicial

## Geração procedural no servidor, sem API paga. Combina classe, raça e afinidades.
## O resultado é fraco de propósito e persistido uma única vez.

const NOMES_ACAO := {
	"fisica":["Golpe","Investida","Corte","Impacto","Estocada","Rasante","Punho"],
	"magica":["Faísca","Pulso","Projétil","Sopro","Marca","Orbe","Fragmento"],
	"suporte":["Bênção","Amparo","Véu","Toque","Selo","Restauração"],
	"defesa":["Guarda","Bloqueio","Postura","Aparar","Muralha"]
}
const PREFIXOS_RACIAIS := {
	"humano":["Improvisado","Versátil","Despertar"], "elfo":["Élfico","Sussurro","Folha"],
	"anao":["Rúnico","Forjado","Pedra"], "orc":["Brutal","Feral","Ancestral"],
	"fera":["Instintivo","Predador","Selvagem"], "draconiano":["Dracônico","Escama","Ígneo"],
	"silvestre":["Silvestre","Raiz","Orvalho"], "umbral":["Umbral","Crepuscular","Abissal"]
}
const NOMES_ELEMENTAIS := {
	"fogo":["Brasa","Chama","Centelha"], "gelo":["Geada","Estilhaço","Neve"],
	"relampago":["Faísca","Trovão","Arco"], "vento":["Rajada","Sopro","Vendaval"],
	"natureza":["Broto","Espinho","Seiva"], "terra":["Lasca","Fragmento","Abalo"],
	"sombra":["Vulto","Penumbra","Eclipse"], "luz":["Clarão","Aurora","Lume"],
	"cura":["Alento","Pulso Vital","Consolo"], "vida":["Seiva Vital","Renovo","Sopro Vital"],
	"arcano":["Éter","Runas","Mistério"], "energia":["Chi","Fluxo","Vibração"],
	"lua":["Luar","Crescente","Maré Lunar"], "vazio":["Vácuo","Fenda","Eco"],
	"runa":["Glifo","Selo","Inscrição"], "invocacao":["Vínculo","Chamado","Eco"],
	"espiritos":["Espírito","Sopro Anímico","Eco"], "barreira":["Guarda","Cúpula","Manto"]
}
const ELEMENTO_VISUAL := {
	"relampago":"raio","natureza":"terra","cura":"luz","vida":"luz",
	"energia":"arcano","lua":"luz","vazio":"gravidade","runa":"arcano",
	"invocacao":"arcano","espiritos":"arcano","barreira":"luz"
}
const CLASSES_MAGICAS := ["mago"]
const CLASSES_SUPORTE := ["curandeiro"]
const MULTIPLICADOR_INICIAL := 1.08
const CUSTO_MANA_INICIAL := 3

static func gerar(perfil: Dictionary, identidade: String) -> Dictionary:
	var raca := str(perfil.get("racaId",""))
	var classe := str(perfil.get("classeId",""))
	if raca.is_empty() or classe.is_empty(): return {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	rng.seed = absi(hash(identidade + str(Time.get_ticks_usec()))) + 1
	var fisica: Array = perfil.get("afinidadesFisicas",[])
	var magica: Array = perfil.get("afinidadesMagicas",[])
	var categoria := _categoria(classe, fisica, magica, rng)
	var afinidades: Array = fisica if categoria in ["fisica", "defesa"] else magica
	if afinidades.is_empty(): afinidades = fisica if not fisica.is_empty() else magica
	if afinidades.is_empty(): afinidades = ["arcano"]
	var elemento := str(afinidades[rng.randi_range(0, afinidades.size()-1)])
	var prefixos: Array = PREFIXOS_RACIAIS.get(raca,["Despertar"])
	var acoes: Array = NOMES_ACAO.get(categoria,NOMES_ACAO["magica"])
	var elementos: Array = NOMES_ELEMENTAIS.get(elemento,[elemento.capitalize()])
	var nome := "%s %s %s" % [str(prefixos[rng.randi_range(0,prefixos.size()-1)]),str(elementos[rng.randi_range(0,elementos.size()-1)]),str(acoes[rng.randi_range(0,acoes.size()-1)])]
	var concede_acao_extra := _classe_pode_conceder_acao_extra(classe) and rng.randf() < 0.25
	var descricao := "Uma habilidade inicial de %s, moldada pela afinidade de %s e pela tradição %s. Seu poder ainda é modesto, mas pode evoluir com o personagem." % [("uma técnica defensiva inicial" if categoria == "defesa" else ("um movimento físico simples" if categoria == "fisica" else ("uma técnica inicial de apoio" if categoria == "suporte" else ("um vínculo de invocação inicial" if categoria == "invocacao" else "uma pequena manifestação elemental")))),elemento,raca]
	if concede_acao_extra:
		descricao += " Esta técnica concede uma ação adicional antes da resposta dos inimigos."
	return {
		"id":"inicial_" + str(hash(identidade + nome + str(rng.randi()))),
		"nome":nome,"descricao":descricao,"classeOrigem":classe,"racaOrigem":raca,
		"categoria":categoria,"elemento":str(ELEMENTO_VISUAL.get(elemento,elemento)),
		"afinidadeOriginal":elemento,"raridade":"comum","nivel":1,"poderBase":1,
		"multiplicadorDano":MULTIPLICADOR_INICIAL,
		"custoMana":CUSTO_MANA_INICIAL if categoria != "fisica" else 0,
		"alcance":"curto" if categoria == "fisica" else "medio",
		"efeito":"defesa" if categoria == "defesa" else ("cura" if categoria == "suporte" else ("invocacao" if categoria == "invocacao" else "impacto_leve")),
		"alvo":"proprio" if categoria == "defesa" else ("aliado" if categoria == "suporte" else "inimigo"),
		"habilidadeInicial":true,"evoluivel":true,"concedeAcaoExtra":concede_acao_extra
	}

static func _classe_pode_conceder_acao_extra(classe: String) -> bool:
	return classe in ["assassino", "assassin"]

static func _categoria(classe: String, fisica: Array, magica: Array, rng: RandomNumberGenerator) -> String:
	if CLASSES_SUPORTE.has(classe): return "suporte"
	if classe == "invocador": return "invocacao"
	if CLASSES_MAGICAS.has(classe): return "magica"
	if classe in ["assassino", "assassin"]: return "fisica" if rng.randf() < 0.7 else "magica"
	if classe == "cavaleiro": return "defesa"
	if classe in ["arqueiro","monge","guerreiro"]: return "fisica"
	if fisica.is_empty() and not magica.is_empty(): return "magica"
	if magica.is_empty() and not fisica.is_empty(): return "fisica"
	return "magica" if rng.randf() < 0.5 else "fisica"
