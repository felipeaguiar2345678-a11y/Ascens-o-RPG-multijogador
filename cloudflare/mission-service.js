import {
  firestoreAdminBeginTransaction,
  firestoreAdminGetDocumentInTransaction,
  firestoreAdminCommitTransaction,
  decodeFirestoreFields,
  encodeFirestoreFields
} from "./firebase-admin.js";

const RANKS = ["E", "D", "C", "B", "A", "S", "SS", "SSS", "WORLD"];
const TYPES = new Set([
  "CREATURE_DEFEATED", "MATERIAL_OBTAINED", "LOCATION_DISCOVERED",
  "EVIDENCE_FOUND", "ESCORT_STEP_COMPLETED", "PROTECTED_TARGET_SURVIVED",
  "TRACKING_CLUE_FOUND", "CORRUPTION_SOURCE_CLEARED", "RAID_STEP_COMPLETED",
  "REGIONAL_BOSS_DEFEATED"
]);

function normalize(value) {
  return String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase().replace(/[^a-z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
}

function targetTokens(title) {
  const ignored = new Set([
    "cacada", "caca", "ameaca", "regional", "contrato", "missao", "derrote",
    "elimine", "afaste", "enfrente", "criatura", "criaturas", "monstro",
    "monstros", "fera", "feras", "selvagem", "selvagens", "agressivo",
    "agressivos", "da", "das", "de", "do", "dos", "na", "nas", "no", "nos"
  ]);
  return normalize(String(title).split(":").slice(1).join(":") || title)
    .split(" ").map(token => token.endsWith("s") && token.length > 4 ? token.slice(0, -1) : token)
    .filter(token => token.length >= 4 && !ignored.has(token));
}

function requiredAmount(objective) {
  const match = String(objective || "").match(/(?:derrote|elimine|recolha|obtenha|encontre|recupere|descubra|purifique)\s+(\d+)/i);
  return Math.max(1, Math.min(1000, Number(match?.[1]) || 1));
}

function eventCounter(type) {
  return ({
    CREATURE_DEFEATED: "kills",
    MATERIAL_OBTAINED: "materials",
    LOCATION_DISCOVERED: "locations",
    EVIDENCE_FOUND: "evidence",
    ESCORT_STEP_COMPLETED: "escort",
    PROTECTED_TARGET_SURVIVED: "protection",
    TRACKING_CLUE_FOUND: "tracking",
    CORRUPTION_SOURCE_CLEARED: "purification"
  })[type] || "";
}

function missionKind(kind) {
  const value = normalize(kind);
  if (value.includes("raid") || value.includes("masmorra")) return "raid";
  if (value.includes("cacada") || value.includes("caca")) return "hunt";
  if (value.includes("coleta")) return "collection";
  if (value.includes("explora")) return "exploration";
  if (value.includes("investiga")) return "investigation";
  if (value.includes("escolta")) return "escort";
  if (value.includes("protec") || value.includes("defesa")) return "protection";
  if (value.includes("rastrea")) return "tracking";
  if (value.includes("purifica")) return "purification";
  if (value.includes("chefe")) return "boss";
  return "unknown";
}

function rewardCaps(rank, rarity) {
  const rankIndex = Math.max(0, RANKS.indexOf(String(rank || "E").toUpperCase()));
  const rarityIndex = ["Comum", "Incomum", "Rara", "Épica", "Lendária", "Mítica", "Divina", "World"]
    .indexOf(String(rarity || "Comum"));
  const multiplier = [1, 1.5, 2, 3, 5, 8, 12, 20][Math.max(0, rarityIndex)];
  return {
    xp: Math.floor((100 + (rankIndex + 1) * 250) * multiplier),
    gold: Math.floor((250 + (rankIndex + 1) * 500) * multiplier)
  };
}

function progressComplete(kind, objective, counters, stages) {
  const required = requiredAmount(objective);
  let primary = false;
  switch (kind) {
    case "raid": primary = ["entrada", "grupos", "nucleo", "guardiao"].every(stage => stages.includes(stage)); break;
    case "hunt": primary = (counters.kills || 0) >= required; break;
    case "collection": primary = (counters.materials || 0) >= required; break;
    case "exploration": primary = (counters.locations || 0) >= required; break;
    case "investigation": primary = (counters.evidence || 0) >= required; break;
    case "escort": primary = (counters.escort || 0) >= required; break;
    case "protection": primary = (counters.protection || 0) >= required; break;
    case "tracking": primary = (counters.tracking || 0) >= required; break;
    case "purification": primary = (counters.purification || 0) >= required; break;
    case "boss": primary = stages.some(stage => stage.startsWith("boss:")); break;
    default: return false;
  }
  const normalized = normalize(objective);
  const extraEvidence = !/(prova|evidencia)/.test(normalized) || (counters.extraEvidence || 0) >= 1;
  const extraCreature = !/(criatura de rank compativel|supere uma criatura)/.test(normalized) || (counters.extraCreature || 0) >= 1;
  const extraBoss = !/(guardiao|chefe regional|chefe world|chefe de alto rank)/.test(normalized) ||
    stages.some(stage => stage.startsWith("boss:") || stage === "guardiao");
  const extraArtifact = !/(artefato raro|reliquia unica|amostra unica)/.test(normalized) || (counters.artifact || 0) >= 1;
  return primary && extraEvidence && extraCreature && extraBoss && extraArtifact;
}

function levelUp(level, xp, attributePoints, gained) {
  let nextLevel = Math.max(1, Math.floor(Number(level) || 1));
  let nextXp = Math.max(0, Math.floor(Number(xp) || 0)) + gained;
  let points = Math.max(0, Math.floor(Number(attributePoints) || 0));
  let levels = 0;
  while (nextLevel < 10000 && nextXp >= nextLevel * 100) {
    nextXp -= nextLevel * 100;
    nextLevel += 1;
    levels += 1;
    points += 5;
  }
  return { level: nextLevel, xp: nextXp, attributePoints: points, levelsGained: levels };
}

function response(body, status = 200) {
  return { body, status };
}

export async function handleMissionEvent(env, uid, body, fetchImpl = fetch, options = {}) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(String(uid || "")) ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(String(body?.characterId || "")) ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(String(body?.missionId || "")) ||
      !/^[A-Za-z0-9_-]{8,160}$/.test(String(body?.eventId || "")) ||
      !TYPES.has(body?.type)) {
    return response({ error: "INVALID_MISSION_EVENT" }, 400);
  }
  const type = body.type;
  if (type === "CREATURE_DEFEATED" && options.verifiedCombat !== true) {
    return response({ error: "COMBAT_PROOF_REQUIRED", message: "Uma derrota só conta após confirmação oficial do combate." }, 403);
  }
  if (type === "REGIONAL_BOSS_DEFEATED" && options.verifiedCombat !== true) {
    return response({ error: "BOSS_PROOF_REQUIRED", message: "O chefe precisa ser derrotado em um combate confirmado." }, 403);
  }
  const amount = Number(body.amount ?? 1);
  if (!Number.isSafeInteger(amount) || amount < 1 || amount > 1000) {
    return response({ error: "INVALID_MISSION_AMOUNT" }, 400);
  }

  const characterPath = "characters/" + body.characterId;
  const missionPath = characterPath + "/guildContracts/" + body.missionId;
  let transaction;
  try {
    transaction = await firestoreAdminBeginTransaction(env, fetchImpl);
    const [characterDocument, missionDocument] = await Promise.all([
      firestoreAdminGetDocumentInTransaction(env, characterPath, transaction, fetchImpl),
      firestoreAdminGetDocumentInTransaction(env, missionPath, transaction, fetchImpl)
    ]);
    if (!characterDocument || !missionDocument) return response({ error: "MISSION_OR_CHARACTER_NOT_FOUND" }, 404);
    const character = decodeFirestoreFields(characterDocument.fields || {});
    const mission = decodeFirestoreFields(missionDocument.fields || {});
    if (character.ownerUid !== uid || mission.ownerUid !== uid || mission.characterId !== body.characterId) {
      return response({ error: "MISSION_OWNER_MISMATCH" }, 403);
    }
    if (mission.status === "COMPLETED") return response({ accepted: true, duplicate: true, completed: true, progress: mission.progressCounters || {} });
    if (mission.status !== "ACCEPTED") return response({ error: "MISSION_NOT_ACTIVE" }, 409);
    if (mission.destinationId !== body.locationId ||
        character.currentWorldPointId !== mission.destinationId ||
        mission.ecosystemId !== body.regionId) {
      return response({ error: "MISSION_LOCATION_MISMATCH", message: "Vá até o destino registrado para avançar esta missão." }, 409);
    }

    const eventId = body.eventId;
    const processed = Array.isArray(mission.processedEventIds) ? mission.processedEventIds : [];
    if (processed.includes(eventId)) {
      return response({ accepted: true, duplicate: true, completed: mission.status === "COMPLETED", progress: mission.progressCounters || {} });
    }

    const kind = missionKind(mission.kind);
    const objective = normalize(mission.objective);
    const counters = { ...(mission.progressCounters || {}) };
    const stages = Array.isArray(mission.completedStages) ? [...mission.completedStages] : [];
    let counter = eventCounter(type);
    let stageId = "";
    let creature = null;
    let nextInventoryItems = null;

    if (type === "CREATURE_DEFEATED" || type === "REGIONAL_BOSS_DEFEATED") {
      const creatureId = String(options.creatureId || "");
      if (!/^[A-Za-z0-9_-]{1,128}$/.test(creatureId)) return response({ error: "CREATURE_PROOF_MISSING" }, 403);
      const creatureDocument = await firestoreAdminGetDocumentInTransaction(env, "criaturas/" + creatureId, transaction, fetchImpl);
      if (!creatureDocument) return response({ error: "OFFICIAL_CREATURE_NOT_FOUND" }, 404);
      creature = decodeFirestoreFields(creatureDocument.fields || {});
      const creatureRank = String(creature.rank || creature.rankLabel || "").toUpperCase();
      const rankLimit = RANKS.indexOf(String(mission.rank || "E").toUpperCase());
      const actualRank = RANKS.indexOf(creatureRank);
      if (actualRank < 0 || rankLimit < 0 || actualRank > rankLimit) {
        return response({ error: "CREATURE_RANK_MISMATCH", message: "A criatura está acima do rank permitido nesta missão." }, 409);
      }
      const ecosystem = String(creature.ecosystemId || creature.habitat || "");
      if (ecosystem && ecosystem !== mission.ecosystemId) {
        return response({ error: "CREATURE_ECOSYSTEM_MISMATCH" }, 409);
      }
      const isBoss = creature.isBoss === true || creature.chefe === true;
      const requiresBoss = /(guardiao|chefe regional|chefe world|chefe de alto rank)/.test(objective);
      if (type === "REGIONAL_BOSS_DEFEATED" && !isBoss) {
        return response({ error: "TARGET_IS_NOT_BOSS" }, 409);
      }
      if (isBoss && (kind === "boss" || kind === "raid" || requiresBoss || type === "REGIONAL_BOSS_DEFEATED")) {
        stageId = kind === "raid" ? "guardiao" : "boss:" + creatureId;
      } else if (type === "CREATURE_DEFEATED" && kind === "raid") {
        counter = "raidKills";
      } else if (type === "CREATURE_DEFEATED" && kind === "hunt") {
        const tokens = targetTokens(mission.title);
        const creatureName = normalize(creature.name || creature.nome || "");
        if (tokens.length && !tokens.some(token => creatureName.includes(token))) {
          return response({ error: "CREATURE_TARGET_MISMATCH" }, 409);
        }
        counter = "kills";
      } else if (type === "CREATURE_DEFEATED" && /(criatura de rank compativel|supere uma criatura)/.test(objective)) {
        counter = "extraCreature";
      } else {
        return response({ error: "CREATURE_NOT_REQUIRED_FOR_MISSION" }, 409);
      }
    } else if (type === "MATERIAL_OBTAINED") {
      const items = Array.isArray(character.inventory?.items) ? [...character.inventory.items] : [];
      const requestedArtifact = String(body.targetId || "") === "artifact";
      if (kind === "collection" && !requestedArtifact) {
        const match = String(mission.objective || "").match(/(?:unidades?\s+de|quantidade\s+de)\s+([^.;]+)/i);
        const materialName = (match?.[1] || String(mission.title || "Material da missão").split(":").pop()).trim();
        const existingCount = Number(counters.materials) || 0;
        if (existingCount + amount > requiredAmount(mission.objective)) return response({ error: "COLLECTION_QUANTITY_EXCEEDED" }, 409);
        const itemId = "mission_" + body.missionId + "_resource";
        const index = items.findIndex(item => item && item.id === itemId);
        if (index >= 0) items[index] = { ...items[index], quantity: Math.min(1000, (Number(items[index].quantity) || 0) + amount) };
        else items.push({ id: itemId, name: materialName, description: "Material coletado durante a missão " + mission.title, type: "MATERIAL", quantity: amount, materialRank: String(mission.rank || "E"), materialOrigin: String(mission.region || "Missão da Guilda") });
        nextInventoryItems = items;
        counter = "materials";
      } else {
        if (!/(artefato raro|reliquia unica|amostra unica)/.test(objective)) return response({ error: "MATERIAL_NOT_REQUIRED" }, 409);
        const artifactName = objective.includes("reliquia unica") ? "Relíquia única" : objective.includes("amostra unica") ? "Amostra única" : "Artefato raro";
        const artifactId = "mission_" + body.missionId + "_artifact";
        const index = items.findIndex(item => item && item.id === artifactId);
        if (index < 0) items.push({ id: artifactId, name: artifactName, description: "Artefato recuperado durante a missão " + mission.title, type: "MATERIAL", quantity: 1, materialRank: String(mission.rank || "E"), materialOrigin: String(mission.region || "Missão da Guilda") });
        nextInventoryItems = items;
        counter = "artifact";
      }
    } else {
      const expectedTypes = {
        exploration: ["LOCATION_DISCOVERED"],
        investigation: ["EVIDENCE_FOUND"],
        escort: ["ESCORT_STEP_COMPLETED"],
        protection: ["PROTECTED_TARGET_SURVIVED"],
        tracking: ["TRACKING_CLUE_FOUND"],
        purification: ["CORRUPTION_SOURCE_CLEARED"],
        raid: ["RAID_STEP_COMPLETED"],
        boss: ["REGIONAL_BOSS_DEFEATED"]
      };
      if (type === "RAID_STEP_COMPLETED") {
        if (kind !== "raid") return response({ error: "RAID_STEP_NOT_REQUIRED" }, 409);
        const step = normalize(body.targetId || "");
        const canonical = step.includes("entrada") ? "entrada"
          : step.includes("grupo") || step.includes("onda") ? "grupos"
          : step.includes("nucleo") || step.includes("core") ? "nucleo" : "";
        if (!canonical) return response({ error: "INVALID_RAID_STEP" }, 400);
        stageId = canonical;
      } else if (kind === "hunt" && type === "EVIDENCE_FOUND" && objective.includes("provas")) {
        counter = "evidence";
        stageId = "prova:" + String(body.targetId || "");
      } else {
        const allowed = expectedTypes[kind] || [];
        if (!allowed.includes(type)) {
          if (type === "EVIDENCE_FOUND" && /(prova|evidencia)/.test(objective)) counter = "extraEvidence";
          else return response({ error: "EVENT_NOT_REQUIRED_FOR_MISSION" }, 409);
        }
        if (!counter) counter = eventCounter(type);
        stageId = type + ":" + String(body.targetId || "");
      }
      if (!String(body.targetId || "").trim()) return response({ error: "MISSION_EVENT_TARGET_REQUIRED" }, 400);
    }

    if (stageId) {
      if (stages.includes(stageId)) return response({ accepted: false, duplicate: true, progress: counters });
      stages.push(stageId);
      counter = counter || (stageId === "guardiao" ? "guardians" : stageId === "entrada" || stageId === "grupos" || stageId === "nucleo" ? "raidStages" : "stages");
      counters[counter] = Math.min(100000, (Number(counters[counter]) || 0) + 1);
    } else {
      if (!counter) return response({ error: "EVENT_NOT_SUPPORTED" }, 409);
      counters[counter] = Math.min(100000, (Number(counters[counter]) || 0) + (type === "CREATURE_DEFEATED" ? 1 : amount));
      if (kind === "raid" && type === "CREATURE_DEFEATED" &&
          (counters.raidKills || 0) >= 3 && !stages.includes("grupos")) {
        stages.push("grupos");
        counters.raidStages = (Number(counters.raidStages) || 0) + 1;
      }
    }

    const nextProcessed = [...processed, eventId].slice(-1000);
    const completed = progressComplete(kind, mission.objective, counters, stages);
    const caps = rewardCaps(mission.rank, mission.rarity);
    const rewardXp = completed ? Math.min(caps.xp, Math.max(0, Math.floor(Number(mission.rewardXp) || caps.xp))) : 0;
    const rewardGold = completed ? Math.min(caps.gold, Math.max(0, Math.floor(Number(mission.rewardGold) || caps.gold))) : 0;
    const characterInventory = character.inventory || {};
    const levelResult = completed ? levelUp(character.level, character.xp, character.attributePoints, rewardXp) : null;
    const nextGold = Math.max(0, Number(characterInventory.gold) || 0) + rewardGold;

    const projectId = env.FIREBASE_PROJECT_ID || "ascensao-do-soberano";
    const prefix = "projects/" + projectId + "/databases/(default)/documents/";
    const missionFields = {
      progressCounters: counters,
      completedStages: stages,
      processedEventIds: nextProcessed,
      updatedAt: new Date().toISOString()
    };
    if (completed) Object.assign(missionFields, {
      status: "COMPLETED",
      completedAt: new Date().toISOString(),
      rewardClaimed: true,
      rewardGoldPaid: rewardGold,
      rewardXpPaid: rewardXp
    });
    const writes = [{
      update: { name: prefix + missionPath, fields: encodeFirestoreFields(missionFields) },
      updateMask: { fieldPaths: Object.keys(missionFields) }
    }];
    if (completed || nextInventoryItems !== null) {
      const characterFields = {};
      const characterMasks = [];
      if (nextInventoryItems !== null) {
        characterFields.inventory = { items: nextInventoryItems };
        characterMasks.push("inventory.items");
      }
      if (completed) {
        characterFields.xp = levelResult.xp;
        characterFields.level = levelResult.level;
        characterFields.attributePoints = levelResult.attributePoints;
        characterFields.inventory = { ...(characterFields.inventory || {}), gold: nextGold };
        characterMasks.push("xp", "level", "attributePoints", "inventory.gold");
      }
      writes.push({
        update: { name: prefix + characterPath, fields: encodeFirestoreFields(characterFields) },
        updateMask: { fieldPaths: characterMasks }
      });
    }
    await firestoreAdminCommitTransaction(env, transaction, writes, fetchImpl);
    return response({
      accepted: true, duplicate: false, completed,
      progress: counters, completedStages: stages,
      rewards: completed ? { xp: rewardXp, gold: rewardGold, levelsGained: levelResult.levelsGained } : null
    });
  } catch (error) {
    return response({ error: "MISSION_PROCESSING_FAILED", message: "Não foi possível salvar o progresso da missão." }, 503);
  }
}
