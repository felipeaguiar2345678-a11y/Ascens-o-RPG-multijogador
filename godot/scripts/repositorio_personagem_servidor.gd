extends RefCounted
## Armazenamento local do processo dedicado. Nunca é carregado pelo cliente.
## Adequado para desenvolvimento em um único servidor com disco persistente.

const CAMINHO := "user://dados/personagens_online.json"
const CAMINHO_BACKUP := "user://dados/personagens_online.json.bak"
const LIMITE_ARQUIVO := 16 * 1024 * 1024
const CATALOGO = preload("res://scripts/catalogo_criacao_personagem.gd")
const SistemaDrops = preload("res://scripts/sistema_drops.gd")
const SistemaEquipamentos = preload("res://scripts/sistema_equipamentos.gd")

func carregar_ou_criar(uid: String) -> Dictionary:
	if not _uid_valido(uid):
		return {}
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(CAMINHO):
		push_error("Banco local de personagens inválido; entrada bloqueada para evitar sobrescrita.")
		return {}
	var registros: Dictionary = banco.get("personagens", {})
	if registros.has(uid):
		var existente = registros[uid]
		if not (existente is Dictionary) or str(existente.get("uid", "")) != uid:
			return {}
		return existente.duplicate(true)

	var novo := {
		"uid": uid,
		"personagemId": uid,
		"nome": "",
		"personagemCriado": false,
		"nivel": 1,
		"experiencia": 0,
		"vida": 100,
		"vidaMaxima": 100,
		"mana": 50,
		"manaMaxima": 50,
		"forca": 5,
		"inteligencia": 5,
		"agilidade": 5,
		"vitalidade": 5,
		"espirito": 5,
		"pontoMundoId": "clareira_inicial",
		"x": 1190.0,
		"y": 1120.0,
		"aparenciaId": "",
		"inventario": [],
		"equipamentos": {"mao_principal":"","mao_secundaria":"","cabeca":"","torso":"","pernas":"","maos":"","pes":"","costas":"","anel":"","colar":"","bracelete":"","cinto":""},
		"sexo": "", "racaId": "", "classeId": "", "afinidadesFisicas": [], "afinidadesMagicas": [], "anatomiaRacial": {},
		"revisaoServidor": 1
	}
	registros[uid] = novo
	banco["personagens"] = registros
	if not _gravar_banco(banco):
		return {}
	return novo.duplicate(true)

func criar_personagem(uid: String, nome: String, sexo: String, aparencia_id: String, raca_id: String, classe_id: String) -> Dictionary:
	var nome_limpo := nome.strip_edges()
	if not _uid_valido(uid) or nome_limpo.length() < 3 or nome_limpo.length() > 20:
		return {}
	var escolhas := CATALOGO.montar_perfil(sexo, aparencia_id, raca_id, classe_id)
	if escolhas.is_empty():
		return {}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or bool(perfil.get("personagemCriado", false)):
		return {}
	perfil["nome"] = nome_limpo
	perfil["personagemCriado"] = true
	for chave in escolhas:
		perfil[chave] = escolhas[chave]
	if not salvar(uid, perfil):
		return {}
	return perfil.duplicate(true)
func salvar(uid: String, snapshot: Dictionary) -> bool:
	if not _uid_valido(uid) or str(snapshot.get("uid", "")) != uid:
		return false
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(CAMINHO):
		return false
	var registros: Dictionary = banco.get("personagens", {})
	var atual: Dictionary = registros.get(uid, {})
	if atual.is_empty():
		return false

	# Impede que um snapshot antigo sobrescreva uma versão mais nova.
	var revisao_atual := int(atual.get("revisaoServidor", 0))
	if int(snapshot.get("revisaoServidor", -1)) != revisao_atual:
		push_warning("Gravação recusada: revisão de personagem desatualizada.")
		return false
	# Somente campos conhecidos são persistidos; a revisão é controlada aqui.
	var revisao := revisao_atual + 1
	var salvo := atual.duplicate(true)
	for chave in ["nome", "personagemCriado", "sexo", "racaId", "racaNome", "classeId", "classeNome", "descricaoRaca", "descricaoClasse", "afinidadesFisicas", "afinidadesMagicas", "anatomiaRacial", "nivel", "experiencia", "vida", "vidaMaxima", "mana", "manaMaxima", "forca", "inteligencia", "agilidade", "vitalidade", "espirito", "pontoMundoId", "x", "y", "aparenciaId", "inventario", "equipamentos"]:
		if snapshot.has(chave):
			salvo[chave] = snapshot[chave]
	salvo["uid"] = uid
	salvo["revisaoServidor"] = revisao
	if not _snapshot_valido(salvo):
		return false
	registros[uid] = salvo
	banco["personagens"] = registros
	if not _gravar_banco(banco):
		return false
	snapshot["revisaoServidor"] = revisao
	return true


