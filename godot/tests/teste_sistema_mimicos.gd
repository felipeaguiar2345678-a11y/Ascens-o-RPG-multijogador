extends SceneTree

const Sistema = preload("res://scripts/sistema_mimicos.gd")

func _initialize() -> void:
	_testar_aparicao()
	_testar_comportamento_e_combate()
	_testar_piedade_independente()
	_testar_uma_arma_e_tripla_excluida()
	print("TESTE DOS MÍMICOS: aparição, disfarce, combate, drop único e piedade independente aprovados.")
	quit(0)

func _testar_aparicao() -> void:
	var contagem := {"comum": 0, "raro": 0, "lendario": 0, "mitico": 0, "nenhum": 0}
	for semente in range(1, 20001):
		var resultado := Sistema.sortear_aparicao(semente)
		var tipo := str(resultado.get("tipo", ""))
		if bool(resultado.get("aparece", false)):
			contagem[tipo] += 1
		else:
			contagem["nenhum"] += 1
	for tipo in ["comum", "raro", "lendario", "mitico", "nenhum"]:
		var esperado := float(Sistema.CHANCES_APARICAO.get(tipo, 0.90)) * 20000.0
		if absf(float(contagem[tipo]) - esperado) > 260.0:
			_falhar("A frequência simulada de aparição ficou fora da tolerância: " + tipo)
			return
	var repetido := Sistema.sortear_aparicao(1234)
	if repetido != Sistema.sortear_aparicao(1234):
		_falhar("A mesma semente não reproduziu o mesmo resultado de aparição.")

func _testar_comportamento_e_combate() -> void:
	var mimico := Sistema.criar_mimico("mitico", "encontro_teste", "floresta_arcana", 55)
	if mimico.is_empty() or not bool(mimico.get("servidorAutoritativo", false)):
		_falhar("Não criou um mímico mítico autoritativo.")
		return
	var disfarce := Sistema.decidir_comportamento(mimico, {"jogadorInteragiu": false, "jogadorDetectouSinais": false}, 12)
	if str(disfarce.get("estado", "")) != "disfarcado":
		_falhar("O mímico deveria permanecer disfarçado antes da interação.")
		return
	var pista := Sistema.decidir_comportamento(mimico, {"jogadorInteragiu": false, "jogadorDetectouSinais": true}, 12)
	if str(pista.get("estado", "")) != "alerta":
		_falhar("A percepção deveria colocar o mímico em alerta sem iniciar combate.")
		return
	var revelacao := Sistema.decidir_comportamento(mimico, {"jogadorInteragiu": true, "distanciaJogador": 30.0}, 12)
	if not bool(revelacao.get("iniciaCombate", false)):
		_falhar("A interação próxima não iniciou o encontro.")
		return
	var inimigo := Sistema.preparar_inimigo_combate(mimico)
	if inimigo.is_empty() or inimigo.get("padroesAtaque", []).size() < 3 or int(inimigo.get("fasesCombate", 0)) != 3:
		_falhar("O mímico mítico não recebeu seus padrões e fases de chefe.")
		return
	var comum := Sistema.criar_mimico("comum", "comum_teste", "bosque", 1)
	if int(comum.get("fases", 0)) != 1 or bool(comum.get("invoca", true)):
		_falhar("O mímico comum recebeu características de chefe indevidas.")

func _catalogo() -> Array:
	return [
		{"id":"arma_comum_teste","nome":"Lâmina Simples","raridade":"comum"},
		{"id":"arma_rara_teste","nome":"Lâmina Rara","raridade":"rara"},
		{"id":"arma_lendaria_teste","nome":"Lâmina Lendária","raridade":"lendaria"},
		{"id":"arma_mitica_teste","nome":"Lâmina Mítica","raridade":"mitica"},
		{"id":"arma_suprema_teste","nome":"Lâmina Suprema","raridade":"suprema"},
		{"id":"tripla_katana","nome":"Tripla Katana","raridade":"suprema"}
	]

func _testar_piedade_independente() -> void:
	var piedade := Sistema.criar_piedade_vazia()
	piedade["contadores"] = {"lendaria": 49, "mitica": 99, "suprema": 199}
	var primeira := Sistema.resolver_recompensa("mitico", _catalogo(), piedade, "encontro_200", 987)
	if not bool(primeira.get("ok", false)) or str(primeira.get("raridade", "")) != "suprema" or not bool(primeira.get("garantida", false)):
		_falhar("O marco de 200 deve priorizar uma Suprema garantida.")
		return
	var estado: Dictionary = primeira.get("piedade", {})
	var contadores: Dictionary = estado.get("contadores", {})
	if int(contadores.get("suprema", -1)) != 0 or int(contadores.get("mitica", -1)) != 100 or int(contadores.get("lendaria", -1)) != 50:
		_falhar("A Suprema garantida deve zerar somente seu próprio contador.")
		return
	var segunda := Sistema.resolver_recompensa("comum", _catalogo(), estado, "encontro_201", 987)
	if str(segunda.get("raridade", "")) != "mitica" or not bool(segunda.get("garantida", false)):
		_falhar("O próximo marco pendente deve garantir a Mítica.")
		return
	var terceira := Sistema.resolver_recompensa("raro", _catalogo(), segunda.get("piedade", {}), "encontro_202", 987)
	if str(terceira.get("raridade", "")) != "lendaria" or not bool(terceira.get("garantida", false)):
		_falhar("O marco lendário deve continuar independente.")
		return
	var duplicada := Sistema.resolver_recompensa("raro", _catalogo(), terceira.get("piedade", {}), "encontro_202", 987)
	if not bool(duplicada.get("duplicado", false)):
		_falhar("Um mesmo encontro não pode conceder recompensa duas vezes.")

func _testar_uma_arma_e_tripla_excluida() -> void:
	var piedade := Sistema.criar_piedade_vazia()
	var resultado := Sistema.resolver_recompensa("mitico", _catalogo(), piedade, "drop_unico", 444)
	if not bool(resultado.get("ok", false)) or int(resultado.get("quantidadeArmas", 0)) != 1:
		_falhar("Cada mímico deve conceder no máximo uma arma.")
		return
	if str(resultado.get("arma", {}).get("id", "")) == "tripla_katana":
		_falhar("A Tripla Katana não pode ser obtida por drop.")

func _falhar(mensagem: String) -> void:
	push_error("TESTE DOS MÍMICOS: " + mensagem)
	quit(1)
