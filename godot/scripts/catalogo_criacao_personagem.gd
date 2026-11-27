extends RefCounted
class_name CatalogoCriacaoPersonagem

## Opções iniciais validadas pelo servidor. Os modificadores são aplicados uma única vez.
const APARENCIAS := {
	"masculino": ["masc_cabelo_curto", "masc_cabelo_longo", "masc_trancas", "masc_careca", "masc_cabelo_prateado", "masc_cabelo_ruivo", "masc_cicatriz", "masc_elmo_leve"],
	"feminino": ["fem_cabelo_longo", "fem_cabelo_curto", "fem_trancas", "fem_rabo_cavalo", "fem_cabelo_prateado", "fem_cabelo_ruivo", "fem_cicatriz", "fem_cor_de_lua"]
}
const RACAS := {
	"humano": {"nome":"Humano", "descricao":"Versátil e adaptável; aprende qualquer caminho.", "mods":{"forca":1,"inteligencia":1,"agilidade":1,"vitalidade":1,"espirito":1}, "fisica":["adaptabilidade"], "magica":["adaptabilidade"]},
	"elfo": {"nome":"Elfo", "descricao":"Ágil, perceptivo e ligado à magia natural.", "mods":{"forca":-1,"inteligencia":2,"agilidade":3,"vitalidade":-1,"espirito":2}, "fisica":["arco","precisao","evasao"], "magica":["natureza","vento","luz"]},
	"anao": {"nome":"Anão", "descricao":"Robusto, resistente e talentoso com metal.", "mods":{"forca":3,"inteligencia":0,"agilidade":-1,"vitalidade":3,"espirito":0}, "fisica":["machado","martelo","resistencia"], "magica":["terra","runa"]},
	"orc": {"nome":"Orc", "descricao":"Força brutal e grande resistência física.", "mods":{"forca":4,"inteligencia":-1,"agilidade":0,"vitalidade":3,"espirito":-1}, "fisica":["machado","impacto","intimidacao"], "magica":["fogo"]},
	"fera": {"nome":"Fera", "descricao":"Instintos aguçados, velocidade e sentidos superiores.", "mods":{"forca":2,"inteligencia":-1,"agilidade":4,"vitalidade":1,"espirito":0}, "fisica":["garras","velocidade","rastreamento"], "magica":["lua","natureza"]},
	"draconiano": {"nome":"Draconiano", "descricao":"Sangue ancestral com vigor e afinidade elemental.", "mods":{"forca":3,"inteligencia":1,"agilidade":0,"vitalidade":2,"espirito":2}, "fisica":["armas_pesadas","resistencia","sopro"], "magica":["fogo","relampago"]},
	"silvestre": {"nome":"Silvestre", "descricao":"Espírito da floresta, cura e conexão natural.", "mods":{"forca":-1,"inteligencia":2,"agilidade":2,"vitalidade":0,"espirito":4}, "fisica":["arco","evasao"], "magica":["natureza","cura","vida"]},
	"umbral": {"nome":"Umbral", "descricao":"Afinidade com sombras, percepção e magia proibida.", "mods":{"forca":0,"inteligencia":3,"agilidade":2,"vitalidade":-1,"espirito":3}, "fisica":["adagas","furtividade"], "magica":["sombra","morte","vazio"]},
	"gigante": {"nome":"Gigante", "descricao":"Colosso de resistência extraordinária: possui muita vida e defesa, mas se move e ataca mais devagar.", "mods":{"forca":4,"inteligencia":-1,"agilidade":-2,"vitalidade":5,"espirito":-1}, "fisica":["armas_pesadas","impacto","resistencia","desequilibrio"], "magica":["terra"]}
}
const CLASSES := {
	"guerreiro":{"nome":"Guerreiro","descricao":"Combate corpo a corpo e proteção.", "mods":{"forca":3,"inteligencia":-1,"agilidade":1,"vitalidade":2,"espirito":-1},"fisica":["espada","machado","escudo","armadura"],"magica":[]},
	"espadachim":{"nome":"Espadachim","descricao":"Mestre absoluto das espadas; transforma técnica, precisão e sequência de cortes em poder.", "mods":{"forca":2,"inteligencia":0,"agilidade":3,"vitalidade":0,"espirito":1},"fisica":["espadas","katanas","sabres","montantes","floretes","espadas_duplas","cortes","precisao","combos"],"magica":["lamina_energizada"],"afinidadeArmas":["espada","katana","sabre","montante","florete","nodachi","bengala_espada","espada_negra","espada_viva","espada_zou","par_de_espadas","conjunto_santoryu"],"passivas":["maestria_das_laminas","corte_preciso","fluxo_da_espada","lamina_dominante","instinto_do_espadachim"]},
	"cavaleiro":{"nome":"Cavaleiro","descricao":"Defesa, disciplina e armas pesadas.", "mods":{"forca":2,"inteligencia":0,"agilidade":-1,"vitalidade":4,"espirito":0},"fisica":["lanca","escudo","armadura","montaria"],"magica":[]},
	"assassino":{"nome":"Assassino","descricao":"Precisão, velocidade e ataques críticos.", "mods":{"forca":1,"inteligencia":1,"agilidade":4,"vitalidade":-1,"espirito":0},"fisica":["adagas","furtividade","critico","evasao"],"magica":["sombra"]},
	"arqueiro":{"nome":"Arqueiro","descricao":"Ataques à distância, mira e mobilidade.", "mods":{"forca":0,"inteligencia":1,"agilidade":4,"vitalidade":0,"espirito":1},"fisica":["arco","precisao","evasao"],"magica":["vento"]},
	"mago":{"nome":"Mago","descricao":"Grande poder arcano e variedade elemental.", "mods":{"forca":-2,"inteligencia":4,"agilidade":0,"vitalidade":-1,"espirito":3},"fisica":[],"magica":["fogo","gelo","relampago","arcano"]},
	"curandeiro":{"nome":"Curandeiro","descricao":"Restauração, proteção e suporte mágico.", "mods":{"forca":-1,"inteligencia":2,"agilidade":0,"vitalidade":1,"espirito":4},"fisica":[],"magica":["cura","luz","vida","barreira"]},
	"monge":{"nome":"Monge","descricao":"Disciplina corporal e energia interior.", "mods":{"forca":2,"inteligencia":1,"agilidade":2,"vitalidade":1,"espirito":2},"fisica":["punhos","combate_desarmado","evasao"],"magica":["energia","chi"]},
	"invocador":{"nome":"Invocador","descricao":"Vínculos, espíritos e criaturas conjuradas.", "mods":{"forca":-1,"inteligencia":3,"agilidade":0,"vitalidade":0,"espirito":4},"fisica":[],"magica":["invocacao","espiritos","vinculo","arcano"]}
}
## Anatomia é dado de personagem, não apenas cosmético: a cena visual usará estes traços
## para montar silhueta, proporções e partes raciais.
const ANATOMIA_RACAS := {
	"humano": {"descricao":"Anatomia humana comum, proporções equilibradas e sem traços raciais extraordinários.", "altura":1.0,"porte":"medio","orelhas":"humanas","chifres":"nenhum","asas":"nenhuma","cauda":"nenhuma","pele":"humana","marcas":["nenhuma"]},
	"elfo": {"descricao":"Corpo esguio, orelhas longas e pontudas e traços delicados.", "altura":1.02,"porte":"esguio","orelhas":"elficas_pontudas","chifres":"nenhum","asas":"nenhuma","cauda":"nenhuma","pele":"variada","marcas":["nenhuma"]},
	"anao": {"descricao":"Baixa estatura, corpo compacto, ombros largos e musculatura densa.", "altura":0.72,"porte":"baixo_robusto","orelhas":"curtas","chifres":"nenhum","asas":"nenhuma","cauda":"nenhuma","pele":"variada","marcas":["barba_opcional"]},
	"orc": {"descricao":"Grande estatura, musculatura volumosa, presas inferiores e mandíbula forte.", "altura":1.12,"porte":"muito_forte","orelhas":"orc","chifres":"variavel","asas":"nenhuma","cauda":"nenhuma","pele":"tons_orc","marcas":["presas"]},
	"fera": {"descricao":"Traços animais, orelhas bestiais, garras e cauda; espécie visual pode variar.", "altura":1.0,"porte":"atletico","orelhas":"bestiais","chifres":"variavel","asas":"nenhuma","cauda":"bestial","pele":"pelagem_ou_escamas","marcas":["garras"]},
	"draconiano": {"descricao":"Escamas, chifres e asas dracônicas; silhueta ancestral imponente.", "altura":1.08,"porte":"robusto","orelhas":"draconicas","chifres":"draconicos","asas":"draconicas_recolhidas","cauda":"draconica","pele":"escamas","marcas":["escamas_visiveis","olhos_reptilianos"]},
	"silvestre": {"descricao":"Traços feéricos e naturais, orelhas levemente alongadas e marcas vegetais.", "altura":0.98,"porte":"leve","orelhas":"alongadas","chifres":"galhos_opcionais","asas":"nenhuma","cauda":"nenhuma","pele":"variada","marcas":["marcas_folhas"]},
	"umbral": {"descricao":"Pele de tons sombrios, olhos luminosos e marcas arcanas discretas.", "altura":1.0,"porte":"esguio","orelhas":"pontudas_sutis","chifres":"sombrios_opcionais","asas":"sombrias_opcionais","cauda":"nenhuma","pele":"tons_umbral","marcas":["runa_sombria","olhos_luminosos"]},
	"gigante": {"descricao":"Anatomia colossal, muito alta e larga, com musculatura densa e passos pesados.", "altura":1.35,"porte":"colossal","orelhas":"humanas","chifres":"nenhum","asas":"nenhuma","cauda":"nenhuma","pele":"variada","marcas":["musculatura_colossal"]}
}
const ATRIBUTOS := ["forca","inteligencia","agilidade","vitalidade","espirito"]

