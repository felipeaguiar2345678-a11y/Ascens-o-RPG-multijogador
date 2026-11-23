extends Control
## Palco 2D estilizado do combate por turnos. A lógica e o resultado continuam no servidor.

var nome_heroi := "Aventureiro"
var nome_inimigo := "Criatura"
var chefe := false
var invocacao_aliada: Dictionary = {}
var inimigos: Array = []
var ataques_telegrafados: Array = []
var alvo_selecionado_id := ""
signal alvo_selecionado(individuo_id: String)
var _tempo := 0.0
var _impacto := 0.0
var _ultimo_evento := ""
var _tipo_efeito := "impacto"
var _lado_efeito := "inimigo"
var _tempo_efeito := 0.0
var _elemento_efeito := "arcano"
var _intensidade_efeito := 1.0
var contexto_celeste: Dictionary = {"periodo":"dia","faseLunar":"lua_crescente","eventoCeleste":{"id":"nenhum"}}

func _ready() -> void:
	custom_minimum_size = Vector2(0, 112)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func configurar(jogador: Dictionary, inimigo: Dictionary) -> void:
	configurar_grupo(jogador, [inimigo])

func configurar_grupo(jogador: Dictionary, lista_inimigos: Array, alvo_id: String = "", invocacao: Dictionary = {}) -> void:
	nome_heroi = str(jogador.get("nome", "Aventureiro"))
	invocacao_aliada = invocacao.duplicate(true) if bool(invocacao.get("ativa", false)) else {}
	inimigos = lista_inimigos.duplicate(true).slice(0, 3)
	alvo_selecionado_id = alvo_id if not alvo_id.is_empty() else str(inimigos[0].get("id", "")) if not inimigos.is_empty() else ""
	var primeiro: Dictionary = inimigos[0] if not inimigos.is_empty() else {}
	nome_inimigo = str(primeiro.get("nome", "Criatura"))
	chefe = bool(primeiro.get("chefe", false))
	queue_redraw()

func definir_alvo_selecionado(individuo_id: String) -> void:
	alvo_selecionado_id = individuo_id
	queue_redraw()

## Recebe apenas os ataques já anunciados pelo estado de combate do servidor.
func configurar_ataques_telegrafados(avisos: Array) -> void:
	ataques_telegrafados = avisos.duplicate(true).slice(0, 3)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var ponto := Vector2(-10000, -10000)
	if event is InputEventScreenTouch and event.pressed:
		ponto = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ponto = event.position
	else:
		return
	var posicoes := _obter_posicoes_inimigos()
	for indice in range(mini(3, inimigos.size())):
		if int(inimigos[indice].get("vida", 0)) <= 0:
			continue
		if ponto.distance_to(posicoes[indice]) <= 43.0:
			alvo_selecionado_id = str(inimigos[indice].get("id", ""))
			alvo_selecionado.emit(alvo_selecionado_id)
			queue_redraw()
			accept_event()
			return

func _obter_posicoes_inimigos() -> Array:
	var bases := [Vector2(size.x * 0.68, size.y * 0.56), Vector2(size.x * 0.86, size.y * 0.66), Vector2(size.x * 0.88, size.y * 0.43)]
	for indice in range(bases.size()):
		bases[indice].y += sin(_tempo * (2.0 + float(indice) * 0.25) + float(indice)) * 2.0
	return bases

func atualizar_contexto_celeste(contexto: Dictionary) -> void:
	contexto_celeste = contexto.duplicate(true)
	queue_redraw()

## Recebe metadados visuais de uma habilidade já validada pelo servidor.
## Intensidade altera somente a apresentação, nunca o dano real.
func configurar_efeito_habilidade(habilidade: Dictionary, intensidade: float = 1.0) -> void:
	_elemento_efeito = _normalizar_elemento(str(habilidade.get("elemento", habilidade.get("tipo", "arcano"))))
	_intensidade_efeito = clampf(intensidade, 0.35, 3.0)
	_tipo_efeito = "magia"
	_lado_efeito = "inimigo"
	_impacto = 1.0
	_tempo_efeito = 0.0
	queue_redraw()

