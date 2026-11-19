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
  const evidenceCount = (counters.extraEvidence || 0) +
    (kind === "investigation" || kind === "hunt" ? (counters.evidence || 0) : 0);
  const extraEvidence = !/(prova|evidencia)/.test(normalized) || evidenceCount >= 1;
  const creatureProofCount = (counters.extraCreature || 0) + (kind === "hunt" ? (counters.kills || 0) : 0);
  const extraCreature = !/(criatura de rank compativel|supere uma criatura)/.test(normalized) || creatureProofCount >= 1;
  const extraBoss = !/(guardiao|chefe regional|chefe world|chefe de alto rank)/.test(normalized) ||
    stages.some(stage => stage.startsWith("boss:") || stage === "guardiao");
  const requiresArtifact = /(artefato raro|reliquia unica|suprimentos roubados|selo imperial)/.test(normalized);
  const requiresSample = /amostra unica/.test(normalized);
  const extraArtifact = !requiresArtifact || (counters.artifact || 0) >= 1;
  const extraSample = !requiresSample || (counters.sample || 0) >= 1;
  return primary && extraEvidence && extraCreature && extraBoss && extraArtifact && extraSample;
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

function rollMissionChallenge(character, mission, type, targetId, forcedRoll) {
  const attribute = type === "EVIDENCE_FOUND" ? "intelligence"
    : type === "CORRUPTION_SOURCE_CLEARED" || (type === "RAID_STEP_COMPLETED" && targetId === "nucleo") ? "spirit"
    : type === "ESCORT_STEP_COMPLETED" || type === "PROTECTED_TARGET_SURVIVED" ? "vitality"
    : type === "TRACKING_CLUE_FOUND" || type === "MATERIAL_OBTAINED" || type === "LOCATION_DISCOVERED" ? "agility"
    : type === "RAID_STEP_COMPLETED" ? "intelligence" : "strength";
  const stat = Math.max(0, Number(character.attributes?.[attribute]) || 0);
  const level = Math.max(1, Number(character.level) || 1);
  const bonus = Math.floor(stat / 5) + Math.floor(level / 10);
  const rankIndex = Math.max(0, RANKS.indexOf(String(mission.rank || "E").toUpperCase()));
  const rarityIndex = Math.max(0, ["Comum", "Incomum", "Rara", "Épica", "Lendária", "Mítica", "Divina", "World"].indexOf(String(mission.rarity || "Comum")));
  const multiplier = Math.min(10, Math.max(1, Number(mission.difficultyMultiplier) || 1));
  const difficultyClass = Math.min(29, Math.max(8, Math.round(8 + rankIndex * 1.5 + rarityIndex * 1.25 + (multiplier - 1) * 1.2)));
  const roll = Number.isInteger(forcedRoll) ? Math.min(20, Math.max(1, forcedRoll)) : crypto.getRandomValues(new Uint32Array(1))[0] % 20 + 1;
  const success = roll === 20 || (roll !== 1 && roll + bonus >= difficultyClass);
  return { roll, attribute, bonus, difficultyClass, success, total: roll + bonus };
}
function response(body, status = 200) {
  return { body, status };
}

