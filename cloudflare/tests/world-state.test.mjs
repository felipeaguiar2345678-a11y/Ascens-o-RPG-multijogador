test("CORS permits PUT and lease headers", async () => {
  const response = await worker.fetch(new Request("https://api.example.test/api/server/world-state/world_clock", {
    method: "OPTIONS",
    headers: {
      "Origin": "https://game.example.test",
      "Access-Control-Request-Method": "PUT",
      "Access-Control-Request-Headers": "authorization,content-type,x-world-server-id,x-world-lease-token"
    }
  }), {});
  assert.equal(response.status, 204);
  assert.match(response.headers.get("Access-Control-Allow-Methods"), /PUT/);
  assert.match(response.headers.get("Access-Control-Allow-Headers"), /X-World-Lease-Token/i);
});

import test from "node:test";
import assert from "node:assert/strict";
import worker from "../worker.js";

const secret = "teste-seguro-com-mais-de-trinta-e-dois-caracteres";

function makeD1() {
  const rows = new Map();
  let lease = null;
  const trades = new Map();
  let takeoverBeforeNextDocumentWrite = null;
  return {
    expireLease() { if (lease) lease.expires_at = 0; },
    takeOverBeforeNextDocumentWrite(ownerId, leaseToken) {
      takeoverBeforeNextDocumentWrite = { world_id: lease?.world_id, owner_id: ownerId, lease_token: leaseToken, expires_at: Date.now() + 30000 };
    },
    async batch(statements) {
      const snapshotRows = new Map([...rows.entries()].map(([k,v]) => [k, {...v}]));
      const snapshotTrades = new Map([...trades.entries()].map(([k,v]) => [k, {...v}]));
      try {
        for (const statement of statements) {
          const { sql, values } = statement;
          if (sql.startsWith("INSERT INTO world_trade_transactions")) {
            const [worldId, transactionId, nonce, fingerprint, keyA, keyB, createdAt, worldA, docA, revA, worldB, docB, revB] = values;
            const a = rows.get(worldA + ":" + docA), b = rows.get(worldB + ":" + docB);
            if (a?.revision === revA && b?.revision === revB && !trades.has(worldId + ":" + transactionId)) {
              trades.set(worldId + ":" + transactionId, { nonce, fingerprint, player_a_key: keyA, player_b_key: keyB, created_at: createdAt });
            }
          } else if (sql.startsWith("UPDATE world_documents") && sql.includes("world_trade_transactions")) {
            const [payload, updatedAt, worldId, key, expectedRevision, tradeWorld, transactionId, nonce] = values;
            const row = rows.get(worldId + ":" + key), trade = trades.get(tradeWorld + ":" + transactionId);
            if (row && row.revision === expectedRevision && trade?.nonce === nonce) {
              row.revision += 1; row.payload = payload; row.updated_at = updatedAt;
            }
          }
        }
        return statements.map(() => ({ success: true, results: [] }));
      } catch (error) {
        rows.clear(); for (const [k,v] of snapshotRows) rows.set(k,v);
        trades.clear(); for (const [k,v] of snapshotTrades) trades.set(k,v);
        throw error;
      }
    },
    prepare(sql) {
      return {
        bind(...values) {
          return {
            sql,
            values,
            async first() {
              if (sql.startsWith("SELECT nonce, fingerprint")) {
                const trade = trades.get(values[0] + ":" + values[1]);
                return trade ? { ...trade } : null;
              }
              if (sql.startsWith("SELECT revision, payload")) {
                const row = rows.get(values[0] + ":" + values[1]);
                return row ? { ...row } : null;
              }
              if (sql.startsWith("SELECT owner_id, lease_token, expires_at")) return lease ? { owner_id: lease.owner_id, lease_token: lease.lease_token, expires_at: lease.expires_at } : null;
              if (sql.startsWith("SELECT owner_id, expires_at")) return lease ? { owner_id: lease.owner_id, expires_at: lease.expires_at } : null;
              if (sql.startsWith("SELECT revision FROM")) {
                const row = rows.get(values[0] + ":" + values[1]);
                return row ? { revision: row.revision } : null;
              }
              return null;
            },
            async all() {
              if (sql.startsWith("INSERT INTO world_server_lease")) {
                const [worldId, ownerId, leaseToken, expiresAt, updatedAt, now, renewOwner, renewToken] = values;
                if (lease && lease.expires_at > now && !(lease.owner_id === renewOwner && lease.lease_token === renewToken)) return { results: [] };
                lease = { world_id: worldId, owner_id: ownerId, lease_token: leaseToken, expires_at: expiresAt, updated_at: updatedAt };
                return { results: [{ owner_id: ownerId, expires_at: expiresAt }] };
              }
              if (sql.startsWith("DELETE FROM world_server_lease")) {
                const [worldId, ownerId, leaseToken] = values;
                if (lease && lease.world_id === worldId && lease.owner_id === ownerId && lease.lease_token === leaseToken) { lease = null; return { results: [{ owner_id: ownerId }] }; }
                return { results: [] };
              }
              if ((sql.startsWith("INSERT INTO world_documents") || sql.startsWith("UPDATE world_documents")) &&
                  sql.includes("world_server_lease")) {
                if (takeoverBeforeNextDocumentWrite) {
                  lease = takeoverBeforeNextDocumentWrite;
                  takeoverBeforeNextDocumentWrite = null;
                }
                const insert = sql.startsWith("INSERT INTO world_documents");
                const [worldId, key, payload, updatedAt] = insert ? values : [values[2], values[3], values[0], values[1]];
                const leaseOffset = insert ? 4 : 5;
                const [leaseWorld, leaseOwner, leaseToken, leaseExpiresAt] = values.slice(leaseOffset, leaseOffset + 4);
                if (!lease || lease.world_id !== leaseWorld || lease.owner_id !== leaseOwner ||
                    lease.lease_token !== leaseToken || lease.expires_at <= leaseExpiresAt) return { results: [] };
                const mapKey = worldId + ":" + key;
                if (insert) {
                  if (rows.has(mapKey)) return { results: [] };
                  rows.set(mapKey, { revision: 1, payload, updated_at: updatedAt });
                  return { results: [{ revision: 1 }] };
                }
                const expectedRevision = values[4];
                const row = rows.get(mapKey);
                if (!row || row.revision !== expectedRevision) return { results: [] };
                row.revision += 1;
                row.payload = payload;
                row.updated_at = updatedAt;
                return { results: [{ revision: row.revision }] };
              }
              if (sql.startsWith("INSERT INTO world_documents")) {
                const [worldId, key, payload, updatedAt] = values;
                const mapKey = worldId + ":" + key;
                if (rows.has(mapKey)) return { results: [] };
                rows.set(mapKey, { revision: 1, payload, updated_at: updatedAt });
                return { results: [{ revision: 1 }] };
              }
              if (sql.startsWith("UPDATE world_documents")) {
                const [payload, updatedAt, worldId, key, expectedRevision] = values;
                const mapKey = worldId + ":" + key;
                const row = rows.get(mapKey);
                if (!row || row.revision !== expectedRevision) return { results: [] };
                row.revision += 1;
                row.payload = payload;
                row.updated_at = updatedAt;
                return { results: [{ revision: row.revision }] };
              }
              return { results: [] };
            }
          };
        }
      };
    }
  };
}

