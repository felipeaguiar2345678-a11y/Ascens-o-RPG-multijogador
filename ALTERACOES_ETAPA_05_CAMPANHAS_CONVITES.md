# Etapa 05 — Correção dos convites de campanha

## Problema identificado

O aplicativo antigo criava somente o documento em `campaigns/{id}` e guardava o código dentro dele. Para entrar, fazia uma consulta por `inviteCode` na coleção `campaigns`. As regras de segurança bloqueiam listagens dessa coleção para jogadores que ainda não são membros, então o fluxo não podia funcionar com segurança.

## Alterações realizadas

- A criação agora grava `campaigns/{id}` e `campaignInvites/{codigo}` no mesmo lote atômico.
- A entrada consulta diretamente `campaignInvites/{codigo}`, sem listar campanhas.
- Antes de adicionar o jogador, o aplicativo grava um comprovante em `campaignInvites/{codigo}/joins/{uid}` e atualiza `members` no mesmo lote atômico.
- As regras exigem que o convite esteja ativo, corresponda à campanha e que o comprovante e a inclusão do jogador aconteçam na mesma operação.
- A listagem de campanhas e convites permanece bloqueada.
- Um membro não pode alterar o proprietário, o código, o nome ou a visibilidade da campanha. O proprietário só pode editar nome e visibilidade.

## Campos gravados

`campaigns/{id}`:
- `ownerUid`
- `inviteCode`
- `name`
- `visibility`
- `members`
- `createdAt`

`campaignInvites/{codigo}`:
- `campaignId`
- `inviteCode`
- `ownerUid`
- `active`
- `createdAt`

`campaignInvites/{codigo}/joins/{uid}`:
- `userUid`
- `campaignId`
- `inviteCode`
- `joinedAt`

## Validação pendente

O código e as regras foram atualizados no ZIP, mas ainda precisam ser testados no emulador Firestore e compilados pelo fluxo Android do repositório. Não publicar as regras no Firebase de produção antes desses testes.

## Escopo

Esta etapa corrige somente convites de **campanhas**. Ela não implementa nem altera o sistema cooperativo **Ally** (grupo de até 4 jogadores), que continua sendo um recurso separado.