const OFFER_REGIONS = [
  { id: "central_wilds", name: "Região Central", destinations: ["aurelia", "cidade_do_sol", "arkanis", "mina_dourada", "vila_esperanca"], tasks: ["Investigar cartas desaparecidas", "Escoltar uma caravana", "Rastrear ladrões na estrada", "Proteger os arredores de Aurelia"] },
  { id: "dark_forest", name: "Floresta Arcana", destinations: ["clareira_inicial", "eldarion", "vila_verdejante", "ruinas_elficas"], tasks: ["Recolher ervas luminosas", "Investigar rastros entre as raízes", "Encontrar uma patrulha desaparecida", "Purificar um foco de corrupção"] },
  { id: "frost_mountains", name: "Montanhas Gélidas", destinations: ["fortaleza_glacial", "caverna_gelo", "pico_aurora"], tasks: ["Recolher cristais de gelo", "Localizar exploradores perdidos", "Investigar uma caverna congelada", "Caçar a fera da nevasca"] },
  { id: "imperial_frontier", name: "Terras do Império", destinations: ["valdracon", "forte_guarda", "catacumbas_reais", "vila_helios"], tasks: ["Entregar um selo imperial", "Escoltar suprimentos", "Investigar as catacumbas", "Impedir uma conspiração na fronteira"] },
  { id: "shadowlands", name: "Terras das Sombras", destinations: ["malachar", "templo_sombrio", "covil_mortos", "vila_necropole"], tasks: ["Encontrar um mensageiro", "Investigar vozes no templo", "Destruir um altar corrompido", "Rastrear uma presença ancestral"] },
  { id: "ancestral_desert", name: "Deserto Ancestral", destinations: ["tharion", "oasis_perdido", "ruinas_antigas", "caverna_escorpiao"], tasks: ["Encontrar água para uma caravana", "Mapear ruínas soterradas", "Recuperar uma relíquia", "Enfrentar o guardião das dunas"] },
  { id: "eternal_sea", name: "Mar Eterno", destinations: ["kyrath", "ilha_serpente", "torre_oceano"], tasks: ["Localizar um barco à deriva", "Escoltar um navio mercante", "Investigar uma torre submersa", "Rastrear a criatura das profundezas"] },
  { id: "forgotten_ruins", name: "Ruínas Esquecidas", destinations: ["ruinas_elficas", "ruinas_antigas", "catacumbas_reais"], tasks: ["Decifrar inscrições antigas", "Recuperar um artefato perdido", "Investigar uma câmara selada", "Impedir o despertar de uma entidade"] }
];
const LOCATION_NAMES = {
  aurelia: "Aurelia", cidade_do_sol: "Cidade do Sol", arkanis: "Arkanis",
  mina_dourada: "Mina Dourada", vila_esperanca: "Vila Esperança",
  clareira_inicial: "Clareira Inicial", eldarion: "Eldarion",
  vila_verdejante: "Vila Verdejante", ruinas_elficas: "Ruínas Élficas",
  fortaleza_glacial: "Fortaleza Glacial", caverna_gelo: "Caverna do Gelo",
  pico_aurora: "Pico da Aurora", valdracon: "Valdracon", forte_guarda: "Forte da Guarda",
  catacumbas_reais: "Catacumbas Reais", vila_helios: "Vila Hélios",
  malachar: "Malachar", templo_sombrio: "Templo Sombrio", covil_mortos: "Covil dos Mortos",
  vila_necropole: "Vila Necrópole", tharion: "Tharion", oasis_perdido: "Oásis Perdido",
  ruinas_antigas: "Ruínas Antigas", caverna_escorpiao: "Caverna do Escorpião",
  kyrath: "Kyrath", ilha_serpente: "Ilha da Serpente", torre_oceano: "Torre do Oceano"
};
const RARITY_DATA = {
  "Comum": [1, 1], "Incomum": [1.5, 1.2], "Rara": [2, 1.5],
  "Épica": [3, 2], "Lendária": [5, 3], "Mítica": [8, 4.5],
  "Divina": [12, 7], "World": [20, 10]
};
const RANK_DATA = [["E", 1, 35], ["D", 3, 60], ["C", 7, 100], ["B", 14, 160], ["A", 25, 240], ["S", 40, 360], ["SS", 60, 520], ["SSS", 80, 800]];

function inferOfferType(task) {
  const value = normalize(task);
  if (value.includes("escoltar")) return "Escolta";
  if (value.includes("proteger")) return "Proteção";
  if (value.includes("rastrear")) return "Rastreamento";
  if (value.includes("purificar") || value.includes("destruir um altar") || value.includes("destruir altar")) return "Purificação";
  if (value.includes("recolher") || value.includes("encontrar agua") || value.includes("entregar ") ||
      value.includes("recuperar suprimentos") || value.includes("recuperar uma reliquia") || value.includes("recuperar um artefato")) return "Coleta";
  if (value.includes("investigar") || value.includes("decifrar") || value.includes("localizar ") ||
      value.includes("encontrar um mensageiro") || value.includes("encontrar uma patrulha")) return "Investigação";
  if (value.includes("mapear")) return "Exploração";
  if (value.includes("impedir o despertar")) return "Chefe regional";
  if (value.includes("cacar") || value.includes("enfrentar o guardiao") || value.includes("enfrentar a fera") || value.includes("criatura das profundezas")) return "Caçada e ameaça regional";
  return "Exploração";
}

