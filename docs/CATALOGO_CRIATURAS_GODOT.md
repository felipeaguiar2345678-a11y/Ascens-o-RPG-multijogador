# Catálogo global de criaturas geradas

## Objetivo
O catálogo recebe criaturas completas fornecidas por um gerador confiável executado no servidor. Ele não mantém uma lista artesanal de inimigos e não finge produzir IA: a integração com um provedor de geração será uma etapa separada, sujeita à escolha e aprovação de custos.

## Registro e validação
- Arquivo de desenvolvimento: `user://dados/criaturas_online.json`, com cópia `.bak` e gravação temporária.
- Cada criatura precisa de ID único, nome, descrição, rank E–SSS, raridade, nível, atributos de combate, experiência, perigo, ecossistema, bioma, habitat, habilidades e tabela de drops válida.
- IDs duplicados são recusados; dados inválidos não entram no catálogo.
- Cada registro guarda campos de versão, descoberta global e total de derrotas.

## Descoberta e histórico global
- A primeira descoberta registra o UID do primeiro descobridor e o horário.
- Cada jogador conta apenas uma vez no total de descobertas de uma criatura.
- Derrotas são contabilizadas individualmente e no total global.
- O primeiro derrotador e o horário da primeira derrota também são preservados.
- O catálogo pode listar criaturas por ecossistema e recuperar estatísticas globais.

## Segurança e limites
- O repositório é uma classe de armazenamento para uso no processo servidor; não cria RPC público para o cliente.
- O servidor deve validar a origem dos dados antes de chamar `registrar_criatura_gerada`.
- O arquivo local é adequado somente ao desenvolvimento em um servidor com disco persistente. Ainda não é banco distribuído nem persistência em nuvem.
- Ainda não há gerador de IA conectado, gatilhos de zona no mapa ou sincronização de descobertas entre servidores. Não iniciar encontros a partir de dados enviados pelo cliente.
- Não há uso de API paga ou serviço externo nesta etapa.

## Integração com a sessão multiplayer
- `RedeMultiplayer.registrar_criatura_gerada_servidor` só aceita chamadas no processo servidor.
- Ao iniciar um combate, o servidor recupera a criatura pelo ID no catálogo; se ainda não estiver registrada, tenta registrar os dados recebidos da lógica interna confiável.
- O estado de combate usa os atributos da cópia persistida, e não um pacote de atributos enviado pelo cliente.
- O início do encontro registra a descoberta para o UID autenticado.
- Uma vitória confirmada registra a derrota global e individual antes de conceder os drops.
- `RedeMultiplayer.tentar_iniciar_encontro_servidor` é a porta interna para a lógica confiável do mundo: recebe o ecossistema, bioma, perigo e autorização de chefe calculados no servidor, consulta o catálogo, seleciona uma criatura e inicia o combate. Não é RPC e não aceita chamadas de clientes.
- O método exige jogador autenticado, personagem criado, presença no mundo, ausência de combate ativo e intervalo mínimo de 30 segundos entre encontros iniciados para o mesmo jogador.
- A função não é chamada automaticamente ainda: falta definir zonas/biomas reais por coordenadas e conectar um gatilho de exploração que derive o contexto da posição validada no servidor.

## Seleção de encontros
- `SistemaSelecaoEncontros` seleciona somente criaturas que já existem no catálogo.
- A seleção exige correspondência exata de ecossistema e bioma e não ultrapassa o nível de perigo informado pelo servidor.
- Chefes ficam excluídos por padrão e só entram quando a lógica confiável autoriza explicitamente.
- A raridade determina o peso relativo da seleção: criaturas comuns são mais frequentes; raridades superiores são progressivamente mais difíceis de selecionar.
- A semente é fornecida pelo servidor para permitir testes reproduzíveis.
- Este componente não determina a posição do jogador nem cria criaturas. O contexto de zona deve ser calculado pela lógica do mundo no servidor. A seleção só funciona quando já existem criaturas registradas que correspondam exatamente ao ecossistema e bioma.


## Criaturas sobreviventes e evolução persistente

- Quando o jogador perde um combate, o servidor registra a vitória da criatura sobre aquele UID. A criatura continua registrada e não é apagada ao terminar a batalha.
- Cada registro mantém quantidade de vitórias sobre jogadores, lista de jogadores derrotados, data inicial da vida persistente, dias de evolução, atributos-base e mutações.
- A evolução temporal é calculada pelo tempo real decorrido, inclusive entre sessões: +2% nos atributos por dia, limitado a 30% por tempo.
- Cada vitória sobre jogador acrescenta progresso evolutivo de 0,5%, limitado a 20%.
- A cada cinco vitórias sobre jogadores ou sete dias de sobrevivência, a criatura pode desenvolver uma mutação. O limite atual é de três mutações por criatura.
- Mutações alteram um atributo específico e recebem nomes próprios, como Carapaça reforçada, Olhos arcanos e Membros predatórios. O cálculo sempre parte dos atributos-base, evitando crescimento multiplicativo sem controle.
- O servidor aplica a evolução ao recuperar a criatura do catálogo ou listar criaturas do ecossistema.
- **Limite desta etapa:** a persistência e a evolução estão implementadas no catálogo do servidor, mas a entidade ainda não caminha fisicamente pelo mapa nem tem posição de mundo sincronizada. Isso depende do sistema de entidades persistentes, zonas e navegação do mundo, que será conectado depois. O registro atual é armazenamento local de desenvolvimento, não persistência distribuída em nuvem.


## Criaturas errantes no mundo compartilhado

