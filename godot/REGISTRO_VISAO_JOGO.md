# Registro da visão de Ascensão do Soberano

Este documento preserva as decisões de design já estabelecidas. **Registrar uma ideia não significa que ela esteja implementada.** O estado de cada sistema deve ser atualizado somente após código e testes verificáveis.

## Regras fundamentais

- RPG online persistente, com interface e textos visíveis em português.
- Exploração livre: nenhuma missão, tutorial, guilda ou linha principal é obrigatória.
- Missões podem ser oferecidas, recusadas, adiadas ou abandonadas quando o sistema permitir; elas enriquecem o mundo, mas não bloqueiam a exploração.
- O multiplayer de grupo é uma experiência visual compartilhada, com cenário, avatares dos participantes, estados visuais e encontros/combates apresentados na mesma cena.
- A aventura cooperativa não usa mapa espacial nem deslocamento livre por mapa; narrativa, escolhas e conversa em texto complementam a apresentação visual, sem substituir o RPG visual.
- A exploração espacial do mundo solo continua em sua própria experiência.
- Não contratar hospedagem, APIs de IA, geração paga de imagens, funções em nuvem ou serviços pagos sem aprovação explícita do usuário.
- APK é a última etapa, depois de validação, servidor e testes reais.

## Mundo e narrativa

- Aurelia é a cidade principal e referência inicial do mundo.
- Novos personagens começam na Clareira Inicial, na borda sul da Floresta Arcana, com Aurelia visível ao longe.
- Ecossistemas/regiões planejados: Montanhas Geladas, Floresta Arcana, Império, Central, Sombras, Deserto Ancestral e Mar Eterno. Cidades como Aurelia e Malachar podem constituir ecossistemas próprios, sem limitar o mundo a quatro regiões fixas.
- A abertura apresenta o mundo, criaturas, aldeias ameaçadas, Aurelia e a Grande Serpente, mas não força o jogador a aceitar uma missão.
- NPCs podem oferecer ajuda, esconder informações, negociar, mentir e reagir às escolhas.
- O mundo deve continuar explorável mesmo quando o jogador ignora missões.

## Personagem e progressão

- Atributos: força, inteligência, agilidade, vitalidade e espírito.
- Valores-base inicialmente definidos em 5; ao subir de nível, o personagem recebe 5 pontos para distribuir.
- Experiência necessária para o próximo nível: nível atual × 100.
- Classes representam afinidades e especializações, não bloqueios absolutos de habilidades.
- Raça, aparência, anatomia e equipamentos devem refletir a identidade escolhida.
- Derrota: retornar ao último ponto de ressurgimento, restaurar completamente vida e mana, perder 50% da experiência acumulada total e 20% do ouro. A semântica exata do saldo de XP deve ser confirmada antes de implementar a perda.
- Equipamento: espada de uma mão sozinha ou com escudo; arma de duas mãos ocupa ambas as mãos; arma pesada ocupa o espaço do escudo. No máximo um anel e um colar. Escudo restrito às classes de combate corpo a corpo.
- Um companheiro ativo por vez; o seguidor usa deslocamento relativo e velocidade superior à do jogador.

## Criaturas, IA e chefes

- A IA deve criar criaturas do zero, não depender de um banco de inimigos artesanais como fonte principal.
- Depois da geração, criaturas válidas são registradas no catálogo global para descoberta e reutilização.
- Dados previstos: identificador, nome, descrição, rank E–SSS, nível, vida, ataque, defesa, mana, agilidade, poder mágico, experiência-base, perigo, bioma, habitat, habilidades, chefe, versão e referências visuais.
- Geração deve respeitar ecossistema, identidade regional, raridade, rank, habitat e condições de aparição.
- Cada região pode ter mais de um chefe regional, com condições próprias de aparição.
- Habilidades podem ser originais e variadas; não limitar a IA a uma lista pequena de habilidades predefinidas.
- Catálogo global: total de derrotas, primeiro descobridor, primeiro derrotador, data da descoberta, maior dano, jogador com mais derrotas e total de jogadores que encontraram a criatura.
- Raridades devem cobrir todos os níveis definidos, não apenas comum.
- Combate considera ações da IA (atacar, defender, especial, recuar), ranks E–SSS e eventos de dado natural 1/20, com balanceamento.

## Drops, companheiros e economia

