import test from "node:test";
import assert from "node:assert/strict";
import worker from "../worker.js";

const secret = "teste-seguro-com-mais-de-trinta-e-dois-caracteres";

function makeD1() {
  const rows = new Map();
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
              if (sql.startsWith("SELECT revision FROM")) {
                const row = rows.get(values[0] + ":" + values[1]);
                return row ? { revision: row.revision } : null;
              }
              return null;
            },
            async all() {
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

function request(path, method = "GET", body = undefined, token = secret) {
  return new Request("https://api.example.test" + path, {
    method,
    headers: {
      ...(token ? { Authorization: "Bearer " + token } : {}),
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
  const first = await worker.fetch(request(path, "PUT", { expectedRevision: 0, payload: { day: 42 } }), env);
  assert.equal(first.status, 200);
  assert.equal((await first.json()).revision, 1);

  const conflict = await worker.fetch(request(path, "PUT", { expectedRevision: 0, payload: { day: 99 } }), env);
  assert.equal(conflict.status, 409);
  assert.equal((await conflict.json()).currentRevision, 1);

  const second = await worker.fetch(request(path, "PUT", { expectedRevision: 1, payload: { day: 43 } }), env);
  assert.equal(second.status, 200);
  assert.equal((await second.json()).revision, 2);

  const loaded = await worker.fetch(request(path), env);
  const document = await loaded.json();
  assert.equal(document.revision, 2);
  assert.deepEqual(document.payload, { day: 43 });
});

test("unknown document names and invalid payloads are rejected", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const unknown = await worker.fetch(request("/api/server/world-state/players"), env);
  assert.equal(unknown.status, 400);
  const invalid = await worker.fetch(request("/api/server/world-state/world_clock", "PUT", { expectedRevision: -1, payload: {} }), env);
  assert.equal(invalid.status, 400);
});
