extends Node2D
## Avatar pixelado por camadas, orientado pelo perfil validado pelo servidor.
## A animação não altera o contrato de aparência/equipamentos.

var raca_id := "humano"
var sexo := "masculino"
var aparencia_id := ""
var equipamentos: Dictionary = {}
var _tempo_animacao := 0.0
var _intensidade_movimento := 0.0
const APRESENTACAO_ARMA = preload("res://scripts/apresentacao_arma.gd")
var _apresentacao_arma: Node2D

func definir_movimento(intensidade: float, direcao: Vector2 = Vector2.ZERO) -> void:
	_intensidade_movimento = clampf(intensidade, 0.0, 1.0)
	if direcao.x != 0.0:
		scale.x = absf(scale.x) * (-1.0 if direcao.x < 0.0 else 1.0)
	if is_instance_valid(_apresentacao_arma) and direcao.length_squared() > 0.0:
		var orientacao := "frente" if direcao.y > 0.25 else "costas" if direcao.y < -0.25 else "esquerda" if direcao.x < 0.0 else "direita"
		_apresentacao_arma.definir_direcao(orientacao)


func _process(delta: float) -> void:
	_tempo_animacao += delta
	var passo := sin(_tempo_animacao * 13.0)
	position.y = -absf(passo) * 1.7 * _intensidade_movimento + sin(_tempo_animacao * 2.4) * 0.35 * (1.0 - _intensidade_movimento)
	rotation = sin(_tempo_animacao * 13.0) * 0.035 * _intensidade_movimento


func configurar(perfil: Dictionary) -> void:
	for filho in get_children():
		filho.queue_free()
	raca_id = str(perfil.get("racaId", "humano"))
	sexo = str(perfil.get("sexo", "masculino"))
	aparencia_id = str(perfil.get("aparenciaId", ""))
	equipamentos = perfil.get("equipamentos", {}).duplicate(true)
	var anatomia: Dictionary = perfil.get("anatomiaRacial", {})
	var altura := float(anatomia.get("altura", 1.0))
	var porte := str(anatomia.get("porte", "medio"))
	var largura := 1.0
	if raca_id == "gigante":
		largura = 1.32
		altura = 1.35
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
	_desenhar_detalhes_pixel()
	_desenhar_equipamentos()
	_apresentar_arma_equipada()

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
		"gigante": pele = Color("#b58b68")
		"gigante": pele = Color("#b58b68")
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
	# Personagem recém-criado usa apenas roupa íntima; armaduras são camadas separadas.
	var roupa_intima := Color("#344b62") if sexo == "masculino" else Color("#493c5b")
	_poligono([Vector2(-5, 1), Vector2(5, 1), Vector2(6, 10), Vector2(-6, 10)], pele)
	_poligono([Vector2(-5, 0), Vector2(5, 0), Vector2(6, 9), Vector2(-6, 9)], roupa_intima)
	_poligono([Vector2(-5, 9), Vector2(-1, 9), Vector2(-1, 14), Vector2(-5, 14)], Color("#594432"))
	_poligono([Vector2(1, 9), Vector2(5, 9), Vector2(5, 14), Vector2(1, 14)], Color("#594432"))
	_poligono([Vector2(-6, 13), Vector2(-1, 13), Vector2(-1, 16), Vector2(-7, 16)], Color("#302b2a"))
	_poligono([Vector2(1, 13), Vector2(6, 13), Vector2(7, 16), Vector2(1, 16)], Color("#302b2a"))
	_poligono([Vector2(-5, 2), Vector2(0, 4), Vector2(5, 2), Vector2(4, 8), Vector2(-4, 8)], roupa_intima.lightened(0.12))
	_poligono([Vector2(-2, 2), Vector2(0, 4), Vector2(2, 2), Vector2(1, 8), Vector2(-1, 8)], Color("#c5a46c"))
	_poligono([Vector2(-8, 1), Vector2(-5, -1), Vector2(-4, 7), Vector2(-7, 8)], pele)
	_poligono([Vector2(5, -1), Vector2(8, 1), Vector2(7, 8), Vector2(4, 7)], pele)
	_poligono([Vector2(-4, -8), Vector2(4, -8), Vector2(5, -1), Vector2(-5, -1)], pele)
	_poligono([Vector2(-5, -8), Vector2(-3, -12), Vector2(3, -12), Vector2(5, -8), Vector2(4, -4), Vector2(-4, -4)], cabelo)
	if "cicatriz" in aparencia_id:
		_poligono([Vector2(1, -6), Vector2(2, -6), Vector2(-1, -2), Vector2(-2, -2)], Color("#8e4d48"))
	if "elmo" in aparencia_id:
		_poligono([Vector2(-6, -8), Vector2(0, -14), Vector2(6, -8), Vector2(5, -5), Vector2(-5, -5)], Color("#9ca8ad"))


