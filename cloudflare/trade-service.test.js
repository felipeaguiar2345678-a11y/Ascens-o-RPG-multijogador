import test from "node:test";
import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import {
  validateTradeOffer,
  validateTradePossessions,
  transferTradeInventory,
  handleTradeAction
} from "./trade-service.js";
import { decodeFirestoreFields, decodeFirestoreValue, encodeFirestoreFields } from "./firebase-admin.js";

globalThis.crypto ||= webcrypto;

test("oferta de troca aceita somente IDs e quantidades válidas", () => {
  assert.deepEqual(validateTradeOffer({
    itens: [{ id: "fibra-1", quantidade: 2 }],
    ovos: ["ovo-1"],
    equipamentos: ["espada-1"]
  }), {
    itens: [{ id: "fibra-1", quantidade: 2 }],
    ovos: ["ovo-1"],
    equipamentos: ["espada-1"]
  });
  assert.throws(() => validateTradeOffer({ itens: [{ id: "xp", quantidade: 1 }], moedas: 10 }), /OFERTA_CAMPO_PROIBIDO/);
  assert.throws(() => validateTradeOffer({ itens: [{ id: "fibra-1", quantidade: 0 }] }), /ITEM_OFERTA_INVALIDO/);
  assert.throws(() => validateTradeOffer({ ovos: ["ovo-1", "ovo-1"] }), /OBJETO_OFERTA_DUPLICADO/);
});

test("troca rejeita XP e objetos que não pertencem ao jogador", () => {
  const offer = validateTradeOffer({ itens: [{ id: "xp", quantidade: 1 }] });
  assert.throws(() => validateTradePossessions({
    items: [{ id: "xp", name: "Experiência", type: "XP", quantity: 10 }]
  }, offer), /XP_NAO_NEGOCIAVEL/);
  assert.throws(() => validateTradePossessions({ items: [] }, offer), /ITEM_NAO_PERTENCE_AO_JOGADOR/);
  const gearOffer = validateTradeOffer({ equipamentos: ["espada-1"] });
  assert.throws(() => validateTradePossessions({
    equipment: [{ id: "espada-1" }]
  }, gearOffer, { weapon: { id: "espada-1" } }), /EQUIPAMENTO_EQUIPADO/);
});

test("transferência move quantidades sem duplicar IDs nem alterar ouro e companheiros", () => {
  const offer = validateTradeOffer({
    itens: [{ id: "fibra-1", quantidade: 2 }],
    ovos: ["ovo-1"],
    equipamentos: ["espada-1"]
  });
  const source = {
    items: [{ id: "fibra-1", name: "Fibra", type: "MATERIAL", quantity: 5 }],
    eggs: [{ id: "ovo-1", species: "Lobo" }],
    equipment: [{ id: "espada-1", name: "Espada" }],
    gold: 999,
    companions: [{ id: "pet-1" }]
  };
  const target = { items: [], eggs: [], equipment: [], gold: 3, companions: [] };
  const result = transferTradeInventory(source, target, offer);
  assert.equal(result.source.items[0].quantity, 3);
  assert.equal(result.target.items[0].quantity, 2);
  assert.equal(result.source.eggs.length, 0);
  assert.equal(result.target.eggs[0].id, "ovo-1");
  assert.equal(result.source.equipment.length, 0);
  assert.equal(result.target.equipment[0].id, "espada-1");
  assert.equal(result.source.gold, 999);
  assert.equal(result.target.gold, 3);
  assert.equal(result.source.companions[0].id, "pet-1");
});

async function makePrivateKeyPem() {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"]
  );
  const bytes = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return "-----BEGIN PRIVATE KEY-----\\n" +
    btoa(binary).match(/.{1,64}/g).join("\\n") +
    "\\n-----END PRIVATE KEY-----";
}

