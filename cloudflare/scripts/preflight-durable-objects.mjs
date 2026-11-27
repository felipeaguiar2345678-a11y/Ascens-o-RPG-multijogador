import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const API_BASE = "https://api.cloudflare.com/client/v4";
const SCRIPT_NAME = "ascensao-soberano-api";
const EXPECTED_CLASS = "MonthlyAIBudget";

export function validarNamespacesDurableObjects(resposta) {
  if (!resposta || resposta.success !== true || !Array.isArray(resposta.result)) {
    throw new Error("A API Cloudflare não retornou uma lista válida de namespaces.");
  }

  const namespacesDoWorker = resposta.result.filter(
    (namespace) => namespace && namespace.script === SCRIPT_NAME,
  );

  if (namespacesDoWorker.length !== 1) {
    throw new Error(
      `Esperado exatamente um namespace em ${SCRIPT_NAME}; encontrados ${namespacesDoWorker.length}. ` +
      "A publicação foi bloqueada para evitar alterar classes não auditadas.",
    );
  }

  const namespace = namespacesDoWorker[0];
  if (namespace.class !== EXPECTED_CLASS) {
    throw new Error(
      `Classe provisionada inesperada: ${String(namespace.class)}. ` +
      `Era esperado ${EXPECTED_CLASS}. A publicação foi bloqueada.`,
    );
  }

  if (namespace.use_sqlite !== true) {
    throw new Error(
      "O namespace MonthlyAIBudget não foi confirmado como SQLite. " +
      "A publicação foi bloqueada para não declarar um backend incorreto.",
    );
  }

  return { classe: EXPECTED_CLASS, armazenamento: "sqlite" };
}

async function listarTodosNamespaces(accountId, token) {
  const todos = [];
  let totalPaginas = 1;

  for (let pagina = 1; pagina <= totalPaginas; pagina += 1) {
    const url = new URL(`${API_BASE}/accounts/${encodeURIComponent(accountId)}/workers/durable_objects/namespaces`);
    url.searchParams.set("per_page", "1000");
    url.searchParams.set("page", String(pagina));

    const response = await fetch(url, {
      method: "GET",
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    });
    if (!response.ok) {
      throw new Error(`Consulta somente leitura do Cloudflare falhou (HTTP ${response.status}).`);
    }

    const body = await response.json();
    if (body.success !== true || !Array.isArray(body.result)) {
      throw new Error("A API Cloudflare recusou ou retornou uma resposta incompleta ao listar namespaces.");
    }
    todos.push(...body.result);

    const paginasInformadas = Number(body.result_info?.total_pages);
    if (!Number.isInteger(paginasInformadas) || paginasInformadas < 1) {
      throw new Error("A API Cloudflare não informou a paginação; não é seguro presumir que a lista está completa.");
    }
    totalPaginas = paginasInformadas;
  }

  return { success: true, result: todos };
}

async function main() {
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID?.trim();
  const token = process.env.CLOUDFLARE_API_TOKEN?.trim();
  if (!accountId || !token) {
    throw new Error("Configure CLOUDFLARE_ACCOUNT_ID e CLOUDFLARE_API_TOKEN nos segredos do GitHub.");
  }

  const namespaces = await listarTodosNamespaces(accountId, token);
  const confirmado = validarNamespacesDurableObjects(namespaces);
  console.log(`Preflight aprovado: ${confirmado.classe} existente com armazenamento ${confirmado.armazenamento}.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((error) => {
    console.error(`Preflight Cloudflare bloqueou a publicação: ${error.message}`);
    process.exitCode = 1;
  });
}
