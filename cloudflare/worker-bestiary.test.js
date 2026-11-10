import test from "node:test";
import assert from "node:assert/strict";
import { PersistentWorldState, normalizeCreatureManaCosts, normalizeGeneratedCreature, buildCreatureRepairPrompt, creatureValidationIssues } from "./worker.js";

function createWorld() {
  const values = new Map();
  const storage = {
    async get(key) { return values.get(key); },
    async put(key, value) { values.set(key, structuredClone(value)); },
    async delete(key) { return values.delete(key); },
    async list(options = {}) {
      const prefix = options.prefix || "";
      return new Map([...values.entries()]
        .filter(([key]) => key.startsWith(prefix))
        .map(([key, value]) => [key, structuredClone(value)]));
    }
  };
  const world = new PersistentWorldState({ storage });
  world.testStorage = storage;
  return world;
}

async function post(world, path, body) {
  const response = await world.fetch(new Request("https://world" + path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  }));
  return { status: response.status, body: await response.json() };
}

async function publishPresence(world, uid, worldPointId) {
  return post(world, "/presence", {
    uid, worldPointId, x: 0.5, y: 0.5
  });
}

test("descoberta global conta cada jogador apenas uma vez", async () => {
  const world = createWorld();
  const first = await post(world, "/bestiary/encounter", {
    creatureId: "lobo_arcano", uid: "jogador-1", playerName: "Aventureiro 1"
  });
  const repeated = await post(world, "/bestiary/encounter", {
    creatureId: "lobo_arcano", uid: "jogador-1", playerName: "Aventureiro 1"
  });
  const second = await post(world, "/bestiary/encounter", {
    creatureId: "lobo_arcano", uid: "jogador-2", playerName: "Aventureiro 2"
  });

  assert.equal(first.status, 200);
  assert.equal(repeated.body.totalPlayersEncountered, 1);
  assert.equal(second.body.totalPlayersEncountered, 2);
  assert.equal(second.body.firstDiscovererUid, "jogador-1");
  assert.equal(second.body.firstDiscovererName, "Aventureiro 1");
});

