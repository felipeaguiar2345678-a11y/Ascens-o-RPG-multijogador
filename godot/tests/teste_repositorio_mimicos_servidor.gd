extends SceneTree

const Repositorio = preload("res://scripts/repositorio_mimicos_servidor.gd")
const SISTEMA = preload("res://scripts/sistema_mimicos.gd")
const CAMINHO := "user://teste_mimicos_mundo_ci.json"

func _initialize() -> void:
	var repo = Repositorio.new(CAMINHO)
	var banco := repo.carregar_ou_criar(87654321)
	if banco.is_empty() or int(banco.get("versao", 0)) != 1:
		_falhar("Não foi possível criar o estado inicial do mundo.")
		return
	var ativos := repo.listar_ativos()
	if ativos.size() > 20:
		_falhar("O mundo criou mais baús do que os pontos de aparição definidos.")
		return
	for bau in ativos:
		if not SISTEMA.validar_tipo(str(bau.get("raridade", ""))):
			_falhar("Um baú recebeu uma raridade inválida.")
			return
	var novamente := Repositorio.new(CAMINHO).carregar_ou_criar(87654321)
	if novamente.get("bauList", []) != banco.get("bauList", []):
		_falhar("O mesmo mundo não preservou os mesmos baús após recarregar.")
		return
	if not ativos.is_empty():
		var id := str(ativos[0].get("id", ""))
		var reserva := repo.reservar_encontro(id, "uid_teste")
		if not bool(reserva.get("ok", false)):
			_falhar("Não foi possível reservar o baú para um encontro.")
			return
		var segunda_reserva := repo.reservar_encontro(id, "uid_outro")
		if bool(segunda_reserva.get("ok", true)):
			_falhar("Dois jogadores conseguiram reservar o mesmo baú.")
			return
		if not repo.liberar_reserva(id, "uid_teste"):
			_falhar("Não foi possível liberar a reserva de teste.")
			return
		var terceira_reserva := repo.reservar_encontro(id, "uid_outro")
		if not bool(terceira_reserva.get("ok", false)):
			_falhar("O baú não ficou disponível após liberar a reserva.")
			return
	for sufixo in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(CAMINHO + sufixo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO + sufixo))
	print("TESTE DOS BAÚS MÍMICOS: geração persistente, raridade, reserva exclusiva e liberação aprovadas.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DOS BAÚS MÍMICOS: " + mensagem)
	quit(1)
