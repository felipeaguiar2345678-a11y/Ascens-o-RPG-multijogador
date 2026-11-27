import test from "node:test";
import assert from "node:assert/strict";
import { validarNamespacesDurableObjects } from "../scripts/preflight-durable-objects.mjs";

const namespaceValido = {
  id: "namespace-id-de-teste",
  name: "AI_BUDGET",
  class: "MonthlyAIBudget",
  script: "ascensao-soberano-api",
  use_sqlite: true,
};

test("aprova o namespace SQLite esperado e ignora outros Workers", () => {
  const resultado = validarNamespacesDurableObjects({
    success: true,
    result: [namespaceValido, { ...namespaceValido, script: "outro-worker", class: "OutraClasse" }],
  });
  assert.deepEqual(resultado, { classe: "MonthlyAIBudget", armazenamento: "sqlite" });
});

test("bloqueia quando o namespace esperado não existe", () => {
  assert.throws(
    () => validarNamespacesDurableObjects({ success: true, result: [] }),
    /exatamente um namespace/,
  );
});

test("bloqueia classes extras ainda não auditadas do mesmo Worker", () => {
  assert.throws(
    () => validarNamespacesDurableObjects({
      success: true,
      result: [namespaceValido, { ...namespaceValido, id: "segundo", class: "ClasseExtra" }],
    }),
    /encontrados 2/,
  );
});

test("bloqueia se a classe provisionada for diferente", () => {
  assert.throws(
    () => validarNamespacesDurableObjects({
      success: true,
      result: [{ ...namespaceValido, class: "ClasseDiferente" }],
    }),
    /Classe provisionada inesperada/,
  );
});

test("bloqueia se o armazenamento não for SQLite", () => {
  assert.throws(
    () => validarNamespacesDurableObjects({
      success: true,
      result: [{ ...namespaceValido, use_sqlite: false }],
    }),
    /não foi confirmado como SQLite/,
  );
});

test("bloqueia resposta incompleta da API", () => {
  assert.throws(
    () => validarNamespacesDurableObjects({ success: false, result: [] }),
    /lista válida de namespaces/,
  );
});
