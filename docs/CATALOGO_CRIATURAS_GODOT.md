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


## Liderança natural por grupo

O módulo `godot/scripts/sistema_lideres_criaturas.gd` define regras isoladas para líderes naturais de grupos já existentes:
- Cada grupo tem seu próprio `grupoId` e `especieId`; a mesma espécie pode ter vários grupos e vários líderes.
- O grupo só recebe líder quando atinge `populacaoMinimaParaLider` e possui indivíduos vivos elegíveis.
- O indivíduo com maior soma de atributos declarados assume a liderança; empates são resolvidos pelo ID para manter resultado determinístico.
- Atributos de combate do líder recebem um multiplicador limitado entre 1,15 e 1,35.
- Equipamentos adicionais são escolhidos somente entre IDs existentes em `SistemaEquipamentos.CATALOGO`; não são criados itens falsos.
- A tabela de drops da própria criatura pode receber multiplicador limitado de até 2x. Isso melhora chances declaradas, mas não garante itens raros ou lendários.
- Quando o líder morre, a função de sucessão marca o indivíduo como morto e escolhe o sobrevivente elegível mais forte. O bônus do sucessor é limitado a 1,20x.

**Limite desta etapa:** o núcleo e os testes estão separados do catálogo e da simulação de população. O jogo ainda não persiste indivíduos selvagens nem grupos populacionais, então não existe liderança ativa no mapa. A integração só deve ocorrer quando o servidor tiver IDs de grupos, indivíduos vivos, equipamentos e posições persistidos; não se deve inventar indivíduos para preencher o grupo. Liderança não é rank, não é promoção por combate e não transforma automaticamente todo líder em chefe mundial.


## Grupos e indivíduos selvagens persistidos

O módulo `godot/scripts/repositorio_grupos_criaturas_servidor.gd` cria grupos somente a partir de uma criatura já registrada no catálogo global e que declare `ecologia.populacao` e `ecologia.territorio` válidos. Cada indivíduo recebe ID próprio, cópia dos atributos-base da espécie, estado vivo/morto e posição dentro do território declarado. O grupo persiste sua população, relógio ecológico, sequência de IDs e líder atual em arquivo JSON local do servidor.

Ao avançar a simulação, nascimentos geram novos indivíduos e mortes naturais marcam indivíduos existentes como mortos; a contagem viva acompanha o estado populacional. Se o líder morrer, a regra de sucessão escolhe outro indivíduo vivo elegível. O grupo pode ter equipamentos adicionais de liderança apenas se os IDs estiverem no catálogo atual.

**Limites desta etapa:** os grupos já podem ser criados, atualizados e persistidos por código do servidor, mas ainda não estão ligados à rotina de mundo/posicionamento multiplayer nem aparecem como criaturas selvagens na tela dos jogadores. A persistência continua local ao servidor de desenvolvimento, sem banco distribuído ou hospedagem pública. O alimento continua sendo uma entrada explícita do mundo; o repositório não inventa presas ou disponibilidade de recursos.


## Grupos selvagens no mundo multiplayer

- Ao iniciar o servidor, grupos salvos são restaurados; novas populações só são criadas para espécies catalogadas que declaram população e território.
- A criação inicial tem limites de 64 grupos, 80 indivíduos por grupo e 2.000 indivíduos vivos no total. Espécies sem configuração ecológica explícita não são instanciadas.
- O servidor movimenta os indivíduos em intervalos controlados, mantém todos dentro do território declarado e aproxima membros dispersos do centro do grupo.
- O líder natural recebe comportamento de proteção do grupo e destaque visual próprio. A liderança não é promoção de rank nem depende de derrotar chefes.
- Clientes recebem os indivíduos e suas posições por replicação multiplayer; o cliente não escolhe posições nem altera o estado de vida.
- A persistência de movimento é feita no repositório local do servidor. Ainda não equivale a armazenamento distribuído/cloud.
- Esta etapa implementa presença, coesão e movimento dos grupos. Caça com dano real entre espécies, mortes por combate ecológico e proteção com combate efetivo ainda precisam de um sistema próprio antes de serem considerados implementados.


## Combate ecológico entre grupos

