# Alterações desta versão

## Segurança dos dados visuais
- Adicionada regra `characterVisuals/{characterId}` em `firestore.rules`.
- A leitura exige que o documento pertença ao jogador autenticado.
- A criação e atualização exigem que o personagem correspondente exista e pertença ao jogador autenticado.
- A exclusão também é restrita ao proprietário.

## Repositório Kotlin
- `CharacterAIGenerationRepository.save()` confirma a propriedade do personagem antes de gravar os dados visuais.
- `CharacterAIGenerationRepository.get()` verifica o usuário autenticado e o `ownerUid` do documento antes de devolver os dados.

## Pré-visualização
- `CharacterAppearancePreview.kt` agora carrega `generatedImageUrl` usando Coil (`AsyncImage`), já presente nas dependências do aplicativo.
- Enquanto não houver imagem gerada, mantém a prévia textual da aparência escolhida.

## Ainda não conectado
- A geração real por IA continua desativada. O ZIP recebido não contém o código do Cloudflare Worker nem um contrato de endpoint para geração de personagem.
- Nenhuma chamada paga foi feita e nenhuma chave de API foi adicionada ao aplicativo.
- As regras do Firestore precisam ser publicadas no Firebase Console depois que este projeto for enviado ao GitHub.

## Validação
- Arquivos alterados revisados estaticamente.
- Não foi possível executar uma compilação Gradle neste ambiente porque o projeto não inclui o Gradle Wrapper e o comando `gradle` não está instalado.
