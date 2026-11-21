extends RefCounted
## Decide o comportamento de uma criatura errante usando apenas contexto confiável do servidor.
## Não inicia combate nem inventa presas, habitats ou invasores: recebe esses sinais de sistemas do mundo.
const VAGANDO := "vagando"
const FUGINDO := "fugindo"
const CACANDO := "cacando"
const BUSCANDO_HABITAT := "buscando_habitat"
const DEFENDENDO_TERRITORIO := "defendendo_territorio"

static func decidir(criatura: Dictionary, contexto: Dictionary) -> Dictionary:
	var mutacoes := _atributos_mutacoes(criatura.get("evolucao", {}).get("mutacoes", []))
	var distancia := maxf(0.0, float(contexto.get("distanciaAmeaca", INF)))
	var forca_criatura := maxf(0.0, float(contexto.get("forcaCriatura", 0.0)))
	var forca_ameaca := maxf(0.0, float(contexto.get("forcaAmeaca", 0.0)))
	var ameaca_perto := bool(contexto.get("ameacaPresente", false)) and distancia <= 180.0
	var agressividade := 1.0 + float(mutacoes.get("ataque", 0.0)) * 0.08 + float(mutacoes.get("agilidade", 0.0)) * 0.04
	var resistencia := 1.0 + float(mutacoes.get("defesa", 0.0)) * 0.08 + float(mutacoes.get("vidaMaxima", 0.0)) * 0.04
	if ameaca_perto and forca_ameaca > forca_criatura * resistencia:
		return _resultado(FUGINDO, "Uma ameaça próxima é mais forte.", 1.0 + float(mutacoes.get("agilidade", 0.0)) * 0.08)
	if not bool(contexto.get("habitatAdequado", true)):
		return _resultado(BUSCANDO_HABITAT, "O ambiente atual não é adequado.", 1.0)
	if bool(contexto.get("invasorTerritorio", false)) and forca_criatura * agressividade >= forca_ameaca:
		return _resultado(DEFENDENDO_TERRITORIO, "Um invasor entrou no território.", 1.0)
	if bool(contexto.get("presaPresente", false)) and forca_criatura * agressividade > forca_ameaca:
		return _resultado(CACANDO, "Uma presa foi detectada.", 1.0 + float(mutacoes.get("agilidade", 0.0)) * 0.05)
	if ameaca_perto:
		return _resultado(FUGINDO, "A criatura evita uma presença próxima.", 1.0)
	return _resultado(VAGANDO, "A criatura explora a região.", 1.0)

static func _atributos_mutacoes(lista: Array) -> Dictionary:
	var resultado := {"ataque":0.0,"defesa":0.0,"agilidade":0.0,"vidaMaxima":0.0,"poderMagico":0.0,"manaMaxima":0.0}
	for mutacao in lista:
		if not (mutacao is Dictionary):
			continue
		var atributo := str(mutacao.get("atributo", ""))
		if resultado.has(atributo):
			resultado[atributo] = float(resultado[atributo]) + 1.0
	return resultado

static func _resultado(estado: String, motivo: String, multiplicador_velocidade: float) -> Dictionary:
	return {"estado":estado,"motivo":motivo,"multiplicadorVelocidade":clampf(multiplicador_velocidade, 0.75, 1.25)}
