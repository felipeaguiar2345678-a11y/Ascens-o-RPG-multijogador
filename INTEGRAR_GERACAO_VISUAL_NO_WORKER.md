# Integração da geração visual ao Worker existente

O arquivo `character-visual-route.js` contém a nova rota sem substituir as rotas de criaturas, upload administrativo ou orçamento que já existem em `cloudflare/worker.js` no GitHub.

## 1. Importar os handlers

No início de `cloudflare/worker.js`, antes de `const corsHeaders`, adicione:

```js
import {
  handleCharacterVisualGeneration,
  handleCharacterImageRequest
} from "./character-visual-route.js";
```

## 2. Adicionar as duas rotas

Dentro de `export default { async fetch(request, env) { ... } }`, logo depois do bloco `OPTIONS` e antes das outras rotas, adicione:

```js
    if (path === "/api/characters/visual/generate" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) {
        return jsonResponse({
          error: "UNAUTHORIZED",
          message: "É necessário entrar em uma conta válida.",
          reason: authentication.reason
        }, 401);
      }
      return handleCharacterVisualGeneration(request, env, authentication);
    }

    if (path.startsWith("/images/characters/") && method === "GET") {
      return handleCharacterImageRequest(url, env);
    }
```

## 3. Configuração que a rota reutiliza

A extensão utiliza os bindings já existentes no `wrangler.toml`:

- `IMAGENS_R2` — bucket `ascensao-soberano-imagens`.
- `AI_BUDGET` — Durable Object `MonthlyAIBudget`.
- `OPENAI_API_KEY` — secret já configurado no Worker.

Não coloque a chave OpenAI no aplicativo Android. A nova rota valida o Firebase ID token, consulta `characters/{characterId}` usando o token do próprio jogador, confirma `ownerUid`, reserva R$ 0,60 na categoria `characters`, gera uma imagem `gpt-image-2` em qualidade média, salva no R2 e contabiliza a reserva. O limite já existente para a categoria é R$ 2,00 por mês.

## 4. Verificações antes de publicar

Na pasta `cloudflare`, execute:

```bash
npm run check
npm test
```

Depois publique somente quando os testes passarem. Esta integração não foi publicada nem fez chamadas pagas durante a preparação do ZIP.

## 5. Comportamento esperado

- A geração automática ocorre somente depois que um personagem novo foi salvo.
- Ao entrar novamente no jogo, uma imagem já salva é reutilizada; não há geração automática no login.
- Se a geração falhar, o personagem continua salvo e a tela permite tentar novamente manualmente.
- O endpoint retorna uma URL pública somente da arte do personagem; nenhum dado de ficha é exposto pela rota de imagens.
- A reserva de R$ 0,60 é conservadora. Como a resposta da Images API não fornece neste fluxo um custo monetário confiável por imagem, a tentativa é contabilizada pela reserva inteira para nunca ultrapassar o teto configurado.
