extends SceneTree

const Eventos = preload("res://scripts/sistema_eventos_mundo.gd")

func _initialize() -> void:
	var inicial := Eventos.criar_documento([
		{"id":"eclipse-1","tipo":"eclipse","inicioUnix":1000,"fimUnix":2000},
		{"id":"invasao-1","tipo":"invasao","inicioUnix":2500,"fimUnix":4000}
	])
	if not Eventos.documento_valido(inicial):
		_falhar("Documento válido foi rejeitado.")
		return
	if Eventos.listar_ativos(inicial, 1500).size() != 1:
		_falhar("Evento ativo não foi recuperado pelo horário Unix.")
		return
	if Eventos.listar_ativos(inicial, 2200).size() != 0:
		_falhar("Evento futuro foi exibido antes do início.")
		return
	var antes := Eventos.expirar(inicial, 1999)
	if antes["expirados"].size() != 0:
		_falhar("Evento expirou antes do prazo.")
		return
	var no_prazo := Eventos.expirar(inicial, 2000)
	if no_prazo["expirados"] != ["eclipse-1"]:
		_falhar("Evento não expirou exatamente no prazo.")
		return
	var depois := Eventos.expirar(no_prazo["payload"], 4000)
	if depois["payload"]["eventos"].size() != 0:
		_falhar("Evento não expirou após ausência prolongada.")
		return
	var registro := Eventos.registrar(Eventos.criar_documento(), {"id":"novo","tipo":"lua_sangrenta","inicioUnix":3000,"fimUnix":5000}, 2500)
	if not registro["ok"] or Eventos.listar_ativos(registro["payload"], 3500).size() != 1:
		_falhar("Novo evento não foi registrado corretamente.")
		return
	var duplicado := Eventos.registrar(registro["payload"], {"id":"novo","tipo":"lua_sangrenta","inicioUnix":3000,"fimUnix":5000}, 2500)
	if duplicado["ok"]:
		_falhar("Identificador duplicado foi aceito.")
		return
	var invalido := Eventos.criar_documento([{"id":"ruim","tipo":"x","inicioUnix":100,"fimUnix":9999999999}])
	if Eventos.documento_valido(invalido):
		_falhar("Evento com duração excessiva foi aceito.")
		return
	var duracao_maxima := Eventos.criar_documento([{"id":"limite","tipo":"evento","inicioUnix":1000,"fimUnix":1000 + Eventos.DURACAO_MAXIMA_SEGUNDOS}])
	if not Eventos.documento_valido(duracao_maxima):
		_falhar("Evento com duração máxima permitida foi rejeitado.")
		return
	var duracao_excedida := Eventos.criar_documento([{"id":"excesso","tipo":"evento","inicioUnix":1000,"fimUnix":1001 + Eventos.DURACAO_MAXIMA_SEGUNDOS}])
	if Eventos.documento_valido(duracao_excedida):
		_falhar("Evento acima da duração máxima foi aceito.")
		return
	var inicio_invalido := Eventos.criar_documento([{"id":"sem-inicio","tipo":"evento","inicioUnix":0,"fimUnix":1000}])
	if Eventos.documento_valido(inicio_invalido):
		_falhar("Evento sem horário Unix inicial válido foi aceito.")
		return
	var registro_vencido := Eventos.registrar(Eventos.criar_documento(), {"id":"vencido","tipo":"evento","inicioUnix":1000,"fimUnix":2000}, 2000)
	if registro_vencido["ok"]:
		_falhar("Evento com prazo já encerrado foi registrado.")
		return
	var muitos_eventos: Array = []
	for indice in range(Eventos.LIMITE_EVENTOS):
		muitos_eventos.append({"id":"evento-%d" % indice,"tipo":"teste","inicioUnix":1000,"fimUnix":2000})
	if not Eventos.documento_valido(Eventos.criar_documento(muitos_eventos)):
		_falhar("O limite máximo permitido de eventos foi rejeitado.")
		return
	muitos_eventos.append({"id":"evento-extra","tipo":"teste","inicioUnix":1000,"fimUnix":2000})
	if Eventos.documento_valido(Eventos.criar_documento(muitos_eventos)):
		_falhar("Documento acima do limite de eventos foi aceito.")
		return
	var registro_apos_expiracao := Eventos.registrar(Eventos.criar_documento([
		{"id":"antigo","tipo":"teste","inicioUnix":1000,"fimUnix":2000}
	]), {"id":"novo-apos-expiracao","tipo":"teste","inicioUnix":3000,"fimUnix":4000}, 2500)
	if not registro_apos_expiracao["ok"] or registro_apos_expiracao["payload"]["eventos"].size() != 1:
		_falhar("Registro não removeu eventos expirados antes de persistir o novo.")
		return
	print("TESTE DE EVENTOS TEMPORÁRIOS GLOBAIS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE EVENTOS DO MUNDO: " + mensagem)
	quit(1)
