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
var _estilo_combo_companheiro := "vinculo"
var _suprema_efeito: Dictionary = {}
var _efeito_arma_normal: Dictionary = {}
var _tempo_arma_normal := 99.0
var _tempo_suprema := 99.0
var contexto_celeste: Dictionary = {"periodo":"dia","faseLunar":"lua_crescente","eventoCeleste":{"id":"nenhum"}}
var _marcas_destruicao_cenario: Array[Dictionary] = []

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
	_tipo_efeito = "combo_companheiro" if str(habilidade.get("tipoEfeito", "")) == "combo_companheiro" else "magia"
	_estilo_combo_companheiro = obter_estilo_combo_companheiro(habilidade)
	_lado_efeito = "inimigo"
	_impacto = 1.0
	_tempo_efeito = 0.0
	queue_redraw()

static func obter_estilo_combo_companheiro(dados: Dictionary) -> String:
	var estilo := str(dados.get("estiloCombo", "")).to_lower()
	if estilo in ["cacada", "constricao", "mergulho", "investida", "elemental"]:
		return estilo
	var especie := str(dados.get("especie", dados.get("familia", ""))).to_lower()
	var elemento := str(dados.get("elemento", "")).to_lower()
	if "serp" in especie or "cobra" in especie:
		return "constricao"
	if "ave" in especie or "drag" in especie or "asa" in especie:
		return "mergulho"
	if elemento in ["fogo", "gelo", "raio", "agua", "água", "luz", "sombra"]:
		return "elemental"
	if "lobo" in especie or "felino" in especie:
		return "cacada"
	return "investida"

static func _normalizar_elemento(valor: String) -> String:
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
	if "combo de vínculo" in texto:
		_tipo_efeito = "combo_companheiro"
	elif "magia" in texto or "místico" in texto or "mistico" in texto or "feitiço" in texto or "feitico" in texto or "habilidade" in texto or "conjur" in texto:
		_tipo_efeito = "magia"
		_elemento_efeito = _normalizar_elemento(texto)
		_intensidade_efeito = 1.0
	elif "crítico" in texto or "critico" in texto:
		_tipo_efeito = "critico"
	elif "esquiv" in texto:
		_tipo_efeito = "esquiva"
	elif "defend" in texto or "bloque" in texto:
		_tipo_efeito = "defesa"
	elif "executa" in texto and ("constrição" in texto or "constricao" in texto):
		_tipo_efeito = "constricao"
	elif "executa" in texto and "onda" in texto:
		_tipo_efeito = "onda_abissal"
	elif "executa" in texto and "tremor" in texto:
		_tipo_efeito = "tremor_tectonico"
	elif "executa" in texto and "sopro" in texto:
		_tipo_efeito = "sopro_elemental"
		_elemento_efeito = _normalizar_elemento(texto)
	else:
		_tipo_efeito = "fisico"
	if chefe and _tipo_efeito in ["onda_abissal", "tremor_tectonico", "sopro_elemental"]:
		_registrar_destruicao_cenario(_tipo_efeito, _elemento_efeito)
	queue_redraw()

