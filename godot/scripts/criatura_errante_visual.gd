extends Node2D
## Marcador provisório para criaturas persistentes; será substituído pelo sprite gerado.

var nome_criatura := "Criatura"
var eh_chefe := false
var eh_lider := false
var esta_morta := false
var mutacoes: Array = []
var comportamento := "vagando"
var identidade_visual: Dictionary = {}
var aura_lider := false
var titulo_lider := ""
var _tempo_animacao := 0.0

func configurar(dados: Dictionary) -> void:
	nome_criatura = str(dados.get("nome", "Criatura"))
	eh_chefe = bool(dados.get("chefe", false))
	eh_lider = bool(dados.get("lider", false))
	esta_morta = bool(dados.get("morto", false))
	mutacoes = dados.get("mutacoes", []).duplicate(true)
	comportamento = str(dados.get("comportamento", "vagando"))
	identidade_visual = dados.get("identidadeVisual", {}).duplicate(true)
	aura_lider = bool(dados.get("auraLider", eh_lider))
	titulo_lider = str(dados.get("titulo", ""))
	queue_redraw()
	_atualizar_nome()

func definir_posicao_mundo(posicao: Vector2) -> void:
	global_position = posicao

func definir_comportamento(novo_comportamento: String) -> void:
	comportamento = novo_comportamento
	_atualizar_nome()

func definir_lider(valor: bool, visual: Dictionary = {}) -> void:
	eh_lider = valor
	if not visual.is_empty():
		identidade_visual = visual.duplicate(true)
	aura_lider = eh_lider and bool(identidade_visual.get("auraAtiva", false))
	_atualizar_nome()
	queue_redraw()

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
	rotulo.text = nome_criatura + (" †" if esta_morta else (" ★" if eh_chefe else (" ♛" if eh_lider else ""))) + (" ✧" if not mutacoes.is_empty() else "") + (" · " + titulo_lider if eh_lider and not titulo_lider.is_empty() else "") + " " + ("morta" if esta_morta else str(simbolos.get(comportamento, "·")) )

func _draw() -> void:
	var pulsacao := 1.0 + sin(_tempo_animacao * 2.0) * 0.06
	var cor := Color("#514b49") if esta_morta else (Color("#b64c38") if eh_chefe else (Color("#d7b45b") if eh_lider else Color("#777c63")))
	if not mutacoes.is_empty():
		cor = Color("#9b65bd")
	if eh_lider and not esta_morta:
		_desenhar_aura_lider(pulsacao)
	# Silhueta-base do indivíduo.
	draw_circle(Vector2.ZERO, (13.0 if eh_chefe else 8.0) * pulsacao, Color("#1a1716", 0.8))
	draw_circle(Vector2.ZERO, (10.0 if eh_chefe else 6.0) * pulsacao, cor)
	if eh_lider and not esta_morta:
		_desenhar_marcas_lider(cor)
	if not esta_morta:
		draw_circle(Vector2(-2, -2), 2.0, Color("#f3d8a0"))
	else:
		draw_line(Vector2(-4, -4), Vector2(4, 4), Color("#d8c5b7"), 2.0)
		draw_line(Vector2(4, -4), Vector2(-4, 4), Color("#d8c5b7"), 2.0)

func _desenhar_aura_lider(pulsacao: float) -> void:
	if not aura_lider:
		return
	var cor_aura := Color(str(identidade_visual.get("auraCor", "#e7c46a")))
	var intensidade := clampf(float(identidade_visual.get("auraIntensidade", 1.0)), 0.5, 2.0)
	var escala := clampf(float(identidade_visual.get("auraEscala", 1.0)), 0.7, 1.8)
	var raio := 17.0 * escala * pulsacao
	var cor_externa := Color(cor_aura, 0.10 * intensidade)
	var cor_interna := Color(cor_aura, 0.22 * intensidade)
	draw_circle(Vector2.ZERO, raio, cor_externa)
	draw_arc(Vector2.ZERO, raio, _tempo_animacao * 0.45, _tempo_animacao * 0.45 + TAU * 0.88, 40, Color(cor_aura, 0.82), 1.8, true)
	draw_arc(Vector2.ZERO, raio * 0.72, -_tempo_animacao * 0.7, -_tempo_animacao * 0.7 + TAU * 0.62, 32, Color(cor_aura, 0.55), 1.2, true)
	for i in range(6):
		var angulo := _tempo_animacao * 0.8 + TAU * float(i) / 6.0
		var distancia := raio + sin(_tempo_animacao * 2.2 + float(i)) * 3.0
		var ponto := Vector2(cos(angulo), sin(angulo)) * distancia
		draw_circle(ponto, 1.5 * intensidade, Color(cor_aura, 0.9))
	if str(identidade_visual.get("auraTipo", "")) == "faíscas":
		for i in range(4):
			var angulo_faisca := -_tempo_animacao * 1.3 + TAU * float(i) / 4.0
			draw_line(Vector2(cos(angulo_faisca), sin(angulo_faisca)) * (raio * 0.55), Vector2(cos(angulo_faisca), sin(angulo_faisca)) * (raio * 0.9), Color(cor_aura, 0.85), 1.4)
	elif str(identidade_visual.get("auraTipo", "")) == "brasa":
		for i in range(3):
			var angulo_brasa := _tempo_animacao + TAU * float(i) / 3.0
			var ponto_brasa := Vector2(cos(angulo_brasa), sin(angulo_brasa)) * (raio * 0.82)
			draw_circle(ponto_brasa + Vector2(0, -sin(_tempo_animacao * 2.0 + i) * 3.0), 1.8, cor_interna)

func _desenhar_marcas_lider(cor_base: Color) -> void:
	var marca := str(identidade_visual.get("marcaDistintiva", ""))
	var padrao := str(identidade_visual.get("padraoCorporal", ""))
	var adereco := str(identidade_visual.get("aderecoNatural", ""))
	var destaque := Color("#f6e4a6")
	# As formas são detalhes sobrepostos à cor original, sem trocar a espécie.
	if "olhos" in padrao or "facial" in marca or "testa" in marca:
		draw_circle(Vector2(0, -4), 2.0, destaque)
	elif "listras" in padrao or "faixa" in padrao:
		draw_line(Vector2(-4, -1), Vector2(4, -1), destaque, 1.5)
	elif "manchas" in padrao or "escamas" in padrao:
		draw_circle(Vector2(-3, 1), 1.5, destaque)
		draw_circle(Vector2(3, 1), 1.5, destaque)
	else:
		draw_arc(Vector2.ZERO, 4.5, 3.4, 5.9, 12, destaque, 1.4, true)
	if "crista" in adereco or "juba" in adereco or "penas" in adereco or "chifres" in adereco:
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -5), Vector2(0, -12), Vector2(4, -5)]), Color(cor_base).lightened(0.55))
	elif "cauda" in adereco:
		draw_line(Vector2(5, 2), Vector2(10, 6), destaque, 2.0)
	elif "pontas" in marca or "brilhantes" in marca:
		draw_circle(Vector2(0, -7), 1.8, destaque)
