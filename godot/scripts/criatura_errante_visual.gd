extends Node2D
## Marcador provisório para criaturas persistentes; será substituído pelo sprite gerado.

signal interacao_solicitada(criatura_id: String)

var id_criatura_mundo := ""
var _area_interacao: Area2D

var nome_criatura := "Criatura"
var eh_chefe := false
var eh_lider := false
var esta_morta := false
var mutacoes: Array = []
var comportamento := "vagando"
var identidade_visual: Dictionary = {}
var aura_lider := false
var titulo_lider := ""
var especie_id := "criatura"
var habitat := ""
var bioma := ""
var _tempo_animacao := 0.0

func configurar(dados: Dictionary) -> void:
	nome_criatura = str(dados.get("nome", "Criatura"))
	id_criatura_mundo = str(dados.get("id", "")).strip_edges()
	especie_id = str(dados.get("especieId", dados.get("especie", dados.get("tipo", "criatura")))).to_lower()
	habitat = str(dados.get("habitat", "")).to_lower()
	bioma = str(dados.get("bioma", "")).to_lower()
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
	_criar_area_interacao()
	_atualizar_nome()

func _criar_area_interacao() -> void:
	_area_interacao = Area2D.new()
	_area_interacao.name = "AreaInteracao"
	_area_interacao.input_pickable = true
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 26.0
	forma.shape = circulo
	_area_interacao.add_child(forma)
	_area_interacao.input_event.connect(_ao_receber_input_area)
	add_child(_area_interacao)

func definir_interacao_habilitada(habilitada: bool) -> void:
	if is_instance_valid(_area_interacao):
		_area_interacao.input_pickable = habilitada

func _ao_receber_input_area(_viewport: Viewport, evento: InputEvent, _indice_forma: int) -> void:
	var acionado := false
	if evento is InputEventMouseButton:
		acionado = evento.button_index == MOUSE_BUTTON_LEFT and evento.pressed
	elif evento is InputEventScreenTouch:
		acionado = evento.pressed
	if acionado and not id_criatura_mundo.is_empty():
		interacao_solicitada.emit(id_criatura_mundo)
		get_viewport().set_input_as_handled()

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
	# Silhuetas variam conforme a espécie/ecologia, em vez de usar um círculo genérico.
	draw_set_transform(Vector2(0.0, sin(_tempo_animacao * 5.0) * 1.4), sin(_tempo_animacao * 3.0) * 0.025, Vector2(pulsacao, pulsacao))
	_desenhar_silhueta_especie(cor)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if eh_lider and not esta_morta:
		_desenhar_marcas_lider(cor)
	if not esta_morta and not mutacoes.is_empty():
		_desenhar_mutacoes()
	if not esta_morta:
		draw_circle(Vector2(-2, -2), 2.0, Color("#f3d8a0"))
	else:
		draw_line(Vector2(-4, -4), Vector2(4, 4), Color("#d8c5b7"), 2.0)
		draw_line(Vector2(4, -4), Vector2(-4, 4), Color("#d8c5b7"), 2.0)