func _process(delta: float) -> void:
	_tempo += delta
	_tempo_efeito += delta
	_tempo_suprema += delta
	_tempo_arma_normal += delta
	for indice in range(_marcas_destruicao_cenario.size() - 1, -1, -1):
		_marcas_destruicao_cenario[indice]["idade"] = float(_marcas_destruicao_cenario[indice].get("idade", 0.0)) + delta
		if float(_marcas_destruicao_cenario[indice]["idade"]) >= 18.0:
			_marcas_destruicao_cenario.remove_at(indice)
	_impacto = move_toward(_impacto, 0.0, delta * 2.6)
	queue_redraw()

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	_desenhar_ceu_da_arena(area)
	draw_rect(Rect2(Vector2(0, size.y * 0.68), Vector2(size.x, size.y * 0.32)), Color("#242a2d"), true)
	for i in range(12):
		var x := float(i) * size.x / 11.0
		draw_line(Vector2(x, size.y * 0.68), Vector2(x - 12, size.y), Color("#4b4941", 0.35), 1.0)
	_desenhar_marcas_destruicao_cenario()
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
			_desenhar_indicadores_status(posicao, inimigo.get("efeitosStatus", []))
	_desenhar_avisos_especiais(heroi, posicoes)
	if not _efeito_arma_normal.is_empty() and _tempo_arma_normal < 0.72:
		_desenhar_efeito_arma_normal()
	if not _suprema_efeito.is_empty() and _tempo_suprema < 3.2:
		_desenhar_efeito_suprema()
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
				var avanco := fposmod(_tempo * 0.16, 1.0)
				var crista := base + Vector2(-avanco * size.x * 0.18, -18.0 - pulso * 7.0)
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
				# O elemento do aviso colore a carga; o cone delimita a área antes do impacto.
				var elemento := _normalizar_elemento(str(aviso.get("elemento", "fogo")))
				var cor_sopro := _cor_elemento(elemento)
				var origem := Vector2(size.x * 0.64, size.y * 0.48)
				var destino := heroi + Vector2(0, -8)
				var direcao := (destino - origem).normalized()
				var lateral := Vector2(-direcao.y, direcao.x)
				var abertura := 11.0 + pulso * 10.0
				var cone_externo := PackedVector2Array([origem, destino + lateral * abertura, destino - lateral * abertura])
				var cone_interno := PackedVector2Array([origem.lerp(destino, 0.18), destino + lateral * abertura * 0.42, destino - lateral * abertura * 0.42])
				draw_colored_polygon(cone_externo, Color(cor_sopro, 0.13 + pulso * 0.12))
				draw_colored_polygon(cone_interno, Color(cor_sopro.lightened(0.35), 0.10 + pulso * 0.12))
				draw_line(origem, destino + lateral * abertura, Color(cor_sopro, 0.9), 2.2)
				draw_line(origem, destino - lateral * abertura, Color(cor_sopro.lightened(0.4), 0.9), 2.2)
				draw_arc(origem, 7.0 + pulso * 4.0, 0.0, TAU, 24, Color(cor_sopro.lightened(0.55), 0.95), 2.0)
				for particula in range(7):
					var t := fposmod(float(particula) * 0.15 + _tempo * 0.18, 1.0)
					var desvio := sin(_tempo * 9.0 + float(particula)) * abertura * t
					var ponto := origem.lerp(destino, t) + lateral * desvio
					draw_circle(ponto, 1.4 + pulso * 1.2, Color(cor_sopro.lightened(0.5), 0.92))
			_:
				# Ataques especiais sem arte específica recebem um aviso visual neutro.
				draw_arc(heroi, 28.0 + pulso * 4.0, 0.0, TAU, 28, cor_aviso, 2.0)

## Recebe o pacote visual confirmado pelo servidor; não calcula dano.
func configurar_efeito_suprema(dados: Dictionary) -> void:
	if dados.is_empty():
		return
	_suprema_efeito = dados.duplicate(true)
	_tempo_suprema = 0.0
	_impacto = 1.0
	_registrar_destruicao_cenario("tremor_tectonico", "gravidade")
	queue_redraw()

## Metadados enviados pelo servidor após um ataque normal validado.
func configurar_efeito_ataque_arma(dados: Dictionary) -> void:
	if dados.is_empty():
		return
	_efeito_arma_normal = dados.duplicate(true)
	_tempo_arma_normal = 0.0
	_impacto = 0.72
	_tempo_efeito = 0.0
	_lado_efeito = "inimigo"
	queue_redraw()

