# Publicação das Firebase Functions

O backend das funções callable do multiplayer fica em `functions/src/index.ts`.
O projeto Firebase configurado pelo Worker é `ascensao-do-soberano`, região `southamerica-east1`.

## Preparação única do GitHub Actions

1. No Google Cloud Console, selecione o projeto `ascensao-do-soberano`.
2. Crie ou use uma conta de serviço dedicada para publicação.
3. Conceda à conta permissões para implantar Cloud Functions de 2ª geração e acessar o projeto (Cloud Functions Admin, Service Account User, Cloud Build Editor e Firebase Admin, conforme as políticas do projeto).
4. Gere uma chave JSON dessa conta de serviço.
5. No GitHub, abra Settings > Secrets and variables > Actions > New repository secret.
6. Crie o secret com o nome exato `FIREBASE_SERVICE_ACCOUNT` e cole o JSON inteiro como valor.
7. Depois de salvar, abra Actions > Publicar Firebase Functions e execute Run workflow na branch `ia-historia-mundos`.

Não publique a chave no código, em Issues ou em mensagens. A chave deve existir somente como secret do GitHub.

## O que a publicação entrega

- `gerenciarTroca`
- `gerenciarGuilda`
- `multiplayerExpandido`

As funções são compiladas antes do deploy. A região é definida no código como `southamerica-east1`.

A publicação pode exigir que o projeto Firebase esteja no plano Blaze e que as APIs necessárias do Google Cloud estejam habilitadas. Custos de infraestrutura do Firebase/Google Cloud são separados do orçamento de chamadas de IA; confira o faturamento antes de habilitar serviços pagos.
