extends SceneTree

const Combate = preload("res://scripts/sistema_combate_cooperativo.gd")
const PalcoAventura = preload("res://scripts/palco_aventura_compartilhada.gd")

func _initialize() -> void:
	_testar_suprema_individual()
	_testar_suprema_em_area()
	_testar_suprema_de_classe_e_combinada()
	_testar_evento_visual_sincronizado()
	print("OK: Supremas cooperativas, carga individual, dano no servidor, alvos múltiplos e reprodução visual idempotente.")
	quit(0)

func _testar_suprema_individual() -> void:
	var criatura := {"id":"guardiao","nome":"Guardião","rank":"A","nivel":20,"vidaMaxima":1000,"ataque":1,"defesa":0}
	var equipe := [
		{"uid":"uid-suprema-a","nome":"Espadachim","vida":1000,"vidaMaxima":1000,"ataque":1,"defesa":0,"armaOnePieceId":"gryphon"},
		{"uid":"uid-suprema-b","nome":"Aliada","vida":1000,"vidaMaxima":1000,"ataque":1,"defesa":0}
	]
	var estado := Combate.criar_estado(criatura, equipe)
	assert(not estado.is_empty(), "O combate de teste precisa ser criado.")
	var suprema_inicial: Dictionary = estado.participantes[0].get("suprema", {})
	assert(str(suprema_inicial.get("armaId", "")) == "gryphon", "A Suprema da Gryphon deve ser inicializada no participante que equipa a arma.")
	assert(int(suprema_inicial.get("carga", -1)) == 0, "A carga da Suprema deve começar zerada.")
	var ataque := Combate.executar_acao(estado, "uid-suprema-a", Combate.ACAO_ATAQUE, 501)
	assert(bool(ataque.get("ok", false)), "O ataque inicial do participante deve funcionar.")
	var estado_ataque: Dictionary = ataque.estado
	assert(int(estado_ataque.participantes[0].suprema.carga) == 12, "Cada turno normal do participante deve carregar +12 na sua Suprema.")
	var defesa := Combate.executar_acao(estado_ataque, "uid-suprema-b", Combate.ACAO_DEFENDER, 502)
	assert(bool(defesa.get("ok", false)), "A aliada deve conseguir concluir seu turno.")
	var volta := Combate.executar_acao(defesa.estado, "uid-suprema-a", Combate.ACAO_ATAQUE, 503)
	assert(bool(volta.get("ok", false)), "O primeiro participante deve conseguir agir novamente.")
	assert(int(volta.estado.participantes[0].suprema.carga) == 24, "A carga deve ser individual e acumular somente nos turnos do dono.")
	var turno_aliada := Combate.executar_acao(volta.estado, "uid-suprema-b", Combate.ACAO_DEFENDER, 505)
	assert(bool(turno_aliada.get("ok", false)), "A aliada deve agir antes da próxima Suprema do espadachim.")
	var pronta: Dictionary = turno_aliada.estado.duplicate(true)
	pronta.participantes[0].suprema.carga = 100
	pronta.participantes[0].suprema.pronta = true
	var liberada := Combate.executar_acao(pronta, "uid-suprema-a", Combate.ACAO_SUPREMA, 506, "guardiao")
	assert(bool(liberada.get("ok", false)), "O participante deve liberar a Suprema quando sua carga chega a 100.")
	var resultado: Dictionary = liberada.estado
	assert(str(resultado.supremaExecutada.get("efeito", "")) == "golpe_do_rei", "A animação deve receber o efeito característico da Gryphon.")
	assert(str(resultado.supremaParticipanteNome) == "Espadachim", "O evento visual deve identificar o dono da Suprema pelo nome.")
	assert(str(resultado.supremaParticipanteUid) == "uid-suprema-a", "O evento deve preservar o UID de quem executou a Suprema.")
	assert(not str(resultado.supremaEventoId).is_empty(), "O evento precisa de um identificador único para sincronização e reprodução única.")
	assert(int(resultado.participantes[0].suprema.carga) == 0 and not bool(resultado.participantes[0].suprema.pronta), "Usar a Suprema deve zerar apenas a carga do dono.")
	assert(int(resultado.participantes[0].danoCausado) == 1000, "A contribuição deve registrar somente o dano efetivamente aplicado.")
	assert(str(resultado.status) == Combate.VITORIA, "A Suprema deve poder concluir o combate cooperativo.")

