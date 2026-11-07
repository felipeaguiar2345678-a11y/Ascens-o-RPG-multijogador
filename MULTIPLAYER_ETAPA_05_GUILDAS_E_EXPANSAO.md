# Etapa 05 — Guildas e expansão do multiplayer

## Implementado nesta etapa

- Guildas permanentes, separadas de Ally e de campanhas.
- Criação de guilda com nome de 3 a 24 caracteres e código de convite de 6 caracteres.
- Entrada por código, limite inicial de 30 membros e exibição de membros.
- Saída segura; se o líder sair, a liderança passa ao membro mais antigo da lista. Se o último membro sair, a guilda é encerrada.
- Escritas de guildas e associações são exclusivas da Cloud Function `gerenciarGuilda`.
- Interface de guildas integrada à aba Multiplayer.

## Próximos módulos multiplayer a integrar

1. Masmorras cooperativas: salas de expedição, níveis de dificuldade, progressão por salas e recompensa por participação.
2. Chefes mundiais: encontros públicos por região, limite de participantes, contribuição de dano e recompensa individual validada no servidor.
3. Arena PvP opcional: fila por faixa de poder, partidas com consentimento, temporadas e proteção contra manipulação de resultados.
4. Rankings: níveis, chefes derrotados, contribuição em guildas, arena e descobertas; dados de classificação escritos apenas pelo servidor.
5. Eventos sazonais: calendário de eventos, objetivos globais e recompensas limitadas por conta.
6. Habilidades combinadas de Ally, funções de equipe, reviver aliados e formações.

Esses módulos ainda não são apresentados como funcionais nesta etapa: precisam do motor de batalha/resultado autoritativo no servidor, das regras de participação e da integração com inventário/recompensas. Não criar rankings nem recompensas graváveis pelo cliente, para evitar trapaças.

## Segurança, custos e testes

- A Cloud Function `gerenciarGuilda` usa transações Firestore para impedir que uma conta entre em duas guildas simultaneamente.
- O cliente só pode ler a guilda da qual é membro; não pode criar, editar ou excluir documentos de guilda diretamente.
- Não foram implantadas funções nem regras, não foi ativado o plano Blaze e não houve cobrança.
- APK e TypeScript não foram compilados nesta etapa, conforme a decisão de integrar os sistemas antes da compilação geral.
- Antes de produção, testar criação simultânea, códigos inválidos, guilda cheia, saída do líder e concorrência de entradas com duas ou mais contas no emulador Firebase.