func conceder_drops(uid: String, drops: Array) -> bool:
	if not _uid_valido(uid) or drops.is_empty() or drops.size() > 100:
		return false
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return false
	var inventario: Array = perfil.get("inventario", [])
	for drop in drops:
		if not (drop is Dictionary):
			return false
		var item_id := str(drop.get("itemId", "")).strip_edges()
		var quantidade := int(drop.get("quantidade", 0))
		var raridade := str(drop.get("raridade", ""))
		if item_id.is_empty() or item_id.length() > 128 or quantidade < 1 or quantidade > 999:
			return false
		if not SistemaDrops.RARIDADES.has(raridade):
			return false
		var encontrado := false
		for existente in inventario:
			if str(existente.get("itemId", "")) == item_id and str(existente.get("raridade", "")) == raridade:
				existente["quantidade"] = int(existente.get("quantidade", 0)) + quantidade
				encontrado = true
				break
		if not encontrado:
			inventario.append({
				"itemId": item_id,
				"nome": str(drop.get("nome", item_id)),
				"categoria": str(drop.get("categoria", "material")),
				"raridade": raridade,
				"quantidade": quantidade,
				"origemCriaturaId": str(drop.get("origemCriaturaId", ""))
			})
	perfil["inventario"] = inventario
	return salvar(uid, perfil)


## Operações chamadas pela lógica autoritativa do servidor; nunca expostas como RPC de cliente.
func equipar_item(uid: String, item_id: String) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Conta inválida."}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	var possui := false
	for item in perfil.get("inventario", []):
		if str(item.get("itemId", "")) == item_id and int(item.get("quantidade", 0)) > 0:
			possui = true
			break
	if not possui:
		return {"ok":false,"erro":"Esse item não está no inventário."}
	var equipamentos: Dictionary = perfil.get("equipamentos", {})
	var resultado := SistemaEquipamentos.equipar(equipamentos, item_id, str(perfil.get("classeId", "")))
	if not bool(resultado.get("ok", false)):
		return resultado
	perfil["equipamentos"] = resultado["equipamentos"]
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar o equipamento."}
	return {"ok":true,"equipamentos":resultado["equipamentos"]}

func desequipar_slot(uid: String, slot: String) -> Dictionary:
	if not _uid_valido(uid):
		return {"ok":false,"erro":"Conta inválida."}
	var perfil := carregar_ou_criar(uid)
	if perfil.is_empty() or not bool(perfil.get("personagemCriado", false)):
		return {"ok":false,"erro":"Personagem não encontrado."}
	var resultado := SistemaEquipamentos.desequipar(perfil.get("equipamentos", {}), slot)
	if not bool(resultado.get("ok", false)):
		return resultado
	perfil["equipamentos"] = resultado["equipamentos"]
	if not salvar(uid, perfil):
		return {"ok":false,"erro":"Não foi possível salvar a alteração."}
	return {"ok":true,"equipamentos":resultado["equipamentos"]}

