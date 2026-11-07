import { afterEach, describe, expect, it, vi } from "vitest";
import { handleCreatureImageGeneration } from "../creature-image-route.js";

afterEach(() => {
  vi.unstubAllGlobals();
});

function request(token = "firebase-test-token") {
  return new Request("https://worker.test/api/creatures/image", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ creatureId: "criatura_teste_01" }),
  });
}

function firestoreDocument(ownerUid) {
  return new Response(JSON.stringify({
    fields: {
      criadoPorUid: { stringValue: ownerUid },
      nome: { stringValue: "Lobo de Teste" },
      descricao: { stringValue: "Uma criatura de teste." },
      bioma: { stringValue: "floresta" },
    },
  }), { status: 200 });
}

describe("Geração de imagem de criatura", () => {
  it("encaminha o token Firebase corretamente e só então consulta imagem existente", async () => {
    const externalFetch = vi.fn(async () => firestoreDocument("jogador-123"));
    vi.stubGlobal("fetch", externalFetch);
    const head = vi.fn(async () => ({ size: 1234 }));
    const env = {
      OPENAI_API_KEY: "fake-openai-key",
      FIREBASE_PROJECT_ID: "ascensao-do-soberano",
      IMAGENS_R2: { head },
      AI_BUDGET: {},
    };

    const response = await handleCreatureImageGeneration(
      request(),
      env,
      { valid: true, uid: "jogador-123" },
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      status: "already_generated",
      imageId: "criatura_teste_01",
      sizeBytes: 1234,
      actualBRL: 0,
    });
    expect(externalFetch).toHaveBeenCalledTimes(1);
    expect(externalFetch.mock.calls[0][1].headers.Authorization).toBe(
      "Bearer firebase-test-token",
    );
    expect(head).toHaveBeenCalledWith("criaturas/criatura_teste_01.png");
  });

  it("não consulta o R2 quando a criatura pertence a outro jogador", async () => {
    const externalFetch = vi.fn(async () => firestoreDocument("outro-jogador"));
    vi.stubGlobal("fetch", externalFetch);
    const head = vi.fn();
    const env = {
      OPENAI_API_KEY: "fake-openai-key",
      FIREBASE_PROJECT_ID: "ascensao-do-soberano",
      IMAGENS_R2: { head },
      AI_BUDGET: {},
    };

    const response = await handleCreatureImageGeneration(
      request(),
      env,
      { valid: true, uid: "jogador-123" },
    );

    expect(response.status).toBe(403);
    expect((await response.json()).error).toBe("CREATURE_OWNER_REQUIRED");
    expect(head).not.toHaveBeenCalled();
  });
});
