extends Node2D
## Marcador provisório para criaturas persistentes; será substituído pelo sprite gerado.

var nome_criatura := "Criatura"
var eh_chefe := false
var mutacoes: Array = []
var comportamento := "vagando"
var _tempo_animacao := 0.0

func configurar(dados: Dictionary) -> void:
	nome_criatura = str(dados.get("nome", "Criatura"))
	eh_chefe = bool(dados.get("chefe", false))
	mutacoes = dados.get("mutacoes", []).duplicate(true)
	comportamento = str(dados.get("comportamento", "vagando"))
	queue_redraw()
	_atualizar_nome()

func definir_posicao_mundo(posicao: Vector2) -> void:
	global_position = posicao

func definir_comportamento(novo_comportamento: String) -> void:
	comportamento = novo_comportamento
	_atualizar_nome()

func _ready() -> void:
	_atualizar_nome()

func _process(delta: float) -> void:
	_tempo_animacao += delta
	queue_redraw()

func _atualizar_nome() -> void:
	var rotulo := get_node_or_null("Nome")
	if rotulo == null:
		rotulo = Label.new()
		rotulo.name = "Nome"
		rotulo.position = Vector2(-65, -42)
		rotulo.add_theme_font_size_override("font_size", 10)
		rotulo.add_theme_color_override("font_color", Color("#f5e6c8"))
		rotulo.add_theme_color_override("font_shadow_color", Color("#17120e"))
		rotulo.add_theme_constant_override("shadow_offset_x", 1)
		rotulo.add_theme_constant_override("shadow_offset_y", 1)
		add_child(rotulo)
	var simbolos := {"vagando":"·","fugindo":"!","cacando":"⚔","buscando_habitat":"⌂","defendendo_territorio":"◆"}
	rotulo.text = nome_criatura + (" ★" if eh_chefe else "") + (" ✧" if not mutacoes.is_empty() else "") + " " + str(simbolos.get(comportamento, "·"))

func _draw() -> void:
	var pulsacao := 1.0 + sin(_tempo_animacao * 2.0) * 0.06
	var cor := Color("#b64c38") if eh_chefe else Color("#777c63")
	if not mutacoes.is_empty():
		cor = Color("#9b65bd")
	draw_circle(Vector2.ZERO, (13.0 if eh_chefe else 8.0) * pulsacao, Color("#1a1716", 0.8))
	draw_circle(Vector2.ZERO, (10.0 if eh_chefe else 6.0) * pulsacao, cor)
	draw_circle(Vector2(-2, -2), 2.0, Color("#f3d8a0"))
