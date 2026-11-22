extends RefCounted
class_name SistemaCicloNoturno

## Regras determinísticas do ciclo diário. A hora deve vir do relógio autoritativo.
const MULTIPLICADOR_ATRIBUTOS_NOTURNOS := 1.5
const MULTIPLICADOR_XP_NOTURNO := 1.5
const MULTIPLICADOR_CHANCE_DROP_NOTURNO := 1.5
const MULTIPLICADOR_QUANTIDADE_DROP_NOTURNO := 1.25

## Relógio acelerado compartilhado: ciclo completo de 3h30 (2h de dia + 1h30 noturna).
const DURACAO_DIA_SEGUNDOS := 7200
const DURACAO_CREPUSCULO_SEGUNDOS := 1200
const DURACAO_NOITE_SEGUNDOS := 2400
const DURACAO_MADRUGADA_SEGUNDOS := 1800
const DURACAO_CICLO_SEGUNDOS := DURACAO_DIA_SEGUNDOS + DURACAO_CREPUSCULO_SEGUNDOS + DURACAO_NOITE_SEGUNDOS + DURACAO_MADRUGADA_SEGUNDOS

static func periodo_por_tempo_no_ciclo(segundos_no_ciclo: int) -> String:
	var tempo := posmod(segundos_no_ciclo, DURACAO_CICLO_SEGUNDOS)
	if tempo < DURACAO_DIA_SEGUNDOS:
		return "dia"
	tempo -= DURACAO_DIA_SEGUNDOS
	if tempo < DURACAO_CREPUSCULO_SEGUNDOS:
		return "crepusculo"
	tempo -= DURACAO_CREPUSCULO_SEGUNDOS
	if tempo < DURACAO_NOITE_SEGUNDOS:
		return "noite"
	return "madrugada"

## Usa Unix UTC apenas como contador comum; não depende do fuso ou relógio local de cada jogador.
## O servidor e todos os clientes calculam o mesmo dia, fase lunar e período.
static func criar_contexto_por_tempo_unix(segundos_unix: int, semente_mundo: int = 20261122) -> Dictionary:
	var ciclo := maxi(0, segundos_unix) / DURACAO_CICLO_SEGUNDOS
	var segundo_no_ciclo := posmod(maxi(0, segundos_unix), DURACAO_CICLO_SEGUNDOS)
	var periodo := periodo_por_tempo_no_ciclo(segundo_no_ciclo)
	var dia_mundo := int(ciclo) + 1
	var minuto_no_ciclo := int(segundo_no_ciclo / 60)
	var hora_visual := int(floor(float(minuto_no_ciclo) / (DURACAO_CICLO_SEGUNDOS / 60.0) * 24.0))
	var evento := evento_celeste_por_dia(dia_mundo, semente_mundo)
	return {
		"hora":hora_visual,
		"dia":dia_mundo,
		"periodo":periodo,
		"noturno":esta_no_periodo_noturno(periodo),
		"faseLunar":fase_lunar_por_dia(dia_mundo),
		"eventoCeleste":evento,
		"segundoNoCiclo":segundo_no_ciclo,
		"minutoNoCiclo":minuto_no_ciclo,
		"duracaoCicloSegundos":DURACAO_CICLO_SEGUNDOS
	}

static func periodo_por_hora(hora: int) -> String:
	if hora < 0 or hora > 23:
		return "indefinido"
	if hora >= 5 and hora < 18:
		return "dia"
	if hora >= 18 and hora < 20:
		return "crepusculo"
	if hora >= 20 or hora < 4:
		return "noite"
	return "madrugada"

static func esta_no_periodo_noturno(periodo: String) -> bool:
	return ["crepusculo", "noite", "madrugada"].has(periodo)

