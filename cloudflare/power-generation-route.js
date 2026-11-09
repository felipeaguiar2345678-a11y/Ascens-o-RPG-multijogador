// Geração de poderes originais e progressivos para Ascensão do Soberano.
const MODEL = "gpt-6-luna";
const RESERVE_MICROS = 40000; // R$ 0,04 por despertar, dentro do teto other_ai já existente.

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
      "Content-Type": "application/json; charset=utf-8"
    }
  });
}

function monthBR(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Sao_Paulo", year: "numeric", month: "2-digit"
  }).formatToParts(date);
  const year = parts.find(p => p.type === "year")?.value;
  const month = parts.find(p => p.type === "month")?.value;
  return year && month ? `${year}-${month}` : null;
}

function validText(value, max) {
  return typeof value === "string" && value.trim().length > 0 && value.length <= max;
}

export function powerLimits(level, intelligence, spirit, maxMana) {
  const safeLevel = Math.max(1, Math.min(10000, level));
  const safeInt = Math.max(1, Math.min(10000, intelligence));
  const safeSpirit = Math.max(1, Math.min(10000, spirit));
  const safeMana = Math.max(1, Math.min(100000, maxMana));
  return {
    maxDamage: Math.min(100000, Math.max(6, safeLevel * 3 + safeInt + safeSpirit)),
    maxManaCost: Math.max(1, Math.floor(safeMana * (safeLevel <= 5 ? 0.25 : 0.4))),
    maxCooldown: Math.min(12, 2 + Math.floor(safeLevel / 8)),
    maxDuration: Math.min(10, 1 + Math.floor(safeLevel / 10))
  };
}

export function validateGeneratedPower(power, context) {
  if (!power || typeof power !== "object") return false;
  const limits = powerLimits(context.level, context.intelligence, context.spirit, context.maxMana);
  if (!validText(power.name, 70) || !validText(power.description, 600)) return false;
  if (!validText(power.concept, 180) || !validText(power.potential, 600) ||
      !validText(power.manifestation, 600) || !validText(power.awakeningNarrative, 700)) return false;
  if (!validText(power.type, 40) || !validText(power.originExplanation, 300)) return false;
  if (!Number.isInteger(power.manaCost) || power.manaCost < 0 || power.manaCost > limits.maxManaCost) return false;
  if (!Number.isInteger(power.baseDamage) || power.baseDamage < 0 || power.baseDamage > limits.maxDamage) return false;
  if (!Number.isInteger(power.cooldown) || power.cooldown < 0 || power.cooldown > limits.maxCooldown) return false;
  if (!Array.isArray(power.effects) || power.effects.length > 6 ||
      power.effects.some(v => !validText(v, 120))) return false;
  if (!Array.isArray(power.limitations) || power.limitations.length < 1 || power.limitations.length > 6 ||
      power.limitations.some(v => !validText(v, 160))) return false;
  if (!Array.isArray(power.evolutionStages) || power.evolutionStages.length !== 4 ||
      power.evolutionStages.some(stage => !stage || !validText(stage.name, 70) ||
        !validText(stage.description, 300) || !Number.isInteger(stage.requiredLevel) ||
        stage.requiredLevel <= context.level || stage.requiredLevel > 10000)) return false;
  const levels = power.evolutionStages.map(s => s.requiredLevel);
  if (levels.some((v, i) => i > 0 && v <= levels[i - 1])) return false;
  return true;
}

const schema = {
  type: "object",
  additionalProperties: false,
  properties: {
    name: { type: "string" },
    description: { type: "string" },
    concept: { type: "string" },
    potential: { type: "string" },
    manifestation: { type: "string" },
    awakeningNarrative: { type: "string" },
    originExplanation: { type: "string" },
    type: { type: "string" },
    manaCost: { type: "integer" },
    baseDamage: { type: "integer" },
    cooldown: { type: "integer" },
    effects: { type: "array", items: { type: "string" } },
    limitations: { type: "array", items: { type: "string" } },
    evolutionStages: {
      type: "array",
      minItems: 4,
      maxItems: 4,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          name: { type: "string" },
          description: { type: "string" },
          requiredLevel: { type: "integer" }
        },
        required: ["name", "description", "requiredLevel"]
      }
    }
  },
  required: ["name", "description", "concept", "potential", "manifestation",
    "awakeningNarrative", "originExplanation", "type", "manaCost", "baseDamage",
    "cooldown", "effects", "limitations", "evolutionStages"]
};

