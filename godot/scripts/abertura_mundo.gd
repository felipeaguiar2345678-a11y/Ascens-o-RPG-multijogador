extends Node2D
## Apresentação cinematográfica do mundo. Não cria missão nem altera progresso.
## A câmera percorre um panorama ilustrativo e, ao terminar, libera o fluxo normal.

const CENA_PERSONAGEM := "res://scenes/criacao_personagem.tscn"
const TAMANHO_MAPA := Vector2(2600.0, 1500.0)

var camera: Camera2D
var titulo: Label
var descricao: Label
var botao_pular: Button
var _encerrando := false
var _energia := 0.0

func _ready() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(350, 300)
	camera.zoom = Vector2(0.78, 0.78)
	add_child(camera)
	camera.make_current()
	_criar_interface()
	queue_redraw()
	_executar_apresentacao()

func _criar_interface() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 20
	add_child(camada)
	var faixa := ColorRect.new()
	faixa.color = Color(0.025, 0.035, 0.035, 0.62)
	faixa.anchor_left = 0.0
	faixa.anchor_right = 1.0
	faixa.anchor_top = 0.0
	faixa.anchor_bottom = 0.0
	faixa.offset_bottom = 104.0
	camada.add_child(faixa)
	titulo = Label.new()
	titulo.position = Vector2(24, 17)
	titulo.size = Vector2(592, 32)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 21)
	titulo.add_theme_color_override("font_color", Color("#f1d99c"))
	faixa.add_child(titulo)
	descricao = Label.new()
	descricao.position = Vector2(24, 53)
	descricao.size = Vector2(592, 38)
	descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	descricao.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descricao.add_theme_font_size_override("font_size", 12)
	descricao.add_theme_color_override("font_color", Color("#f0eee4"))
	faixa.add_child(descricao)
	botao_pular = Button.new()
	botao_pular.text = "Pular apresentação"
	botao_pular.position = Vector2(460, 318)
	botao_pular.size = Vector2(160, 30)
	botao_pular.pressed.connect(_finalizar)
	camada.add_child(botao_pular)

func _executar_apresentacao() -> void:
	await _mostrar_cena("UM MUNDO VIVO", "Terras antigas, florestas e regiões que seguem seu próprio curso.", Vector2(350, 300), 3.8)
	if _encerrando: return
	await _mostrar_cena("A LEI DA NATUREZA", "Criaturas caçam, fogem e disputam território mesmo quando ninguém as observa.", Vector2(880, 690), 4.0)
	if _encerrando: return
	await _mostrar_cena("TERRAS EM PERIGO", "Vilas enfrentam ataques. Seus habitantes lutam para proteger o que construíram.", Vector2(1390, 350), 4.0)
	if _encerrando: return
	await _mostrar_cena("AURELIA", "A grande cidade permanece de pé, movimentada em meio a um mundo imprevisível.", Vector2(1900, 650), 4.2)
	if _encerrando: return
	await _mostrar_cena("A GRANDE SERPENTE", "Muito além das muralhas, uma presença colossal desperta.", Vector2(2260, 1110), 4.2)
	if _encerrando: return
	titulo.text = "ASCENSÃO DO SOBERANO"
	descricao.text = "Um mundo que não espera por você."
	_energia = 1.0
	queue_redraw()
	await get_tree().create_timer(2.8).timeout
	_finalizar()

func _mostrar_cena(nome: String, texto: String, destino: Vector2, duracao: float) -> void:
	if _encerrando: return
	titulo.text = nome
	descricao.text = texto
	var movimento := create_tween()
	movimento.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	movimento.tween_property(camera, "position", destino, duracao)
	await movimento.finished

func _finalizar() -> void:
	if _encerrando: return
	_encerrando = true
	# Registra a apresentação por UID: cada conta vê a abertura uma vez neste aparelho.
	var uid := RedeMultiplayer.uid_autenticado
	if not uid.is_empty():
		var configuracao := ConfigFile.new()
		configuracao.load("user://aberturas_mundo.cfg")
		configuracao.set_value("contas", uid, true)
		var erro := configuracao.save("user://aberturas_mundo.cfg")
		if erro != OK:
			push_warning("Não foi possível salvar que a apresentação já foi exibida.")
	get_tree().change_scene_to_file(CENA_PERSONAGEM)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, TAMANHO_MAPA), Color("#172b2b"))
	var continente := PackedVector2Array([
		Vector2(70, 250), Vector2(250, 100), Vector2(610, 80), Vector2(900, 190),
		Vector2(1210, 120), Vector2(1530, 210), Vector2(1880, 120), Vector2(2260, 260),
		Vector2(2500, 510), Vector2(2390, 900), Vector2(2110, 1290), Vector2(1700, 1390),
		Vector2(1330, 1300), Vector2(970, 1430), Vector2(590, 1280), Vector2(230, 1000),
		Vector2(80, 650)
	])
	draw_colored_polygon(continente, Color("#526b45"))
	draw_polyline(continente, Color("#b2a477"), 13.0, true)
	for ponto in [Vector2(350, 260), Vector2(520, 210), Vector2(690, 290), Vector2(1040, 250), Vector2(1190, 300), Vector2(1450, 260)]:
		_desenhar_montanha(ponto, 70.0)
	for x in range(260, 1120, 92):
		for y in range(390, 1120, 86):
			var ponto := Vector2(x + sin(float(x + y)) * 24.0, y + cos(float(x - y)) * 18.0)
			if ponto.distance_to(Vector2(880, 690)) > 260.0:
				_desenhar_arvore(ponto, 18.0 + float((x + y) % 13))
	draw_polyline(PackedVector2Array([Vector2(680, 130), Vector2(790, 360), Vector2(970, 510), Vector2(1120, 760), Vector2(1450, 900), Vector2(1710, 1190)]), Color("#5599a0"), 24.0, true)
	draw_polyline(PackedVector2Array([Vector2(1390, 350), Vector2(1650, 470), Vector2(1900, 650), Vector2(2130, 780)]), Color("#d0b77e"), 10.0, true)
	draw_polyline(PackedVector2Array([Vector2(880, 690), Vector2(1190, 820), Vector2(1510, 900), Vector2(1900, 650)]), Color("#d0b77e"), 7.0, true)
	_desenhar_vila(Vector2(1390, 350), true)
	_desenhar_capital(Vector2(1900, 650))
	_desenhar_cacada(Vector2(880, 690))
	_desenhar_serpente(Vector2(2260, 1110))
	if _energia > 0.0:
		var origem := Vector2(2260, 1010)
		var ponta := Vector2(2350, 250)
		draw_line(origem, ponta, Color(0.85, 0.93, 1.0, 0.18 * _energia), 58.0, true)
		draw_line(origem, ponta, Color(0.95, 0.91, 0.69, 0.88 * _energia), 13.0, true)
		draw_circle(ponta, 34.0, Color(1.0, 0.91, 0.66, 0.7 * _energia))

