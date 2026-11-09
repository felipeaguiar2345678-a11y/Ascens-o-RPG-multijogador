// Aventura solo narrativa com quatro escolhas e ação livre.
const MODEL = "gpt-6-luna";
const RESERVE_MICROS = 50000; // R$ 0,05 por turno; limite monetário compartilhado other_ai.

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

async function budgetRequest(stub, path, body) {
  return stub.fetch(`https://budget/${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
}

function validText(value, max) {
  return typeof value === "string" && value.trim().length > 0 && value.length <= max;
}

const adventureSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    chapterTitle: { type: "string" },
    narrative: { type: "string" },
    choices: {
      type: "array",
      minItems: 4,
      maxItems: 4,
      items: { type: "string" }
    },
    encounter: { type: "boolean" },
    creatureHint: { type: "string" },
    bossEncounter: { type: "boolean" }
  },
  required: ["chapterTitle", "narrative", "choices", "encounter", "creatureHint", "bossEncounter"]
};

export async function handleAdventureTurn(body, env, authentication) {
  if (!env.OPENAI_API_KEY || !env.AI_BUDGET) {
    return json({ error: "AI_NOT_CONFIGURED", message: "A aventura por IA ainda não está configurada. Nenhum valor foi reservado." }, 503);
  }

  if (!authentication?.uid) return json({ error: "UNAUTHORIZED" }, 401);
  if (!body || !validText(body.characterName, 60) ||
      !Number.isInteger(body.level) || body.level < 1 || body.level > 10000 ||
      !validText(body.location, 100) || !validText(body.ecosystemId, 100) ||
      !validText(body.biome, 100) ||
      (body.action != null && (typeof body.action !== "string" || body.action.length > 700)) ||
      !Array.isArray(body.history) || body.history.length > 8 ||
      body.history.some(item => !item || !["player", "assistant"].includes(item.role) ||
        !validText(item.text, 1600))) {
    return json({ error: "INVALID_ADVENTURE_REQUEST", message: "Os dados da aventura estão incompletos ou inválidos." }, 400);
  }

  const action = (body.action || "").trim();
  if (!action && body.history.length === 0) {
    return json({ error: "ACTION_REQUIRED", message: "Escolha uma opção ou descreva sua ação." }, 400);
  }

  const month = monthBR();
  if (!month) return json({ error: "BUDGET_MONTH_UNAVAILABLE", message: "Não foi possível determinar o mês do orçamento." }, 503);
  const reservationId = `adventure_${crypto.randomUUID()}`;
  const stub = env.AI_BUDGET.get(env.AI_BUDGET.idFromName("ascensao-global-monthly-ai"));

  let reservation;
  try {
    reservation = await budgetRequest(stub, "reserve", {
      month, action: "reserve", category: "other_ai",
      reservationId, reserveMicros: RESERVE_MICROS,
      minimumReserveMicros: RESERVE_MICROS
    });
  } catch {
    return json({ error: "BUDGET_GUARD_UNAVAILABLE", message: "A proteção do orçamento está indisponível. A IA não foi chamada." }, 503);
  }
  if (reservation.status === 429) {
    return json({ error: "MONTHLY_AI_BUDGET_REACHED", message: "O limite mensal de IA de R$ 48,00 para aventura e outros sistemas foi atingido." }, 429);
  }
  if (!reservation.ok) {
    return json({ error: "BUDGET_RESERVATION_FAILED", message: "Não foi possível reservar o custo do turno. A IA não foi chamada." }, 503);
  }

  const history = body.history.map(item =>
    `${item.role === "player" ? "JOGADOR" : "NARRADOR"}: ${item.text.trim()}`
  ).join("\n");

  const prompt = [
    "Você é o narrador oficial do RPG Ascensão do Soberano.",
    "Continue uma aventura solo persistente. Escreva sempre em português do Brasil.",
    "Respeite a continuidade do histórico, as ações do jogador e o mundo descrito.",
    "Não decida ações, falas ou pensamentos do personagem pelo jogador.",
    "Descreva cenas concretas, atmosfera, consequências e oportunidades; evite repetir fórmulas.",
    "Forneça exatamente quatro escolhas curtas e diferentes, mas permita que o jogador escreva qualquer ação.",
    "Não inicie combate automaticamente. Se uma criatura realmente aparecer, marque encounter=true e descreva uma pista visual curta em creatureHint; bossEncounter só para chefe.",
    "Não invente atributos, recompensas, itens, XP ou resultados de combate. O jogo controla esses sistemas.",
    "A ação do jogador pode incluir um teste D20 já rolado pelo jogo. Se incluir, respeite exatamente o valor natural, modificador, total, atributo e resultado informados; narre consequências coerentes sem rolar novamente nem alterar números. Falhas devem gerar consequência, custo, risco ou pista alternativa, sem bloquear a aventura; sucessos devem conceder avanço proporcional.",
    "Se encounter=false, creatureHint deve ser string vazia e bossEncounter=false.",
    `Personagem: ${body.characterName}, nível ${body.level}.`,
    `Local atual: ${body.location}. Ecossistema: ${body.ecosystemId}. Bioma: ${body.biome}.`,
    `Ação atual do jogador: ${action || "Continue a cena a partir do histórico."}`,
    "Histórico recente:", history || "A aventura está começando.",
    "Entregue uma cena que avance a história e termine em um momento de decisão."
  ].join("\n\n");

  let response;
  try {
    response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: MODEL,
        reasoning: { effort: "none" },
        input: prompt,
        max_output_tokens: 1200,
        text: {
          format: {
            type: "json_schema",
            name: "ascensao_adventure_turn",
            strict: true,
            schema: adventureSchema
          }
        }
      }),
      signal: AbortSignal.timeout(45000)
    });
  } catch {
    return json({ error: "ADVENTURE_PROVIDER_FAILED", message: "Não foi possível conectar ao narrador. A reserva permanece protegida para conferência." }, 502);
  }
  if (!response.ok) {
    return json({ error: "ADVENTURE_PROVIDER_FAILED", message: "O narrador não conseguiu concluir este turno.", upstreamStatus: response.status }, 502);
  }

  let result;
  try { result = await response.json(); }
  catch { return json({ error: "ADVENTURE_INVALID_RESPONSE", message: "A resposta do narrador não pôde ser interpretada." }, 502); }

  const outputText = (result.output || [])
    .flatMap(item => item.content || [])
    .find(item => item.type === "output_text")?.text;
  let story;
  try { story = JSON.parse(outputText || ""); }
  catch { return json({ error: "ADVENTURE_INVALID_JSON", message: "O narrador retornou uma cena inválida." }, 502); }

  if (!validText(story.chapterTitle, 100) || !validText(story.narrative, 3000) ||
      !Array.isArray(story.choices) || story.choices.length !== 4 ||
      story.choices.some(choice => !validText(choice, 180)) ||
      typeof story.encounter !== "boolean" || typeof story.bossEncounter !== "boolean" ||
      typeof story.creatureHint !== "string" || story.creatureHint.length > 240 ||
      (!story.encounter && (story.bossEncounter || story.creatureHint.trim()))) {
    return json({ error: "ADVENTURE_VALIDATION_FAILED", message: "A cena não passou pelas validações do jogo." }, 422);
  }

  const usage = result.usage || {};
  if (!Number.isSafeInteger(usage.input_tokens) || !Number.isSafeInteger(usage.output_tokens)) {
    return json({ error: "ADVENTURE_USAGE_UNAVAILABLE", message: "Não foi possível confirmar o custo deste turno; a reserva permanece para conferência." }, 503);
  }

  // Tarifa conservadora do modelo Luna no projeto: US$ 0,10/M entrada e US$ 0,60/M saída.
  // Conversão interna de segurança: R$ 9/US$. Valores são liquidados em micros de real.
  const actualMicros = Math.ceil((usage.input_tokens * 0.10 + usage.output_tokens * 0.60) * 9);
  if (actualMicros > RESERVE_MICROS) {
    return json({ error: "ADVENTURE_COST_EXCEEDS_RESERVE", message: "O custo calculado ultrapassou a reserva deste turno. A cena não será publicada." }, 503);
  }

  let settled = false;
  try {
    const settlement = await budgetRequest(stub, "settle", { month, reservationId, actualMicros });
    settled = settlement.ok;
  } catch { settled = false; }

  return json({
    ...story,
    model: MODEL,
    costBRL: actualMicros / 1000000,
    budgetSettlementPending: !settled
  });
}
