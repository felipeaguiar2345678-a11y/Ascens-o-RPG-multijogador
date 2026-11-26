extends Node2D
class_name ApresentacaoArma

const CatalogoVisual = preload("res://scripts/catalogo_visual_equipamentos.gd")

## Contrato único entre o item persistido, a miniatura do inventário e a arte equipada.
## As texturas finais são arquivos transparentes, preparados por arma; nenhum placeholder é desenhado.

const CATALOGO_VISUAL := {
	"kikoku": {"inventario":"res://assets/armas/inventario/kikoku.png","equipada":"res://assets/armas/equipadas/kikoku.png","escala":1.0},
	"gryphon": {"inventario":"res://assets/armas/inventario/gryphon.png","equipada":"res://assets/armas/equipadas/gryphon.png","escala":1.0},
	"wado_ichimonji": {"inventario":"res://assets/armas/inventario/wado_ichimonji.png","equipada":"res://assets/armas/equipadas/wado_ichimonji.png","escala":1.0},
	"sandai_kitetsu": {"inventario":"res://assets/armas/inventario/sandai_kitetsu.png","equipada":"res://assets/armas/equipadas/sandai_kitetsu.png","escala":1.0},
	"enma": {"inventario":"res://assets/armas/inventario/enma.png","equipada":"res://assets/armas/equipadas/enma.png","escala":1.0},
	"murakumogiri": {"inventario":"res://assets/armas/inventario/murakumogiri.png","equipada":"res://assets/armas/equipadas/murakumogiri.png","escala":1.0},
	"tripla_katana": {"inventario":"res://assets/armas/inventario/tripla_katana.png","equipada":"res://assets/armas/equipadas/tripla_katana.png","escala":1.0}
}

const POSICOES_MAO := {
	"frente": Vector2(8.0, 4.0),
	"costas": Vector2(-7.0, 3.0),
	"esquerda": Vector2(-8.0, 3.0),
	"direita": Vector2(8.0, 3.0)
}
const ROTACOES := {"frente": -0.48, "costas": 0.48, "esquerda": -1.15, "direita": 0.35}

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
	var escala := float(dados.get("escala", 1.0))
	sprite_arma.scale = Vector2.ONE * escala