func _desenhar_detalhes_pixel() -> void:
	var pele := Color("#d8a879")
	match raca_id:
		"elfo": pele = Color("#d5b58e")
		"anao": pele = Color("#b98561")
		"orc": pele = Color("#668b55")
		"fera": pele = Color("#c18b68")
		"draconiano": pele = Color("#8d7866")
		"silvestre": pele = Color("#c6c99a")
		"umbral": pele = Color("#75658e")
	var sombra_pele := pele.darkened(0.22)
	# Luz e sombra em blocos para reforçar o aspecto de pixel art.
	_poligono([Vector2(-4, -7), Vector2(-2, -8), Vector2(-2, -2), Vector2(-4, -1)], pele.lightened(0.18))
	_poligono([Vector2(3, -1), Vector2(5, -2), Vector2(4, 7), Vector2(2, 8)], sombra_pele)
	_poligono([Vector2(-5, 2), Vector2(-3, 2), Vector2(-3, 8), Vector2(-5, 8)], sombra_pele)
	# Olhos, sobrancelhas e nariz permanecem visíveis sem elmo fechado.
	if not "elmo_fechado" in aparencia_id and not "careca" in aparencia_id:
		var cor_olho := Color("#302c2b")
		if raca_id == "umbral":
			cor_olho = Color("#8de4e6")
		elif raca_id == "draconiano":
			cor_olho = Color("#e5bd67")
		_poligono([Vector2(-3, -6), Vector2(-1, -6), Vector2(-1, -5), Vector2(-3, -5)], cor_olho)
		_poligono([Vector2(1, -6), Vector2(3, -6), Vector2(3, -5), Vector2(1, -5)], cor_olho)
		_poligono([Vector2(-3, -7), Vector2(-1, -8), Vector2(-1, -7)], Color("#4a3730"))
		_poligono([Vector2(1, -7), Vector2(3, -8), Vector2(3, -7)], Color("#4a3730"))
		_poligono([Vector2(0, -5), Vector2(1, -4), Vector2(0, -3)], sombra_pele)
	# Cinto e costuras da roupa inicial.
	_poligono([Vector2(-5, 8), Vector2(5, 8), Vector2(5, 9), Vector2(-5, 9)], Color("#76533b"))
	_poligono([Vector2(-1, 8), Vector2(1, 8), Vector2(1, 10), Vector2(-1, 10)], Color("#d2b36d"))
	_poligono([Vector2(-4, 12), Vector2(-2, 12), Vector2(-2, 14), Vector2(-4, 14)], Color("#f0e7d5"))
	_poligono([Vector2(2, 12), Vector2(4, 12), Vector2(4, 14), Vector2(2, 14)], Color("#f0e7d5"))

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

