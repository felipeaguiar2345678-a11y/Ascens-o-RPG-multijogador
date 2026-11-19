import test from "node:test";
import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import { handleMissionEvent } from "./mission-service.js";
import { decodeFirestoreFields, encodeFirestoreFields } from "./firebase-admin.js";

globalThis.crypto ||= webcrypto;

async function privateKeyPem() {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true, ["sign", "verify"]
  );
  const bytes = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return "-----BEGIN PRIVATE KEY-----\n" + btoa(binary).match(/.{1,64}/g).join("\n") + "\n-----END PRIVATE KEY-----";
}

async function fixture({ mission, character, creature } = {}) {
  const project = "ascensao-do-soberano";
  const prefix = "projects/" + project + "/databases/(default)/documents/";
  const docs = new Map();
  const put = (path, data) => docs.set(prefix + path, {
    name: prefix + path, fields: encodeFirestoreFields(data)
  });
  put("characters/char-1", character || {
    id: "char-1", ownerUid: "player-1", currentWorldPointId: "clareira_inicial",
    guildRank: "E", level: 1, xp: 0, attributePoints: 0,
    inventory: { items: [], gold: 0, eggs: [], companions: [], equipment: [] }
  });
  put("characters/char-1/guildContracts/mission-1", mission || {
    contractId: "mission-1", characterId: "char-1", ownerUid: "player-1",
    title: "Caçada: lobos da nevasca", rank: "E", kind: "Caçada e ameaça regional",
    ecosystemId: "dark_forest", destinationId: "clareira_inicial",
    objective: "Derrote 2 lobos da nevasca.", rarity: "Comum",
    rewardGold: 50, rewardXp: 100, status: "ACCEPTED"
  });
  if (creature) put("criaturas/" + creature.id, creature);
  let transactionNumber = 0;
  const fetchMock = async (urlValue, options = {}) => {
    const url = String(urlValue);
    if (url === "https://oauth2.googleapis.com/token") {
      return Response.json({ access_token: "mission-service-test-token", expires_in: 3600 });
    }
    if (url.endsWith(":beginTransaction")) {
      transactionNumber += 1;
      return Response.json({ transaction: "mission-tx-" + transactionNumber });
    }
    if (url.includes("/documents/") && url.includes("?transaction=")) {
      const path = url.split("/documents/")[1].split("?")[0];
      const document = docs.get(prefix + path);
      return document ? Response.json(structuredClone(document)) : new Response("not found", { status: 404 });
    }
    if (url.endsWith(":commit")) {
      const body = JSON.parse(options.body);
      for (const write of body.writes) {
        const name = write.update.name;
        const existing = docs.get(name);
        const data = existing ? decodeFirestoreFields(existing.fields) : {};
        const incoming = decodeFirestoreFields(write.update.fields);
        for (const field of write.updateMask.fieldPaths) {
          const parts = field.split(".");
          if (parts.length === 1) data[parts[0]] = incoming[parts[0]];
          else {
            const root = parts[0];
            data[root] = { ...(data[root] || {}), [parts[1]]: incoming[root]?.[parts[1]] };
          }
        }
        docs.set(name, { name, fields: encodeFirestoreFields(data) });
      }
      return Response.json({ writeResults: body.writes.map(() => ({})) });
    }
    throw new Error("URL inesperada: " + url);
  };
  const env = {
    FIREBASE_SERVICE_ACCOUNT_EMAIL: "mission-" + Math.random().toString(36).slice(2) + "@ascensao-do-soberano.iam.gserviceaccount.com",
    FIREBASE_PRIVATE_KEY: await privateKeyPem(),
    FIREBASE_PROJECT_ID: project
  };
  return { env, docs, fetchMock, prefix };
}

function stored(fixture, path) {
  return decodeFirestoreFields(fixture.docs.get(fixture.prefix + path).fields);
}

