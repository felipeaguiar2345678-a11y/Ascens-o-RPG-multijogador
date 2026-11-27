extends SceneTree

const Gerador = preload("res://scripts/gerador_equipamentos_criaturas.gd")
const Catalogo = preload("res://scripts/catalogo_equipamentos_gerados.gd")
const SistemaEquipamentos = preload("res://scripts/sistema_equipamentos.gd")

func _initialize() -> void:
	var dragao := {"id":"dragao_chama_azul","nome":"Dragão da Chama Azul","especieId":"dragao","elemento":"fogo","rank":"S"}
	var espada := Gerador.criar_projeto(dragao, 12, 445, "arma")
	if espada.is_empty():
		_falhar("O gerador não criou arma para criatura válida.")
		return
	if str(espada.get("origemCriaturaId", "")) != "dragao_chama_azul" or str(espada.get("elemento", "")) != "fogo":
		_falhar("O equipamento perdeu a identidade elemental/origem da criatura.")
		return
	if str(espada.get("efeitoEspecial", "")) != "brasas" or not str(espada.get("nome", "")).contains("Flamejante"):
		_falhar("O tema visual e o efeito não acompanharam a criatura.")
		return
	var catalogado := Catalogo.obter(str(espada.get("id", "")))
	if catalogado.is_empty() or str(catalogado.get("origemCriaturaId", "")) != "dragao_chama_azul":
		_falhar("O projeto não foi persistido no catálogo do servidor.")
		return
	var definicao_equipar := SistemaEquipamentos.obter(str(espada.get("id", "")))
	if definicao_equipar.is_empty() or int(definicao_equipar.get("dano", 0)) != int(espada.get("dano", -1)):
		_falhar("O sistema de equipamentos não reconheceu o item gerado.")
		return
	var repetido := Gerador.criar_projeto(dragao, 12, 445, "arma")
	if espada != repetido:
		_falhar("A mesma semente não reproduziu o mesmo projeto.")
		return
	var gelo := Gerador.criar_projeto({"id":"lobo_nevasca","nome":"Lobo da Nevasca","elemento":"gelo","rank":"C"}, 12, 445, "armadura")
	if str(gelo.get("materialOrigem", "")) != "cristal glacial" or str(gelo.get("slot", "")) != "torso":
		_falhar("A armadura não herdou material e forma corretos.")
		return
	if int(espada.get("dano", 0)) < 1 or int(espada.get("dano", 0)) > 250:
		_falhar("O dano gerado saiu dos limites de balanceamento.")
		return
	if not Gerador.criar_projeto(dragao, 12, 445, "forma_invalida").is_empty():
		_falhar("O gerador aceitou uma forma de equipamento inválida.")
		return
	print("TESTE DE EQUIPAMENTOS GERADOS POR CRIATURAS: origem, tema, cache determinístico e limites aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE EQUIPAMENTOS GERADOS: " + mensagem)
	quit(1)
