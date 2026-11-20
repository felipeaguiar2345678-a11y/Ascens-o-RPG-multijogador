# Multiplayer exclusivo — mundo único persistente

**Decisão oficial de produto:** Ascensão do Soberano será exclusivamente online e multiplayer. Não haverá modo offline, campanha offline ou modo solo separado.

## Visão

Todos os jogadores entram no mesmo mundo lógico persistente. Eles podem se encontrar nas cidades, estradas, florestas e demais regiões, explorar simultaneamente, participar dos mesmos eventos e afetar o estado coletivo do universo.

O mundo não é recriado individualmente para cada jogador. Instâncias técnicas, zonas de servidor ou distribuição de carga só poderão ser usadas se preservarem um único mundo lógico compartilhado, sem campanhas privadas ou estados divergentes.

## O que é individual e o que é compartilhado

| Individual por jogador | Compartilhado pelo mundo |
|---|---|
| Personagem e aparência | Mapa, cidades e regiões |
| Nível, experiência e atributos | Estado e mudanças dos ecossistemas |
| Habilidades e equipamentos | Eventos mundiais |
| Inventário e moedas pessoais | Criaturas e descobertas globais |
| Missões/progresso pessoal quando aplicável | Chefes mundiais e vida global |
| Histórico pessoal | Placar e história dos acontecimentos mundiais |

## Requisitos de funcionamento

- A conexão com o servidor é obrigatória para entrar no jogo.
- Sem conexão, o jogador não acessa uma campanha offline alternativa.
- O servidor mantém e valida o estado compartilhado do mundo.
- Jogadores conectados à mesma região podem ver e encontrar uns aos outros.
- Movimento, presença e estado dos personagens são sincronizados.
- O mundo continua evoluindo com base no relógio persistente do servidor, mesmo quando um jogador está desconectado.
- Reconexões recuperam o estado atual do personagem e do mundo.
- Quedas de conexão não podem duplicar ataques, itens, pagamentos, recompensas ou progresso.
- A experiência deve suportar inicialmente uma população pequena e crescer por etapas, sem abandonar a regra de mundo único.

## Autoridade do servidor

O cliente Godot cuida da apresentação, controles, câmera, interface, efeitos e envio de intenções de ação. O servidor é a autoridade final para:

- autenticação de sessão e identidade do jogador;
- posição/movimento validado e presença online;
- encontros e início/fim de combates;
- cálculo e validação de dano, turnos, efeitos e resultados;
- vida global, fases e crescimento de chefes mundiais;
- inventário, equipamentos, moedas, comércio e recompensas;
- placares, eventos, missões e alterações persistentes do mundo.

O cliente nunca deve poder declarar unilateralmente que derrotou uma criatura, causou determinado dano, recebeu um item ou venceu um chefe mundial.

## Jǫrmungandr e eventos globais

O Chefe Mundial Jǫrmungandr deve existir uma única vez no estado lógico do mundo. Sua vida compartilhada, crescimento global, maturidade, derrota, renascimento, mutações, placar e recompensas seguem o documento `docs/JORMUNGANDR_CHEFE_MUNDIAL.md`.

O relógio do mundo e o estado de eventos são controlados pelo servidor, para que todos vejam a mesma fase mesmo quando estiverem offline.

## Arquitetura e custos

A arquitetura técnica ainda precisa ser escolhida e validada. Avaliar opções gratuitas ou open-source para servidor, comunicação em tempo real, persistência e hospedagem, considerando limites de jogadores, tráfego, disponibilidade e manutenção.

Firebase pode continuar sendo avaliado para autenticação e partes da persistência, mas banco de dados acessado diretamente pelo cliente não deve ser considerado suficiente como autoridade antitrapaça para combate, economia, ranking ou chefes globais.

**Não ativar APIs, hospedagem, Cloud Functions ou serviços pagos sem antes explicar ao usuário o custo estimado, limites e alternativas, e obter aprovação explícita.** Não prometer operação gratuita ou escalabilidade sem validar os limites reais do serviço escolhido.

## Estado atual

A base Godot existente ainda é um protótipo local de exploração: personagem, câmera, joystick, mapa geométrico e guardião de perímetro. Ela ainda não sincroniza jogadores e não possui servidor multiplayer autoritativo. A decisão deste documento define o destino do produto; não significa que o multiplayer já esteja implementado.

## Critérios mínimos para considerar o primeiro multiplayer funcional

1. Dois ou mais clientes autenticados entram no mesmo mundo.
2. Cada cliente vê os demais jogadores em posições sincronizadas.
3. Movimento e presença são atualizados sem criar cópias privadas do mundo.
4. Todos recebem o mesmo estado de região e eventos globais.
5. Desconectar e reconectar restaura o estado correto.
6. O servidor rejeita ações inválidas e impede duplicação básica de ações e recompensas.
7. Um teste com dois clientes confirma que o mundo é realmente compartilhado.

