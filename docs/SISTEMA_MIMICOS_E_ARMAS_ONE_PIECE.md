# Mímicos e armas especiais de One Piece

## Regras de aparição

A verificação ocorre somente quando o servidor confirma que o jogador abriu um baú elegível. A rolagem é única por baú:

| Resultado | Chance |
|---|---:|
| Mímico comum | 5% |
| Mímico raro | 3% |
| Mímico lendário | 1% |
| Mímico mítico | 1% |
| Baú normal | 90% |

A semente da rolagem é fornecida pelo servidor. O cliente não escolhe raridade, resultado nem recompensa.

## Disfarce e descoberta

- O mímico começa no estado `disfarcado`.
- A implementação sorteia se aquele exemplar deixa pistas visuais.
- Percepção/investigação pode revelar sinais e colocá-lo em alerta, sem iniciar combate por si só.
- Interagir a curta distância pode revelar o monstro e iniciar o encontro.
- O comportamento pode variar entre emboscar, revelar-se, perseguir ou fugir (fuga prevista para exemplares lendários/míticos feridos).

## Perfis de combate iniciais

Os atributos são valores-base de protótipo e precisarão de balanceamento contra os atributos reais dos personagens:

| Tipo | Vida | Ataque | Defesa | Fases | Armadilha | Invoca |
|---|---:|---:|---:|---:|---|---|
| Comum | 90 | 12 | 4 | 1 | Não | Não |
| Raro | 220 | 24 | 12 | 1 | Sim | Não |
| Lendário | 650 | 48 | 30 | 2 | Sim | Sim |
| Mítico | 1.800 | 85 | 55 | 3 | Sim | Sim |

Padrões iniciais: mordida com sangramento; língua de aço com lentidão; mandíbula esmagadora com atordoamento; armadilhas; devorar; chuva de fragmentos e invocação de ninhada. São dados de inimigo para o motor de combate, não novos botões do jogador.

## Recompensa de arma

Cada mímico derrotado concede no máximo uma arma principal. O sorteio é feito no servidor e usa a tabela abaixo:

| Raridade da arma | Mímico comum | Raro | Lendário | Mítico |
|---|---:|---:|---:|---:|
| Comum | 55% | 30% | 15% | 5% |
| Rara | 30% | 35% | 30% | 20% |
| Lendária | 13% | 25% | 35% | 35% |
| Mítica | 1,8% | 8% | 17% | 25% |
| Suprema | 0,2% | 2% | 3% | 15% |

As probabilidades são normalizadas somente se o catálogo disponível não contiver uma das raridades sorteáveis. A Tripla Katana é sempre excluída dos drops.

## Piedade independente

Cada vitória válida incrementa os três contadores da conta:

- 50 mímicos: uma arma Lendária garantida.
- 100 mímicos: uma arma Mítica garantida.
- 200 mímicos: uma arma Suprema garantida.

Se o jogador conseguir naturalmente uma arma de determinada raridade, somente o contador daquela raridade zera. Se mais de um marco estiver pendente no mesmo encontro, a prioridade é Suprema, depois Mítica e depois Lendária; cada encontro ainda entrega somente uma arma. Os marcos pendentes restantes são entregues nos encontros seguintes. Um mesmo ID de encontro não pode incrementar contadores ou conceder recompensa duas vezes.

O arquivo `user://dados/piedade_mimicos.json` persiste os contadores por UID no servidor dedicado. Como a persistência atual é local ao host, produção pública precisará de backup/replicação ou migração para armazenamento durável compartilhado.

## Catálogo de armas

O catálogo-base contém 49 entradas: 11 comuns, 14 raras, 13 lendárias, 6 míticas e 5 supremas. Gryphon e Kikoku estão na categoria Mítica e têm `especialSupremo=true`. Armas Míticas e Supremas recebem o Especial Supremo; armas de outras raridades não recebem essa mecânica.

A Tripla Katana é uma receita de combinação, não um drop: exige Wado Ichimonji + Sandai Kitetsu + Enma, consome as três peças numa transação de inventário no servidor e ocupa um único espaço. A função de validação da receita apenas verifica os materiais; o consumo transacional ainda precisa ser conectado ao serviço de inventário.

## Escopo desta atualização

Implementado nesta etapa: motor de regras puro, perfis e comportamentos, padrões de combate, tabela de raridades, piedade independente, persistência local de piedade, catálogo de armas e testes automatizados.

Ainda pendente para a integração jogável: posicionar baús elegíveis e mímicos no mapa, sincronizar o estado do baú entre jogadores, conectar a interação/descoberta à abertura do combate solo ou cooperativo, conceder a recompensa ao vencedor de forma transacional no perfil e sincronizar a piedade com o armazenamento persistente global. Até esses pontos serem conectados, os sistemas são módulos preparados e testáveis, não encontros já ativos no mapa.