func _normalizar_elemento(valor: String) -> String:
	var texto := valor.to_lower()
	if "buraco" in texto or "gravidade" in texto or "gravity" in texto: return "gravidade"
	if "gelo" in texto or "ice" in texto or "congel" in texto: return "gelo"
	if "raio" in texto or "eletr" in texto or "lightning" in texto or "trov" in texto: return "raio"
	if "fogo" in texto or "fire" in texto or "chama" in texto or "lava" in texto: return "fogo"
	if "terra" in texto or "pedra" in texto or "rocha" in texto: return "terra"
	if "vento" in texto or "wind" in texto: return "vento"
	if "luz" in texto or "sagrado" in texto or "holy" in texto: return "luz"
	if "sombra" in texto or "trevas" in texto or "shadow" in texto: return "sombra"
	if "agua" in texto or "água" in texto or "water" in texto: return "agua"
	return "arcano"

func registrar_evento(evento: String) -> void:
	if evento == _ultimo_evento:
		return
	_ultimo_evento = evento
	_impacto = 1.0
	_tempo_efeito = 0.0
	var texto := evento.to_lower()
	_lado_efeito = "heroi" if ("recebe" in texto or "atinge o aventureiro" in texto or "jogador sofre" in texto) else "inimigo"
	if "magia" in texto or "místico" in texto or "mistico" in texto or "feitiço" in texto or "feitico" in texto or "habilidade" in texto or "conjur" in texto:
		_tipo_efeito = "magia"
		_elemento_efeito = _normalizar_elemento(texto)
		_intensidade_efeito = 1.0
	elif "crítico" in texto or "critico" in texto:
		_tipo_efeito = "critico"
	elif "esquiv" in texto:
		_tipo_efeito = "esquiva"
	elif "defend" in texto or "bloque" in texto:
		_tipo_efeito = "defesa"
	else:
		_tipo_efeito = "fisico"
	queue_redraw()

func _process(delta: float) -> void:
	_tempo += delta
	_tempo_efeito += delta
	_impacto = move_toward(_impacto, 0.0, delta * 2.6)
	queue_redraw()

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	_desenhar_ceu_da_arena(area)
	draw_rect(Rect2(Vector2(0, size.y * 0.68), Vector2(size.x, size.y * 0.32)), Color("#242a2d"), true)
	for i in range(12):
		var x := float(i) * size.x / 11.0
		draw_line(Vector2(x, size.y * 0.68), Vector2(x - 12, size.y), Color("#4b4941", 0.35), 1.0)
	# Arcos de pedra e luzes ao fundo.
	draw_rect(Rect2(Vector2(size.x * 0.43, 8), Vector2(size.x * 0.14, size.y * 0.55)), Color("#252b35"))
	draw_rect(Rect2(Vector2(size.x * 0.47, 16), Vector2(size.x * 0.06, size.y * 0.47)), Color("#111b27"))
	draw_circle(Vector2(size.x * 0.5, 24), 7.0, Color("#d2ad65", 0.8))
	var heroi := Vector2(size.x * 0.25, size.y * 0.63 + sin(_tempo * 3.0) * 1.5)
	var progresso_acao := clampf(_tempo_efeito / 0.48, 0.0, 1.0)
	var impulso := sin(progresso_acao * PI) * _impacto
	if _impacto > 0.05 and _lado_efeito == "inimigo" and _tipo_efeito in ["fisico", "critico"]:
		heroi += Vector2(impulso * 18.0, -impulso * 3.0)
	elif _impacto > 0.05 and _lado_efeito == "heroi" and _tipo_efeito == "esquiva":
		heroi += Vector2(-impulso * 15.0, -impulso * 4.0)
	_desenhar_heroi(heroi)
	if not invocacao_aliada.is_empty():
		var posicao_invocacao := Vector2(size.x * 0.43, size.y * 0.64 + sin(_tempo * 2.5) * 1.5)
		_desenhar_inimigo(posicao_invocacao, false, invocacao_aliada)
	var posicoes := _obter_posicoes_inimigos()
	var posicao_alvo: Vector2 = posicoes[0]
	for indice in range(mini(3, inimigos.size())):
		var inimigo: Dictionary = inimigos[indice]
		var posicao: Vector2 = posicoes[indice]
		if str(inimigo.get("id", "")) == alvo_selecionado_id:
			posicao_alvo = posicao
		if _impacto > 0.05 and _lado_efeito == "heroi" and str(inimigo.get("id", "")) == alvo_selecionado_id and _tipo_efeito in ["fisico", "critico"]:
			posicao += Vector2(-impulso * 12.0, 0.0)
		if int(inimigo.get("vida", 0)) > 0:
			if str(inimigo.get("id", "")) == alvo_selecionado_id:
				draw_arc(posicao + Vector2(0, 2), 24.0, 0.0, TAU, 32, Color("#f4d16b"), 2.5)
			_desenhar_inimigo(posicao, bool(inimigo.get("chefe", false)), inimigo)
	_desenhar_avisos_especiais(heroi, posicoes)
	if _impacto > 0.05:
		_desenhar_efeito_ataque(heroi, posicao_alvo)
	var fonte := ThemeDB.fallback_font
	if fonte:
		draw_string(fonte, Vector2(8, 14), nome_heroi, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.35, 10, Color("#e7d5b2"))
		if not invocacao_aliada.is_empty():
			draw_string(fonte, Vector2(size.x * 0.40, 14), str(invocacao_aliada.get("nome", "Invocação")), HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.22, 9, Color("#9bd5bd"))
		for indice in range(mini(3, inimigos.size())):
			var x := size.x * (0.62 + float(indice) * 0.12)
			draw_string(fonte, Vector2(x, 14), str(inimigos[indice].get("nome", "Criatura")), HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.3, 9, Color("#f0b3a0"))