test("encontro cooperativo não cria token de derrota individual", async () => {
  const world = createWorld();
  const result = await post(world, "/bestiary/encounter", {
    creatureId: "guardiao_ancestral",
    uid: "jogador-grupo",
    playerName: "Aventureiro",
    issueSoloToken: false
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.totalPlayersEncountered, 1);
  assert.equal(result.body.encounterToken, "");
});

test("vitória global é contabilizada uma única vez por batalha", async () => {
  const world = createWorld();
  const battle = {
    id: "batalha-123",
    creatureId: "dragao_antigo",
    status: "FINISHED",
    phase: "VICTORY",
    enemyHp: 0,
    enemyMaxHp: 370,
    activePlayerUid: "jogador-2",
    participantUids: ["jogador-1", "jogador-2"],
    members: [
      { uid: "jogador-1", name: "Aventureiro 1", damageDealt: 120 },
      { uid: "jogador-2", name: "Aventureiro 2", damageDealt: 250 }
    ]
  };

  const first = await post(world, "/bestiary/defeat", { battle });
  const duplicate = await post(world, "/bestiary/defeat", { battle });

  assert.equal(first.status, 200);
  assert.equal(first.body.registered, true);
  assert.equal(first.body.stats.totalDefeats, 1);
  assert.equal(first.body.stats.firstDefeaterUid, "jogador-2");
  assert.equal(first.body.stats.highestDamage, 250);
  assert.equal(first.body.stats.highestDamageUid, "jogador-2");
  assert.equal(first.body.stats.totalPlayersEncountered, 2);
  assert.equal(first.body.stats.mostDefeatsCount, 1);
  assert.equal(first.body.stats.mostDefeatsUid, "jogador-1");
  assert.equal(duplicate.body.duplicate, true);
  assert.equal(duplicate.body.stats.totalDefeats, 1);

  const nextBattle = {
    ...battle,
    id: "batalha-124",
    enemyHp: 0,
    enemyMaxHp: 80,
    activePlayerUid: "jogador-2",
    participantUids: ["jogador-2"],
    members: [{ uid: "jogador-2", name: "Aventureiro 2", damageDealt: 80 }]
  };
  const secondVictory = await post(world, "/bestiary/defeat", { battle: nextBattle });
  assert.equal(secondVictory.body.stats.totalDefeats, 2);
  assert.equal(secondVictory.body.stats.mostDefeatsUid, "jogador-2");
  assert.equal(secondVictory.body.stats.mostDefeatsCount, 2);
});

test("duas requisições simultâneas não duplicam a mesma vitória", async () => {
  const world = createWorld();
  const battle = {
    id: "batalha-concorrente",
    creatureId: "hidra_antiga",
    status: "FINISHED",
    phase: "VICTORY",
    enemyHp: 0,
    enemyMaxHp: 500,
    activePlayerUid: "jogador-1",
    participantUids: ["jogador-1", "jogador-2"],
    members: [
      { uid: "jogador-1", name: "Aventureiro 1", damageDealt: 300 },
      { uid: "jogador-2", name: "Aventureiro 2", damageDealt: 200 }
    ]
  };

  const results = await Promise.all([
    post(world, "/bestiary/defeat", { battle }),
    post(world, "/bestiary/defeat", { battle })
  ]);

  assert.equal(results.filter((result) => result.body.registered === true).length, 1);
  assert.equal(results.filter((result) => result.body.duplicate === true).length, 1);
  const stats = await world.fetch(new Request("https://world/bestiary/stats?id=hidra_antiga"));
  assert.equal((await stats.json()).totalDefeats, 1);
});

test("estatísticas vazias são retornadas para criatura sem registros", async () => {
  const world = createWorld();
  const response = await world.fetch(
    new Request("https://world/bestiary/stats?id=criatura_nova")
  );
  const stats = await response.json();

  assert.equal(response.status, 200);
  assert.equal(stats.creatureId, "criatura_nova");
  assert.equal(stats.totalDefeats, 0);
  assert.equal(stats.totalPlayersEncountered, 0);
});

test("vitória individual exige token de encontro e não duplica", async () => {
  const world = createWorld();
  const encounter = await post(world, "/bestiary/encounter", {
    creatureId: "urso_sombrio", uid: "jogador-solo", playerName: "Explorador"
  });
  const token = encounter.body.encounterToken;
  assert.equal(typeof token, "string");
  assert.ok(token.length > 20);

  const first = await post(world, "/bestiary/solo-defeat", {
    encounterToken: token, uid: "jogador-solo", damageDealt: 220
  });
  const duplicate = await post(world, "/bestiary/solo-defeat", {
    encounterToken: token, uid: "jogador-solo"
  });

  assert.equal(first.body.registered, true);
  assert.equal(first.body.stats.totalDefeats, 1);
  assert.equal(first.body.stats.firstDefeaterUid, "jogador-solo");
  assert.equal(first.body.stats.mostDefeatsCount, 1);
  assert.equal(first.body.stats.highestDamage, 220);
  assert.equal(first.body.stats.highestDamageUid, "jogador-solo");
  assert.equal(duplicate.body.duplicate, true);
  assert.equal(duplicate.body.stats.totalDefeats, 1);
});

test("token de encontro não pode ser usado por outro jogador", async () => {
  const world = createWorld();
  const encounter = await post(world, "/bestiary/encounter", {
    creatureId: "aranha_gelida", uid: "jogador-certo", playerName: "Explorador"
  });
  const result = await post(world, "/bestiary/solo-defeat", {
    encounterToken: encounter.body.encounterToken, uid: "jogador-falso"
  });
  assert.equal(result.status, 403);
});


test("consulta em lote retorna registros de várias criaturas", async () => {
  const world = createWorld();
  await post(world, "/bestiary/encounter", {
    creatureId: "raposa_arcana", uid: "jogador-1", playerName: "Explorador"
  });
  const response = await world.fetch(
    new Request("https://world/bestiary/stats-batch?ids=raposa_arcana,lobo_arcano")
  );
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.stats.length, 2);
  assert.equal(body.stats[0].creatureId, "raposa_arcana");
  assert.equal(body.stats[0].totalPlayersEncountered, 1);
  assert.equal(body.stats[1].creatureId, "lobo_arcano");
  assert.equal(body.stats[1].totalDefeats, 0);
});


test("token solo é reutilizado até a vitória e renovado no próximo encontro", async () => {
  const world = createWorld();
  const firstEncounter = await post(world, "/bestiary/encounter", {
    creatureId: "golem_de_pedra", uid: "jogador-1", playerName: "Aventureiro"
  });
  const repeatedEncounter = await post(world, "/bestiary/encounter", {
    creatureId: "golem_de_pedra", uid: "jogador-1", playerName: "Aventureiro"
  });
  assert.equal(firstEncounter.body.encounterToken, repeatedEncounter.body.encounterToken);

  const firstVictory = await post(world, "/bestiary/solo-defeat", {
    encounterToken: firstEncounter.body.encounterToken, uid: "jogador-1"
  });
  assert.equal(firstVictory.body.stats.totalDefeats, 1);

  const secondEncounter = await post(world, "/bestiary/encounter", {
    creatureId: "golem_de_pedra", uid: "jogador-1", playerName: "Aventureiro"
  });
  assert.notEqual(firstEncounter.body.encounterToken, secondEncounter.body.encounterToken);

  const secondVictory = await post(world, "/bestiary/solo-defeat", {
    encounterToken: secondEncounter.body.encounterToken, uid: "jogador-1"
  });
  assert.equal(secondVictory.body.stats.totalDefeats, 2);
  assert.equal(secondVictory.body.stats.mostDefeatsCount, 2);
});

