import test from "node:test";
import assert from "node:assert/strict";
import {
  seedAutonomousAdventurers,
  advanceAutonomousAdventurers
} from "./adventurer-ai.js";

const settlements = [
  { id: "aurelia", name: "Aurelia", condition: "NORMAL", hostileInvaders: 0 },
  { id: "cidade_do_sol", name: "Cidade do Sol", condition: "NORMAL", hostileInvaders: 0 }
];

const neighbors = {
  aurelia: ["cidade_do_sol"],
  cidade_do_sol: ["aurelia"]
};

test("seeds one persistent adventurer for each settlement", () => {
  const seeded = seedAutonomousAdventurers(settlements, 1000);
  assert.equal(seeded.length, 3);
  assert.equal(seeded.find((npc) => npc.currentLocationId === "clareira_inicial")?.name, "Ayla");
  assert.equal(seeded[0].role, "AVENTUREIRO");
  assert.equal(seeded[0].homeLocationId, "aurelia");
  assert.ok(seeded.every((npc) => npc.personality && npc.memories.length === 1));
});

test("critically wounded adventurer retreats toward home", () => {
  const npc = {
    ...seedAutonomousAdventurers(settlements, 1000)[0],
    currentLocationId: "cidade_do_sol",
    health: 10
  };
  const result = advanceAutonomousAdventurers(
    [npc], settlements, neighbors, 20_000, 1
  );
  assert.equal(result.adventurers[0].currentLocationId, "aurelia");
  assert.equal(result.adventurers[0].goal, "SOBREVIVER");
  assert.equal(result.adventurers[0].activity, "RETIRANDO");
});

test("curious adventurer chooses a neighboring settlement", () => {
  const npc = {
    ...seedAutonomousAdventurers(settlements, 1000)[0],
    personality: { courage: 100, caution: 0, curiosity: 100, ambition: 20 }
  };
  const result = advanceAutonomousAdventurers(
    [npc], settlements, neighbors, 20_000, 1
  );
  assert.equal(result.adventurers[0].targetLocationId, "cidade_do_sol");
  assert.equal(result.adventurers[0].activity, "PREPARANDO_VIAGEM");
});

test("ambitious adventurer can level up through training", () => {
  const npc = {
    ...seedAutonomousAdventurers(settlements, 1000)[0],
    level: 1,
    experience: 98,
    personality: { courage: 50, caution: 100, curiosity: 0, ambition: 100 }
  };
  const result = advanceAutonomousAdventurers(
    [npc], settlements, neighbors, 20_000, 1
  );
  assert.equal(result.adventurers[0].level, 2);
  assert.ok(result.events.some((event) => event.type === "AVENTUREIRO_EVOLUIU"));
});

test("sociable adventurers can form a party together", () => {
  const seeded = seedAutonomousAdventurers(settlements, 1000);
  const pair = seeded.map((npc) => ({
    ...npc,
    currentLocationId: "aurelia",
    personality: { courage: 50, caution: 100, curiosity: 0, ambition: 0, sociability: 95 }
  }));
  const result = advanceAutonomousAdventurers(
    pair, settlements, neighbors, 20_000, 1
  );
  assert.ok(result.adventurers.every((npc) => npc.partyId));
  assert.ok(result.adventurers.every((npc) => npc.relationships?.length > 0));
  assert.ok(result.events.some((event) => event.type === "GRUPO_DE_AVENTUREIROS_FORMADO"));
});