func _desenhar_equipamentos() -> void:
	# As peças ocupam somente a silhueta humana; orelhas, chifres, asas e caudas raciais permanecem visíveis.
	var torso := str(equipamentos.get("torso", ""))
	var cabeca := str(equipamentos.get("cabeca", ""))
	var pernas := str(equipamentos.get("pernas", ""))
	var maos := str(equipamentos.get("maos", ""))
	var pes := str(equipamentos.get("pes", ""))
	var costas := str(equipamentos.get("costas", ""))
	var principal := str(equipamentos.get("mao_principal", ""))
	var secundaria := str(equipamentos.get("mao_secundaria", ""))
	var colar := str(equipamentos.get("colar", ""))
	var bracelete := str(equipamentos.get("bracelete", ""))
	var anel := str(equipamentos.get("anel", ""))

	if not costas.is_empty():
		var capa := Color("#57436f") if costas == "manto_arcano" else Color("#654b38")
		_poligono([Vector2(-6, -1), Vector2(-8, 2), Vector2(-7, 12), Vector2(0, 15), Vector2(7, 12), Vector2(8, 2), Vector2(6, -1)], capa)
	if not pernas.is_empty():
		var cor_pernas := _cor_peca(pernas)
		_poligono([Vector2(-5, 10), Vector2(-1, 10), Vector2(-1, 15), Vector2(-5, 15)], cor_pernas)
		_poligono([Vector2(1, 10), Vector2(5, 10), Vector2(5, 15), Vector2(1, 15)], cor_pernas)
	if not pes.is_empty():
		var cor_pes := _cor_peca(pes)
		_poligono([Vector2(-6, 13), Vector2(-1, 13), Vector2(-1, 16), Vector2(-7, 16)], cor_pes)
		_poligono([Vector2(1, 13), Vector2(6, 13), Vector2(7, 16), Vector2(1, 16)], cor_pes)
	if not torso.is_empty():
		var cor_torso := _cor_peca(torso)
		_poligono([Vector2(-6, 1), Vector2(-5, -1), Vector2(5, -1), Vector2(6, 1), Vector2(5, 10), Vector2(-5, 10)], cor_torso)
		if torso == "peitoral_placas":
			_poligono([Vector2(-3, 1), Vector2(0, 0), Vector2(3, 1), Vector2(2, 8), Vector2(-2, 8)], Color("#c0c5c8"))
		elif torso == "peitoral_malha":
			for y in range(3, 9, 2):
				_poligono([Vector2(-4, y), Vector2(4, y), Vector2(4, y + 1), Vector2(-4, y + 1)], Color("#9da6a9"))
	if not maos.is_empty():
		var cor_maos := _cor_peca(maos)
		_poligono([Vector2(-9, 3), Vector2(-5, 4), Vector2(-5, 8), Vector2(-9, 8)], cor_maos)
		_poligono([Vector2(5, 4), Vector2(9, 3), Vector2(9, 8), Vector2(5, 8)], cor_maos)
	if not cabeca.is_empty():
		var cor_cabeca := _cor_peca(cabeca)
		_poligono([Vector2(-6, -9), Vector2(-5, -13), Vector2(5, -13), Vector2(6, -9), Vector2(4, -5), Vector2(-4, -5)], cor_cabeca)
		# Laterais abertas para não esconder orelhas raciais.
		_poligono([Vector2(-6, -9), Vector2(-5, -13), Vector2(-2, -13), Vector2(-3, -8)], cor_cabeca)
		_poligono([Vector2(6, -9), Vector2(5, -13), Vector2(2, -13), Vector2(3, -8)], cor_cabeca)
	if not colar.is_empty():
		_poligono([Vector2(-2, -1), Vector2(0, 1), Vector2(2, -1), Vector2(1, 3), Vector2(-1, 3)], Color("#e4c66d"))
	if not bracelete.is_empty():
		_poligono([Vector2(-9, 5), Vector2(-5, 5), Vector2(-5, 7), Vector2(-9, 7)], Color("#d7b65f"))
	if not anel.is_empty():
		_poligono([Vector2(6, 7), Vector2(9, 7), Vector2(9, 9), Vector2(6, 9)], Color("#e7d17a"))
	if not secundaria.is_empty():
		var cor_escudo := Color("#98734b") if secundaria == "escudo_madeira" else Color("#9ca8b5")
		_poligono([Vector2(-11, 0), Vector2(-7, -2), Vector2(-5, 1), Vector2(-5, 9), Vector2(-9, 11), Vector2(-12, 7)], cor_escudo)
		_poligono([Vector2(-9, 2), Vector2(-7, 2), Vector2(-7, 8), Vector2(-9, 8)], Color("#e1c37c"))
	# Armas são renderizadas por ApresentacaoArma; não desenhar silhuetas genéricas.

func _cor_peca(item_id: String) -> Color:
	if item_id in ["elmo_couro", "peitoral_couro", "calcas_couro", "luvas_couro", "botas_caminhante"]:
		return Color("#80583d")
	if item_id in ["elmo_placas", "peitoral_placas", "grevas_aco", "manoplas_placas", "botas_placas"]:
		return Color("#8998a5")
	if item_id == "peitoral_malha":
		return Color("#737f89")
	return Color("#66517e")

func _apresentar_arma_equipada() -> void:
	_apresentacao_arma = APRESENTACAO_ARMA.new()
	_apresentacao_arma.name = "ApresentacaoArmaEquipada"
	add_child(_apresentacao_arma)
	_apresentacao_arma.configurar(str(equipamentos.get("mao_principal", "")), "frente")
