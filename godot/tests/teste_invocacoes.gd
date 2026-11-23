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
 var perfil := {"uid":"jogador_a","classeId":"invocador","invocacoes":[inicial_a]}
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
 var serpente_derrotada := {
  "id":"serpente_do_mundo","tipoChefeMundo":"serpente_mundo","nome":"Serpente do Mundo",
  "rank":"SSS","raridade":"unico","chefe":true,"derrotadoEmCombate":true,
  "vidaMaxima":1000000,"ataque":5000,"defesa":3000,"agilidade":800,"poderMagico":1200
 }
 var filhote_resultado := Sistema.domesticar({"uid":"domador_serpente","classeId":"invocador","invocacoes":[]}, serpente_derrotada)
 assert(bool(filhote_resultado.get("ok", false)), "A derrota da Serpente do Mundo deve gerar o filhote domesticável.")
 var filhote: Dictionary = filhote_resultado.get("invocacao", {})
 assert(str(filhote.get("nome", "")) == "Serpente Filhote Primordial")
 assert(str(filhote.get("rank", "")) == "SSS")
 assert(str(filhote.get("raridade", "")) == "unico")
 assert(int(filhote.get("ataque", 0)) >= 900)
 assert(str(filhote.get("crescimentoVisual", "")) == "filhote")
 filhote["nivel"] = 10
 var crescimento := Sistema._atualizar_crescimento_serpente(filhote)
 assert(str(crescimento.get("crescimentoVisual", "")) == "juvenil")
 assert(is_equal_approx(float(crescimento.get("escalaVisual", 0.0)), 1.0))
 var classe_comum := {"uid":"jogador_comum","classeId":"guerreiro","invocacoes":[]}
 var domesticacao_bloqueada := Sistema.domesticar(classe_comum, monstro_derrotado)
 assert(not bool(domesticacao_bloqueada.get("ok", false)), "Classes diferentes de Invocador não podem domesticar.")
 var ovo_teste := {
  "itemId":"ovo_lobo",
  "raridade":"raro",
  "modeloCompanheiro":{
   "nome":"Lobo Companheiro","especieId":"lobo","criaturaOrigemId":"lobo_arcano",
   "vida":90,"vidaMaxima":90,"ataque":18,"defesa":12,"agilidade":20,"poderMagico":4,
   "rank":"C","raridade":"raro","imagemId":"visual_lobo_teste","habilidades":[{"id":"mordida_teste"}]
  }
 }
 var eclosao := Sistema.chocar_ovo(classe_comum, ovo_teste)
 assert(bool(eclosao.get("ok", false)), "Uma classe comum deve conseguir chocar um ovo.")
 assert(str(eclosao.invocacao.get("nome", "")) == "Lobo Companheiro")
 assert(str(eclosao.invocacao.get("origem", "")) == "ovo")
 assert(str(eclosao.invocacao.get("imagemId", "")) == "visual_lobo_teste")
 assert(eclosao.invocacao.get("habilidades", []).size() == 1, "O companheiro deve herdar as habilidades registradas no ovo.")
 var ovo_invocador := Sistema.chocar_ovo({"uid":"invocador","classeId":"invocador","invocacoes":[]}, ovo_teste)
 assert(not bool(ovo_invocador.get("ok", false)), "Invocador não deve chocar ovos pelo sistema comum.")
 print("OK: identidade, XP, alimentação, evolução, três tentativas, chefes e filhote da Serpente do Mundo.")
 quit()
