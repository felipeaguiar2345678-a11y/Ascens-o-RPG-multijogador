extends RefCounted
class_name RepositorioMimicosServidor

const CAMINHO := "user://dados/mimicos_mundo.json"
const SISTEMA = preload("res://scripts/sistema_mimicos.gd")
const PONTOS := [
	{"id":"bau_floresta_01","posicao":Vector2(390,660),"bioma":"bosque"},
	{"id":"bau_floresta_02","posicao":Vector2(540,820),"bioma":"bosque"},
	{"id":"bau_floresta_03","posicao":Vector2(760,1020),"bioma":"bosque"},
	{"id":"bau_floresta_04","posicao":Vector2(430,1280),"bioma":"bosque"},
	{"id":"bau_floresta_05","posicao":Vector2(690,1480),"bioma":"bosque"},
	{"id":"bau_deserto_01","posicao":Vector2(390,1680),"bioma":"dunas"},
	{"id":"bau_deserto_02","posicao":Vector2(680,1720),"bioma":"dunas"},
	{"id":"bau_montanha_01","posicao":Vector2(1550,550),"bioma":"cordilheira"},
	{"id":"bau_montanha_02","posicao":Vector2(1740,620),"bioma":"cordilheira"},
	{"id":"bau_montanha_03","posicao":Vector2(1940,550),"bioma":"cordilheira"},
	{"id":"bau_pantano_01","posicao":Vector2(1770,1480),"bioma":"pantano"},
	{"id":"bau_pantano_02","posicao":Vector2(1920,1610),"bioma":"pantano"},
	{"id":"bau_pantano_03","posicao":Vector2(2070,1720),"bioma":"pantano"},
	{"id":"bau_planicie_01","posicao":Vector2(1120,1250),"bioma":"planicie"},
	{"id":"bau_planicie_02","posicao":Vector2(1360,1450),"bioma":"planicie"},
	{"id":"bau_planicie_03","posicao":Vector2(1010,1850),"bioma":"planicie"},
	{"id":"bau_planicie_04","posicao":Vector2(1450,1900),"bioma":"planicie"},
	{"id":"bau_planicie_05","posicao":Vector2(1180,1580),"bioma":"planicie"},
	{"id":"bau_floresta_06","posicao":Vector2(300,1050),"bioma":"bosque"},
	{"id":"bau_floresta_07","posicao":Vector2(820,1330),"bioma":"bosque"}
]

var caminho_arquivo := CAMINHO

func _init(caminho: String = CAMINHO) -> void:
	caminho_arquivo = caminho

func carregar_ou_criar(semente_mundo: int) -> Dictionary:
	var banco := _ler()
	if not banco.is_empty():
		var alterado := false
		var agora := int(Time.get_unix_time_from_system())
		var lista: Array = banco.get("bauList", [])
		for i in range(lista.size()):
			if str(lista[i].get("estado", "")) == "em_combate" and agora - int(lista[i].get("reservadoEmUnix", agora)) > 600:
				lista[i]["estado"] = "disfarcado"
				lista[i].erase("reservadoPorUid")
				lista[i].erase("reservadoEmUnix")
				alterado = true
		if alterado:
			banco["bauList"] = lista
			if not _gravar(banco):
				return {}
		return banco
	if FileAccess.file_exists(caminho_arquivo):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, semente_mundo ^ 0x51A7C3)
	var bau_list: Array = []
	for ponto in PONTOS:
		var semente := int(rng.randi())
		var aparicao := SISTEMA.sortear_aparicao(semente)
		if not bool(aparicao.get("aparece", false)):
			continue
		var tipo := str(aparicao.get("tipo", "comum"))
		var id := str(ponto.get("id", ""))
		var mimico := SISTEMA.criar_mimico(tipo, "mimico_" + id, str(ponto.get("bioma", "")), semente)
		var posicao: Vector2 = ponto.get("posicao", Vector2.ZERO)
		bau_list.append({
			"id":id, "mimico":mimico, "estado":"disfarcado",
			"posicao":{"x":posicao.x,"y":posicao.y},
			"criadoEmUnix":int(Time.get_unix_time_from_system()),
			"respawnEmUnix":0
		})
	var novo := {"versao":1,"sementeMundo":semente_mundo,"bauList":bau_list}
	if not _gravar(novo):
		return {}
	return novo

func listar_ativos() -> Array:
	var banco := _ler()
	var resultado: Array = []
	for bau in banco.get("bauList", []):
		if bau is Dictionary and str(bau.get("estado", "")) != "derrotado":
			resultado.append(_publico(bau))
	return resultado

