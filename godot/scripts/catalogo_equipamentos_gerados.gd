extends RefCounted
class_name CatalogoEquipamentosGerados

## Catálogo persistente no processo do servidor dedicado.
## Um ID de projeto é registrado uma única vez e reaproveitado após reinicializações.
const CAMINHO_ARQUIVO := "user://equipamentos_gerados.json"
static var _itens: Dictionary = {}
static var _carregado := false

static func registrar(item: Dictionary) -> bool:
	_carregar_se_necessario()
	var item_id := str(item.get("id", "")).strip_edges()
	if item_id.is_empty() or not item_id.begins_with("gerado_"):
		return false
	if _itens.has(item_id):
		return _itens[item_id] == item
	var copia := item.duplicate(true)
	copia["catalogadoEm"] = int(Time.get_unix_time_from_system())
	_itens[item_id] = copia
	return _salvar()


static func obter(item_id: String) -> Dictionary:
	_carregar_se_necessario()
	return _itens.get(item_id, {}).duplicate(true)


static func listar_ids() -> Array[String]:
	_carregar_se_necessario()
	var ids: Array[String] = []
	for item_id in _itens.keys():
		ids.append(str(item_id))
	ids.sort()
	return ids


static func quantidade() -> int:
	_carregar_se_necessario()
	return _itens.size()


static func _carregar_se_necessario() -> void:
	if _carregado:
		return
	_carregado = true
	if not FileAccess.file_exists(CAMINHO_ARQUIVO):
		return
	var arquivo := FileAccess.open(CAMINHO_ARQUIVO, FileAccess.READ)
	if arquivo == null:
		return
	var dados = JSON.parse_string(arquivo.get_as_text())
	if not (dados is Dictionary):
		return
	for item_id in dados:
		var item = dados[item_id]
		if item is Dictionary and str(item.get("id", "")) == str(item_id) and str(item_id).begins_with("gerado_"):
			_itens[str(item_id)] = item.duplicate(true)


static func _salvar() -> bool:
	var arquivo := FileAccess.open(CAMINHO_ARQUIVO, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(_itens))
	arquivo.flush()
	return arquivo.get_error() == OK


static func limpar_para_teste() -> void:
	_itens.clear()
	_carregado = true
	if FileAccess.file_exists(CAMINHO_ARQUIVO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_ARQUIVO))
