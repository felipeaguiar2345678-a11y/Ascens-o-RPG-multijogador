/**
 * Simulação determinística dos aventureiros autônomos do mundo.
 * Não usa IA externa, chaves ou chamadas pagas.
 */

const TEMPLATES = [
  { name: "Kael", className: "GUERREIRO", temperament: "CORAJOSO", courage: 88, ambition: 62, curiosity: 48, sociability: 55, caution: 28 },
  { name: "Neris", className: "ARQUEIRA", temperament: "CURIOSO", courage: 62, ambition: 70, curiosity: 91, sociability: 66, caution: 42 },
  { name: "Maelis", className: "MAGA", temperament: "PRUDENTE", courage: 42, ambition: 76, curiosity: 82, sociability: 48, caution: 88 },
  { name: "Darian", className: "CAVALEIRO", temperament: "LEAL", courage: 78, ambition: 45, curiosity: 35, sociability: 82, caution: 56 },
  { name: "Vexa", className: "ASSASSINA", temperament: "SOLITARIO", courage: 73, ambition: 88, curiosity: 69, sociability: 22, caution: 66 },
  { name: "Iria", className: "CURANDEIRA", temperament: "SOCIAVEL", courage: 50, ambition: 54, curiosity: 63, sociability: 94, caution: 72 },
  { name: "Orin", className: "EXPLORADOR", temperament: "CURIOSO", courage: 67, ambition: 58, curiosity: 96, sociability: 60, caution: 46 },
  { name: "Soren", className: "GUERREIRO", temperament: "AMBICIOSO", courage: 81, ambition: 92, curiosity: 51, sociability: 44, caution: 35 },
  { name: "Lyra", className: "MAGA", temperament: "PRUDENTE", courage: 38, ambition: 68, curiosity: 87, sociability: 73, caution: 91 },
  { name: "Tarek", className: "ARQUEIRO", temperament: "LEAL", courage: 72, ambition: 59, curiosity: 64, sociability: 85, caution: 52 }
];

function stableRoll(value, revision) {
  let hash = 2166136261;
  const source = String(value) + ":" + String(revision);
  for (let i = 0; i < source.length; i++) {
    hash ^= source.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) % 100;
}

export function seedAutonomousAdventurers(settlements, now = Date.now()) {
  const seeded = (settlements || []).map((city, index) => {
    const template = TEMPLATES[index % TEMPLATES.length];
    return {
      id: "adventurer_" + template.name.toLowerCase() + "_" + city.id,
      name: template.name,
      role: "AVENTUREIRO",
      className: template.className,
      temperament: template.temperament,
      homeLocationId: city.id,
      currentLocationId: city.id,
      targetLocationId: null,
      level: 3 + (index % 5),
      experience: 0,
      health: 100,
      maxHealth: 100,
      stamina: 100,
      maxStamina: 100,
      gold: 20 + index * 7,
      personality: {
        courage: template.courage,
        ambition: template.ambition,
        curiosity: template.curiosity,
        sociability: template.sociability,
        caution: template.caution
      },
      activity: "SOCIALIZING",
      mood: "DETERMINADO",
      goal: "EXPLORAR_O_MUNDO",
      currentMissionId: null,
      partyId: null,
      relationships: [],
      memories: [{ type: "INICIO_DA_JORNADA", at: now, text: "Começou sua jornada em " + city.name + "." }],
      lastDecisionAtMillis: now,
      nextDecisionAtMillis: now
    };
  });

  // Um explorador já percorre a região inicial quando o jogador chega.
  seeded.push({
    id: "adventurer_ayla_clareira_inicial",
    name: "Ayla",
    role: "AVENTUREIRO",
    className: "EXPLORADORA",
    temperament: "CURIOSO",
    homeLocationId: "vila_verdejante",
    currentLocationId: "clareira_inicial",
    targetLocationId: null,
    level: 4,
    experience: 0,
    health: 100,
    maxHealth: 100,
    stamina: 100,
    maxStamina: 100,
    gold: 35,
    personality: { courage: 76, ambition: 70, curiosity: 94, sociability: 70, caution: 42 },
    activity: "EXPLORANDO",
    mood: "CURIOSO",
    goal: "INVESTIGAR_A_CLAREIRA",
    currentMissionId: null,
    partyId: null,
    relationships: [],
    memories: [{ type: "INICIO_DA_JORNADA", at: now, text: "Está investigando os caminhos próximos à Clareira Inicial." }],
    lastDecisionAtMillis: now,
    nextDecisionAtMillis: now
  });

  return seeded;
}

function nextHopToward(start, destination, neighbors) {
  if (!start || !destination || start === destination) return destination;
  const queue = [[start, null]];
  const visited = new Set([start]);
  while (queue.length) {
    const [current, firstHop] = queue.shift();
    for (const next of neighbors[current] || []) {
      if (visited.has(next)) continue;
      const hop = firstHop || next;
      if (next === destination) return hop;
      visited.add(next);
      queue.push([next, hop]);
    }
  }
  return (neighbors[start] || [])[0] || start;
}

