extends CharacterBody2D

@export var velocidade: float = 205.0
@export var distancia_seguimento: float = 28.0
var alvo: Node2D
var dados_companheiro: Dictionary = {}

func configurar_companheiro(dados: Dictionary) -> void:
	dados_companheiro = dados.duplicate(true)
	var corpo := get_node_or_null("CorpoProvisorio") as Polygon2D
	var caminho := str(dados_companheiro.get("iconePath", dados_companheiro.get("detalhePath", "")))
	if caminho.begins_with("res://") and ResourceLoader.exists(caminho):
		var recurso = load(caminho)
		if recurso is Texture2D:
			if corpo != null:
				corpo.visible = false
			var sprite := Sprite2D.new()
			sprite.name = "VisualCompanheiro"
			sprite.texture = recurso
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(0.65, 0.65)
			add_child(sprite)
	else:
		if corpo != null:
			corpo.color = _cor_da_raridade(str(dados_companheiro.get("raridade", "comum")))
			corpo.scale = Vector2.ONE * clampf(1.0 + float(int(dados_companheiro.get("nivel", 1)) - 1) * 0.015, 1.0, 1.35)
	velocidade = clampf(165.0 + float(dados_companheiro.get("agilidade", 5)) * 1.2, 170.0, 330.0)
	distancia_seguimento = clampf(25.0 + float(dados_companheiro.get("nivel", 1)) * 0.15, 25.0, 44.0)

func _cor_da_raridade(raridade: String) -> Color:
	match raridade.to_lower():
		"comum": return Color("#a9c39a")
		"incomum": return Color("#7ed39b")
		"raro": return Color("#72b7ed")
		"epico", "épico": return Color("#bd91f0")
		"lendario", "lendária": return Color("#f0c36a")
		"mitico", "mítico", "ancestral": return Color("#ed8fcb")
		"unico", "único", "supremo": return Color("#ff8b73")
		_: return Color("#a9c39a")

func configurar_alvo(novo_alvo: Node2D) -> void:
	alvo = novo_alvo

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(alvo):
		velocity = Vector2.ZERO
		return
	var deslocamento := alvo.global_position - global_position
	if deslocamento.length() > distancia_seguimento:
		velocity = deslocamento.normalized() * velocidade
	else:
		velocity = Vector2.ZERO
	move_and_slide()