- Drops automáticos após derrotas confirmadas.
- Em grupo, experiência dividida igualmente; itens/ovos destinados ao participante que causou maior dano, conforme regra definida para cada recompensa.
- Chance-base de ovos por rank: E 5%, D 4%, C 3%, B/A 2%, S/SS/SSS 1%.
- Companheiros obtidos de ovos preservam a aparência da criatura de origem.
- Materiais possíveis incluem pele, carne e dentes; raridade acompanha a força/raridade da criatura.
- Roleta visual mostra falha (X) ou sucesso (✓), mas o servidor calcula a chance e o resultado antes da animação. A animação nunca altera o sorteio.
- Moedas: Bronzhar (bronze, ⛨), Ferrak (ferro, ⚒), Auréon (ouro, ☼), Diamyr (diamante, ◈), Jaderys (jade, ❖) e Ankhar (moeda ancestral especial, ⟁). Ankhar fica fora da conversão comum entre moedas.

## Mundo vivo e fenômenos celestes

- Relógio compacto deve mostrar horário e período do mundo.
- Eventos noturnos: lua cheia, eclipse e lua de sangue.
- Fenômenos celestes afetam aparição, força, comportamento e recompensas das criaturas.
- O tempo e os eventos relevantes devem ser compartilhados entre participantes do multiplayer.

## Multiplayer visual cooperativo

- A tela compartilhada deve mostrar cenário ilustrado, personagens reais do grupo com aparência/equipamentos, informações de vida e mana e área visual para encontros e combates.
- Não usar mapa espacial nem deslocamento livre no modo de grupo; a cena é compartilhada e guiada por acontecimentos, decisões e encontros.
- O diário registra acontecimentos e a conversa fica recolhida/ secundária, sem dominar a tela.
- Dados visuais públicos de cada participante são enviados pelo servidor a partir do perfil autenticado; nunca aceitar aparência, nível, vida ou mana como dados de autoridade enviados pelo cliente.


- Fluxo de grupo: criar sala e compartilhar código; ou entrar usando código.
- A aventura compartilhada começa quando há pelo menos dois jogadores, embora uma sala possa guardar estado antes disso.
- Tela compartilhada apresenta participantes, registro narrativo e ações em texto; não deve introduzir mapa espacial.
- Ações e progresso precisam ser validados pelo servidor. Nunca confiar em UID, progresso, derrotas ou recompensas enviados livremente pelo cliente.
- Missões cooperativas, encontros, combate visual compartilhado, progresso e recompensas devem ser sincronizados e persistidos por sala.
- Mensagens de uma sala não podem vazar para outra.

## Estado técnico registrado em 24/11/2026

### Implementado no repositório (ainda sujeito à validação automatizada e testes reais)

- Projeto migrado para Godot 4.7.2.
- Login Firebase por e-mail/senha e validação da sessão no servidor.
- Servidor ENet dedicado e empacotamento Docker preparados; hospedagem ainda não escolhida.
- Mundo solo com cena própria.
- Salas de até quatro jogadores, códigos de convite e persistência em arquivo do servidor.
- Cena cooperativa com cenário procedural animado, avatares pixelados dos participantes, barras de vida/mana, diário secundário e apresentação visual de encontro sincronizado; arte ainda provisória.
- Estrutura de encontro cooperativo persistida por sala: o servidor inicia a apresentação somente com dois ou mais membros ativos e usando criatura existente no catálogo confiável; o snapshot inclui identidade, rank, nível, vida e referências de arte.
- Motor inicial de combate cooperativo com turnos compartilhados, ações básicas (atacar, defender e esquivar), dano calculado no servidor, vida individual e condição de vitória/derrota; ações limitadas ao participante do turno.
- Identificadores UID permanecem no estado interno do servidor e são removidos dos snapshots enviados aos clientes; cada cliente recebe somente um indicador booleano de seu próprio turno.
- Sincronização de dados visuais públicos dos personagens do grupo (aparência, raça, equipamentos, nível, vida e mana), sem expor UID ou credenciais.
- Mensagens de sala com validação de membro/UID no servidor, limite de 300 caracteres, intervalo mínimo entre envios, histórico limitado a 100 mensagens e persistência.
- Participantes de sala são mantidos fora da simulação espacial solo.

### Regra de sobrevivência e recompensa no combate cooperativo (base implementada)

