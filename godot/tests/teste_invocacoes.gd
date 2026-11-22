extends SceneTree

const Sistema = preload("res://scripts/sistema_invocacoes.gd")
const Catalogo = preload("res://scripts/catalogo_criacao_personagem.gd")

func _initialize() -> void:
 var inicial_a := Sistema.gerar_inicial("jogador_a")
 var inicial_b := Sistema.gerar_inicial("jogador_b")
 assert(not inicial_a.is_empty())
 assert(not inicial_b.is_empty())
 assert(str(inicial_a.get("id","")) != str(inicial_b.get("id","")))
 assert(str(inicial_a.get("origem","")) == "inicial")
 assert(int(inicial_a.get("nivel",0)) == 1)
 assert(Sistema.gerar_inicial("jogador_a") == inicial_a, "A mesma identidade deve gerar a mesma invocação, caso a criação precise ser retomada.")
 var ganho := Sistema.adicionar_experiencia(inicial_a, 100)
 assert(bool(ganho.get("ok",false)))
 assert(int(ganho.invocacao.nivel) == 2)
 var monstro := {"id":"monstro_teste","nome":"Lobo","rank":"D","nivel":2,"vidaMaxima":80,"ataque":20,"defesa":8,"agilidade":12}
 var alimento := Sistema.alimentar(inicial_a, monstro)
 assert(bool(alimento.get("ok",false)))
 var perfil := {"uid":"jogador_a","invocacoes":[inicial_a]}
 var tentativa_viva := Sistema.domesticar(perfil, monstro)
 assert(not bool(tentativa_viva.get("ok", false)), "Não pode domesticar criatura viva.")
 var monstro_derrotado := monstro.duplicate(true)
 monstro_derrotado["derrotadoEmCombate"] = true
 var domesticada := Sistema.domesticar(perfil, monstro_derrotado)
 assert(bool(domesticada.get("ok",false)))
 perfil.invocacoes.append(domesticada.invocacao)
 assert(Sistema.selecionar(perfil, str(domesticada.invocacao.id)))
 assert(str(perfil.invocacaoAtivaId) == str(domesticada.invocacao.id))
 assert(is_equal_approx(Sistema.calcular_chance_domesticacao({"rank":"E"}), 0.35))
 assert(is_equal_approx(Sistema.calcular_chance_domesticacao({"rank":"A"}), 0.19))
 assert(is_equal_approx(Sistema.calcular_chance_domesticacao({"rank":"SSS"}), 0.07))
 assert(is_equal_approx(Sistema.calcular_chance_domesticacao({"rank":"SSS","chefe":true}), 0.014))
 assert(is_equal_approx(Sistema.calcular_chance_domesticacao({"rank":"E","chefe":true}), 0.07))
 assert(Sistema.MAX_TENTATIVAS_DOMESTICACAO == 3)
 print("OK: identidade, XP, alimentação, evolução, três tentativas e chefes domesticáveis.")
 quit()
