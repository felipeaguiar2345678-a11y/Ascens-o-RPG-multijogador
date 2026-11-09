import test from "node:test";
import assert from "node:assert/strict";
import { powerLimits, validateGeneratedPower } from "./power-generation-route.js";

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