test("registro global rejeita vitória com inimigo vivo ou dano insuficiente", async () => {
  const world = createWorld();
  const battle = {
    id: "batalha-sem-vitoria",
    creatureId: "dragao_antigo",
    status: "FINISHED",
    phase: "VICTORY",
    enemyHp: 1,
    enemyMaxHp: 370,
    activePlayerUid: "jogador-1",
    participantUids: ["jogador-1"],
    members: [{ uid: "jogador-1", name: "Aventureiro", damageDealt: 370 }]
  };

  const enemyAlive = await post(world, "/bestiary/defeat", { battle });
  assert.equal(enemyAlive.status, 400);
  assert.equal(enemyAlive.body.error, "INVALID_VICTORY");

  const damageInsufficient = await post(world, "/bestiary/defeat", {
    battle: { ...battle, id: "batalha-dano-insuficiente", enemyHp: 0, enemyMaxHp: 400 }
  });
  assert.equal(damageInsufficient.status, 400);
  assert.equal(damageInsufficient.body.error, "INVALID_VICTORY");
});

test("registro de vitória rejeita participantes inconsistentes", async () => {
  const world = createWorld();
  const invalidBattle = {
    id: "batalha-invalida",
    creatureId: "dragao_antigo",
    status: "FINISHED",
    phase: "VICTORY",
    activePlayerUid: "jogador-1",
    participantUids: ["jogador-1", "jogador-2"],
    members: [
      { uid: "jogador-1", name: "Aventureiro 1", damageDealt: 100 },
      { uid: "jogador-falso", name: "Intruso", damageDealt: 100 }
    ]
  };
  const result = await post(world, "/bestiary/defeat", { battle: invalidBattle });
  assert.equal(result.status, 400);
  assert.equal(result.body.error, "INVALID_VICTORY");
});


test("presença mundial valida deslocamento e compartilha posição oficial", async () => {
  const world = createWorld();
  const first = await post(world, "/presence", {
    uid: "jogador-1", nome: "Explorador", nivel: 4,
    worldPointId: "clareira_inicial", x: 0.5, y: 0.5
  });
  assert.equal(first.status, 200);
  assert.equal(first.body.accepted, true);

  const teleport = await post(world, "/presence", {
    uid: "jogador-1", nome: "Explorador", nivel: 4,
    worldPointId: "clareira_inicial", x: 20, y: 20
  });
  assert.equal(teleport.status, 200);
  assert.equal(teleport.body.accepted, false);
  assert.equal(teleport.body.presence.x, 0.5);
  assert.equal(teleport.body.presence.y, 0.5);

  const normalMovement = await post(world, "/presence", {
    uid: "jogador-1", nome: "Explorador", nivel: 4,
    worldPointId: "clareira_inicial", x: 0.52, y: 0.51
  });
  assert.equal(normalMovement.body.accepted, true);
  assert.equal(normalMovement.body.presence.x, 0.52);
  assert.equal(normalMovement.body.presence.y, 0.51);

  const nearby = await post(world, "/presence", {
    uid: "jogador-2", nome: "Companheiro", nivel: 2,
    worldPointId: "clareira_inicial", x: 0.52, y: 0.51
  });
  assert.equal(nearby.body.accepted, true);

  const response = await world.fetch(new Request(
    "https://world/presence?worldPointId=clareira_inicial"
  ));
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.players.length, 2);
  assert.deepEqual(
    body.players.map((player) => player.uid).sort(),
    ["jogador-1", "jogador-2"]
  );
});

test("presença mundial rejeita área ou coordenadas inválidas", async () => {
  const world = createWorld();
  const invalidArea = await post(world, "/presence", {
    uid: "jogador-1", worldPointId: "../aurelia", x: 0.5, y: 0.5
  });
  const invalidPosition = await post(world, "/presence", {
    uid: "jogador-1", worldPointId: "clareira_inicial", x: 1000, y: 0.5
  });
  assert.equal(invalidArea.status, 400);
  assert.equal(invalidPosition.status, 400);
});