func _desenhar_ceu_da_arena(area: Rect2) -> void:
	var periodo := str(contexto_celeste.get("periodo", "dia"))
	var evento: Dictionary = contexto_celeste.get("eventoCeleste", {})
	var evento_id := str(evento.get("id", "nenhum"))
	var base := Color("#5b91bd")
	match periodo:
		"crepusculo": base = Color("#bd795e")
		"noite": base = Color("#111b35")
		"madrugada": base = Color("#293957")
	draw_rect(area, base, true)
	var faixa := Color("#f4bd79", 0.22) if periodo == "crepusculo" else Color("#8bb9dc", 0.12) if periodo == "dia" else Color("#7288bd", 0.12)
	for i in range(5):
		draw_rect(Rect2(0, float(i) * area.size.y * 0.13, area.size.x, area.size.y * 0.13), Color(faixa, 1.0 - float(i) * 0.17), true)
	if periodo in ["noite", "madrugada", "crepusculo"]:
		for i in range(24):
			var px := fposmod(float(i * 67 + 23), maxf(1.0, area.size.x))
			var py := fposmod(float(i * 31 + 9), maxf(1.0, area.size.y * 0.52))
			var brilho := 0.45 + 0.35 * absf(sin(_tempo * 1.7 + float(i)))
			draw_circle(Vector2(px, py), 0.8 + float(i % 3) * 0.35, Color("#e4eaff", brilho))
	if periodo == "dia":
		draw_circle(Vector2(area.size.x * 0.82, area.size.y * 0.2), 15.0, Color("#ffe7a1", 0.18))
		draw_circle(Vector2(area.size.x * 0.82, area.size.y * 0.2), 8.0, Color("#fff0b5"))
	else:
		var lua := Vector2(area.size.x * 0.82, area.size.y * 0.2)
		var cor_lua := Color("#e7e6d6")
		if "lua_de_sangue" in evento_id:
			cor_lua = Color("#d94d55")
		elif "lua_azul" in evento_id:
			cor_lua = Color("#83c7ff")
		elif "lua_negra" in evento_id or "eclipse" in evento_id:
			cor_lua = Color("#6d7182")
		draw_circle(lua, 12.0, Color(cor_lua, 0.2))
		draw_circle(lua, 7.0, cor_lua)
		if "eclipse" in evento_id:
			draw_circle(lua + Vector2(5, -2), 7.0, Color("#111522"))
			draw_arc(lua, 11.0, 0.0, TAU, 32, Color("#d5a95e", 0.9), 1.5)
	if "aurora_arcana" in evento_id:
		for faixa_aurora in range(3):
			var y := 12.0 + float(faixa_aurora) * 8.0 + sin(_tempo * 0.7 + float(faixa_aurora)) * 3.0
			draw_arc(Vector2(area.size.x * 0.45, y), area.size.x * (0.3 + float(faixa_aurora) * 0.06), 0.1, PI - 0.1, 36, Color("#72e0c4", 0.42 - float(faixa_aurora) * 0.08), 3.0)
	if "chuva_de_estrelas" in evento_id:
		for estrela in range(5):
			var x := fposmod(float(estrela * 83) + _tempo * 24.0, maxf(1.0, area.size.x))
			var y := 12.0 + float(estrela * 11)
			draw_line(Vector2(x, y), Vector2(x - 9, y + 5), Color("#fff0c4", 0.85), 1.2)


