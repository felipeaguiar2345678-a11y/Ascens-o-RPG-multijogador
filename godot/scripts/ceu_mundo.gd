extends Control
## Camada atmosférica compartilhada: acompanha o relógio autoritativo do mundo.

var contexto: Dictionary = {
	"periodo":"dia",
	"faseLunar":"lua_crescente",
	"eventoCeleste":{"id":"nenhum","nome":"Céu comum"}
}
var _tempo := 0.0

func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func atualizar_contexto(novo_contexto: Dictionary) -> void:
	contexto = novo_contexto.duplicate(true)
	queue_redraw()

func _process(delta: float) -> void:
	_tempo += delta
	if str(contexto.get("periodo", "dia")) != "dia":
		queue_redraw()

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	var periodo := str(contexto.get("periodo", "dia"))
	var evento: Dictionary = contexto.get("eventoCeleste", {})
	var evento_id := str(evento.get("id", "nenhum"))
	var cor_ceu := Color("#75b8e8", 0.035)
	match periodo:
		"crepusculo": cor_ceu = Color("#f08a59", 0.12)
		"noite": cor_ceu = Color("#101b45", 0.24)
		"madrugada": cor_ceu = Color("#344a79", 0.18)
	for faixa in range(12):
		var y := float(faixa) * area.size.y / 12.0
		var alpha := cor_ceu.a * (1.0 - float(faixa) / 12.0) * 0.72
		draw_rect(Rect2(0, y, area.size.x, area.size.y / 12.0 + 1.0), Color(cor_ceu, alpha / maxf(cor_ceu.a, 0.001)), true)
	if periodo == "dia":
		_desenhar_sol(area)
	else:
		_desenhar_estrelas(area)
		_desenhar_lua(area, evento_id)
	if "aurora_arcana" in evento_id:
		_desenhar_aurora(area)
	if "chuva_de_estrelas" in evento_id:
		_desenhar_chuva_de_estrelas(area)
	if "eclipse" in evento_id:
		_desenhar_eclipse(area)

func _desenhar_sol(area: Rect2) -> void:
	var sol := Vector2(area.size.x * 0.78, area.size.y * 0.16)
	draw_circle(sol, 31.0, Color("#ffe7a1", 0.035))
	draw_circle(sol, 20.0, Color("#ffe7a1", 0.07))
	draw_circle(sol, 11.0, Color("#fff0b5", 0.18))

func _desenhar_estrelas(area: Rect2) -> void:
	for i in range(85):
		var x := fposmod(float(i * 97 + 31), maxf(area.size.x, 1.0))
		var y := fposmod(float(i * 53 + 17), maxf(area.size.y * 0.72, 1.0))
		var brilho := 0.35 + 0.45 * absf(sin(_tempo * 1.5 + float(i)))
		draw_circle(Vector2(x, y), 0.7 + float(i % 3) * 0.35, Color("#e7efff", brilho))

func _desenhar_lua(area: Rect2, evento_id: String) -> void:
	var centro := Vector2(area.size.x * 0.83, area.size.y * 0.17)
	var cor := Color("#e7e8df")
	if "lua_de_sangue" in evento_id:
		cor = Color("#d94d58")
	elif "lua_azul" in evento_id:
		cor = Color("#8bcaff")
	elif "lua_negra" in evento_id:
		cor = Color("#7b8295")
	draw_circle(centro, 32.0, Color(cor, 0.045))
	draw_circle(centro, 22.0, Color(cor, 0.10))
	draw_circle(centro, 14.0, cor)
	var fase := str(contexto.get("faseLunar", "lua_cheia"))
	if fase == "lua_nova":
		draw_circle(centro, 14.0, Color("#172039"))
	elif fase in ["lua_crescente", "lua_minguante", "quarto_crescente", "quarto_minguante"]:
		var deslocamento := -7.0 if fase in ["lua_crescente", "quarto_crescente"] else 7.0
		draw_circle(centro + Vector2(deslocamento, 0), 14.0, Color("#172039"))
	if "eclipse" in evento_id:
		draw_circle(centro, 15.0, Color("#101522"))
		draw_arc(centro, 19.0, 0.0, TAU, 48, Color("#d6ad66", 0.9), 2.0)

func _desenhar_aurora(area: Rect2) -> void:
	for i in range(5):
		var y := area.size.y * (0.08 + float(i) * 0.035) + sin(_tempo * 0.55 + float(i)) * 7.0
		var raio := area.size.x * (0.28 + float(i) * 0.045)
		draw_arc(Vector2(area.size.x * 0.48, y), raio, 0.05, PI - 0.05, 48, Color("#65e0bd", 0.22 - float(i) * 0.025), 5.0)

func _desenhar_chuva_de_estrelas(area: Rect2) -> void:
	for i in range(9):
		var x := fposmod(float(i * 113) + _tempo * (25.0 + float(i % 3) * 8.0), maxf(area.size.x, 1.0))
		var y := fposmod(float(i * 47 + 12), maxf(area.size.y * 0.55, 1.0))
		draw_line(Vector2(x, y), Vector2(x - 13, y + 8), Color("#fff0c4", 0.72), 1.4)

func _desenhar_eclipse(area: Rect2) -> void:
	var centro := Vector2(area.size.x * 0.83, area.size.y * 0.17)
	draw_circle(centro, 29.0, Color("#d9b36a", 0.12))
	draw_circle(centro, 23.0, Color("#111522"))
	draw_arc(centro, 27.0, 0.0, TAU, 64, Color("#d9b36a", 0.9), 2.0)