static func criatura_disponivel(criatura: Dictionary, periodo: String) -> bool:
	if periodo == "indefinido" or periodo.is_empty():
		return false
	var atividade := str(criatura.get("periodoAtividade", criatura.get("atividade", "qualquer"))).to_lower()
	var exclusiva_noturna := bool(criatura.get("exclusivaNoturna", false))
	if exclusiva_noturna and not esta_no_periodo_noturno(periodo):
		return false
	if atividade in ["noturna", "noite"] and not esta_no_periodo_noturno(periodo):
		return false
	if atividade in ["diurna", "dia"] and esta_no_periodo_noturno(periodo):
		return false
	if atividade in ["crepuscular", "crepusculo"] and not ["crepusculo", "madrugada"].has(periodo):
		return false
	return true

## Retorna uma cópia para que os atributos catalogados nunca sejam alterados.
## O marcador evita aplicar 1,5x duas vezes sobre a mesma cópia.
static func preparar_criatura_para_periodo(criatura: Dictionary, periodo: String) -> Dictionary:
	if criatura.is_empty() or not criatura_disponivel(criatura, periodo):
		return {}
	var copia := criatura.duplicate(true)
	if not esta_no_periodo_noturno(periodo) or bool(copia.get("_ajusteNoturnoAplicado", false)):
		return copia
	for campo in ["vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico"]:
		if copia.has(campo):
			copia[campo] = maxi(1 if campo == "vidaMaxima" else 0, roundi(float(copia[campo]) * MULTIPLICADOR_ATRIBUTOS_NOTURNOS))
	if copia.has("vida"):
		copia["vida"] = maxi(1, roundi(float(copia["vida"]) * MULTIPLICADOR_ATRIBUTOS_NOTURNOS))
	copia["_ajusteNoturnoAplicado"] = true
	copia["periodoEncontro"] = periodo
	copia["multiplicadorNoturno"] = MULTIPLICADOR_ATRIBUTOS_NOTURNOS
	return copia

static func calcular_experiencia(base: int, periodo: String, criatura: Dictionary = {}) -> int:
	if base <= 0:
		return 0
	var bonus := MULTIPLICADOR_XP_NOTURNO if esta_no_periodo_noturno(periodo) else 1.0
	if bool(criatura.get("recompensaNoturnaEspecial", false)) and esta_no_periodo_noturno(periodo):
		bonus *= 1.25
	return maxi(0, roundi(float(base) * bonus))

## Calendário celeste compartilhado: calendário de 28 dias, com fenômenos raros.
const CICLO_LUNAR_DIAS := 28
const CICLO_EVENTOS_RAROS_DIAS := 112

static func fase_lunar_por_dia(dia_mundo: int) -> String:
	if dia_mundo < 1:
		return "indefinida"
	match posmod(dia_mundo - 1, CICLO_LUNAR_DIAS) + 1:
		1: return "lua_nova"
		4: return "lua_crescente"
		8: return "quarto_crescente"
		11: return "lua_gibosa_crescente"
		14: return "lua_cheia"
		18: return "lua_gibosa_minguante"
		22: return "quarto_minguante"
		25: return "lua_minguante"
		_: return "fase_intermediaria"

