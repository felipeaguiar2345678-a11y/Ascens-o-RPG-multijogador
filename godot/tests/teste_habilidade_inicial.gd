extends SceneTree

const Sistema = preload("res://scripts/sistema_habilidade_inicial.gd")
const Catalogo = preload("res://scripts/catalogo_criacao_personagem.gd")

func _initialize() -> void:
 var combinacoes := [["humano","guerreiro"],["elfo","mago"],["orc","guerreiro"],["anao","cavaleiro"],["umbral","assassino"],["silvestre","curandeiro"],["fera","monge"],["draconiano","invocador"]]
 for combinacao in combinacoes:
  var perfil: Dictionary = Catalogo.montar_perfil("masculino","masc_cabelo_curto",combinacao[0],combinacao[1])
  var habilidade: Dictionary = Sistema.gerar(perfil,"teste_" + combinacao[0] + combinacao[1])
  assert(not habilidade.is_empty())
  assert(not str(habilidade.get("nome","")).is_empty())
  assert(str(habilidade.get("racaOrigem","")) == combinacao[0])
  assert(str(habilidade.get("classeOrigem","")) == combinacao[1])
  assert(float(habilidade.get("multiplicadorDano",9.0)) <= 1.1)
  assert(bool(habilidade.get("habilidadeInicial",false)))
  assert(str(habilidade.get("raridade","")) == "comum")
  assert(int(habilidade.get("nivel",0)) == 1)
 print("OK: geração de habilidade inicial por raça e classe.")
 quit()
