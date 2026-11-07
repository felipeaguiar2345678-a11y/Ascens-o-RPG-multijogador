# Etapa 04 — Imagens oficiais das criaturas

## Implementado
- Novo `CreatureImageApi.kt`: solicitação autenticada ao Worker; chave OpenAI não fica no APK.
- Novo `cloudflare/creature-image-route.js`: confirma existência e propriedade da criatura, gera arte e grava PNG no R2.
- `RepositorioCriaturas.kt`: grava metadados em subcoleção imutável e carrega a última arte registrada.
- `firestore.rules`: leitura autenticada e criação restrita dos metadados; documento principal da criatura permanece imutável.
- Prompt de arte em pixel art detalhada, criatura inteira, fundo transparente, 1024×1024, qualidade média.

## Orçamento
- Modelo `gpt-image-2`; 1024×1024; qualidade `medium`.
- Estimativa de referência para 1024×1024/medium: cerca de US$ 0,053 por imagem; com o câmbio interno de R$ 9,00/US$, cerca de R$ 0,48. O custo efetivo é calculado pelos tokens retornados pela API: texto de entrada US$ 2,50/M, imagem de entrada US$ 4/M e imagem de saída US$ 15/M.
- Reserva máxima de segurança por tentativa: R$ 5,00 em `other_ai`; o Worker liquida o valor calculado pelo uso retornado pela API e libera a diferença.
- Limite mensal `other_ai` continua R$ 48,00; teto teórico de 80 reservas se nenhum outro sistema consumir essa categoria.
- Tentativas com falha/timeout também são contabilizadas, pois não é possível confirmar que o provedor não processou a solicitação interrompida.
- Nenhuma chamada paga foi feita.

## Pendente
- `worker.js` na branch `feature/ai-budget-categories` já importa e despacha as rotas de imagem. Essa branch ainda não foi publicada: o workflow de deploy aceita somente `main`.
- O primeiro registro global dispara a geração automática somente para o jogador que criou o registro. Registros já existentes não disparam uma nova geração. Se a chamada falhar, a criatura permanece registrada e o método `gerarImagemOficialSeAusente` permite nova tentativa sem duplicar arte já salva.
- As regras foram revisadas estaticamente para personagens, campanhas, criaturas, imagens e bestiário; ainda precisam de teste no Firebase Emulator. O ZIP não contém `firebase.json` nem configuração do Emulator.
- Build Android não executado: não há `gradlew` nem Gradle instalado neste ambiente.
