extends RefCounted
## Conversões explícitas dos registros persistidos do mapa antigo.
## O chamador só deve executar estas funções quando versaoCoordenadas < VERSAO_COORDENADAS.
const VERSAO_COORDENADAS := 2

static func migrar_perfil_legado(perfil_original: Dictionary) -> Dictionary:
	var perfil := perfil_original.duplicate(true)
	if perfil.has("x") or perfil.has("y"):
		if not (perfil.has("x") and perfil.has("y")):
			return {}
		var ponto := _migrar_ponto({"x":perfil["x"], "y":perfil["y"]})
		if ponto.is_empty():
			return {}
		perfil["x"] = ponto["x"]
		perfil["y"] = ponto["y"]
	return perfil

static func migrar_criatura_legada(criatura_original: Dictionary) -> Dictionary:
	var criatura := criatura_original.duplicate(true)
	for campo in ["posicaoMundo", "origemMundo", "alvoMundo"]:
		if criatura.has(campo):
			var ponto := _migrar_ponto(criatura[campo])
			if ponto.is_empty():
				return {}
			criatura[campo] = ponto
	if criatura.has("ecologia") and criatura["ecologia"] is Dictionary:
		var ecologia: Dictionary = criatura["ecologia"].duplicate(true)
		if ecologia.has("territorio"):
			var territorio := _migrar_territorio(ecologia["territorio"])
			if territorio.is_empty():
				return {}
			ecologia["territorio"] = territorio
		if ecologia.has("rotasMigracao"):
			var rotas := _migrar_rotas(ecologia["rotasMigracao"])
			if rotas.is_empty() and not ecologia["rotasMigracao"].is_empty():
				return {}
			ecologia["rotasMigracao"] = rotas
		criatura["ecologia"] = ecologia
	return criatura

static func _migrar_territorio(valor: Variant) -> Dictionary:
	if not (valor is Dictionary):
		return {}
	var territorio: Dictionary = valor.duplicate(true)
	if territorio.has("centro"):
		var centro := _migrar_ponto(territorio["centro"])
		if centro.is_empty():
			return {}
		territorio["centro"] = centro
	return territorio

static func _migrar_rotas(valor: Variant) -> Array:
	if not (valor is Array):
		return []
	var rotas: Array = valor.duplicate(true)
	for indice in range(rotas.size()):
		if not (rotas[indice] is Dictionary):
			return []
		var rota: Dictionary = rotas[indice].duplicate(true)
		if rota.has("territorio"):
			var territorio := _migrar_territorio(rota["territorio"])
			if territorio.is_empty():
				return []
			rota["territorio"] = territorio
		rotas[indice] = rota
	return rotas

static func migrar_grupo_legado(grupo_original: Dictionary) -> Dictionary:
	var grupo := grupo_original.duplicate(true)
	var territorio := _migrar_territorio(grupo.get("territorio", {}))
	if territorio.is_empty():
		return {}
	grupo["territorio"] = territorio
	if grupo.has("rotasMigracao"):
		var rotas := _migrar_rotas(grupo["rotasMigracao"])
		if rotas.is_empty() and not grupo["rotasMigracao"].is_empty():
			return {}
		grupo["rotasMigracao"] = rotas
	var individuos: Array = grupo.get("individuos", [])
	for indice in range(individuos.size()):
		if not (individuos[indice] is Dictionary):
			return {}
		var individuo: Dictionary = individuos[indice].duplicate(true)
		if individuo.has("posicaoMundo"):
			var posicao := _migrar_ponto(individuo["posicaoMundo"])
			if posicao.is_empty():
				return {}
			individuo["posicaoMundo"] = posicao
		if individuo.has("carcaca") and individuo["carcaca"] is Dictionary:
			var carcaca: Dictionary = individuo["carcaca"].duplicate(true)
			if carcaca.has("posicaoMundo"):
				var posicao_carcaca := _migrar_ponto(carcaca["posicaoMundo"])
				if posicao_carcaca.is_empty():
					return {}
				carcaca["posicaoMundo"] = posicao_carcaca
			individuo["carcaca"] = carcaca
		individuos[indice] = individuo
	grupo["individuos"] = individuos
	return grupo

static func _migrar_ponto(valor: Variant) -> Dictionary:
	if not (valor is Dictionary) or not valor.has("x") or not valor.has("y"):
		return {}
	var ponto := Vector2(float(valor["x"]), float(valor["y"]))
	var convertido := Geometria.migrar_posicao_legada(ponto)
	if convertido.x < 0.0 or convertido.y < 0.0:
		return {}
	var resultado: Dictionary = valor.duplicate(true)
	resultado["x"] = convertido.x
	resultado["y"] = convertido.y
	return resultado

const Geometria = preload("res://scripts/sistema_geometria_mundo.gd")