func _desenhar_efeito_arma_normal() -> void:
	var progresso := clampf(_tempo_arma_normal / 0.72, 0.0, 1.0)
	var opacidade := 0.78 * (1.0 - progresso) * clampf(float(_efeito_arma_normal.get("intensidadeVisual", 0.14)), 0.05, 1.15)
	var centro := Vector2(size.x * 0.66, size.y * 0.55)
	var tipo := str(_efeito_arma_normal.get("efeito", "corte"))
	match tipo:
		"haki_do_rei":
			for i in range(3):
				var raio := 12.0 + float(i) * 9.0 + progresso * 18.0
				draw_arc(centro, raio, -0.9, PI + 0.9, 32, Color("#211b2b", opacidade), 2.2)
			for i in range(5):
				var x := centro.x - 18.0 + float(i) * 9.0
				var ponta := Vector2(x + sin(_tempo_arma_normal * 32.0 + float(i)) * 5.0, centro.y - 20.0 - float(i % 2) * 8.0)
				draw_line(Vector2(x, centro.y + 12.0), ponta, Color("#d34c65", opacidade * 0.85), 1.8)
		"tremor":
			for i in range(3):
				var raio := 10.0 + float(i) * 12.0 + progresso * 20.0
				draw_arc(centro, raio, -0.35, PI + 0.35, 40, Color("#d9f4ff", opacidade * (1.0 - float(i) * 0.16)), 2.0)
			for i in range(4):
				var x := size.x * (0.53 + float(i) * 0.065)
				draw_line(Vector2(x, size.y * 0.26), Vector2(x + sin(_tempo_arma_normal * 25.0 + float(i)) * 4.0, size.y * 0.79), Color("#b9e8f8", opacidade * 0.75), 1.5)
		"corte_negro":
			draw_line(centro + Vector2(-28.0, 19.0), centro + Vector2(28.0, -19.0), Color("#11151e", opacidade), 5.0)
			draw_line(centro + Vector2(-25.0, 21.0), centro + Vector2(25.0, -17.0), Color("#d7e3f0", opacidade * 0.8), 1.5)
		"energia_espacial":
			for i in range(2):
				draw_arc(centro, 15.0 + float(i) * 12.0 + progresso * 12.0, 0.0, TAU, 36, Color("#69c9ef", opacidade * (1.0 - float(i) * 0.25)), 2.0)
		"haki_roxo":
			draw_arc(centro, 18.0 + progresso * 16.0, 0.0, TAU, 32, Color("#a77be8", opacidade), 2.4)
		"energia_carmesim":
			draw_arc(centro, 16.0 + progresso * 14.0, -0.7, PI + 0.7, 32, Color("#d94d59", opacidade), 2.4)
		"corte_dourado":
			draw_line(centro + Vector2(-26.0, 18.0), centro + Vector2(26.0, -18.0), Color("#e9c66f", opacidade), 3.2)
			draw_arc(centro, 20.0 + progresso * 12.0, -0.8, PI + 0.8, 32, Color("#fff0b8", opacidade * 0.7), 1.4)
		"aura_negra":
			for i in range(3):
				draw_arc(centro, 12.0 + float(i) * 8.0 + progresso * 10.0, 0.0, TAU, 32, Color("#34394b", opacidade * (1.0 - float(i) * 0.18)), 2.4)
		"vento_celeste", "vento_cortante":
			for i in range(4):
				var y := centro.y - 18.0 + float(i) * 10.0
				draw_line(Vector2(centro.x - 28.0, y + 8.0), Vector2(centro.x + 25.0, y - 8.0), Color("#a9e4df", opacidade * (1.0 - float(i) * 0.12)), 1.8)
		"raio_sombrio":
			for i in range(4):
				var x := centro.x - 18.0 + float(i) * 12.0
				draw_line(Vector2(x, centro.y - 22.0), Vector2(x + 5.0, centro.y - 8.0), Color("#9b80ed", opacidade), 2.0)
				draw_line(Vector2(x + 5.0, centro.y - 8.0), Vector2(x - 2.0, centro.y + 8.0), Color("#d8c7ff", opacidade), 1.5)
		"chama_azul":
			for i in range(3):
				draw_arc(centro + Vector2(0, 4.0), 10.0 + float(i) * 8.0, PI, TAU, 24, Color("#70c9f5", opacidade * (1.0 - float(i) * 0.18)), 2.5)
		"corte_doce":
			draw_line(centro + Vector2(-25.0, 15.0), centro + Vector2(25.0, -15.0), Color("#ef9fc8", opacidade), 3.0)
			draw_circle(centro + Vector2(20.0, -13.0), 3.0, Color("#ffe0ed", opacidade))
		"corte_fino":
			draw_line(centro + Vector2(-30.0, 0.0), centro + Vector2(30.0, 0.0), Color("#dce7f0", opacidade), 1.4)
		"onda_sonica":
			for i in range(4):
				draw_arc(centro, 8.0 + float(i) * 8.0 + progresso * 12.0, -0.7, 0.7, 24, Color("#c8e8f3", opacidade * (1.0 - float(i) * 0.15)), 1.8)
		"gravidade", "energia_ancestral":
			for i in range(3):
				draw_arc(centro, 12.0 + float(i) * 9.0 + progresso * 9.0, 0.0, TAU, 32, Color("#b59ae8" if tipo == "gravidade" else "#e4c17c", opacidade * (1.0 - float(i) * 0.15)), 2.0)
		"haki_dourado":
			draw_arc(centro, 17.0 + progresso * 14.0, -0.6, PI + 0.6, 32, Color("#edcf82", opacidade), 2.8)
		"impacto_zou":
			for i in range(3):
				draw_arc(centro, 9.0 + float(i) * 11.0 + progresso * 12.0, -0.3, PI + 0.3, 32, Color("#b7c6b1", opacidade), 2.0)
		"corte_triplo":
			for i in range(3):
				var deslocamento := float(i - 1) * 7.0
				draw_line(centro + Vector2(-22.0, 13.0 + deslocamento), centro + Vector2(22.0, -13.0 + deslocamento), Color("#e8e1d4", opacidade * (1.0 - float(i) * 0.12)), 2.0)
		_:
			draw_line(centro + Vector2(-18.0, 12.0), centro + Vector2(18.0, -12.0), Color("#f2dfb7", opacidade), 2.0)
	# Marcos de maestria acrescentam técnica visual sem alterar dano ou raridade.
	var nivel_maestria := clampi(int(_efeito_arma_normal.get("nivelMaestria", 1)), 1, 50)
	var brilho_marco := clampf(opacidade * 1.8, 0.08, 0.72)
	if nivel_maestria >= 5:
		draw_line(centro + Vector2(-34.0, 22.0), centro + Vector2(34.0, -22.0), Color("#fff0c2", brilho_marco * 0.8), 1.4)
	if nivel_maestria >= 10:
		draw_line(centro + Vector2(-29.0, 27.0), centro + Vector2(29.0, -27.0), Color("#f2d58d", brilho_marco * 0.72), 1.2)
		draw_arc(centro, 25.0 + progresso * 7.0, -0.9, 0.9, 24, Color("#fff0c2", brilho_marco * 0.75), 1.3)
	if nivel_maestria >= 20:
		for anel in range(2):
			draw_arc(centro, 31.0 + float(anel) * 8.0 + progresso * 8.0, 0.0, TAU, 36, Color("#e8d6a8", brilho_marco * (0.58 - float(anel) * 0.12)), 1.2)
	if nivel_maestria >= 35:
		for particula in range(4):
			var angulo := float(particula) * TAU / 4.0 + _tempo_arma_normal * 4.0
			var ponto := centro + Vector2(cos(angulo), sin(angulo)) * (29.0 + progresso * 5.0)
			draw_circle(ponto, 2.0, Color("#fff1c8", brilho_marco * 0.85))
	if nivel_maestria >= 50:
		draw_arc(centro, 43.0 + sin(_tempo_arma_normal * 12.0) * 2.0, 0.0, TAU, 48, Color("#f7d98c", brilho_marco), 2.0)
		draw_arc(centro, 48.0, -0.8, 0.8, 24, Color("#fff4d2", brilho_marco * 0.8), 1.4)

