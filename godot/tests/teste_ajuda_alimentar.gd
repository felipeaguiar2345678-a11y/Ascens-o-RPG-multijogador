extends SceneTree

const SISTEMA = preload("res://scripts/sistema_ajuda_alimentar.gd")

func _initialize() -> void:
	var relacao := {"estado":"aliado","confianca":0.75}
	var doador := {
		"grupoId":"grupo_a","ecossistemaId":"floresta_arcana",
		"territorio":{"centro":{"x":100.0,"y":100.0},"raio":30.0},
		"relacoesGrupos":{"grupo_b":relacao}
	}
	var receptor := {
		"grupoId":"grupo_b","ecossistemaId":"floresta_arcana",
		"territorio":{"centro":{"x":150.0,"y":100.0},"raio":30.0},
		"relacoesGrupos":{"grupo_a":relacao}
	}
	var indices := {"grupo_a":1.0,"grupo_b":0.10}
	var cooldown := {}
	var resultado := SISTEMA.aplicar_ajuda([doador,receptor],indices,cooldown,100000)
	var novos: Dictionary = resultado.get("disponibilidadePorGrupo", {})
	if absf(float(novos.get("grupo_a",0.0))-0.85)>0.001 or absf(float(novos.get("grupo_b",0.0))-0.25)>0.001:
		_falhar("A transferência não preservou o total de alimento disponível."); return
	if resultado.get("eventos",[]).size()!=1:
		_falhar("Não registrou exatamente um apoio alimentar."); return
	var repetido := SISTEMA.aplicar_ajuda([doador,receptor],indices,cooldown,100001)
	if not repetido.get("eventos",[]).is_empty():
		_falhar("Ignorou o intervalo de seis horas entre apoios."); return
	receptor["ecossistemaId"]="deserto_ancestral"
	var outro_ecossistema := SISTEMA.aplicar_ajuda([doador,receptor],indices,{},200000)
	if not outro_ecossistema.get("eventos",[]).is_empty():
		_falhar("Permitiu ajuda entre ecossistemas diferentes."); return
	print("TESTE DE AJUDA ALIMENTAR: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE AJUDA ALIMENTAR: "+mensagem)
	quit(1)