- A queda de um integrante não encerra o combate; o turno passa ao próximo participante vivo.
- O combate só termina em derrota quando não resta nenhum participante vivo.
- Se a equipe vencer, todos os integrantes registrados no encontro ficam marcados como elegíveis às recompensas, inclusive quem foi derrotado durante a luta.
- O motor contabiliza o dano causado por cada integrante e identifica no servidor quem causou mais dano, preservando a regra de distribuição de itens/ovos ao maior causador de dano. Esse identificador interno não é exposto aos clientes.
- Durante o combate cooperativo, o painel visual apresenta o ranking de dano de todos os participantes, com dano total e porcentagem de contribuição; participantes derrotados continuam visíveis e identificados como derrotados.
- Abaixo das informações de vida da criatura, a interface mostra uma prévia dos drops catalogados, com nome e raridade. A prévia é informativa: não revela nem altera as chances ou o resultado da rolagem do servidor.
- Integrantes derrotados recebem 1 HP no estado de retorno após a vitória; sobreviventes mantêm a vida restante.
- Se toda a equipe cair, o resultado marca retorno ao ponto de renascimento.
- Se um integrante desconectar durante o combate, ele permanece registrado com seu dano e elegibilidade potencial; se era seu turno, o motor avança para o próximo integrante vivo e conectado. Ao retornar à mesma sala, sua participação é reativada. Se não houver nenhum integrante vivo e conectado, mas ainda existir alguém vivo, o combate aguarda uma reconexão sem declarar derrota automática; derrota só ocorre quando todos os participantes estiverem realmente sem vida.
- A elegibilidade e o estado de retorno são calculados pelo motor do servidor, não pelo cliente.

### Atualização visual de combate registrada em 24/11/2026

- Painel de combate cooperativo com identificação da criatura, barra de vida e ranking de dano em tempo real para todos os integrantes, incluindo os derrotados.
- O ranking mostra posição, dano acumulado e percentual relativo ao dano total do grupo.
- A lista de recompensas possíveis é montada a partir da tabela confiável da criatura e inclui a entrada de ovo quando aplicável. A prévia também inclui a recompensa monetária derivada do rank, nível e perigo da criatura.
- A interface mostra somente nome, categoria e raridade da prévia; chance e resultado continuam sob controle exclusivo do servidor.
- Teste de sala ampliado para verificar a publicação da prévia de drops.

### Em desenvolvimento ou ainda não concluído

- Catálogo e geração real de criaturas por IA, sem API paga não aprovada.
- Catálogo completo de missões cooperativas e fluxo de objetivos.
- Combate cooperativo completo ainda em desenvolvimento: queda individual, elegibilidade, entrega idempotente de XP/itens, HP final e retorno persistido após derrota total já possuem integração inicial. Ainda falta ligar os pontos seguros reais do mundo ao método de atualização do último ponto de renascimento; a rotina de retorno usa o último ponto que o servidor tiver registrado (por enquanto, a Clareira Inicial como padrão). Também faltam habilidades, IA avançada, fuga e efeitos de estado.
- Recompensas cooperativas, roleta, ovos e distribuição final.
- Gatilhos reais do mundo para iniciar encontros cooperativos ainda precisam ser conectados ao método autoritativo; o início ainda depende de chamada interna do servidor.
- Arte final do combate e animações de ataque/defesa/esquiva; a apresentação atual é uma base procedural.
- Arte final original para cenários, personagens e criaturas; o cenário procedural atual é apenas uma base visual temporária.
- Missões cooperativas registradas no catálogo do servidor e fluxo completo de objetivos/recompensas.
- Arte final das criaturas no palco cooperativo; a silhueta atual é apenas um indicador visual temporário.
- Testes de integração em dois celulares e reinício real do servidor.
- Escolha e configuração de hospedagem UDP.
- Arte final, animações, áudio e polimento visual.
- Exportação e teste do APK.

## Política de atualização

Ao concluir cada sistema, registrar aqui:
1. Arquivos e sistemas alterados.
2. O que realmente funciona.
3. Testes automatizados executados e resultado.
4. O que ainda depende de teste em dispositivo ou servidor real.

Nunca marcar uma ideia como concluída apenas porque existe uma tela, uma estrutura de dados ou um protótipo.


## Recompensas idempotentes de combate cooperativo
- O repositório de personagens possui a operação `conceder_recompensa_encontro`, que aplica XP, drops, moedas e recursos finais em uma gravação do perfil e registra o identificador do encontro para impedir pagamento duplicado ao mesmo personagem.
- O fluxo de vitória do servidor agora chama a operação: XP-base é dividido igualmente entre todos os participantes registrados, inclusive derrotados/desconectados; os drops obtidos (incluindo moeda e ovo) são atribuídos ao maior causador de dano. O HP final é salvo para todos: quem caiu retorna com 1 HP e sobreviventes mantêm a vida restante. O ID do encontro é único por sala/execução e o recibo por perfil permite retomar uma concessão parcial sem duplicar quem já recebeu. Ao reconectar, o servidor tenta liquidar vitórias pendentes antes de publicar o perfil atualizado.

