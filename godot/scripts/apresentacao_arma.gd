extends Node2D
class_name ApresentacaoArma

const CatalogoVisual = preload("res://scripts/catalogo_visual_equipamentos.gd")
const CatalogoArmas = preload("res://scripts/catalogo_armas_one_piece.gd")

## Contrato único entre o item persistido, a miniatura do inventário e a arte equipada.
## As texturas finais são arquivos transparentes, preparados por arma; nenhum placeholder é desenhado.

const CATALOGO_VISUAL := {
	"kikoku": {"inventario":"res://assets/armas/inventario/kikoku.png","equipada":"res://assets/armas/equipadas/kikoku.png","escala":1.45},
	"gryphon": {"inventario":"res://assets/armas/inventario/gryphon.png","equipada":"res://assets/armas/equipadas/gryphon.png","escala":1.2},
	"wado_ichimonji": {"inventario":"res://assets/armas/inventario/wado_ichimonji.png","equipada":"res://assets/armas/equipadas/wado_ichimonji.png","escala":1.0},
	"sandai_kitetsu": {"inventario":"res://assets/armas/inventario/sandai_kitetsu.png","equipada":"res://assets/armas/equipadas/sandai_kitetsu.png","escala":1.0},
	"enma": {"inventario":"res://assets/armas/inventario/enma.png","equipada":"res://assets/armas/equipadas/enma.png","escala":1.0},
	"murakumogiri": {"inventario":"res://assets/armas/inventario/murakumogiri.png","equipada":"res://assets/armas/equipadas/murakumogiri.png","escala":2.25},
	"tripla_katana": {"inventario":"res://assets/armas/inventario/tripla_katana.png","equipada":"res://assets/armas/equipadas/tripla_katana.png","escala":1.3}
}

const POSICOES_MAO := {
	"frente": Vector2(8.0, 4.0),
	"costas": Vector2(-7.0, 3.0),
	"esquerda": Vector2(-8.0, 3.0),
	"direita": Vector2(8.0, 3.0)
}
const ROTACOES := {"frente": -0.48, "costas": 0.48, "esquerda": -1.15, "direita": 0.35}

## Multiplicadores por família; IDs especiais podem sobrescrever estes valores.
const ESCALAS_CATEGORIA := {
	"espada": 1.0, "espadas": 1.0, "espada_viva": 1.1, "espada_zou": 1.15,
	"espada_negra": 1.35, "nodachi": 1.45, "bengala_espada": 0.95,
	"par_de_espadas": 0.9, "conjunto_santoryu": 1.3, "machado": 1.55,
	"bisento": 2.25, "bastao": 1.25, "tridente": 1.35, "foices": 1.2,
	"garras": 0.8, "chicote": 1.35, "arma": 1.0
}
const ESCALAS_ID := {
	"kikoku": 1.45, "gryphon": 1.2, "murakumogiri": 2.25,
	"tripla_katana": 1.3, "bruiser_axe": 1.65, "yoru": 1.4,
	"ace": 1.15, "nonosama_bo": 1.3, "mogura": 1.35
}

var arma_id := ""
var direcao := "frente"
var sprite_arma: Sprite2D

func _ready() -> void:
	sprite_arma = Sprite2D.new()
	sprite_arma.name = "SpriteArmaEquipada"
	sprite_arma.centered = true
	add_child(sprite_arma)
	z_index = 3
	_atualizar_apresentacao()

func configurar(novo_arma_id: String, nova_direcao: String = "frente") -> void:
	arma_id = novo_arma_id.strip_edges().to_lower()
	definir_direcao(nova_direcao)

func definir_direcao(nova_direcao: String) -> void:
	direcao = nova_direcao if POSICOES_MAO.has(nova_direcao) else "frente"
	_atualizar_apresentacao()

static func obter_caminho_miniatura(id: String) -> String:
	var chave := id.strip_edges().to_lower()
	var dados: Dictionary = CATALOGO_VISUAL.get(chave, {})
	var caminho := str(dados.get("inventario", ""))
	return caminho if not caminho.is_empty() else CatalogoVisual.obter_caminho_miniatura(chave)

static func obter_escala_visual(id: String) -> float:
	var chave := id.strip_edges().to_lower()
	if ESCALAS_ID.has(chave):
		return float(ESCALAS_ID[chave])
	var dados: Dictionary = CATALOGO_VISUAL.get(chave, {})
	if dados.has("escala"):
		return maxf(0.1, float(dados.escala))
	var arma := CatalogoArmas.obter(chave)
	var categoria := str(arma.get("categoria", ""))
	return maxf(0.1, float(ESCALAS_CATEGORIA.get(categoria, 1.0)))

func possui_arte_equipada(id: String) -> bool:
	var chave := id.strip_edges().to_lower()
	var dados: Dictionary = CATALOGO_VISUAL.get(chave, {})
	var caminho := str(dados.get("equipada", ""))
	if caminho.is_empty():
		caminho = CatalogoVisual.obter_caminho_equipado(chave)
	return not caminho.is_empty() and ResourceLoader.exists(caminho)

func _atualizar_apresentacao() -> void:
	if not is_instance_valid(sprite_arma):
		return
	var dados: Dictionary = CATALOGO_VISUAL.get(arma_id, {})
	var caminho := str(dados.get("equipada", ""))
	if caminho.is_empty():
		caminho = CatalogoVisual.obter_caminho_equipado(arma_id)
	sprite_arma.texture = load(caminho) as Texture2D if not caminho.is_empty() and ResourceLoader.exists(caminho) else null
	sprite_arma.visible = sprite_arma.texture != null
	sprite_arma.position = POSICOES_MAO[direcao]
	sprite_arma.rotation = float(ROTACOES[direcao])
	var escala := obter_escala_visual(arma_id)
	sprite_arma.scale = Vector2.ONE * escala
