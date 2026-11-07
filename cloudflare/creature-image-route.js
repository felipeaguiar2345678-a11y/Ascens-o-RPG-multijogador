const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

async function readJsonBodyLimited(request, maxBytes) {
  if (!request.body) return { ok: false, tooLarge: false };
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel();
        return { ok: false, tooLarge: true };
      }
      chunks.push(value);
    }
  } catch {
    return { ok: false, tooLarge: false };
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return { ok: true, value: JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)) };
  } catch {
    return { ok: false, tooLarge: false };
  }
}

function firestoreString(fields, ...names) {
  for (const name of names) {
    const value = fields?.[name];
    if (typeof value?.stringValue === "string") return value.stringValue;
  }
  return "";
}

function firestoreArray(fields, name) {
  const values = fields?.[name]?.arrayValue?.values || [];
  return values
    .map((item) => item.stringValue || "")
    .filter((item) => item.trim())
    .slice(0, 8);
}

async function reserveImageBudget(env, reservationId) {
  const budgetId = env.AI_BUDGET.idFromName("ascensao-global-monthly-ai");
  const stub = env.AI_BUDGET.get(budgetId);
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
  }).formatToParts(new Date());
  const year = parts.find((part) => part.type === "year")?.value;
  const monthNumber = parts.find((part) => part.type === "month")?.value;
  const month = year && monthNumber ? `${year}-${monthNumber}` : null;
  if (!month) throw new Error("Não foi possível determinar o mês brasileiro.");
  const response = await stub.fetch("https://budget/reserve", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      month,
      action: "reserve",
      category: "other_ai",
      reservationId,
      reserveMicros: 1000000,
      minimumReserveMicros: 1000000,
    }),
  });
  return { stub, month, response };
}

async function settleImageBudget(stub, month, reservationId, actualMicros) {
  return stub.fetch("https://budget/settle", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ month, action: "settle", reservationId, actualMicros }),
  });
}

function getFirestoreField(fields, ...names) {
  return firestoreString(fields, ...names);
}