function request(path, method = "GET", body = undefined, token = secret, leaseOwner = "", leaseToken = "") {
  return new Request("https://api.example.test" + path, {
    method,
    headers: {
      ...(token ? { Authorization: "Bearer " + token } : {}),
      ...(leaseOwner ? { "X-World-Server-ID": leaseOwner } : {}),
      ...(leaseToken ? { "X-World-Lease-Token": leaseToken } : {}),
      ...(body === undefined ? {} : { "Content-Type": "application/json" })
    },
    body: body === undefined ? undefined : JSON.stringify(body)
  });
}

test("character trade commits both profiles atomically and is idempotent", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  await worker.fetch(request("/api/server/lease", "POST", { action: "acquire", ownerId, leaseToken: leaseA, ttlSeconds: 30 }), env);
  const keyA = "character_" + "a".repeat(64);
  const keyB = "character_" + "b".repeat(64);
  for (const [key, payload] of [[keyA,{uid:"a",items:["sword"]}],[keyB,{uid:"b",items:["potion"]}]]) {
    const seeded = await worker.fetch(request("/api/server/world-state/" + key, "PUT", { expectedRevision: 0, payload }, secret, ownerId, leaseA), env);
    assert.equal(seeded.status, 200);
  }
  const transactionId = "c".repeat(32);
  const body = {
    transactionId,
    playerA: { key:keyA, expectedRevision:1, payload:{uid:"a",items:["potion"]} },
    playerB: { key:keyB, expectedRevision:1, payload:{uid:"b",items:["sword"]} }
  };
  const committed = await worker.fetch(request("/api/server/character-trade", "POST", body, secret, ownerId, leaseA), env);
  assert.equal(committed.status, 200);
  assert.deepEqual((await committed.json()).revisions, { [keyA]:2, [keyB]:2 });
  const replay = await worker.fetch(request("/api/server/character-trade", "POST", body, secret, ownerId, leaseA), env);
  assert.equal(replay.status, 200);
  assert.equal((await replay.json()).replayed, true);
  const a = await (await worker.fetch(request("/api/server/world-state/" + keyA), env)).json();
  const b = await (await worker.fetch(request("/api/server/world-state/" + keyB), env)).json();
  assert.deepEqual(a.payload.items, ["potion"]);
  assert.deepEqual(b.payload.items, ["sword"]);
  assert.equal(a.revision, 2);
  assert.equal(b.revision, 2);
});