test("vitória só conta com prova de combate e respeita destino e proprietário", async () => {
  const f = await fixture({ creature: {
    id: "lobo-nevasca", name: "Lobo da Nevasca", rank: "E",
    ecosystemId: "dark_forest", chefe: false
  } });
  const body = {
    characterId: "char-1", missionId: "mission-1", eventId: "solo_token_001",
    type: "CREATURE_DEFEATED", regionId: "dark_forest", locationId: "clareira_inicial"
  };
  const unverified = await handleMissionEvent(f.env, "player-1", body, f.fetchMock);
  assert.equal(unverified.status, 403);
  const wrongLocation = await handleMissionEvent(f.env, "player-1", { ...body, locationId: "aurelia" }, f.fetchMock, {
    verifiedCombat: true, creatureId: "lobo-nevasca"
  });
  assert.equal(wrongLocation.status, 409);
  const valid = await handleMissionEvent(f.env, "player-1", body, f.fetchMock, {
    verifiedCombat: true, creatureId: "lobo-nevasca"
  });
  assert.equal(valid.body.accepted, true);
  assert.equal(valid.body.progress.kills, 1);
});

test("missão conclui e entrega XP e ouro uma única vez na transação", async () => {
  const f = await fixture({ creature: {
    id: "lobo-nevasca", name: "Lobo da Nevasca", rank: "E",
    ecosystemId: "dark_forest", chefe: false
  } });
  for (const eventId of ["solo_token_001", "solo_token_002"]) {
    const result = await handleMissionEvent(f.env, "player-1", {
      characterId: "char-1", missionId: "mission-1", eventId,
      type: "CREATURE_DEFEATED", regionId: "dark_forest", locationId: "clareira_inicial"
    }, f.fetchMock, { verifiedCombat: true, creatureId: "lobo-nevasca" });
    assert.equal(result.body.accepted, true);
  }
  const mission = stored(f, "characters/char-1/guildContracts/mission-1");
  const character = stored(f, "characters/char-1");
  assert.equal(mission.status, "COMPLETED");
  assert.equal(mission.rewardClaimed, true);
  assert.equal(character.level, 2);
  assert.equal(character.xp, 0);
  assert.equal(character.attributePoints, 5);
  assert.equal(character.inventory.gold, 50);
  const duplicate = await handleMissionEvent(f.env, "player-1", {
    characterId: "char-1", missionId: "mission-1", eventId: "solo_token_002",
    type: "CREATURE_DEFEATED", regionId: "dark_forest", locationId: "clareira_inicial"
  }, f.fetchMock, { verifiedCombat: true, creatureId: "lobo-nevasca" });
  assert.equal(duplicate.body.duplicate, true);
  assert.equal(stored(f, "characters/char-1").inventory.gold, 50);
});

test("coleta cria material real no inventário e limita a quantidade do contrato", async () => {
  const f = await fixture({ mission: {
    contractId: "mission-1", characterId: "char-1", ownerUid: "player-1",
    title: "Recolher ervas luminosas", rank: "E", kind: "Coleta",
    ecosystemId: "dark_forest", destinationId: "clareira_inicial",
    objective: "Obtenha 3 unidades de ervas luminosas.", rarity: "Comum",
    rewardGold: 10, rewardXp: 10, status: "ACCEPTED"
  } });
  for (let i = 1; i <= 3; i++) {
    const result = await handleMissionEvent(f.env, "player-1", {
      characterId: "char-1", missionId: "mission-1", eventId: "resource_event_" + i,
      type: "MATERIAL_OBTAINED", regionId: "dark_forest", locationId: "clareira_inicial",
      targetId: "resource_" + i, amount: 1
    }, f.fetchMock, { roll: 20 });
    assert.equal(result.body.accepted, true);
  }
  const character = stored(f, "characters/char-1");
  assert.equal(character.inventory.items.length, 1);
  assert.equal(character.inventory.items[0].name, "Ervas luminosas");
  assert.equal(character.inventory.items[0].quantity, 3);
  assert.equal(stored(f, "characters/char-1/guildContracts/mission-1").status, "COMPLETED");
});

