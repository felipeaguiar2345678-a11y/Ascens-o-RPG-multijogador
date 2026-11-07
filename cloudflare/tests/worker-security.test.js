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
