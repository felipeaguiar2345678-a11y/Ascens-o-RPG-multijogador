extends RefCounted
## Armazenamento local do processo dedicado. Nunca é carregado pelo cliente.
## Adequado para desenvolvimento em um único servidor com disco persistente.

const CAMINHO := "user://dados/personagens_online.json"
const CAMINHO_BACKUP := "user://dados/personagens_online.json.bak"
const LIMITE_ARQUIVO := 16 * 1024 * 1024

func carregar_ou_criar(uid: String) -> Dictionary:
	if not _uid_valido(uid):
		return {}
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(CAMINHO):
		push_error("Banco local de personagens inválido; entrada bloqueada para evitar sobrescrita.")
		return {}
	var registros: Dictionary = banco.get("personagens", {})
	if registros.has(uid):
		var existente = registros[uid]
		if not (existente is Dictionary) or str(existente.get("uid", "")) != uid:
			return {}
		return existente.duplicate(true)

	var novo := {
		"uid": uid,
		"personagemId": uid,
		"nome": "Aventureiro",
		"nivel": 1,
		"experiencia": 0,
		"vida": 100,
		"vidaMaxima": 100,
		"mana": 50,
		"manaMaxima": 50,
		"forca": 5,
		"inteligencia": 5,
		"agilidade": 5,
		"vitalidade": 5,
		"espirito": 5,
		"pontoMundoId": "clareira_inicial",
		"x": 1190.0,
		"y": 1120.0,
		"aparenciaId": "",
		"revisaoServidor": 1
	}
	registros[uid] = novo
	banco["personagens"] = registros
	if not _gravar_banco(banco):
		return {}
	return novo.duplicate(true)

func salvar(uid: String, snapshot: Dictionary) -> bool:
	if not _uid_valido(uid) or str(snapshot.get("uid", "")) != uid:
		return false
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(CAMINHO):
		return false
	var registros: Dictionary = banco.get("personagens", {})
	var atual: Dictionary = registros.get(uid, {})
	if atual.is_empty():
		return false

	# Impede que um snapshot antigo sobrescreva uma versão mais nova.
	var revisao_atual := int(atual.get("revisaoServidor", 0))
	if int(snapshot.get("revisaoServidor", -1)) != revisao_atual:
		push_warning("Gravação recusada: revisão de personagem desatualizada.")
		return false
	# Somente campos conhecidos são persistidos; a revisão é controlada aqui.
	var revisao := revisao_atual + 1
	var salvo := atual.duplicate(true)
	for chave in ["nome", "nivel", "experiencia", "vida", "vidaMaxima", "mana", "manaMaxima", "forca", "inteligencia", "agilidade", "vitalidade", "espirito", "pontoMundoId", "x", "y", "aparenciaId"]:
		if snapshot.has(chave):
			salvo[chave] = snapshot[chave]
	salvo["uid"] = uid
	salvo["revisaoServidor"] = revisao
	if not _snapshot_valido(salvo):
		return false
	registros[uid] = salvo
	banco["personagens"] = registros
	if not _gravar_banco(banco):
		return false
	snapshot["revisaoServidor"] = revisao
	return true

func _snapshot_valido(d: Dictionary) -> bool:
	var nivel := int(d.get("nivel", 0))
	var experiencia := int(d.get("experiencia", -1))
	var vida_maxima := int(d.get("vidaMaxima", 0))
	var vida := int(d.get("vida", -1))
	var mana_maxima := int(d.get("manaMaxima", -1))
	var mana := int(d.get("mana", -1))
	var x := float(d.get("x", -1.0))
	var y := float(d.get("y", -1.0))
	if nivel < 1 or nivel > 10000 or experiencia < 0:
		return false
	if vida_maxima < 1 or vida_maxima > 100000000 or vida < 0 or vida > vida_maxima:
		return false
	if mana_maxima < 0 or mana_maxima > 100000000 or mana < 0 or mana > mana_maxima:
		return false
	if not is_finite(x) or not is_finite(y):
		return false
	if x < 0.0 or x > 2400.0 or y < 0.0 or y > 1600.0:
		return false
	for atributo in ["forca", "inteligencia", "agilidade", "vitalidade", "espirito"]:
		var valor := int(d.get(atributo, -1))
		if valor < 0 or valor > 1000000:
			return false
	return true
func _uid_valido(uid: String) -> bool:
	return not uid.is_empty() and uid.length() <= 128 and uid.is_valid_filename()

func _ler_banco() -> Dictionary:
	if FileAccess.file_exists(CAMINHO):
		var principal := _ler_arquivo_banco(CAMINHO)
		if not principal.is_empty():
			return principal
		var backup := _ler_arquivo_banco(CAMINHO_BACKUP)
		if not backup.is_empty():
			push_warning("Banco principal inválido; usando a cópia de segurança.")
			return backup
		return {}
	if FileAccess.file_exists(CAMINHO_BACKUP):
		return _ler_arquivo_banco(CAMINHO_BACKUP)
	return {"versao": 1, "personagens": {}}

func _ler_arquivo_banco(caminho: String) -> Dictionary:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null or arquivo.get_length() > LIMITE_ARQUIVO:
		return {}
	var dados = JSON.parse_string(arquivo.get_as_text())
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1:
		return {}
	if not (dados.get("personagens", {}) is Dictionary):
		return {}
	return dados

func _gravar_banco(banco: Dictionary) -> bool:
	var diretorio := ProjectSettings.globalize_path("user://dados")
	var caminho_final := ProjectSettings.globalize_path(CAMINHO)
	var caminho_backup := ProjectSettings.globalize_path(CAMINHO_BACKUP)
	var caminho_temporario := caminho_final + ".tmp"
	if DirAccess.make_dir_recursive_absolute(diretorio) != OK and not DirAccess.dir_exists_absolute(diretorio):
		return false
	var arquivo := FileAccess.open(caminho_temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(banco))
	arquivo.flush()
	var erro_arquivo := arquivo.get_error()
	arquivo.close()
	if erro_arquivo != OK:
		return false
	# Se o arquivo principal estiver corrompido, recupera primeiro o backup válido.
	if FileAccess.file_exists(CAMINHO) and _ler_arquivo_banco(CAMINHO).is_empty() and not _ler_arquivo_banco(CAMINHO_BACKUP).is_empty():
		if DirAccess.remove_absolute(caminho_final) != OK:
			return false
		if DirAccess.rename_absolute(caminho_backup, caminho_final) != OK:
			return false
	# Mantém a última versão válida antes de promover o arquivo temporário.
	if FileAccess.file_exists(CAMINHO):
		if FileAccess.file_exists(CAMINHO_BACKUP):
			if DirAccess.remove_absolute(caminho_backup) != OK:
				return false
		if DirAccess.rename_absolute(caminho_final, caminho_backup) != OK:
			return false
	if DirAccess.rename_absolute(caminho_temporario, caminho_final) != OK:
		if not FileAccess.file_exists(CAMINHO) and FileAccess.file_exists(CAMINHO_BACKUP):
			DirAccess.rename_absolute(caminho_backup, caminho_final)
		return false
	return true