test("criatura registrada recebe ponto fixo no mapa mundial", async () => {
  const world = createWorld();
  const first = await post(world, "/register-creature", {
    id: "criatura_lobo_arcano", ecosystemId: "dark_forest", danger: 35, rank: "D"
  });
  const stateResponse = await world.fetch(new Request("https://world/state"));
  const state = (await stateResponse.json()).state;
  const creature = state.populations.find((item) => item.speciesId === "criatura_lobo_arcano");
  assert.equal(first.status, 200);
  assert.equal(typeof creature.spawnX, "number");
  assert.equal(typeof creature.spawnY, "number");
  assert.ok(creature.spawnX >= 0.16 && creature.spawnX <= 0.84);
  assert.ok(creature.spawnY >= 0.16 && creature.spawnY <= 0.84);

  await post(world, "/register-creature", {
    id: "criatura_lobo_arcano", ecosystemId: "dark_forest", danger: 35, rank: "D"
  });
  const repeatedResponse = await world.fetch(new Request("https://world/state"));
  const repeatedState = (await repeatedResponse.json()).state;
  const repeated = repeatedState.populations.find((item) => item.speciesId === "criatura_lobo_arcano");
  assert.equal(repeated.spawnX, creature.spawnX);
  assert.equal(repeated.spawnY, creature.spawnY);
  assert.equal(repeatedState.populations.filter((item) => item.speciesId === "criatura_lobo_arcano").length, 1);
});


test("consulta de posições de criaturas retorna apenas o ecossistema solicitado", async () => {
  const world = createWorld();
  await post(world, "/register-creature", {
    id: "lobo_floresta", ecosystemId: "dark_forest", danger: 25, rank: "E"
  });
  await post(world, "/register-creature", {
    id: "escorpiao_deserto", ecosystemId: "ancestral_desert", danger: 55, rank: "B"
  });

  const response = await world.fetch(new Request(
    "https://world/creature-placements?ecosystemId=dark_forest"
  ));
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.creatures.length, 1);
  assert.equal(body.creatures[0].speciesId, "lobo_floresta");
  assert.equal(body.creatures[0].ecosystemId, "dark_forest");
});


test("presença do beta aceita a Floresta Arcana e Aurelia, mas bloqueia outras regiões", async () => {
  const world = createWorld();
  const floresta = await post(world, "/presence", {
    uid: "jogador-floresta", worldPointId: "clareira_inicial", x: 0.52, y: 0.78
  });
  const aurelia = await post(world, "/presence", {
    uid: "jogador-aurelia", worldPointId: "aurelia", x: 0.52, y: 0.12
  });
  const cidadeBloqueada = await post(world, "/presence", {
    uid: "jogador-bloqueado", worldPointId: "cidade_do_sol", x: 0.5, y: 0.5
  });
  const malacharBloqueada = await post(world, "/presence", {
    uid: "jogador-sombras", worldPointId: "malachar", x: 0.5, y: 0.5
  });

  assert.equal(floresta.status, 200);
  assert.equal(aurelia.status, 200);
  assert.equal(cidadeBloqueada.status, 400);
  assert.equal(malacharBloqueada.status, 400);
});


test("interação com NPC só funciona em Aurelia e na Floresta Arcana", async () => {
  const world = createWorld();
  await publishPresence(world, "jogador-aurelia", "aurelia");
  await publishPresence(world, "jogador-cidade", "aurelia");
  const remote = await post(world, "/npc/interact", {
    uid: "jogador-remoto", npcId: "npc_aurelia_comerciante", action: "CONVERSAR"
  });
  const aurelia = await post(world, "/npc/interact", {
    uid: "jogador-aurelia", npcId: "npc_aurelia_comerciante", action: "CONVERSAR"
  });
  const cidadeBloqueada = await post(world, "/npc/interact", {
    uid: "jogador-cidade", npcId: "npc_cidade_do_sol_comerciante", action: "CONVERSAR"
  });

  assert.equal(remote.status, 403);
  assert.equal(aurelia.status, 200);
  assert.equal(cidadeBloqueada.status, 404);
});