- A caça só ocorre quando o catálogo declara explicitamente a relação predador-presa; espécies neutras não se atacam.
- O servidor procura indivíduos vivos de grupos do mesmo ecossistema e só resolve ataques quando estão próximos.
- Dano usa ataque/agilidade do indivíduo contra defesa e vida da presa, com variação controlada pelo servidor.
- Se o líder da presa estiver próximo do membro ameaçado, ele protege o membro reduzindo o dano recebido. A defesa ainda não é uma animação de interceptação física.
- A vida individual é persistida. Ao chegar a zero, o indivíduo é marcado como morto, a população é atualizada e pode ocorrer sucessão natural da liderança.
- Mortos permanecem registrados e recebem marca visual; não voltam a ser alvos nem se movimentam.
- Este combate ecológico não cria itens ou inventário de carcaça. Drops de caça, coleta de materiais e alimentação da população precisam de regras próprias e ainda não estão conectados.


## Recursos ambientais e dieta declarada

O módulo `godot/scripts/sistema_recursos_ecologicos.gd` estabelece fontes ambientais finitas, configuradas explicitamente em cada ecologia:
- Cada fonte declara ID, estoque inicial, capacidade máxima e recuperação por dia.
- A fonte lista quais IDs de espécies podem consumi-la; não há inferência de dieta por nome, aparência ou rank.
- Cada espécie consumidora declara demanda diária por indivíduo. O processamento recupera o estoque pelo tempo transcorrido, desconta a demanda dos indivíduos vivos e calcula disponibilidade de 0..1.
- O consumo direto recusa espécies não autorizadas, estoque insuficiente, quantidades inválidas e IDs duplicados.
- A simulação limita o número de fontes e o intervalo máximo de tempo processado.

**Limite desta etapa:** o núcleo de recursos e suas regras estão implementados e testados isoladamente. Ainda não está conectado ao relógio dos grupos selvagens, à reprodução, ao consumo visual no mundo nem à morte por fome. Não afirmar que os animais já estão se alimentando em tempo real até essa integração ser concluída. A próxima etapa liga o estoque compartilhado às populações e aos ciclos do servidor.


## Alimentação compartilhada e competição por recursos

- `ecologia.recursosAmbientais` declara fontes finitas, estoque inicial, capacidade, recuperação diária, consumo por indivíduo e IDs de espécies autorizadas.
- O servidor consolida fontes de mesmo ID. Fontes repetidas precisam ter capacidade, estoque inicial, recuperação e demanda iguais; as listas de consumidores são combinadas sem autorizar espécies implicitamente.
- Um repositório ambiental separado persiste o estoque compartilhado em `user://dados/recursos_ecologicos.json`.
- A cada ciclo controlado de 60 segundos, o servidor calcula a demanda conjunta de todos os grupos vivos e divide a oferta disponível entre as espécies consumidoras. O consumo é descontado uma vez do estoque compartilhado, não uma vez por grupo.
- A disponibilidade calculada por espécie é enviada ao simulador populacional. Ela afeta nascimentos e mortalidade gradual por fome; espécies sem fonte declarada não consomem esse estoque.
- O estoque é recuperado pelo tempo real transcorrido e permanece limitado à capacidade. O servidor não inventa alimentos nem presume dieta por nome, aparência ou classe.

**Limites atuais:** o sistema usa taxas ecológicas declaradas e competição proporcional, não simula ainda animação de alimentação, deslocamento até plantas, coleta de carcaças ou predação como fonte de alimento. A persistência continua local ao servidor de desenvolvimento, não é banco distribuído ou nuvem. A consolidação exige que fontes com o mesmo ID mantenham parâmetros físicos idênticos.

## Carcaças persistentes e alimentação necrófaga

- Quando um indivíduo morre por combate ecológico ou mortalidade natural, o servidor registra uma carcaça no próprio indivíduo morto, com espécie de origem, quantidade, posição, horário e taxa de decomposição.
- A quantidade inicial deriva da vida máxima da criatura (50% por padrão). A espécie pode declarar `ecologia.carcaca.unidades` e `ecologia.carcaca.decomposicaoPorDia` para ajustar esses valores.
- Uma espécie só consome carcaças das espécies listadas em `ecologia.especiesNecrófagas`; também precisa declarar `ecologia.consumoCarcacaPorIndividuoDia` maior que zero. Não há dieta presumida.
- A cada ciclo ecológico, o servidor considera apenas carcaças e necrófagos do mesmo ecossistema, aplica decomposição pelo tempo real, distribui a demanda entre as carcaças acessíveis e desconta o consumo do estoque persistido.
- A oferta de carcaça entra no índice alimentar da espécie necrófaga, afetando o simulador populacional junto dos recursos ambientais.
- Se não houver carcaças disponíveis, a disponibilidade dessa fonte alimentar é zero. Carcaças esgotadas não voltam a fornecer alimento.
- O teste automatizado verifica criação na morte, decomposição, competição, persistência e falta de alimento após o esgotamento.

