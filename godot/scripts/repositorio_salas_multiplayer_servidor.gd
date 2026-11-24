extends RefCounted
## Persistência local durável das salas cooperativas. O volume do servidor deve preservar user://dados.

const CAMINHO := "user://dados/salas_multiplayer.json"

func salvar(registros: Array) -> bool:
	var diretorio := ProjectSettings.globalize_path(CAMINHO.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(diretorio) != OK and not DirAccess.dir_exists_absolute(diretorio):
		push_error("Não foi possível criar o diretório de persistência das salas.")
		return false
	var arquivo := FileAccess.open(CAMINHO, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível abrir o arquivo de salas para gravação.")
		return false
	arquivo.store_string(JSON.stringify({"versao": 1, "salas": registros}))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		push_error("Falha ao gravar o estado persistente das salas.")
		return false
	return true

func carregar() -> Dictionary:
	if not FileAccess.file_exists(CAMINHO):
		return {"sucesso": true, "salas": [], "arquivoNovo": true}
	var arquivo := FileAccess.open(CAMINHO, FileAccess.READ)
	if arquivo == null:
		return {"sucesso": false, "erro": "Não foi possível abrir o arquivo persistente das salas."}
	var dados = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if not dados is Dictionary or int(dados.get("versao", 0)) != 1 or not dados.get("salas", null) is Array:
		return {"sucesso": false, "erro": "Arquivo persistente das salas está corrompido ou em versão incompatível."}
	return {"sucesso": true, "salas": dados["salas"].duplicate(true), "arquivoNovo": false}