function objectiveForOffer(task, rarity) {
  const quantities = { "Comum": 3, "Incomum": 5, "Rara": 8, "Épica": 12, "Lendária": 20, "Mítica": 30, "Divina": 50, "World": 100 };
  const conditions = {
    "Comum": "Retorne à Guilda com uma prova simples da conclusão.",
    "Incomum": "Retorne com uma prova verificável e não abandone o objetivo.",
    "Rara": "Conclua em uma área remota e traga uma evidência adicional.",
    "Épica": "Conclua em uma área perigosa e supere uma criatura de rank compatível.",
    "Lendária": "Conclua sem perder o objetivo e derrote o guardião que o protege.",
    "Mítica": "Conclua e derrote um chefe regional antes de retornar.",
    "Divina": "Conclua, derrote um chefe de alto rank e recupere um artefato raro.",
    "World": "Conclua em uma zona extrema, derrote um chefe World e recupere uma relíquia única."
  };
  const normalized = String(task).trim().replace(/[.]$/, "");
  if (normalized.toLowerCase().startsWith("recolher ") || normalize(normalized).startsWith("encontrar agua")) {
    const resource = normalized.toLowerCase().startsWith("recolher ")
      ? normalized.slice("Recolher ".length).trim() : "água potável para a caravana";
    const sample = rarity === "World" ? " e uma amostra única" : "";
    return "Obtenha " + quantities[rarity] + " unidades de " + resource + sample + ". " + conditions[rarity];
  }
  return normalized + ". " + conditions[rarity];
}

function sameValue(actual, expected) {
  if (typeof expected === "number") return Number(actual) === expected;
  return actual === expected;
}

function validateMissionOffer(offer) {
  if (!offer || typeof offer !== "object") return null;
  const rarity = String(offer.rarity || "");
  const rarityValues = RARITY_DATA[rarity];
  if (!rarityValues) return null;
  const [rarityMultiplier, difficultyMultiplier] = rarityValues;
  const rankIndex = RANK_DATA.findIndex(row => row[0] === offer.rank);
  if (rankIndex < 0) return null;
  const [rank, level, baseReward] = RANK_DATA[rankIndex];
  const regionIndex = OFFER_REGIONS.findIndex(region => region.id === offer.regionId);
  if (regionIndex < 0) return null;
  const region = OFFER_REGIONS[regionIndex];
  const task = region.tasks[rankIndex % region.tasks.length];
  const destinationId = region.destinations[(rankIndex + regionIndex) % region.destinations.length];
  const title = rank === "SSS" ? "Calamidade: " + task : rank === "SS" ? "Contrato lendário: " + task : rank === "S" ? "Contrato de elite: " + task : task;
  const uuid = "[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
  if (!new RegExp("^guild_" + region.id + "_" + rank.toLowerCase() + "_" + uuid + "$").test(String(offer.id || ""))) return null;
  const expected = {
    title, rank, type: inferOfferType(task), regionId: region.id, regionName: region.name,
    destinationId, destinationName: LOCATION_NAMES[destinationId] || destinationId,
    summary: "A guilda recebeu um relato de atividade incomum em " + (LOCATION_NAMES[destinationId] || destinationId) + ".",
    objective: objectiveForOffer(task, rarity),
    rewardGold: Math.trunc(baseReward * (regionIndex + 1) * rarityMultiplier),
    rewardXp: Math.trunc(baseReward * 2 * rarityMultiplier),
    recommendedLevel: level, special: rank === "SS" || rank === "SSS",
    rarity, rarityMultiplier, difficultyMultiplier
  };
  for (const [key, value] of Object.entries(expected)) if (!sameValue(offer[key], value)) return null;
  return { ...expected, id: offer.id };
}