func _desenhar_efeito_suprema() -> void:
	var progresso := clampf(_tempo_suprema / 3.2, 0.0, 1.0)
	var pulso := sin(progresso * PI)
	var centro := Vector2(size.x * 0.61, size.y * 0.57)
	var tipo := str(_suprema_efeito.get("efeito", ""))
	if tipo == "terremoto_dimensional":
		# A Gura Gura distorce o espaço em camadas, como uma onda sísmica.
		for camada in range(5):
			var fase := fposmod(progresso * 1.7 + float(camada) * 0.19, 1.0)
			var raio := 14.0 + fase * size.x * 0.68
			var alpha := (1.0 - fase) * (0.48 + pulso * 0.3)
			draw_arc(centro, raio, -0.28, PI + 0.28, 64, Color("#dff8ff", alpha), 3.0 + pulso * 2.0)
			draw_arc(centro, raio * 0.78, PI + 0.5, TAU - 0.5, 48, Color("#9bd9f2", alpha * 0.55), 1.6)
		for fissura in range(9):
			var x := size.x * (0.12 + float(fissura) * 0.095)
			var deslocamento := sin(_tempo_suprema * 18.0 + float(fissura)) * (5.0 + pulso * 7.0)
			var inicio := Vector2(x, size.y * 0.16)
			var meio := Vector2(x + deslocamento, size.y * 0.48)
			var fim := Vector2(x - deslocamento * 0.7, size.y * 0.86)
			draw_line(inicio, meio, Color("#e7f8ff", 0.82 * (1.0 - progresso * 0.55)), 2.2)
			draw_line(meio, fim, Color("#a8d9ee", 0.72 * (1.0 - progresso * 0.55)), 1.8)
		for fragmento in range(14):
			var angulo := float(fragmento) * TAU / 14.0 + _tempo_suprema * 1.4
			var distancia := 22.0 + fposmod(_tempo_suprema * 95.0 + float(fragmento) * 17.0, 100.0)
			var ponto := centro + Vector2(cos(angulo), sin(angulo)) * distancia
			draw_colored_polygon(PackedVector2Array([ponto, ponto + Vector2(4, -7), ponto + Vector2(9, 2)]), Color("#c8eaff", 0.62 * (1.0 - progresso)))
	elif tipo == "golpe_do_rei" or tipo == "corte_haki":
		var cor := Color("#17131f") if tipo == "corte_haki" else Color("#b52d42")
		for raio_indice in range(4):
			draw_arc(centro, 18.0 + float(raio_indice) * 19.0 + progresso * 30.0, -0.8, PI + 0.8, 48, Color(cor, 0.85 * (1.0 - progresso)), 3.0)
		for raio in range(8):
			var angulo := float(raio) * TAU / 8.0
			var fim := centro + Vector2(cos(angulo), sin(angulo)) * (40.0 + progresso * size.x * 0.35)
			draw_line(centro, fim, Color("#f0d9ff", 0.8 * (1.0 - progresso)), 2.0)
	elif tipo == "corte_colossal":
		var inicio := Vector2(size.x * 0.2, size.y * 0.8)
		var fim := Vector2(size.x * 0.9, size.y * 0.16)
		var abertura := 12.0 + progresso * 35.0
		draw_line(inicio + Vector2(0, -abertura), fim + Vector2(0, -abertura), Color("#10151e", 0.9 * (1.0 - progresso)), 7.0)
		draw_line(inicio + Vector2(0, abertura), fim + Vector2(0, abertura), Color("#c9d8e8", 0.9 * (1.0 - progresso)), 3.0)
	else:
		for anel in range(4):
			draw_arc(centro, 16.0 + float(anel) * 16.0 + progresso * 42.0, 0.0, TAU, 40, Color("#8edcf4", 0.75 * (1.0 - progresso)), 2.0)

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
	if _tipo_efeito == "combo_companheiro":
		_desenhar_combo_companheiro(alvo, progresso, opacidade)
		return
	if _tipo_efeito in ["constricao", "onda_abissal", "tremor_tectonico", "sopro_elemental"]:
		_desenhar_impacto_especial(alvo, origem, progresso, opacidade)
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

