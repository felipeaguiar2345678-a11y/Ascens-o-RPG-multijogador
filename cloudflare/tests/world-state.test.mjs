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
  return {
    prepare(sql) {
      return {
        bind(...values) {
          return {
            async first() {
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
