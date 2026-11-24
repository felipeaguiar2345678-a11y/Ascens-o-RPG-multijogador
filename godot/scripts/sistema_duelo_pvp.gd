
extends RefCounted
class_name SistemaDueloPvP

const Equipamentos = preload("res://scripts/sistema_equipamentos.gd")
const ACAO_ATAQUE := "ataque"
const ACAO_MAGIA := "magia"
const ACAO_HABILIDADE := "habilidade"
const ACAO_DEFENDER := "defender"
const ACAO_ESQUIVAR := "esquivar"

static func criar_duelo(id: String, peer_a: int, peer_b: int, perfil_a: Dictionary, perfil_b: Dictionary) -> Dictionary:
	if id.is_empty() or peer_a <= 0 or peer_b <= 0 or peer_a == peer_b:
		return {}
	var lutador_a := _criar_lutador(perfil_a, peer_a)
	var lutador_b := _criar_lutador(perfil_b, peer_b)
	if lutador_a.is_empty() or lutador_b.is_empty() or int(lutador_a.get("vida", 0)) <= 0 or int(lutador_b.get("vida", 0)) <= 0:
		return {}
	return {"id":id,"peerA":peer_a,"peerB":peer_b,"turnoPeer":peer_a,"status":"em_andamento","vencedorPeer":0,"perdedorPeer":0,"rodada":1,"lutadores":{str(peer_a):lutador_a,str(peer_b):lutador_b},"historico":["O duelo começou entre %s e %s." % [lutador_a["nome"],lutador_b["nome"]]]}

static func _criar_lutador(perfil: Dictionary, peer: int) -> Dictionary:
	if not bool(perfil.get("personagemCriado", false)):
		return {}
	var base := {"forca":int(perfil.get("forca",5)),"inteligencia":int(perfil.get("inteligencia",5)),"agilidade":int(perfil.get("agilidade",5)),"vitalidade":int(perfil.get("vitalidade",5)),"espirito":int(perfil.get("espirito",5)),"vidaMaxima":int(perfil.get("vidaMaxima",100)),"manaMaxima":int(perfil.get("manaMaxima",50))}
	var efetivos := Equipamentos.calcular_atributos_efetivos(base, perfil.get("equipamentos", {}))
	var arma := Equipamentos.obter(str(perfil.get("equipamentos", {}).get("mao_principal", "")))
	return {"peerId":peer,"nome":str(perfil.get("nome","Aventureiro")),"vida":clampi(int(perfil.get("vida",efetivos["vidaMaxima"])),0,int(efetivos["vidaMaxima"])),"vidaMaxima":int(efetivos["vidaMaxima"]),"mana":clampi(int(perfil.get("mana",efetivos["manaMaxima"])),0,int(efetivos["manaMaxima"])),"manaMaxima":int(efetivos["manaMaxima"]),"forca":int(efetivos["forca"]),"inteligencia":int(efetivos["inteligencia"]),"agilidade":int(efetivos["agilidade"]),"espirito":int(efetivos["espirito"]),"defesa":int(efetivos["defesaEquipamento"])+int(efetivos["vitalidade"])/3,"armaDano":int(arma.get("dano",5)),"habilidades":(perfil.get("habilidades",[]) if perfil.get("habilidades",[]) is Array else []).duplicate(true),"defendendo":false,"esquivando":false}

