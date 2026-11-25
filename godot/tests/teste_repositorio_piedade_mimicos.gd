extends SceneTree

const Repositorio = preload("res://scripts/repositorio_piedade_mimicos.gd")
const Catalogo = preload("res://scripts/catalogo_armas_one_piece.gd")

const CAMINHO := "user://teste_piedade_mimicos_ci.json"

func _initialize() -> void:
	var repositorio = Repositorio.new(CAMINHO)
	var uid := "jogador_teste_piedade"
	var catalogo := Catalogo.listar_para_drop()
	var primeiro := repositorio.registrar_vitoria(uid, "vitoria_teste_001", "comum", catalogo, 1001)
	if not bool(primeiro.get("ok", false)) or bool(primeiro.get("duplicado", false)):
		_falhar("Não registrou a primeira vitória.")
		return
	var estado := Repositorio.new(CAMINHO).obter_piedade(uid)
	if int(estado.get("contadores", {}).get("lendaria", 0)) != 1:
		_falhar("O progresso não persistiu após reabrir o repositório.")
		return
	var repetido := repositorio.registrar_vitoria(uid, "vitoria_teste_001", "comum", catalogo, 1001)
	if not bool(repetido.get("duplicado", false)):
		_falhar("O mesmo ID de vitória foi aceito duas vezes.")
		return
	var progresso := repositorio.obter_piedade(uid)
	if int(progresso.get("contadores", {}).get("lendaria", 0)) != 1:
		_falhar("Uma vitória duplicada alterou a piedade.")
		return
	for sufixo in ["", ".tmp", ".bak"]:
		var caminho := ProjectSettings.globalize_path(CAMINHO + sufixo)
		if FileAccess.file_exists(CAMINHO + sufixo):
			DirAccess.remove_absolute(caminho)
	print("TESTE DO REPOSITÓRIO DE PIEDADE: persistência por UID e idempotência aprovadas.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DO REPOSITÓRIO DE PIEDADE: " + mensagem)
	quit(1)