- A derrota total aplica, por participante e com recibo idempotente, perda de 50% da experiência acumulada e de 20% do valor total das moedas comuns (Bronzhar, Ferrak, Auréon, Diamyr e Jaderys); Ankhar permanece fora da conversão. HP e Mana são restaurados integralmente. O perfil também volta ao último ponto de renascimento persistido pelo servidor.

### Sincronização visual após recompensas cooperativas
Após a concessão idempotente de recompensas, o servidor republica os cartões dos participantes da sala usando os perfis já persistidos. Assim, o HP de quem foi derrotado (1 ponto após vitória) e os recursos restantes dos sobreviventes aparecem na tela compartilhada sem depender de uma nova entrada na sala. A localização da sala para essa publicação procura qualquer integrante ainda conectado, sem depender de o primeiro participante da lista (ou líder original) permanecer online. Isso não substitui a integração ainda pendente do retorno do grupo após derrota total nem define as penalidades de XP/moedas.

## Atualização multiplayer — retorno da vitória e derrota total

- A vitória cooperativa agora identifica o destino como `aventura_compartilhada`, mantendo a equipe no palco visual compartilhado, sem encaminhamento para um mapa espacial.
- A tela da aventura apresenta mensagens distintas para vitória e derrota. Na vitória, informa que as recompensas foram processadas; na derrota total, informa o estado da restauração dos recursos.
- Quando todos os participantes são derrotados, o servidor restaura HP e Mana de todos os perfis, inclusive dos participantes desconectados, usando os atributos efetivos do equipamento.
- A penalidade e seu recibo idempotente são salvos juntos no perfil. A restauração de HP/Mana é realizada em seguida. A restauração é marcada no estado persistente da sala somente após concluir as gravações individuais; se o processo falhar ou o servidor reiniciar antes do marcador, a penalidade não será aplicada novamente e a restauração poderá ser repetida.
- A regra de perda de 50% da experiência e 20% das moedas ainda não foi aplicada. O perfil armazena experiência acumulada em um campo único e seis denominações de moedas; a regra de penalidade precisa ser integrada com validação específica e sem presumir equivalência entre moedas.
- O ponto de renascimento persistido ainda precisa ser integrado ao fluxo cooperativo; esta atualização restaura recursos, mas não declara concluído o retorno espacial ao ponto de renascimento.
- A validação automatizada e o teste real entre dois dispositivos continuam pendentes.


### Ponto de renascimento persistido — atualização de 24/11/2026

- Perfis novos recebem `pontoRenascimentoId = clareira_inicial` e coordenadas iniciais da Clareira Inicial (1190, 1520).
- O repositório agora oferece `atualizar_ponto_renascimento`, operação interna do servidor para registrar um ponto seguro somente depois que o mundo validar o checkpoint. Ela persiste identificador e coordenadas, e atualiza também a localização atual do personagem.
- Ao processar uma derrota cooperativa total, o perfil restaura `pontoMundoId`, `x` e `y` a partir do último ponto de renascimento persistido, além das penalidades e da restauração de HP/Mana.
- O teste de derrota foi ampliado para verificar o padrão inicial, registrar um checkpoint diferente, deslocar a posição atual e confirmar o retorno ao checkpoint após a derrota.
- Limitação ainda aberta: não foi localizado/ligado nesta etapa um gatilho real de checkpoint no mundo solo. Até essa integração existir, o último ponto salvo permanece a Clareira Inicial ou o último ponto gravado por uma chamada validada do servidor. O multiplayer cooperativo continua sem mapa espacial.


### Integração de pontos seguros e recuperação após reinício — 24/11/2026

- A visita a locais é confirmada usando a posição já validada pelo servidor. Clareira Inicial, fogueira e abrigos de viajante, vigia e materiais foram explicitamente marcados como pontos seguros.
- Ao entrar em um desses locais, o servidor persiste o identificador e as coordenadas canônicas do ponto no perfil; o cliente não escolhe nem envia livremente o ponto de renascimento.
- Após reinício do servidor, encontros cooperativos que ainda estavam em andamento marcam todos os participantes como desconectados, removem o turno pendente e aguardam uma reconexão autenticada. O primeiro integrante vivo que retornar reassume o turno; os demais podem retornar depois.
- O motor cooperativo centraliza a divisão de XP (com resto distribuído de forma determinística) e a identificação do único destinatário dos drops, o integrante de maior dano.
- Novos testes automatizados cobrem limite de quatro jogadores, sala persistida, reinício com combate ativo, reconexão, divisão de XP, distribuição de drops e recibos idempotentes.
