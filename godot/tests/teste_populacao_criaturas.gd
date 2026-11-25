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
	if int(resultado["quantidade"]) != 10 or int(um_dia["nascimentos"]) != 1 or int(um_dia["mortesNaturais"]) != 1:
		_falhar("Nascimentos e mortes naturais não foram calculados corretamente."); return
	var sem_alimento := Populacao.avancar(resultado, 174800, 0.0)
	if int(sem_alimento["estado"]["quantidade"]) != 9 or int(sem_alimento["nascimentos"]) != 0 or int(sem_alimento["mortesPorFome"]) != 1:
		_falhar("A escassez alimentar deveria bloquear nascimentos e causar mortalidade gradual."); return
	if int(sem_alimento["estado"].get("totalMortesFome", 0)) != 1 or int(sem_alimento["estado"].get("totalMortesNaturais", 0)) != 1:
		_falhar("Mortes por fome foram misturadas às mortes naturais."); return
	var protegido := Populacao.criar_estado({"quantidadeInicial":10,"minima":0,"maxima":20,"nascimentosPorDia":0.0,"mortesPorDia":0.0}, 0)
	var fome_normal := Populacao.avancar(protegido, 86400, 0.0)
	var fome_protegida := Populacao.avancar(protegido, 86400, 0.0, 0.25)
	if int(fome_normal.get("mortesPorFome", 0)) != 1 or int(fome_protegida.get("mortesPorFome", 0)) != 0 or absf(float(fome_protegida["estado"].get("restoMortesFome", 0.0)) - 0.75) > 0.001:
		_falhar("A proteção temporária de aliado não reduziu corretamente a mortalidade por fome."); return
	if bool(Populacao.avancar(protegido, 86400, 0.0, 0.626).get("ok", true)):
		_falhar("Aceitou proteção contra fome acima do limite seguro."); return
	var condicoes_sem_alimento := Populacao.avaliar_condicoes_habitat(estado, 0.2)
	if bool(condicoes_sem_alimento.get("podeRetornar", true)) or str(condicoes_sem_alimento.get("motivo", "")) != "alimento_insuficiente":
		_falhar("Habitat sem alimento suficiente foi considerado sustentável."); return
	var condicoes_suficientes := Populacao.avaliar_condicoes_habitat(estado, 0.8)
	if not bool(condicoes_suficientes.get("podeRetornar", false)):
		_falhar("Habitat com alimento suficiente foi bloqueado."); return
	if absf(Populacao.calcular_ocupacao(10, 20) - 0.5) > 0.001 or Populacao.calcular_ocupacao(25, 20) != 1.0:
		_falhar("Índice de ocupação da capacidade incorreto."); return
	var resumo := Populacao.resumir_estado(estado)
	if not bool(resumo.get("ok", false)) or int(resumo.get("vagas", -1)) != 10 or absf(float(resumo.get("ocupacao", -1.0)) - 0.5) > 0.001:
		_falhar("Resumo populacional não calculou ocupação e vagas."); return
	var config_infinita := config.duplicate(true)
	config_infinita["nascimentosPorDia"] = INF
	if Populacao.validar_configuracao(config_infinita):
		_falhar("Aceitou taxa de nascimento infinita."); return
	var limite := Populacao.criar_estado({"quantidadeInicial":19,"minima":2,"maxima":20,"nascimentosPorDia":100.0,"mortesPorDia":0.0}, 0)
	var cheio := Populacao.avancar(limite, 86400, 1.0)
	if int(cheio["estado"]["quantidade"]) != 20:
		_falhar("A população ultrapassou ou ignorou o limite máximo."); return
	var quase_cheio := Populacao.criar_estado({"quantidadeInicial":18,"minima":0,"maxima":20,"nascimentosPorDia":10.0,"mortesPorDia":0.0}, 0)
	var crescimento_lento := Populacao.avancar(quase_cheio, 86400, 1.0)
	if int(crescimento_lento.get("nascimentos", -1)) != 1:
		_falhar("A reprodução não desacelerou conforme o habitat se aproxima da capacidade."); return
	var minimo := Populacao.criar_estado({"quantidadeInicial":3,"minima":2,"maxima":20,"nascimentosPorDia":0.0,"mortesPorDia":100.0}, 0)
	var reduzido := Populacao.avancar(minimo, 86400, 1.0)
	if int(reduzido["estado"]["quantidade"]) != 2:
		_falhar("A população caiu abaixo do mínimo configurado."); return
	if bool(Populacao.avancar(resultado, 1000, 1.0).get("ok", true)):
		_falhar("Relógio retrocedido deveria ser recusado."); return
	var fracionario := Populacao.criar_estado({"quantidadeInicial":0,"minima":0,"maxima":10,"nascimentosPorDia":1.0,"mortesPorDia":0.0}, 0)
	var meio_dia := Populacao.avancar(fracionario, 43200, 1.0)
	var segundo_meio := Populacao.avancar(meio_dia["estado"], 86400, 1.0)
	if int(segundo_meio["estado"]["quantidade"]) != 6:
		_falhar("Frações de nascimento não foram acumuladas corretamente."); return
	var alimento_parcial := Populacao.criar_estado({"quantidadeInicial":10,"minima":0,"maxima":20,"nascimentosPorDia":0.0,"mortesPorDia":0.0}, 0)
	var meia_comida := Populacao.avancar(alimento_parcial, 86400, 0.5)
	if int(meia_comida.get("mortesPorFome", 0)) != 0 or absf(float(meia_comida["estado"].get("restoMortesFome", 0.0)) - 0.5) > 0.001:
		_falhar("Mortalidade por fome fracionária não foi acumulada corretamente."); return
	print("TESTE DE POPULAÇÃO DE CRIATURAS: aprovado.")
	quit(0)

func _falhar(mensagem: String) -> void:
	push_error("TESTE DE POPULAÇÃO DE CRIATURAS: " + mensagem)
	quit(1)
