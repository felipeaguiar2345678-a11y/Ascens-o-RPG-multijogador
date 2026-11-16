import test from "node:test";
import assert from "node:assert/strict";
import { handleWorldSceneGeneration, handleWorldSceneRequest } from "./world-scene-image-route.js";

test("rejeita identificadores de cenário fora da lista antes de reservar orçamento", async () => {
  const request = new Request("https://worker.test/api/scenes/generate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sceneId: "cenario_inventado" })
  });
  const response = await handleWorldSceneGeneration(request, {}, { uid: "jogador-teste" });
  assert.equal(response.status, 400);
  assert.equal((await response.json()).error, "INVALID_SCENE_ID");
});

test("não expõe imagens para identificadores de cenário desconhecidos", async () => {
  const request = new Request("https://worker.test/api/scenes/image/cenario_qualquer");
  const response = await handleWorldSceneRequest(request, {});
  assert.equal(response.status, 404);
});