## Pré-visualizações animadas dos especiais: não alteram alcance, dano ou regras.
func _desenhar_avisos_especiais(heroi: Vector2, posicoes: Array) -> void:
	if ataques_telegrafados.is_empty():
		return
	var pulso := 0.55 + 0.45 * sin(_tempo * 7.0)
	for aviso in ataques_telegrafados:
		if not aviso is Dictionary:
			continue
		var efeito := str(aviso.get("efeito", aviso.get("id", ""))).to_lower()
		var cor_aviso := Color("#ffe08a", 0.72 + pulso * 0.22)
		match efeito:
			"imobilizacao", "constricao":
				# Anéis incompletos antecipam as voltas da serpente ao redor do herói.
				for volta in range(3):
					var raio := 17.0 + float(volta) * 8.0 + sin(_tempo * 5.0 + float(volta)) * 2.0
					draw_arc(heroi + Vector2(0, 1), raio, _tempo * 1.8 + float(volta) * 1.7, _tempo * 1.8 + float(volta) * 1.7 + PI * 1.45, 28, Color("#d8a64e", cor_aviso.a), 3.0)
				draw_line(heroi + Vector2(-20, 13), heroi + Vector2(-27, 21), Color("#f2cb78", cor_aviso.a), 2.0)
			"onda_area", "onda_abissal", "onda_marinha":
				# Crista azul crescente avançando do lado dos inimigos.
				var base := Vector2(size.x * 0.53, size.y * 0.69)
				var avanço := fposmod(_tempo * 0.16, 1.0)
				var crista := base + Vector2(-avanço * size.x * 0.18, -18.0 - pulso * 7.0)
				var agua := PackedVector2Array([base, crista + Vector2(-13, -10), crista + Vector2(0, -25), crista + Vector2(13, -9), base + Vector2(28, 0)])
				draw_colored_polygon(agua, Color("#2c9ed0", 0.24 + pulso * 0.13))
				draw_arc(crista, 23.0 + pulso * 5.0, PI, TAU, 24, Color("#b9f2ff", 0.9), 2.2)
				for faixa in range(2):
					draw_arc(base + Vector2(0, -float(faixa) * 5.0), 34.0 + float(faixa) * 10.0, PI + 0.2, TAU - 0.2, 24, Color("#62c9ed", 0.48), 1.5)
			"tremor_area", "tremor_tectonico", "tremor_corporal":
				# Fissuras luminosas no piso e pequenos fragmentos levantados.
				var chao := Vector2(size.x * 0.48, size.y * 0.78)
				for fissura in range(4):
					var inicio := chao + Vector2(float(fissura) * 15.0 - 22.0, 0)
					draw_line(inicio, inicio + Vector2(5, -8 - pulso * 4.0), Color("#e8b36e", 0.95), 2.0)
					draw_line(inicio + Vector2(5, -8 - pulso * 4.0), inicio + Vector2(12, -4), Color("#d18b56", 0.9), 1.8)
				for pedra in range(5):
					var x := chao.x + float(pedra) * 12.0 - 25.0
					var altura := 5.0 + fposmod(float(pedra) * 3.0 + _tempo * 8.0, 7.0)
					draw_colored_polygon(PackedVector2Array([Vector2(x - 3, chao.y), Vector2(x, chao.y - altura), Vector2(x + 4, chao.y)]), Color("#b69a78", 0.9))
			"sopro_area", "sopro_elemental", "sopro_primordial":
				# Cone de energia carregando entre a serpente e o herói.
				var origem := Vector2(size.x * 0.64, size.y * 0.48)
				var destino := heroi + Vector2(0, -8)
				var direcao := (destino - origem).normalized()
				var lateral := Vector2(-direcao.y, direcao.x)
				var abertura := 10.0 + pulso * 8.0
				var cone := PackedVector2Array([origem, destino + lateral * abertura, destino - lateral * abertura])
				draw_colored_polygon(cone, Color("#ff8a42", 0.18 + pulso * 0.12))
				draw_line(origem, destino + lateral * abertura, Color("#ffc16b", 0.85), 2.0)
				draw_line(origem, destino - lateral * abertura, Color("#ffdc9a", 0.85), 2.0)
				for brasa in range(5):
					var t := fposmod(float(brasa) * 0.19 + _tempo * 0.12, 1.0)
					var particula := origem.lerp(destino, t) + lateral * sin(_tempo * 8.0 + float(brasa)) * abertura * t
					draw_circle(particula, 1.5 + pulso, Color("#ffe3a1", 0.9))
			_:
				# Ataques especiais sem arte específica recebem um aviso visual neutro.
				draw_arc(heroi, 28.0 + pulso * 4.0, 0.0, TAU, 28, cor_aviso, 2.0)

