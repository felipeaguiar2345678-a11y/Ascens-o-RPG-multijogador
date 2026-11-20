# Ascensão do Soberano — projeto Godot

Este diretório contém a migração do jogo para Godot 4.7.2 estável, usando GDScript e renderizador Compatibility para priorizar dispositivos Android. **Direção oficial: jogo exclusivamente online e multiplayer, em um único mundo persistente compartilhado. Não haverá modo offline ou campanha separada.**

## Abrir
Abra este diretório no Godot 4.7.2 ou superior. A cena inicial é `scenes/mundo_principal.tscn`.

## Implementado na base atual
- Mapa regional amplo de referência para a Região Central e a cidade de Aurelia.
- Câmera 2D acompanhando o personagem, com limites do mundo.
- Movimento por teclado para testes no computador.
- Joystick virtual na tela para controle por toque.
- Estrutura opcional de companheiro seguidor, desativada até o jogador desbloquear um pet.
- Jǫrmungandr contorna o perímetro da área liberada como guardião lendário, com barreiras físicas no limite.
- Aviso visual de perigo que aparece quando o jogador se aproxima do perímetro protegido por Jǫrmungandr.
- Cena de personagem e companheiro com formas geométricas temporárias para validar escala e movimentação.

## Próximas etapas
- Substituir a composição geométrica e o guardião provisório por arte pixelada final, tilesets e construções modulares.
- Desenvolver a presença ativa, animações, regras de encontro e combate lendário de Jǫrmungandr; ainda não implementados.
- Implementar colisões reais, passagens entre áreas e salvamento da posição.
- Conectar exploração, encontros e retorno ao ponto exato após combate por turnos.
- Portar personagem, criaturas, inventário, progressão e catálogo global.
- Integrar autenticação e persistência de forma segura.
- Construir a arquitetura online autoritativa: servidor valida estado, movimento, combate, inventário, economia, eventos e chefes mundiais; clientes Godot exibem e controlam seus personagens.
- Sincronizar todos os jogadores no mesmo mundo/região, com progressão individual e estado coletivo persistente.
- Configurar exportação e validar o APK em aparelho Android.

## Direção multiplayer obrigatória
- O jogo exige conexão com o servidor para entrar; não existe modo offline separado.
- Todos os jogadores compartilham o mesmo mundo persistente, cidades, regiões, eventos, criaturas e chefes mundiais.
- Cada jogador mantém personagem, progressão, equipamentos e inventário próprios.
- O servidor é a autoridade do estado compartilhado e valida ações importantes; o cliente não decide sozinho dano, recompensas, economia ou resultado de eventos.
- Instâncias técnicas podem ser usadas apenas se necessárias à escala, mas não devem criar campanhas privadas ou mundos divergentes. A experiência deve preservar um único mundo lógico compartilhado.
- Antes de contratar ou ativar qualquer serviço pago, explicar custos e obter aprovação explícita.

## Regras da migração
- O projeto Android/Kotlin anterior permanece preservado durante a migração.
- A branch de migração é isolada; não substituir a versão principal nem o backup sem validação.
- Sistemas antigos serão portados em módulos, não copiados como um bloco único.
- Nenhuma API paga, geração paga de imagens ou serviço com cobrança será ativado sem aprovação explícita.

## Estado de validação
A validação headless anterior passou. As alterações recentes de mapa, joystick e companheiro precisam passar pela execução automática atual; isso ainda não equivale a um APK Android pronto.
