import test from "node:test";
import assert from "node:assert/strict";
import { validateAdventureStory } from "./adventure-route.js";

const base = {
  chapterTitle: "Ecos na floresta",
  narrative: "Você ouve galhos se partindo atrás das árvores.",
  choices: [
    "Investigar os rastros",
    "Preparar uma defesa",
    "Recuar em silêncio",
    "Chamar por quem está escondido"
  ],
  encounter: false,
  creatureHint: "",
  bossEncounter: false
};

test("aceita uma cena narrativa sem combate", () => {
  assert.equal(validateAdventureStory(base), true);
});

test("aceita encontro quando a criatura está identificada", () => {
  assert.equal(validateAdventureStory({
    ...base,
    encounter: true,
    creatureHint: "Um lobo espectral de olhos azulados"
  }), true);
});

test("rejeita encontro sem pista que permita materializar a criatura", () => {
  assert.equal(validateAdventureStory({
    ...base,
    encounter: true,
    creatureHint: ""
  }), false);
});

test("rejeita chefe sem encontro", () => {
  assert.equal(validateAdventureStory({
    ...base,
    bossEncounter: true
  }), false);
});

test("rejeita escolhas repetidas", () => {
  assert.equal(validateAdventureStory({
    ...base,
    choices: [
      "Atacar o monstro",
      "Atacar o monstro",
      "Fugir",
      "Conversar"
    ]
  }), false);
});

test("rejeita pista de criatura quando não existe encontro", () => {
  assert.equal(validateAdventureStory({
    ...base,
    creatureHint: "Serpente de cristal"
  }), false);
});