static func executar_acao(duelo_original: Dictionary, peer: int, acao: String, habilidade_id: String, semente: int) -> Dictionary:
	var duelo := duelo_original.duplicate(true)
	if str(duelo.get("status","")) != "em_andamento" or int(duelo.get("turnoPeer",-1)) != peer:
		return {"ok":false,"erro":"Ainda não é seu turno no duelo."}
	if not [ACAO_ATAQUE,ACAO_MAGIA,ACAO_HABILIDADE,ACAO_DEFENDER,ACAO_ESQUIVAR].has(acao):
		return {"ok":false,"erro":"Ação PvP inválida."}
	var lutadores: Dictionary = duelo.get("lutadores",{})
	var atacante: Dictionary = lutadores.get(str(peer),{}).duplicate(true)
	var alvo_peer := int(duelo.get("peerB",-1)) if peer == int(duelo.get("peerA",-2)) else int(duelo.get("peerA",-1))
	var alvo: Dictionary = lutadores.get(str(alvo_peer),{}).duplicate(true)
	if atacante.is_empty() or alvo.is_empty() or int(atacante.get("vida",0)) <= 0 or int(alvo.get("vida",0)) <= 0:
		return {"ok":false,"erro":"Estado dos participantes inválido."}
	var historico: Array = duelo.get("historico",[])
	if acao == ACAO_DEFENDER:
		atacante["defendendo"] = true
		atacante["esquivando"] = false
		historico.append("%s assumiu uma postura defensiva." % atacante["nome"])
	elif acao == ACAO_ESQUIVAR:
		atacante["esquivando"] = true
		atacante["defendendo"] = false
		historico.append("%s preparou uma esquiva." % atacante["nome"])
	else:
		var dano_base := maxi(1,int(atacante.get("forca",5))+int(atacante.get("armaDano",5)))
		if acao == ACAO_MAGIA:
			if int(atacante.get("mana",0)) < 8:
				return {"ok":false,"erro":"Mana insuficiente para magia."}
			atacante["mana"] = int(atacante["mana"])-8
			dano_base = maxi(1,int(atacante.get("inteligencia",5))+int(atacante.get("espirito",5)))
		elif acao == ACAO_HABILIDADE:
			var habilidade := _buscar_habilidade(atacante,habilidade_id)
			if habilidade.is_empty():
				return {"ok":false,"erro":"Habilidade não pertence ao seu personagem."}
			var custo := clampi(int(habilidade.get("custoMana",5)),0,100000)
			if int(atacante.get("mana",0)) < custo:
				return {"ok":false,"erro":"Mana insuficiente para essa habilidade."}
			atacante["mana"] = int(atacante["mana"])-custo
			dano_base = maxi(1,int(habilidade.get("dano",habilidade.get("poder",dano_base*1.4))))
		var rng := RandomNumberGenerator.new()
		rng.seed = semente
		if bool(alvo.get("esquivando",false)) and rng.randf() < clampf(0.08+float(alvo.get("agilidade",5))*0.003,0.08,0.40):
			historico.append("%s esquivou do ataque de %s." % [alvo["nome"],atacante["nome"]])
		else:
			var critico := rng.randf() < clampf(0.05+float(atacante.get("agilidade",5))*0.002,0.05,0.25)
			var dano := maxi(1,int(round(float(dano_base)*(1.7 if critico else 1.0)-float(alvo.get("defesa",0))*0.45)))
			if bool(alvo.get("defendendo",false)):
				dano = maxi(1,int(round(float(dano)*0.5)))
			alvo["vida"] = maxi(0,int(alvo.get("vida",0))-dano)
			historico.append("%s causou %d de dano em %s%s." % [atacante["nome"],dano,alvo["nome"]," (crítico)" if critico else ""])
		alvo["defendendo"] = false
		alvo["esquivando"] = false
	atacante["defendendo"] = false if acao != ACAO_DEFENDER else true
	lutadores[str(peer)] = atacante
	lutadores[str(alvo_peer)] = alvo
	duelo["lutadores"] = lutadores
	duelo["rodada"] = int(duelo.get("rodada",1))+1
	if int(alvo.get("vida",0)) <= 0:
		duelo["status"] = "vitoria"
		duelo["vencedorPeer"] = peer
		duelo["perdedorPeer"] = alvo_peer
		historico.append("%s venceu o duelo!" % atacante["nome"])
	else:
		duelo["turnoPeer"] = alvo_peer
	if historico.size() > 30:
		historico = historico.slice(historico.size()-30)
	duelo["historico"] = historico
	return {"ok":true,"duelo":duelo}

static func _buscar_habilidade(lutador: Dictionary, habilidade_id: String) -> Dictionary:
	if habilidade_id.is_empty():
		return {}
	for habilidade in lutador.get("habilidades",[]):
		if habilidade is Dictionary and str(habilidade.get("id","")) == habilidade_id:
			return habilidade.duplicate(true)
	return {}

static func estado_para_peer(duelo: Dictionary, peer: int) -> Dictionary:
	var a := int(duelo.get("peerA",-1))
	var b := int(duelo.get("peerB",-1))
	var proprio := str(peer)
	var adversario := str(b) if peer == a else str(a)
	var lutadores: Dictionary = duelo.get("lutadores",{})
	var jogador: Dictionary = lutadores.get(proprio,{}).duplicate(true)
	var inimigo: Dictionary = lutadores.get(adversario,{}).duplicate(true)
	var eh_turno := int(duelo.get("turnoPeer",-1)) == peer
	return {"status":str(duelo.get("status","em_andamento")),"turno":"jogador" if eh_turno else "inimigo","jogador":jogador,"inimigo":inimigo,"historico":duelo.get("historico",[]).duplicate(true),"pvp":true,"dueloId":str(duelo.get("id","")),"rodada":int(duelo.get("rodada",1))}