- Quando uma criatura derrota um jogador, o servidor registra sua posição validada no mundo no momento da derrota, junto de uma origem e um alvo inicial de caminhada.
- O servidor mantém a lista das criaturas sobreviventes em memória e atualiza sua caminhada em intervalos de um segundo.
- A criatura vaga em torno da região em que venceu, com raio limitado a 220 unidades e velocidade de 24 unidades por segundo. Não atravessa os limites gerais do mapa.
- Posições e destinos são gravados em lote no catálogo local a cada cinco segundos, evitando uma gravação individual por criatura.
- Ao entrar no mundo, cada cliente recebe a lista das criaturas persistentes. Depois, recebe atualizações de posição emitidas pelo servidor.
- A tela de mundo cria marcadores provisórios com nome, indicação de chefe e mutação. A aparência ainda não é o sprite definitivo.
- O servidor é a autoridade da posição; clientes não enviam nem escolhem posições dessas criaturas.
- **Limite atual:** a caminhada usa uma área circular simples ao redor do local da vitória. Ainda não considera colisões, estradas, obstáculos, regiões ecológicas ou navegação por terreno. O sistema atual só movimenta criaturas que já derrotaram pelo menos um jogador. A persistência segue local ao servidor de desenvolvimento.


## Núcleo de comportamento de criaturas

O módulo `godot/scripts/sistema_comportamento_criaturas.gd` decide entre vagar, fugir, caçar, buscar habitat e defender território a partir de sinais fornecidos pelo servidor. Mutações de ataque, defesa, agilidade e vida influenciam os limiares e a velocidade. A função não inicia combate nem cria presas, invasores ou habitats.

**Limite atual:** o mundo ainda precisa fornecer dados reais de presas, invasores, força relativa e adequação de habitat. Até esses sistemas existirem, a movimentação errante permanece no comportamento simples já implementado; este módulo é o núcleo de decisão testado, não uma simulação ecológica completa.


## Comportamento ligado à presença de jogadores

A simulação do servidor agora consulta jogadores autenticados próximos (até 180 unidades) e compara uma pontuação aproximada de força com a criatura. Criaturas mais fortes podem perseguir; criaturas em desvantagem fogem. A velocidade de perseguição/fuga recebe o modificador retornado pelo sistema de comportamento. O estado é salvo junto das posições e enviado aos clientes, cujo marcador exibe um símbolo correspondente.

A pontuação é uma heurística inicial baseada em nível, atributos e recursos, não uma previsão perfeita do resultado de combate. Perseguição não inicia combate automaticamente; não há ainda dados de presas não-jogadoras, disputa real de território, navegação por habitat, colisões ou caminhos. Os estados de habitat e território continuam aguardando dados reais do mundo.


## Relações ecológicas e interação entre criaturas

O módulo `godot/scripts/sistema_ecologia_criaturas.gd` aceita relações explícitas no campo opcional `ecologia` de cada criatura:
- `especiesPresas`: IDs de espécies que a criatura caça.
- `especiesPredadoras`: IDs de espécies que podem caçá-la.
- `territorio`: centro (`x`, `y`) e raio do território declarado.

O cadastro valida os campos, limita listas e dimensões e rejeita IDs duplicados. A ausência de relações significa neutralidade; dieta e hostilidade nunca são inferidas pelo nome, aparência ou rank.

O servidor agora procura criaturas persistentes próximas no mesmo ecossistema. Quando encontra uma relação declarada, uma criatura predadora suficientemente forte pode perseguir a presa; uma criatura reconhecida como presa pode fugir. Uma criatura territorial pode aproximar-se de um invasor dentro de seu território para defendê-lo. Os alvos e posições são calculados pelo servidor.

**Limites atuais:** a interação ocorre somente entre criaturas já persistentes no mundo (atualmente, as que derrotaram pelo menos um jogador). A perseguição não causa dano nem morte entre criaturas e não altera populações; não há ainda geração de população selvagem, cadeia alimentar com consumo, disputa territorial com resultado ou migração entre habitats. Essas etapas exigem dados e regras próprios antes de simular consequências. As posições ainda usam o mapa provisório e não navegam por obstáculos.


## Base de reprodução e equilíbrio de populações

O módulo `godot/scripts/sistema_populacao_criaturas.gd` introduz a simulação matemática para populações de espécies já registradas. A configuração é opcional e declarada no campo `ecologia.populacao`:
- `quantidadeInicial`: quantidade inicial conhecida.
- `minima` e `maxima`: limites populacionais rígidos.
- `nascimentosPorDia` e `mortesPorDia`: taxas declaradas por dia de simulação.

O estado guarda a quantidade atual, horário da última simulação, frações acumuladas de nascimentos/mortes e totais históricos. A simulação usa o tempo real transcorrido, acumula taxas fracionárias, respeita os limites mínimo/máximo e recusa relógio retrocedido ou índice de alimento fora de 0..1. A disponibilidade de alimento é um dado explícito: sem alimento, não há nascimentos; o módulo não inventa dieta nem presume que uma presa esteja disponível.

**Limite desta etapa:** o simulador e sua validação estão implementados e testados como núcleo isolado, mas ainda não criam indivíduos no mapa, não persistem estados populacionais no catálogo e não conectam nascimentos/mortes à perseguição entre criaturas. Nenhuma população é iniciada automaticamente: cada espécie precisa declarar seus próprios parâmetros. Ainda não há consumo de presas, cadeia alimentar, migração ou morte por fome. Isso evita que o mundo invente ecologia sem dados confiáveis.
