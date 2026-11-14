import test from "node:test";
import assert from "node:assert/strict";
import { handleCreatureImageGeneration } from "./creature-image-route.js";

function request(creatureId = "criatura_teste") {
  return new Request("https://ascensao-soberano-api.test/api/creatures/image", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ creatureId })
  });
}

test("pedido concorrente da mesma criatura é recusado sem iniciar nova geração", async () => {
  const calls = [];
  const stub = {
    async fetch(_url, options) {
      const body = JSON.parse(options.body);
      calls.push(body.action);
      if (body.action === "creature_image_lock_acquire") {
        return new Response(JSON.stringify({
          acquired: false, error: "CREATURE_IMAGE_ALREADY_GENERATING"
        }), { status: 409 });
      }
      return new Response(JSON.stringify({ released: true }));
    }
  };
  const env = {
    OPENAI_API_KEY: "não-utilizada",
    IMAGENS_R2: { head: async () => null },
    AI_BUDGET: { get: () => stub, idFromName: () => "global" }
  };

  const response = await handleCreatureImageGeneration(
    request(), env, { uid: "jogador-2" }
  );
  const body = await response.json();

  assert.equal(response.status, 409);
  assert.equal(body.error, "CREATURE_IMAGE_ALREADY_GENERATING");
  assert.deepEqual(calls, ["creature_image_lock_acquire"]);
});

test("trava adquirida é liberada mesmo quando a configuração de IA está ausente", async () => {
  const calls = [];
  const stub = {
    async fetch(_url, options) {
      const body = JSON.parse(options.body);
      calls.push(body.action);
      return new Response(JSON.stringify({ acquired: true, released: true }));
    }
  };
  const env = {
    IMAGENS_R2: { head: async () => null },
    AI_BUDGET: { get: () => stub, idFromName: () => "global" }
  };

  const response = await handleCreatureImageGeneration(
    request(), env, { uid: "jogador-1" }
  );
  const body = await response.json();

  assert.equal(response.status, 503);
  assert.equal(body.error, "AI_NOT_CONFIGURED");
  assert.deepEqual(calls, [
    "creature_image_lock_acquire",
    "creature_image_lock_release"
  ]);
});

test("identificador inválido não tenta adquirir trava nem gerar imagem", async () => {
  let lockCalls = 0;
  const env = {
    OPENAI_API_KEY: "não-utilizada",
    IMAGENS_R2: { head: async () => null },
    AI_BUDGET: {
      idFromName: () => "global",
      get: () => ({ fetch: async () => { lockCalls += 1; return new Response("{}", { status: 200 }); } })
    }
  };

  const response = await handleCreatureImageGeneration(
    request("../criatura"), env, { uid: "jogador-1" }
  );
  const body = await response.json();

  assert.equal(response.status, 400);
  assert.equal(body.error, "INVALID_CREATURE_IMAGE_REQUEST");
  assert.equal(lockCalls, 0);
});
