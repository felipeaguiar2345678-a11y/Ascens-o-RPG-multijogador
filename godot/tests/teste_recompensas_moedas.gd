extends SceneTree

const SistemaDrops = preload("res://scripts/sistema_drops.gd")
const Repositorio = preload("res://scripts/repositorio_personagem_servidor.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var ranks := ["E","D","C","B","A","S","SS","SSS"]
	var moedas := ["bronze","bronze","ferro","ferro","ouro","ouro","diamante","jade"]
	for i in range(ranks.size()):
		var criatura := {"id":"criatura_%s" % ranks[i],"rank":ranks[i],"nivel":10,"perigo":20}
		var entrada := SistemaDrops.criar_entrada_moeda_criatura(criatura, {"nivelPerigo":20,"sorte":0})
		if str(entrada.get("denominacaoMoeda","")) != moedas[i]:
			_falhar("Denominação incorreta para rank %s." % ranks[i])
			return
		if int(entrada.get("quantidadeMinima",0)) < 1 or int(entrada.get("quantidadeMaxima",0)) < int(entrada.get("quantidadeMinima",0)):
			_falhar("Quantidade inválida para rank %s." % ranks[i])
			return
	var base := SistemaDrops.criar_entrada_moeda_criatura({"rank":"C","nivel":10}, {"sorte":0})
	var sorte := SistemaDrops.criar_entrada_moeda_criatura({"rank":"C","nivel":10}, {"sorte":100})
	if float(sorte.get("chance",0.0)) <= float(base.get("chance",0.0)):
		_falhar("Sorte não aumentou a chance de moeda.")
		return
	var chefe := SistemaDrops.criar_entrada_moeda_criatura({"rank":"A","nivel":10,"chefe":true}, {})
	var normal := SistemaDrops.criar_entrada_moeda_criatura({"rank":"A","nivel":10}, {})
	if int(chefe.get("quantidadeMinima",0)) <= int(normal.get("quantidadeMinima",0)):
		_falhar("Chefe não recebeu quantidade superior de moedas.")
		return
	var repositorio = Repositorio.new()
	var uid := "ci_drop_moedas_%s" % str(Time.get_ticks_usec())
	var perfil := repositorio.carregar_ou_criar(uid)
	if perfil.is_empty() or repositorio.criar_personagem(uid,"Teste Moedas","masculino","masc_cabelo_curto","humano","guerreiro").is_empty():
		_falhar("Não foi possível criar personagem de teste.")
		return
	var drop := {"itemId":"moeda_ferro","nome":"Moedas de Ferrak ⚒","categoria":"moeda","raridade":"comum","quantidade":7,"denominacaoMoeda":"ferro"}
	if not repositorio.conceder_drops(uid,[drop]):
		_falhar("Servidor recusou drop de moedas.")
		return
	var salvo := repositorio.carregar_ou_criar(uid)
	if int(salvo.get("moedas",{}).get("ferro",0)) != 7:
		_falhar("Moedas não foram persistidas na carteira.")
		return
	if not salvo.get("inventario",[]).is_empty():
		_falhar("Moedas foram inseridas incorretamente no inventário.")
		return
	print("TESTE DE RECOMPENSAS EM MOEDAS: rank, sorte, chefes e persistência aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE RECOMPENSAS EM MOEDAS: " + mensagem)
	quit(1)
