extends SceneTree

const Apresentacao = preload("res://scripts/apresentacao_arma.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var arma := Apresentacao.new()
	root.add_child(arma)
	await process_frame
	if not is_instance_valid(arma.sprite_arma):
		_falhar("O sprite da arma não foi inicializado.")
		return
	arma.configurar("kikoku", "frente")
	if Apresentacao.obter_caminho_miniatura("kikoku") != "res://assets/armas/inventario/kikoku.png":
		_falhar("A Kikoku não aponta para a miniatura oficial do inventário.")
		return
	if not Apresentacao.CATALOGO_VISUAL.has("gryphon") or not Apresentacao.CATALOGO_VISUAL.has("murakumogiri"):
		_falhar("Faltam entradas visuais das armas de Law, Shanks ou Barba Branca.")
		return
	arma.definir_direcao("esquerda")
	if arma.direcao != "esquerda":
		_falhar("A apresentação não aceitou orientação lateral.")
		return
	arma.configurar("arma_sem_arte", "costas")
	if arma.sprite_arma.visible:
		_falhar("Uma arma sem textura final não pode exibir um placeholder.")
		return
	print("TESTE APRESENTAÇÃO DE ARMAS: catálogo, miniatura, orientação e ausência de placeholder aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE APRESENTAÇÃO DE ARMAS: " + mensagem)
	quit(1)