## Fenômenos sorteados independentemente. A semente deve ser definida e persistida pelo servidor.
## Repetir a mesma semente e o mesmo dia sempre produz o mesmo céu para todos os jogadores.
const EVENTOS_CELESTES := [
	{"id":"lua_cheia","nome":"Lua Cheia","tituloNoite":"A Noite do Luar Prateado","mensagemInicio":"A luz prateada cobre o mundo. Criaturas lunares podem deixar seus esconderijos.","chance":0.12,"raridade":"incomum","aparicao":1.25,"xp":1.1,"drop":1.15,"criaturas":"lunares"},
	{"id":"superlua","nome":"Superlua","tituloNoite":"A Noite da Superlua Ancestral","mensagemInicio":"A lua parece próxima o bastante para tocar as montanhas. Presenças ancestrais despertam.","chance":0.07,"raridade":"rara","aparicao":1.35,"xp":1.2,"drop":1.4,"criaturas":"ancestrais"},
	{"id":"lua_azul","nome":"Lua Azul","tituloNoite":"A Noite da Lua Azul","mensagemInicio":"Uma luz azul sobrenatural atravessa o céu. Criaturas arcanas e tesouros raros podem surgir.","chance":0.04,"raridade":"muito_rara","aparicao":1.5,"xp":1.35,"drop":1.75,"criaturas":"arcanas"},
	{"id":"aurora_arcana","nome":"Aurora Arcana","tituloNoite":"A Noite da Aurora Arcana","mensagemInicio":"Véus de magia dançam no céu. A energia arcana transforma os encontros desta noite.","chance":0.03,"raridade":"lendaria","aparicao":1.5,"xp":1.5,"drop":1.75,"criaturas":"arcanas","recurso":"essencia_aurora"},
	{"id":"chuva_de_estrelas","nome":"Chuva de Estrelas","tituloNoite":"A Noite das Estrelas Caídas","mensagemInicio":"Fragmentos luminosos cruzam o firmamento. Procure sinais de recursos celestes.","chance":0.025,"raridade":"rara","aparicao":1.0,"xp":1.0,"drop":1.5,"recurso":"fragmentos_celestes"},
	{"id":"lua_negra","nome":"Lua Negra","tituloNoite":"A Noite do Véu Negro","mensagemInicio":"A escuridão parece engolir até o luar. Criaturas das sombras estão mais ativas.","chance":0.015,"raridade":"muito_rara","aparicao":1.5,"xp":1.3,"drop":1.5,"criaturas":"sombras"},
	{"id":"lua_de_sangue","nome":"Lua de Sangue","tituloNoite":"A Noite da Superlua de Sangue","mensagemInicio":"O céu fica vermelho como sangue. Predadores sanguinários espreitam e as recompensas são maiores.","chance":0.01,"raridade":"muito_rara","aparicao":1.5,"xp":1.5,"drop":1.5,"criaturas":"sanguinarias"},
	{"id":"eclipse","nome":"Eclipse","tituloNoite":"A Noite do Eclipse Ancestral","mensagemInicio":"A luz desaparece do céu. Uma força ancestral altera os perigos e as recompensas desta noite.","chance":0.005,"raridade":"lendaria","aparicao":1.75,"xp":1.75,"drop":1.75,"criaturas":"ancestrais"}
]

static func evento_celeste_por_dia(dia_mundo: int, semente_mundo: int = 20261122) -> Dictionary:
	if dia_mundo < 1:
		return _evento_celeste_vazio()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("%d:%d:eventos_celestes" % [semente_mundo, dia_mundo]))
	var sorteados: Array[Dictionary] = []
	for definicao in EVENTOS_CELESTES:
		if rng.randf() < float(definicao["chance"]):
			sorteados.append(definicao)
	if sorteados.is_empty():
		return _evento_celeste_vazio()
	return _combinar_eventos_celestes(sorteados)

static func _evento_celeste_vazio() -> Dictionary:
	return {"id":"nenhum","nome":"Céu comum","eventos":[],"raridade":"comum","multiplicadorAparicao":1.0,"multiplicadorXP":1.0,"multiplicadorDrop":1.0}