test("character trade revision conflict leaves both profiles unchanged", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  await worker.fetch(request("/api/server/lease", "POST", { action: "acquire", ownerId, leaseToken: leaseA, ttlSeconds: 30 }), env);
  const keyA = "character_" + "d".repeat(64), keyB = "character_" + "e".repeat(64);
  for (const key of [keyA,keyB]) await worker.fetch(request("/api/server/world-state/" + key, "PUT", { expectedRevision:0, payload:{items:["original"]} }, secret, ownerId, leaseA), env);
  const conflict = await worker.fetch(request("/api/server/character-trade", "POST", {
    transactionId:"f".repeat(32),
    playerA:{key:keyA,expectedRevision:1,payload:{items:["changed"]}},
    playerB:{key:keyB,expectedRevision:9,payload:{items:["changed"]}}
  }, secret, ownerId, leaseA), env);
  assert.equal(conflict.status, 409);
  const a = await (await worker.fetch(request("/api/server/world-state/" + keyA), env)).json();
  const b = await (await worker.fetch(request("/api/server/world-state/" + keyB), env)).json();
  assert.deepEqual(a.payload.items, ["original"]);
  assert.deepEqual(b.payload.items, ["original"]);
  assert.equal(a.revision, 1);
  assert.equal(b.revision, 1);
});

test("world state requires the server secret", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const response = await worker.fetch(request("/api/server/world-state/world_clock", "GET", undefined, "invalid"), env);
  assert.equal(response.status, 401);
});

test("world state fails closed when D1 is not configured", async () => {
  const response = await worker.fetch(request("/api/server/world-state/world_clock"), { WORLD_STORAGE_TOKEN: secret });
  assert.equal(response.status, 503);
});

