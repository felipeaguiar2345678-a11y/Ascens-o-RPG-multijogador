extends RefCounted
class_name SistemaSerpenteMundo

## Regras puras da incursão mundial. O chamador deve ser exclusivamente o servidor.
## A cabeça é o único alvo; o corpo permanece como cenário e perigo ambiental.
const ID_CHEFE := "serpente_do_mundo"
const VIDA_TOTAL_PADRAO := 2000000
const RAIO_ARENA := 190.0
const LIMITE_PARTICIPANTES := 40
const INTERVALO_ACAO_MS := 1200
const INTERVALO_ATAQUE_MS := 12000
const TEMPO_RENASCIMENTO_SEGUNDOS := 1800
const MAX_TENTATIVAS_FILHOTE := 3
const STATUS_DISPONIVEL := "disponivel"
const STATUS_EM_COMBATE := "em_combate"
const STATUS_DERROTADA := "derrotada"

static func criar_estado(vida_total: int = VIDA_TOTAL_PADRAO) -> Dictionary:
	if vida_total < 1 or vida_total > 2000000000:
		return {}
	return {
		"versao": 2, "chefeId": ID_CHEFE, "status": STATUS_DISPONIVEL,
		"vida": vida_total, "vidaMaxima": vida_total, "participantes": {},
		"tentativasDomesticacao": {}, "criadaUnix": int(Time.get_unix_time_from_system()),
		"derrotadaUnix": 0, "proximoRenascimentoUnix": 0, "ciclos": 1,
		"totalDerrotas": 0, "ultimoAtaque": "A Serpente observa a arena.",
		"ultimoAtaqueUnix": 0, "serpenteOriginalPreservada": true
	}

static func entrar(estado_original: Dictionary, uid: String, peer_id: int, posicao: Vector2, posicao_cabeca: Vector2) -> Dictionary:
	if estado_original.is_empty() or str(estado_original.get("status", "")) not in [STATUS_DISPONIVEL, STATUS_EM_COMBATE]:
		return {"ok": false, "erro": "A incursão não está aceitando participantes."}
	if uid.strip_edges().is_empty() or uid.length() > 128 or peer_id <= 0:
		return {"ok": false, "erro": "Identidade de participante inválida."}
	if posicao.distance_to(posicao_cabeca) > RAIO_ARENA:
		return {"ok": false, "erro": "Aproxime-se da cabeça da Serpente do Mundo para entrar na arena."}
	var estado := estado_original.duplicate(true)
	var participantes: Dictionary = estado.get("participantes", {})
	if participantes.has(uid):
		var existente: Dictionary = participantes[uid]
		if int(existente.get("peerId", -1)) != peer_id and bool(existente.get("ativo", true)):
			return {"ok": false, "erro": "Esta conta já está participando da incursão."}
		existente["peerId"] = peer_id
		existente["ativo"] = true
		participantes[uid] = existente
		estado["participantes"] = participantes
		return {"ok": true, "estado": estado, "jaParticipava": true}
	if participantes.size() >= LIMITE_PARTICIPANTES:
		return {"ok": false, "erro": "A arena atingiu o limite de participantes."}
	participantes[uid] = {"peerId": peer_id, "danoTotal": 0, "entrouUnix": int(Time.get_unix_time_from_system()), "ultimaAcaoMs": -INTERVALO_ACAO_MS, "ativo": true}
	estado["participantes"] = participantes
	estado["status"] = STATUS_EM_COMBATE
	return {"ok": true, "estado": estado, "jaParticipava": false}

static func calcular_dano_jogador(perfil: Dictionary, acao: String) -> int:
	if acao == "ataque":
		return clampi(12 + int(perfil.get("forca", 5)) * 3, 1, 250000)
	if acao == "magia":
		return clampi(10 + int(perfil.get("inteligencia", 5)) * 3 + int(perfil.get("espirito", 5)), 1, 250000)
	return 0

static func calcular_dano_serpente(perfil: Dictionary) -> int:
	var vida_maxima := maxi(1, int(perfil.get("vidaMaxima", 100)))
	var vitalidade := maxi(0, int(perfil.get("vitalidade", 5)))
	var dano_bruto := maxi(8, int(round(float(vida_maxima) * 0.12)))
	return maxi(5, dano_bruto - mini(dano_bruto - 5, vitalidade))