static func _combinar_eventos_celestes(eventos: Array[Dictionary]) -> Dictionary:
	var nomes: Array[String] = []
	var titulos_noite: Array[String] = []
	var mensagens_inicio: Array[String] = []
	var ids: Array[String] = []
	var criaturas: Array[String] = []
	var recursos: Array[String] = []
	var raridade := "incomum"
	var aparicao := 1.0
	var xp := 1.0
	var drop := 1.0
	var ordem_raridade := {"comum":0,"incomum":1,"rara":2,"muito_rara":3,"lendaria":4,"transcendente":5,"unica":6}
	for evento in eventos:
		ids.append(str(evento["id"]))
		nomes.append(str(evento["nome"]))
		titulos_noite.append(str(evento.get("tituloNoite", evento["nome"])))
		mensagens_inicio.append(str(evento.get("mensagemInicio", "Fenômenos incomuns alteram esta noite.")))
		var r := str(evento["raridade"])
		if int(ordem_raridade.get(r, 0)) > int(ordem_raridade.get(raridade, 0)):
			raridade = r
		aparicao *= float(evento["aparicao"])
		xp *= float(evento["xp"])
		drop *= float(evento["drop"])
		var tipo := str(evento.get("criaturas", ""))
		var recurso := str(evento.get("recurso", ""))
		if not tipo.is_empty() and not criaturas.has(tipo):
			criaturas.append(tipo)
		if not recurso.is_empty() and not recursos.has(recurso):
			recursos.append(recurso)
	var nome_final := " + ".join(PackedStringArray(nomes))
	var id_final := "+".join(PackedStringArray(ids))
	var titulo_noite := titulos_noite[0] if titulos_noite.size() == 1 else "A Noite da Convergência: " + " + ".join(PackedStringArray(titulos_noite))
	var mensagem_inicio := " ".join(PackedStringArray(mensagens_inicio))
	if eventos.size() >= 2:
		raridade = "transcendente" if eventos.size() >= 3 else "lendaria"
		nome_final = "Convergência Celeste: " + nome_final
	return {
		"id":id_final,"nome":nome_final,"tituloNoite":titulo_noite,"mensagemInicio":mensagem_inicio,"eventos":ids,"quantidadeFenomenos":eventos.size(),
		"combinado":eventos.size() > 1,"raridade":raridade,
		"multiplicadorAparicao":min(3.0, aparicao),
		"multiplicadorXP":min(2.5, xp),
		"multiplicadorDrop":min(3.0, drop),
		"criaturas":criaturas,"recursos":recursos
	}

## Gera um anúncio somente na transição para o período noturno.
## O chamador deve guardar o período anterior para evitar anúncios repetidos.
static func criar_anuncio_inicio_noite(contexto: Dictionary, periodo_anterior: String) -> Dictionary:
	var periodo_atual := str(contexto.get("periodo", "indefinido"))
	if not esta_no_periodo_noturno(periodo_atual) or esta_no_periodo_noturno(periodo_anterior):
		return {"deveAnunciar":false}
	var evento: Dictionary = contexto.get("eventoCeleste", {})
	if evento.is_empty() or str(evento.get("id", "nenhum")) == "nenhum":
		return {"deveAnunciar":false,"titulo":"A noite chegou","mensagem":"O mundo mergulha na escuridão. Fique atento ao que se move nela.","raridade":"comum"}
	return {
		"deveAnunciar":true,
		"titulo":str(evento.get("tituloNoite", evento.get("nome", "Uma noite incomum"))),
		"mensagem":str(evento.get("mensagemInicio", "Algo mudou no céu. Esta noite não será comum.")),
		"raridade":str(evento.get("raridade", "incomum")),
		"eventoId":str(evento.get("id", "nenhum")),
		"multiplicadorAparicao":float(evento.get("multiplicadorAparicao", 1.0)),
		"multiplicadorXP":float(evento.get("multiplicadorXP", 1.0)),
		"multiplicadorDrop":float(evento.get("multiplicadorDrop", 1.0))
	}

static func criar_contexto(hora_autoritativa: int, dia_mundo: int = 1, semente_mundo: int = 20261122) -> Dictionary:
	var periodo := periodo_por_hora(hora_autoritativa)
	var evento := evento_celeste_por_dia(dia_mundo, semente_mundo)
	return {
		"hora":hora_autoritativa,
		"dia":dia_mundo,
		"periodo":periodo,
		"noturno":esta_no_periodo_noturno(periodo),
		"faseLunar":fase_lunar_por_dia(dia_mundo),
		"eventoCeleste":evento
	}