static func opcoes_aparencia(sexo: String) -> Array:
	return APARENCIAS.get(sexo, []).duplicate()

static func validar(sexo: String, aparencia: String, raca: String, classe: String) -> bool:
	return APARENCIAS.has(sexo) and APARENCIAS[sexo].has(aparencia) and RACAS.has(raca) and CLASSES.has(classe)

static func montar_perfil(sexo: String, aparencia: String, raca: String, classe: String) -> Dictionary:
	if not validar(sexo, aparencia, raca, classe):
		return {}
	var atributos := {"forca":5,"inteligencia":5,"agilidade":5,"vitalidade":5,"espirito":5}
	for origem in [RACAS[raca]["mods"], CLASSES[classe]["mods"]]:
		for atributo in ATRIBUTOS:
			atributos[atributo] = maxi(1, int(atributos[atributo]) + int(origem.get(atributo, 0)))
	var vida_maxima := 80 + int(atributos["vitalidade"]) * 12
	var multiplicador_vida := 1.25 if raca == "gigante" else 1.0
	vida_maxima = int(round(vida_maxima * multiplicador_vida))
	var mana_maxima := 30 + int(atributos["espirito"]) * 10 + int(atributos["inteligencia"]) * 3
	return {
		"sexo":sexo,"aparenciaId":aparencia,"racaId":raca,"racaNome":RACAS[raca]["nome"],
		"classeId":classe,"classeNome":CLASSES[classe]["nome"],
		"descricaoRaca":RACAS[raca]["descricao"],"descricaoClasse":CLASSES[classe]["descricao"],
		"anatomiaRacial":ANATOMIA_RACAS[raca].duplicate(true),
		"afinidadesFisicas":_unir(RACAS[raca]["fisica"],CLASSES[classe]["fisica"]),
		"afinidadesMagicas":_unir(RACAS[raca]["magica"],CLASSES[classe]["magica"]),
		"forca":atributos["forca"],"inteligencia":atributos["inteligencia"],
		"agilidade":atributos["agilidade"],"vitalidade":atributos["vitalidade"],
		"espirito":atributos["espirito"],"vidaMaxima":vida_maxima,"vida":vida_maxima,
		"manaMaxima":mana_maxima,"mana":mana_maxima,
		"defesaPercentual":120 if raca == "gigante" else 100,
		"velocidadePercentual":88 if raca == "gigante" else 100,
		"velocidadeAtaquePercentual":92 if raca == "gigante" else 100
	}

static func _unir(a: Array, b: Array) -> Array:
	var resultado: Array = a.duplicate()
	for item in b:
		if not resultado.has(item):
			resultado.append(item)
	return resultado