test("pedido de habitante exige aceite e só pode ser concluído uma vez", async () => {
  const world = createWorld();
  const state = await world.load();
  const npc = state.npcs.find(n => n.id === "npc_aurelia_morador");
  const problem = {
    id: "npc_problem_npc_aurelia_morador_test",
    npcId: npc.id,
    settlementId: "aurelia",
    type: "CONSEGUIR_ALIMENTOS",
    status: "ACTIVE",
    title: "Conseguir alimentos para Mira",
    description: "Mira precisa de alimentos.",
    createdAtMillis: Date.now(),
    expiresAtMillis: Date.now() + 60_000
  };
  state.npcProblems.push(problem);
  await world.testStorage.put("world", state);
  await publishPresence(world, "jogador-quest", "aurelia");
  await publishPresence(world, "outro-jogador", "aurelia");
  const completeBeforeAccept = await post(world, "/npc/interact", {
    uid: "jogador-quest", npcId: npc.id, problemId: problem.id, action: "AJUDAR_HABITANTE"
  });
  assert.equal(completeBeforeAccept.status, 409);

  const accepted = await post(world, "/npc/interact", {
    uid: "jogador-quest", npcId: npc.id, problemId: problem.id, action: "ACEITAR_PEDIDO"
  });
  assert.equal(accepted.status, 200);
  assert.equal(accepted.body.accepted, true);

  const secondPlayerRead = await world.fetch(new Request(
    "https://world/npcs?settlementId=aurelia&uid=outro-jogador"
  ));
  const secondPlayerData = await secondPlayerRead.json();
  const publicProblem = secondPlayerData.problems.find(p => p.id === problem.id);
  assert.equal(publicProblem.acceptedByMe, false);
  assert.equal("acceptedByUid" in publicProblem, false);

  const otherPlayerComplete = await post(world, "/npc/interact", {
    uid: "outro-jogador", npcId: npc.id, problemId: problem.id, action: "AJUDAR_HABITANTE"
  });
  assert.equal(otherPlayerComplete.status, 409);

  const completed = await post(world, "/npc/interact", {
    uid: "jogador-quest", npcId: npc.id, problemId: problem.id, action: "AJUDAR_HABITANTE"
  });
  assert.equal(completed.status, 200);
  assert.equal(completed.body.resolved, true);
  assert.equal(completed.body.relationshipGained, 5);

  const repeated = await post(world, "/npc/interact", {
    uid: "jogador-quest", npcId: npc.id, problemId: problem.id, action: "AJUDAR_HABITANTE"
  });
  assert.equal(repeated.status, 200);
  assert.equal(repeated.body.alreadyResolved, true);

  const otherAccepted = await post(world, "/npc/interact", {
    uid: "outro-jogador", npcId: npc.id, problemId: problem.id, action: "ACEITAR_PEDIDO"
  });
  assert.equal(otherAccepted.status, 200);
  const otherCompleted = await post(world, "/npc/interact", {
    uid: "outro-jogador", npcId: npc.id, problemId: problem.id, action: "AJUDAR_HABITANTE"
  });
  assert.equal(otherCompleted.status, 200);
  assert.equal(otherCompleted.body.resolved, true);
  assert.equal(otherCompleted.body.relationshipGained, 5);

  const publicAfterBoth = await world.fetch(new Request(
    "https://world/npcs?settlementId=aurelia&uid=outro-jogador"
  ));
  const publicAfterBothBody = await publicAfterBoth.json();
  const problemForOther = publicAfterBothBody.problems.find(p => p.id === problem.id);
  assert.equal(problemForOther.resolvedByMe, true);
  assert.equal("resolvedByUid" in problemForOther, false);
});

test("pedidos expirados ou sem prazo válido não podem ser aceitos", async () => {
  const world = createWorld();
  const state = await world.load();
  const npc = state.npcs.find((entry) => entry.id === "npc_aurelia_morador");
  const expired = {
    id: "npc_problem_npc_aurelia_morador_expired",
    npcId: npc.id,
    settlementId: "aurelia",
    type: "CONSEGUIR_ALIMENTOS",
    status: "ACTIVE",
    title: "Pedido expirado",
    description: "Este pedido já passou do prazo.",
    createdAtMillis: Date.now() - 1000,
    expiresAtMillis: Date.now() - 1
  };
  const missingDeadline = {
    id: "npc_problem_npc_aurelia_morador_no_deadline",
    npcId: npc.id,
    settlementId: "aurelia",
    type: "BUSCAR_AGUA",
    status: "ACTIVE",
    title: "Pedido sem prazo",
    description: "Este pedido não tem prazo válido.",
    createdAtMillis: Date.now()
  };
  state.npcProblems.push(expired, missingDeadline);
  await world.testStorage.put("world", state);
  await publishPresence(world, "jogador-prazo", "aurelia");

  for (const problem of [expired, missingDeadline]) {
    const result = await post(world, "/npc/interact", {
      uid: "jogador-prazo",
      npcId: npc.id,
      problemId: problem.id,
      action: "ACEITAR_PEDIDO"
    });
    assert.equal(result.status, 410);
    assert.equal(result.body.error, "NPC_PROBLEM_EXPIRED");
  }

  const persisted = await world.load();
  assert.equal(persisted.npcProblems.find((entry) => entry.id === expired.id).status, "EXPIRED");
  assert.equal(persisted.npcProblems.find((entry) => entry.id === missingDeadline.id).status, "EXPIRED");
});

