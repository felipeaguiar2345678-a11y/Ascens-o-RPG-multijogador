extends SceneTree

const Repositorio = preload("res://scripts/repositorio_criaturas_servidor.gd")

func _initialize() -> void:
	var caminho := "user://teste_criaturas_errantes.json"
	for sufixo in ["", ".bak", ".tmp"]:
		var destino: String = caminho + str(sufixo)
		if FileAccess.file_exists(destino):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(destino))
	var repositorio = Repositorio.new(caminho)
	var criatura := {
		"id":"criatura_errante_ci","nome":"Predador Errante","descricao":"Criatura de teste persistente.",
		"rank":"E","raridade":"comum","nivel":1,"vidaMaxima":100,"ataque":10,"defesa":5,
		"manaMaxima":0,"agilidade":8,"poderMagico":0,"experienciaBase":5,"perigo":5,
		"ecossistemaId":"floresta_arcana","bioma":"floresta","habitat":"clareira",
		"habilidades":[],"tabelaDrops":[],"chefe":false
	}
	if not bool(repositorio.registrar_criatura_gerada(criatura).get("ok", false)):
		_falhar("Não registrou criatura de teste.")
		return
	var resultado := repositorio.registrar_vitoria_sobre_jogador("uid_teste", "criatura_errante_ci", Vector2(1200, 900))
	if not bool(resultado.get("ok", false)):
		_falhar("Não registrou vitória nem posição inicial.")
		return
	var persistidas := repositorio.listar_criaturas_persistentes()
	if persistidas.size() != 1:
		_falhar("Não listou a criatura persistente.")
		return
	var posicao: Dictionary = persistidas[0].get("posicaoMundo", {})
	if not is_equal_approx(float(posicao.get("x", -1)), 1200.0) or not is_equal_approx(float(posicao.get("y", -1)), 900.0):
		_falhar("A posição inicial não foi persistida.")
		return
	var atualizacao := [{
		"id":"criatura_errante_ci",
		"posicaoMundo":{"x":1210.0,"y":905.0},
		"alvoMundo":{"x":1300.0,"y":950.0}
	}]
	if not repositorio.salvar_posicoes_mundo(atualizacao):
		_falhar("Não salvou a movimentação.")
		return
	persistidas = repositorio.listar_criaturas_persistentes()
	posicao = persistidas[0].get("posicaoMundo", {})
	if not is_equal_approx(float(posicao.get("x", -1)), 1210.0):
		_falhar("A posição atualizada não foi recuperada.")
		return
	for sufixo in ["", ".bak", ".tmp"]:
		var destino := caminho + sufixo
		if FileAccess.file_exists(destino):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(destino))
	print("TESTE DE CRIATURAS ERRANTES PERSISTENTES: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE CRIATURAS ERRANTES PERSISTENTES: " + mensagem)
	quit(1)
