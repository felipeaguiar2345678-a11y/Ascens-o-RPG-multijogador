extends RefCounted
## Persistência local durável das salas cooperativas. O volume do servidor deve preservar user://dados.

const CAMINHO := "user://dados/salas_multiplayer.json"
const CAMINHO_BACKUP := "user://dados/salas_multiplayer.json.bak"

func salvar(registros: Array) -> bool:
	var diretorio := ProjectSettings.globalize_path(CAMINHO.get_base_dir())
	var caminho_final := ProjectSettings.globalize_path(CAMINHO)
	var caminho_backup := ProjectSettings.globalize_path(CAMINHO_BACKUP)
	var caminho_temporario := caminho_final + ".tmp"
	if DirAccess.make_dir_recursive_absolute(diretorio) != OK and not DirAccess.dir_exists_absolute(diretorio):
		push_error("Não foi possível criar o diretório de persistência das salas.")
		return false
	var arquivo := FileAccess.open(caminho_temporario, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível abrir o arquivo temporário das salas.")
		return false
	arquivo.store_string(JSON.stringify({"versao": 1, "salas": registros}))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		DirAccess.remove_absolute(caminho_temporario)
		push_error("Falha ao gravar o arquivo temporário das salas.")
		return false
	# Recupera um principal corrompido antes de rotacionar o backup válido.
	if FileAccess.file_exists(CAMINHO) and _ler_arquivo(CAMINHO).is_empty() and not _ler_arquivo(CAMINHO_BACKUP).is_empty():
		if DirAccess.remove_absolute(caminho_final) != OK:
			DirAccess.remove_absolute(caminho_temporario)
			return false
		if DirAccess.rename_absolute(caminho_backup, caminho_final) != OK:
			DirAccess.remove_absolute(caminho_temporario)
			return false
	if FileAccess.file_exists(CAMINHO):
		if FileAccess.file_exists(CAMINHO_BACKUP) and DirAccess.remove_absolute(caminho_backup) != OK:
			DirAccess.remove_absolute(caminho_temporario)
			return false
		if DirAccess.rename_absolute(caminho_final, caminho_backup) != OK:
			DirAccess.remove_absolute(caminho_temporario)
			return false
	if DirAccess.rename_absolute(caminho_temporario, caminho_final) != OK:
		if not FileAccess.file_exists(CAMINHO) and FileAccess.file_exists(CAMINHO_BACKUP):
			DirAccess.rename_absolute(caminho_backup, caminho_final)
		DirAccess.remove_absolute(caminho_temporario)
		return false
	return true

func carregar() -> Dictionary:
	var principal := _ler_arquivo(CAMINHO)
	if not principal.is_empty():
		return {"sucesso": true, "salas": principal.get("salas", []).duplicate(true), "arquivoNovo": false, "recuperadoBackup": false}
	if not FileAccess.file_exists(CAMINHO):
		return {"sucesso": true, "salas": [], "arquivoNovo": true, "recuperadoBackup": false}
	var backup := _ler_arquivo(CAMINHO_BACKUP)
	if backup.is_empty():
		return {"sucesso": false, "erro": "Arquivo principal e backup das salas estão corrompidos ou em versão incompatível."}
	var caminho_final := ProjectSettings.globalize_path(CAMINHO)
	if FileAccess.file_exists(CAMINHO) and DirAccess.remove_absolute(caminho_final) != OK:
		return {"sucesso": false, "erro": "O backup das salas é válido, mas o arquivo corrompido não pôde ser substituído."}
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(CAMINHO_BACKUP), caminho_final) != OK:
		return {"sucesso": false, "erro": "O backup das salas é válido, mas não pôde ser restaurado."}
	return {"sucesso": true, "salas": backup.get("salas", []).duplicate(true), "arquivoNovo": false, "recuperadoBackup": true}

func _ler_arquivo(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return {}
	var dados = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1 or not (dados.get("salas", null) is Array):
		return {}
	return dados
