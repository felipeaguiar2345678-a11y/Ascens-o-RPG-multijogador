import test from "node:test";
import assert from "node:assert/strict";
import { handleMultiplayerAction } from "./multiplayer-service.js";

test("multiplayer expandido rejeita sessão ausente antes de acessar o Firestore", async () => {
  const result = await handleMultiplayerAction({}, "", { acao: "buscarMasmorra" });
  assert.equal(result.status, 401);
  assert.equal(result.body.error, "UNAUTHORIZED");
});

test("multiplayer expandido rejeita payloads que não são objetos", async () => {
  const result = await handleMultiplayerAction({}, "jogador-1", []);
  assert.equal(result.status, 400);
  assert.equal(result.body.error, "INVALID_REQUEST");
});

test("multiplayer expandido não executa ações desconhecidas", async () => {
  const result = await handleMultiplayerAction({}, "jogador-1", { acao: "darOuroInfinito" });
  assert.equal(result.status, 400);
  assert.equal(result.body.error, "UNKNOWN_MULTIPLAYER_ACTION");
});
