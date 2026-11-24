extends RefCounted
class_name SistemaMoedas

## Economia em cinco denominações. Cada nível vale 100 unidades do nível anterior.
const DENOMINACOES := ["bronze", "ferro", "ouro", "diamante", "jade"]
const LIMITE_SALDO := 2_000_000_000
const VALOR_EM_BRONZE := {
	"bronze": 1,
	"ferro": 100,
	"ouro": 10000,
	"diamante": 1000000,
	"jade": 100000000
}

static func criar_saldo_vazio() -> Dictionary:
	return {"bronze":0,"ferro":0,"ouro":0,"diamante":0,"jade":0}

static func normalizar(saldo_recebido) -> Dictionary:
	var saldo := criar_saldo_vazio()
	if not (saldo_recebido is Dictionary):
		return saldo
	for denominacao in DENOMINACOES:
		var valor = saldo_recebido.get(denominacao, 0)
		if valor is int or value_is_integer_number(valor):
			saldo[denominacao] = clampi(int(valor), 0, LIMITE_SALDO)
	return saldo

static func value_is_integer_number(valor) -> bool:
	return valor is float and is_finite(valor) and floor(valor) == valor

static func valor_total_em_bronze(saldo_recebido) -> int:
	var saldo := normalizar(saldo_recebido)
	var total: int = 0
	for denominacao in DENOMINACOES:
		total += int(saldo[denominacao]) * int(VALOR_EM_BRONZE[denominacao])
	return total

static func converter(saldo_recebido, denominacao_origem: String, quantidade: int) -> Dictionary:
	var indice := DENOMINACOES.find(denominacao_origem)
	if indice < 0 or indice >= DENOMINACOES.size() - 1:
		return {"ok":false,"erro":"Essa moeda não possui uma denominação superior."}
	if quantidade < 100 or quantidade % 100 != 0:
		return {"ok":false,"erro":"A conversão exige múltiplos de 100 moedas."}
	var saldo := normalizar(saldo_recebido)
	if int(saldo[denominacao_origem]) < quantidade:
		return {"ok":false,"erro":"Saldo insuficiente para essa conversão."}
	var denominacao_destino: String = DENOMINACOES[indice + 1]
	var recebidas := quantidade / 100
	if int(saldo[denominacao_destino]) + recebidas > LIMITE_SALDO:
		return {"ok":false,"erro":"O limite da moeda superior seria ultrapassado."}
	saldo[denominacao_origem] = int(saldo[denominacao_origem]) - quantidade
	saldo[denominacao_destino] = int(saldo[denominacao_destino]) + recebidas
	return {
		"ok":true,
		"moedas":saldo,
		"origem":denominacao_origem,
		"quantidadeConvertida":quantidade,
		"destino":denominacao_destino,
		"quantidadeRecebida":recebidas
	}
