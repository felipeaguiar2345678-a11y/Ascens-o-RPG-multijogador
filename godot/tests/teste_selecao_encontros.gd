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
	var marca_ativa := [{"x":100.0,"y":100.0,"raio":100.0,"intensidade":1.0,"criadoUnix":1000,"expiraUnix":2800}]
	if Selecao.calcular_influencia_destruicao(marca_ativa, Vector2(100.0, 100.0), 1000) < 0.99:
		_falhar("Cicatriz ativa não produziu influência máxima no centro."); return
	if Selecao.calcular_influencia_destruicao(marca_ativa, Vector2(100.0, 100.0), 2800) != 0.0:
		_falhar("Cicatriz expirada ainda afeta a fauna."); return
	var direcao_fuga := Selecao.calcular_direcao_fuga_cicatriz(marca_ativa, Vector2(150.0,100.0), 1000)
	if direcao_fuga.x < 0.99 or absf(direcao_fuga.y) > 0.01:
		_falhar("A criatura não recebeu uma direção de fuga para fora da cicatriz."); return
	if Selecao.calcular_direcao_fuga_cicatriz(marca_ativa, Vector2(500.0,500.0), 1000) != Vector2.ZERO:
		_falhar("A cicatriz enviou direção de fuga para criatura fora do raio."); return
	var longe := Selecao.selecionar(criaturas,"floresta_arcana","bosque",50,false,12345,"dia",Vector2(500.0,500.0),marca_ativa,1000)
	if longe.is_empty():
		_falhar("Cicatriz distante afetou encontros fora do raio."); return
	var no_impacto := Selecao.selecionar(criaturas,"floresta_arcana","bosque",50,false,12345,"dia",Vector2(100.0,100.0),marca_ativa,1000)
	if not no_impacto.is_empty():
		_falhar("Fauna comum apareceu no núcleo de uma cicatriz ativa."); return
	var chefe_protegido := Selecao.selecionar([criaturas[2]],"floresta_arcana","bosque",100,true,12345,"dia",Vector2(100.0,100.0),marca_ativa,1000)
	if str(chefe_protegido.get("id","")) != "chefe_bosque":
		_falhar("Cicatriz local bloqueou indevidamente um chefe/evento especial."); return
	var marca_recuperando := [{"x":100.0,"y":100.0,"raio":100.0,"intensidade":0.2,"criadoUnix":1000,"expiraUnix":2800}]
	if Selecao.calcular_influencia_destruicao(marca_recuperando, Vector2(100.0,100.0), 1900) >= 0.85:
		_falhar("A fauna não começou a retornar durante a recuperação gradual."); return
	print("TESTE DE SELEÇÃO DE ENCONTROS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE SELEÇÃO DE ENCONTROS: " + mensagem)
	quit(1)
