import test from "node:test";
import assert from "node:assert/strict";
import { validateAdventureStory, estimateAdventureTokens, readRetryAfterSeconds, buildLocalAdventureFallback } from "./adventure-route.js";

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
  bossEncounter: false,
  missionObjectiveCompleted: false
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

test("aceita conclusão de missão apenas sem encontro pendente", () => {
  assert.equal(validateAdventureStory({
    ...base,
    missionObjectiveCompleted: true
  }), true);
});

test("rejeita conclusão de missão no mesmo turno em que surge um inimigo", () => {
  assert.equal(validateAdventureStory({
    ...base,
    encounter: true,
    creatureHint: "Um lobo espectral de olhos azulados",
    missionObjectiveCompleted: true
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


test("estima tokens com margem de segurança", () => {
  const estimate = estimateAdventureTokens({
    characterName: "Aventureiro", location: "Clareira Inicial",
    ecosystemId: "floresta_arcana", biome: "floresta",
    action: "Investigar os rastros",
    history: [{ role: "player", text: "Ouço um barulho." }]
  });
  assert.ok(estimate >= 1800);
  assert.ok(estimate <= 20000);
});

test("limita a estimativa de tokens para históricos extensos", () => {
  const estimate = estimateAdventureTokens({
    characterName: "Aventureiro", location: "Clareira Inicial",
    ecosystemId: "floresta_arcana", biome: "floresta",
    action: "Investigar",
    history: Array.from({ length: 8 }, () => ({ role: "player", text: "x".repeat(1600) }))
  });
  assert.ok(estimate > 1800);
  assert.ok(estimate <= 20000);
});


test("interpreta Retry-After em segundos", () => {
  const headers = new Headers({ "Retry-After": "12" });
  assert.equal(readRetryAfterSeconds(headers), 12);
});

test("interpreta janela de reset de requisições", () => {
  const headers = new Headers({ "x-ratelimit-reset-requests": "1m2s" });
  assert.equal(readRetryAfterSeconds(headers), 62);
});

test("não inventa tempo de espera quando o provedor não informa", () => {
  assert.equal(readRetryAfterSeconds(new Headers()), null);
});


test("fallback local permite continuar a aventura sem chamar a IA", () => {
  const fallback = buildLocalAdventureFallback({
    characterName: "Aventureiro",
    location: "Clareira Inicial",
    action: "Subir pela trilha e investigar o sino"
  }, "OPENAI_RATE_LIMITED");
  assert.equal(fallback.fallback, true);
  assert.equal(fallback.model, "narrador_local");
  assert.equal(fallback.costBRL, 0);
  assert.equal(fallback.encounter, false);
  assert.equal(fallback.bossEncounter, false);
  assert.equal(fallback.choices.length, 4);
  assert.match(fallback.narrative, /Subir pela trilha e investigar o sino/);
  assert.match(fallback.narrative, /Clareira Inicial/);
  assert.equal(validateAdventureStory(fallback), true);
});

test("fallback local sanitiza marcação e mantém quatro escolhas distintas", () => {
  const fallback = buildLocalAdventureFallback({
    location: "<script>alert(1)</script>",
    action: "  testar   <b>uma ação</b>  "
  });
  assert.doesNotMatch(fallback.narrative, /<script>|<b>/);
  assert.equal(new Set(fallback.choices).size, 4);
  assert.equal(validateAdventureStory(fallback), true);
});


test("fallback local cria consequências diferentes conforme a ação", () => {
  const investigate = buildLocalAdventureFallback({
    location: "Clareira Inicial",
    action: "Investigar os rastros"
  });
  const travel = buildLocalAdventureFallback({
    location: "Clareira Inicial",
    action: "Seguir pela trilha"
  });
  assert.notEqual(investigate.narrative, travel.narrative);
  assert.notDeepEqual(investigate.choices, travel.choices);
  assert.equal(validateAdventureStory(investigate), true);
  assert.equal(validateAdventureStory(travel), true);
});

test("fallback local varia a cena conforme o histórico avança", () => {
  const first = buildLocalAdventureFallback({
    location: "Clareira Inicial",
    action: "Observar a clareira",
    history: []
  });
  const later = buildLocalAdventureFallback({
    location: "Clareira Inicial",
    action: "Observar a clareira",
    history: [
      { role: "player", text: "Observar a clareira" },
      { role: "assistant", text: first.narrative },
      { role: "player", text: "Olhar novamente" },
      { role: "assistant", text: first.narrative }
    ]
  });
  assert.notEqual(first.narrative, later.narrative);
});
