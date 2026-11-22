extends SceneTree
const Populacao = preload("res://scripts/sistema_populacao_criaturas.gd")

func _initialize() -> void:
	var config := {"quantidadeInicial":10,"minima":2,"maxima":20,"nascimentosPorDia":2.0,"mortesPorDia":1.0}
	if not Populacao.validar_configuracao(config):
		_falhar("Configuração válida foi rejeitada."); return
	var estado := Populacao.criar_estado(config, 1000)
	if estado.is_empty() or int(estado.get("quantidade", -1)) != 10:
		_falhar("Estado inicial não foi criado corretamente."); return
	var um_dia := Populacao.avancar(estado, 87400, 1.0)
	if not bool(um_dia.get("ok", false)):
		_falhar("Simulação de um dia falhou."); return
	var resultado: Dictionary = um_dia["estado"]
	if int(resultado["quantidade"]) != 11 or int(um_dia["nascimentos"]) != 2 or int(um_dia["mortesNaturais"]) != 1:
		_falhar("Nascimentos e mortes naturais não foram calculados corretamente."); return
	var sem_alimento := Populacao.avancar(resultado, 174800, 0.0)
	if int(sem_alimento["estado"]["quantidade"]) != 10 or int(sem_alimento["nascimentos"]) != 0:
		_falhar("Sem alimento declarado, não deveria haver nascimento."); return
	var limite := Populacao.criar_estado({"quantidadeInicial":19,"minima":2,"maxima":20,"nascimentosPorDia":100.0,"mortesPorDia":0.0}, 0)
	var cheio := Populacao.avancar(limite, 86400, 1.0)
	if int(cheio["estado"]["quantidade"]) != 20:
		_falhar("A população ultrapassou ou ignorou o limite máximo."); return
	var minimo := Populacao.criar_estado({"quantidadeInicial":3,"minima":2,"maxima":20,"nascimentosPorDia":0.0,"mortesPorDia":100.0}, 0)
	var reduzido := Populacao.avancar(minimo, 86400, 1.0)
	if int(reduzido["estado"]["quantidade"]) != 2:
		_falhar("A população caiu abaixo do mínimo configurado."); return
	if bool(Populacao.avancar(resultado, 1000, 1.0).get("ok", true)):
		_falhar("Relógio retrocedido deveria ser recusado."); return
	var fracionario := Populacao.criar_estado({"quantidadeInicial":5,"minima":0,"maxima":10,"nascimentosPorDia":1.0,"mortesPorDia":0.0}, 0)
	var meio_dia := Populacao.avancar(fracionario, 43200, 1.0)
	var segundo_meio := Populacao.avancar(meio_dia["estado"], 86400, 1.0)
	if int(segundo_meio["estado"]["quantidade"]) != 6:
		_falhar("Frações de nascimento não foram acumuladas corretamente."); return
	print("TESTE DE POPULAÇÃO DE CRIATURAS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE POPULAÇÃO DE CRIATURAS: " + mensagem)
	quit(1)