static func aplicar_ataque(estado_original: Dictionary, uid: String, peer_id: int, perfil_servidor: Dictionary, acao: String, agora_ms: int) -> Dictionary:
	if estado_original.is_empty() or str(estado_original.get("status", "")) != STATUS_EM_COMBATE:
		return {"ok": false, "erro": "A Serpente do Mundo não está em combate."}
	var estado := estado_original.duplicate(true)
	var participantes: Dictionary = estado.get("participantes", {})
	if not participantes.has(uid):
		return {"ok": false, "erro": "Você não está participando desta incursão."}
	var participante: Dictionary = participantes[uid]
	if int(participante.get("peerId", -1)) != peer_id or not bool(participante.get("ativo", false)):
		return {"ok": false, "erro": "Participante não autorizado."}
	var ultima_acao := int(participante.get("ultimaAcaoMs", -INTERVALO_ACAO_MS))
	if agora_ms - ultima_acao < INTERVALO_ACAO_MS:
		return {"ok": false, "erro": "Aguarde antes de atacar novamente."}
	var dano := calcular_dano_jogador(perfil_servidor, acao)
	if dano <= 0:
		return {"ok": false, "erro": "Ação inválida contra a Serpente do Mundo."}
	var vida_anterior := int(estado.get("vida", 0))
	var dano_aplicado := mini(vida_anterior, dano)
	estado["vida"] = maxi(0, vida_anterior - dano_aplicado)
	participante["danoTotal"] = int(participante.get("danoTotal", 0)) + dano_aplicado
	participante["ultimaAcaoMs"] = agora_ms
	participantes[uid] = participante
	estado["participantes"] = participantes
	if int(estado["vida"]) <= 0:
		estado["status"] = STATUS_DERROTADA
		estado["derrotadaUnix"] = int(Time.get_unix_time_from_system())
		estado["proximoRenascimentoUnix"] = int(estado["derrotadaUnix"]) + TEMPO_RENASCIMENTO_SEGUNDOS
		estado["totalDerrotas"] = int(estado.get("totalDerrotas", 0)) + 1
		estado["ultimoAtaque"] = "A Serpente do Mundo foi derrotada. Seu corpo permanece no mundo."
		estado["serpenteOriginalPreservada"] = true
	return {"ok": true, "estado": estado, "dano": dano_aplicado, "derrotada": str(estado.get("status", "")) == STATUS_DERROTADA}

static func marcar_desconectado(estado_original: Dictionary, uid: String, peer_id: int) -> Dictionary:
	if estado_original.is_empty():
		return estado_original
	var estado := estado_original.duplicate(true)
	var participantes: Dictionary = estado.get("participantes", {})
	if not participantes.has(uid):
		return estado
	var participante: Dictionary = participantes[uid]
	if int(participante.get("peerId", -1)) == peer_id:
		participante["ativo"] = false
		participantes[uid] = participante
		estado["participantes"] = participantes
	return estado

static func registrar_tentativa_filhote(estado_original: Dictionary, uid: String) -> Dictionary:
	if estado_original.is_empty() or str(estado_original.get("status", "")) != STATUS_DERROTADA:
		return {"ok": false, "erro": "A Serpente do Mundo precisa ser derrotada primeiro."}
	var participantes: Dictionary = estado_original.get("participantes", {})
	if not participantes.has(uid) or int(participantes[uid].get("danoTotal", 0)) <= 0:
		return {"ok": false, "erro": "Somente quem participou da batalha e causou dano pode tentar obter o filhote."}
	var estado := estado_original.duplicate(true)
	var tentativas: Dictionary = estado.get("tentativasDomesticacao", {})
	var usadas := int(tentativas.get(uid, 0))
	if usadas >= MAX_TENTATIVAS_FILHOTE:
		return {"ok": false, "erro": "Você já usou as três tentativas para este ciclo da Serpente do Mundo.", "restantes": 0}
	usadas += 1
	tentativas[uid] = usadas
	estado["tentativasDomesticacao"] = tentativas
	return {"ok": true, "estado": estado, "tentativa": usadas, "restantes": MAX_TENTATIVAS_FILHOTE - usadas}

static func verificar_renascimento(estado_original: Dictionary, agora_unix: int) -> Dictionary:
	if estado_original.is_empty() or str(estado_original.get("status", "")) != STATUS_DERROTADA:
		return estado_original
	var renascimento := int(estado_original.get("proximoRenascimentoUnix", 0))
	if renascimento <= 0 or agora_unix < renascimento:
		return estado_original
	var novo := criar_estado(int(estado_original.get("vidaMaxima", VIDA_TOTAL_PADRAO)))
	novo["ciclos"] = int(estado_original.get("ciclos", 1)) + 1
	novo["totalDerrotas"] = int(estado_original.get("totalDerrotas", 1))
	novo["ultimaDerrotaUnix"] = int(estado_original.get("derrotadaUnix", 0))
	novo["ultimoAtaque"] = "A Serpente do Mundo retornou. A cabeça voltou a ameaçar a arena."
	return novo

static func obter_estado_publico(estado: Dictionary) -> Dictionary:
	var agora := int(Time.get_unix_time_from_system())
	var renascimento := int(estado.get("proximoRenascimentoUnix", 0))
	return {
		"chefeId": str(estado.get("chefeId", ID_CHEFE)),
		"status": str(estado.get("status", STATUS_DISPONIVEL)),
		"vida": int(estado.get("vida", 0)),
		"vidaMaxima": int(estado.get("vidaMaxima", 0)),
		"participantes": int(estado.get("participantes", {}).size()),
		"serpenteOriginalPreservada": bool(estado.get("serpenteOriginalPreservada", true)),
		"ultimoAtaque": str(estado.get("ultimoAtaque", "")),
		"ciclos": int(estado.get("ciclos", 1)),
		"totalDerrotas": int(estado.get("totalDerrotas", 0)),
		"renascimentoRestante": maxi(0, renascimento - agora) if str(estado.get("status", "")) == STATUS_DERROTADA else 0,
		"renascimentoUnix": renascimento
	}
