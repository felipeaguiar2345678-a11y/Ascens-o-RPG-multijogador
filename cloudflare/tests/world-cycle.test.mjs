import test from "node:test";
import assert from "node:assert/strict";
import worker from "../worker.js";

const secret = "c".repeat(64);
const owner = "host-principal";
const leaseToken = "a".repeat(64);
const worldId = "ascensao_global";
const keys = ["ecological_resources", ...Array.from({ length: 16 }, (_, i) => "wildlife_groups_" + i.toString(16).padStart(2, "0"))];

function makeD1({ failAfterStatement = -1, takeoverOnBatchStart = false } = {}) {
  let failureIndex = failAfterStatement;
  const documents = new Map();
  const transactions = new Map();
  const lease = { owner_id: owner, lease_token: leaseToken, expires_at: Date.now() + 60000 };
  let pendingTakeover = takeoverOnBatchStart;
  return {
    documents,
    transactions,
    setFailureIndex(index) { failureIndex = index; },
    takeLease(newOwner, newToken) {
      lease.owner_id = newOwner;
      lease.lease_token = newToken;
      lease.expires_at = Date.now() + 60000;
    },
    async batch(statements) {
      if (pendingTakeover) {
        pendingTakeover = false;
        lease.owner_id = "host-secundario";
        lease.lease_token = "b".repeat(64);
        lease.expires_at = Date.now() + 60000;
      }
      const oldDocs = new Map([...documents].map(([k, v]) => [k, { ...v }]));
      const oldTransactions = new Map([...transactions].map(([k, v]) => [k, { ...v }]));
      try {
        for (let statementIndex = 0; statementIndex < statements.length; statementIndex++) {
          const statement = statements[statementIndex];
          const { sql, values } = statement;
          if (sql.startsWith("INSERT INTO world_cycle_transactions")) {
            const [w, id, nonce, fingerprint, createdAt] = values;
            const guardValues = values.slice(5, 5 + keys.length * 3);
            const leaseValues = values.slice(5 + keys.length * 3);
            let valid = w === worldId && leaseValues[0] === worldId &&
              leaseValues[1] === lease.owner_id && leaseValues[2] === lease.lease_token &&
              lease.expires_at > leaseValues[3];
            for (let i = 0; i < keys.length; i++) {
              const [guardWorld, key, expected] = guardValues.slice(i * 3, i * 3 + 3);
              const row = documents.get(guardWorld + ":" + key);
              if (guardWorld !== worldId || (row?.revision ?? 0) !== expected) valid = false;
            }
            if (valid && !transactions.has(w + ":" + id)) {
              transactions.set(w + ":" + id, { nonce, fingerprint, created_at: createdAt });
            }
          } else if (sql.startsWith("INSERT INTO world_documents")) {
            const [w, key, revision, payload, updatedAt, txWorld, txId, nonce,
              leaseWorld, leaseOwner, leaseTokenValue, leaseExpiresAt] =
              [values[0], values[1], 1, values[2], values[3], values[4], values[5], values[6],
                values[7], values[8], values[9], values[10]];
            const tx = transactions.get(txWorld + ":" + txId);
            const validLease = leaseWorld === worldId && leaseOwner === lease.owner_id &&
              leaseTokenValue === lease.lease_token && lease.expires_at > leaseExpiresAt;
            if (validLease && tx?.nonce === nonce && !documents.has(w + ":" + key)) {
              documents.set(w + ":" + key, { revision, payload, updated_at: updatedAt });
            }
          } else if (sql.startsWith("UPDATE world_documents")) {
            const [payload, updatedAt, w, key, expected, txWorld, txId, nonce,
              leaseWorld, leaseOwner, leaseTokenValue, leaseExpiresAt] = values;
            const row = documents.get(w + ":" + key);
            const tx = transactions.get(txWorld + ":" + txId);
            const validLease = leaseWorld === worldId && leaseOwner === owner &&
              leaseTokenValue === leaseToken && lease.expires_at > leaseExpiresAt;
            if (validLease && row && row.revision === expected && tx?.nonce === nonce) {
              row.revision += 1;
              row.payload = payload;
              row.updated_at = updatedAt;
            }
          }
          if (statementIndex === failureIndex) throw new Error("falha simulada durante o batch");
        }
        return statements.map(() => ({ success: true, results: [] }));
      } catch (error) {
        documents.clear(); for (const [k, v] of oldDocs) documents.set(k, v);
        transactions.clear(); for (const [k, v] of oldTransactions) transactions.set(k, v);
        throw error;
      }
    },
    prepare(sql) {
      return {
        bind(...values) {
          return {
            sql, values,
            async first() {
              if (sql.startsWith("SELECT owner_id, lease_token, expires_at")) return { ...lease };
              if (sql.startsWith("SELECT nonce, fingerprint FROM world_cycle_transactions")) {
                const tx = transactions.get(values[0] + ":" + values[1]);
                return tx ? { ...tx } : null;
              }
              if (sql.startsWith("SELECT revision FROM world_documents")) {
                const row = documents.get(values[0] + ":" + values[1]);
                return row ? { revision: row.revision } : null;
              }
              return null;
            }
          };
        }
      };
    }
  };
}