test("world documents use compare-and-swap revisions", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const path = "/api/server/world-state/world_clock";
  const blocked = await worker.fetch(request(path, "PUT", { expectedRevision: 0, payload: { day: 42 } }), env);
  assert.equal(blocked.status, 423);
  await worker.fetch(request("/api/server/lease", "POST", { action: "acquire", ownerId, leaseToken: leaseA, ttlSeconds: 30 }), env);
  const first = await worker.fetch(request(path, "PUT", { expectedRevision: 0, payload: { day: 42 } }, secret, ownerId, leaseA), env);
  assert.equal(first.status, 200);
  assert.equal((await first.json()).revision, 1);

  const conflict = await worker.fetch(request(path, "PUT", { expectedRevision: 0, payload: { day: 99 } }, secret, ownerId, leaseA), env);
  assert.equal(conflict.status, 409);
  assert.equal((await conflict.json()).currentRevision, 1);

  const second = await worker.fetch(request(path, "PUT", { expectedRevision: 1, payload: { day: 43 } }, secret, ownerId, leaseA), env);
  assert.equal(second.status, 200);
  assert.equal((await second.json()).revision, 2);

  const loaded = await worker.fetch(request(path), env);
  const document = await loaded.json();
  assert.equal(document.revision, 2);
  assert.deepEqual(document.payload, { day: 43 });
});

test("world document writes reject a different lease owner or token", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const path = "/api/server/world-state/world_clock";
  await worker.fetch(request("/api/server/lease", "POST", { action: "acquire", ownerId, leaseToken: leaseA, ttlSeconds: 30 }), env);
  const wrongOwner = await worker.fetch(request(path, "PUT", { expectedRevision: 0, payload: { day: 1 } }, secret, ownerB, leaseA), env);
  assert.equal(wrongOwner.status, 423);
  const wrongToken = await worker.fetch(request(path, "PUT", { expectedRevision: 0, payload: { day: 1 } }, secret, ownerA, leaseB), env);
  assert.equal(wrongToken.status, 423);
});

test("fauna fragment keys are bounded to the configured 16 shards", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const allowed = await worker.fetch(request("/api/server/world-state/wildlife_groups_0f"), env);
  assert.equal(allowed.status, 200);
  const outside = await worker.fetch(request("/api/server/world-state/wildlife_groups_10"), env);
  assert.equal(outside.status, 400);
  const malformed = await worker.fetch(request("/api/server/world-state/wildlife_groups_zz"), env);
  assert.equal(malformed.status, 400);
});
test("private character document keys require an opaque SHA-256 suffix", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const valid = await worker.fetch(request("/api/server/world-state/character_" + "a".repeat(64)), env);
  assert.equal(valid.status, 200);
  const shortHash = await worker.fetch(request("/api/server/world-state/character_" + "a".repeat(63)), env);
  assert.equal(shortHash.status, 400);
  const nonHex = await worker.fetch(request("/api/server/world-state/character_" + "g".repeat(64)), env);
  assert.equal(nonHex.status, 400);
});


test("unknown document names and invalid payloads are rejected", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const unknown = await worker.fetch(request("/api/server/world-state/players"), env);
  assert.equal(unknown.status, 400);
  await worker.fetch(request("/api/server/lease", "POST", { action: "acquire", ownerId, leaseToken: leaseA, ttlSeconds: 30 }), env);
  const invalid = await worker.fetch(request("/api/server/world-state/world_clock", "PUT", { expectedRevision: -1, payload: {} }, secret, ownerId, leaseA), env);
  assert.equal(invalid.status, 400);
});

const ownerA = "servidor-principal";
const ownerB = "servidor-reserva";
const leaseA = "a".repeat(64);
const leaseB = "b".repeat(64);
const ownerId = ownerA;

