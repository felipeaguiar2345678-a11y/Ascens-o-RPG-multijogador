import { describe, expect, it } from "vitest";
import { getBrazilianMonth } from "../worker.js";

describe("Virada mensal no horário de Brasília", () => {
  it("mantém o mês anterior até meia-noite em São Paulo", () => {
    expect(getBrazilianMonth(new Date("2026-11-01T02:59:59.000Z"))).toBe("2026-10");
  });

  it("inicia o novo mês exatamente à meia-noite em São Paulo", () => {
    expect(getBrazilianMonth(new Date("2026-11-01T03:00:00.000Z"))).toBe("2026-11");
  });

  it("considera corretamente a virada do ano", () => {
    expect(getBrazilianMonth(new Date("2027-01-01T02:59:59.000Z"))).toBe("2026-12");
    expect(getBrazilianMonth(new Date("2027-01-01T03:00:00.000Z"))).toBe("2027-01");
  });
});
