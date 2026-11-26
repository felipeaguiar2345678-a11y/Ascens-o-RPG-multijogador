extends RefCounted
## Persistência transacional local do estado global da Serpente do Mundo.
## Em produção, user://dados deve estar em volume durável do servidor dedicado.

const CAMINHO_PADRAO := "user://dados/incursao_serpente_mundo.json"
const LIMITE_ARQUIVO := 4 * 1024 * 1024
const SISTEMA_SERPENTE = preload("res://scripts/sistema_serpente_mundo.gd")

var caminho_arquivo: String
var caminho_backup: String
var caminho_temporario: String

func _init(caminho: String = CAMINHO_PADRAO) -> void:
	caminho_arquivo = caminho
	caminho_backup = caminho + ".bak"
	caminho_temporario = caminho + ".tmp"

func carregar() -> Dictionary:
	var principal_existe := FileAccess.file_exists(caminho_arquivo)
	var backup_existe := FileAccess.file_exists(caminho_backup)
	if not principal_existe and not backup_existe:
		return {"sucesso":true,"estado":SISTEMA_SERPENTE.criar_estado(),"arquivoNovo":true,"recuperadoBackup":false}
	var principal := _ler_estado(caminho_arquivo) if principal_existe else {}
	if not principal.is_empty():
		return {"sucesso":true,"estado":principal,"arquivoNovo":false,"recuperadoBackup":false}
	var backup := _ler_estado(caminho_backup) if backup_existe else {}
	if not backup.is_empty():
		push_warning("Recuperação do estado da Serpente a partir do backup.")
		return {"sucesso":true,"estado":backup,"arquivoNovo":false,"recuperadoBackup":true}
	return {"sucesso":false,"erro":"Arquivos principal e backup do estado da Serpente estão inválidos; gravação bloqueada para proteger o progresso."}

func salvar(estado: Dictionary) -> bool:
	if not _estado_valido(estado):
		return false
	var caminho_final_abs := ProjectSettings.globalize_path(caminho_arquivo)
	var caminho_backup_abs := ProjectSettings.globalize_path(caminho_backup)
	var caminho_temp_abs := ProjectSettings.globalize_path(caminho_temporario)
	var diretorio := ProjectSettings.globalize_path(caminho_arquivo.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(diretorio) != OK and not DirAccess.dir_exists_absolute(diretorio):
		return false
	var arquivo := FileAccess.open(caminho_temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(estado))
	arquivo.flush()
	var erro_arquivo := arquivo.get_error()
	arquivo.close()
	if erro_arquivo != OK or _ler_estado(caminho_temporario).is_empty():
		return false
	# Nunca substitui um principal inválido sem antes recuperar um backup válido.
	if FileAccess.file_exists(caminho_arquivo) and _ler_estado(caminho_arquivo).is_empty():
		var backup_valido := _ler_estado(caminho_backup)
		if backup_valido.is_empty():
			return false
		if DirAccess.remove_absolute(caminho_final_abs) != OK:
			return false
		if DirAccess.rename_absolute(caminho_backup_abs, caminho_final_abs) != OK:
			return false
	if FileAccess.file_exists(caminho_arquivo):
		if FileAccess.file_exists(caminho_backup) and DirAccess.remove_absolute(caminho_backup_abs) != OK:
			return false
		if DirAccess.rename_absolute(caminho_final_abs, caminho_backup_abs) != OK:
			return false
	if DirAccess.rename_absolute(caminho_temp_abs, caminho_final_abs) != OK:
		if not FileAccess.file_exists(caminho_arquivo) and FileAccess.file_exists(caminho_backup):
			DirAccess.rename_absolute(caminho_backup_abs, caminho_final_abs)
		return false
	return not _ler_estado(caminho_arquivo).is_empty()

func _ler_estado(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return {}
	if arquivo.get_length() <= 0 or arquivo.get_length() > LIMITE_ARQUIVO:
		arquivo.close()
		return {}
	var dados = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	return dados if _estado_valido(dados) else {}

func _estado_valido(estado) -> bool:
	if not (estado is Dictionary):
		return false
	if str(estado.get("chefeId", "")) != SISTEMA_SERPENTE.ID_CHEFE:
		return false
	if int(estado.get("versao", 0)) < 1 or int(estado.get("versao", 0)) > 2:
		return false
	var status := str(estado.get("status", ""))
	if not [SISTEMA_SERPENTE.STATUS_DISPONIVEL, SISTEMA_SERPENTE.STATUS_EM_COMBATE, SISTEMA_SERPENTE.STATUS_DERROTADA].has(status):
		return false
	var vida_maxima := int(estado.get("vidaMaxima", 0))
	var vida := int(estado.get("vida", -1))
	if vida_maxima < 1 or vida_maxima > 2000000000 or vida < 0 or vida > vida_maxima:
		return false
	if not (estado.get("participantes", {}) is Dictionary) or not (estado.get("tentativasDomesticacao", {}) is Dictionary):
		return false
	if not (estado.get("defesasPreparadas", {}) is Dictionary):
		return false
	return true
