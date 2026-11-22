extends RefCounted
## Estoques ambientais compartilhados por todos os grupos do servidor.
## Fontes só existem quando declaradas na ecologia de espécies catalogadas.
const REPOSITORIO_CRIATURAS = preload("res://scripts/repositorio_criaturas_servidor.gd")
const SISTEMA_RECURSOS = preload("res://scripts/sistema_recursos_ecologicos.gd")
const CAMINHO_PADRAO := "user://dados/recursos_ecologicos.json"
const LIMITE_ARQUIVO := 4 * 1024 * 1024

var caminho_arquivo: String
var repositorio_criaturas: Object

func _init(caminho: String = CAMINHO_PADRAO, repositorio: Object = null) -> void:
	caminho_arquivo = caminho
	repositorio_criaturas = repositorio if repositorio != null else REPOSITORIO_CRIATURAS.new()

## Consolida fontes declaradas; IDs iguais precisam ter parâmetros físicos iguais.
func obter_configuracoes_compartilhadas() -> Array:
	var por_id := {}
	for criatura in repositorio_criaturas.listar_todas_as_criaturas_catalogadas():
		var ecologia: Dictionary = criatura.get("ecologia", {})
		var fontes = ecologia.get("recursosAmbientais", [])
		if not (fontes is Array):
			continue
		for fonte in fontes:
			if not (fonte is Dictionary):
				continue
			var id := str(fonte.get("id", ""))
			if id.is_empty():
				continue
			var normalizada: Dictionary = fonte.duplicate(true)
			var consumidores: Array = normalizada.get("especiesConsumidoras", []).duplicate()
			if por_id.has(id):
				var existente: Dictionary = por_id[id]
				for campo in ["capacidade", "quantidadeInicial", "recuperacaoPorDia", "consumoPorIndividuoDia"]:
					if float(existente.get(campo, -1.0)) != float(normalizada.get(campo, -2.0)):
						return []
				for consumidor in consumidores:
					if not existente["especiesConsumidoras"].has(consumidor):
						existente["especiesConsumidoras"].append(consumidor)
				por_id[id] = existente
			else:
				por_id[id] = normalizada
	var resultado: Array = por_id.values()
	return resultado if SISTEMA_RECURSOS.validar_configuracoes(resultado) else []

## Processa uma vez o ecossistema inteiro, dividindo estoque entre todos os grupos consumidores.
func processar_tick(grupos: Array, agora_unix: int) -> Dictionary:
	var configs := obter_configuracoes_compartilhadas()
	if configs.is_empty():
		return {"ok":true,"disponibilidadePorEspecie":{},"semFontes":true}
	var banco := _ler_banco()
	if banco.is_empty() and FileAccess.file_exists(caminho_arquivo):
		return {"ok":false,"erro":"Estado de recursos inválido; processamento bloqueado."}
	var estado: Dictionary = banco.get("estado", {})
	if estado.is_empty():
		estado = SISTEMA_RECURSOS.criar_estado(configs, agora_unix)
		if estado.is_empty():
			return {"ok":false,"erro":"Não foi possível inicializar os estoques ecológicos."}
	var recursos: Dictionary = estado.get("recursos", {})
	var dias := 0.0
	for fonte in recursos.values():
		var ultima := int(fonte.get("ultimaAtualizacaoUnix", -1))
		if ultima < 0 or agora_unix < ultima:
			return {"ok":false,"erro":"Relógio dos recursos retrocedeu."}
		dias = maxf(dias, minf(float(agora_unix - ultima) / 86400.0, 3650.0))
	var demanda_por_especie := {}
	for grupo in grupos:
		var especie_id := str(grupo.get("especieId", ""))
		var vivos := 0
		for individuo in grupo.get("individuos", []):
			if bool(individuo.get("vivo", false)):
				vivos += 1
		demanda_por_especie[especie_id] = int(demanda_por_especie.get(especie_id, 0)) + vivos
	var disponibilidade := {}
	for especie_id in demanda_por_especie:
		disponibilidade[especie_id] = 1.0
	for config in configs:
		var id := str(config["id"])
		var fonte: Dictionary = recursos.get(id, {}).duplicate(true)
		if fonte.is_empty():
			return {"ok":false,"erro":"Fonte declarada ausente no estado salvo."}
		var recuperada := minf(float(config["capacidade"]), float(fonte.get("quantidade", 0.0)) + float(config["recuperacaoPorDia"]) * dias)
		var demanda_total := 0.0
		var demandas := {}
		for especie_id in demanda_por_especie:
			if config["especiesConsumidoras"].has(especie_id):
				var demanda := float(config["consumoPorIndividuoDia"]) * float(demanda_por_especie[especie_id]) * dias
				demandas[especie_id] = demanda
				demanda_total += demanda
		var indice := 1.0 if demanda_total <= 0.0 else clampf(recuperada / demanda_total, 0.0, 1.0)
		for especie_id in demandas:
			disponibilidade[especie_id] = minf(float(disponibilidade.get(especie_id, 1.0)), indice)
		var consumido := minf(recuperada, demanda_total)
		fonte["quantidade"] = maxf(0.0, recuperada - consumido)
		fonte["ultimaAtualizacaoUnix"] = agora_unix
		recursos[id] = fonte
	estado["recursos"] = recursos
	if not _gravar_banco({"versao":1,"estado":estado}):
		return {"ok":false,"erro":"Não foi possível salvar os estoques compartilhados."}
	return {"ok":true,"disponibilidadePorEspecie":disponibilidade,"diasProcessados":dias,"estoques":recursos.duplicate(true)}

func obter_estado() -> Dictionary:
	return _ler_banco().get("estado", {}).duplicate(true)

func _ler_banco() -> Dictionary:
	if not FileAccess.file_exists(caminho_arquivo):
		return {"versao":1,"estado":{}}
	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.READ)
	if arquivo == null or arquivo.get_length() > LIMITE_ARQUIVO:
		return {}
	var dados = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if not (dados is Dictionary) or int(dados.get("versao", 0)) != 1 or not (dados.get("estado", {}) is Dictionary):
		return {}
	return dados

func _gravar_banco(banco: Dictionary) -> bool:
	var diretorio := caminho_arquivo.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(diretorio)) != OK:
		return false
	var temporario := caminho_arquivo + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(banco))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		return false
	if FileAccess.file_exists(caminho_arquivo):
		var backup := caminho_arquivo + ".bak"
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho_arquivo), ProjectSettings.globalize_path(backup)) != OK:
			return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporario), ProjectSettings.globalize_path(caminho_arquivo)) == OK