export async function handleCreatureImageGeneration(request, env, authentication) {
  if (!env.OPENAI_API_KEY) {
    return jsonResponse({ error: "AI_NOT_CONFIGURED", message: "A chave da IA não está configurada." }, 503);
  }
  if (!env.IMAGENS_R2) {
    return jsonResponse({ error: "R2_NOT_CONFIGURED", message: "O armazenamento de imagens não está configurado." }, 503);
  }
  if (!env.AI_BUDGET) {
    return jsonResponse({ error: "BUDGET_GUARD_UNAVAILABLE", message: "A proteção de orçamento está indisponível." }, 503);
  }

  const parsed = await readJsonBodyLimited(request, 4000);
  if (!parsed.ok) {
    return jsonResponse({
      error: parsed.tooLarge ? "REQUEST_TOO_LARGE" : "INVALID_JSON",
      message: parsed.tooLarge ? "A solicitação ultrapassa o limite permitido." : "O corpo da solicitação não contém JSON válido.",
    }, parsed.tooLarge ? 413 : 400);
  }

  const creatureId = parsed.value?.creatureId;
  if (typeof creatureId !== "string" || !/^[A-Za-z0-9_-]{1,100}$/.test(creatureId)) {
    return jsonResponse({ error: "INVALID_CREATURE_ID", message: "O identificador da criatura é inválido." }, 400);
  }

  const objectKey = `criaturas/${creatureId}.png`;
  const existing = await env.IMAGENS_R2.head(objectKey);
  if (existing) {
    return jsonResponse({
      status: "already_generated",
      imageId: creatureId,
      objectKey,
      imageUrl: `/api/creatures/image/${creatureId}`,
    });
  }

  const token = (request.headers.get("Authorization") || "").replace(/^Bearer\\s+/i, "");
  if (!token) return jsonResponse({ error: "UNAUTHORIZED", message: "Token de acesso ausente." }, 401);

  const projectId = env.FIREBASE_PROJECT_ID || "ascensao-do-soberano";
  let firestoreResponse;
  try {
    firestoreResponse = await fetch(
      `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/(default)/documents/criaturas/${encodeURIComponent(creatureId)}`,
      {
        headers: { Authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(12000),
      }
    );
  } catch {
    return jsonResponse({ error: "CREATURE_LOOKUP_FAILED", message: "Não foi possível consultar a criatura no catálogo." }, 502);
  }

  if (firestoreResponse.status === 404) {
    return jsonResponse({ error: "CREATURE_NOT_FOUND", message: "Essa criatura não existe no catálogo." }, 404);
  }
  if (!firestoreResponse.ok) {
    return jsonResponse({ error: "CREATURE_LOOKUP_DENIED", message: "Não foi possível validar a criatura ou sua permissão de leitura." }, 403);
  }

  let document;
  try {
    document = await firestoreResponse.json();
  } catch {
    return jsonResponse({ error: "CREATURE_LOOKUP_INVALID", message: "O catálogo retornou dados inválidos." }, 502);
  }

  const fields = document.fields || {};
  const ownerUid = getFirestoreField(fields, "criadoPorUid", "createdByUid", "ownerUid");
  if (!ownerUid || ownerUid !== authentication.uid) {
    return jsonResponse({ error: "CREATURE_OWNER_REQUIRED", message: "Somente quem registrou a criatura pode solicitar sua primeira imagem." }, 403);
  }

  const name = getFirestoreField(fields, "nome");
  const description = getFirestoreField(fields, "descricao");
  const biome = getFirestoreField(fields, "bioma");
  const habitat = getFirestoreField(fields, "habitat");
  const rank = getFirestoreField(fields, "rank");
  const rarity = getFirestoreField(fields, "raridade");
  const skills = firestoreArray(fields, "habilidades");
  if (!name || !description || !biome) {
    return jsonResponse({ error: "CREATURE_DATA_INCOMPLETE", message: "A criatura não possui dados suficientes para criar sua imagem." }, 422);
  }

  const prompt = [
    "Crie uma arte original de criatura para o RPG de fantasia Ascensão do Soberano.",
    "Estilo: pixel art muito detalhada, acabamento de jogo RPG premium, silhueta clara e anatomia consistente.",
    "Mostre somente a criatura inteira, centralizada, em pose natural e marcante; sem cenário, sem moldura, sem texto, sem letras, sem logotipos e sem interface.",
    "Fundo totalmente transparente. Não desenhe sombra de chão nem elementos flutuantes fora da criatura.",
    "A aparência deve traduzir fielmente a espécie, descrição, bioma e habitat. Não transforme a criatura em humano ou mascote genérico.",
    `Nome: ${name}`,
    `Descrição: ${description}`,
    `Bioma: ${biome}`,
    `Habitat: ${habitat || "não especificado"}`,
    `Rank: ${rank || "E"}`,
    `Raridade: ${rarity || "COMUM"}`,
    `Habilidades: ${skills.join(", ") || "não especificadas"}`,
  ].join("\\n");

  const reservationId = "creature_image_" + crypto.randomUUID();
  let budget;
  try {
    budget = await reserveImageBudget(env, reservationId);
  } catch {
    return jsonResponse({ error: "BUDGET_GUARD_UNAVAILABLE", message: "A proteção de orçamento está indisponível. Nenhuma imagem foi gerada." }, 503);
  }
  if (budget.response.status === 429) {
    return jsonResponse({ error: "MONTHLY_AI_BUDGET_REACHED", message: "Não há R$ 1,00 disponível na categoria mensal de IA para reservar esta imagem." }, 429);
  }
  if (!budget.response.ok) {
    return jsonResponse({ error: "BUDGET_RESERVATION_FAILED", message: "Não foi possível reservar o orçamento. Nenhuma imagem foi gerada." }, 503);
  }

  let imageResponse;
  try {
    imageResponse = await fetch("https://api.openai.com/v1/images/generations", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-image-2",
        prompt,
        size: "1024x1024",
        quality: "medium",
        background: "transparent",
        output_format: "png",
        n: 1,
      }),
      signal: AbortSignal.timeout(120000),
    });
  } catch {
    return jsonResponse({
      error: "IMAGE_GENERATION_UNCONFIRMED",
      message: "A conexão foi interrompida. A reserva foi mantida para conferência; nenhuma nova tentativa automática será feita.",
      reservationId,
    }, 502);
  }

  if (!imageResponse.ok) {
    return jsonResponse({
      error: "IMAGE_GENERATION_FAILED",
      message: "O serviço de imagens não concluiu a solicitação. A reserva foi mantida para conferência.",
      reservationId,
      upstreamStatus: imageResponse.status,
    }, 502);
  }

  let result;
  try {
    result = await imageResponse.json();
  } catch {
    return jsonResponse({ error: "IMAGE_RESPONSE_INVALID", message: "A resposta do serviço de imagens é inválida. A reserva foi mantida para conferência.", reservationId }, 502);
  }

  const usage = result.usage || {};
  const inputTokens = usage.input_tokens;
  const outputImageTokens = usage.output_tokens_details?.image_tokens ?? usage.output_tokens;
  if (!Number.isSafeInteger(inputTokens) || inputTokens < 0 ||
      !Number.isSafeInteger(outputImageTokens) || outputImageTokens < 0 ||
      typeof result.data?.[0]?.b64_json !== "string") {
    return jsonResponse({ error: "IMAGE_USAGE_UNAVAILABLE", message: "Não foi possível validar a imagem e seu custo. A reserva foi mantida para conferência.", reservationId }, 503);
  }

  // Estimativa conservadora: US$ 5/M de tokens de texto e US$ 30/M de tokens de imagem.
  // O câmbio interno é o mesmo usado pelo controle mensal: R$ 9,00 por US$ 1,00.
  const inputUsd = inputTokens * 5 / 1000000;
  const outputUsd = outputImageTokens * 30 / 1000000;
  const actualMicros = Math.ceil((inputUsd + outputUsd) * 9 * 1000000);
  let settlement;
  try {
    settlement = await settleImageBudget(budget.stub, budget.month, reservationId, actualMicros);
  } catch {
    return jsonResponse({ error: "BUDGET_SETTLEMENT_UNAVAILABLE", message: "A imagem foi gerada, mas o custo não pôde ser confirmado. A reserva continua bloqueada.", reservationId }, 503);
  }
  if (!settlement.ok) {
    return jsonResponse({ error: "BUDGET_SETTLEMENT_FAILED", message: "A imagem foi gerada, mas o controle mensal não aceitou o custo. A imagem não foi publicada.", reservationId }, 503);
  }

  let imageBytes;
  try {
    const binary = atob(result.data[0].b64_json);
    imageBytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  } catch {
    return jsonResponse({ error: "IMAGE_DECODE_FAILED", message: "Não foi possível interpretar a imagem gerada.", reservationId }, 502);
  }

  if (imageBytes.length === 0 || imageBytes.length > 5000000 ||
      imageBytes[0] !== 0x89 || imageBytes[1] !== 0x50 ||
      imageBytes[2] !== 0x4e || imageBytes[3] !== 0x47) {
    return jsonResponse({ error: "IMAGE_FILE_INVALID", message: "A imagem retornada não é um PNG válido ou ultrapassa 5 MB.", reservationId }, 415);
  }

  try {
    await env.IMAGENS_R2.put(objectKey, imageBytes, {
      httpMetadata: { contentType: "image/png", cacheControl: "public, max-age=31536000, immutable" },
      customMetadata: { creatureId, imageId: creatureId, ownerUid: authentication.uid, source: "openai-gpt-image-2" },
    });
  } catch {
    return jsonResponse({ error: "IMAGE_STORAGE_FAILED", message: "A imagem foi gerada e cobrada, mas não pôde ser salva no armazenamento.", reservationId, actualBRL: actualMicros / 1000000 }, 503);
  }

  return jsonResponse({
    status: "generated",
    imageId: creatureId,
    objectKey,
    imageUrl: `/api/creatures/image/${creatureId}`,
    sizeBytes: imageBytes.length,
    actualBRL: actualMicros / 1000000,
  }, 201);
}

export async function handleCreatureImageRequest(request, env) {
  if (!env.IMAGENS_R2) {
    return jsonResponse({ error: "R2_NOT_CONFIGURED", message: "O armazenamento de imagens não está configurado." }, 503);
  }
  const url = new URL(request.url);
  const match = url.pathname.match(/^\\/api\\/creatures\\/image\\/([A-Za-z0-9_-]{1,100})$/);
  if (!match) return jsonResponse({ error: "INVALID_IMAGE_ID", message: "O identificador da imagem é inválido." }, 400);

  const object = await env.IMAGENS_R2.get(`criaturas/${match[1]}.png`);
  if (!object) return jsonResponse({ error: "IMAGE_NOT_FOUND", message: "A imagem ainda não foi gerada." }, 404);

  const headers = new Headers(corsHeaders);
  object.writeHttpMetadata(headers);
  headers.set("Content-Type", "image/png");
  headers.set("Cache-Control", "public, max-age=31536000, immutable");
  headers.set("ETag", object.httpEtag);
  return new Response(object.body, { headers });
}
