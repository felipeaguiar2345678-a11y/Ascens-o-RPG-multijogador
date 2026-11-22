extends SceneTree

const Visual = preload("res://scripts/criatura_errante_visual.gd")

func _initialize() -> void:
	var lider := Visual.new()
	lider.configurar({
		"id":"lider_visual_teste",
		"nome":"Sentinela",
		"lider":true,
		"titulo":"Líder do grupo",
		"auraLider":true,
		"identidadeVisual":{
			"tipo":"lider_comum",
			"padraoCorporal":"listras de liderança",
			"marcaDistintiva":"marca na testa",
			"aderecoNatural":"crista elevada",
			"auraAtiva":true,
			"auraTipo":"halo pulsante",
			"auraCor":"#75D6C6",
			"auraIntensidade":1.0,
			"auraEscala":1.0
		}
	})
	root.add_child(lider)
	if not lider.aura_lider or lider.identidade_visual.is_empty():
		_falhar("O líder comum não recebeu a aura e a identidade visual.")
		return
	if not lider.eh_lider:
		_falhar("O marcador visual não reconheceu a liderança.")
		return
	lider.definir_lider(false)
	if lider.aura_lider:
		_falhar("A aura deve desaparecer quando o indivíduo deixa de ser líder.")
		return
	lider.definir_lider(true, {"auraAtiva":true,"auraCor":"#F2A65A","auraIntensidade":1.35,"auraEscala":1.25})
	if not lider.aura_lider or str(lider.identidade_visual.get("auraCor", "")) != "#F2A65A":
		_falhar("A identidade visual não foi atualizada após sucessão.")
		return
	await process_frame
	print("TESTE VISUAL DE LÍDERES E AURAS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE VISUAL DE LÍDERES E AURAS: " + mensagem)
	quit(1)