function remember(adventurer, type, text, at) {
  const memories = [...(adventurer.memories || []), { type, text, at }];
  return memories.slice(-20);
}

function gainExperience(adventurer, amount, at, events) {
  let level = Math.max(1, adventurer.level || 1);
  let experience = Math.max(0, adventurer.experience || 0) + Math.max(0, amount);
  let maxHealth = Math.max(1, adventurer.maxHealth || 100);
  let maxStamina = Math.max(1, adventurer.maxStamina || 100);
  let health = Math.max(0, adventurer.health || 0);
  let stamina = Math.max(0, adventurer.stamina || 0);
  while (experience >= level * 100) {
    experience -= level * 100;
    level += 1;
    maxHealth += 8;
    maxStamina += 4;
    health = Math.min(maxHealth, health + 8);
    stamina = Math.min(maxStamina, stamina + 4);
    events.push({
      id: "adventurer-level-" + adventurer.id + "-" + level + "-" + at,
      type: "AVENTUREIRO_EVOLUIU",
      locationId: adventurer.currentLocationId,
      description: adventurer.name + " alcançou o nível " + level + ".",
      occurredAtMillis: at
    });
  }
  return { ...adventurer, level, experience, maxHealth, maxStamina, health, stamina };
}

export function advanceAutonomousAdventurers(
  rawAdventurers,
  settlements,
  neighbors,
  at,
  revision = 0
) {
  const cities = new Map((settlements || []).map((city) => [city.id, city]));
  const events = [];
  let adventurers = (rawAdventurers || []).map((raw) => {
    let npc = {
      ...raw,
      personality: raw.personality || {},
      memories: raw.memories || [],
      level: Math.max(1, raw.level || 1),
      health: Math.max(0, raw.health ?? 100),
      maxHealth: Math.max(1, raw.maxHealth || 100),
      stamina: Math.max(0, raw.stamina ?? 100),
      maxStamina: Math.max(1, raw.maxStamina || 100),
      gold: Math.max(0, raw.gold || 0)
    };
    const city = cities.get(npc.currentLocationId);
    const threatened = city && ["THREATENED", "BESIEGED", "CONQUERED"].includes(city.condition);
    const danger = threatened ? 75 : Math.min(100, Math.max(0, city?.hostileInvaders || 0) * 8);
    const roll = stableRoll(npc.id, revision);
    const courage = npc.personality.courage ?? 50;
    const curiosity = npc.personality.curiosity ?? 50;
    const caution = npc.personality.caution ?? 50;

    npc.lastDecisionAtMillis = at;

    // A sobrevivência tem prioridade sobre exploração, recompensa e orgulho.
    if (npc.health <= 25) {
      npc.goal = "SOBREVIVER";
      npc.mood = "FERIDO";
      npc.activity = "RETIRANDO";
      const hop = nextHopToward(npc.currentLocationId, npc.homeLocationId, neighbors);
      if (npc.currentLocationId !== npc.homeLocationId) {
        npc.currentLocationId = hop;
        npc.targetLocationId = npc.homeLocationId;
        npc.stamina = Math.max(0, npc.stamina - 8);
        npc.memories = remember(npc, "RETIRADA", "Recuou para sobreviver.", at);
      } else {
        npc.activity = "DESCANSANDO";
        npc.health = Math.min(npc.maxHealth, npc.health + 12);
        npc.stamina = Math.min(npc.maxStamina, npc.stamina + 22);
      }
      return npc;
    }

    if (npc.stamina <= 20) {
      npc.activity = "DESCANSANDO";
      npc.mood = "CANSADO";
      npc.health = Math.min(npc.maxHealth, npc.health + 4);
      npc.stamina = Math.min(npc.maxStamina, npc.stamina + 24);
      npc.targetLocationId = null;
      return npc;
    }

    // Missões defensivas existentes passam a atrair aventureiros capazes.
    const defenseMission = (cities.get(npc.currentLocationId)?.condition === "THREATENED" ||
      cities.get(npc.currentLocationId)?.condition === "BESIEGED")
      ? "defend-" + npc.currentLocationId : null;
    if (!defenseMission && typeof npc.currentMissionId === "string" &&
        npc.currentMissionId.startsWith("defend-")) {
      npc.currentMissionId = null;
      npc.memories = remember(npc, "MISSAO_CONCLUIDA", "A ameaça à cidade diminuiu.", at);
    }
    if (defenseMission && npc.level >= 3 && courage >= 45) {
      const iniciouDefesa = npc.currentMissionId !== defenseMission;
      npc.currentMissionId = defenseMission;
      npc.goal = "DEFENDER_A_CIDADE";
      npc.activity = "DEFENDING";
      npc.mood = "ALERTA";
      npc.health = Math.max(1, npc.health - Math.max(1, Math.floor(danger / 28)));
      npc.stamina = Math.max(0, npc.stamina - 9);
      npc.gold += 2;
      npc = gainExperience(npc, 8 + Math.floor(danger / 8), at, events);
      npc.memories = remember(npc, "DEFENDEU_CIDADE", "Ajudou a defender " + npc.currentLocationId + ".", at);
      if (iniciouDefesa) {
        events.push({
          id: "adventurer-defend-" + npc.id + "-" + at,
          type: "AVENTUREIRO_DEFENDEU_CIDADE",
          locationId: npc.currentLocationId,
          description: npc.name + " está ajudando a defender a cidade.",
          occurredAtMillis: at
        });
      }
      return npc;
    }

    if (npc.targetLocationId && npc.targetLocationId !== npc.currentLocationId) {
      const hop = nextHopToward(npc.currentLocationId, npc.targetLocationId, neighbors);
      const destination = cities.get(hop);
      npc.currentLocationId = hop;
      npc.activity = "VIAJANDO";
      npc.goal = "EXPLORAR_" + hop.toUpperCase();
      npc.mood = "FOCADO";
      npc.stamina = Math.max(0, npc.stamina - 7);
      npc = gainExperience(npc, 4, at, events);
      npc.memories = remember(npc, "VIAGEM", "Viajou para " + (destination?.name || hop) + ".", at);
      events.push({
        id: "adventurer-travel-" + npc.id + "-" + at,
        type: "AVENTUREIRO_VIAJOU",
        locationId: hop,
        description: npc.name + " chegou a " + (destination?.name || hop) + ".",
        occurredAtMillis: at
      });
      if (npc.currentLocationId === npc.targetLocationId) npc.targetLocationId = null;
      return npc;
    }

    const options = (neighbors[npc.currentLocationId] || [])
      .map((id) => cities.get(id))
      .filter(Boolean)
      .filter((destination) => {
        const destinationDanger = ["THREATENED", "BESIEGED", "CONQUERED"].includes(destination.condition) ? 75 : 10;
        return destinationDanger <= courage + (100 - caution) / 2;
      });

    if (options.length && roll < curiosity) {
      const destination = options[roll % options.length];
      npc.targetLocationId = destination.id;
      npc.goal = "EXPLORAR_" + destination.id.toUpperCase();
      npc.activity = "PREPARANDO_VIAGEM";
      npc.mood = "CURIOSO";
      npc.stamina = Math.max(0, npc.stamina - 3);
      return npc;
    }

    // Se não viajar, treina, socializa ou recupera recursos na cidade atual.
    if (roll < (npc.personality.ambition ?? 50)) {
      npc.activity = "TREINANDO";
      npc.goal = "FICAR_MAIS_FORTE";
      npc.mood = "DETERMINADO";
      npc.stamina = Math.max(0, npc.stamina - 5);
      npc = gainExperience(npc, 3, at, events);
    } else {
      npc.activity = "SOCIALIZANDO";
      npc.goal = "FORTALECER_LACOS";
      npc.mood = "TRANQUILO";
      npc.stamina = Math.min(npc.maxStamina, npc.stamina + 6);
      npc.health = Math.min(npc.maxHealth, npc.health + 2);
    }
    return npc;
  });

  // Aventureiros sociáveis podem formar grupos espontaneamente na mesma cidade.
  const grouped = new Set();
  for (const npc of adventurers) {
    if (npc.partyId || (npc.personality?.sociability ?? 50) < 70 || grouped.has(npc.id)) continue;
    const partners = adventurers.filter((other) =>
      other.id !== npc.id && !other.partyId && !grouped.has(other.id) &&
      other.currentLocationId === npc.currentLocationId &&
      (other.personality?.sociability ?? 50) >= 60
    ).slice(0, 2);
    if (!partners.length) continue;
    const partyId = "party_" + npc.currentLocationId + "_" + at + "_" + npc.id;
    const members = [npc, ...partners];
    for (const member of members) {
      member.partyId = partyId;
      member.activity = "FORMANDO_GRUPO";
      member.relationships ||= [];
      for (const other of members) {
        if (other.id === member.id) continue;
        const existing = member.relationships.find((relationship) => relationship.characterId === other.id);
        if (existing) {
          existing.affinity = Math.min(100, (existing.affinity || 0) + 3);
          existing.trust = Math.min(100, (existing.trust || 0) + 2);
        } else {
          member.relationships.push({
            characterId: other.id,
            affinity: 3,
            trust: 2,
            rivalry: 0,
            sharedVictories: 0,
            sharedDefeats: 0
          });
        }
      }
      member.memories = remember(member, "GRUPO_FORMADO", "Formou um grupo de aventureiros.", at);
      grouped.add(member.id);
    }
    events.push({
      id: partyId,
      type: "GRUPO_DE_AVENTUREIROS_FORMADO",
      locationId: npc.currentLocationId,
      description: "Um grupo de aventureiros se formou em " + npc.currentLocationId + ".",
      occurredAtMillis: at
    });
  }

  return { adventurers, events };
}
