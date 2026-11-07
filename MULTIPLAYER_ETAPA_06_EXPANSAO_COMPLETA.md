# Etapa 06 — Expansão do Multiplayer

## Sistemas adicionados

### 1. Masmorras cooperativas
- Expedições de até quatro jogadores por código de convite.
- Três dificuldades: Normal, Difícil e Abismo.
- Cinco salas por expedição.
- As criaturas das salas são escolhidas do catálogo global `criaturas`; não foi criada uma nova lista manual de inimigos.
- Formação escolhida pelo líder antes de iniciar: Balanceada, Agressiva ou Defensiva.
- Funções automáticas de equipe: Atacante, Mago e Guardião, inferidas pelos atributos do personagem.
- Ações de ataque, magia, defesa, combo e reanimação de aliado.
- Recompensas individuais validadas no servidor: XP, Fragmentos de Masmorra e pontuação de temporada.

### 2. Chefes mundiais por ecossistema
- Um encontro por ecossistema e temporada mensal.
- O chefe é selecionado entre criaturas já cadastradas com `chefe = true` e `ecosystemId` correspondente.
- Até 50 jogadores podem participar do mesmo encontro.
- Dano e contribuição são calculados no servidor; recompensa só é liberada a quem participou e causou dano.
- Recompensa: XP, Essência de Chefe Regional, pontos de temporada e pontuação global de dano.

### 3. Arena PvP opcional
- O jogador entra voluntariamente na fila.
- Pareamento por rating, com diferença máxima inicial de 250 pontos; rating inicial 1000, +25 por vitória e -20 por derrota.
- Partidas por turnos, com ataque e defesa calculados no servidor.
- Vitória e derrota atualizam rating e ranking; nenhum jogador é forçado a PvP.

### 4. Acampamento compartilhado da guilda
- Cada guilda possui um acampamento comum, com nível e progresso próprios.
- Concluir uma masmorra contribui 10 pontos; derrotar um chefe regional contribui 20 pontos.
- O acampamento sobe de nível automaticamente ao atingir a contribuição necessária.
- Cada nível concede +2% de XP aos membros (limitado a +20%).
- O painel da guilda mostra nível, progresso e bônus atual.

### 5. Rankings globais
- Nível.
- Conclusões de masmorras.
- Dano causado a chefes regionais.
- Vitórias na arena.
- Tamanho atual das guildas.
- Consulta dos 20 primeiros colocados por categoria.

### 6. Eventos sazonais
- Temporada mensal identificada por ano e mês.
- Objetivo individual: 3 pontos, obtidos ao concluir masmorras e reivindicar recompensas de chefes.
- Objetivo global acumulado no documento da temporada.
- Recompensa única por conta: 250 XP e uma Insígnia; se a meta global for alcançada, 500 XP e duas Insígnias.

### 7. Cooperação avançada no Ally
- Funções de equipe inferidas a partir dos atributos do combatente.
- Combo Ally com bônus de dano de acordo com a diversidade de funções vivas.
- Reanimação de aliado caído durante o combate compartilhado.
- A interface identifica as funções dos integrantes.

## Segurança e consistência
- Masmorras, chefes mundiais, arena, rankings e recompensas sazonais são executados por `multiplayerExpandido` em Cloud Functions.
- Resultados desses novos modos, contribuições, pontuações e recompensas não podem ser gravados pelo cliente.
- Os combates Ally existentes continuam usando a transação Firestore já presente no projeto; o combo e a reanimação foram integrados a esse fluxo e ainda precisam de uma futura migração para cálculo integral no servidor antes de produção competitiva.
- **Atenção antitrapaça:** as regras atuais de `characters` ainda permitem que o próprio cliente atualize o documento completo do personagem. Portanto, embora os novos modos calculem dano e recompensas no servidor, atributos e nível ainda não são uma fonte totalmente confiável contra clientes modificados. Antes de abrir Arena PvP ou rankings competitivos ao público, será necessário migrar progressão/atributos para gravações autorizadas pelo servidor e restringir essas alterações nas regras sem quebrar o salvamento normal do jogo.
- As regras do Firestore permitem somente as leituras necessárias; gravações das novas coleções ficam bloqueadas para clientes.
- XP respeita a progressão atual: cada nível exige `nível atual × 100` XP e concede 5 pontos de atributo.
- Materiais são inseridos no inventário existente; não são criados campos de inventário incompatíveis.
- Guildas permanecem separadas de Ally e de campanhas.

## Item pendente de decisão: mercado público de jogadores

A troca direta da Etapa 04 continua disponível. O mercado público (anúncios para qualquer jogador) ainda não foi criado porque o projeto não possui saldo de ouro implementado. Para não inventar uma economia que afete inventário, recompensas e a futura penalidade de morte, preciso confirmar se o mercado deve usar ouro ou funcionar por escambo de itens.

## Observações antes de produção
- Não foi ativado o plano Blaze, não houve implantação de Cloud Functions nem de regras Firestore. A autorização anterior para usar Cloud Functions não foi tratada como autorização para ativar cobrança.
- Não foi executada compilação do APK nem publicação.
- A instalação das dependências TypeScript não terminou neste ambiente; a sintaxe do arquivo TypeScript foi verificada sem diagnósticos, mas a checagem de tipos completa ainda depende de `npm install` e `npm run build` no ambiente de desenvolvimento.
- Antes de publicar, testar com duas ou mais contas: convites, concorrência de entrada, expedições completas e derrotadas, chefe regional com participantes simultâneos, pareamento e desistência de arena, recompensas repetidas e mudança de temporada.
- Para chefes mundiais e masmorras aparecerem, o catálogo Firestore precisa conter criaturas geradas com `ecosystemId` correspondente; para encontros de chefe, precisa existir pelo menos uma criatura com `chefe = true` nesse ecossistema.
- A lista de IDs de ecossistema no painel inclui exemplos já usados pelo diretor de mundo (`dark_forest`, `forgotten_ruins`, `abyss_valley`, `dead_lands`) e aceita outros IDs válidos cadastrados no catálogo.
