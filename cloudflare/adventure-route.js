import {
  getFirebaseAdminAccessToken,
  firestoreAdminGet,
  firestoreAdminBeginTransaction,
  firestoreAdminGetDocumentInTransaction,
  firestoreAdminCommitTransaction,
  decodeFirestoreFields,
  encodeFirestoreFields
} from "./firebase-admin.js";

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

// Continuidade sem bloqueio: quando a IA ou a cota do provedor estiver indisponível,
// o jogador ainda pode agir. Esta resposta local não chama a API nem gera custo de IA.
export function buildLocalAdventureFallback(body, reason = "AI_TEMPORARILY_UNAVAILABLE") {
  const action = (typeof body?.action === "string" && body.action.trim())
    ? body.action.trim().replace(/<\/?[^>]+>/g, "").replace(/[<>]/g, "").replace(/\s+/g, " ").slice(0, 500)
    : "observar cuidadosamente o que acontece ao redor";
  const location = (typeof body?.location === "string" && body.location.trim())
    ? body.location.trim().replace(/<\/?[^>]+>/g, "").replace(/[<>]/g, "").slice(0, 100)
    : "a região atual";
  const normalized = action.toLocaleLowerCase("pt-BR");
  const history = Array.isArray(body?.history) ? body.history : [];
  const recent = history.slice(-4).map(item => String(item?.text || "").toLocaleLowerCase("pt-BR")).join(" ");
  const sceneIndex = history.length % 4;
  let reaction;
  let detail;
  let choices;

  if (/investig|examinar|observar|procur|rastro|pista|olhar/.test(normalized)) {
    reaction = [
      "Ao examinar o local, você encontra marcas recentes que não estavam visíveis à primeira vista. A névoa se move contra o vento, revelando que algo passou por ali há pouco.",
      "Sua atenção separa os sons do ambiente: primeiro o vento, depois um estalo seco vindo de trás das pedras. Há sinais de passagem, mas ainda não é possível saber quem os deixou.",
      "Você se aproxima sem tocar nos vestígios. No chão úmido, marcas interrompidas indicam que alguma coisa mudou de direção perto dali.",
      "A observação cuidadosa revela um detalhe fora do lugar: fibras presas à casca de uma árvore e pequenas gotas de água sobre folhas que deveriam estar secas."
    ][sceneIndex];
    detail = "A descoberta oferece uma pista, mas não revela ainda toda a história.";
    choices = ["Seguir as marcas com cuidado", "Examinar o detalhe mais de perto", "Procurar outros sinais nas proximidades", "Recuar para observar o local de outro ângulo"];
  } else if (/seguir|avanç|caminh|trilh|entrar|descer|subir|ir para/.test(normalized)) {
    reaction = [
      "Você avança alguns passos e a paisagem muda. A trilha se estreita entre raízes, enquanto um som distante parece acompanhar seu ritmo.",
      "O caminho leva a uma área menos coberta pela névoa. Adiante, o terreno se divide e há sinais recentes de passagem nos dois lados.",
      "Ao continuar, você alcança um trecho de solo pedregoso. Uma rajada fria atravessa a clareira e traz consigo um ruído breve, como metal tocando pedra.",
      "A trilha faz uma curva e revela um pequeno marco antigo. A inscrição está desgastada, mas alguém removeu o musgo de uma parte dela recentemente."
    ][sceneIndex];
    detail = "Você mudou de posição dentro da cena; o próximo passo pode revelar uma nova área.";
    choices = ["Continuar pela trilha principal", "Investigar o marco ou caminho lateral", "Parar e escutar antes de avançar", "Voltar alguns passos e conferir o entorno"];
  } else if (/atac|golpe|lutar|dispar|lanç|magia|feiti|invoc|poder/.test(normalized)) {
    reaction = [
      "Sua tentativa altera o ambiente: folhas e poeira se espalham, e o eco da ação percorre a clareira. Não há um alvo confirmado à sua frente, então nenhum combate é iniciado automaticamente.",
      "A energia da sua ação se manifesta por um instante e deixa marcas visíveis no cenário. O silêncio que vem depois torna os sons distantes mais fáceis de distinguir.",
      "Você executa o movimento escolhido. O terreno reage sob seus pés e revela como a área pode interferir em uma próxima tentativa.",
      "A ação acontece, mas o resultado não aponta para um inimigo presente. Um ruído responde de longe, sem revelar sua origem."
    ][sceneIndex];
    detail = "A cena registra sua iniciativa, sem conceder dano, itens ou resultados de combate fictícios.";
    choices = ["Testar a habilidade de outra maneira", "Observar o efeito deixado no ambiente", "Avançar na direção do ruído", "Preparar uma postura defensiva"];
  } else if (/falar|pergunt|cham|convers|negoci|responder/.test(normalized)) {
    reaction = [
      "Sua voz atravessa o ambiente e recebe uma resposta distante, curta demais para identificar quem falou. O som veio da direção das pedras.",
      "Você chama por alguém. Por alguns instantes não há resposta; então, um movimento discreto entre os galhos indica que talvez não esteja sozinho.",
      "Sua abordagem quebra o silêncio. O ambiente permanece cauteloso, mas um som ritmado surge ao longe, como se alguém estivesse tentando responder.",
      "Você formula sua pergunta em voz alta. O eco retorna distorcido e destaca uma passagem estreita que antes passava despercebida."
    ][sceneIndex];
    detail = "Ainda não há um interlocutor identificado; você pode tentar estabelecer contato ou investigar a origem do som.";
    choices = ["Chamar novamente e aguardar", "Aproximar-se da origem da resposta", "Procurar alguém nas proximidades", "Mudar a abordagem e observar em silêncio"];
  } else {
    reaction = [
      "Você coloca seu plano em prática. O ambiente responde com pequenos sinais: a névoa se abre por um instante e revela uma passagem entre as raízes.",
      "Sua decisão altera o ritmo da cena. Um som vindo da mata interrompe o silêncio, enquanto o chão úmido guarda marcas difíceis de interpretar.",
      "A tentativa produz uma mudança perceptível no entorno. Algo se desloca além do limite da clareira, mas permanece fora de vista.",
      "Você conclui sua ação e percebe uma nova possibilidade: perto da estaca antiga, a vegetação está amassada como se alguém tivesse passado recentemente."
    ][sceneIndex];
    detail = "A consequência abre uma possibilidade para a próxima decisão, sem inventar recompensas ou encontros.";
    choices = ["Investigar o que mudou no ambiente", "Seguir o sinal mais próximo", "Esperar para perceber outro movimento", "Tentar uma abordagem diferente"];
  }

  // Evita repetir literalmente a mesma reação em sequência quando a memória já contém a frase.
  if (recent.includes(reaction.toLocaleLowerCase("pt-BR").slice(0, 55))) {
    reaction = "A cena continua a partir do que você já fez. Um novo som surge perto do limite da área, enquanto os vestígios anteriores permanecem no local. Você pode escolher como lidar com essa nova informação.";
  }

  return {
    chapterTitle: "Aventura em andamento",
    narrative: `Em ${location}, você decide: ${action}. ${reaction} ${detail} O narrador principal está temporariamente indisponível; esta é uma continuação local de contingência.`,
    choices,
    encounter: false,
    creatureHint: "",
    bossEncounter: false,
    missionObjectiveCompleted: false,
    model: "narrador_local",
    fallback: true,
    fallbackReason: reason,
    costBRL: 0
  };
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
    const parts = [...reset.matchAll(/(\d+(?:\.\d+)?)(ms|s|m|h)/g)];
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
  if (typeof story.encounter !== "boolean" || typeof story.bossEncounter !== "boolean" ||
      typeof story.missionObjectiveCompleted !== "boolean") return false;
  if (typeof story.creatureHint !== "string" || story.creatureHint.length > 240) return false;
  if (story.bossEncounter && !story.encounter) return false;
  if (story.missionObjectiveCompleted && story.encounter) return false;
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
    bossEncounter: { type: "boolean" },
    missionObjectiveCompleted: {
      type: "boolean",
      description: "True somente quando o objetivo do contrato ativo foi integralmente cumprido e narrado como fato concluído nesta etapa. Caso contrário, false."
    }
  },
  required: ["chapterTitle", "narrative", "choices", "encounter", "creatureHint", "bossEncounter", "missionObjectiveCompleted"]
};

