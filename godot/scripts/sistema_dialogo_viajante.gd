extends RefCounted
## Sequência curta de conversa opcional da viajante Iren.
## Não cria missão, não concede recompensa e não bloqueia a exploração.

static func avancar(etapa_atual: int) -> Dictionary:
	match etapa_atual:
		0:
			return {
				"continuar": true,
				"etapa": 1,
				"texto": "IREN, VIAJANTE\nA estrada para Aurelia está tranquila por enquanto. Vejo carroças seguindo para o sul desde cedo.\n\nSe pretende visitar a cidade, a trilha principal é a mais movimentada.",
				"botao": "Perguntar sobre a floresta"
			}
		1:
			return {
				"continuar": true,
				"etapa": 2,
				"texto": "IREN, VIAJANTE\nMais ao norte, a mata fica fechada e os caminhos mudam depois das chuvas. Às vezes, o som dos rios ajuda a encontrar uma trilha segura.\n\nNão precisa seguir conselho algum. A floresta está aberta para quem quiser explorá-la.",
				"botao": "Perguntar por que ela viaja"
			}
		2:
			return {
				"continuar": true,
				"etapa": 3,
				"texto": "IREN, VIAJANTE\nViajo para conhecer lugares que ainda não aparecem nos mapas. Cada parada rende uma história diferente.\n\nTalvez nossos caminhos se cruzem outra vez.",
				"botao": "Encerrar conversa"
			}
		_:
			return {"continuar": false, "etapa": 0}