## Padrão visual de dano ao cenário. Não altera atributos nem regras do combate.
static func obter_configuracao_destruicao(tipo: String, elemento: String = "arcano") -> Dictionary:
	var paleta := {"fogo":Color("#f06a35"),"gelo":Color("#9deaff"),"raio":Color("#b7a5ff"),"agua":Color("#55bde8"),"terra":Color("#c39a69"),"vento":Color("#b8eadb"),"luz":Color("#ffe69a"),"sombra":Color("#9165bd"),"gravidade":Color("#8058b7"),"arcano":Color("#a98bdf")}
	var forma := "cratera"
	if tipo == "onda_abissal":
		forma = "erosao"
	elif tipo == "tremor_tectonico":
		forma = "fissura"
	elif tipo == "sopro_elemental":
		forma = "queimadura"
	return {"forma":forma,"cor":paleta.get(elemento, paleta["arcano"])}

func _registrar_destruicao_cenario(tipo: String, elemento: String) -> void:
	var indice := _marcas_destruicao_cenario.size()
	var configuracao := obter_configuracao_destruicao(tipo, elemento)
	var x := 0.48 + float(posmod(indice * 17 + int(_tempo * 3.0), 31)) / 100.0
	var y := 0.78 + float(posmod(indice * 7, 5)) * 0.012
	_marcas_destruicao_cenario.append({"x":x,"y":y,"tipo":tipo,"cor":configuracao.cor,"idade":0.0})
	while _marcas_destruicao_cenario.size() > 8:
		_marcas_destruicao_cenario.pop_front()

