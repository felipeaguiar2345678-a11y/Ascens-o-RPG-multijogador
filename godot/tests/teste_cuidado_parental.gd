extends SceneTree
const Cuidado = preload("res://scripts/sistema_cuidado_parental.gd")

func _initialize() -> void:
	var grupo := {"criadoUnix":0,"idadeMaturidadeDias":7.0,"individuos":[]}
	for i in range(2):
		grupo["individuos"].append({"vivo":true,"nascimentoUnix":0})
	for i in range(4):
		grupo["individuos"].append({"vivo":true,"nascimentoUnix":900000})
	var resultado := Cuidado.avaliar(grupo, 1000000)
	if int(resultado.get("adultos", 0)) != 2 or int(resultado.get("filhotes", 0)) != 4:
		_falhar("Não distinguiu corretamente adultos e filhotes."); return
	if absf(float(resultado.get("coberturaCuidado", 0.0)) - 1.0) > 0.001 or absf(float(resultado.get("protecaoFome", 0.0)) - (0.5 * 4.0 / 6.0)) > 0.001:
		_falhar("Dois adultos deveriam cobrir quatro filhotes e reduzir o risco proporcionalmente."); return
	var sem_adultos := {"criadoUnix":0,"idadeMaturidadeDias":7.0,"individuos":[{"vivo":true,"nascimentoUnix":900000},{"vivo":true,"nascimentoUnix":900000}]}
	if float(Cuidado.avaliar(sem_adultos, 1000000).get("protecaoFome", 0.0)) != 0.0:
		_falhar("Filhotes sem adultos não podem receber cuidado parental."); return
	var sem_filhotes := {"criadoUnix":0,"idadeMaturidadeDias":7.0,"individuos":[{"vivo":true,"nascimentoUnix":0}]}
	if float(Cuidado.avaliar(sem_filhotes, 1000000).get("protecaoFome", 0.0)) != 0.0:
		_falhar("Grupos sem filhotes não devem receber bônus de cuidado."); return
	var morto := {"criadoUnix":0,"idadeMaturidadeDias":7.0,"individuos":[{"vivo":false,"nascimentoUnix":0},{"vivo":true,"nascimentoUnix":900000}]}
	if int(Cuidado.avaliar(morto, 1000000).get("adultos", 0)) != 0:
		_falhar("Indivíduos mortos não podem atuar como cuidadores."); return
	print("TESTE DE CUIDADO PARENTAL: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE CUIDADO PARENTAL: " + mensagem)
	quit(1)
