// Aventura solo narrativa com quatro escolhas e ação livre.
const MODEL = "gpt-6-luna";
const RESERVE_MICROS = 50000; // R$ 0,05 por turno; limite monetário compartilhado other_ai.

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
      "Content-Type": "application/json; charset=utf-8",
      ...extraHeaders
    }
  });
}

export function estimateAdventureTokens(body) {
  const source = [
    body.characterName || "",
    body.location || "",
    body.ecosystemId || "",
    body.biome || "",
    body.action || "",
    ...(Array.isArray(body.history) ? body.history.map(item => item.text || "") : [])
  ].join("\n");
  return Math.min(20000, Math.ceil(source.length / 3) + 1800);
}

export function readRetryAfterSeconds(headers, now = Date.now()) {
  const raw = headers?.get?.("retry-after");
  if (raw) {
    const seconds = Number(raw);
    if (Number.isFinite(seconds) && seconds >= 0) return Math.max(1, Math.min(86400, Math.ceil(seconds)));
    const date = Date.parse(raw);
    if (Number.isFinite(date)) return Math.max(1, Math.min(86400, Math.ceil((date - now) / 1000)));
  }

  const reset = headers?.get?.("x-ratelimit-reset-requests") ||
    headers?.get?.("x-ratelimit-reset-tokens");
  if (reset) {
    const parts = [...reset.matchAll(/(\\d+(?:\\.\\d+)?)(ms|s|m|h)/g)];
    if (parts.length) {
      const milliseconds = parts.reduce((sum, part) => {
        const amount = Number(part[1]);
        const factor = part[2] === "ms" ? 1 : part[2] === "s" ? 1000 :
          part[2] === "m" ? 60000 : 3600000;
        return sum + amount * factor;
      }, 0);
      return Math.max(1, Math.min(86400, Math.ceil(milliseconds / 1000)));
    }
  }
  return null;
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

export function validateAdventureStory(story) {
  if (!story || typeof story !== "object") return false;
  if (!validText(story.chapterTitle, 100) || !validText(story.narrative, 3000)) return false;
  if (!Array.isArray(story.choices) || story.choices.length !== 4) return false;
  if (story.choices.some(choice => !validText(choice, 180))) return false;
  const normalizedChoices = story.choices.map(choice => choice.trim().toLocaleLowerCase("pt-BR"));
  if (new Set(normalizedChoices).size !== 4) return false;
  if (typeof story.encounter !== "boolean" || typeof story.bossEncounter !== "boolean") return false;
  if (typeof story.creatureHint !== "string" || story.creatureHint.length > 240) return false;
  if (story.bossEncounter && !story.encounter) return false;
  if (story.encounter && !validText(story.creatureHint, 240)) return false;
  if (!story.encounter && (story.bossEncounter || story.creatureHint.trim())) return false;
  return true;
}

const adventureSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    chapterTitle: { type: "string" },
    narrative: { type: "string" },
    choices: {
      type: "array",
      description: "Quatro decisões realmente diferentes, coerentes com a cena e sem duplicatas.",
      minItems: 4,
      maxItems: 4,
      items: { type: "string" }
    },
    encounter: { type: "boolean" },
    creatureHint: {
      type: "string",
      description: "Quando encounter=true, descreva a espécie ameaçadora de modo concreto e reconhecível, em até 240 caracteres. Não use expressões vagas."
    },
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

  const estimatedTokens = estimateAdventureTokens(body);
  let rateResponse;
  try {
    rateResponse = await budgetRequest(stub, "throttle", {
      month, uid: authentication.uid, requestId: reservationId, estimatedTokens
    });
  } catch {
    return json({ error: "AI_RATE_GUARD_UNAVAILABLE", message: "O controle de capacidade está indisponível. Nenhuma chamada de IA foi feita." }, 503);
  }
  if (!rateResponse.ok) {
    let rate = {};
    try { rate = await rateResponse.json(); } catch {}
    if (rateResponse.status === 429) {
      const retryAfterSeconds = Math.max(1, Math.min(86400, Number(rate.retryAfterSeconds) || 30));
      const daily = rate.reason === "DAILY_REQUEST_LIMIT";
      return json({
        error: daily ? "AI_DAILY_CAP_REACHED" : "AI_RATE_LIMITED",
        message: daily
          ? "O narrador atingiu o limite diário de segurança. A aventura poderá continuar após a renovação da cota."
          : `O narrador está atendendo outros aventureiros. Tente novamente em ${retryAfterSeconds} segundos.`,
        retryAfterSeconds, scope: rate.reason || "GLOBAL"
      }, 429, { "Retry-After": String(retryAfterSeconds) });
    }
    return json({ error: "AI_RATE_GUARD_FAILED", message: "Não foi possível confirmar a capacidade do narrador. Nenhuma chamada foi feita." }, 503);
  }

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
    "Respeite a continuidade do histórico, as ações do jogador e o mundo descrito. Nunca contradiga fatos já estabelecidos, nomes, ferimentos, alianças, promessas, itens ou consequências anteriores.",
    "Não repita a mesma estrutura de cena em turnos consecutivos. Alterne investigação, diálogo, exploração narrativa, tensão, descoberta e consequência conforme a ação do jogador.",
    "Cada escolha deve representar uma abordagem distinta e ter consequência plausível; não ofereça quatro variações da mesma ação.",
    "Não transforme toda ação em combate. Use encontros apenas quando houver uma criatura fisicamente presente na cena e uma razão narrativa clara.",
    "Quando encounter=true, creatureHint deve identificar a espécie ou aparência da criatura que realmente está presente, não apenas dizer 'um monstro' ou 'uma ameaça'.",

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
  } catch (error) {
    const failureType = error instanceof Error ? error.name : "UnknownError";
    console.error("ADVENTURE_PROVIDER_CONNECTION_FAILED", JSON.stringify({
      failureType,
      message: error instanceof Error ? error.message.slice(0, 180) : "unknown"
    }));
    return json({
      error: "ADVENTURE_PROVIDER_CONNECTION_FAILED",
      message: "Não foi possível conectar ao narrador (falha de rede ou tempo esgotado)."
    }, 502);
  }
  if (!response.ok) {
    let providerFailure = null;
    try {
      const payload = await response.json();
      providerFailure = payload && typeof payload.error === "object" ? payload.error : null;
    } catch {
      // A resposta de erro pode não conter JSON.
    }

    const providerCode = typeof providerFailure?.code === "string"
      ? providerFailure.code.slice(0, 100)
      : null;
    const providerType = typeof providerFailure?.type === "string"
      ? providerFailure.type.slice(0, 100)
      : null;
    const requestId = response.headers.get("x-request-id");

    console.error("ADVENTURE_PROVIDER_REJECTED_REQUEST", JSON.stringify({
      upstreamStatus: response.status,
      providerCode,
      providerType,
      requestId
    }));

    const retryAfterSeconds = response.status === 429
      ? readRetryAfterSeconds(response.headers)
      : null;
    const diagnostic = [
      `HTTP ${response.status}`,
      providerCode ? `código ${providerCode}` : null,
      requestId ? `referência ${requestId}` : null
    ].filter(Boolean).join(" · ");

    return json({
      error: "ADVENTURE_PROVIDER_FAILED",
      message: response.status === 429
        ? `O serviço do narrador atingiu um limite temporário. Tente novamente${retryAfterSeconds ? ` em ${retryAfterSeconds} segundos` : " mais tarde"}.`
        : `O narrador não conseguiu concluir este turno (${diagnostic}).`,
      upstreamStatus: response.status,
      providerCode,
      providerType,
      requestId,
      retryAfterSeconds
    }, response.status === 429 ? 429 : 502,
    retryAfterSeconds ? { "Retry-After": String(retryAfterSeconds) } : {});
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

  if (!validateAdventureStory(story)) {
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
