import test from "node:test";
import assert from "node:assert/strict";
import { PersistentWorldState } from "./worker.js";

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