async function budgetRequest(stub, path, body) {
  return stub.fetch(`https://budget/${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
}

export async function handlePowerGeneration(body, env, authentication, characterDocument) {
  if (!authentication?.uid) return json({ error: "UNAUTHORIZED" }, 401);
  if (!env.OPENAI_API_KEY || !env.AI_BUDGET) {
    return json({ error: "AI_NOT_CONFIGURED", message: "A geração de poderes ainda não está configurada." }, 503);
  }
  if (!body || !validText(body.characterId, 128) || !body.desire || !validText(body.desire.id, 100)) {
    return json({ error: "INVALID_POWER_REQUEST", message: "O personagem ou despertar informado é inválido." }, 400);
  }

  // Nunca confiar no nível, atributos ou afinidades enviados pelo aplicativo.
  // A ficha real é lida do Firestore com o token Firebase do próprio jogador.
  const fields = characterDocument?.fields || {};
  if (firestoreString(fields, "ownerUid") !== authentication.uid) {
    return json({ error: "CHARACTER_NOT_OWNED", message: "Esse personagem não pertence à conta autenticada." }, 403);
  }
  const classFields = firestoreFields(fields, "characterClass");
  const attributeFields = firestoreFields(fields, "attributes");
  const powerFields = firestoreFields(fields, "powerProfile");
  const storedDesires = firestoreEntries(powerFields, "desires")
    .map(item => item.mapValue?.fields || {});
  const storedDesire = storedDesires.find(item => firestoreString(item, "id") === body.desire.id);
  if (!storedDesire || firestoreNumber(storedDesire, "progress") < 20) {
    return json({ error: "AWAKENING_NOT_EARNED", message: "O personagem ainda não conquistou esse despertar." }, 409);
  }
  const storedPowers = firestoreEntries(powerFields, "powers")
    .map(item => item.mapValue?.fields || {});
  if (storedPowers.some(item => firestoreString(item, "originDesireId") === body.desire.id)) {
    return json({ error: "POWER_ALREADY_CREATED", message: "Esse despertar já originou um poder." }, 409);
  }

  const level = firestoreNumber(fields, "level", 1);
  const attributes = {
    strength: firestoreNumber(attributeFields, "strength", 5),
    intelligence: firestoreNumber(attributeFields, "intelligence", 5),
    agility: firestoreNumber(attributeFields, "agility", 5),
    vitality: firestoreNumber(attributeFields, "vitality", 5),
    spirit: firestoreNumber(attributeFields, "spirit", 5)
  };
  const affinityFields = firestoreFields(classFields, "affinities");
  const affinities = Object.fromEntries(Object.entries(affinityFields)
    .map(([key, value]) => [key, value.stringValue || "MEDIUM"])
    .filter(([, value]) => ["LOW", "MEDIUM", "HIGH"].includes(value)));
  const magicAffinity = affinities.MAGIC || "MEDIUM";
  const summonAffinity = affinities.SUMMONING || "MEDIUM";
  const manaBase = magicAffinity === "HIGH" ? 100 : magicAffinity === "LOW" ? 40 : 70;
  const summonBonus = summonAffinity === "HIGH" ? 25 : summonAffinity === "LOW" ? 0 : 10;
  const maxMana = Math.max(1, manaBase + summonBonus + Math.max(0, level - 1) * 10 + Math.max(0, attributes.spirit - 5) * 10);

  const observations = firestoreEntries(powerFields, "observations")
    .map(item => item.mapValue?.fields || {})
    .map(item => ({
      action: firestoreString(item, "action"),
      category: firestoreString(item, "category"),
      intensity: firestoreNumber(item, "intensity", 1)
    }))
    .filter(item => validText(item.action, 180) && validText(item.category, 60) &&
      Number.isInteger(item.intensity) && item.intensity >= 1 && item.intensity <= 100)
    .slice(-20);

  body = {
    ...body,
    characterName: firestoreString(fields, "name"),
    level,
    className: firestoreString(classFields, "name"),
    affinities,
    attributes,
    maxMana,
    desire: {
      id: firestoreString(storedDesire, "id"),
      name: firestoreString(storedDesire, "name"),
      description: firestoreString(storedDesire, "description"),
      type: firestoreString(storedDesire, "desiredType"),
      progress: firestoreNumber(storedDesire, "progress")
    },
    observations
  };

  if (!validText(body.characterName, 60) ||
      !Number.isInteger(body.level) || body.level < 1 || body.level > 10000 ||
      !validText(body.className, 80) ||
      !body.affinities || typeof body.affinities !== "object" || Array.isArray(body.affinities) ||
      Object.keys(body.affinities).length > 12 ||
      Object.values(body.affinities).some(v => !["LOW", "MEDIUM", "HIGH"].includes(v)) ||
      !body.attributes || !["strength", "intelligence", "agility", "vitality", "spirit"].every(k =>
        Number.isInteger(body.attributes[k]) && body.attributes[k] >= 1 && body.attributes[k] <= 10000) ||
      !Number.isInteger(body.maxMana) || body.maxMana < 1 || body.maxMana > 100000 ||
      !body.desire || !validText(body.desire.id, 100) ||
      !validText(body.desire.name, 100) ||
      !Array.isArray(body.observations) || body.observations.length > 20 ||
      body.observations.some(o => !o || !validText(o.action, 180) ||
        !validText(o.category, 60) || !Number.isInteger(o.intensity) ||
        o.intensity < 1 || o.intensity > 100)) {
    return json({ error: "INVALID_POWER_REQUEST", message: "Os dados para despertar o poder são inválidos." }, 400);
  }

  const month = monthBR();
  if (!month) return json({ error: "BUDGET_MONTH_UNAVAILABLE" }, 503);
  const reservationId = `power_${crypto.randomUUID()}`;
  const stub = env.AI_BUDGET.get(env.AI_BUDGET.idFromName("ascensao-global-monthly-ai"));
  let reservation;
  try {
    reservation = await budgetRequest(stub, "reserve", {
      month, action: "reserve", category: "other_ai",
      reservationId, reserveMicros: RESERVE_MICROS, minimumReserveMicros: RESERVE_MICROS
    });
  } catch {
    return json({ error: "BUDGET_GUARD_UNAVAILABLE", message: "A proteção do orçamento está indisponível; a IA não foi chamada." }, 503);
  }
  if (reservation.status === 429) {
    return json({ error: "MONTHLY_AI_BUDGET_REACHED", message: "O limite mensal compartilhado de IA foi atingido." }, 429);
  }
  if (!reservation.ok) return json({ error: "BUDGET_RESERVATION_FAILED" }, 503);

  const limits = powerLimits(body.level, body.attributes.intelligence, body.attributes.spirit, body.maxMana);
  const prompt = [
    "Você é o Arquiteto de Poderes original de Ascensão do Soberano. Escreva em português do Brasil e retorne somente JSON.",
    "INVENTE UMA HABILIDADE ÚNICA. Não escolha de uma lista, não se limite a elementos clássicos ou categorias predefinidas. Qualquer conceito imaginável é permitido: espaço, tempo, gravidade, buracos negros, causalidade, probabilidade, memória, som, luz, sombra, matéria, vida, morte, dimensões, conceitos abstratos, combinações ou algo completamente novo.",
    "A imaginação do conceito e o poder final NÃO têm limite criativo. O limite é somente a manifestação atual do personagem. Nunca apague, troque ou banalize o conceito só porque ele é cósmico ou absurdo: transforme-o em uma versão inicial minúscula, instável, incompleta ou simbólica e explique isso na narrativa.",
    "Exemplo de princípio, não copie: o conceito de buraco negro pode despertar como uma 'Fagulha de Estrela', um ponto gravitacional instável que só puxa poeira e desequilibra um alvo por um instante. A verdadeira singularidade fica como potencial futuro.",
    "A manifestação inicial precisa ser útil mas equilibrada para o nível atual. Poderes utilitários, defensivos, de suporte, mobilidade, controle e investigação podem ter dano zero. Não transforme tudo em ataque.",
    "Custos, dano, duração, recarga e efeitos devem respeitar rigorosamente estes limites numéricos calculados pelo jogo: " + JSON.stringify(limits) + ". Não ultrapasse nenhum deles.",
    "Não conceda invulnerabilidade, morte instantânea, controle mental absoluto, criação ilimitada, viagem temporal irrestrita ou destruição de área na forma inicial. Se o conceito envolver isso, deixe explícito que tais capacidades ainda não podem ser manifestadas.",
    "Crie quatro estágios futuros com nomes e descrições que evoluam de forma coerente, não apenas números maiores. O primeiro estágio deve exigir nível acima do nível atual; os requisitos devem ser crescentes. Evolução pode liberar novas aplicações, alcance, precisão, duração, controle e efeitos.",
    "Limitações devem ser específicas e narrativamente coerentes: alcance curto, concentração, instabilidade, preparação, risco de exaustão, alvos resistentes, efeitos colaterais ou incapacidade de sustentar a manifestação.",
    "Considere classe, atributos, afinidades, histórico e desejo como inspiração, não como prisão. Não copie habilidades de franquias existentes; crie nomes e manifestações originais.",
    "Personagem: " + body.characterName + ", nível " + body.level + ", classe " + body.className + ".",
    "Afinidades reais da classe: " + JSON.stringify(body.affinities) + ". Use-as como inclinações e não como bloqueios.",
    "Atributos: " + JSON.stringify(body.attributes) + "; mana máxima: " + body.maxMana + ".",
    "Despertar relacionado a: " + JSON.stringify(body.desire) + ".",
    "Experiências reais recentes: " + JSON.stringify(body.observations) + ".",
    "O poder precisa parecer que nasceu da história desse personagem."
  ].join("\n\n");

  let response;
  try {
    response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { Authorization: `Bearer ${env.OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        reasoning: { effort: "none" },
        input: prompt,
        max_output_tokens: 1300,
        text: { format: { type: "json_schema", name: "ascensao_original_power", strict: true, schema } }
      }),
      signal: AbortSignal.timeout(45000)
    });
  } catch {
    return json({ error: "POWER_PROVIDER_FAILED", message: "Não foi possível conectar à IA." }, 502);
  }
  if (!response.ok) return json({ error: "POWER_PROVIDER_FAILED", message: "A IA não conseguiu criar o poder." }, 502);

  let result;
  try { result = await response.json(); } catch { return json({ error: "POWER_INVALID_RESPONSE" }, 502); }
  const outputText = (result.output || []).flatMap(item => item.content || [])
    .find(item => item.type === "output_text")?.text;
  let power;
  try { power = JSON.parse(outputText || ""); } catch { return json({ error: "POWER_INVALID_JSON" }, 502); }
  if (!validateGeneratedPower(power, body)) {
    return json({ error: "POWER_VALIDATION_FAILED", message: "A habilidade não respeitou os limites de equilíbrio." }, 422);
  }

  const usage = result.usage || {};
  if (!Number.isSafeInteger(usage.input_tokens) || !Number.isSafeInteger(usage.output_tokens)) {
    return json({ error: "POWER_USAGE_UNAVAILABLE" }, 503);
  }
  const actualMicros = Math.ceil((usage.input_tokens * 0.10 + usage.output_tokens * 0.60) * 9);
  if (actualMicros > RESERVE_MICROS) {
    return json({ error: "POWER_COST_EXCEEDS_RESERVE" }, 503);
  }
  let settled = false;
  try {
    settled = (await budgetRequest(stub, "settle", { month, reservationId, actualMicros })).ok;
  } catch { settled = false; }

  return json({
    id: "poder_" + crypto.randomUUID(),
    ...power,
    origin: "DISCOVERY",
    status: "AWAKENED",
    level: 1,
    experience: 0,
    costBRL: actualMicros / 1000000,
    budgetSettlementPending: !settled
  }, 201);
}