test("eventos de investigação, escolta, proteção, rastreamento e purificação usam seus próprios tipos", async () => {
  const cases = [
    ["Investigação", "EVIDENCE_FOUND", "evidence_1", "evidence"],
    ["Escolta", "ESCORT_STEP_COMPLETED", "escort_1", "escort"],
    ["Proteção", "PROTECTED_TARGET_SURVIVED", "protection_1", "protection"],
    ["Rastreamento", "TRACKING_CLUE_FOUND", "clue_1", "tracking"],
    ["Purificação", "CORRUPTION_SOURCE_CLEARED", "focus_1", "purification"],
    ["Exploração", "LOCATION_DISCOVERED", "location_1", "locations"]
  ];
  for (const [kind, type, targetId, counter] of cases) {
    const f = await fixture({ mission: {
      contractId: "mission-1", characterId: "char-1", ownerUid: "player-1",
      title: kind + " regional", rank: "E", kind,
      ecosystemId: "dark_forest", destinationId: "clareira_inicial",
      objective: "Conclua a etapa solicitada.", rarity: "Comum",
      rewardGold: 5, rewardXp: 5, status: "ACCEPTED"
    } });
    const result = await handleMissionEvent(f.env, "player-1", {
      characterId: "char-1", missionId: "mission-1", eventId: "action_event_001",
      type, regionId: "dark_forest", locationId: "clareira_inicial", targetId
    }, f.fetchMock, { roll: 20 });
    assert.equal(result.body.accepted, true, kind);
    assert.equal(result.body.progress[counter], 1, kind);
    assert.equal(result.body.completed, true, kind);
  }
});

