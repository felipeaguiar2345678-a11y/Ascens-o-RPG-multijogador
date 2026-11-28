import test from "node:test";
import assert from "node:assert/strict";
import { validarNamespacesDurableObjects } from "../scripts/preflight-durable-objects.mjs";

const budgetValido = {
  id: "namespace-budget",
  name: "AI_BUDGET",
  class: "MonthlyAIBudget",
  script: "ascensao-soberano-api",
  use_sqlite: true,
};
const legadoSqlite = {
  id: "namespace-legado",
  name: "WORLD_STATE",
  class: "PersistentWorldState",
  script: "ascensao-soberano-api",
  use_sqlite: true,
};

test("aprova os dois namespaces conhecidos e preserva o backend SQLite legado", () => {
  const resultado = validarNamespacesDurableObjects({
    success: true,
    result: [budgetValido, legadoSqlite, { ...budgetValido, script: "outro-worker", class: "OutraClasse" }],
  });
  assert.deepEqual(resultado, {
    classe: "MonthlyAIBudget",
    armazenamento: "sqlite",
    classeLegada: "PersistentWorldState",
    armazenamentoLegado: "sqlite",
  });
});

test("identifica e preserva namespace legado com backend legacy-kv", () => {
  const resultado = validarNamespacesDurableObjects({
    success: true,
    result: [budgetValido, { ...legadoSqlite, use_sqlite: false }],
  });
  assert.equal(resultado.armazenamentoLegado, "legacy-kv");
});

test("bloqueia quando um namespace esperado não existe", () => {
  assert.throws(
    () => validarNamespacesDurableObjects({ success: true, result: [budgetValido] }),
    /Esperados exatamente 2 namespaces/,
  );
});

test("bloqueia classes extras ainda não auditadas do mesmo Worker", () => {
  assert.throws(
    () => validarNamespacesDurableObjects({
      success: true,
      result: [budgetValido, legadoSqlite, { ...budgetValido, id: "extra", class: "ClasseExtra" }],
    }),
    /Esperados exatamente 2 namespaces/,
  );
});

test("bloqueia se MonthlyAIBudget não for SQLite", () => {
  assert.throws(
    () => validarNamespacesDurableObjects({
      success: true,
      result: [{ ...budgetValido, use_sqlite: false }, legadoSqlite],
    }),
    /MonthlyAIBudget não foi confirmado como SQLite/,
  );
});

test("bloqueia quando o backend legado não foi informado", () => {
  const { use_sqlite, ...semBackend } = legadoSqlite;
  assert.throws(
    () => validarNamespacesDurableObjects({
      success: true,
      result: [budgetValido, semBackend],
    }),
    /não informou o backend/,
  );
});

test("bloqueia resposta incompleta da API", () => {
  assert.throws(
    () => validarNamespacesDurableObjects({ success: false, result: [] }),
    /lista válida de namespaces/,
  );
});