func _desenhar_montanha(p: Vector2, escala: float) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-escala, escala * 0.55), p + Vector2(0, -escala), p + Vector2(escala, escala * 0.55)]), Color("#687b78"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-escala * 0.35, 0), p + Vector2(0, -escala), p + Vector2(escala * 0.35, 0)]), Color("#d0d1bd"))

func _desenhar_arvore(p: Vector2, tamanho: float) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -tamanho), p + Vector2(-tamanho * 0.58, tamanho * 0.45), p + Vector2(tamanho * 0.58, tamanho * 0.45)]), Color("#294b37"))
	draw_circle(p + Vector2(0, -tamanho * 0.2), tamanho * 0.22, Color("#6c8150"))

func _desenhar_vila(p: Vector2, atacada: bool) -> void:
	for deslocamento in [Vector2(-55, 0), Vector2(0, -28), Vector2(48, 18), Vector2(10, 48)]:
		var casa := p + deslocamento
		draw_rect(Rect2(casa + Vector2(-13, -8), Vector2(26, 20)), Color("#bda77a"))
		draw_colored_polygon(PackedVector2Array([casa + Vector2(-17, -8), casa + Vector2(0, -25), casa + Vector2(17, -8)]), Color("#583c32"))
	if atacada:
		for fogo in [p + Vector2(-55, -38), p + Vector2(47, -30), p + Vector2(10, -62)]:
			draw_circle(fogo, 10.0, Color("#e77a35"))
			draw_circle(fogo + Vector2(0, -8), 5.0, Color("#f6d16b"))
		draw_arc(p, 95.0, 0.0, TAU, 48, Color("#382d28"), 5.0, true)

func _desenhar_capital(p: Vector2) -> void:
	draw_circle(p, 145.0, Color("#d2b66f", 0.16))
	draw_rect(Rect2(p + Vector2(-100, -55), Vector2(200, 120)), Color("#9a987e"))
	for x in [-92.0, -48.0, 0.0, 48.0, 92.0]:
		draw_rect(Rect2(p + Vector2(x - 13, -92), Vector2(26, 55)), Color("#c9b88d"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(x - 18, -92), p + Vector2(x, -119), p + Vector2(x + 18, -92)]), Color("#76584a"))
	draw_rect(Rect2(p + Vector2(-28, -22), Vector2(56, 87)), Color("#57483d"))
	draw_circle(p, 8.0, Color("#f5df9c"))

func _desenhar_cacada(p: Vector2) -> void:
	for deslocamento in [Vector2(-36, -8), Vector2(52, 18)]:
		var corpo := p + deslocamento
		draw_circle(corpo, 15.0, Color("#26332b"))
		draw_circle(corpo + Vector2(23, -7), 9.0, Color("#26332b"))
		for perna in [-13.0, 8.0]:
			draw_line(corpo + Vector2(perna, 8), corpo + Vector2(perna - 5, 27), Color("#26332b"), 5.0, true)
	draw_line(p + Vector2(-4, -18), p + Vector2(20, -35), Color("#d9d0a2"), 3.0, true)

func _desenhar_serpente(p: Vector2) -> void:
	var pontos := PackedVector2Array()
	for i in range(101):
		var a := TAU * float(i) / 100.0
		pontos.append(p + Vector2(cos(a) * 330.0, sin(a) * 220.0))
	draw_polyline(pontos, Color("#10211e"), 74.0, true)
	draw_polyline(pontos, Color("#527653"), 48.0, true)
	draw_polyline(pontos, Color("#b2a66a"), 5.0, true)
	draw_circle(p + Vector2(0, -218), 56.0, Color("#73936a"))
	draw_circle(p + Vector2(-19, -228), 7.0, Color("#f1d16b"))
	draw_circle(p + Vector2(19, -228), 7.0, Color("#f1d16b"))
	draw_line(p + Vector2(0, -170), p + Vector2(70, -820), Color("#73936a"), 42.0, true)
	draw_line(p + Vector2(0, -170), p + Vector2(70, -820), Color("#d8c987"), 4.0, true)
