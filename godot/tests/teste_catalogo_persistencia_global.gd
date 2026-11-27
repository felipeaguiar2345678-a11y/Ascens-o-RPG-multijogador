extends SceneTree
## Testa a importação do catálogo remoto e a produção do snapshot usado no CAS seguinte.

const Repositorio = preload("res://scripts/repositorio_criaturas_servidor.gd")
const Rede = preload("res://scripts/rede_multiplayer.gd")

func _initialize() -> void:
	var caminho := "user://teste_catalogo_global_%d.json" % Time.get_ticks_usec()
	var repositorio = Repositorio.new(caminho)
	var remoto := {
		"versao": 1,
		"criaturas": {},
		"estatisticas": {}
	}
	var snapshot := repositorio.importar_estado_persistente_e_obter_snapshot(remoto)
	if snapshot.is_empty():
		_falhar("Um catálogo remoto vazio, mas válido, não produziu snapshot após importação.")
		return
	if Rede.snapshot_global_confirmado(snapshot, JSON.stringify(remoto)):
		_falhar("A migração do catálogo legado não foi diferenciada do payload ainda confirmado no D1.")
		return
	if JSON.stringify(snapshot) != JSON.stringify(repositorio.exportar_estado_persistente()):
		_falhar("O snapshot retornado não corresponde ao catálogo persistido localmente.")
		return
	if int(snapshot.get("versao", 0)) != 1 or not (snapshot.get("criaturas", null) is Dictionary) or not (snapshot.get("estatisticas", null) is Dictionary):
		_falhar("O snapshot importado perdeu campos obrigatórios do catálogo.")
		return

	var invalido := repositorio.importar_estado_persistente_e_obter_snapshot({"versao": 2, "criaturas": {}, "estatisticas": {}})
	if not invalido.is_empty():
		_falhar("Um catálogo com versão inválida produziu snapshot.")
		return

	_limpar(caminho)
	print("TESTE CATÁLOGO GLOBAL: importação remota, snapshot pós-importação e rejeição de versão inválida aprovados.")
	quit(0)

func _limpar(caminho: String) -> void:
	for sufixo in ["", ".bak", ".tmp"]:
		var alvo := caminho + sufixo
		if FileAccess.file_exists(alvo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(alvo))

func _falhar(mensagem: String) -> void:
	push_error("TESTE CATÁLOGO GLOBAL: " + mensagem)
	quit(1)
