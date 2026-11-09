import test from "node:test";
import assert from "node:assert/strict";
import { handlePowerGeneration, powerLimits, validateGeneratedPower } from "./power-generation-route.js";

const context = {
  level: 1,
  intelligence: 5,
  spirit: 5,
  maxMana: 40,
  affinities: { MAGIC: "MEDIUM", PHYSICAL: "HIGH" }
};

const validPower = {
  name: "Fagulha de Estrela",
  description: "Uma manifestação gravitacional instável.",
  concept: "Criar buracos negros e singularidades.",
  potential: "No auge, poderá formar uma singularidade real.",
  manifestation: "Um ponto minúsculo que atrai poeira e desequilibra um alvo.",
  awakeningNarrative: "A essência cósmica ainda não consegue sustentar sua própria gravidade.",
  originExplanation: "Nasceu de uma experiência de sobrevivência.",
  type: "GRAVITY",
  manaCost: 4,
  baseDamage: 8,
  cooldown: 2,
  durationTurns: 1,
  effects: ["Atração muito curta"],
  limitations: ["Alcance de um passo", "Desaparece após um instante"],
  evolutionStages: [
    { name: "Núcleo Devorador", description: "Atrai um inimigo por um breve momento.", requiredLevel: 3 },
    { name: "Singularidade Instável", description: "Cria um campo gravitacional curto.", requiredLevel: 6 },
    { name: "Horizonte Faminto", description: "Sustenta a singularidade por alguns segundos.", requiredLevel: 10 },
    { name: "Buraco Negro", description: "Manifesta uma singularidade real sob limites severos.", requiredLevel: 15 }
  ]
};

test("calcula limites iniciais conservadores sem limitar o conceito futuro", () => {
  const limits = powerLimits(1, 5, 5, 40);
  assert.equal(limits.maxDamage, 13);
  assert.equal(limits.maxManaCost, 10);
  assert.equal(limits.maxCooldown, 2);
});

test("aceita conceito cósmico com manifestação inicial fraca", () => {
  assert.equal(validateGeneratedPower(validPower, context), true);
});

test("rejeita dano acima do limite inicial mesmo com conceito válido", () => {
  assert.equal(validateGeneratedPower({ ...validPower, baseDamage: 99999 }, context), false);
});

test("rejeita custo de mana acima do orçamento do personagem", () => {
  assert.equal(validateGeneratedPower({ ...validPower, manaCost: 11 }, context), false);
});

test("rejeita evolução sem níveis crescentes acima do nível atual", () => {
  const stages = validPower.evolutionStages.map(s => ({ ...s }));
  stages[2].requiredLevel = stages[1].requiredLevel;
  assert.equal(validateGeneratedPower({ ...validPower, evolutionStages: stages }, context), false);
});

test("rejeita poder sem limitações", () => {
  assert.equal(validateGeneratedPower({ ...validPower, limitations: [] }, context), false);
});


test("não gera poder para personagem que pertence a outra conta", async () => {
  const response = await handlePowerGeneration(
    { characterId: "personagem_1", desire: { id: "despertar_1" } },
    { OPENAI_API_KEY: "test", AI_BUDGET: {} },
    { uid: "jogador_autenticado" },
    { fields: { ownerUid: { stringValue: "outro_jogador" } } }
  );
  assert.equal(response.status, 403);
  assert.equal((await response.json()).error, "CHARACTER_NOT_OWNED");
});

test("não gera poder antes de o despertar alcançar o progresso mínimo", async () => {
  const response = await handlePowerGeneration(
    { characterId: "personagem_1", desire: { id: "despertar_1" } },
    { OPENAI_API_KEY: "test", AI_BUDGET: {} },
    { uid: "jogador_1" },
    {
      fields: {
        ownerUid: { stringValue: "jogador_1" },
        powerProfile: {
          mapValue: {
            fields: {
              desires: {
                arrayValue: {
                  values: [{
                    mapValue: {
                      fields: {
                        id: { stringValue: "despertar_1" },
                        progress: { integerValue: "19" }
                      }
                    }
                  }]
                }
              }
            }
          }
        }
      }
    }
  );
  assert.equal(response.status, 409);
  assert.equal((await response.json()).error, "AWAKENING_NOT_EARNED");
});

test("permite uma única habilidade inicial de classe sem exigir despertar conquistado", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response(JSON.stringify({
    output: [{ content: [{ type: "output_text", text: JSON.stringify(validPower) }] }],
    usage: { input_tokens: 100, output_tokens: 100 }
  }), { status: 200, headers: { "Content-Type": "application/json" } });
  try {
    const response = await handlePowerGeneration(
      { characterId: "personagem_1", desire: { id: "despertar_inicial_classe" } },
      {
        OPENAI_API_KEY: "test",
        AI_BUDGET: {
          idFromName: () => ({
            fetch: async () => new Response(JSON.stringify({ ok: true }), { status: 200 })
          })
        }
      },
      { uid: "jogador_1" },
      {
        fields: {
          ownerUid: { stringValue: "jogador_1" },
          name: { stringValue: "Aventureiro" },
          level: { integerValue: "1" },
          characterClass: { mapValue: { fields: {
            name: { stringValue: "Guerreiro" },
            affinities: { mapValue: { fields: {
              PHYSICAL: { stringValue: "HIGH" },
              MAGIC: { stringValue: "LOW" }
            } } }
          } } },
          attributes: { mapValue: { fields: {
            strength: { integerValue: "5" }, intelligence: { integerValue: "5" },
            agility: { integerValue: "5" }, vitality: { integerValue: "5" },
            spirit: { integerValue: "5" }
          } } },
          powerProfile: { mapValue: { fields: {
            desires: { arrayValue: { values: [{ mapValue: { fields: {
              id: { stringValue: "despertar_inicial_classe" },
              name: { stringValue: "Afinidade de Guerreiro" },
              description: { stringValue: "Técnica inicial de combate físico." },
              desiredType: { stringValue: "PHYSICAL" },
              progress: { integerValue: "100" }
            } } }] } },
            powers: { arrayValue: { values: [] } },
            observations: { arrayValue: { values: [] } }
          } } }
        }
      }
    );
    assert.equal(response.status, 201);
    assert.equal((await response.json()).origin, "DISCOVERY");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("não permite gerar habilidade inicial de classe pela segunda vez", async () => {
  const response = await handlePowerGeneration(
    { characterId: "personagem_1", desire: { id: "despertar_inicial_classe" } },
    { OPENAI_API_KEY: "test", AI_BUDGET: {} },
    { uid: "jogador_1" },
    {
      fields: {
        ownerUid: { stringValue: "jogador_1" },
        powerProfile: { mapValue: { fields: {
          desires: { arrayValue: { values: [{ mapValue: { fields: {
            id: { stringValue: "despertar_inicial_classe" },
            progress: { integerValue: "100" }
          } } }] } },
          powers: { arrayValue: { values: [{ mapValue: { fields: {
            originDesireId: { stringValue: "despertar_inicial_classe" }
          } } }] } }
        } } }
      }
    }
  );
  assert.equal(response.status, 409);
  assert.equal((await response.json()).error, "INVALID_CLASS_STARTER");
});
