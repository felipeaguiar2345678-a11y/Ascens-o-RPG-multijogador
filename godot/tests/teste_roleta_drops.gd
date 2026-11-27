extends SceneTree

const SistemaDrops = preload("res://scripts/sistema_drops.gd")

func _initialize() -> void:
	var criatura := {
		"id": "criatura_teste_roleta",
		"tabelaDrops": [
			{"itemId":"gema_garantida","nome":"Gema garantida","categoria":"material","raridade":"comum","chance":1.0,"quantidadeMinima":2,"quantidadeMaxima":2},
			{"itemId":"ovo_impossivel","nome":"Ovo impossível","categoria":"ovo","raridade":"comum","chance":0.0,"quantidadeMinima":1,"quantidadeMaxima":1}
		]
	}
	if not SistemaDrops.validar_tabela(criatura["tabelaDrops"]):
		_falhar("A tabela de teste deveria ser válida.")
		return
	var resultados := SistemaDrops.resolver_tabela(criatura["tabelaDrops"], "atividade_teste", {"semente":12345,"periodo":"dia"})
	if resultados.size() != 2:
		_falhar("A roleta não registrou todas as tentativas elegíveis.")
		return
	var sucesso: Dictionary = resultados[0]
	var falha: Dictionary = resultados[1]
	if not bool(sucesso.get("obtido", false)) or str(sucesso.get("resultadoVisual", "")) != "sucesso":
		_falhar("Uma recompensa com chance de 100% não foi concedida.")
		return
	if int(sucesso.get("quantidade", 0)) != 2:
		_falhar("A quantidade garantida não foi preservada.")
		return
	if bool(falha.get("obtido", true)) or str(falha.get("resultadoVisual", "")) != "falha":
		_falhar("Uma recompensa com chance de 0% foi concedida.")
		return
	if int(falha.get("quantidade", -1)) != 0:
		_falhar("Uma tentativa fracassada recebeu quantidade de item.")
		return
	var apenas_obtidos := SistemaDrops.gerar_drops(criatura, {"semente":12345,"periodo":"dia","classeId":"invocador"})
	var recompensas_atividade := SistemaDrops.resolver_tabela(criatura["tabelaDrops"], "baú_teste", {"semente":12345,"periodo":"dia"})
	if recompensas_atividade.size() != 2 or str(recompensas_atividade[0].get("origemCriaturaId", "")) != "baú_teste":
		_falhar("A tabela universal não preservou a origem da atividade.")
		return
	if apenas_obtidos.size() != 1 or str(apenas_obtidos[0].get("itemId", "")) != "gema_garantida":
		_falhar("A função de compatibilidade não filtrou somente recompensas obtidas.")
		return
	var criatura_ovo := {"id":"lobo_arcano_gerado","nome":"Lobo Arcano","rank":"D","raridade":"raro","vidaMaxima":400,"ataque":80,"defesa":40,"agilidade":60,"poderMagico":20,"especieId":"lobo_arcano","imagemId":"lobo_arcano_visual","habilidades":[{"id":"mordida_arcana"}]}
	var entrada_ovo := SistemaDrops.criar_entrada_ovo(criatura_ovo)
	if entrada_ovo.is_empty() or str(entrada_ovo.get("categoria", "")) != "ovo":
		_falhar("Criatura válida não gerou entrada de ovo.")
		return
	if not is_equal_approx(float(entrada_ovo.get("chance", 0.0)), 0.04):
		_falhar("Ovos de criaturas rank D devem ter chance-base de 4%.")
		return
	var modelo: Dictionary = entrada_ovo.get("modeloCompanheiro", {})
	if str(modelo.get("criaturaOrigemId", "")) != "lobo_arcano_gerado" or str(modelo.get("imagemId", "")) != "lobo_arcano_visual":
		_falhar("O ovo não preservou a origem e a identidade visual da criatura.")
		return
	var tabela_ovo := SistemaDrops.resolver_tentativas(criatura_ovo, {"semente":9876,"periodo":"dia","classeId":"guerreiro"})
	var tabela_invocador := SistemaDrops.resolver_tentativas(criatura_ovo, {"semente":9876,"periodo":"dia","classeId":"invocador"})
	if tabela_ovo.size() != 1 or str(tabela_ovo[0].get("categoria", "")) != "ovo":
		_falhar("Classes não Invocador devem receber tentativa de ovo.")
		return
	if not tabela_invocador.is_empty():
		_falhar("Invocador não deve receber tentativa de ovo.")
		return
	print("TESTE DA ROLETA DE DROPS: sucessos, falhas, probabilidades extremas e filtro de inventário aprovados.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DA ROLETA DE DROPS: " + mensagem)
	quit(1)
