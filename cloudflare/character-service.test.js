import test from "node:test";
import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import { handleCharacterPosition } from "./character-service.js";

globalThis.crypto ||= webcrypto;

async function fixture(ownerUid = "player-1") {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true, ["sign", "verify"]
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let binary = "";
  for (const byte of pkcs8) binary += String.fromCharCode(byte);
  const pem = "-----BEGIN PRIVATE KEY-----\\n" +
    btoa(binary).match(/.{1,64}/g).join("\\n") +
    "\\n-----END PRIVATE KEY-----";
  const env = {
    FIREBASE_SERVICE_ACCOUNT_EMAIL: "character-test-" + Math.random().toString(36).slice(2) + "@ascensao-do-soberano.iam.gserviceaccount.com",
    FIREBASE_PRIVATE_KEY: pem,
    FIREBASE_PROJECT_ID: "ascensao-do-soberano"
  };
  const calls = [];
  const fetchMock = async (url, options = {}) => {
    calls.push({ url: String(url), options });
    if (String(url) === "https://oauth2.googleapis.com/token") {
      return Response.json({ access_token: "token-character", expires_in: 3600 });
    }
    if (String(url).endsWith(":beginTransaction")) {
      return Response.json({ transaction: "transaction-character-123" });
    }
    if (String(url).includes("characters/hero-1?transaction=")) {
      return Response.json({
        name: "projects/ascensao-do-soberano/databases/(default)/documents/characters/hero-1",
        fields: {
          ownerUid: { stringValue: ownerUid },
          worldX: { doubleValue: 0.5 },
          worldY: { doubleValue: 0.7 },
          xp: { integerValue: "999" }
        }
      });
    }
    if (String(url).endsWith(":commit")) return Response.json({ writeResults: [{}] });
    throw new Error("URL inesperada: " + url);
  };
  return { env, calls, fetchMock };
}

test("posição atualiza somente coordenadas e área do personagem dono", async () => {
  const { env, calls, fetchMock } = await fixture();
  const result = await handleCharacterPosition(env, "player-1", {
    characterId: "hero-1", x: 0.61, y: 0.42, worldPointId: "eldarion"
  }, fetchMock);
  assert.equal(result.status, 200);
  assert.equal(result.body.saved, true);
  const commit = calls.find(call => call.url.endsWith(":commit"));
  const body = JSON.parse(commit.options.body);
  const write = body.writes[0];
  assert.deepEqual(write.updateMask.fieldPaths, ["worldX", "worldY", "currentWorldPointId"]);
  assert.deepEqual(Object.keys(write.update.fields).sort(), ["currentWorldPointId", "worldX", "worldY"]);
  assert.equal(write.update.fields.currentWorldPointId.stringValue, "eldarion");
  assert.equal(write.update.fields.worldX.doubleValue, 0.61);
  assert.equal(write.update.fields.worldY.doubleValue, 0.42);
  assert.equal(write.update.fields.xp, undefined);
});

test("posição não pode alterar personagem de outra conta", async () => {
  const { env, fetchMock } = await fixture("player-2");
  const result = await handleCharacterPosition(env, "player-1", {
    characterId: "hero-1", x: 0.6, y: 0.4
  }, fetchMock);
  assert.equal(result.status, 403);
});

test("posição rejeita coordenadas e campos extras inválidos", async () => {
  const { env, fetchMock } = await fixture();
  assert.equal((await handleCharacterPosition(env, "player-1", {
    characterId: "hero-1", x: 999, y: 0.4
  }, fetchMock)).status, 400);
  assert.equal((await handleCharacterPosition(env, "player-1", {
    characterId: "hero-1", x: 0.5, y: 0.5, xp: 1000000
  }, fetchMock)).status, 400);
});
