# Migração para Godot — Ascensão do Soberano

## Decisão técnica
Motor: Godot 4.7.2 estável, renderizador Compatibility e GDScript. A versão 4.8 ainda está em beta na data desta decisão; portanto, não será usada em produção.

## Objetivo de produto
RPG 2D de ação e exploração em tempo real, com câmera acompanhando o personagem, joystick virtual, colisões, cidades e grandes regiões conectadas. O combate ocorre em uma tela própria por turnos, com regras e identidade visual do Ascensão. **O jogo será exclusivamente online/multiplayer: não haverá modo offline, campanha offline ou mundo separado por jogador. Todos compartilham um único mundo persistente.**

## Preservação
O projeto Android/Kotlin atual não será apagado durante a migração. A branch de backup do RPG de texto será mantida intacta. A migração ocorre nesta branch isolada.

## Sistemas que devem ser reaproveitados/adaptados
- Perfil, atributos, nível, experiência e salvamento do personagem.
- Catálogo global de criaturas, raridades, ecossistemas, chefes e descoberta individual.
- Regras de combate, habilidades, efeitos, turnos, vitória/derrota e recompensas.
- Inventário, equipamentos, ovos, companheiros e progressão.
- Contas e dados persistidos no Firebase.

## Regras de descoberta visual
Criaturas com visual já registrado e armazenado podem aparecer com sua arte existente. Criaturas sem visual conhecido podem ser representadas por silhueta escura e interrogação ou por encontro surpresa, sem revelar uma arte inexistente. Descoberta global não substitui descoberta individual.

## Arquitetura alvo
- Godot: cliente do jogo — cenas, exploração 2D, câmera, controles, colisões, animações, interface e apresentação do combate.
- GDScript: lógica de apresentação e interação do cliente; não deve ser autoridade final para ações competitivas ou estado compartilhado.
- Servidor multiplayer: autoridade sobre sessões, presença, posição validada, estado do mundo, encontros, combate, vida global de chefes, placares, inventário, economia e recompensas.
- Mundo único lógico e persistente: todos os jogadores conectam-se ao mesmo universo e observam os mesmos eventos e alterações globais. Soluções de escala podem distribuir carga, mas não criar mundos independentes por jogador.
- Persistência: contas, personagens, inventários, catálogo, estado mundial, relógio de eventos e histórico devem ser salvos no backend.
- Firebase existente: avaliar o que pode continuar sendo usado para autenticação e dados; não presumir que Firestore/client-side seja suficiente como autoridade antitrapaça para combate, economia ou chefes mundiais.
- Kotlin existente: referência e fonte dos contratos/regras a portar, não dependência automática do runtime Godot.
- GitHub Actions: validação headless e, em etapa posterior, exportação Android.

## Etapas
1. Criar projeto Godot isolado e validar abertura/headless.
2. Definir a arquitetura de servidor autoritativo e o protocolo de comunicação cliente-servidor, priorizando opções gratuitas e avaliando limites/custos antes de escolher hospedagem.
3. Definir contratos de dados, autenticação, sessões, presença e persistência para o mundo único.
4. Construir o cliente de exploração: controle móvel, personagem, câmera, colisões, mapa e sincronização de outros jogadores.
5. Construir áreas, biomas, cidades, transições e estado mundial compartilhado.
6. Implementar encontros e combate por turnos com validação no servidor; sincronizar chefes mundiais, placares e recompensas.
7. Portar inventário, progressão, catálogo de criaturas e persistência/autenticação.
8. Configurar exportação Android, gerar APK e testar em dispositivo real com múltiplos clientes conectados.
9. Migrar dados e fluxo principal somente após testes de compatibilidade.

## Regras obrigatórias do multiplayer
- Não criar modo offline ou campanha individual separada.
- Sem conexão com o servidor, o jogador não entra no mundo.
- Todos compartilham o mesmo mundo lógico persistente; personagem e progressão são individuais, mundo e eventos são coletivos.
- O servidor valida ações sensíveis. Nunca confiar no cliente para definir dano final, vida de chefe mundial, itens, moedas, ranking ou recompensas.
- Planejar reconexão, desconexão, perda de conexão, sincronização inicial e prevenção de duplicação de ações/recompensas.
- Nenhum serviço pago será ativado sem explicar custos e receber aprovação explícita.

## Restrições
- Não apagar nem sobrescrever o projeto antigo nesta fase.
- Não habilitar serviços pagos, APIs pagas ou geração paga de arte sem autorização específica após explicar custos.
- Não usar EnemyDatabase manual como fonte de criaturas; a geração e o catálogo de criaturas devem seguir o sistema dinâmico já definido.
- Não declarar APK pronto sem exportação e teste reais.