test("world writer lease prevents two active server hosts", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const path = "/api/server/lease";
  const acquireA = await worker.fetch(request(path, "POST", { action: "acquire", ownerId: ownerA, leaseToken: leaseA, ttlSeconds: 30 }), env);
  assert.equal(acquireA.status, 200);
  assert.equal((await acquireA.json()).acquired, true);

  const acquireB = await worker.fetch(request(path, "POST", { action: "acquire", ownerId: ownerB, leaseToken: leaseB, ttlSeconds: 30 }), env);
  assert.equal(acquireB.status, 409);
  assert.equal((await acquireB.json()).error, "WORLD_LEASE_HELD");

  const renewA = await worker.fetch(request(path, "POST", { action: "renew", ownerId: ownerA, leaseToken: leaseA, ttlSeconds: 45 }), env);
  assert.equal(renewA.status, 200);

  const releaseWrongOwner = await worker.fetch(request(path, "POST", { action: "release", ownerId: ownerB, leaseToken: leaseB }), env);
  assert.equal((await releaseWrongOwner.json()).released, false);

  const releaseWrongToken = await worker.fetch(request(path, "POST", { action: "release", ownerId: ownerA, leaseToken: leaseB }), env);
  assert.equal((await releaseWrongToken.json()).released, false);

  const stillHeldAfterInvalidRelease = await worker.fetch(request(path, "POST", { action: "acquire", ownerId: ownerB, leaseToken: leaseB, ttlSeconds: 30 }), env);
  assert.equal(stillHeldAfterInvalidRelease.status, 409);

  const releaseA = await worker.fetch(request(path, "POST", { action: "release", ownerId: ownerA, leaseToken: leaseA }), env);
  assert.equal((await releaseA.json()).released, true);

  const acquireBAfterRelease = await worker.fetch(request(path, "POST", { action: "acquire", ownerId: ownerB, leaseToken: leaseB, ttlSeconds: 30 }), env);
  assert.equal(acquireBAfterRelease.status, 200);
});

test("world writer lease validates identity and bounded expiry", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const path = "/api/server/lease";
  const badIdentity = await worker.fetch(request(path, "POST", { action: "acquire", ownerId: "x", leaseToken: "bad", ttlSeconds: 30 }), env);
  assert.equal(badIdentity.status, 400);
  const badTtl = await worker.fetch(request(path, "POST", { action: "acquire", ownerId: ownerA, leaseToken: leaseA, ttlSeconds: 3600 }), env);
  assert.equal(badTtl.status, 400);
  const noSecret = await worker.fetch(request(path, "POST", { action: "acquire", ownerId: ownerA, leaseToken: leaseA, ttlSeconds: 30 }, "invalid"), env);
  assert.equal(noSecret.status, 401);
});


test("cooperative room snapshots persist globally with CAS revisions", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const path = "/api/server/world-state/cooperative_rooms";
  const lease = await worker.fetch(request("/api/server/lease", "POST", {
    action: "acquire", ownerId, leaseToken: leaseA, ttlSeconds: 30
  }), env);
  assert.equal(lease.status, 200);

  const initialPayload = {
    versao: 1,
    salas: [{
      codigo: "ABC234",
      membrosUid: ["uid-a", "uid-b"],
      criadaEmUnix: 1795700000,
      estadoAventura: { missao: "bosque", etapa: 2 },
      revisaoAventura: 2
    }]
  };
  const initial = await worker.fetch(request(path, "PUT", {
    expectedRevision: 0, payload: initialPayload
  }, secret, ownerId, leaseA), env);
  assert.equal(initial.status, 200);
  assert.equal((await initial.json()).revision, 1);

  const stale = await worker.fetch(request(path, "PUT", {
    expectedRevision: 0,
    payload: { versao: 1, salas: [] }
  }, secret, ownerId, leaseA), env);
  assert.equal(stale.status, 409);

  const updatedPayload = {
    versao: 1,
    salas: [{
      ...initialPayload.salas[0],
      estadoAventura: { missao: "bosque", etapa: 3, encontro: { ativo: true } },
      revisaoAventura: 3
    }]
  };
  const updated = await worker.fetch(request(path, "PUT", {
    expectedRevision: 1, payload: updatedPayload
  }, secret, ownerId, leaseA), env);
  assert.equal(updated.status, 200);
  assert.equal((await updated.json()).revision, 2);

  const loaded = await worker.fetch(request(path), env);
  const document = await loaded.json();
  assert.equal(document.revision, 2);
  assert.deepEqual(document.payload, updatedPayload);
});

