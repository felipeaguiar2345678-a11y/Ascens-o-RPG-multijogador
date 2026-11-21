# Ascensão do Soberano — projeto Godot

Este diretório contém a migração do jogo para Godot 4.7.2 estável, usando GDScript e renderizador Compatibility para priorizar dispositivos Android. **Direção oficial: jogo exclusivamente online e multiplayer, em um único mundo persistente compartilhado. Não haverá modo offline ou campanha separada.**

## Abrir
Abra este diretório no Godot 4.7.2 ou superior. A cena inicial é `scenes/conexao_multiplayer.tscn`; o mapa só abre após conexão ENet confirmada.

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
- Camada inicial de conexão ENet em `scripts/rede_multiplayer.gd`, registrada como singleton `RedeMultiplayer`.
- Tela inicial em `scenes/conexao_multiplayer.tscn` com cadastro/login Firebase por e-mail e senha e endereço/porta UDP; o mapa só abre após validação da conta pelo servidor.
- Validação inicial de movimento no servidor com intervalo mínimo entre pacotes, medição de tempo no servidor e rejeição de deslocamentos excessivos.
- Entrada dedicada de servidor headless em `scenes/servidor_dedicado.tscn`, com porta e limite configuráveis por argumentos.
- Protocolo inicial de entrada no mundo: o servidor mantém uma lista de presença e envia a lista de jogadores já conectados; clientes exibem representações provisórias dos demais.
- Integrar autenticação e persistência de forma segura antes de abrir o acesso público.
- Completar a arquitetura online autoritativa: validar colisões, movimento, combate, inventário, economia, eventos e chefes mundiais no servidor; clientes Godot apenas exibem e solicitam ações.
- Sincronizar todos os jogadores no mesmo mundo/região, com progressão individual e estado coletivo persistente.
- Configurar exportação Android e validar o APK em aparelho real, além de testar dois ou mais clientes simultâneos.

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

## Multiplayer online — estado atual
A direção oficial é exclusivamente online, com um único mundo lógico persistente. A camada ENet e a entrada headless dedicada foram adicionadas, com presença/entrada inicial básica. A conexão online é obrigatória e a tela inicial integra cadastro/login Firebase; o servidor valida o ID token e associa o UID antes de liberar a entrada. Ainda não há servidor público nem persistência de personagem no Godot; sem endereço de servidor ativo, não é possível entrar. O login precisa ser testado com E-mail/senha habilitado no Firebase. A validação de movimento não é antitrapaça completa. Consulte `docs/AUTENTICACAO_FIREBASE_GODOT.md`. Consulte `docs/BASE_CONEXAO_MULTIPLAYER.md` e `docs/SINCRONIZACAO_MOVIMENTO_MULTIPLAYER.md`.

## Estado de validação
A validação headless anterior passou. As alterações recentes de mapa, joystick e companheiro precisam passar pela execução automática atual; isso ainda não equivale a um APK Android pronto.