func _desenhar_efeito_ataque(heroi: Vector2, inimigo: Vector2) -> void:
	var alvo := heroi if _lado_efeito == "heroi" else inimigo
	var origem := inimigo if _lado_efeito == "heroi" else heroi
	var progresso := clampf(_tempo_efeito / 0.48, 0.0, 1.0)
	var opacidade := _impacto
	if _tipo_efeito == "esquiva":
		var deslocamento := Vector2(-12 if _lado_efeito == "heroi" else 12, -5)
		draw_arc(alvo + deslocamento, 12.0 + progresso * 5.0, -1.2, 1.2, 18, Color("#9bd9e8", opacidade), 2.0)
		draw_line(alvo + deslocamento + Vector2(-5, -8), alvo + deslocamento + Vector2(5, 8), Color("#d7f4ff", opacidade), 2.0)
		return
	if _tipo_efeito == "defesa":
		draw_arc(alvo + Vector2(0, -5), 18.0, PI, TAU, 24, Color("#8fb9cf", opacidade), 3.0)
		draw_line(alvo + Vector2(-12, -5), alvo + Vector2(0, -18), Color("#d7e8f0", opacidade), 2.0)
		draw_line(alvo + Vector2(0, -18), alvo + Vector2(12, -5), Color("#d7e8f0", opacidade), 2.0)
		return
	if _tipo_efeito == "magia":
		_desenhar_efeito_elemental(origem, alvo, progresso, opacidade)
		return
	var cor_corte := Color("#ffe2a1") if _tipo_efeito == "critico" else Color("#e9d3b2")
	var direcao := (alvo - origem).normalized()
	var centro := alvo + Vector2(0, -8)
	var abertura := 12.0 + (1.0 - progresso) * 10.0
	var corte_inicio := centro + Vector2(-abertura, -8 + progresso * 5.0)
	var corte_fim := centro + Vector2(abertura, 8 - progresso * 5.0)
	draw_line(corte_inicio, corte_fim, cor_corte * Color(1, 1, 1, opacidade), 2.5 if _tipo_efeito == "critico" else 1.8)
	draw_line(centro + Vector2(-abertura, 8), centro + Vector2(abertura, -8), Color("#fff4d5", opacidade * 0.8), 1.2)
	if _tipo_efeito == "critico":
		draw_arc(centro, 10.0 + progresso * 13.0, 0.0, TAU, 24, Color("#ffcf6b", opacidade * 0.9), 2.0)
	if _tipo_efeito == "critico":
		for i in range(4):
			var angulo := float(i) * TAU / 4.0 + _tempo_efeito * 5.0
			var raio := 13.0 + progresso * 8.0
			draw_circle(centro + Vector2(cos(angulo), sin(angulo)) * raio, 1.8, Color("#ffd36f", opacidade))

