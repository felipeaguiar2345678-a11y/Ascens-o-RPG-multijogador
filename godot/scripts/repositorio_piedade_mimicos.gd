extends RefCounted
class_name RepositorioPiedadeMimicos

## Persistência local do servidor dedicado. Não aceitar chamadas diretas do cliente.
const CAMINHO_PADRAO := "user://dados/piedade_mimicos.json"
const SISTEMA = preload("res://scripts/sistema_mimicos.gd")
const LIMITE_JOGADORES := 10000

var caminho_arquivo: String

func _init(caminho: String = CAMINHO_PADRAO) -> void:
	caminho_arquivo = caminho

func obter_piedade(uid: String) -> Dictionary:
	if not _uid_valido(uid):
		return SISTEMA.criar_piedade_vazia()
	var banco := _ler_banco()
	var perfis: Dictionary = banco.get("jogadores", {})
	var estado: Dictionary = perfis.get(uid, SISTEMA.criar_piedade_vazia())
	return estado.duplicate(true)

func registrar_vitoria(uid: String, id_encontro: String, tipo_mimico: String, catalogo_armas: Array, semente: int) -> Dictionary:
	if not _uid_valido(uid) or id_encontro.strip_edges().is_empty():
		return {"ok": false, "erro": "Identidade ou encontro inválido."}
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(caminho_arquivo):
		return {"ok": false, "erro": "Arquivo de piedade inválido; gravação bloqueada para proteger o progresso."}
	var perfis: Dictionary = banco.get("jogadores", {})
	var piedade: Dictionary = perfis.get(uid, SISTEMA.criar_piedade_vazia())
	var resultado := SISTEMA.resolver_recompensa(tipo_mimico, catalogo_armas, piedade, id_encontro, semente)
	if not bool(resultado.get("ok", false)) or bool(resultado.get("duplicado", false)):
		return resultado
	if not perfis.has(uid) and perfis.size() >= LIMITE_JOGADORES:
		return {"ok": false, "erro": "Limite de perfis de piedade atingido."}
	perfis[uid] = resultado.get("piedade", {}).duplicate(true)
	banco["jogadores"] = perfis
	if not _gravar_banco(banco):
		return {"ok": false, "erro": "Não foi possível salvar a piedade; recompensa não confirmada."}
	return resultado

func _uid_valido(uid: String) -> bool:
	return not uid.strip_edges().is_empty() and uid.length() <= 256 and not uid.contains("/") and not uid.contains("\\")

func _ler_banco() -> Dictionary:
	if not FileAccess.file_exists(caminho_arquivo):
		return {"versao": 1, "jogadores": {}}
	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.READ)
	if arquivo == null:
		return {}
	var texto := arquivo.get_as_text()
	arquivo.close()
	var parseado = JSON.parse_string(texto)
	if not (parseado is Dictionary) or int(parseado.get("versao", 0)) != 1 or not (parseado.get("jogadores", {}) is Dictionary):
		return {}
	return parseado

func _gravar_banco(banco: Dictionary) -> bool:
	var diretorio := caminho_arquivo.get_base_dir()
	if not diretorio.is_empty() and not diretorio.begins_with("res://") and not diretorio.begins_with("user://"):
		return false
	if diretorio.begins_with("user://"):
		var erro_diretorio := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(diretorio))
		if erro_diretorio != OK and erro_diretorio != ERR_ALREADY_EXISTS:
			return false
	var temporario := caminho_arquivo + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(banco))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		return false
	var destino := ProjectSettings.globalize_path(caminho_arquivo)
	var origem := ProjectSettings.globalize_path(temporario)
	if FileAccess.file_exists(caminho_arquivo):
		var backup := caminho_arquivo + ".bak"
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
		var erro_backup := DirAccess.rename_absolute(destino, ProjectSettings.globalize_path(backup))
		if erro_backup != OK:
			return false
	var erro_final := DirAccess.rename_absolute(origem, destino)
	if erro_final != OK:
		var backup_path := caminho_arquivo + ".bak"
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), destino)
		return false
	return true
