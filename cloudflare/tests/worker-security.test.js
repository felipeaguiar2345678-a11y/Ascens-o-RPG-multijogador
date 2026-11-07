import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../worker.js";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("Proteção das rotas públicas do Worker", () => {
  it("bloqueia geração de criatura sem token Firebase antes de chamar serviços externos", async () => {
    const externalFetch = vi.fn();
    vi.stubGlobal("fetch", externalFetch);

    const response = await worker.fetch(
      new Request("https://worker.test/api/creatures/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          ecosystemId: "floresta_arcana",
          biome: "floresta",
          rank: "E",
          danger: 1,
          isBoss: false
        })
      }),
      {}
    );

    expect(response.status).toBe(401);
    expect((await response.json()).error).toBe("UNAUTHORIZED");
    expect(externalFetch).not.toHaveBeenCalled();
  });

  it("bloqueia envio de imagem sem token Firebase antes de acessar o armazenamento", async () => {
    const externalFetch = vi.fn();
    vi.stubGlobal("fetch", externalFetch);

    const response = await worker.fetch(
      new Request("https://worker.test/api/images/upload", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          imageId: "teste",
          contentType: "image/png",
          imageBase64: "aW1hZ2Vt"
        })
      }),
      { IMAGENS_R2: { put: vi.fn() } }
    );

    expect(response.status).toBe(401);
    expect((await response.json()).error).toBe("UNAUTHORIZED");
    expect(externalFetch).not.toHaveBeenCalled();
  });

  it("bloqueia consulta de reservas pendentes sem autenticação", async () => {
    const response = await worker.fetch(
      new Request("https://worker.test/admin/ai-budget/pending?month=2026-11"),
      { AI_BUDGET: { idFromName: vi.fn(), get: vi.fn() }, ADMIN_UID: "admin-uid" }
    );

    expect(response.status).toBe(401);
    expect((await response.json()).error).toBe("UNAUTHORIZED");
  });

  it("não expõe orçamento nem presença de segredos na rota pública de saúde", async () => {
    const response = await worker.fetch(
      new Request("https://worker.test/health"),
      {
        OPENAI_API_KEY: "segredo-de-teste",
        ADMIN_UID: "admin-uid",
        IMAGENS_R2: {},
        AI_BUDGET: {
          idFromName: vi.fn(() => "budget-id"),
          get: vi.fn(() => ({
            fetch: vi.fn(async () => new Response(JSON.stringify({
              used: 12,
              limit: 4000,
              categories: {
                other_ai: { reservedBRL: 48, spentBRL: 0, limitBRL: 48 }
              }
            }), { status: 200 }))
          }))
        }
      }
    );

    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body).toEqual({
      status: "online",
      service: "Ascensão do Soberano API",
      budgetGuardAvailable: true
    });
    expect(JSON.stringify(body)).not.toContain("segredo-de-teste");
    expect(body).not.toHaveProperty("monthlyAIBudget");
    expect(body).not.toHaveProperty("adminConfigured");
    expect(body).not.toHaveProperty("aiConfigured");
  });

  it("informa indisponibilidade do controle sem revelar detalhes internos", async () => {
    const response = await worker.fetch(
      new Request("https://worker.test/health"),
      {}
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      status: "online",
      service: "Ascensão do Soberano API",
      budgetGuardAvailable: false
    });
  });

  it("bloqueia reconciliação administrativa sem autenticação", async () => {
    const response = await worker.fetch(
      new Request("https://worker.test/admin/ai-budget/reconcile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ reservationId: "pending_test", actualMicros: 0 })
      }),
      { AI_BUDGET: { idFromName: vi.fn(), get: vi.fn() }, ADMIN_UID: "admin-uid" }
    );

    expect(response.status).toBe(401);
    expect((await response.json()).error).toBe("UNAUTHORIZED");
  });
});
