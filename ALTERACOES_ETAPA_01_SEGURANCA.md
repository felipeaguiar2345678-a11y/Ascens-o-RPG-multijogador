# Etapa 01 — Auditoria de segurança e estrutura

## Estado desta cópia

Esta etapa registra e preserva a base Android recebida, com foco nas regras de propriedade dos personagens e dos dados visuais. Nenhuma chave, segredo, publicação ou implantação foi realizada.

## Verificações concluídas

- O perfil do personagem é salvo em `characters/{profile.id}`.
- O documento do personagem grava `ownerUid` a partir do usuário autenticado no Firebase.
- A consulta do perfil procura documentos pelo `ownerUid` do usuário atual.
- O repositório visual usa `characterVisuals/{characterId}` e verifica a propriedade do personagem antes de gravar ou retornar os dados.
- As regras do Firestore em `firestore.rules` protegem `characters` e `characterVisuals` verificando o UID autenticado.
- A regra de criação/atualização de `characterVisuals` exige que o campo `characterId` corresponda ao ID do documento e que o personagem correspondente pertença ao mesmo UID.

## Limites identificados

- A geração visual ainda não está conectada: `UnavailableCharacterVisualGenerationService` retorna falha intencionalmente.
- A tela de criação salva o personagem, mas ainda não inicia a geração visual.
- O Worker Cloudflare existente no GitHub ainda não foi alterado nesta etapa.
- Esta cópia não contém `app/google-services.json` nem credenciais. Isso é intencional; não incluir segredos no ZIP.
- Não foi possível executar a compilação Android neste ambiente: o ZIP recebido não contém `gradlew` e não há Gradle instalado. Portanto, esta etapa é uma auditoria estática, não uma certificação de build.

## Próxima etapa

Conectar o fluxo Android ao endpoint seguro de geração visual, sem expor a chave OpenAI no aplicativo, validar a propriedade no servidor, reservar o orçamento da categoria `characters` antes da chamada paga e salvar a imagem no R2. Nenhuma chamada paga será feita durante o desenvolvimento do código.
