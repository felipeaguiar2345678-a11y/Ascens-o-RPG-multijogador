import test from "node:test";
import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import { encodeFirestoreFields, decodeFirestoreFields, decodeFirestoreValue } from "./firebase-admin.js";
import { handleGuildAction } from "./guild-service.js";

globalThis.crypto ||= webcrypto;

async function privateKeyPem() {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true, ["sign", "verify"]
  );
  const bytes = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return "-----BEGIN PRIVATE KEY-----\n" + btoa(binary).match(/.{1,64}/g).join("\n") + "\n-----END PRIVATE KEY-----";
}

function firestoreMock(seed = []) {
  const project = "ascensao-do-soberano";
  const prefix = `projects/${project}/databases/(default)/documents/`;
  const docs = new Map();
  for (const [path, data] of seed) {
    const name = prefix + path;
    docs.set(name, { name, fields: encodeFirestoreFields(data) });
  }
  let sequence = 0;
  const fetch = async (urlValue, options = {}) => {
    const url = String(urlValue);
    if (url === "https://oauth2.googleapis.com/token") return Response.json({ access_token: "guild-test-token", expires_in: 3600 });
    if (url.endsWith(":beginTransaction")) return Response.json({ transaction: "guild-transaction-" + (++sequence) });
    if (url.endsWith(":runQuery")) {
      const query = JSON.parse(options.body).structuredQuery;
      const collection = query.from[0].collectionId;
      const filter = query.where?.fieldFilter;
      const expected = filter ? decodeFirestoreValue(filter.value) : undefined;
      const found = [...docs.entries()].find(([name, doc]) =>
        name.startsWith(prefix + collection + "/") &&
        (!filter || decodeFirestoreFields(doc.fields)[filter.field.fieldPath] === expected)
      );
      return Response.json(found ? [{ document: found[1] }] : []);
    }
    if (url.includes("/documents/") && url.includes("?transaction=")) {
      const name = url.split("?")[0].split("/v1/")[1];
      const doc = docs.get(name);
      return doc ? Response.json(doc) : new Response("not found", { status: 404 });
    }
    if (url.endsWith(":commit")) {
      const body = JSON.parse(options.body);
      for (const write of body.writes) {
        if (write.delete) { docs.delete(write.delete); continue; }
        const name = write.update.name;
        const existing = docs.get(name);
        if (write.currentDocument?.exists === false && existing) return new Response("already exists", { status: 409 });
        const incoming = decodeFirestoreFields(write.update.fields);
        let data = incoming;
        if (write.updateMask?.fieldPaths && existing) {
          data = decodeFirestoreFields(existing.fields);
          for (const field of write.updateMask.fieldPaths) data[field] = incoming[field];
        }
        docs.set(name, { name, fields: encodeFirestoreFields(data) });
      }
      return Response.json({ writeResults: body.writes.map(() => ({})) });
    }
    throw new Error("URL inesperada: " + url);
  };
  return { docs, fetch, prefix };
}

const envFor = key => ({
  FIREBASE_SERVICE_ACCOUNT_EMAIL: "worker@ascensao-do-soberano.iam.gserviceaccount.com",
  FIREBASE_PRIVATE_KEY: key,
  FIREBASE_PROJECT_ID: "ascensao-do-soberano"
});

test("cria guilda e registra associação e classificação", async () => {
  const mock = firestoreMock();
  const result = await handleGuildAction(envFor(await privateKeyPem()), "jogador-a", {
    acao: "criar", nome: "Guardiões", nomeJogador: "Aventureiro"
  }, mock.fetch);
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.codigo.length, 6);
  const guild = decodeFirestoreFields(mock.docs.get(mock.prefix + "guilds/" + result.body.guildaId).fields);
  assert.deepEqual(guild.members, ["jogador-a"]);
  assert.equal(guild.memberNames["jogador-a"], "Aventureiro");
  const membership = decodeFirestoreFields(mock.docs.get(mock.prefix + "guildMembership/jogador-a").fields);
  assert.equal(membership.guildId, result.body.guildaId);
  const ranking = decodeFirestoreFields(mock.docs.get(mock.prefix + "leaderboards/guildas/entries/" + result.body.guildaId).fields);
  assert.equal(ranking.score, 1);
});

test("entrada e saída atualizam membros, liderança e ranking", async () => {
  const mock = firestoreMock();
  const env = envFor(await privateKeyPem());
  const created = await handleGuildAction(env, "jogador-a", {
    acao: "criar", nome: "Companhia", nomeJogador: "Líder"
  }, mock.fetch);
  assert.equal(created.status, 200);
  const joined = await handleGuildAction(env, "jogador-b", {
    acao: "entrar", codigo: created.body.codigo, nomeJogador: "Aliado"
  }, mock.fetch);
  assert.equal(joined.status, 200);
  const left = await handleGuildAction(env, "jogador-a", { acao: "sair" }, mock.fetch);
  assert.equal(left.status, 200);
  const guild = decodeFirestoreFields(mock.docs.get(mock.prefix + "guilds/" + created.body.guildaId).fields);
  assert.deepEqual(guild.members, ["jogador-b"]);
  assert.equal(guild.leaderUid, "jogador-b");
  assert.equal(mock.docs.has(mock.prefix + "guildMembership/jogador-a"), false);
  const ranking = decodeFirestoreFields(mock.docs.get(mock.prefix + "leaderboards/guildas/entries/" + created.body.guildaId).fields);
  assert.equal(ranking.score, 1);
});

test("impede entrada duplicada e falha fechada sem credenciais", async () => {
  const mock = firestoreMock();
  const env = envFor(await privateKeyPem());
  const created = await handleGuildAction(env, "jogador-a", {
    acao: "criar", nome: "Companhia"
  }, mock.fetch);
  const duplicate = await handleGuildAction(env, "jogador-a", {
    acao: "entrar", codigo: created.body.codigo
  }, mock.fetch);
  assert.equal(duplicate.status, 409);
  const unavailable = await handleGuildAction({}, "jogador-c", { acao: "criar", nome: "Guilda" }, mock.fetch);
  assert.equal(unavailable.status, 503);
});
