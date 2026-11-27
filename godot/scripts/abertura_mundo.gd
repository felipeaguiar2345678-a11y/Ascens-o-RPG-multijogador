extends Node2D
## Apresentação cinematográfica do mundo. Não cria missão nem altera progresso.
## A câmera percorre um panorama ilustrativo e, ao terminar, libera o fluxo normal.

const CENA_PERSONAGEM := "res://scenes/criacao_personagem.tscn"
const TAMANHO_MAPA := Vector2(2600.0, 1500.0)

var camera: Camera2D
var titulo: Label
var descricao: Label
var botao_pular: Button
var barra_superior: ColorRect
var barra_inferior: ColorRect
var titulo_final: Label
var _encerrando := false
var _energia := 0.0
var _tempo := 0.0

func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()

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
	barra_superior = ColorRect.new()
	barra_superior.color = Color(0.015, 0.02, 0.02, 0.94)
	barra_superior.anchor_right = 1.0
	camada.add_child(barra_superior)
	barra_inferior = ColorRect.new()
	barra_inferior.color = Color(0.015, 0.02, 0.02, 0.94)
	barra_inferior.anchor_top = 1.0
	barra_inferior.anchor_right = 1.0
	barra_inferior.anchor_bottom = 1.0
	camada.add_child(barra_inferior)
	var faixa := ColorRect.new()
	faixa.color = Color(0.025, 0.035, 0.035, 0.58)
	faixa.anchor_right = 1.0
	faixa.offset_top = 42.0
	faixa.offset_bottom = 146.0
	camada.add_child(faixa)
	titulo = Label.new()
	titulo.anchor_left = 0.08
	titulo.anchor_right = 0.92
	titulo.offset_top = 48.0
	titulo.offset_bottom = 80.0
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 21)
	titulo.add_theme_color_override("font_color", Color("#f1d99c"))
	faixa.add_child(titulo)
	descricao = Label.new()
	descricao.anchor_left = 0.08
	descricao.anchor_right = 0.92
	descricao.offset_top = 82.0
	descricao.offset_bottom = 126.0
	descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	descricao.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descricao.add_theme_font_size_override("font_size", 12)
	descricao.add_theme_color_override("font_color", Color("#f0eee4"))
	faixa.add_child(descricao)
	botao_pular = Button.new()
	botao_pular.text = "Pular apresentação"
	botao_pular.anchor_left = 1.0
	botao_pular.anchor_top = 1.0
	botao_pular.anchor_right = 1.0
	botao_pular.anchor_bottom = 1.0
	botao_pular.offset_left = -184.0
	botao_pular.offset_top = -76.0
	botao_pular.offset_right = -20.0
	botao_pular.offset_bottom = -38.0
	botao_pular.pressed.connect(_finalizar)
	camada.add_child(botao_pular)
	titulo_final = Label.new()
	titulo_final.anchor_left = 0.08
	titulo_final.anchor_top = 0.40
	titulo_final.anchor_right = 0.92
	titulo_final.anchor_bottom = 0.60
	titulo_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_final.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo_final.add_theme_font_size_override("font_size", 34)
	titulo_final.add_theme_color_override("font_color", Color("#f1d99c"))
	titulo_final.modulate.a = 0.0
	camada.add_child(titulo_final)
	var entrada_barras := create_tween().set_parallel(true)
	entrada_barras.tween_property(barra_superior, "offset_bottom", 34.0, 1.0)
	entrada_barras.tween_property(barra_inferior, "offset_top", -34.0, 1.0)

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
	_energia = 1.0
	queue_redraw()
	var aproximacao := create_tween()
	aproximacao.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	aproximacao.tween_property(camera, "zoom", Vector2(1.02, 1.02), 2.0)
	await aproximacao.finished
	if _encerrando: return
	titulo.text = ""
	descricao.text = ""
	titulo_final.text = "ASCENSÃO DO SOBERANO\nUm mundo que não espera por você."
	var revelar := create_tween()
	revelar.tween_property(titulo_final, "modulate:a", 1.0, 1.35)
	await revelar.finished
	await get_tree().create_timer(2.8).timeout
	_finalizar()

func _mostrar_cena(nome: String, texto: String, destino: Vector2, duracao: float) -> void:
	if _encerrando: return
	var saida_texto := create_tween().set_parallel(true)
	saida_texto.tween_property(titulo, "modulate:a", 0.0, 0.25)
	saida_texto.tween_property(descricao, "modulate:a", 0.0, 0.25)
	await saida_texto.finished
	if _encerrando: return
	titulo.text = nome
	descricao.text = texto
	var movimento := create_tween().set_parallel(true)
	movimento.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	movimento.tween_property(camera, "position", destino, duracao)
	movimento.tween_property(titulo, "modulate:a", 1.0, 0.6)
	movimento.tween_property(descricao, "modulate:a", 1.0, 0.6)
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
		var pulsacao := 0.78 + 0.22 * sin(_tempo * 5.0)
		draw_line(origem, ponta, Color(0.85, 0.93, 1.0, 0.22 * _energia * pulsacao), 58.0 + 12.0 * pulsacao, true)
		draw_line(origem, ponta, Color(0.95, 0.91, 0.69, 0.92 * _energia), 13.0 + 4.0 * pulsacao, true)
		draw_circle(ponta, 28.0 + 12.0 * pulsacao, Color(1.0, 0.91, 0.66, 0.7 * _energia))

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
		var tremor := sin(_tempo * 9.0) * 4.0
		for indice in range(3):
			var deslocamento: Vector2 = [Vector2(-55, -38), Vector2(47, -30), Vector2(10, -62)][indice]
			var fogo := p + deslocamento + Vector2(0, tremor * (1.0 + float(indice) * 0.2))
			draw_circle(fogo, 9.0 + abs(tremor), Color("#e77a35", 0.9))
			draw_circle(fogo + Vector2(0, -9.0 - tremor), 5.0, Color("#f6d16b"))
			var subida := fposmod(_tempo * 22.0 + float(indice) * 31.0, 48.0)
			draw_circle(fogo + Vector2(sin(_tempo + float(indice)) * 7.0, -24.0 - subida), 5.0 + subida * 0.12, Color(0.16, 0.17, 0.15, 0.28 - subida * 0.003))
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
	var corrida := sin(_tempo * 2.4) * 24.0
	for indice in range(2):
		var deslocamento: Vector2 = [Vector2(-36.0 + corrida, -8.0), Vector2(52.0 + corrida * 0.35, 18.0)][indice]
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
	var cabeca := p + Vector2(0, -218 + sin(_tempo * 1.2) * 7.0)
	draw_circle(cabeca, 56.0, Color("#73936a"))
	draw_circle(cabeca + Vector2(-19, -10), 7.0, Color("#f1d16b"))
	draw_circle(cabeca + Vector2(19, -10), 7.0, Color("#f1d16b"))
	draw_line(p + Vector2(0, -170), p + Vector2(70, -820), Color("#73936a"), 42.0, true)
	draw_line(p + Vector2(0, -170), p + Vector2(70, -820), Color("#d8c987"), 4.0, true)