function makeDocuments(expectedRevision = 0, suffix = "base") {
  return keys.map((key) => ({
    key,
    expectedRevision,
    payload: { marker: suffix, key }
  }));
}

function makeRequest(body, token = secret, serverId = owner, serverLeaseToken = leaseToken) {
  return new Request("https://api.example.test/api/server/world-cycle", {
    method: "POST",
    headers: {
      Authorization: "Bearer " + token,
      "Content-Type": "application/json",
      "X-World-Server-ID": serverId,
      "X-World-Lease-Token": serverLeaseToken
    },
    body: JSON.stringify(body)
  });
}


test("perda da lease entre a leitura inicial e o batch bloqueia o host antigo e permite takeover limpo", async () => {
  const db = makeD1({ takeoverOnBatchStart: true });
  const env = { WORLD_STATE: db, WORLD_STORAGE_TOKEN: secret };
  const body = { transactionId: "8".repeat(32), documents: makeDocuments(0, "host-antigo") };

  const staleHost = await worker.fetch(makeRequest(body), env);
  assert.equal(staleHost.status, 409);
  assert.equal((await staleHost.json()).error, "WORLD_CYCLE_REVISION_CONFLICT");
  assert.equal(db.documents.size, 0, "o host antigo não pode gravar nenhum dos 17 documentos");
  assert.equal(db.transactions.size, 0, "o host antigo não pode deixar transação órfã");

  const newOwner = "host-secundario";
  const newToken = "b".repeat(64);
  const newHost = await worker.fetch(makeRequest(body, secret, newOwner, newToken), env);
  assert.equal(newHost.status, 200);
  assert.equal(db.documents.size, 17, "o novo host conclui o ciclo inteiro");
  assert.equal(db.transactions.size, 1, "somente a transação válida fica registrada");
  for (const key of keys) {
    const row = db.documents.get(worldId + ":" + key);
    assert.equal(row.revision, 1);
    assert.equal(JSON.parse(row.payload).marker, "host-antigo");
  }
});

test("world cycle commits resources and all 16 fauna shards atomically", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const body = { transactionId: "1".repeat(32), documents: makeDocuments() };
  const response = await worker.fetch(makeRequest(body), env);
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.equal(Object.keys(result.revisions).length, 17);
  for (const key of keys) {
    const row = env.WORLD_STATE.documents.get(worldId + ":" + key);
    assert.equal(row.revision, 1);
    assert.deepEqual(JSON.parse(row.payload), { marker: "base", key });
  }
});