function makeFirestoreMock(seed) {
  const docs = new Map();
  const project = "ascensao-do-soberano";
  const prefix = `projects/${project}/databases/(default)/documents/`;
  for (const [collection, id, data] of seed) {
    docs.set(prefix + collection + "/" + id, { name: prefix + collection + "/" + id, fields: encodeFirestoreFields(data) });
  }
  let transactionNumber = 0;
  const fetch = async (urlValue, options = {}) => {
    const url = String(urlValue);
    if (url === "https://oauth2.googleapis.com/token") {
      return Response.json({ access_token: "trade-test-token", expires_in: 3600 });
    }
    if (url.endsWith(":beginTransaction")) {
      transactionNumber++;
      return Response.json({ transaction: "transaction-" + transactionNumber });
    }
    if (url.endsWith(":runQuery")) {
      const body = JSON.parse(options.body);
      const query = body.structuredQuery;
      const collection = query.from[0].collectionId;
      const filter = query.where.fieldFilter;
      const expected = decodeFirestoreValue(filter.value);
      const found = [...docs.entries()].find(([name, doc]) =>
        name.startsWith(prefix + collection + "/") &&
        decodeFirestoreFields(doc.fields)[filter.field.fieldPath] === expected
      );
      return Response.json(found ? [ { document: found[1] } ] : []);
    }
    if (url.includes("/documents/") && url.includes("?transaction=")) {
      const name = url.split("?")[0].split("/v1/")[1];
      const doc = docs.get(name);
      return doc ? Response.json(doc) : new Response("not found", { status: 404 });
    }
    if (url.endsWith(":commit")) {
      const body = JSON.parse(options.body);
      for (const write of body.writes) {
        const name = write.update.name;
        const existing = docs.get(name);
        if (write.currentDocument?.exists === false && existing) {
          return new Response("already exists", { status: 409 });
        }
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

test("troca completa é processada no servidor em transações atômicas", async () => {
  const mock = makeFirestoreMock([
    ["characters", "char-a", {
      id: "char-a", ownerUid: "jogador-a",
      inventory: {
        items: [{ id: "fibra-a", name: "Fibra", type: "MATERIAL", quantity: 4 }],
        eggs: [], equipment: [], gold: 100, companions: []
      }
    }],
    ["characters", "char-b", {
      id: "char-b", ownerUid: "jogador-b",
      inventory: {
        items: [], eggs: [{ id: "ovo-b", species: "Lobo" }],
        equipment: [], gold: 50, companions: []
      }
    }]
  ]);
  const env = {
    FIREBASE_SERVICE_ACCOUNT_EMAIL: "trade-worker@ascensao-do-soberano.iam.gserviceaccount.com",
    FIREBASE_PRIVATE_KEY: await makePrivateKeyPem(),
    FIREBASE_PROJECT_ID: "ascensao-do-soberano"
  };
  const create = await handleTradeAction(env, "jogador-a", { acao: "criar", destinatarioUid: "jogador-b" }, mock.fetch);
  assert.equal(create.status, 200);
  const tradeId = create.body.trocaId;
  assert.ok(tradeId);
  const offerA = await handleTradeAction(env, "jogador-a", {
    acao: "ofertar", trocaId: tradeId,
    oferta: { itens: [{ id: "fibra-a", quantidade: 2 }] }
  }, mock.fetch);
  assert.equal(offerA.status, 200, JSON.stringify(offerA.body));
  assert.equal((await handleTradeAction(env, "jogador-b", {
    acao: "ofertar", trocaId: tradeId,
    oferta: { ovos: ["ovo-b"] }
  }, mock.fetch)).status, 200);
  assert.equal((await handleTradeAction(env, "jogador-a", { acao: "aceitar", trocaId: tradeId }, mock.fetch)).body.status, "ACEITE_REGISTRADO");
  assert.equal((await handleTradeAction(env, "jogador-b", { acao: "aceitar", trocaId: tradeId }, mock.fetch)).body.status, "TROCA_CONCLUIDA");
  const a = decodeFirestoreFields(mock.docs.get(mock.prefix + "characters/char-a").fields);
  const b = decodeFirestoreFields(mock.docs.get(mock.prefix + "characters/char-b").fields);
  assert.equal(a.inventory.items[0].quantity, 2);
  assert.equal(b.inventory.items[0].quantity, 2);
  assert.equal(a.inventory.eggs[0].id, "ovo-b");
  assert.equal(b.inventory.eggs.length, 0);
  const trade = decodeFirestoreFields(mock.docs.get(mock.prefix + "trades/" + tradeId).fields);
  assert.equal(trade.status, "CONCLUIDA");
  assert.deepEqual(trade.aceitoPor, ["jogador-a", "jogador-b"]);
});
