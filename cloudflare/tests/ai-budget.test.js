import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

const MONTH = "2026-11";

function budgetStub(name) {
  return env.AI_BUDGET.get(env.AI_BUDGET.idFromName(name));
}

async function reserve(stub, data) {
  return stub.fetch("https://budget/reserve", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      month: MONTH,
      action: "reserve",
      category: "characters",
      reservationId: "test_" + crypto.randomUUID(),
      reserveMicros: 500000,
      ...data,
    }),
  });
}

async function settle(stub, reservationId, actualMicros) {
  return stub.fetch("https://budget/settle", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ month: MONTH, action: "settle", reservationId, actualMicros }),
  });
}

async function status(stub) {
  return stub.fetch("https://budget/status?month=" + MONTH);
}

describe("Controle mensal de orçamento de IA", () => {
  it("reserva saldo e liquida pelo custo real", async () => {
    const stub = budgetStub("test-settlement");
    const reservationId = "settle_" + crypto.randomUUID();

    const reserved = await reserve(stub, { reservationId, reserveMicros: 700000 });
    expect(reserved.status).toBe(200);
    expect((await reserved.json()).reservedMicros).toBe(700000);

    const settled = await settle(stub, reservationId, 250000);
    expect(settled.status).toBe(200);
    expect((await settled.json()).actualMicros).toBe(250000);

    const report = await (await status(stub)).json();
    expect(report.categories.characters.reservedMicros).toBe(0);
    expect(report.categories.characters.spentMicros).toBe(250000);
  });

  it("impede reserva duplicada", async () => {
    const stub = budgetStub("test-duplicate");
    const reservationId = "duplicate_" + crypto.randomUUID();

    const first = await reserve(stub, { reservationId, reserveMicros: 100000 });
    const second = await reserve(stub, { reservationId, reserveMicros: 100000 });

    expect(first.status).toBe(200);
    expect(second.status).toBe(409);
  });

  it("não aceita custo acima do valor reservado e mantém a reserva bloqueada", async () => {
    const stub = budgetStub("test-overrun");
    const reservationId = "overrun_" + crypto.randomUUID();

    const reserved = await reserve(stub, { reservationId, reserveMicros: 200000 });
    expect(reserved.status).toBe(200);

    const settled = await settle(stub, reservationId, 200001);
    expect(settled.status).toBe(409);

    const report = await (await status(stub)).json();
    expect(report.categories.characters.reservedMicros).toBe(200000);
    expect(report.categories.characters.spentMicros).toBe(0);
  });

  it("não permite que reservas simultâneas ultrapassem o limite mensal", async () => {
    const stub = budgetStub("test-concurrency");
    const attempts = await Promise.all([
      reserve(stub, { reservationId: "parallel_a", reserveMicros: 1500000 }),
      reserve(stub, { reservationId: "parallel_b", reserveMicros: 1500000 }),
    ]);

    expect(attempts.map((response) => response.status).sort()).toEqual([200, 429]);

    const report = await (await status(stub)).json();
    expect(report.categories.characters.reservedMicros).toBe(1500000);
    expect(
      report.categories.characters.reservedMicros + report.categories.characters.spentMicros
    ).toBeLessThanOrEqual(report.categories.characters.limitMicros);
  });

  it("lista reservas pendentes e remove da lista somente após custo conhecido", async () => {
    const stub = budgetStub("test-pending-reconciliation");
    const reservationId = "pending_" + crypto.randomUUID();

    const reserved = await reserve(stub, {
      reservationId,
      reserveMicros: 800000,
      category: "other_ai"
    });
    expect(reserved.status).toBe(200);

    const pendingResponse = await stub.fetch("https://budget/pending", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ month: MONTH, action: "list_pending" })
    });
    expect(pendingResponse.status).toBe(200);
    const pending = await pendingResponse.json();
    expect(pending.reservations).toContainEqual({
      reservationId,
      month: MONTH,
      category: "other_ai",
      reservedMicros: 800000,
      reservedBRL: 0.8
    });

    const unknownRelease = await stub.fetch("https://budget/release", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ month: MONTH, action: "release", reservationId })
    });
    expect(unknownRelease.status).toBe(400);

    const reconciled = await settle(stub, reservationId, 120000);
    expect(reconciled.status).toBe(200);

    const afterSettlement = await stub.fetch("https://budget/pending", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ month: MONTH, action: "list_pending" })
    });
    expect((await afterSettlement.json()).reservations).toEqual([]);
  });

  it("reserva todo o saldo restante somente uma vez", async () => {
    const stub = budgetStub("test-reserve-all");
    const firstId = "all_" + crypto.randomUUID();
    const first = await reserve(stub, {
      category: "other_ai",
      reservationId: firstId,
      reserveAllAvailable: true,
      minimumReserveMicros: 50000,
    });
    expect(first.status).toBe(200);
    expect((await first.json()).reservedMicros).toBe(48000000);

    const second = await reserve(stub, {
      category: "other_ai",
      reservationId: "all_" + crypto.randomUUID(),
      reserveAllAvailable: true,
      minimumReserveMicros: 50000,
    });
    expect(second.status).toBe(429);
  });
});