function validateSpecialOffer(offer) {
  if (!offer || typeof offer !== "object") return null;
  const rarity = String(offer.rarity || "");
  const data = RARITY_DATA[rarity];
  if (!data || !["Comum", "Incomum", "Rara"].includes(rarity)) return null;
  const [rarityMultiplier, difficultyMultiplier] = data;
  const uuid = "[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
  const id = String(offer.id || "");
  if (/^guild_caca_inicial_[0-3]_/.test(id)) {
    const match = id.match(new RegExp("^guild_caca_inicial_([0-3])_" + uuid + "$"));
    if (!match) return null;
    const index = Number(match[1]);
    const hunts = [
      ["Caçada: ratos da clareira", "Caçada", "Derrote 3 ratos selvagens de rank E e recolha provas da ameaça."],
      ["Caçada: javalis agressivos", "Caçada", "Afaste 3 javalis de rank E que estão atacando viajantes."],
      ["Caçada: goblins saqueadores", "Caçada", "Derrote 3 goblins de rank E e recupere os suprimentos roubados."],
      ["Caçada: esqueletos errantes", "Caçada", "Derrote 3 esqueletos de rank E que rondam as ruínas."]
    ];
    const [title, type, objective] = hunts[index];
    const destinationId = index === 3 ? "ruinas_elficas" : "clareira_inicial";
    const regionId = index === 3 ? "forgotten_ruins" : "dark_forest";
    const regionName = index === 3 ? "Ruínas Esquecidas" : "Floresta Arcana";
    const destinationName = LOCATION_NAMES[destinationId];
    const expected = {
      title, rank: "E", type, regionId, regionName, destinationId, destinationName,
      summary: "A Guilda recebeu relatos de criaturas fracas ameaçando viajantes e moradores.",
      objective: objective + " A ameaça deve permanecer compatível com rank E e raridade " + rarity + ".",
      rewardGold: Math.trunc(35 * rarityMultiplier), rewardXp: Math.trunc(70 * rarityMultiplier),
      recommendedLevel: 1, special: false, rarity, rarityMultiplier, difficultyMultiplier
    };
    for (const [key, value] of Object.entries(expected)) if (!sameValue(offer[key], value)) return null;
    return { ...expected, id };
  }
  if (new RegExp("^guild_raid_masmorra_e_" + uuid + "$").test(id)) {
    const expected = {
      title: "Raid de Masmorra: Cripta dos Primeiros Ossos", rank: "E", type: "Raid de masmorra",
      regionId: "forgotten_ruins", regionName: "Ruínas Esquecidas", destinationId: "ruinas_elficas",
      destinationName: LOCATION_NAMES.ruinas_elficas,
      summary: "Um grupo de aventureiros precisa limpar uma pequena masmorra recém-descoberta. A incursão é de rank E e adequada a iniciantes.",
      objective: "Conclua a incursão em etapas: atravesse a entrada, vença os grupos de criaturas de rank E, encontre o núcleo da cripta e derrote o guardião final de rank E. Não transforme a raid em ameaça de rank superior.",
      rewardGold: Math.trunc(55 * rarityMultiplier), rewardXp: Math.trunc(110 * rarityMultiplier),
      recommendedLevel: 1, special: true, rarity, rarityMultiplier, difficultyMultiplier
    };
    for (const [key, value] of Object.entries(expected)) if (!sameValue(offer[key], value)) return null;
    return { ...expected, id };
  }
  return null;
}

export async function handleMissionAccept(env, uid, body, fetchImpl = fetch) {
  const characterId = String(body?.characterId || "");
  const offer = body?.mission;
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid) || !/^[A-Za-z0-9_-]{1,128}$/.test(characterId)) {
    return response({ error: "INVALID_MISSION_ACCEPT" }, 400);
  }
  const verified = validateMissionOffer(offer) || validateSpecialOffer(offer);
  if (!verified) return response({ error: "MISSION_OFFER_INVALID", message: "A oferta não corresponde ao catálogo oficial da Guilda." }, 400);
  const missionPath = "characters/" + characterId + "/guildContracts/" + verified.id;
  const characterPath = "characters/" + characterId;
  try {
    const transaction = await firestoreAdminBeginTransaction(env, fetchImpl);
    const [characterDocument, missionDocument] = await Promise.all([
      firestoreAdminGetDocumentInTransaction(env, characterPath, transaction, fetchImpl),
      firestoreAdminGetDocumentInTransaction(env, missionPath, transaction, fetchImpl)
    ]);
    if (!characterDocument) return response({ error: "CHARACTER_NOT_FOUND" }, 404);
    const character = decodeFirestoreFields(characterDocument.fields || {});
    if (character.ownerUid !== uid) return response({ error: "CHARACTER_OWNER_MISMATCH" }, 403);
    if (missionDocument) return response({ error: "MISSION_ALREADY_USED" }, 409);
    const currentRank = RANKS.indexOf(String(character.guildRank || "E").toUpperCase());
    const missionRank = RANKS.indexOf(String(verified.rank).toUpperCase());
    if (currentRank < 0 || missionRank < 0 || missionRank > currentRank) {
      return response({ error: "GUILD_RANK_TOO_LOW" }, 403);
    }
    if (Number(character.level || 1) < verified.recommendedLevel) {
      return response({ error: "CHARACTER_LEVEL_TOO_LOW" }, 403);
    }
    if (character.activeGuildMissionId && character.activeGuildMissionId !== verified.id) {
      return response({ error: "ACTIVE_MISSION_EXISTS", message: "Conclua ou abandone a missão atual antes de aceitar outra." }, 409);
    }
    const missionFields = {
      contractId: verified.id, characterId, ownerUid: uid,
      title: verified.title, rank: verified.rank, ecosystemId: verified.regionId,
      biome: verified.regionName, region: verified.regionName, location: verified.destinationName,
      destinationId: verified.destinationId, kind: verified.type, objective: verified.objective,
      summary: verified.summary, rarity: verified.rarity, rarityMultiplier: verified.rarityMultiplier,
      difficultyMultiplier: verified.difficultyMultiplier, rewardGold: verified.rewardGold,
      rewardXp: verified.rewardXp, recommendedLevel: verified.recommendedLevel,
      special: verified.special, threat: "Ameaça compatível com rank " + verified.rank + " e raridade " + verified.rarity,
      rewardPreview: verified.rewardGold + " ouro · " + verified.rewardXp + " XP",
      status: "ACCEPTED", progressCounters: {}, completedStages: [], processedEventIds: [],
      rewardClaimed: false, acceptedAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    const projectId = env.FIREBASE_PROJECT_ID || "ascensao-do-soberano";
    const prefix = "projects/" + projectId + "/databases/(default)/documents/";
    await firestoreAdminCommitTransaction(env, transaction, [
      {
        update: { name: prefix + missionPath, fields: encodeFirestoreFields(missionFields) },
        currentDocument: { exists: false }
      },
      {
        update: { name: prefix + characterPath, fields: encodeFirestoreFields({ activeGuildMissionId: verified.id }) },
        updateMask: { fieldPaths: ["activeGuildMissionId"] }
      }
    ], fetchImpl);
    return response({ accepted: true, missionId: verified.id, mission: missionFields });
  } catch {
    return response({ error: "MISSION_ACCEPT_FAILED", message: "Não foi possível aceitar a missão com segurança." }, 503);
  }
}