test("conversa entrega diálogo contextual e promove a relação por faixa", async () => {
  const world = createWorld();
  const state = await world.load();
  const npc = state.npcs.find((entry) => entry.id === "npc_aurelia_morador");
  npc.relationshipByUid = { "jogador-dialogo": 29 };
  await world.testStorage.put("world", state);
  await publishPresence(world, "jogador-dialogo", "aurelia");

  const result = await post(world, "/npc/interact", {
    uid: "jogador-dialogo", npcId: npc.id, action: "CONVERSAR"
  });

  assert.equal(result.status, 200);
  assert.equal(result.body.npc.relationship, 30);
  assert.equal(result.body.relationshipTier, "AMIGO");
  assert.equal(result.body.npc.relationshipTier, "AMIGO");
  assert.equal(typeof result.body.dialogue, "string");
  assert.ok(result.body.dialogue.length > 20);
  assert.match(result.body.dialogue, /família|compartilhar/i);
});

test("conversa respeita intervalo e não permite farm de relação", async () => {
  const world = createWorld();
  const state = await world.load();
  const npc = state.npcs.find((entry) => entry.id === "npc_aurelia_guarda");
  await world.testStorage.put("world", state);
  await publishPresence(world, "jogador-cooldown", "aurelia");

  const first = await post(world, "/npc/interact", {
    uid: "jogador-cooldown", npcId: npc.id, action: "CONVERSAR"
  });
  const immediateRepeat = await post(world, "/npc/interact", {
    uid: "jogador-cooldown", npcId: npc.id, action: "CONVERSAR"
  });

  assert.equal(first.status, 200);
  assert.equal(first.body.npc.relationship, 1);
  assert.equal(immediateRepeat.status, 429);
  assert.equal(immediateRepeat.body.error, "INTERACTION_COOLDOWN");

  const persisted = await world.load();
  const persistedNpc = persisted.npcs.find((entry) => entry.id === npc.id);
  assert.equal(persistedNpc.relationshipByUid["jogador-cooldown"], 1);
});

test("relação com habitante nunca ultrapassa cem pontos", async () => {
  const world = createWorld();
  const state = await world.load();
  const npc = state.npcs.find((entry) => entry.id === "npc_aurelia_morador");
  npc.relationshipByUid = { "jogador-maximo": 100 };
  await world.testStorage.put("world", state);
  await publishPresence(world, "jogador-maximo", "aurelia");

  const result = await post(world, "/npc/interact", {
    uid: "jogador-maximo", npcId: npc.id, action: "CONVERSAR"
  });

  assert.equal(result.status, 200);
  assert.equal(result.body.npc.relationship, 100);
  assert.equal(result.body.relationshipTier, "CONFIDENTE");
});

test("confiança máxima libera diálogo reservado específico do habitante", async () => {
  const world = createWorld();
  const state = await world.load();
  const npc = state.npcs.find((entry) => entry.id === "npc_aurelia_morador");
  npc.relationshipByUid = { "jogador-confidente": 89 };
  await world.testStorage.put("world", state);
  await publishPresence(world, "jogador-confidente", "aurelia");

  const result = await post(world, "/npc/interact", {
    uid: "jogador-confidente", npcId: npc.id, action: "CONVERSAR"
  });

  assert.equal(result.status, 200);
  assert.equal(result.body.relationshipTier, "CONFIDENTE");
  assert.match(result.body.dialogue, /segredo|Clareira Inicial/i);
});

test("humor de medo tem prioridade sobre diálogos de alta confiança", async () => {
  const world = createWorld();
  const state = await world.load();
  const npc = state.npcs.find((entry) => entry.id === "npc_aurelia_guarda");
  npc.relationshipByUid = { "jogador-ajuda": 100 };
  npc.mood = "ASSUSTADO";
  await world.testStorage.put("world", state);
  await publishPresence(world, "jogador-ajuda", "aurelia");

  const result = await post(world, "/npc/interact", {
    uid: "jogador-ajuda", npcId: npc.id, action: "CONVERSAR"
  });

  assert.equal(result.status, 200);
  assert.match(result.body.dialogue, /cuidado|seguro/i);
});



