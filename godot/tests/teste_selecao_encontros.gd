extends SceneTree

const Selecao = preload("res://scripts/sistema_selecao_encontros.gd")

func _initialize() -> void:
	var criaturas := [
		{"id":"lobo_comum","nome":"Lobo","ecossistemaId":"floresta_arcana","bioma":"bosque","perigo":20,"raridade":"comum","chefe":false},
		{"id":"lobo_raro","nome":"Lobo Raro","ecossistemaId":"floresta_arcana","bioma":"bosque","perigo":50,"raridade":"raro","chefe":false},
		{"id":"chefe_bosque","nome":"Chefe","ecossistemaId":"floresta_arcana","bioma":"bosque","perigo":90,"raridade":"lendario","chefe":true},
		{"id":"deserto","nome":"Criatura do Deserto","ecossistemaId":"deserto_ancestral","bioma":"dunas","perigo":10,"raridade":"comum","chefe":false}
	]
	var escolhida := Selecao.selecionar(criaturas,"floresta_arcana","bosque",50,false,12345)
	if escolhida.is_empty() or not ["lobo_comum","lobo_raro"].has(str(escolhida.get("id",""))):
		_falhar("Selecionou criatura fora do perigo permitido ou chefe bloqueado.")
		return
	var repetida := Selecao.selecionar(criaturas,"floresta_arcana","bosque",50,false,12345)
	if str(escolhida.get("id","")) != str(repetida.get("id","")):
		_falhar("A mesma semente não reproduziu a seleção.")
		return
	if not Selecao.selecionar(criaturas,"deserto_ancestral","dunas",20,false,4).has("id"):
		_falhar("Não encontrou criatura do ecossistema correto.")
		return
	if not Selecao.selecionar(criaturas,"floresta_arcana","bosque",100,true,4).has("id"):
		_falhar("Não selecionou criatura quando havia candidatas.")
		return
	var diurna := {"id":"criatura_diurna","ecossistemaId":"floresta_arcana","bioma":"bosque","perigo":10,"raridade":"comum","atividade":"diurna"}
	var noturna := {"id":"criatura_noturna","ecossistemaId":"floresta_arcana","bioma":"bosque","perigo":10,"raridade":"comum","atividade":"noturna"}
	var encontro_noturno := Selecao.selecionar([diurna, noturna],"floresta_arcana","bosque",20,false,77,"noite")
	if str(encontro_noturno.get("id","")) not in ["criatura_diurna","criatura_noturna"]:
		_falhar("Não selecionou criatura compatível com o período noturno.")
		return
	var encontro_dia := Selecao.selecionar([noturna],"floresta_arcana","bosque",20,false,77,"dia")
	if not encontro_dia.is_empty():
		_falhar("Uma criatura exclusivamente noturna apareceu durante o dia.")
		return
	if not Selecao.selecionar(criaturas,"floresta_arcana","clareira",100,true,4).is_empty():
		_falhar("Selecionou criatura de bioma diferente.")
		return
	print("TESTE DE SELEÇÃO DE ENCONTROS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE SELEÇÃO DE ENCONTROS: " + mensagem)
	quit(1)
