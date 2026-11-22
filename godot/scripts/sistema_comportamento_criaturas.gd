extends RefCounted
## Decide o comportamento de uma criatura errante usando apenas contexto confiável do servidor.
## Não inicia combate nem inventa presas, habitats ou invasores: recebe esses sinais de sistemas do mundo.
const VAGANDO := "vagando"
const FUGINDO := "fugindo"
const CACANDO := "cacando"
const BUSCANDO_HABITAT := "buscando_habitat"
const DEFENDENDO_TERRITORIO := "defendendo_territorio"
const PERSEGUINDO_INVASOR := "perseguindo_invasor"

static func decidir(criatura: Dictionary, contexto: Dictionary) -> Dictionary:
	var mutacoes := _atributos_mutacoes(criatura.get("evolucao", {}).get("mutacoes", []))
	var distancia := maxf(0.0, float(contexto.get("distanciaAmeaca", INF)))
	var forca_criatura := maxf(0.0, float(contexto.get("forcaCriatura", 0.0)))
	var forca_ameaca := maxf(0.0, float(contexto.get("forcaAmeaca", 0.0)))
	var ameaca_perto := bool(contexto.get("ameacaPresente", false)) and distancia <= 180.0
	var moral := clampf(float(contexto.get("moralMultiplicador", criatura.get("moralMultiplicador", 1.0))), 0.5, 2.0)
	var agressividade := 1.0 + float(mutacoes.get("ataque", 0.0)) * 0.08 + float(mutacoes.get("agilidade", 0.0)) * 0.04
	var resistencia := 1.0 + float(mutacoes.get("defesa", 0.0)) * 0.08 + float(mutacoes.get("vidaMaxima", 0.0)) * 0.04
	if ameaca_perto and forca_ameaca > forca_criatura * resistencia * (0.85 + moral * 0.15):
		return _resultado(FUGINDO, "Uma ameaça próxima é mais forte.", 1.0 + float(mutacoes.get("agilidade", 0.0)) * 0.08)
	if not bool(contexto.get("habitatAdequado", true)):
		return _resultado(BUSCANDO_HABITAT, "O ambiente atual não é adequado.", 1.0)
	if bool(contexto.get("invasorTerritorio", false)) and forca_criatura * agressividade * moral >= forca_ameaca:
		return _resultado(DEFENDENDO_TERRITORIO, "Um invasor entrou no território; a moral sustenta a defesa.", 1.0 + (moral - 1.0) * 0.12)
	if bool(contexto.get("invasorTerritorio", false)) and moral >= 1.25 and forca_criatura * agressividade * moral >= forca_ameaca * 0.8:
		return _resultado(PERSEGUINDO_INVASOR, "A moral elevada encoraja a perseguição do invasor.", 1.0 + (moral - 1.0) * 0.15)
	if bool(contexto.get("presaPresente", false)) and forca_criatura * agressividade * (0.9 + moral * 0.1) > forca_ameaca:
		return _resultado(CACANDO, "Uma presa foi detectada.", 1.0 + float(mutacoes.get("agilidade", 0.0)) * 0.05)
	if ameaca_perto and forca_criatura >= forca_ameaca * 1.15:
		return _resultado(CACANDO, "A criatura identificou uma presa mais fraca.", 1.0 + float(mutacoes.get("agilidade", 0.0)) * 0.05)
	if ameaca_perto:
		return _resultado(FUGINDO, "A criatura evita uma presença próxima.", 1.0)
	return _resultado(VAGANDO, "A criatura explora a região.", 1.0)

## Decide a reação coletiva após avaliar a força relativa e a moral do grupo.
## coragem_variavel deve ser gerada pelo servidor com RNG determinístico.
static func grupo_deve_continuar_confronto_razao(razao_forca: float, moral_multiplicador: float, coragem_variavel: float) -> bool:
	var moral := clampf(moral_multiplicador, 0.5, 2.0)
	var coragem := clampf(coragem_variavel, 0.0, 0.20)
	var limiar := clampf(0.72 - (moral - 1.0) * 0.20, 0.45, 0.85)
	return razao_forca + coragem >= limiar

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
