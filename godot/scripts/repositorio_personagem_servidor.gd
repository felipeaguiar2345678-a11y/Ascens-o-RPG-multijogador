extends RefCounted
## Armazenamento local do processo dedicado. Nunca é carregado pelo cliente.
## Adequado para desenvolvimento em um único servidor com disco persistente.

const CAMINHO := "user://dados/personagens_online.json"
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

	# Somente campos conhecidos são persistidos; a revisão é controlada aqui.
	var revisao := maxi(0, int(atual.get("revisaoServidor", 0))) + 1
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
	var x := float(d.get("x", -1.0))
	var y := float(d.get("y", -1.0))
	return int(d.get("nivel", 0)) >= 1 and int(d.get("experiencia", -1)) >= 0 and int(d.get("vidaMaxima", 0)) >= 1 and int(d.get("vida", -1)) >= 0 and int(d.get("vida", -1)) <= int(d.get("vidaMaxima", 0)) and int(d.get("manaMaxima", -1)) >= 0 and int(d.get("mana", -1)) >= 0 and int(d.get("mana", -1)) <= int(d.get("manaMaxima", 0)) and x >= 0.0 and x <= 2400.0 and y >= 0.0 and y <= 1600.0

func _uid_valido(uid: String) -> bool:
	return not uid.is_empty() and uid.length() <= 128 and uid.is_valid_filename()

func _ler_banco() -> Dictionary:
	if not FileAccess.file_exists(CAMINHO):
		return {"versao": 1, "personagens": {}}
	var arquivo := FileAccess.open(CAMINHO, FileAccess.READ)
	if arquivo == null or arquivo.get_length() > LIMITE_ARQUIVO:
		return {}
	var dados = JSON.parse_string(arquivo.get_as_text())
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1 or not (dados.get("personagens", {}) is Dictionary):
		return {}
	return dados

func _gravar_banco(banco: Dictionary) -> bool:
	var diretorio := ProjectSettings.globalize_path("user://dados")
	var caminho_final := ProjectSettings.globalize_path(CAMINHO)
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
	if FileAccess.file_exists(CAMINHO):
		var erro_remocao := DirAccess.remove_absolute(caminho_final)
		if erro_remocao != OK:
			return false
	return DirAccess.rename_absolute(caminho_temporario, caminho_final) == OK
