# Etapa 04 — Integração das imagens oficiais de criaturas

## Rotas reais do Worker

- `POST /api/creatures/image` — recebe `{ "creatureId": "..." }`, valida o token Firebase e confirma o primeiro registrador da criatura.
- `GET /api/creatures/image/{criaturaId}` — entrega o PNG armazenado no R2.

O `worker.js` da branch `feature/ai-budget-categories` já importa `creature-image-route.js` e despacha essas duas rotas. Não adicione uma segunda rota nem use `/api/creatures/image/generate`: esse caminho não é o contrato atual.

## Fluxo Android

1. `CreatureApi` gera e registra a criatura globalmente.
2. `RepositorioCriaturas.registrarCriaturaGlobal` detecta se o documento acabou de ser criado.
3. Somente a transação que efetivamente cria o documento recebe `criadaAgora = true`; ela chama `gerarImagemOficialSeAusente` para o UID que ficou como `criadoPorUid`. Uma transação concorrente que encontrar o documento já criado não dispara outra geração.
4. O Worker consulta a criatura no Firestore, valida o proprietário, reserva o orçamento, chama `gpt-image-2` e grava `criaturas/{criaturaId}.png` no R2.
5. O Android grava os metadados em `criaturas/{criaturaId}/imagens/{imagemId}`.
6. `buscarCriaturaComImagem` carrega a URL e o caminho do objeto. A URL aponta para o PNG global no R2: todos os jogadores autenticados reutilizam o mesmo arquivo e não geram nem pagam por uma cópia individual.

Se a geração falhar, a criatura continua registrada e o encontro textual não é cancelado. A primeira tentativa é automática no registro global. Uma nova tentativa pode ser feita pelo método `RepositorioCriaturas.gerarImagemOficialSeAusente(criaturaId)`; se o PNG já existir no R2, o Worker devolve a imagem existente com custo zero.

## Orçamento e segurança

- Reserva máxima por tentativa: R$ 5,00 na categoria `other_ai`.
- O Worker calcula o custo a partir do uso retornado pelo provedor: texto de entrada US$ 2,50/M, imagem de entrada US$ 4/M e imagem de saída US$ 15/M; usa câmbio interno de R$ 9,00/US$ e liquida a reserva no mesmo mês em que foi feita. O saldo não utilizado é liberado.
- O limite mensal `other_ai` permanece R$ 48,00.
- A chave OpenAI permanece como segredo do Cloudflare Worker; nunca é incluída no APK.
- Nenhuma chamada paga foi executada durante a edição dos arquivos.

## Publicação e validação pendentes

- O `worker.js` da branch `feature/ai-budget-categories` importa e despacha as rotas; o deploy ainda não foi executado. O workflow de publicação está limitado à branch `main`, então é necessário integrar as alterações à `main` após validar.
- As regras Firestore foram revisadas estaticamente, mas precisam ser testadas no Emulator ou no projeto Firebase.
- O build Android ainda precisa ser executado no GitHub Actions.