func _desenhar_silhueta_especie(cor: Color) -> void:
	var perfil := especie_id + " " + habitat + " " + bioma
	var escala := 1.35 if eh_chefe else (1.12 if eh_lider else 1.0)
	var contorno := Color("#171817", 0.9)
	var corpo := 10.0 * escala
	# Cauda e membros ajudam a distinguir famílias sem depender de nomes específicos.
	if "drag" in perfil or "rept" in perfil or "serp" in perfil:
		draw_colored_polygon(PackedVector2Array([Vector2(5, 2), Vector2(13, 5), Vector2(19, 2), Vector2(14, 9), Vector2(5, 7)]), contorno)
		draw_colored_polygon(PackedVector2Array([Vector2(5, 1), Vector2(13, 4), Vector2(17, 2), Vector2(13, 7), Vector2(5, 6)]), cor.darkened(0.12))
		draw_colored_polygon(PackedVector2Array([Vector2(-7, -4), Vector2(-13, -12), Vector2(-2, -9)]), cor.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(7, -4), Vector2(13, -12), Vector2(2, -9)]), cor.darkened(0.2))
	elif "inset" in perfil or "arac" in perfil or "aranh" in perfil:
		for lado in [-1.0, 1.0]:
			for i in range(3):
				var y := -3.0 + float(i) * 4.0
				draw_line(Vector2(lado * 4, y), Vector2(lado * (10 + i), y + 5), contorno, 3.0)
				draw_line(Vector2(lado * 4, y), Vector2(lado * (10 + i), y + 5), cor.lightened(0.18), 1.5)
		draw_circle(Vector2.ZERO, corpo * 0.72, contorno)
		draw_circle(Vector2.ZERO, corpo * 0.58, cor)
	elif "ave" in perfil or "voador" in perfil or "pena" in perfil:
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -2), Vector2(-15, -9), Vector2(-12, 1), Vector2(-5, 5)]), cor.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(4, -2), Vector2(15, -9), Vector2(12, 1), Vector2(5, 5)]), cor.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(-5, 4), Vector2(0, 12), Vector2(5, 4)]), contorno)
		draw_circle(Vector2.ZERO, corpo * 0.72, contorno)
		draw_circle(Vector2.ZERO, corpo * 0.58, cor)
	elif "aqu" in perfil or "mar" in perfil or "peix" in perfil:
		draw_colored_polygon(PackedVector2Array([Vector2(6, -3), Vector2(15, -9), Vector2(14, 0), Vector2(15, 9), Vector2(6, 3)]), contorno)
		draw_colored_polygon(PackedVector2Array([Vector2(6, -2), Vector2(13, -7), Vector2(12, 0), Vector2(13, 7), Vector2(6, 2)]), cor.darkened(0.18))
		draw_colored_polygon(PackedVector2Array([Vector2(-2, -6), Vector2(5, -12), Vector2(5, -4)]), cor.lightened(0.2))
		draw_circle(Vector2.ZERO, corpo * 0.78, contorno)
		draw_circle(Vector2.ZERO, corpo * 0.64, cor)
	else:
		# Quadrúpedes e espécies não classificadas recebem corpo, cabeça e quatro patas.
		for lado in [-1.0, 1.0]:
			var passo := sin(_tempo_animacao * 9.0 + lado * PI) * 2.0
			draw_line(Vector2(lado * 5, 2), Vector2(lado * 7 + passo, 11), contorno, 4.0)
			draw_line(Vector2(lado * 5, 2), Vector2(lado * 7 + passo, 11), cor.darkened(0.18), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -3), Vector2(-5, -8), Vector2(5, -8), Vector2(9, -2), Vector2(7, 6), Vector2(-6, 6)]), contorno)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -3), Vector2(-4, -6), Vector2(5, -6), Vector2(7, -2), Vector2(5, 4), Vector2(-5, 4)]), cor)
		draw_circle(Vector2(7, -5), 4.0 * escala, contorno)
		draw_circle(Vector2(8, -5), 2.8 * escala, cor.lightened(0.12))
	# Olhos e brilho variam de posição para manter leitura em miniatura.
	draw_circle(Vector2(8, -6), 1.5 * escala, Color("#f5dfaa"))
	if eh_chefe:
		draw_arc(Vector2.ZERO, 15.0 * escala, PI, TAU, 20, Color("#e7b66a", 0.9), 1.6, true)

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


## As mutações persistentes alteram a silhueta, sem mudar a espécie-base.
func _desenhar_mutacoes() -> void:
	for mutacao in mutacoes:
		var id_mutacao := str(mutacao.get("id", "")) if mutacao is Dictionary else str(mutacao)
		match id_mutacao:
			"carapaca_reforcada":
				var carapaca := Color("#b9a58b")
				draw_arc(Vector2.ZERO, 8.0, PI, TAU, 20, carapaca, 2.2, true)
				for lado in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([Vector2(lado * 4, -4), Vector2(lado * 9, -10), Vector2(lado * 8, -1)]), carapaca)
			"olhos_arcanos":
				var brilho := Color("#9be7ff")
				draw_circle(Vector2(-5, -3), 2.0, brilho)
				draw_circle(Vector2(5, -3), 2.0, brilho)
				draw_circle(Vector2(0, -7), 1.6, Color("#e9fbff"))
			"membros_predatorios":
				var garra := Color("#e8d6b4")
				for lado in [-1.0, 1.0]:
					draw_line(Vector2(lado * 4, 3), Vector2(lado * 9, 8), garra, 1.8)
					draw_line(Vector2(lado * 9, 8), Vector2(lado * 11, 5), garra, 1.2)
			"chifres_de_guerra":
				var chifre := Color("#e7d0a0")
				draw_line(Vector2(-4, -4), Vector2(-9, -11), chifre, 2.4)
				draw_line(Vector2(4, -4), Vector2(9, -11), chifre, 2.4)
			"coracao_vital":
				var pulso := 0.45 + (sin(_tempo_animacao * 3.0) + 1.0) * 0.18
				draw_arc(Vector2.ZERO, 13.0 + pulso * 2.0, 0.0, TAU, 32, Color("#e76b72", pulso), 1.8, true)
			"nucleo_mistico":
				draw_circle(Vector2.ZERO, 3.0 + sin(_tempo_animacao * 4.0) * 0.7, Color("#83d9ff", 0.85))
				draw_arc(Vector2.ZERO, 11.0, _tempo_animacao, _tempo_animacao + TAU * 0.7, 24, Color("#83d9ff", 0.8), 1.4, true)
