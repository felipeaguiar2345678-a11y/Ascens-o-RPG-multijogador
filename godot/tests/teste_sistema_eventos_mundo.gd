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
	print("TESTE DE EVENTOS TEMPORÁRIOS GLOBAIS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE EVENTOS DO MUNDO: " + mensagem)
	quit(1)