async function settleGuildMissionCompletion(env, uid, body) {
  const characterId = body?.characterId;
  const missionId = body?.missionId;
  if (typeof characterId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(characterId) ||
      typeof missionId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(missionId)) {
    throw new Error("MISSION_CONTEXT_INVALID");
  }

  const transaction = await firestoreAdminBeginTransaction(env);
  const characterPath = `characters/${characterId}`;
  const missionPath = `characters/${characterId}/guildContracts/${missionId}`;
  const [characterDocument, missionDocument] = await Promise.all([
    firestoreAdminGetDocumentInTransaction(env, characterPath, transaction),
    firestoreAdminGetDocumentInTransaction(env, missionPath, transaction)
  ]);
  if (!characterDocument || !missionDocument) throw new Error("MISSION_NOT_FOUND");

  const character = decodeFirestoreFields(characterDocument.fields || {});
  const mission = decodeFirestoreFields(missionDocument.fields || {});
  if (character.ownerUid !== uid || mission.ownerUid !== uid ||
      mission.characterId !== characterId || mission.contractId !== missionId ||
      mission.status !== "ACCEPTED") {
    throw new Error("MISSION_NOT_ACTIVE_OR_NOT_OWNED");
  }
  if (typeof body.missionObjective !== "string" ||
      body.missionObjective !== mission.objective ||
      body.missionRank !== mission.rank ||
      body.missionRarity !== mission.rarity) {
    throw new Error("MISSION_CONTEXT_MISMATCH");
  }

  const goldReward = Math.max(0, Math.min(2_000_000_000, Math.trunc(Number(mission.rewardGold) || 0)));
  const xpReward = Math.max(0, Math.min(1_000_000_000, Math.trunc(Number(mission.rewardXp) || 0)));
  let level = Math.max(1, Math.min(10000, Math.trunc(Number(character.level) || 1)));
  let xp = Math.max(0, Math.min(1_000_000_000, Math.trunc(Number(character.xp) || 0) + xpReward));
  let levelsGained = 0;
  while (level < 10000 && xp >= level * 100) {
    xp -= level * 100;
    level += 1;
    levelsGained += 1;
  }
  const attributePoints = Math.max(0, Math.min(100000,
    Math.trunc(Number(character.attributePoints) || 0) + levelsGained * 5));
  const inventory = character.inventory && typeof character.inventory === "object"
    ? character.inventory : {};
  const currentGold = Math.max(0, Math.min(1_000_000_000_000,
    Math.trunc(Number(inventory.gold) || 0)));
  const newGold = Math.min(1_000_000_000_000, currentGold + goldReward);
  const now = new Date().toISOString();

  const writes = [
    {
      update: {
        name: characterDocument.name,
        fields: encodeFirestoreFields({
          level,
          xp,
          attributePoints,
          inventory: { gold: newGold }
        })
      },
      updateMask: { fieldPaths: ["level", "xp", "attributePoints", "inventory.gold"] }
    },
    {
      update: {
        name: missionDocument.name,
        fields: {
          status: { stringValue: "COMPLETED" },
          paidGold: { integerValue: String(goldReward) },
          paidXp: { integerValue: String(xpReward) },
          completedAt: { timestampValue: now },
          updatedAt: { timestampValue: now }
        }
      },
      updateMask: { fieldPaths: ["status", "paidGold", "paidXp", "completedAt", "updatedAt"] }
    }
  ];
  await firestoreAdminCommitTransaction(env, transaction, writes);
  return { gold: goldReward, xp: xpReward, level, remainingXp: xp, levelsGained };
}

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
        !validText(item.text, 1600)) ||
      (body.missionObjective != null && (typeof body.missionObjective !== "string" || body.missionObjective.length > 300)) ||
      (body.missionRank != null && (typeof body.missionRank !== "string" || body.missionRank.length > 8)) ||
      (body.missionRarity != null && (typeof body.missionRarity !== "string" || body.missionRarity.length > 20)) ||
      (body.characterId != null && (typeof body.characterId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(body.characterId))) ||
      (body.missionId != null && (typeof body.missionId !== "string" || (body.missionId !== "" && !/^[A-Za-z0-9_-]{1,128}$/.test(body.missionId))))) {
    return json({ error: "INVALID_ADVENTURE_REQUEST", message: "Os dados da aventura estão incompletos ou inválidos." }, 400);
  }

  const action = (body.action || "").trim();
  if (!action && body.history.length === 0) {
    return json({ error: "ACTION_REQUIRED", message: "Escolha uma opção ou descreva sua ação." }, 400);
  }

  // Não inicia um turno pago se a liquidação segura da missão não estiver configurada.
  if (typeof body.missionId === "string" && body.missionId.length > 0) {
    try {
      await getFirebaseAdminAccessToken(env);
    } catch {
      return json({
        error: "GUILD_REWARD_SERVICE_UNAVAILABLE",
        message: "A confirmação segura das recompensas da Guilda ainda não está configurada. Nenhum turno de IA foi cobrado."
      }, 503);
    }
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
    console.warn("ADVENTURE_LOCAL_FALLBACK", "AI_RATE_GUARD_UNAVAILABLE");
    return json(buildLocalAdventureFallback(body, "AI_RATE_GUARD_UNAVAILABLE"));
  }
  if (!rateResponse.ok) {
    let rate = {};
    try { rate = await rateResponse.json(); } catch {}
    if (rateResponse.status === 429) {
      console.warn("ADVENTURE_LOCAL_FALLBACK", rate.reason || "AI_RATE_LIMITED");
      return json(buildLocalAdventureFallback(body, rate.reason || "AI_RATE_LIMITED"));
    }
    console.warn("ADVENTURE_LOCAL_FALLBACK", "AI_RATE_GUARD_FAILED");
    return json(buildLocalAdventureFallback(body, "AI_RATE_GUARD_FAILED"));
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
    console.warn("ADVENTURE_LOCAL_FALLBACK", "MONTHLY_AI_BUDGET_REACHED");
    return json(buildLocalAdventureFallback(body, "MONTHLY_AI_BUDGET_REACHED"));
  }
  if (!reservation.ok) {
    return json({ error: "BUDGET_RESERVATION_FAILED", message: "Não foi possível reservar o custo do turno. A IA não foi chamada." }, 503);
  }

  const history = body.history.map(item =>
    `${item.role === "player" ? "JOGADOR" : "NARRADOR"}: ${item.text.trim()}`
  ).join("\n");

  const sharedMode = body.sharedMode === true;
  const prompt = [
    "Você é o narrador oficial do RPG Ascensão do Soberano.",
    sharedMode
      ? "Continue uma aventura COOPERATIVA compartilhada por todo o grupo. Escreva sempre em português do Brasil. Narre no plural, como consequência da escolha votada pelo grupo; nunca trate a cena como aventura solo."
      : "Continue uma aventura solo persistente. Escreva sempre em português do Brasil.",
    ...(sharedMode ? [
      "Todos os integrantes recebem exatamente esta mesma cena. Não invente ações individuais nem escolha em nome de qualquer jogador.",
      "A escolha já foi decidida por votação; execute a consequência dela e encerre com quatro novas escolhas coletivas."
    ] : []),
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
    "missionObjectiveCompleted só pode ser true quando existir objetivo de contrato explicitamente informado na ação atual e ele tiver sido integralmente cumprido por acontecimentos concretos já narrados. Não aceite apenas a afirmação do jogador como prova; não marque como concluído se houver coleta parcial, pista incompleta, inimigo ainda vivo, entrega pendente ou etapa restante. Se não houver contrato ativo ou houver qualquer dúvida, use false.",
    "A ação do jogador pode incluir um teste D20 já rolado pelo jogo. Se incluir, respeite exatamente o valor natural, modificador, total, atributo e resultado informados; narre consequências coerentes sem rolar novamente nem alterar números. Falhas devem gerar consequência, custo, risco ou pista alternativa, sem bloquear a aventura; sucessos devem conceder avanço proporcional.",
    "Se encounter=false, creatureHint deve ser string vazia e bossEncounter=false.",
    `Personagem: ${body.characterName}, nível ${body.level}.`,
    `Local atual: ${body.location}. Ecossistema: ${body.ecosystemId}. Bioma: ${body.biome}.`,
    body.missionObjective ? `OBJETIVO DO CONTRATO ATIVO: ${String(body.missionObjective).slice(0, 300)}. Rank: ${String(body.missionRank || "").slice(0, 8)}. Raridade: ${String(body.missionRarity || "").slice(0, 20)}. Marque missionObjectiveCompleted=true apenas quando este objetivo estiver totalmente concluído.` : "Não há contrato de guilda ativo nesta aventura; missionObjectiveCompleted deve ser false.",
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

    if (response.status === 429) {
      // A chamada foi recusada antes da geração; libera a reserva monetária integral.
      try {
        await budgetRequest(stub, "settle", { month, reservationId, actualMicros: 0 });
      } catch (error) {
        console.error("ADVENTURE_ZERO_COST_SETTLEMENT_PENDING", requestId || "no-request-id");
      }
      console.warn("ADVENTURE_LOCAL_FALLBACK", JSON.stringify({
        reason: "OPENAI_RATE_LIMITED", providerCode, requestId, retryAfterSeconds
      }));
      return json(buildLocalAdventureFallback(body, "OPENAI_RATE_LIMITED"));
    }

    return json({
      error: "ADVENTURE_PROVIDER_FAILED",
      message: `O narrador não conseguiu concluir este turno (${diagnostic}).`,
      upstreamStatus: response.status,
      providerCode,
      providerType,
      requestId
    }, 502);
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

  let missionCompletionMessage = "";
  let missionReward = null;
  if (story.missionObjectiveCompleted) {
    try {
      missionReward = await settleGuildMissionCompletion(env, authentication.uid, body);
      missionCompletionMessage = "Missão concluída e recompensa registrada na Guilda.";
    } catch (error) {
      story.missionObjectiveCompleted = false;
      missionCompletionMessage = "A Guilda ainda não confirmou a conclusão nem entregou a recompensa. Continue com a missão ativa e tente novamente.";
      story.narrative = `${story.narrative} ${missionCompletionMessage}`.slice(0, 3000);
      console.warn("GUILD_MISSION_COMPLETION_NOT_SETTLED",
        error instanceof Error ? error.message.slice(0, 120) : "UNKNOWN");
    }
  }

  return json({
    ...story,
    missionCompletionMessage,
    missionReward,
    model: MODEL,
    costBRL: actualMicros / 1000000,
    budgetSettlementPending: !settled
  });
}