test("raid exige entrada, três inimigos reais, núcleo e chefe", async () => {
  const f = await fixture({ mission: {
    contractId: "mission-1", characterId: "char-1", ownerUid: "player-1",
    title: "Raid da Clareira", rank: "E", kind: "Raid",
    ecosystemId: "dark_forest", destinationId: "clareira_inicial",
    objective: "Conclua a raid e derrote o guardião.", rarity: "Comum",
    rewardGold: 5, rewardXp: 5, status: "ACCEPTED"
  } });
  const send = (eventId, type, targetId, creatureId) => handleMissionEvent(f.env, "player-1", {
    characterId: "char-1", missionId: "mission-1", eventId, type,
    regionId: "dark_forest", locationId: "clareira_inicial", targetId
  }, f.fetchMock, creatureId ? { verifiedCombat: true, creatureId } : {});
  await f.docs.set(f.prefix + "criaturas/grupo_1", { name: "Goblin", fields: encodeFirestoreFields({ id: "grupo_1", name: "Goblin", rank: "E", ecosystemId: "dark_forest", chefe: false }) });
  await f.docs.set(f.prefix + "criaturas/guardiao", { name: "Guardião", fields: encodeFirestoreFields({ id: "guardiao", name: "Guardião", rank: "E", ecosystemId: "dark_forest", chefe: true }) });
  assert.equal((await handleMissionEvent(f.env, "player-1", {
    characterId: "char-1", missionId: "mission-1", eventId: "raid_entry_1",
    type: "RAID_STEP_COMPLETED", regionId: "dark_forest", locationId: "clareira_inicial", targetId: "entrada"
  }, f.fetchMock, { roll: 20 })).body.accepted, true);
  for (let i = 1; i <= 3; i++) {
    await send("raid_kill_" + i, "CREATURE_DEFEATED", "", "grupo_1");
  }
  assert.equal(stored(f, "characters/char-1/guildContracts/mission-1").completedStages.includes("grupos"), true);
  assert.equal((await handleMissionEvent(f.env, "player-1", {
    characterId: "char-1", missionId: "mission-1", eventId: "raid_core_1",
    type: "RAID_STEP_COMPLETED", regionId: "dark_forest", locationId: "clareira_inicial", targetId: "nucleo"
  }, f.fetchMock, { roll: 20 })).body.accepted, true);
  const boss = await send("raid_boss_1", "CREATURE_DEFEATED", "", "guardiao");
  assert.equal(boss.body.completed, true);
test("falha na rolagem não altera progresso nem inventário", async () => {
  const f = await fixture({ mission: {
    contractId: "mission-1", characterId: "char-1", ownerUid: "player-1",
    title: "Examinar inscrições", rank: "E", kind: "Investigação",
    ecosystemId: "dark_forest", destinationId: "clareira_inicial",
    objective: "Encontre uma evidência.", rarity: "Comum", rewardGold: 5, rewardXp: 5, status: "ACCEPTED"
  } });
  const result = await handleMissionEvent(f.env, "player-1", {
    characterId: "char-1", missionId: "mission-1", eventId: "failed_check_001",
    type: "EVIDENCE_FOUND", regionId: "dark_forest", locationId: "clareira_inicial", targetId: "evidence_1"
  }, f.fetchMock, { roll: 1 });
  assert.equal(result.body.accepted, false);
  assert.equal(result.body.challenge.success, false);
  assert.equal(stored(f, "characters/char-1/guildContracts/mission-1").progressCounters, undefined);
});
test("aceitação valida o catálogo, grava a missão e bloqueia uma segunda missão ativa", async () => {
  const f = await fixture();
  const mission = {
    id: "guild_central_wilds_e_00000000-0000-4000-8000-000000000000",
    title: "Investigar cartas desaparecidas", rank: "E", type: "Investigação",
    regionId: "central_wilds", regionName: "Região Central",
    destinationId: "aurelia", destinationName: "Aurelia",
    summary: "A guilda recebeu um relato de atividade incomum em Aurelia.",
    objective: "Investigar cartas desaparecidas. Retorne à Guilda com uma prova simples da conclusão.",
    rewardGold: 35, rewardXp: 70, recommendedLevel: 1, special: false,
    rarity: "Comum", rarityMultiplier: 1, difficultyMultiplier: 1
  };
  const accepted = await handleMissionAccept(f.env, "player-1", { characterId: "char-1", mission }, f.fetchMock);
  assert.equal(accepted.body.accepted, true);
  assert.equal(stored(f, "characters/char-1").activeGuildMissionId, mission.id);
  assert.equal(stored(f, "characters/char-1/guildContracts/" + mission.id).status, "ACCEPTED");
  const second = await handleMissionAccept(f.env, "player-1", { characterId: "char-1", mission: { ...mission, id: "guild_central_wilds_e_11111111-1111-4111-8111-111111111111" } }, f.fetchMock);
  assert.equal(second.status, 409);
  const forged = await handleMissionAccept(f.env, "player-1", { characterId: "char-1", mission: { ...mission, rewardGold: 999999999 } }, f.fetchMock);
  assert.equal(forged.status, 400);
});
test("missão World exige recurso, amostra única, chefe World e relíquia", async () => {
  const f = await fixture({ mission: {
    contractId: "mission-1", characterId: "char-1", ownerUid: "player-1",
    title: "Contrato World: água ancestral", rank: "SSS", kind: "Coleta",
    ecosystemId: "dark_forest", destinationId: "clareira_inicial",
    objective: "Obtenha 1 unidade de água ancestral e uma amostra única. Conclua em uma zona extrema, derrote um chefe World e recupere uma relíquia única.",
    rarity: "World", rewardGold: 10, rewardXp: 10, status: "ACCEPTED"
  }, creature: {
    id: "world-boss", name: "Entidade World", rank: "WORLD", ecosystemId: "dark_forest", chefe: true
  } });
  const send = (eventId, targetId) => handleMissionEvent(f.env, "player-1", {
    characterId: "char-1", missionId: "mission-1", eventId, type: "MATERIAL_OBTAINED",
    regionId: "dark_forest", locationId: "clareira_inicial", targetId
  }, f.fetchMock, { roll: 20 });
  const resource = await send("world_resource_001", "resource_1");
  assert.equal(resource.body.accepted, true);
  const sample = await send("world_sample_001", "sample");
  assert.equal(sample.body.accepted, true);
  const boss = await handleMissionEvent(f.env, "player-1", {
    characterId: "char-1", missionId: "mission-1", eventId: "world_boss_001",
    type: "CREATURE_DEFEATED", regionId: "dark_forest", locationId: "clareira_inicial"
  }, f.fetchMock, { verifiedCombat: true, creatureId: "world-boss" });
  assert.equal(boss.body.accepted, true);
  const relic = await send("world_relic_001", "artifact");
  assert.equal(relic.body.completed, true);
  const character = stored(f, "characters/char-1");
  assert.deepEqual(character.inventory.items.map(item => item.name).sort(), ["Água ancestral", "Amostra única", "Relíquia única"].sort());
  assert.equal(character.activeGuildMissionId, "");
});
});