func _desenhar_marcas_destruicao_cenario() -> void:
	for marca in _marcas_destruicao_cenario:
		var idade := float(marca.get("idade", 0.0))
		var visibilidade := clampf(1.0 - idade / 18.0, 0.0, 1.0)
		var centro := Vector2(size.x * float(marca.get("x", 0.6)), size.y * float(marca.get("y", 0.78)))
		var tipo := str(marca.get("tipo", "tremor_tectonico"))
		var cor: Color = marca.get("cor", Color("#a98bdf"))
		draw_arc(centro, 10.0 + minf(idade, 5.0), 0.0, TAU, 28, Color("#171719", 0.62 * visibilidade), 3.0)
		draw_arc(centro, 7.0, 0.0, TAU, 24, Color(cor, 0.22 * visibilidade), 1.0)
		if tipo == "tremor_tectonico":
			for ramo in range(4):
				var inicio := centro + Vector2(float(ramo - 2) * 3.0, 0)
				var ponta := inicio + Vector2(float(ramo - 1) * 4.0, 7.0 + float(ramo % 2) * 4.0)
				draw_line(inicio, ponta, Color("#171719", 0.78 * visibilidade), 2.0)
		elif tipo == "onda_abissal":
			draw_arc(centro + Vector2(2, 1), 14.0, PI + 0.2, TAU - 0.2, 24, Color("#243b45", 0.65 * visibilidade), 2.0)
		else:
			for fragmento in range(5):
				var angulo := float(fragmento) * TAU / 5.0
				var fim := centro + Vector2(cos(angulo), sin(angulo)) * (12.0 + float(fragmento % 2) * 4.0)
				draw_line(centro, fim, Color("#211d1b", 0.72 * visibilidade), 2.0)
		if visibilidade > 0.15:
			draw_circle(centro, 2.0, Color(cor, 0.28 * visibilidade))