test("custos de mana inconsistentes são normalizados antes da validação", () => {
  const creature = {
    ataques: [
      {
        id: "golpe_arcano",
        custoMana: 18,
        custoManaMinimo: 4,
        custoManaMaximo: 12
      },
      {
        id: "onda_elemental",
        custoMana: 14,
        custoManaMinimo: 15,
        custoManaMaximo: 10
      }
    ]
  };

  const normalized = normalizeCreatureManaCosts(creature);

  assert.equal(normalized.ataques[0].custoManaMinimo, 4);
  assert.equal(normalized.ataques[0].custoMana, 18);
  assert.equal(normalized.ataques[0].custoManaMaximo, 18);

  assert.equal(normalized.ataques[1].custoManaMinimo, 10);
  assert.equal(normalized.ataques[1].custoMana, 14);
  assert.equal(normalized.ataques[1].custoManaMaximo, 15);
  assert.equal(normalized.manaMaxima, 18);

  // A normalização não modifica o objeto original recebido da IA.
  assert.equal(creature.ataques[0].custoMana, 18);
});


test("reserva mínima de mana das criaturas é duas vezes a vida", () => {
  const creature = {
    vidaMaxima: 500,
    manaMaxima: 100,
    ataques: [{
      id: "onda",
      nome: "Onda Astral",
      danoBase: 300,
      custoMana: 400,
      custoManaMinimo: 300,
      custoManaMaximo: 400
    }]
  };

  const normalized = normalizeCreatureManaCosts(creature);
  assert.equal(normalized.manaMaxima, 1000);
  assert.equal(normalized.ataques[0].custoMana, 400);
  assert.equal(normalized.ataques[0].custoManaMaximo, 400);

  const elite = normalizeCreatureManaCosts({
    vidaMaxima: 500,
    manaMaxima: 100,
    ataques: [{
      id: "supremo",
      nome: "Ruptura",
      danoBase: 900,
      custoMana: 1500,
      custoManaMinimo: 1000,
      custoManaMaximo: 1500
    }]
  });
  assert.equal(elite.manaMaxima, 1500);
});
test("prompt de autorreparo manda a IA corrigir sem recriar a identidade da criatura", () => {
  const creature = {
    nome: "Lince das Raízes",
    bioma: "floresta arcana",
    rank: "E",
    manaMaxima: 4,
    ataques: [{ nome: "Garra Umbral", custoMana: 9, custoManaMinimo: 2, custoManaMaximo: 5 }]
  };
  const issues = ["ataque 1: custoMana deve ficar entre custoManaMinimo e custoManaMaximo"];
  const requestData = { ecosystemId: "dark_forest", biome: "floresta arcana", rank: "E", isBoss: false };

  const prompt = buildCreatureRepairPrompt(creature, issues, requestData);

  assert.match(prompt, /Ajuste somente a estrutura técnica/);
  assert.match(prompt, /Não reduza a criatividade/);
  assert.match(prompt, /Lince das Raízes/);
  assert.match(prompt, /custoMana deve ficar entre custoManaMinimo/);
  assert.match(prompt, /dark_forest/);
  assert.match(prompt, /aumente a reserva de mana/);
});


test("motor amplia a reserva de mana sem enfraquecer o ataque criado pela IA", () => {
  const creature = {
    nome: "Lince das Raízes",
    manaMaxima: 3,
    ataques: [{
      id: "garra_arcana",
      nome: "Garra Arcana",
      danoBase: 12,
      custoMana: 9,
      custoManaMinimo: 2,
      custoManaMaximo: 8
    }]
  };
  const safe = normalizeCreatureManaCosts(creature);
  assert.equal(safe.ataques[0].custoManaMaximo, 9);
  assert.equal(safe.ataques[0].custoManaMinimo, 2);
  assert.equal(safe.ataques[0].custoMana, 9);
  assert.equal(safe.manaMaxima, 9);
  assert.equal(safe.ataques[0].danoBase, 12);
  assert.equal(creature.ataques[0].custoMana, 9);
});


