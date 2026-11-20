import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { MonthlyAIBudget } from "./worker.js";

function createBudget() {
  const db = new DatabaseSync(":memory:");
  const sql = {
    exec(query, ...params) {
      const normalized = query.trim().toUpperCase();
      if (normalized.startsWith("CREATE ")) {
        db.exec(query);
        return { toArray: () => [], rowsWritten: 0 };
      }
      if (normalized.startsWith("PRAGMA ")) {
        const statement = db.prepare(query);
        return { toArray: () => statement.all(...params), rowsWritten: 0 };
      }
      const statement = db.prepare(query);
      if (normalized.startsWith("SELECT ") || normalized.includes(" RETURNING ")) {
        return { toArray: () => statement.all(...params), rowsWritten: 0 };
      }
      const result = statement.run(...params);
      return { toArray: () => [], rowsWritten: Number(result.changes || 0) };
    }
  };
  const ctx = {
    storage: {
      sql,
      transactionSync(callback) {
        db.exec("BEGIN IMMEDIATE");
        try {
          const result = callback();
          db.exec("COMMIT");
          return result;
        } catch (error) {
          db.exec("ROLLBACK");
          throw error;
        }
      }
    }
  };
  return new MonthlyAIBudget(ctx, {});
}

async function post(budget, body) {
  const response = await budget.fetch(new Request("https://budget.internal/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ month: "2026-11", ...body })
  }));
  return { status: response.status, body: await response.json() };
}

const base = {
  operationKey: "group_abc_revision_4",
  inputHash: "a".repeat(64),
  reservationId: "shared_group_abc_revision_4"
};

test("somente a primeira chamada conquista a geração compartilhada", async () => {
  const budget = createBudget();
  const first = await post(budget, { action: "shared_adventure_begin", ...base });
  const replay = await post(budget, { action: "shared_adventure_begin", ...base });
  assert.equal(first.status, 200);
  assert.equal(first.body.mayGenerate, true);
  assert.equal(first.body.status, "PROCESSING");
  assert.equal(replay.status, 200);
  assert.equal(replay.body.mayGenerate, false);
  assert.equal(replay.body.status, "PROCESSING");
});

test("a mesma chave não aceita entrada diferente", async () => {
  const budget = createBudget();
  await post(budget, { action: "shared_adventure_begin", ...base });
  const conflict = await post(budget, {
    action: "shared_adventure_begin",
    ...base,
    inputHash: "b".repeat(64)
  });
  assert.equal(conflict.status, 409);
  assert.equal(conflict.body.error, "SHARED_ADVENTURE_KEY_CONFLICT");
});

test("resultado concluído é salvo e devolvido em repetição", async () => {
  const budget = createBudget();
  await post(budget, { action: "shared_adventure_begin", ...base });
  const story = { chapterTitle: "A ponte antiga", narrative: "A ponte range.", choices: ["A", "B", "C", "D"] };
  const saved = await post(budget, {
    action: "shared_adventure_complete",
    operationKey: base.operationKey,
    inputHash: base.inputHash,
    response: story
  });
  const replay = await post(budget, { action: "shared_adventure_begin", ...base });
  assert.equal(saved.status, 200);
  assert.deepEqual(saved.body.response, story);
  assert.equal(replay.body.mayGenerate, false);
  assert.equal(replay.body.status, "COMPLETED");
  assert.deepEqual(replay.body.response, story);
});

test("operação incerta fica bloqueada e não permite nova geração", async () => {
  const budget = createBudget();
  await post(budget, { action: "shared_adventure_begin", ...base });
  const marked = await post(budget, {
    action: "shared_adventure_uncertain",
    operationKey: base.operationKey,
    inputHash: base.inputHash
  });
  const replay = await post(budget, { action: "shared_adventure_begin", ...base });
  assert.equal(marked.body.uncertain, true);
  assert.equal(replay.body.status, "UNCERTAIN");
  assert.equal(replay.body.mayGenerate, false);
});

test("resultado não pode ser alterado depois de concluído", async () => {
  const budget = createBudget();
  await post(budget, { action: "shared_adventure_begin", ...base });
  const story = { narrative: "Cena original" };
  await post(budget, {
    action: "shared_adventure_complete",
    operationKey: base.operationKey,
    inputHash: base.inputHash,
    response: story
  });
  const attempt = await post(budget, {
    action: "shared_adventure_complete",
    operationKey: base.operationKey,
    inputHash: base.inputHash,
    response: { narrative: "Cena substituída" }
  });
  assert.deepEqual(attempt.body.response, story);
});