test("Ally document persists membership and rejects stale global writes", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const path = "/api/server/world-state/allies";
  const lease = await worker.fetch(request("/api/server/lease", "POST", {
    action: "acquire", ownerId, leaseToken: leaseA, ttlSeconds: 30
  }), env);
  assert.equal(lease.status, 200);

  const firstPayload = {
    versao: 1,
    allys: [{
      id: "ALLY_12345",
      liderUid: "uid-a",
      membros: ["uid-a", "uid-b"]
    }]
  };
  const first = await worker.fetch(request(path, "PUT", {
    expectedRevision: 0, payload: firstPayload
  }, secret, ownerId, leaseA), env);
  assert.equal(first.status, 200);
  assert.equal((await first.json()).revision, 1);

  const nextPayload = {
    versao: 1,
    allys: [{
      ...firstPayload.allys[0],
      membros: ["uid-a", "uid-b", "uid-c"]
    }]
  };
  const next = await worker.fetch(request(path, "PUT", {
    expectedRevision: 1, payload: nextPayload
  }, secret, ownerId, leaseA), env);
  assert.equal(next.status, 200);
  assert.equal((await next.json()).revision, 2);

  const stale = await worker.fetch(request(path, "PUT", {
    expectedRevision: 1, payload: firstPayload
  }, secret, ownerId, leaseA), env);
  assert.equal(stale.status, 409);

  const loaded = await worker.fetch(request(path), env);
  const document = await loaded.json();
  assert.equal(document.revision, 2);
  assert.deepEqual(document.payload, nextPayload);
});

test("world boss document imports once and preserves authoritative CAS revisions", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const path = "/api/server/world-state/world_boss";
  const lease = await worker.fetch(request("/api/server/lease", "POST", {
    action: "acquire", ownerId, leaseToken: leaseA, ttlSeconds: 30
  }), env);
  assert.equal(lease.status, 200);
  const initial = await worker.fetch(request(path, "PUT", {
    expectedRevision: 0,
    payload: { chefeId: "jormungandr", vida: 2000000, revisaoSincronizacao: 1 }
  }, secret, ownerId, leaseA), env);
  assert.equal(initial.status, 200);
  assert.equal((await initial.json()).revision, 1);
  const update = await worker.fetch(request(path, "PUT", {
    expectedRevision: 1,
    payload: { chefeId: "jormungandr", vida: 1999750, revisaoSincronizacao: 2 }
  }, secret, ownerId, leaseA), env);
  assert.equal(update.status, 200);
  const stale = await worker.fetch(request(path, "PUT", {
    expectedRevision: 1,
    payload: { chefeId: "jormungandr", vida: 2000000, revisaoSincronizacao: 3 }
  }, secret, ownerId, leaseA), env);
  assert.equal(stale.status, 409);
  const loaded = await worker.fetch(request(path), env);
  const document = await loaded.json();
  assert.equal(document.revision, 2);
  assert.equal(document.payload.vida, 1999750);
});


test("renovação da lease mantém exclusividade e rejeita identidade ou TTL inválidos", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const leasePath = "/api/server/lease";

  const acquired = await worker.fetch(request(leasePath, "POST", {
    action: "acquire", ownerId: ownerA, leaseToken: leaseA, ttlSeconds: 30
  }), env);
  assert.equal(acquired.status, 200);

  const reserveAcquire = await worker.fetch(request(leasePath, "POST", {
    action: "acquire", ownerId: ownerB, leaseToken: leaseB, ttlSeconds: 30
  }), env);
  assert.equal(reserveAcquire.status, 409);

  const wrongOwnerRenewal = await worker.fetch(request(leasePath, "POST", {
    action: "renew", ownerId: ownerB, leaseToken: leaseA, ttlSeconds: 30
  }), env);
  assert.equal(wrongOwnerRenewal.status, 409);

  const wrongTokenRenewal = await worker.fetch(request(leasePath, "POST", {
    action: "renew", ownerId: ownerA, leaseToken: leaseB, ttlSeconds: 30
  }), env);
  assert.equal(wrongTokenRenewal.status, 409);

  const invalidTtl = await worker.fetch(request(leasePath, "POST", {
    action: "renew", ownerId: ownerA, leaseToken: leaseA, ttlSeconds: 61
  }), env);
  assert.equal(invalidTtl.status, 400);

  const renewed = await worker.fetch(request(leasePath, "POST", {
    action: "renew", ownerId: ownerA, leaseToken: leaseA, ttlSeconds: 45
  }), env);
  assert.equal(renewed.status, 200);
  const renewedBody = await renewed.json();
  assert.equal(renewedBody.ownerId, ownerA);
  assert.ok(renewedBody.expiresAt > Date.now());

  const reserveAfterRenewal = await worker.fetch(request(leasePath, "POST", {
    action: "acquire", ownerId: ownerB, leaseToken: leaseB, ttlSeconds: 30
  }), env);
  assert.equal(reserveAfterRenewal.status, 409);
});