// Gera e publica uma única continuação para toda a equipe após a votação.
export async function handleSharedAdventureTurn(body, env, authentication) {
  const fail = (error, status, message) => json({ error, message }, status);
  if (!env.AI_BUDGET || !env.OPENAI_API_KEY) {
    return fail("AI_NOT_CONFIGURED", 503, "O narrador compartilhado ainda não está configurado.");
  }
  const groupId = body?.groupId;
  const revision = body?.revision;
  if (typeof groupId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(groupId) ||
      !Number.isSafeInteger(revision) || revision < 1 || !authentication?.uid) {
    return fail("INVALID_SHARED_ADVENTURE_REQUEST", 400, "O grupo ou a revisão informada é inválida.");
  }

  let groupDocument;
  let storyDocument;
  let group;
  let story;
  try {
    [groupDocument, storyDocument] = await Promise.all([
      firestoreAdminGet(env, "allyGroups", groupId),
      firestoreAdminGet(env, "allyStories", groupId)
    ]);
    if (!groupDocument || !storyDocument) return fail("SHARED_ADVENTURE_NOT_FOUND", 404, "O grupo ou a cena compartilhada não existe.");
    group = decodeFirestoreFields(groupDocument.fields || {});
    story = decodeFirestoreFields(storyDocument.fields || {});
  } catch {
    return fail("SHARED_ADVENTURE_READ_FAILED", 503, "Não foi possível confirmar o estado do grupo.");
  }

  const members = Array.isArray(group.members) ? group.members : [];
  if (members.length < 2 || members.length > 4 || new Set(members).size !== members.length) {
    return fail("GROUP_NOT_READY", 409, "A aventura compartilhada começa quando o grupo tiver de dois a quatro integrantes.");
  }
  if (!members.includes(authentication.uid)) return fail("NOT_GROUP_MEMBER", 403, "Você não pertence a este grupo.");
  if (group.leaderUid !== authentication.uid) return fail("LEADER_REQUIRED", 403, "Somente o líder pode avançar a aventura compartilhada.");
  const choices = Array.isArray(story.choices) ? story.choices : [];
  const selectedChoice = story.resolvedChoice;
  if (story.groupId !== groupId || story.revision !== revision ||
      story.resolvedRevision !== revision || typeof selectedChoice !== "string" ||
      !choices.includes(selectedChoice)) {
    return fail("VOTE_NOT_RESOLVED", 409, "A votação ainda não foi concluída para esta cena.");
  }
  if (typeof story.narrativeText !== "string" || story.narrativeText.length > 5000 ||
      choices.length < 1 || choices.length > 6) {
    return fail("SHARED_STORY_INVALID", 422, "A cena compartilhada contém dados inválidos.");
  }

  const canonical = JSON.stringify({
    groupId, revision, selectedChoice, narrativeText: story.narrativeText,
    choices, members: [...members].sort()
  });
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonical));
  const inputHash = [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, "0")).join("");
  const groupDigest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(groupId));
  const groupKey = [...new Uint8Array(groupDigest)].map(byte => byte.toString(16).padStart(2, "0")).join("");
  const operationKey = `shared_${groupKey}_${revision}`;
  const reservationId = operationKey;
  const month = monthBR();
  if (!month) return fail("BUDGET_MONTH_UNAVAILABLE", 503, "Não foi possível determinar o mês do orçamento.");
  const budget = env.AI_BUDGET.get(env.AI_BUDGET.idFromName("ascensao-global-monthly-ai"));

  let gate;
  try {
    const response = await budgetRequest(budget, "shared_adventure_begin", {
      month, operationKey, inputHash, reservationId
    });
    gate = await response.json();
    if (!response.ok) return fail(gate.error || "SHARED_ADVENTURE_GATE_FAILED", response.status, "Não foi possível reservar a geração desta cena.");
  } catch {
    return fail("SHARED_ADVENTURE_GATE_UNAVAILABLE", 503, "A proteção contra geração duplicada está indisponível.");
  }

  let generated = gate.response;
  if (gate.status === "COMPLETED" && generated) {
    // Resultado já persistido: apenas tenta publicar; nenhuma nova chamada de IA.
  } else if (gate.mayGenerate === true && gate.status === "PROCESSING") {
    const memberNames = group.memberNames && typeof group.memberNames === "object"
      ? Object.values(group.memberNames).filter(name => typeof name === "string").slice(0, 4)
      : [];
    let generation;
    try {
      generation = await handleAdventureTurn({
        sharedMode: true,
        characterName: memberNames.join(", ").slice(0, 60) || "Grupo de aventureiros",
        level: 1,
        location: "Aventura compartilhada",
        ecosystemId: "aventura_compartilhada",
        biome: "narrativa",
        action: selectedChoice,
        history: [{ role: "assistant", text: story.narrativeText.slice(0, 1600) }]
      }, env, authentication);
    } catch {
      try { await budgetRequest(budget, "shared_adventure_uncertain", { month, operationKey, inputHash }); } catch {}
      return fail("SHARED_ADVENTURE_GENERATION_UNCERTAIN", 503, "A geração foi interrompida. Para evitar cobrança duplicada, esta cena ficará bloqueada para revisão.");
    }
    let payload;
    try { payload = await generation.json(); } catch { payload = null; }
    if (!generation.ok || !payload || typeof payload.narrative !== "string" ||
        !Array.isArray(payload.choices) || payload.choices.length !== 4) {
      try {
        await budgetRequest(budget, "shared_adventure_uncertain", { month, operationKey, inputHash });
      } catch {}
      return fail("SHARED_ADVENTURE_GENERATION_UNCERTAIN", 503, "A geração não foi confirmada. Para evitar cobrança duplicada, esta cena ficará bloqueada para revisão.");
    }
    generated = {
      chapterTitle: payload.chapterTitle,
      narrative: payload.narrative,
      choices: payload.choices,
      encounter: Boolean(payload.encounter),
      creatureHint: typeof payload.creatureHint === "string" ? payload.creatureHint : "",
      bossEncounter: Boolean(payload.bossEncounter),
      costBRL: Number(payload.costBRL) || 0,
      fallback: Boolean(payload.fallback)
    };
    try {
      const saved = await budgetRequest(budget, "shared_adventure_complete", {
        month, operationKey, inputHash, response: generated
      });
      const savedPayload = await saved.json();
      if (!saved.ok || !savedPayload.completed) throw new Error("SHARED_RESULT_NOT_SAVED");
      generated = savedPayload.response || generated;
    } catch {
      try { await budgetRequest(budget, "shared_adventure_uncertain", { month, operationKey, inputHash }); } catch {}
      return fail("SHARED_ADVENTURE_RESULT_NOT_SAVED", 503, "A resposta foi gerada, mas não pôde ser salva com segurança.");
    }
  } else if (gate.status === "PROCESSING") {
    return json({ status: "PROCESSING", message: "A aventura compartilhada já está sendo gerada." }, 202);
  } else if (gate.status === "UNCERTAIN") {
    return fail("SHARED_ADVENTURE_REVIEW_REQUIRED", 409, "Esta geração precisa ser revisada antes de tentar novamente.");
  } else {
    return fail("SHARED_ADVENTURE_STATE_INVALID", 409, "O estado desta geração não permite continuar.");
  }

  // Publicação transacional: só avança se a mesma revisão ainda estiver resolvida.
  try {
    const publishTransaction = await firestoreAdminBeginTransaction(env);
    const [latestGroupDoc, latestStoryDoc] = await Promise.all([
      firestoreAdminGetDocumentInTransaction(env, `allyGroups/${groupId}`, publishTransaction),
      firestoreAdminGetDocumentInTransaction(env, `allyStories/${groupId}`, publishTransaction)
    ]);
    if (!latestGroupDoc || !latestStoryDoc) throw new Error("SHARED_GROUP_OR_STORY_MISSING");
    const latestGroup = decodeFirestoreFields(latestGroupDoc.fields || {});
    const latestStory = decodeFirestoreFields(latestStoryDoc.fields || {});
    if (latestGroup.leaderUid !== authentication.uid || !latestGroup.members?.includes(authentication.uid)) {
      throw new Error("SHARED_LEADER_CHANGED");
    }
    if (latestStory.revision === revision + 1 &&
        latestStory.chapterTitle === generated.chapterTitle &&
        latestStory.narrativeText === generated.narrative) {
      return json({ status: "PUBLISHED", revision: revision + 1, replayed: true, costBRL: generated.costBRL || 0 });
    }
    if (latestStory.revision !== revision || latestStory.resolvedRevision !== revision ||
        latestStory.resolvedChoice !== selectedChoice) {
      throw new Error("SHARED_STORY_REVISION_CHANGED");
    }
    const now = new Date().toISOString();
    const nextFields = {
      groupId,
      chapterTitle: String(generated.chapterTitle).slice(0, 120),
      narrativeText: String(generated.narrative).slice(0, 5000),
      imageUrl: "",
      eventType: generated.encounter ? "ENCOUNTER" : "NARRATIVE",
      choices: generated.choices.slice(0, 4).map(choice => String(choice).slice(0, 100)),
      revision: revision + 1,
      updatedByUid: authentication.uid,
      resolvedChoice: "",
      resolutionType: "PENDENTE",
      voteCounts: {},
      resolvedRevision: -1,
      resolvedAt: null,
      updatedAt: now
    };
    const encodedNextFields = encodeFirestoreFields(nextFields);
    encodedNextFields.updatedAt = { timestampValue: now };
    await firestoreAdminCommitTransaction(env, publishTransaction, [{
      update: {
        name: latestStoryDoc.name,
        fields: encodedNextFields
      },
      updateMask: { fieldPaths: Object.keys(nextFields) }
    }]);
    return json({
      status: "PUBLISHED",
      revision: revision + 1,
      replayed: gate.status === "COMPLETED",
      costBRL: generated.costBRL || 0,
      fallback: Boolean(generated.fallback)
    });
  } catch (error) {
    console.error("SHARED_ADVENTURE_PUBLISH_FAILED", error instanceof Error ? error.message : "UNKNOWN");
    return fail("SHARED_ADVENTURE_PUBLISH_PENDING", 503, "A resposta está salva e poderá ser publicada novamente sem gerar outra cena.");
  }
}
