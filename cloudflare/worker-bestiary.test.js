import test from "node:test";
import assert from "node:assert/strict";
import { PersistentWorldState } from "./worker.js";

function createWorld() {
  const values = new Map();
  const storage = {
    async get(key) { return values.get(key); },
    async put(key, value) { values.set(key, structuredClone(value)); }
  };
  return new PersistentWorldState({ storage });
}

async function post(world, path, body) {
  const response = await world.fetch(new Request("https://world" + path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  }));
  return { status: response.status, body: await response.json() };
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

test("vitória global é contabilizada uma única vez por batalha", async () => {
  const world = createWorld();
  const battle = {
    id: "batalha-123",
    creatureId: "dragao_antigo",
    status: "FINISHED",
    phase: "VICTORY",
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
  assert.equal(duplicate.body.duplicate, true);
  assert.equal(duplicate.body.stats.totalDefeats, 1);
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
    encounterToken: token, uid: "jogador-solo"
  });
  const duplicate = await post(world, "/bestiary/solo-defeat", {
    encounterToken: token, uid: "jogador-solo"
  });

  assert.equal(first.body.registered, true);
  assert.equal(first.body.stats.totalDefeats, 1);
  assert.equal(first.body.stats.firstDefeaterUid, "jogador-solo");
  assert.equal(first.body.stats.mostDefeatsCount, 1);
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

