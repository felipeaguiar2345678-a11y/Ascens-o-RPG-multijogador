extends SceneTree
const Comportamento = preload("res://scripts/sistema_comportamento_criaturas.gd")
func _initialize() -> void:
	var criatura := {"evolucao":{"mutacoes":[]}}
	var resultado := Comportamento.decidir(criatura, {"ameacaPresente":true,"distanciaAmeaca":50.0,"forcaCriatura":10.0,"forcaAmeaca":20.0})
	if resultado.get("estado") != Comportamento.FUGINDO:
		_falhar("Não fugiu de ameaça mais forte."); return
	resultado = Comportamento.decidir(criatura, {"habitatAdequado":false})
	if resultado.get("estado") != Comportamento.BUSCANDO_HABITAT:
		_falhar("Não buscou habitat inadequado."); return
	resultado = Comportamento.decidir(criatura, {"invasorTerritorio":true,"forcaCriatura":10.0,"forcaAmeaca":5.0})
	if resultado.get("estado") != Comportamento.DEFENDENDO_TERRITORIO:
		_falhar("Não defendeu território."); return
	resultado = Comportamento.decidir(criatura, {"presaPresente":true,"forcaCriatura":10.0,"forcaAmeaca":5.0})
	if resultado.get("estado") != Comportamento.CACANDO:
		_falhar("Não selecionou caça."); return
	resultado = Comportamento.decidir(criatura, {"ameacaPresente":true,"distanciaAmeaca":40.0,"forcaCriatura":20.0,"forcaAmeaca":10.0})
	if resultado.get("estado") != Comportamento.CACANDO:
		_falhar("Criatura mais forte não perseguiu a presa."); return
	resultado = Comportamento.decidir(criatura, {})
	if resultado.get("estado") != Comportamento.VAGANDO:
		_falhar("Comportamento padrão incorreto."); return
	var mutante := {"evolucao":{"mutacoes":[{"id":"membros_predatorios","atributo":"agilidade"},{"id":"chifres_de_guerra","atributo":"ataque"}]}}
	var normal := Comportamento.decidir(criatura, {"presaPresente":true,"forcaCriatura":10.0,"forcaAmeaca":10.0})
	var evoluido := Comportamento.decidir(mutante, {"presaPresente":true,"forcaCriatura":10.0,"forcaAmeaca":10.0})
	if float(evoluido.get("multiplicadorVelocidade", 1.0)) <= float(normal.get("multiplicadorVelocidade", 1.0)):
		_falhar("Mutação de agilidade não influenciou perseguição."); return
	resultado = Comportamento.decidir(criatura, {"invasorTerritorio":true,"forcaCriatura":10.0,"forcaAmeaca":9.0,"moralMultiplicador":1.5})
	if resultado.get("estado") != Comportamento.DEFENDENDO_TERRITORIO:
		_falhar("Moral elevada não sustentou a defesa territorial."); return
	if not Comportamento.grupo_deve_continuar_confronto_razao(0.60, 1.8, 0.0):
		_falhar("Grupo com moral alta não demonstrou coragem suficiente."); return
	if Comportamento.grupo_deve_continuar_confronto_razao(0.60, 0.5, 0.0):
		_falhar("Grupo com moral baixa não recuou diante de força superior."); return
	var memoria_defensiva_teste := [
		{"tipo":"alerta_perigo","perigo":"incendio","ecossistemaId":"floresta_arcana","grupoOrigemId":"grupo_vizinho","horarioUnix":2000},
		{"especiePredadoraId":"lobo_sombras","ecossistemaId":"floresta_arcana","bioma":"bosque_nevoento","horarioUnix":1900}
	]
	var heranca_defensiva := Comportamento.selecionar_aprendizado_defensivo_herdado(memoria_defensiva_teste, 2001)
	if heranca_defensiva.size() != 2:
		_falhar("Filhote não herdou os conhecimentos defensivos válidos."); return
	var herdou_incendio := false
	var alerta_indireto_correto := false
	var herdou_predador := false
	for lembranca in heranca_defensiva:
		if str(lembranca.get("perigo", "")) == "incendio":
			herdou_incendio = true
			alerta_indireto_correto = str(lembranca.get("nivelConhecimento", "")) == "indireto"
		if str(lembranca.get("especiePredadoraId", "")) == "lobo_sombras":
			herdou_predador = str(lembranca.get("nivelConhecimento", "")) == "vivenciado"
	if not herdou_incendio or not alerta_indireto_correto or not herdou_predador:
		_falhar("Herança não distinguiu alerta indireto de encontro vivenciado."); return
	var memoria_expirada := Comportamento.selecionar_aprendizado_defensivo_herdado(memoria_defensiva_teste, 2000 + 604801)
	if not memoria_expirada.is_empty():
		_falhar("Filhote herdou conhecimento defensivo expirado."); return
	var personalidade_base := {"prudencia":1.0,"protecaoSocial":1.0,"agressividade":1.0,"coragem":1.0,"curiosidade":1.0}
	var adultos_aprendidos := [
		{"vivo":true,"faseVida":"adulto","personalidadeIndividual":{"prudencia":1.30,"protecaoSocial":1.20,"agressividade":0.80,"coragem":1.10,"curiosidade":1.20}},
		{"vivo":true,"faseVida":"adulto","personalidadeIndividual":{"prudencia":1.30,"protecaoSocial":1.20,"agressividade":0.80,"coragem":1.10,"curiosidade":1.20}},
		{"vivo":true,"faseVida":"filhote","personalidadeIndividual":{"prudencia":0.70,"protecaoSocial":0.70,"agressividade":1.30,"coragem":0.70,"curiosidade":0.70}}
	]
	var tendencias_herdadas := Comportamento.herdar_tendencias_temperamentais(personalidade_base, adultos_aprendidos, [{"tipo":"ameaca","horarioUnix":3000}], 3001)
	if float(tendencias_herdadas.get("prudencia", 1.0)) <= 1.0 or float(tendencias_herdadas.get("agressividade", 1.0)) >= 1.0:
		_falhar("Filhote não herdou parcialmente tendências dos adultos experientes."); return
	var sem_experiencia := Comportamento.herdar_tendencias_temperamentais(personalidade_base, adultos_aprendidos, [], 3001)
	if not sem_experiencia == personalidade_base:
		_falhar("Tendências foram herdadas sem experiência registrada."); return
	var experiencia_expirada := Comportamento.herdar_tendencias_temperamentais(personalidade_base, adultos_aprendidos, [{"tipo":"ameaca","horarioUnix":3000}], 3000 + 2592001)
	if not experiencia_expirada == personalidade_base:
		_falhar("Tendências antigas demais foram transmitidas."); return
	var estrategia_cultural := Comportamento.aplicar_tradicao_caca_cooperativa(
		{"estrategia":"perseguir","motivo":"perseguição direta"},
		[{"id":"caca_cooperativa","forca":3}],
		4
	)
	if str(estrategia_cultural.get("estrategia", "")) != "cercar" or float(estrategia_cultural.get("bonusCoordenacao", 0.0)) <= 0.0:
		_falhar("Tradição de caça cooperativa não coordenou um bando numeroso."); return
	var bando_pequeno := Comportamento.aplicar_tradicao_caca_cooperativa(
		{"estrategia":"perseguir"},
		[{"id":"caca_cooperativa","forca":3}],
		2
	)
	if str(bando_pequeno.get("estrategia", "")) != "perseguir":
		_falhar("Tradição coordenou cerco sem número suficiente de predadores."); return
	var taticos := [
		{"individuoId":"filhote","faseVida":"filhote","vivo":true,"posicaoMundo":{"x":100.0,"y":100.0}},
		{"individuoId":"adulto_1","faseVida":"adulto","vivo":true,"posicaoMundo":{"x":110.0,"y":100.0}},
		{"individuoId":"adulto_2","faseVida":"adulto","vivo":true,"posicaoMundo":{"x":120.0,"y":100.0}},
		{"individuoId":"adulto_3","faseVida":"adulto","vivo":true,"posicaoMundo":{"x":150.0,"y":100.0}},
		{"individuoId":"morto","faseVida":"adulto","vivo":false,"posicaoMundo":{"x":105.0,"y":100.0}}
	]
	var formacao := Comportamento.distribuir_papeis_defensivos(taticos, "filhote", Vector2(200.0,100.0))
	var papeis := {}
	for membro in formacao:
		papeis[str(membro.get("individuoId",""))] = str(membro.get("papelDefensivoAtual",""))
	if papeis.get("filhote","") != "recuo_protegido" or papeis.get("adulto_1","") != "guardiao_dos_vulneraveis" or papeis.get("adulto_2","") != "guardiao_dos_vulneraveis" or papeis.get("adulto_3","") != "linha_defensiva":
		_falhar("Papéis defensivos não foram distribuídos por proximidade."); return
	if papeis.get("morto","") != "":
		_falhar("Indivíduo morto recebeu papel tático."); return
	print("TESTE DE COMPORTAMENTO DE CRIATURAS: aprovado.")
	quit(0)
func _falhar(mensagem: String) -> void:
	push_error("TESTE DE COMPORTAMENTO DE CRIATURAS: " + mensagem)
	quit(1)
