extends SceneTree

const Repositorio = preload("res://scripts/repositorio_mimicos_servidor.gd")
const SISTEMA = preload("res://scripts/sistema_mimicos.gd")
const AMBIENTES = preload("res://scripts/sistema_ambientes_mundo.gd")
const CAMINHO := "user://teste_mimicos_mundo_ci.json"

func _initialize() -> void:
	for ponto in Repositorio.PONTOS:
		var posicao: Vector2 = ponto.get("posicao", Vector2.ZERO)
		var contexto := AMBIENTES.obter_contexto(posicao)
		if contexto.is_empty():
			_falhar("Um ponto de baú ficou fora do continente ou em coordenada inválida: " + str(ponto.get("id", "")))
			return
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
	if _assinatura_baus(novamente.get("bauList", [])) != _assinatura_baus(banco.get("bauList", [])):
		_falhar("O mesmo mundo não preservou os mesmos baús após recarregar.")
		return
	var snapshot_global := repo.exportar_estado_persistente()
	if snapshot_global.is_empty():
		_falhar("O repositório não exportou um snapshot global válido.")
		return
	var repo_host_novo = Repositorio.new("user://teste_mimicos_host_novo.json")
	if not repo_host_novo.importar_estado_persistente(snapshot_global):
		_falhar("Um host novo não conseguiu importar o snapshot global.")
		return
	if _assinatura_baus(repo_host_novo.exportar_estado_persistente().get("bauList", [])) != _assinatura_baus(snapshot_global.get("bauList", [])):
		_falhar("A população global mudou durante a migração de host.")
		return
	var snapshot_invalido := snapshot_global.duplicate(true)
	snapshot_invalido["bauList"][0]["id"] = "bau_inventado"
	if repo_host_novo.importar_estado_persistente(snapshot_invalido):
		_falhar("O repositório aceitou um snapshot global com baú desconhecido.")
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
	for caminho_limpeza in [CAMINHO, "user://teste_mimicos_host_novo.json"]:
		for sufixo in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(caminho_limpeza + sufixo):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_limpeza + sufixo))
	print("TESTE DOS BAÚS MÍMICOS: geração persistente, raridade, reserva exclusiva, liberação e recuperação entre hosts aprovadas.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DOS BAÚS MÍMICOS: " + mensagem)
	quit(1)

func _assinatura_baus(lista: Array) -> Array:
	var assinatura: Array = []
	for bau in lista:
		var posicao: Dictionary = bau.get("posicao", {})
		var mimico: Dictionary = bau.get("mimico", {})
		assinatura.append({
			"id":str(bau.get("id", "")),
			"raridade":str(mimico.get("raridade", "")),
			"posicao_x":float(posicao.get("x", 0.0)),
			"posicao_y":float(posicao.get("y", 0.0)),
			"pistas_visuais":bool(mimico.get("pistasVisuais", false))
		})
	assinatura.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("id", "")) < str(b.get("id", "")))
	return assinatura