func _testar_suprema_em_area() -> void:
	var criaturas := [
		{"id":"lobo_a","individuoId":"lobo_a","grupoId":"matilha","nome":"Lobo A","rank":"C","nivel":10,"vidaMaxima":1000,"ataque":1,"defesa":0},
		{"id":"lobo_b","individuoId":"lobo_b","grupoId":"matilha","nome":"Lobo B","rank":"C","nivel":10,"vidaMaxima":1000,"ataque":1,"defesa":0}
	]
	var equipe := [
		{"uid":"uid-terremoto","nome":"Portador da Bisento","vida":1000,"vidaMaxima":1000,"ataque":1,"defesa":0,"armaOnePieceId":"murakumogiri"},
		{"uid":"uid-aliado","nome":"Aliado","vida":1000,"vidaMaxima":1000,"ataque":1,"defesa":0}
	]
	var estado := Combate.criar_estado_grupo(criaturas, equipe)
	assert(not estado.is_empty(), "O encontro com dois inimigos deve ser criado.")
	estado.participantes[0].suprema.carga = 100
	estado.participantes[0].suprema.pronta = true
	var resultado := Combate.executar_acao(estado, "uid-terremoto", Combate.ACAO_SUPREMA, 601, "lobo_a")
	assert(bool(resultado.get("ok", false)), "A Suprema em área deve ser aceita no combate cooperativo.")
	var final: Dictionary = resultado.estado
	assert(int(final.inimigos[0].vida) == 0 and int(final.inimigos[1].vida) == 0, "A Fúria da Gura Gura deve atingir todos os inimigos vivos.")
	assert(final.danosSuprema.size() == 2, "O evento visual deve carregar o dano de cada alvo atingido.")
	assert(int(final.participantes[0].danoCausado) == 2000, "O histórico de contribuição deve somar o dano efetivo em todos os alvos.")
	assert(str(final.supremaExecutada.get("efeito", "")) == "terremoto_dimensional", "A Suprema em área deve preservar sua identidade visual.")
	assert(str(final.supremaParticipanteUid) == "uid-terremoto", "A Suprema em área deve identificar o participante que a executou.")
	assert(not str(final.supremaEventoId).is_empty(), "A Suprema em área também precisa de um identificador de evento sincronizável.")
	assert(str(final.status) == Combate.VITORIA, "Derrotar todos os inimigos com a Suprema deve concluir o encontro.")

func _testar_evento_visual_sincronizado() -> void:
	var palco := Control.new()
	palco.set_script(PalcoAventura)
	root.add_child(palco)
	var snapshot := {
		"ativo": true,
		"combate": {
			"supremaEventoId": "evento-suprema-001",
			"supremaExecutada": {"efeito":"terremoto_dimensional","nome":"Fúria da Gura Gura"},
			"supremaParticipanteNome": "Portador da Bisento",
			"supremaParticipanteUid": "uid-terremoto"
		}
	}
	palco.call("configurar_encontro", snapshot)
	assert(bool(palco.get("_suprema_ativa")), "O snapshot novo deve iniciar o efeito visual da Suprema.")
	assert(str(palco.get("_suprema_evento_id")) == "evento-suprema-001", "O palco deve guardar o identificador sincronizado.")
	assert(str(palco.get("_suprema_autor")) == "Portador da Bisento", "O palco deve exibir o autor correto.")
	palco.set("_suprema_tempo", 1.25)
	palco.call("configurar_encontro", snapshot)
	assert(is_equal_approx(float(palco.get("_suprema_tempo")), 1.25), "Repetir o mesmo snapshot não pode reiniciar a animação.")
	var novo_snapshot: Dictionary = snapshot.duplicate(true)
	novo_snapshot.combate.supremaEventoId = "evento-suprema-002"
	palco.call("configurar_encontro", novo_snapshot)
	assert(is_zero_approx(float(palco.get("_suprema_tempo"))), "Um novo identificador deve iniciar uma nova animação.")
	palco.queue_free()

func _testar_suprema_de_classe_e_combinada() -> void:
	var criatura := {"id":"guardiao_classe","nome":"Guardião de classe","rank":"S","nivel":80,"vidaMaxima":1000,"ataque":1,"defesa":0}
	var equipe := [
		{"uid":"uid-espadachim-classe","nome":"Espadachim","vida":1000,"vidaMaxima":1000,"ataque":1,"defesa":0,"classeId":"espadachim","nivel":80,"armaOnePieceId":"enma"},
		{"uid":"uid-aliado-classe","nome":"Aliado","vida":1000,"vidaMaxima":1000,"ataque":1,"defesa":0,"classeId":"guerreiro","nivel":80}
	]
	var estado := Combate.criar_estado(criatura, equipe)
	assert(not estado.is_empty())
	var membro: Dictionary = estado.participantes[0]
	assert(str(membro.supremasClasse.suprema.id) == "dominio_absoluto")
	assert(str(membro.supremasClasse.avancada.id) == "corte_do_horizonte")
	assert(str(membro.supremasClasse.combinacao.id) == "dominio_enma")
	assert(str(membro.suprema.armaId) == "enma")
	membro.supremasClasse.suprema.carga = 100
	membro.supremasClasse.suprema.pronta = true
	membro.suprema.carga = 100
	membro.suprema.pronta = true
	estado.participantes[0] = membro
	var resultado := Combate.executar_acao(estado, "uid-espadachim-classe", Combate.ACAO_SUPREMA_COMBINADA, 701, "guardiao_classe")
	assert(bool(resultado.get("ok", false)), "A Suprema combinada deve funcionar no combate cooperativo.")
	var final: Dictionary = resultado.estado
	var membro_final: Dictionary = final.participantes[0]
	assert(str(final.supremaExecutada.get("efeito", "")) == "tempestade_haki_roxo")
	assert(str(final.supremaParticipanteUid) == "uid-espadachim-classe")
	assert(int(membro_final.danoCausado) == 1000)
	assert(not bool(membro_final.supremasClasse.suprema.pronta))
	assert(not bool(membro_final.suprema.pronta))
	assert(str(final.status) == Combate.VITORIA)
