extends SceneTree

const Repositorio = preload("res://scripts/repositorio_personagem_servidor.gd")
const CatalogoCriacaoPersonagem = preload("res://scripts/catalogo_criacao_personagem.gd")
const SistemaDrops = preload("res://scripts/sistema_drops.gd")
const SistemaEquipamentos = preload("res://scripts/sistema_equipamentos.gd")

func _initialize() -> void:
	call_deferred("_executar")

func _executar() -> void:
	var repositorio = Repositorio.new()
	var uid := "ci_persistencia_%s" % str(Time.get_ticks_usec())
	var perfil: Dictionary = repositorio.carregar_ou_criar(uid)
	if perfil.is_empty():
		_falhar("Não criou o perfil inicial.")
		return
	var revisao_inicial := int(perfil.get("revisaoServidor", 0))
	var snapshot_antigo := perfil.duplicate(true)
	perfil["x"] = 1200.0
	if not repositorio.salvar(uid, perfil):
		_falhar("Não salvou a primeira atualização.")
		return
	if repositorio.salvar(uid, snapshot_antigo):
		_falhar("Aceitou snapshot com revisão antiga.")
		return
	perfil["x"] = 1300.0
	if not repositorio.salvar(uid, perfil):
		_falhar("Não salvou a segunda atualização.")
		return
	var caminho := ProjectSettings.globalize_path("user://dados/personagens_online.json")
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		_falhar("Não conseguiu preparar o teste de recuperação.")
		return
	arquivo.store_string("arquivo propositalmente corrompido")
	arquivo.close()
	var recuperado: Dictionary = repositorio.carregar_ou_criar(uid)
	if recuperado.is_empty() or not is_equal_approx(float(recuperado.get("x", -1.0)), 1200.0):
		_falhar("Não recuperou a última versão válida do backup.")
		return
	if int(recuperado.get("revisaoServidor", 0)) != revisao_inicial + 1:
		_falhar("A revisão recuperada não corresponde ao backup esperado.")
		return
	var uid_novo := "ci_criacao_%s" % str(Time.get_ticks_usec())
	var perfil_novo: Dictionary = repositorio.carregar_ou_criar(uid_novo)
	if perfil_novo.is_empty() or bool(perfil_novo.get("personagemCriado", true)):
		_falhar("Perfil novo não aguardou a criação do personagem.")
		return
	var criado: Dictionary = repositorio.criar_personagem(uid_novo, "Teste Heroi", "masculino", "masc_cabelo_curto", "humano", "guerreiro")
	if criado.is_empty() or not bool(criado.get("personagemCriado", false)) or str(criado.get("nome", "")) != "Teste Heroi":
		_falhar("Não criou o personagem com os dados permitidos.")
		return
	if not repositorio.criar_personagem(uid_novo, "Outro Nome", "feminino", "fem_cabelo_longo", "elfo", "mago").is_empty():
		_falhar("Permitiu criar um segundo personagem na mesma conta.")
		return
	if not repositorio.criar_personagem("uid_invalido", "X", "sexo_invalido", "aparencia_invalida", "raca_invalida", "classe_invalida").is_empty():
		_falhar("Aceitou dados inválidos de criação.")
		return
	if int(criado.get("forca", 0)) <= 5 or str(criado.get("classeId","")) != "guerreiro" or not criado.get("afinidadesFisicas", []).has("espada"):
		_falhar("Não aplicou os modificadores da raça/classe e afinidades.")
		return
	var anao := CatalogoCriacaoPersonagem.montar_perfil("masculino", "masc_cabelo_curto", "anao", "guerreiro")
	var draconiano := CatalogoCriacaoPersonagem.montar_perfil("feminino", "fem_cabelo_longo", "draconiano", "mago")
	var humano := CatalogoCriacaoPersonagem.montar_perfil("masculino", "masc_cabelo_curto", "humano", "guerreiro")
	if float(anao["anatomiaRacial"]["altura"]) >= 1.0 or anao["anatomiaRacial"]["porte"] != "baixo_robusto":
		_falhar("Anão precisa ter estatura baixa e corpo robusto.")
		return
	if draconiano["anatomiaRacial"]["chifres"] != "draconicos" or draconiano["anatomiaRacial"]["asas"] != "draconicas_recolhidas":
		_falhar("Draconiano precisa registrar chifres e asas.")
		return
	if humano["anatomiaRacial"]["orelhas"] != "humanas" or float(humano["anatomiaRacial"]["altura"]) != 1.0:
		_falhar("Humano precisa manter anatomia comum.")
		return
	var perfil_mago := CatalogoCriacaoPersonagem.montar_perfil("feminino", "fem_cabelo_longo", "elfo", "mago")
	if perfil_mago.is_empty() or int(perfil_mago["inteligencia"]) <= int(perfil_mago["forca"]) or not perfil_mago["afinidadesMagicas"].has("gelo") or perfil_mago["anatomiaRacial"]["orelhas"] != "elficas_pontudas":
		_falhar("Não calculou as afinidades e atributos mágicos.")
		return
	# Valida que os traços raciais chegam à camada visual procedural.
	var avatar_script = load("res://scripts/avatar_personagem.gd")
	var avatar_an = avatar_script.new()
	avatar_an.configurar(anao)
	if avatar_an.get_child_count() < 5 or not is_equal_approx(float(avatar_an.scale.y), 0.72):
		_falhar("Avatar anão não aplicou estatura e silhueta racial.")
		return
	var avatar_dr = avatar_script.new()
	avatar_dr.configurar(draconiano)
	if avatar_dr.get_child_count() <= avatar_an.get_child_count() or not is_equal_approx(float(avatar_dr.scale.y), 1.08):
		_falhar("Avatar draconiano não desenhou seus traços adicionais.")
		return
	var avatar_el = avatar_script.new()
	avatar_el.configurar(perfil_mago)
	if avatar_el.get_child_count() < 8 or not is_equal_approx(float(avatar_el.scale.y), 1.02):
		_falhar("Avatar élfico não aplicou as orelhas e proporções raciais.")
		return
	# Camadas visuais de equipamento são desenhadas sem remover a anatomia draconiana.
	var draconiano_equipado := draconiano.duplicate(true)
	draconiano_equipado["equipamentos"] = {
		"torso":"peitoral_placas", "cabeca":"elmo_placas",
		"pernas":"grevas_aco", "mao_principal":"espada_ferro",
		"mao_secundaria":"escudo_aco", "colar":"colar_mana"
	}
	var avatar_dr_equipado = avatar_script.new()
	avatar_dr_equipado.configurar(draconiano_equipado)
	if avatar_dr_equipado.get_child_count() <= avatar_dr.get_child_count():
		_falhar("Avatar não desenhou as peças de equipamento recebidas no perfil.")
		return
	if not is_equal_approx(float(avatar_dr_equipado.scale.y), 1.08):
		_falhar("Equipamentos alteraram indevidamente a altura racial draconiana.")
		return

	var criatura_teste := {
		"id":"criatura_teste",
		"tabelaDrops":[
			{"itemId":"escama_teste","nome":"Escama de teste","categoria":"material","raridade":"comum","chance":1.0,"quantidadeMinima":1,"quantidadeMaxima":2,"parteCorporal":"escamas"},
			{"itemId":"nucleo_teste","nome":"Núcleo de teste","categoria":"nucleo_magico","raridade":"comum","chance":1.0}
		]
	}
	if not SistemaDrops.validar_tabela(criatura_teste["tabelaDrops"]):
		_falhar("Rejeitou uma tabela de drops válida.")
		return
	var drops_intactos: Array = SistemaDrops.gerar_drops(criatura_teste, {"semente":123,"partesIntactas":["escamas"]})
	if drops_intactos.size() != 2:
		_falhar("Não gerou os drops garantidos da criatura.")
		return
	var drops_danificados: Array = SistemaDrops.gerar_drops(criatura_teste, {"semente":123,"partesDanificadas":["escamas"]})
	for drop in drops_danificados:
		if str(drop.get("itemId","")) == "escama_teste":
			_falhar("Gerou material de uma parte corporal destruída.")
			return
	if not repositorio.conceder_drops(uid_novo, drops_intactos):
		_falhar("Não persistiu os itens recebidos como recompensa.")
		return
	var perfil_com_drops: Dictionary = repositorio.carregar_ou_criar(uid_novo)
	var inventario: Array = perfil_com_drops.get("inventario", [])
	if inventario.size() != 2:
		_falhar("O inventário não guardou os dois itens recebidos.")
		return
	if not repositorio.conceder_drops(uid_novo, [drops_intactos[0]]):
		_falhar("Não acumulou uma nova pilha do mesmo item.")
		return
	perfil_com_drops = repositorio.carregar_ou_criar(uid_novo)
	inventario = perfil_com_drops.get("inventario", [])
	if inventario.size() != 2:
		_falhar("Criou uma pilha duplicada em vez de acumular quantidade.")
		return
	# Equipamentos: inventário, mãos, escudos, armaduras e restrição de classe.
	var drops_equipamento := [
		{"itemId":"espada_ferro","nome":"Espada de Ferro","categoria":"arma","raridade":"comum","quantidade":1},
		{"itemId":"escudo_aco","nome":"Escudo de Aço","categoria":"escudo","raridade":"comum","quantidade":1},
		{"itemId":"machado_batalha","nome":"Machado de Batalha","categoria":"arma","raridade":"raro","quantidade":1},
		{"itemId":"peitoral_placas","nome":"Armadura de Placas","categoria":"armadura","raridade":"raro","quantidade":1},
		{"itemId":"peitoral_couro","nome":"Peitoral de Couro","categoria":"armadura","raridade":"comum","quantidade":1},
		{"itemId":"anel_poder","nome":"Anel do Poder","categoria":"acessorio","raridade":"epico","quantidade":1}
	]
	if not repositorio.conceder_drops(uid_novo, drops_equipamento):
		_falhar("Não adicionou equipamentos de teste ao inventário.")
		return
	var espada_equipada := repositorio.equipar_item(uid_novo, "espada_ferro")
	if not bool(espada_equipada.get("ok", false)):
		_falhar("Não equipou uma espada de uma mão.")
		return
	var escudo_equipado := repositorio.equipar_item(uid_novo, "escudo_aco")
	if not bool(escudo_equipado.get("ok", false)) or str(escudo_equipado["equipamentos"].get("mao_secundaria", "")) != "escudo_aco":
		_falhar("Não permitiu espada de uma mão com escudo.")
		return
	var machado_bloqueado := repositorio.equipar_item(uid_novo, "machado_batalha")
	if bool(machado_bloqueado.get("ok", false)):
		_falhar("Permitiu arma de duas mãos enquanto o escudo estava equipado.")
		return
	if not repositorio.desequipar_slot(uid_novo, "mao_secundaria").get("ok", false):
		_falhar("Não conseguiu remover o escudo.")
		return
	var machado_equipado := repositorio.equipar_item(uid_novo, "machado_batalha")
	if not bool(machado_equipado.get("ok", false)) or not str(machado_equipado["equipamentos"].get("mao_secundaria", "")).is_empty():
		_falhar("Não equipou arma pesada ocupando as duas mãos.")
		return
	if not repositorio.desequipar_slot(uid_novo, "mao_principal").get("ok", false):
		_falhar("Não conseguiu remover a arma pesada.")
		return
	if not repositorio.equipar_item(uid_novo, "peitoral_placas").get("ok", false):
		_falhar("Não equipou armadura pesada.")
		return
	var peso_pesado := SistemaEquipamentos.calcular_penalidades({"torso":"peitoral_placas"}, {"forca":5,"agilidade":10})
	var peso_leve := SistemaEquipamentos.calcular_penalidades({"torso":"peitoral_couro"}, {"forca":5,"agilidade":10})
	if int(peso_pesado["penalidade_agilidade"]) <= int(peso_leve["penalidade_agilidade"]):
		_falhar("Armadura pesada não aplicou penalidade maior que a leve.")
		return
	if not repositorio.equipar_item(uid_novo, "anel_poder").get("ok", false):
		_falhar("Não equipou o anel no espaço único de anel.")
		return
	var uid_mago := "ci_mago_%s" % str(Time.get_ticks_usec())
	if repositorio.criar_personagem(uid_mago, "Mago Teste", "feminino", "fem_cabelo_longo", "elfo", "mago").is_empty():
		_falhar("Não criou personagem mágico para teste de escudo.")
		return
	if not repositorio.conceder_drops(uid_mago, [{"itemId":"escudo_aco","nome":"Escudo de Aço","categoria":"escudo","raridade":"comum","quantidade":1}]):
		_falhar("Não adicionou escudo ao inventário do mago.")
		return
	if repositorio.equipar_item(uid_mago, "escudo_aco").get("ok", false):
		_falhar("Permitiu escudo para classe mágica sem afinidade corpo a corpo.")
		return
	if drops_intactos[0].get("origemCriaturaId","") != "criatura_teste":
		_falhar("Não registrou a origem do drop.")
		return
	print("TESTE DE PERSISTÊNCIA: aprovado (criação, sexo, aparência, raças, classes, atributos, afinidades, revisão e backup).")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE PERSISTÊNCIA: " + mensagem)
	quit(1)