func obter(id: String) -> Dictionary:
	var banco := _ler()
	for bau in banco.get("bauList", []):
		if bau is Dictionary and str(bau.get("id", "")) == id:
			return bau.duplicate(true)
	return {}

func reservar_encontro(id: String, uid: String) -> Dictionary:
	if id.strip_edges().is_empty() or uid.strip_edges().is_empty():
		return {"ok":false,"erro":"Identidade do baú ou jogador inválida."}
	var banco := _ler()
	var lista: Array = banco.get("bauList", [])
	for i in range(lista.size()):
		if str(lista[i].get("id", "")) != id:
			continue
		if str(lista[i].get("estado", "")) != "disfarcado":
			return {"ok":false,"erro":"Este baú não está disponível para interação."}
		lista[i]["estado"] = "em_combate"
		lista[i]["reservadoPorUid"] = uid
		lista[i]["reservadoEmUnix"] = int(Time.get_unix_time_from_system())
		banco["bauList"] = lista
		if not _gravar(banco):
			return {"ok":false,"erro":"Não foi possível reservar o baú."}
		return {"ok":true,"bau":lista[i].duplicate(true)}
	return {"ok":false,"erro":"Baú não encontrado."}

func liberar_reserva(id: String, uid: String) -> bool:
	var banco := _ler()
	var lista: Array = banco.get("bauList", [])
	for i in range(lista.size()):
		if str(lista[i].get("id", "")) != id:
			continue
		if str(lista[i].get("estado", "")) != "em_combate" or str(lista[i].get("reservadoPorUid", "")) != uid:
			return false
		lista[i]["estado"] = "disfarcado"
		lista[i].erase("reservadoPorUid")
		lista[i].erase("reservadoEmUnix")
		banco["bauList"] = lista
		return _gravar(banco)
	return false

func registrar_derrota(id: String) -> Dictionary:
	var banco := _ler()
	var lista: Array = banco.get("bauList", [])
	for i in range(lista.size()):
		if str(lista[i].get("id", "")) != id:
			continue
		if str(lista[i].get("estado", "")) != "em_combate":
			return {"ok":false,"duplicado":true,"erro":"Este mímico já foi derrotado."}
		lista[i]["estado"] = "derrotado"
		lista[i].erase("reservadoPorUid")
		lista[i].erase("reservadoEmUnix")
		lista[i]["derrotadoEmUnix"] = int(Time.get_unix_time_from_system())
		banco["bauList"] = lista
		if not _gravar(banco):
			return {"ok":false,"erro":"Não foi possível salvar o estado do baú."}
		return {"ok":true,"bau":_publico(lista[i])}
	return {"ok":false,"erro":"Baú não encontrado."}

func _publico(bau: Dictionary) -> Dictionary:
	var mimico: Dictionary = bau.get("mimico", {})
	return {
		"id":str(bau.get("id", "")),
		"nome":"Baú suspeito" if str(bau.get("estado", "")) == "disfarcado" else str(mimico.get("nome", "Mímico")),
		"raridade":str(mimico.get("raridade", "")),
		"estado":str(bau.get("estado", "")),
		"posicao":bau.get("posicao", {}).duplicate(true),
		"pistasVisuais":bool(mimico.get("pistasVisuais", false)),
		"bioma":str(mimico.get("bioma", ""))
	}

func _ler() -> Dictionary:
	if not FileAccess.file_exists(caminho_arquivo):
		return {}
	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.READ)
	if arquivo == null:
		return {}
	var dados = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1 or not (dados.get("bauList", []) is Array):
		return {}
	return dados

func _gravar(banco: Dictionary) -> bool:
	var diretorio := ProjectSettings.globalize_path(caminho_arquivo.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(diretorio) != OK and not DirAccess.dir_exists_absolute(diretorio):
		return false
	var arquivo := FileAccess.open(caminho_arquivo + ".tmp", FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(banco))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		return false
	var destino := ProjectSettings.globalize_path(caminho_arquivo)
	var temporario := ProjectSettings.globalize_path(caminho_arquivo + ".tmp")
	if FileAccess.file_exists(caminho_arquivo):
		var backup := ProjectSettings.globalize_path(caminho_arquivo + ".bak")
		if FileAccess.file_exists(caminho_arquivo + ".bak"):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(destino, backup) != OK:
			return false
	if DirAccess.rename_absolute(temporario, destino) != OK:
		var backup := ProjectSettings.globalize_path(caminho_arquivo + ".bak")
		if FileAccess.file_exists(caminho_arquivo + ".bak"):
			DirAccess.rename_absolute(backup, destino)
		return false
	return true