**Limites atuais:** não há animação de alimentação, coleta visual ou migração automática ainda. A carcaça é um recurso ecológico persistido e processado no servidor; a persistência continua local ao servidor de desenvolvimento, não distribuída em nuvem.

## Migração de grupos por escassez alimentar

- Cada espécie pode declarar até 16 destinos alternativos em `ecologia.rotasMigracao`, com ID, ecossistema, bioma, habitat e território (centro e raio).
- O servidor conta ciclos consecutivos com disponibilidade alimentar igual ou inferior a 0,25. Após três ciclos, tenta migrar o grupo inteiro.
- A migração tenta destinos declarados e verifica territórios ocupados no mesmo ecossistema. Se encontrar um residente, os representantes se enfrentam em duelo individual: líder vivo contra líder vivo; se um grupo não tiver líder vivo, seu integrante vivo mais forte assume a representação. O cálculo considera atributos, vida atual e equipamentos cadastrados; o defensor recebe 15% de vantagem defensiva por conhecer o território.
- Se um representante cair, o próximo integrante vivo mais forte daquele grupo pode assumir o duelo. O combate é resolvido pelo servidor com turnos determinísticos e dano persistido, sem exigir relação predador-presa.
- Depois do duelo, todos os integrantes vivos do grupo vencedor recebem +20% de moral (multiplicador individual e do grupo, limitado a 2,0). A moral aumenta o ataque do grupo e reforça a defesa dos integrantes em combates ecológicos posteriores; também influencia o dano no confronto territorial coletivo.
- A IA do grupo derrotado avalia sobreviventes, poder restante, saúde média e moral. Ela pode aceitar a derrota e recuar ou continuar com todos os integrantes vivos em um confronto coletivo. O confronto coletivo resolve ataques por rodadas, registra baixas e atualiza a liderança por sucessão.
- Se o invasor vencer e houver espaço seguro, o residente recua para uma área livre próxima, preservando as posições relativas dos indivíduos, e o migrante ocupa o destino. Se o defensor prevalecer, o migrante permanece onde estava. Se não houver espaço seguro para o recuo, a migração não ocupa o destino.
- Resultado, representantes, turnos do duelo, decisão da IA, rodadas coletivas e bônus de moral ficam registrados nos dois grupos. O histórico mantém até 20 disputas recentes por grupo.
- Todos os indivíduos do grupo migrante mantêm suas posições relativas ao centro antigo, são reposicionados dentro do novo raio e recebem estado de mundo de migração.
- Ecossistema, bioma, habitat, território e histórico de migração são persistidos. O grupo tem intervalo mínimo de 24 horas entre migrações.
- Quando a disponibilidade alimentar se recupera acima do limite de escassez, o contador de ciclos é zerado.
- O teste automatizado verifica os três ciclos, a mudança de habitat, a permanência dos indivíduos dentro do novo território e a persistência após reabrir o repositório.

**Limites atuais:** a escolha percorre a lista de destinos declarada pela espécie e usa o primeiro destino válido e desocupado; ainda não calcula caminhos físicos, perigos do trajeto, distância percorrida ou animação de deslocamento. A transferência de território é uma atualização autoritativa do servidor. A persistência segue local ao servidor de desenvolvimento.


## Personalidade e memória social dos grupos

- Cada grupo recebe uma personalidade estável e reproduzível, com tendências de agressividade, sociabilidade, territorialidade e coragem. São tendências comportamentais, não atributos de combate.
- Grupos começam neutros entre si. Uma disputa territorial registra rivalidade e guarda o resultado, horário e histórico da relação nos dois lados.
- Cooperação precisa ser registrada explicitamente pelo servidor. Interações cooperativas repetidas aumentam confiança e podem estabelecer o estado de aliado; conflitos repetidos aumentam rivalidade.
- Cada relação guarda contagem de interações, última interação e até 20 eventos; o histórico social geral do grupo mantém até 50 eventos.
- O registro de interação valida que ambos os grupos existam e pertençam ao mesmo ecossistema. Nenhuma aliança é presumida por espécie, aparência ou proximidade.
- A API social está pronta para ser chamada por futuros eventos de ajuda, defesa compartilhada e troca de recursos; esses eventos ainda não são simulados automaticamente.