export async function handleMissionStatusChange(env, uid, body, fetchImpl = fetch) {
  const characterId = String(body?.characterId || "");
  const missionId = String(body?.missionId || "");
  const status = String(body?.status || "");
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid) ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(characterId) ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(missionId) ||
      !["ABANDONED", "FAILED"].includes(status)) return response({ error: "INVALID_MISSION_STATUS" }, 400);
  const characterPath = "characters/" + characterId;
  const missionPath = characterPath + "/guildContracts/" + missionId;
  try {
    const transaction = await firestoreAdminBeginTransaction(env, fetchImpl);
    const [characterDocument, missionDocument] = await Promise.all([
      firestoreAdminGetDocumentInTransaction(env, characterPath, transaction, fetchImpl),
      firestoreAdminGetDocumentInTransaction(env, missionPath, transaction, fetchImpl)
    ]);
    if (!characterDocument || !missionDocument) return response({ error: "MISSION_NOT_FOUND" }, 404);
    const character = decodeFirestoreFields(characterDocument.fields || {});
    const mission = decodeFirestoreFields(missionDocument.fields || {});
    if (character.ownerUid !== uid || mission.ownerUid !== uid) return response({ error: "MISSION_OWNER_MISMATCH" }, 403);
    if (mission.status !== "ACCEPTED") return response({ error: "MISSION_NOT_ACTIVE" }, 409);
    if (character.activeGuildMissionId && character.activeGuildMissionId !== missionId) return response({ error: "ACTIVE_MISSION_MISMATCH" }, 409);
    const projectId = env.FIREBASE_PROJECT_ID || "ascensao-do-soberano";
    const prefix = "projects/" + projectId + "/databases/(default)/documents/";
    const timestamp = new Date().toISOString();
    await firestoreAdminCommitTransaction(env, transaction, [
      {
        update: { name: prefix + missionPath, fields: encodeFirestoreFields({ status, updatedAt: timestamp, ...(status === "ABANDONED" ? { abandonedAt: timestamp } : { failedAt: timestamp }) }) },
        updateMask: { fieldPaths: ["status", "updatedAt", status === "ABANDONED" ? "abandonedAt" : "failedAt"] }
      },
      {
        update: { name: prefix + characterPath, fields: encodeFirestoreFields({ activeGuildMissionId: "" }) },
        updateMask: { fieldPaths: ["activeGuildMissionId"] }
      }
    ], fetchImpl);
    return response({ updated: true, status });
  } catch {
    return response({ error: "MISSION_STATUS_UPDATE_FAILED", message: "Não foi possível atualizar o status da missão." }, 503);
  }
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

    const challenge = options.verifiedCombat === true ? null
      : rollMissionChallenge(character, mission, type, body.targetId, options.roll);
    if (challenge && !challenge.success) {
      return response({
        accepted: false, duplicate: false, completed: false,
        reason: "A tentativa não superou a dificuldade desta etapa. Tente outra abordagem.",
        challenge
      });
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
      const isOfficialBoss = creature.isBoss === true || creature.chefe === true;
      const worldBossRequired = isOfficialBoss && objective.includes("chefe world");
      const highRankBossRequired = isOfficialBoss && objective.includes("chefe de alto rank");
      const minimumHighRank = RANKS.indexOf("S");
      if (actualRank < 0 || rankLimit < 0 ||
          (actualRank > rankLimit && !worldBossRequired) ||
          (worldBossRequired && creatureRank !== "WORLD") ||
          (highRankBossRequired && actualRank < minimumHighRank)) {
        return response({ error: "CREATURE_RANK_MISMATCH", message: "A criatura está acima do rank permitido ou não cumpre a raridade desta missão." }, 409);
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
      const requestedSample = String(body.targetId || "") === "sample";
      const requiresArtifact = /(artefato raro|reliquia unica|suprimentos roubados|selo imperial)/.test(objective);
      const requiresSample = /amostra unica/.test(objective);
      if (requestedSample || requestedArtifact) {
        if (requestedSample && !requiresSample) return response({ error: "SAMPLE_NOT_REQUIRED" }, 409);
        if (requestedArtifact && !requiresArtifact) return response({ error: "ARTIFACT_NOT_REQUIRED" }, 409);
        const artifactName = objective.includes("suprimentos roubados") ? "Suprimentos roubados"
          : objective.includes("selo imperial") ? "Selo imperial"
          : objective.includes("reliquia unica") ? "Relíquia única" : "Artefato raro";
        const itemName = requestedSample ? "Amostra única" : artifactName;
        const itemId = "mission_" + body.missionId + (requestedSample ? "_sample" : "_artifact");
        const index = items.findIndex(item => item && item.id === itemId);
        if (index < 0) items.push({ id: itemId, name: itemName, description: "Item recuperado durante a missão " + mission.title, type: "MATERIAL", quantity: 1, materialRank: String(mission.rank || "E"), materialOrigin: String(mission.region || "Missão da Guilda") });
        nextInventoryItems = items;
        counter = requestedSample ? "sample" : "artifact";
      } else if (kind === "collection") {
        const match = String(mission.objective || "").match(/(?:unidades?\\s+de|quantidade\\s+de)\\s+([^.;]+)/i);
        const firstSentence = String(mission.objective || "").split(".")[0].trim();
        const fallbackItem = firstSentence.replace(/^(obtenha\\s+\\d+\\s+unidades?\\s+de|recuperar|entregar|encontrar)\\s*/i, "").trim();
        const materialName = (match?.[1] || fallbackItem || String(mission.title || "Material da missão").split(":").pop()).trim();
        const existingCount = Number(counters.materials) || 0;
        if (existingCount + amount > requiredAmount(mission.objective)) return response({ error: "COLLECTION_QUANTITY_EXCEEDED" }, 409);
        const itemId = "mission_" + body.missionId + "_resource";
        const index = items.findIndex(item => item && item.id === itemId);
        if (index >= 0) items[index] = { ...items[index], quantity: Math.min(1000, (Number(items[index].quantity) || 0) + amount) };
        else items.push({ id: itemId, name: materialName, description: "Material coletado durante a missão " + mission.title, type: "MATERIAL", quantity: amount, materialRank: String(mission.rank || "E"), materialOrigin: String(mission.region || "Missão da Guilda") });
        nextInventoryItems = items;
        counter = "materials";
      } else {
        return response({ error: "MATERIAL_NOT_REQUIRED" }, 409);
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
        characterFields.activeGuildMissionId = "";
        characterFields.inventory = { ...(characterFields.inventory || {}), gold: nextGold };
        characterMasks.push("xp", "level", "attributePoints", "activeGuildMissionId", "inventory.gold");
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
      challenge,
      rewards: completed ? { xp: rewardXp, gold: rewardGold, levelsGained: levelResult.levelsGained } : null
    });
  } catch (error) {
    return response({ error: "MISSION_PROCESSING_FAILED", message: "Não foi possível salvar o progresso da missão." }, 503);
  }
}