test("a stale revision rejects the entire cycle without partial writes", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const seeded = { transactionId: "2".repeat(32), documents: makeDocuments() };
  assert.equal((await worker.fetch(makeRequest(seeded), env)).status, 200);
  const stale = { transactionId: "3".repeat(32), documents: makeDocuments(0, "must-not-appear") };
  const response = await worker.fetch(makeRequest(stale), env);
  assert.equal(response.status, 409);
  for (const key of keys) {
    const row = env.WORLD_STATE.documents.get(worldId + ":" + key);
    assert.equal(row.revision, 1);
    assert.equal(JSON.parse(row.payload).marker, "base");
  }
});

test("world cycle retries are idempotent and transaction IDs cannot be reused with other data", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const body = { transactionId: "4".repeat(32), documents: makeDocuments() };
  assert.equal((await worker.fetch(makeRequest(body), env)).status, 200);
  const replay = await worker.fetch(makeRequest(body), env);
  assert.equal(replay.status, 200);
  assert.equal((await replay.json()).replayed, true);
  const changed = { transactionId: body.transactionId, documents: makeDocuments(0, "different") };
  const conflict = await worker.fetch(makeRequest(changed), env);
  assert.equal(conflict.status, 409);
  assert.equal(env.WORLD_STATE.documents.size, 17);
});

test("world cycle requires server authorization and complete shard set", async () => {
  const env = { WORLD_STATE: makeD1(), WORLD_STORAGE_TOKEN: secret };
  const body = { transactionId: "5".repeat(32), documents: makeDocuments().slice(0, 16) };
  assert.equal((await worker.fetch(makeRequest(body), env)).status, 400);
  assert.equal((await worker.fetch(makeRequest({ transactionId: "6".repeat(32), documents: makeDocuments() }, "wrong"), env)).status, 401);
  assert.equal(env.WORLD_STATE.documents.size, 0);
});


test("a falha no meio do batch reverte todos os documentos e permite retry", async () => {
  const db = makeD1({ failAfterStatement: 8 });
  const env = { WORLD_STATE: db, WORLD_STORAGE_TOKEN: secret };
  const body = { transactionId: "7".repeat(32), documents: makeDocuments() };
  const failed = await worker.fetch(makeRequest(body), env);
  assert.equal(failed.status, 503);
  assert.equal(db.documents.size, 0);
  assert.equal(db.transactions.size, 0);

  db.setFailureIndex(-1);
  const retry = await worker.fetch(makeRequest(body), env);
  assert.equal(retry.status, 200);
  assert.equal(db.documents.size, 17);
});


test("qualquer ponto de falha do batch reverte os 17 documentos e permite recuperar", async () => {
  // O batch contém uma instrução para registrar a transação e 17 gravações
  // (estoques + 16 fragmentos). Simula queda depois de cada instrução.
  for (let failureIndex = 0; failureIndex < 18; failureIndex++) {
    const db = makeD1({ failAfterStatement: failureIndex });
    const env = { WORLD_STATE: db, WORLD_STORAGE_TOKEN: secret };
    const body = {
      transactionId: (failureIndex + 10).toString(16).padStart(32, "0"),
      documents: makeDocuments(0, "recovery-" + failureIndex)
    };

    const failed = await worker.fetch(makeRequest(body), env);
    assert.equal(failed.status, 503, "falha na instrução " + failureIndex);
    assert.equal(db.documents.size, 0, "nenhum documento parcial após instrução " + failureIndex);
    assert.equal(db.transactions.size, 0, "nenhuma transação órfã após instrução " + failureIndex);

    db.setFailureIndex(-1);
    const recovered = await worker.fetch(makeRequest(body), env);
    assert.equal(recovered.status, 200, "retry após instrução " + failureIndex);
    assert.equal(db.documents.size, 17, "todos os documentos após retry " + failureIndex);
    assert.equal(db.transactions.size, 1, "uma única transação após retry " + failureIndex);
    for (const key of keys) {
      const row = db.documents.get(worldId + ":" + key);
      assert.equal(row.revision, 1, "revisão única para " + key + " após retry " + failureIndex);
      assert.equal(JSON.parse(row.payload).marker, "recovery-" + failureIndex);
    }
  }
});
