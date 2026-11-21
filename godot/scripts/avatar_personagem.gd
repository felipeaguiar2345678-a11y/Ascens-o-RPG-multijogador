extends Node2D
## Avatar procedural provisório. A anatomia vem do perfil validado pelo servidor.
## Será substituído por sprites pixel art sem alterar o contrato de perfil.

var raca_id := "humano"
var sexo := "masculino"
var aparencia_id := ""

func configurar(perfil: Dictionary) -> void:
	for filho in get_children():
		filho.queue_free()
	raca_id = str(perfil.get("racaId", "humano"))
	sexo = str(perfil.get("sexo", "masculino"))
	aparencia_id = str(perfil.get("aparenciaId", ""))
	var anatomia: Dictionary = perfil.get("anatomiaRacial", {})
	var altura := float(anatomia.get("altura", 1.0))
	var porte := str(anatomia.get("porte", "medio"))
	var largura := 1.0
	if porte in ["baixo_robusto", "robusto", "muito_forte"]:
		largura = 1.28 if porte == "baixo_robusto" else 1.18
	elif porte == "esguio":
		largura = 0.86
	elif porte == "leve":
		largura = 0.9
	scale = Vector2(largura, altura)
	_desenhar_corpo()
	_desenhar_orelhas(str(anatomia.get("orelhas", "humanas")))
	_desenhar_tracos(anatomia)

func _desenhar_corpo() -> void:
	var pele := Color("#d8a879")
	match raca_id:
		"elfo": pele = Color("#d5b58e")
		"anao": pele = Color("#b98561")
		"orc": pele = Color("#668b55")
		"fera": pele = Color("#c18b68")
		"draconiano": pele = Color("#8d7866")
		"silvestre": pele = Color("#c6c99a")
		"umbral": pele = Color("#75658e")
	var roupa := Color("#344b62")
	var cabelo := Color("#382b27")
	if "prateado" in aparencia_id or "cor_de_lua" in aparencia_id:
		cabelo = Color("#d5d7df")
	elif "ruivo" in aparencia_id:
		cabelo = Color("#a94e2f")
	elif "trancas" in aparencia_id:
		cabelo = Color("#5a3929")
	elif "careca" in aparencia_id:
		cabelo = pele
	elif raca_id == "umbral":
		cabelo = Color("#211d35")
	elif raca_id == "draconiano":
		cabelo = Color("#403f4a")
	_poligono([Vector2(-5, 1), Vector2(5, 1), Vector2(6, 10), Vector2(-6, 10)], roupa)
	_poligono([Vector2(-4, 9), Vector2(-1, 9), Vector2(-1, 15), Vector2(-5, 15)], Color("#493d38"))
	_poligono([Vector2(1, 9), Vector2(4, 9), Vector2(5, 15), Vector2(1, 15)], Color("#493d38"))
	_poligono([Vector2(-8, 1), Vector2(-5, -1), Vector2(-4, 7), Vector2(-7, 8)], pele)
	_poligono([Vector2(5, -1), Vector2(8, 1), Vector2(7, 8), Vector2(4, 7)], pele)
	_poligono([Vector2(-4, -8), Vector2(4, -8), Vector2(5, -1), Vector2(-5, -1)], pele)
	_poligono([Vector2(-5, -8), Vector2(-3, -12), Vector2(3, -12), Vector2(5, -8), Vector2(4, -4), Vector2(-4, -4)], cabelo)
	if "cicatriz" in aparencia_id:
		_poligono([Vector2(1, -6), Vector2(2, -6), Vector2(-1, -2), Vector2(-2, -2)], Color("#8e4d48"))
	if "elmo" in aparencia_id:
		_poligono([Vector2(-6, -8), Vector2(0, -14), Vector2(6, -8), Vector2(5, -5), Vector2(-5, -5)], Color("#9ca8ad"))

func _desenhar_orelhas(tipo: String) -> void:
	var cor := Color("#d8a879")
	if raca_id == "orc":
		cor = Color("#668b55")
	elif raca_id == "draconiano":
		cor = Color("#8d7866")
	if tipo in ["elficas_pontudas", "alongadas", "pontudas_sutis", "orc", "bestiais", "draconicas"]:
		_poligono([Vector2(-4, -7), Vector2(-12, -10), Vector2(-6, -3)], cor)
		_poligono([Vector2(4, -7), Vector2(12, -10), Vector2(6, -3)], cor)

func _desenhar_tracos(anatomia: Dictionary) -> void:
	var pele := Color("#8d7866") if raca_id == "draconiano" else Color("#d8a879")
	if raca_id == "orc":
		_poligono([Vector2(-3, -2), Vector2(-2, 1), Vector2(-1, -2)], Color("#f1e8d2"))
		_poligono([Vector2(1, -2), Vector2(2, 1), Vector2(3, -2)], Color("#f1e8d2"))
	if raca_id == "draconiano":
		_poligono([Vector2(-4, -10), Vector2(-8, -16), Vector2(-2, -12)], Color("#62564f"))
		_poligono([Vector2(4, -10), Vector2(8, -16), Vector2(2, -12)], Color("#62564f"))
		_poligono([Vector2(-6, -1), Vector2(-11, -6), Vector2(-9, 3), Vector2(-5, 5)], Color("#62564f"))
		_poligono([Vector2(6, -1), Vector2(11, -6), Vector2(9, 3), Vector2(5, 5)], Color("#62564f"))
		_poligono([Vector2(4, 8), Vector2(11, 12), Vector2(16, 17), Vector2(13, 18), Vector2(7, 14)], pele)
		for i in range(3):
			_poligono([Vector2(-4 + i * 3, 1), Vector2(-3 + i * 3, 0), Vector2(-2 + i * 3, 2)], Color("#d6c18b"))
	elif raca_id == "fera":
		_poligono([Vector2(-4, -8), Vector2(-7, -16), Vector2(-1, -11)], Color("#a87856"))
		_poligono([Vector2(4, -8), Vector2(7, -16), Vector2(1, -11)], Color("#a87856"))
		_poligono([Vector2(5, 8), Vector2(11, 11), Vector2(15, 16), Vector2(12, 17), Vector2(6, 13)], pele)
	elif raca_id == "silvestre":
		_poligono([Vector2(-5, -2), Vector2(-10, -7), Vector2(-4, -5)], Color("#8da66a"))
		_poligono([Vector2(5, -2), Vector2(10, -7), Vector2(4, -5)], Color("#8da66a"))
	elif raca_id == "umbral":
		_poligono([Vector2(-3, -5), Vector2(-1, -5), Vector2(-1, -4), Vector2(-3, -4)], Color("#8de4e6"))
		_poligono([Vector2(1, -5), Vector2(3, -5), Vector2(3, -4), Vector2(1, -4)], Color("#8de4e6"))
	if str(anatomia.get("chifres", "")) == "draconicos":
		_poligono([Vector2(-4, -10), Vector2(-7, -17), Vector2(-2, -13)], Color("#51483f"))
		_poligono([Vector2(4, -10), Vector2(7, -17), Vector2(2, -13)], Color("#51483f"))

func _poligono(pontos: Array, cor: Color) -> void:
	var forma := Polygon2D.new()
	forma.polygon = PackedVector2Array(pontos)
	forma.color = cor
	add_child(forma)