## Impacto final dos quatro especiais; a direção segue o lado atingido.
func _desenhar_impacto_especial(alvo: Vector2, origem: Vector2, progresso: float, opacidade: float) -> void:
	var centro := alvo + Vector2(0, -9)
	var pulso := sin(progresso * PI)
	match _tipo_efeito:
		"constricao":
			# As voltas se fecham no alvo e desaparecem após o aperto.
			for volta in range(3):
				var raio := (31.0 - progresso * 19.0) + float(volta) * 5.0
				var inicio := _tempo_efeito * 3.0 + float(volta) * 1.8
				draw_arc(centro, raio, inicio, inicio + PI * 1.55, 32, Color("#d7a24c", opacidade), 4.0 - progresso * 1.5)
				draw_arc(centro, raio - 3.0, inicio + PI, inicio + PI * 2.2, 24, Color("#f3d18a", opacidade * 0.8), 1.8)
		"onda_abissal":
			# Parede d'água sobe e cai sobre o alvo.
			var altura := 38.0 * sin(progresso * PI * 0.85)
			var frente := centro + Vector2(-18.0 + progresso * 12.0, -altura)
			var onda := PackedVector2Array([centro + Vector2(-29, 7), frente + Vector2(-18, -9), frente + Vector2(0, -22), frente + Vector2(17, -7), centro + Vector2(28, 7)])
			draw_colored_polygon(onda, Color("#238fc5", opacidade * 0.72))
			draw_arc(frente, 19.0 + pulso * 8.0, PI, TAU, 24, Color("#c4f5ff", opacidade), 3.0)
			for gota in range(7):
				var x := centro.x - 24.0 + float(gota) * 8.0
				var y := centro.y - altura * 0.45 - fposmod(_tempo_efeito * 48.0 + float(gota) * 9.0, 18.0)
				draw_circle(Vector2(x, y), 1.4, Color("#a8eaff", opacidade))
		"tremor_tectonico":
			# Fendas se abrem sob os pés, com estilhaços lançados para cima.
			var base := centro + Vector2(0, 22)
			for fenda in range(5):
				var x := base.x + float(fenda - 2) * 9.0
				var ponta := base + Vector2(float(fenda - 2) * 4.0, -9.0 - pulso * 13.0)
				draw_line(Vector2(x, base.y), ponta, Color("#f2a45f", opacidade), 2.5)
				draw_line(ponta, ponta + Vector2(4.0, 7.0), Color("#8f6c53", opacidade), 2.0)
			for pedra in range(6):
				var px := base.x + float(pedra - 3) * 10.0
				var py := base.y - fposmod(_tempo_efeito * 54.0 + float(pedra) * 7.0, 17.0)
				draw_colored_polygon(PackedVector2Array([Vector2(px - 3, py), Vector2(px, py - 6), Vector2(px + 4, py)]), Color("#c3a17d", opacidade))
		"sopro_elemental":
			# A explosão conserva a assinatura elemental anunciada no turno anterior.
			var cor_sopro := _cor_elemento(_elemento_efeito)
			var direcao := (alvo - origem).normalized()
			var lateral := Vector2(-direcao.y, direcao.x)
			var raio := 13.0 + progresso * 27.0
			var ponto_partida := origem.lerp(alvo, 0.72)
			var chama := PackedVector2Array([ponto_partida, centro + lateral * raio, centro - lateral * raio])
			draw_colored_polygon(chama, Color(cor_sopro, opacidade * 0.68))
			draw_colored_polygon(PackedVector2Array([ponto_partida, centro + lateral * raio * 0.42, centro - lateral * raio * 0.42]), Color(cor_sopro.lightened(0.45), opacidade * 0.42))
			draw_arc(centro, raio * 0.62, 0.0, TAU, 28, Color(cor_sopro.lightened(0.5), opacidade), 2.5)
			for particula in range(8):
				var angulo := float(particula) * TAU / 8.0 + _tempo_efeito * 7.0
				var pos := centro + Vector2(cos(angulo), sin(angulo)) * raio * 0.72
				draw_circle(pos, 1.5 + pulso, Color(cor_sopro.lightened(0.55), opacidade))

static func _cor_elemento(elemento: String) -> Color:
	match _normalizar_elemento(elemento):
		"fogo": return Color("#ff7847")
		"gelo": return Color("#8bd9f0")
		"raio": return Color("#ffe16b")
		"agua": return Color("#55bce8")
		"terra": return Color("#b68a5a")
		"vento": return Color("#a8e8d0")
		"luz": return Color("#fff0a1")
		"sombra": return Color("#a46be8")
		"gravidade": return Color("#8b7bd8")
		_: return Color("#a8dfff")