test("criatura mantém rank, raridade e quantidade de criações sem listas fechadas", () => {
  const creature = {
    nome: "Colosso das Marés Vivas",
    descricao: "Uma entidade colossal formada por água, coral e memória.",
    rank: "TRANSCENDENTE",
    nivel: 900,
    vidaMaxima: 900000,
    ataque: 80000,
    defesa: 50000,
    manaMaxima: 5,
    agilidade: 20,
    poderMagico: 90000,
    experienciaBase: 9000,
    perigo: 900,
    bioma: "Oceano de Cristal",
    habitat: "Fendas abissais que mudam de lugar",
    raridade: "SINGULARIDADE",
    atividadeNoturna: false,
    habilidades: Array.from({ length: 12 }, (_, i) => "Manifestação " + (i + 1)),
    ataques: Array.from({ length: 9 }, (_, i) => ({
      id: "ataque_" + i,
      nome: "Técnica " + i,
      descricao: "Técnica original " + i,
      tipoDano: "CAUSAL",
      elemento: "MEMÓRIA",
      danoBase: 100 + i,
      multiplicador: 1.5,
      custoMana: i === 8 ? 40 : 0,
      custoManaMinimo: 0,
      custoManaMaximo: i === 8 ? 40 : 0,
      efeitos: ["Efeito exclusivo " + i],
      duracaoTurnos: 3,
      chanceAplicacao: 100,
      chanceUso: 100,
      turnosCarregamento: 0,
      turnosRecarga: 0,
      podeSerInterrompida: true,
      categoria: "RITUAL_CAUSAL",
      danoQuebra: 0
    })),
    drops: Array.from({ length: 10 }, (_, i) => ({
      itemId: "drop_" + i,
      nome: "Fragmento " + i,
      descricao: "Fragmento singular",
      tipo: "RELIQUIA",
      raridade: "ABSOLUTA",
      chancePercentual: 5,
      garantido: false,
      quantidadeMinima: 1,
      quantidadeMaxima: 1,
      tipoEquipamento: "ARTEFATO",
      raridadeEquipamento: "TRANSCENDENTE",
      rankEquipamento: "TRANSCENDENTE",
      nivelRequerido: 1,
      atributos: {},
      efeitoEspecial: "Dobra uma regra do mundo"
    }))
  };

  const adapted = normalizeGeneratedCreature(creature, { biome: "Oceano de Cristal", rank: "E" });
  assert.equal(adapted.rank, "TRANSCENDENTE");
  assert.equal(adapted.raridade, "SINGULARIDADE");
  assert.equal(adapted.habilidades.length, 12);
  assert.equal(adapted.ataques.length, 9);
  assert.equal(adapted.drops.length, 10);
  assert.equal(adapted.ataques[8].custoMana, 40);
  assert.equal(adapted.manaMaxima, 1800000);
  assert.ok(adapted.manaMaxima >= adapted.vidaMaxima * 2);
});


test("criatura mantém rank e raridade originais sem enums fechados", () => {
  const creature = normalizeGeneratedCreature({
    nome: "Entidade do Horizonte",
    descricao: "Uma criatura que dobra a distância entre estrelas.",
    rank: "TRANSCENDENTE-ALFA",
    nivel: 900,
    vidaMaxima: 900000,
    ataque: 70000,
    defesa: 30000,
    manaMaxima: 1800000,
    agilidade: 40000,
    poderMagico: 120000,
    experienciaBase: 500000,
    perigo: 100,
    bioma: "oceano celeste",
    habitat: "fendas entre dimensões",
    raridade: "SINGULARIDADE ETERNA",
    atividadeNoturna: false,
    habilidades: ["Dobra do horizonte"],
    ataques: [{
      id: "corte_dimensional",
      nome: "Corte Dimensional",
      descricao: "Abre um corte no espaço.",
      tipoDano: "ESPACIAL",
      elemento: "VAZIO",
      danoBase: 90000,
      multiplicador: 2,
      custoMana: 100,
      custoManaMinimo: 100,
      custoManaMaximo: 100,
      efeitos: [],
      duracaoTurnos: 0,
      chanceAplicacao: 100,
      chanceUso: 100,
      turnosCarregamento: 0,
      turnosRecarga: 0,
      podeSerInterrompida: true,
      categoria: "DIMENSIONAL",
      danoQuebra: 0
    }],
    drops: []
  }, { ecosystemId: "abyss_valley", biome: "vale abissal" });

  assert.equal(creature.rank, "TRANSCENDENTE-ALFA");
  assert.equal(creature.raridade, "SINGULARIDADE ETERNA");
  assert.equal(creature.ataques.length, 1);
  assert.equal(creature.ataques[0].nome, "Corte Dimensional");
});

test("ataque ausente é enviado para reparo da IA em vez de receber ataque genérico", () => {
  const creature = normalizeGeneratedCreature({
    nome: "Criatura sem ataque",
    descricao: "Ainda não definiu seu estilo de combate.",
    rank: "E",
    nivel: 1,
    vidaMaxima: 100,
    ataque: 10,
    defesa: 5,
    manaMaxima: 20,
    agilidade: 5,
    poderMagico: 10,
    experienciaBase: 10,
    perigo: 1,
    bioma: "floresta",
    habitat: "bosque",
    raridade: "INCOMUM",
    atividadeNoturna: false,
    habilidades: [],
    ataques: [],
    drops: []
  }, { ecosystemId: "dark_forest", biome: "floresta sombria" });

  assert.deepEqual(creature.ataques, []);
  assert.deepEqual(creature.habilidades, []);
  assert.ok(
    creatureValidationIssues(creature).some(issue => issue.includes("ataque original"))
  );
});