test("gravação comum revalida a lease atomicamente no instante do commit", async () => {
  const db = makeD1();
  const env = { WORLD_STATE: db, WORLD_STORAGE_TOKEN: secret };
  const path = "/api/server/world-state/world_clock";
  const acquired = await worker.fetch(request("/api/server/lease", "POST", {
    action: "acquire", ownerId: ownerA, leaseToken: leaseA, ttlSeconds: 30
  }), env);
  assert.equal(acquired.status, 200);

  // Simula a troca de host depois da leitura inicial da lease, mas antes do SQL de gravação.
  db.takeOverBeforeNextDocumentWrite(ownerB, leaseB);
  const staleWrite = await worker.fetch(request(path, "PUT", {
    expectedRevision: 0, payload: { day: 99 }
  }, secret, ownerA, leaseA), env);
  assert.equal(staleWrite.status, 409);

  const absent = await (await worker.fetch(request(path), env)).json();
  assert.equal(absent.revision, 0);
  assert.equal(absent.payload, null);

  const currentWrite = await worker.fetch(request(path, "PUT", {
    expectedRevision: 0, payload: { day: 11 }
  }, secret, ownerB, leaseB), env);
  assert.equal(currentWrite.status, 200);
  assert.equal((await currentWrite.json()).revision, 1);
});

test("host reserva assume após expiração e o host antigo perde a autoridade de escrita", async () => {
  const db = makeD1();
  const env = { WORLD_STATE: db, WORLD_STORAGE_TOKEN: secret };
  const leasePath = "/api/server/lease";
  const statePath = "/api/server/world-state/world_clock";

  const firstHost = await worker.fetch(request(leasePath, "POST", {
    action: "acquire", ownerId: ownerA, leaseToken: leaseA, ttlSeconds: 30
  }), env);
  assert.equal(firstHost.status, 200);

  const initialWrite = await worker.fetch(request(statePath, "PUT", {
    expectedRevision: 0, payload: { day: 10 }
  }, secret, ownerA, leaseA), env);
  assert.equal(initialWrite.status, 200);

  // Simula a passagem do TTL sem tornar o teste dependente de espera real.
  db.expireLease();
  const takeover = await worker.fetch(request(leasePath, "POST", {
    action: "acquire", ownerId: ownerB, leaseToken: leaseB, ttlSeconds: 30
  }), env);
  assert.equal(takeover.status, 200);
  assert.equal((await takeover.json()).ownerId, ownerB);

  const staleHostWrite = await worker.fetch(request(statePath, "PUT", {
    expectedRevision: 1, payload: { day: 999 }
  }, secret, ownerA, leaseA), env);
  assert.equal(staleHostWrite.status, 423);

  const newHostWrite = await worker.fetch(request(statePath, "PUT", {
    expectedRevision: 1, payload: { day: 11 }
  }, secret, ownerB, leaseB), env);
  assert.equal(newHostWrite.status, 200);
  assert.equal((await newHostWrite.json()).revision, 2);

  const persisted = await (await worker.fetch(request(statePath), env)).json();
  assert.equal(persisted.revision, 2);
  assert.deepEqual(persisted.payload, { day: 11 });
});
