# Etapa 02 — Integração de geração visual de personagens

## Implementado nesta cópia

### Android
- Adicionado `CloudflareCharacterVisualGenerationService.kt`, que envia a solicitação ao Worker usando o Firebase ID token atual.
- A chave OpenAI não é incluída no APK nem enviada pelo aplicativo.
- Adicionado `CharacterVisualGenerationRunner.kt` para registrar o estado da geração, chamar o serviço e salvar o caminho/URL no perfil.
- A geração automática é chamada somente depois que o personagem novo é salvo.
- O login normal não dispara geração novamente.
- A tela de personagem agora exibe a imagem gerada, o estado de processamento e um botão de nova tentativa quando não há imagem.
- A geração concluída é reaproveitada pelo repositório visual.

### Cloudflare
- Adicionado `cloudflare/character-visual-route.js` com handlers para gerar e servir imagens de personagens.
- O handler exige Firebase Auth, consulta o documento do personagem com o token do jogador e confirma `ownerUid` antes de reservar orçamento.
- Reserva R$ 0,60 na categoria `characters` antes da chamada de imagem. O limite existente dessa categoria é R$ 2,00/mês.
- Usa `gpt-image-2`, tamanho 1024x1024, qualidade média e PNG transparente.
- Salva a imagem no R2 em um caminho separado por UID/personagem/geração.
- A rota de leitura publica apenas o arquivo de arte, sem expor a ficha do personagem.
- Adicionados `cloudflare/wrangler.toml` e `cloudflare/package.json` como cópias da configuração já existente no Worker.

## Integração pendente no Worker que já está no GitHub

O ZIP recebido originalmente não continha `cloudflare/worker.js`; esse arquivo continua no GitHub e não foi alterado. Para evitar sobrescrever as rotas de criaturas e orçamento, a extensão foi mantida em arquivo separado. O arquivo `cloudflare/INTEGRAR_GERACAO_VISUAL_NO_WORKER.md` contém os dois trechos exatos para importar o módulo e registrar as rotas no Worker existente.

## Orçamento e cobrança

- Nenhuma chamada à OpenAI foi executada durante a preparação.
- Nenhuma imagem foi gerada ou cobrada.
- Cada tentativa reserva R$ 0,60. O controle de orçamento bloqueia novas reservas quando não há saldo disponível.
- Como o fluxo da Images API usado aqui não fornece um valor monetário final confiável por imagem, a reserva inteira é contabilizada de forma conservadora. Com R$ 2,00/mês, cabem no máximo três reservas de R$ 0,60 (R$ 1,80), deixando R$ 0,20 sem comprometer.
- O valor real pode variar com câmbio, impostos e alterações de preço. A reserva é proteção interna do jogo, não uma garantia do valor faturado pela OpenAI.

## Testes e limitações

- `node --check cloudflare/character-visual-route.js`: aprovado.
- Testes locais de rota de imagem e validação de requisição: executados separadamente durante a preparação.
- Não foi possível compilar o Android: o projeto recebido não contém `gradlew` e não há Gradle instalado neste ambiente. O Kotlin compiler isolado não substitui uma compilação Android/Compose com dependências Firebase.
- A integração só ficará ativa depois de mesclar os dois trechos documentados em `cloudflare/worker.js` e publicar o Worker. Isso não foi feito nem será feito automaticamente.