## Efeitos procedurais distintos. Elementos desconhecidos usam o efeito arcano.
func _desenhar_efeito_elemental(origem: Vector2, alvo: Vector2, progresso: float, opacidade: float) -> void:
	var escala := 0.75 + _intensidade_efeito * 0.42
	var ponto := origem.lerp(alvo, clampf(progresso * 1.18, 0.0, 1.0))
	var centro := alvo + Vector2(0, -12)
	var pulso := 0.5 + 0.5 * sin(_tempo_efeito * 19.0)
	var tremor := Vector2.ZERO
	if _intensidade_efeito >= 1.35:
		tremor = Vector2(sin(_tempo_efeito * 83.0), cos(_tempo_efeito * 71.0)) * minf(3.5, _intensidade_efeito * 1.2) * opacidade
	draw_set_transform(tremor, 0.0, Vector2.ONE)
	match _elemento_efeito:
		"gravidade":
			var raio := (7.0 + progresso * 17.0) * escala
			draw_circle(centro, raio + 8.0 * escala, Color("#6d43a8", opacidade * 0.16))
			draw_circle(centro, raio, Color("#080711", opacidade * 0.96))
			draw_arc(centro, raio + 5.0 * escala, _tempo_efeito * 3.0, _tempo_efeito * 3.0 + TAU * 0.82, 48, Color("#b78aff", opacidade), 2.0 * escala)
			draw_arc(centro, raio + 10.0 * escala, -_tempo_efeito * 2.2, -_tempo_efeito * 2.2 + TAU * 0.68, 48, Color("#65d8ef", opacidade * 0.8), 1.5 * escala)
			for i in range(8):
				var angulo := float(i) * TAU / 8.0 + _tempo_efeito * (2.0 + _intensidade_efeito)
				var particula := centro + Vector2(cos(angulo), sin(angulo)) * (raio + 13.0 * escala)
				draw_line(particula, centro + (particula - centro) * 0.35, Color("#a98bdf", opacidade * 0.65), 1.5 * escala)
		"gelo":
			draw_line(origem, ponto, Color("#3c9bd8", opacidade * 0.45), 8.0 * escala)
			draw_line(origem, ponto, Color("#8eeaff", opacidade), 2.2 * escala)
			for i in range(6):
				var angulo := float(i) * TAU / 6.0
				var ponta := centro + Vector2(cos(angulo), sin(angulo)) * (10.0 + 8.0 * pulso) * escala
				draw_line(centro, ponta, Color("#d8fbff", opacidade), 2.0 * escala)
			for i in range(5):
				var t := fposmod(float(i) * 0.21 + progresso, 1.0)
				var cristal := origem.lerp(alvo, t)
				draw_colored_polygon(PackedVector2Array([cristal + Vector2(0, -5), cristal + Vector2(3, 0), cristal + Vector2(0, 6), cristal + Vector2(-3, 0)]), Color("#d8fbff", opacidade))
		"raio":
			var anterior := origem
			for i in range(1, 9):
				var base := origem.lerp(ponto, float(i) / 8.0)
				var atual := base + Vector2(0, sin(_tempo_efeito * 43.0 + float(i) * 2.1) * 7.0 * escala)
				draw_line(anterior, atual, Color("#4c79ff", opacidade * 0.8), 5.0 * escala)
				draw_line(anterior, atual, Color("#e3f8ff", opacidade), 1.8 * escala)
				anterior = atual
			draw_circle(centro, 7.0 * escala + pulso * 5.0, Color("#a8dfff", opacidade * 0.45))
		"fogo":
			draw_line(origem, ponto, Color("#c52d22", opacidade * 0.55), 10.0 * escala)
			draw_line(origem, ponto, Color("#ff9b36", opacidade), 5.0 * escala)
			draw_line(origem, ponto, Color("#fff0a8", opacidade * 0.9), 1.8 * escala)
			for i in range(9):
				var t := fposmod(float(i) * 0.13 + progresso, 1.0)
				var chama := origem.lerp(alvo, t) + Vector2(sin(_tempo_efeito * 18.0 + float(i)) * 5.0, cos(_tempo_efeito * 21.0 + float(i)) * 4.0)
				draw_circle(chama, (2.0 + pulso * 2.0) * escala, Color("#ffd36b", opacidade))
			draw_circle(centro, (8.0 + pulso * 8.0) * escala, Color("#ff6a32", opacidade * 0.35))
		"terra":
			for i in range(5):
				var x := centro.x + (float(i) - 2.0) * 7.0 * escala
				var altura := (9.0 + float((i * 7) % 11) + progresso * 9.0) * escala
				draw_colored_polygon(PackedVector2Array([Vector2(x - 4, centro.y + 5), Vector2(x, centro.y - altura), Vector2(x + 5, centro.y + 5)]), Color("#a58a62", opacidade))
			draw_arc(centro, 17.0 * escala, PI, TAU, 24, Color("#d8b77e", opacidade), 2.0 * escala)
		"vento":
			for i in range(5):
				var y := centro.y + (float(i) - 2.0) * 5.0 * escala
				var curva := sin(_tempo_efeito * 11.0 + float(i)) * 8.0 * escala
				draw_line(origem + Vector2(0, y - centro.y), ponto + Vector2(curva, y - centro.y), Color("#c8f4e7", opacidade * (0.45 + pulso * 0.45)), 1.4 * escala)
		"luz":
			draw_circle(centro, (10.0 + pulso * 12.0) * escala, Color("#fff2ad", opacidade * 0.22))
			draw_arc(centro, 15.0 * escala, _tempo_efeito * 1.5, _tempo_efeito * 1.5 + TAU, 32, Color("#fff6d2", opacidade), 2.0 * escala)
			for i in range(8):
				var angulo := float(i) * TAU / 8.0
				draw_line(centro, centro + Vector2(cos(angulo), sin(angulo)) * 22.0 * escala, Color("#fff0a1", opacidade * 0.8), 1.5 * escala)
		"sombra":
			draw_circle(centro, (13.0 + pulso * 9.0) * escala, Color("#160d28", opacidade * 0.82))
			draw_arc(centro, 19.0 * escala, _tempo_efeito * 2.5, _tempo_efeito * 2.5 + TAU * 0.72, 36, Color("#a46be8", opacidade), 2.0 * escala)
			for i in range(6):
				var angulo := float(i) * TAU / 6.0 - _tempo_efeito * 2.0
				var fim := centro + Vector2(cos(angulo), sin(angulo)) * 25.0 * escala
				draw_line(fim, centro, Color("#5c3a87", opacidade * 0.8), 2.0 * escala)
		"agua":
			draw_line(origem, ponto, Color("#277fca", opacidade * 0.45), 8.0 * escala)
			draw_line(origem, ponto, Color("#9deaff", opacidade), 2.0 * escala)
			for i in range(4):
				var onda := 8.0 + float(i) * 5.0 + pulso * 3.0
				draw_arc(centro, onda * escala, 0.1, PI - 0.1, 24, Color("#8adfff", opacidade * 0.75), 1.5 * escala)
		_:
			draw_line(origem, ponto, Color("#8069d8", opacidade * 0.6), 4.0 * escala)
			draw_circle(ponto, (5.0 + pulso * 3.0) * escala, Color("#a8dfff", opacidade))
			draw_arc(ponto, (10.0 + progresso * 8.0) * escala, _tempo_efeito, _tempo_efeito + TAU, 28, Color("#d9b8ff", opacidade), 2.0 * escala)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _desenhar_heroi(p: Vector2) -> void:
	var sombra := Color("#090d12", 0.55)
	draw_ellipse_placeholder(p + Vector2(0, 8), Vector2(17, 5), sombra)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -5), p + Vector2(8, -5), p + Vector2(7, 14), p + Vector2(-7, 14)]), Color("#53677a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -4), p + Vector2(0, -9), p + Vector2(6, -4), p + Vector2(5, 5), p + Vector2(-5, 5)]), Color("#b38b59"))
	draw_rect(Rect2(p + Vector2(-5, -23), Vector2(10, 10)), Color("#d8b58a"))
	draw_rect(Rect2(p + Vector2(-6, -25), Vector2(12, 4)), Color("#403b38"))
	draw_line(p + Vector2(8, -3), p + Vector2(18, -19), Color("#cbd3d7"), 3.0)
	draw_line(p + Vector2(5, 0), p + Vector2(15, -12), Color("#78583d"), 2.0)
	draw_line(p + Vector2(-4, 13), p + Vector2(-7, 24), Color("#8a7156"), 4.0)
	draw_line(p + Vector2(4, 13), p + Vector2(7, 24), Color("#8a7156"), 4.0)

func _desenhar_inimigo(p: Vector2, eh_chefe: bool = false, dados: Dictionary = {}) -> void:
	var escala := 1.25 if eh_chefe else 1.0
	var especie := str(dados.get("especieId", dados.get("nome", "criatura")))
	var identidade_individuo := str(dados.get("id", dados.get("individuoId", "")))
	var variacao := absi((especie + ":" + identidade_individuo).hash()) % 4
	var paleta := [Color("#71865b"), Color("#668da0"), Color("#9b765e"), Color("#8972a8")]
	var corpo: Color = paleta[variacao]
	var sombra := corpo.darkened(0.38)
	var luz := corpo.lightened(0.28)
	if eh_chefe:
		corpo = Color("#9b4f53")
		sombra = Color("#542e45")
		luz = Color("#e0a36e")
	draw_circle(p + Vector2(0, 5), 19.0 * escala, Color("#080d12", 0.48))
	match variacao:
		0:
			# Criatura quadrúpede, com focinho e patas robustas.
			draw_colored_polygon(PackedVector2Array([p + Vector2(-15, -9) * escala, p + Vector2(11, -11) * escala, p + Vector2(17, 5) * escala, p + Vector2(10, 13) * escala, p + Vector2(-14, 11) * escala]), corpo)
			draw_circle(p + Vector2(11, -15) * escala, 9.0 * escala, luz)
			for lado in [-1.0, 1.0]:
				draw_line(p + Vector2(lado * 9, 7) * escala, p + Vector2(lado * 12, 20) * escala, sombra, 4.0 * escala)
			draw_line(p + Vector2(-15, -4) * escala, p + Vector2(-23, -12) * escala, sombra, 3.0 * escala)
		1:
			# Criatura alada, corpo estreito e asas abertas.
			draw_colored_polygon(PackedVector2Array([p + Vector2(-7, -7) * escala, p + Vector2(7, -7) * escala, p + Vector2(10, 13) * escala, p + Vector2(-10, 13) * escala]), corpo)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -3) * escala, p + Vector2(-27, -22) * escala, p + Vector2(-20, 4) * escala]), luz)
			draw_colored_polygon(PackedVector2Array([p + Vector2(5, -3) * escala, p + Vector2(27, -22) * escala, p + Vector2(20, 4) * escala]), luz)
			draw_circle(p + Vector2(0, -14) * escala, 8.0 * escala, corpo.lightened(0.18))
		2:
			# Criatura alongada, serpentina.
			draw_colored_polygon(PackedVector2Array([p + Vector2(-18, 9) * escala, p + Vector2(-7, -1) * escala, p + Vector2(7, 1) * escala, p + Vector2(19, -13) * escala, p + Vector2(23, -7) * escala, p + Vector2(10, 9) * escala, p + Vector2(-5, 13) * escala]), corpo)
			draw_circle(p + Vector2(18, -17) * escala, 8.0 * escala, luz)
			draw_line(p + Vector2(-14, 8) * escala, p + Vector2(-25, 15) * escala, sombra, 4.0 * escala)
		3:
			# Criatura pesada, couraçada e com chifres.
			draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -9) * escala, p + Vector2(0, -15) * escala, p + Vector2(16, -9) * escala, p + Vector2(18, 10) * escala, p + Vector2(9, 16) * escala, p + Vector2(-12, 16) * escala, p + Vector2(-19, 7) * escala]), corpo)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -11) * escala, p + Vector2(-18, -25) * escala, p + Vector2(-3, -17) * escala]), luz)
			draw_colored_polygon(PackedVector2Array([p + Vector2(10, -11) * escala, p + Vector2(18, -25) * escala, p + Vector2(3, -17) * escala]), luz)
			draw_line(p + Vector2(-12, 2) * escala, p + Vector2(12, 2) * escala, sombra, 3.0 * escala)
	draw_circle(p + Vector2(18.0 if variacao == 2 else 0.0, -15.0) * escala, 2.2 * escala, Color("#f4d16b"))
	if variacao != 2:
		draw_circle(p + Vector2(4, -15) * escala, 2.2 * escala, Color("#f4d16b"))
	if eh_chefe:
		draw_arc(p + Vector2(0, -18) * escala, 17.0 * escala, PI + 0.2, TAU - 0.2, 20, Color("#f4d16b"), 2.0)

func draw_ellipse_placeholder(centro: Vector2, raios: Vector2, cor: Color) -> void:
	draw_set_transform(centro, 0.0, Vector2(raios.x / 8.0, raios.y / 8.0))
	draw_circle(Vector2.ZERO, 8.0, cor)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