func _desenhar_combo_companheiro(alvo: Vector2, progresso: float, opacidade: float) -> void:
	var centro := alvo + Vector2(0, -12)
	var pulso := sin(progresso * PI)
	match _estilo_combo_companheiro:
		"cacada":
			for corte in range(3):
				var deslocamento := float(corte - 1) * 7.0
				draw_line(centro + Vector2(-17, -12 + deslocamento), centro + Vector2(17, 12 + deslocamento), Color("#f2d08a", opacidade), 2.5)
		"constricao":
			for volta in range(3):
				draw_arc(centro, 24.0 - progresso * 8.0 + float(volta) * 5.0, _tempo_efeito * 2.0 + float(volta), _tempo_efeito * 2.0 + float(volta) + PI * 1.55, 28, Color("#d7a24c", opacidade), 3.0)
		"mergulho":
			draw_line(centro + Vector2(-18, -23), centro, Color("#b9eaff", opacidade), 3.0)
			draw_line(centro + Vector2(18, -23), centro, Color("#b9eaff", opacidade), 3.0)
		"elemental":
			var cor: Color = _cor_elemento(_elemento_efeito)
			draw_circle(centro, 13.0 + pulso * 10.0, Color(cor, opacidade * 0.3))
			draw_arc(centro, 22.0 + pulso * 8.0, 0.0, TAU, 28, cor, 2.5)
		_:
			draw_arc(centro, 20.0 + pulso * 8.0, 0.0, TAU, 28, Color("#d9b8ff", opacidade), 2.5)
			draw_line(centro + Vector2(-15, 0), centro + Vector2(15, 0), Color("#fff0c2", opacidade), 2.0)

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

## Sinais animados dos estados persistentes; não interferem na simulação.
func _desenhar_indicadores_status(posicao: Vector2, efeitos: Array) -> void:
	var ativos := obter_indicadores_status(efeitos)
	if ativos.is_empty():
		return
	var fonte := ThemeDB.fallback_font
	var largura_total := float(ativos.size()) * 20.0
	var inicio_x := -largura_total * 0.5 + 10.0
	for indice in range(ativos.size()):
		var efeito: Dictionary = ativos[indice]
		var centro := posicao + Vector2(inicio_x + float(indice) * 20.0, -43.0 + sin(_tempo * 4.0 + float(indice)) * 2.0)
		var cor: Color = efeito.get("cor", Color("#e7d5b2"))
		var pulso := 0.82 + 0.18 * sin(_tempo * 6.0 + float(indice) * 1.4)
		draw_circle(centro, 8.5, Color("#10151d", 0.88))
		draw_arc(centro, 8.5, 0.0, TAU, 20, Color(cor, pulso), 1.5)
		if fonte:
			draw_string(fonte, centro + Vector2(-5.5, 3.5), str(efeito.get("icone", "✦")), HORIZONTAL_ALIGNMENT_CENTER, 11.0, 9, cor)
			draw_string(fonte, centro + Vector2(5.0, -7.0), str(efeito.get("turnos", 0)), HORIZONTAL_ALIGNMENT_CENTER, 10.0, 8, Color("#fff4d5"))

static func obter_indicadores_status(efeitos: Array) -> Array:
	var configuracao := {
		"veneno":{"icone":"☠","cor":Color("#8bd36c")},
		"queimadura":{"icone":"🔥","cor":Color("#ff8b45")},
		"lentidao":{"icone":"❄","cor":Color("#8bd9f0")},
		"atordoamento":{"icone":"⚡","cor":Color("#ffe16b")},
		"vulnerabilidade":{"icone":"◈","cor":Color("#c39cff")},
		"sangramento":{"icone":"🩸","cor":Color("#ef6674")}
	}
	var ativos: Array = []
	for efeito in efeitos:
		if not efeito is Dictionary:
			continue
		var id := str(efeito.get("id", ""))
		var turnos := int(efeito.get("turnos", 0))
		if turnos <= 0:
			continue
		var visual: Dictionary = configuracao.get(id, {"icone":"✦","cor":Color("#e7d5b2")})
		ativos.append({"id":id,"icone":visual.icone,"cor":visual.cor,"turnos":turnos})
	return ativos

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