func _snapshot_valido(d: Dictionary) -> bool:
	var nivel := int(d.get("nivel", 0))
	var experiencia := int(d.get("experiencia", -1))
	var vida_maxima := int(d.get("vidaMaxima", 0))
	var vida := int(d.get("vida", -1))
	var mana_maxima := int(d.get("manaMaxima", -1))
	var mana := int(d.get("mana", -1))
	var x := float(d.get("x", -1.0))
	var y := float(d.get("y", -1.0))
	if nivel < 1 or nivel > 10000 or experiencia < 0:
		return false
	if vida_maxima < 1 or vida_maxima > 100000000 or vida < 0 or vida > vida_maxima:
		return false
	if mana_maxima < 0 or mana_maxima > 100000000 or mana < 0 or mana > mana_maxima:
		return false
	if not is_finite(x) or not is_finite(y):
		return false
	if x < 0.0 or x > 2400.0 or y < 0.0 or y > 1600.0:
		return false
	for atributo in ["forca", "inteligencia", "agilidade", "vitalidade", "espirito"]:
		var valor := int(d.get(atributo, -1))
		if valor < 0 or valor > 1000000:
			return false
	var nome := str(d.get("nome", ""))
	if bool(d.get("personagemCriado", false)) and (nome.strip_edges().length() < 3 or nome.length() > 20):
		return false
	if bool(d.get("personagemCriado", false)) and not CATALOGO.validar(str(d.get("sexo","")), str(d.get("aparenciaId","")), str(d.get("racaId","")), str(d.get("classeId",""))):
		return false
	var equipamentos: Dictionary = d.get("equipamentos", {})
	if not equipamentos.is_empty():
		for slot in equipamentos:
			if not SistemaEquipamentos.SLOTS.has(str(slot)):
				return false
			var item_id := str(equipamentos[slot])
			if item_id.is_empty():
				continue
			var definicao := SistemaEquipamentos.obter(item_id)
			if definicao.is_empty() or str(definicao.get("slot", "")) != str(slot):
				return false
		var mao_principal := SistemaEquipamentos.obter(str(equipamentos.get("mao_principal", "")))
		if int(mao_principal.get("maos", 1)) == 2 and not str(equipamentos.get("mao_secundaria", "")).is_empty():
			return false
		var secundario := SistemaEquipamentos.obter(str(equipamentos.get("mao_secundaria", "")))
		if not secundario.is_empty() and secundario.get("tipo") != "escudo":
			return false
		if not secundario.is_empty() and not SistemaEquipamentos.CLASSES_CORPO_A_CORPO.has(str(d.get("classeId", ""))):
			return false
	return true

func _uid_valido(uid: String) -> bool:
	return not uid.is_empty() and uid.length() <= 128 and uid.is_valid_filename()

func _ler_banco() -> Dictionary:
	if FileAccess.file_exists(CAMINHO):
		var principal := _ler_arquivo_banco(CAMINHO)
		if not principal.is_empty():
			return principal
		var backup := _ler_arquivo_banco(CAMINHO_BACKUP)
		if not backup.is_empty():
			push_warning("Banco principal inválido; usando a cópia de segurança.")
			return backup
		return {}
	if FileAccess.file_exists(CAMINHO_BACKUP):
		return _ler_arquivo_banco(CAMINHO_BACKUP)
	return {"versao": 1, "personagens": {}}

func _ler_arquivo_banco(caminho: String) -> Dictionary:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null or arquivo.get_length() > LIMITE_ARQUIVO:
		return {}
	var dados = JSON.parse_string(arquivo.get_as_text())
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1:
		return {}
	if not (dados.get("personagens", {}) is Dictionary):
		return {}
	return dados

func _gravar_banco(banco: Dictionary) -> bool:
	var diretorio := ProjectSettings.globalize_path("user://dados")
	var caminho_final := ProjectSettings.globalize_path(CAMINHO)
	var caminho_backup := ProjectSettings.globalize_path(CAMINHO_BACKUP)
	var caminho_temporario := caminho_final + ".tmp"
	if DirAccess.make_dir_recursive_absolute(diretorio) != OK and not DirAccess.dir_exists_absolute(diretorio):
		return false
	var arquivo := FileAccess.open(caminho_temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(banco))
	arquivo.flush()
	var erro_arquivo := arquivo.get_error()
	arquivo.close()
	if erro_arquivo != OK:
		return false
	# Se o arquivo principal estiver corrompido, recupera primeiro o backup válido.
	if FileAccess.file_exists(CAMINHO) and _ler_arquivo_banco(CAMINHO).is_empty() and not _ler_arquivo_banco(CAMINHO_BACKUP).is_empty():
		if DirAccess.remove_absolute(caminho_final) != OK:
			return false
		if DirAccess.rename_absolute(caminho_backup, caminho_final) != OK:
			return false
	# Mantém a última versão válida antes de promover o arquivo temporário.
	if FileAccess.file_exists(CAMINHO):
		if FileAccess.file_exists(CAMINHO_BACKUP):
			if DirAccess.remove_absolute(caminho_backup) != OK:
				return false
		if DirAccess.rename_absolute(caminho_final, caminho_backup) != OK:
			return false
	if DirAccess.rename_absolute(caminho_temporario, caminho_final) != OK:
		if not FileAccess.file_exists(CAMINHO) and FileAccess.file_exists(CAMINHO_BACKUP):
			DirAccess.rename_absolute(caminho_backup, caminho_final)
		return false
	return true
