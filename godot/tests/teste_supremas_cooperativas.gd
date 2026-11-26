extends SceneTree

const Combate = preload("res://scripts/sistema_combate_cooperativo.gd")

func _initialize() -> void:
	_testar_suprema_individual()
	_testar_suprema_em_area()
	print("OK: Supremas cooperativas, carga individual, dano no servidor e alvos múltiplos.")
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
	var pronta: Dictionary = volta.estado.duplicate(true)
	pronta.participantes[0].suprema.carga = 100
	pronta.participantes[0].suprema.pronta = true
	var liberada := Combate.executar_acao(pronta, "uid-suprema-a", Combate.ACAO_SUPREMA, 504, "guardiao")
	assert(bool(liberada.get("ok", false)), "O participante deve liberar a Suprema quando sua carga chega a 100.")
	var resultado: Dictionary = liberada.estado
	assert(str(resultado.supremaExecutada.get("efeito", "")) == "golpe_do_rei", "A animação deve receber o efeito característico da Gryphon.")
	assert(str(resultado.supremaParticipanteUid) == "uid-suprema-a", "O evento visual deve identificar o dono da Suprema.")
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
	assert(str(final.status) == Combate.VITORIA, "Derrotar todos os inimigos com a Suprema deve concluir o encontro.")
