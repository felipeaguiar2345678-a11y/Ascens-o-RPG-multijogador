// Extensão da rota visual para o Worker Cloudflare existente.
// Integra com os helpers do worker.js sem substituir as rotas de criaturas.

const IMAGE_RESERVATION_MICROS = 600000; // reserva conservadora de R$ 0,60 por tentativa
const CHARACTER_IMAGE_MODEL = "gpt-image-2";
const CHARACTER_IMAGE_MAX_BYTES = 7_000_000;

function getCharacterBrazilianMonth(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Sao_Paulo", year: "numeric", month: "2-digit"
  }).formatToParts(date);
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  return year && month ? `${year}-${month}` : null;
}

async function readCharacterJsonLimited(request, maxBytes = 12000) {
  if (!request.body) return null;
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    return null;
  }
}

function characterJson(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
      "Content-Type": "application/json; charset=utf-8"
    }
  });
}

function decodeImageBase64(value) {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

function validId(value) {
  return typeof value === "string" && /^[A-Za-z0-9_-]{1,100}$/.test(value);
}

async function settleCharacterReservation(budgetStub, reservationId, actualMicros) {
  const response = await budgetStub.fetch("https://budget/settle", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      month: getCharacterBrazilianMonth(),
      action: "settle",
      reservationId,
      actualMicros
    })
  });
  return response.ok;
}

async function markCharacterReservationUncertain(budgetStub, reservationId) {
  const response = await budgetStub.fetch("https://budget/uncertain", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      month: getCharacterBrazilianMonth(),
      action: "mark_uncertain",
      reservationId
    })
  });
  return response.ok;
}

export async function handleCharacterVisualGeneration(request, env, authentication) {
  const parsed = await request.json().catch(() => null);
  if (!parsed || typeof parsed !== "object") {
    return characterJson({ error: "INVALID_JSON", message: "A solicitação não contém JSON válido." }, 400);
  }

  const { characterId, generationId, prompt } = parsed;
  if (!validId(characterId) || !validId(generationId) ||
      typeof prompt !== "string" || prompt.trim().length < 20 || prompt.length > 6000) {
    return characterJson({ error: "INVALID_CHARACTER_VISUAL_REQUEST", message: "Os dados da geração visual são inválidos." }, 400);
  }

  if (!env.OPENAI_API_KEY) {
    return characterJson({ error: "AI_NOT_CONFIGURED", message: "A chave de geração visual não está configurada. Nenhum valor foi reservado." }, 503);
  }
  if (!env.IMAGENS_R2 || !env.AI_BUDGET) {
    return characterJson({ error: "VISUAL_STORAGE_NOT_CONFIGURED", message: "O orçamento ou armazenamento de imagens não está configurado." }, 503);
  }

  // A leitura usa o próprio token Firebase do jogador: as regras Firestore
  // impedem que ele consulte o documento de outro proprietário.
  const authorization = request.headers.get("Authorization") || "";
  const firestoreUrl = `https://firestore.googleapis.com/v1/projects/ascensao-do-soberano/databases/(default)/documents/characters/${encodeURIComponent(characterId)}`;
  const characterResponse = await fetch(firestoreUrl, {
    headers: { Authorization: authorization }
  });
  if (characterResponse.status === 404 || characterResponse.status === 403) {
    return characterJson({ error: "CHARACTER_NOT_FOUND", message: "Personagem não encontrado ou sem permissão." }, 404);
  }
  if (!characterResponse.ok) {
    return characterJson({ error: "CHARACTER_VALIDATION_FAILED", message: "Não foi possível confirmar a propriedade do personagem." }, 503);
  }

  const characterDocument = await characterResponse.json();
  const fields = characterDocument.fields || {};
  const ownerUid = fields.ownerUid?.stringValue;
  if (ownerUid !== authentication.uid) {
    return characterJson({ error: "FORBIDDEN", message: "Este personagem não pertence à conta autenticada." }, 403);
  }

  const storedImageUrl = fields.appearance?.mapValue?.fields?.generatedImageUrl?.stringValue || "";
  if (storedImageUrl) {
    const storedPath = fields.appearance?.mapValue?.fields?.generatedImagePath?.stringValue || "";
    return characterJson({ status: "already_generated", imageUrl: storedImageUrl, objectKey: storedPath });
  }

  const reservationId = `character_${crypto.randomUUID()}`;
  const budgetId = env.AI_BUDGET.idFromName("ascensao-global-monthly-ai");
  const budgetStub = env.AI_BUDGET.get(budgetId);
  let reservationResponse;
  try {
    reservationResponse = await budgetStub.fetch("https://budget/reserve", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        month: getCharacterBrazilianMonth(),
        action: "reserve",
        category: "characters",
        reservationId,
        reserveMicros: IMAGE_RESERVATION_MICROS,
        minimumReserveMicros: IMAGE_RESERVATION_MICROS
      })
    });
  } catch {
    return characterJson({ error: "BUDGET_GUARD_UNAVAILABLE", message: "A proteção do orçamento está indisponível. Nenhuma imagem foi solicitada." }, 503);
  }

  if (reservationResponse.status === 429) {
    return characterJson({ error: "CHARACTER_IMAGE_BUDGET_REACHED", message: "O limite mensal de R$ 2,00 para imagens de personagens foi atingido ou está reservado." }, 429);
  }
  if (!reservationResponse.ok) {
    return characterJson({ error: "BUDGET_RESERVATION_FAILED", message: "Não foi possível reservar o orçamento. Nenhuma imagem foi solicitada." }, 503);
  }

  let imageBytes;
  try {
    const imageResponse = await fetch("https://api.openai.com/v1/images/generations", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: CHARACTER_IMAGE_MODEL,
        prompt: prompt.trim(),
        size: "1024x1024",
        quality: "medium",
        background: "transparent",
        output_format: "png",
        n: 1
      }),
      signal: AbortSignal.timeout(110000)
    });

    if (!imageResponse.ok) {
      // HTTP de erro não entregou imagem; libera a reserva e expõe diagnóstico sanitizado.
      await settleCharacterReservation(budgetStub, reservationId, 0).catch(() => false);
      let providerError = null;
      try {
        const payload = await imageResponse.json();
        providerError = payload?.error || null;
      } catch {
        providerError = null;
      }
      const providerCode = typeof providerError?.code === "string"
        ? providerError.code.slice(0, 100)
        : null;
      const providerType = typeof providerError?.type === "string"
        ? providerError.type.slice(0, 100)
        : null;
      const providerMessage = typeof providerError?.message === "string"
        ? providerError.message.replace(/[\\r\\n]+/g, " ").slice(0, 350)
        : null;
      return characterJson({
        error: "IMAGE_PROVIDER_FAILED",
        message: "O provedor recusou a solicitação. Nenhuma imagem foi recebida e a reserva foi liberada.",
        providerStatus: imageResponse.status,
        providerCode,
        providerType,
        providerMessage
      }, 502);
    }

    const result = await imageResponse.json();
    const base64 = result?.data?.[0]?.b64_json;
    if (typeof base64 !== "string" || !base64) {
      await settleCharacterReservation(budgetStub, reservationId, 0).catch(() => false);
      return characterJson({ error: "IMAGE_RESPONSE_INVALID", message: "O serviço não retornou uma imagem utilizável. A reserva foi liberada." }, 502);
    }
    imageBytes = decodeImageBase64(base64);
    if (imageBytes.byteLength < 8 || imageBytes.byteLength > CHARACTER_IMAGE_MAX_BYTES ||
        imageBytes[0] !== 0x89 || imageBytes[1] !== 0x50 || imageBytes[2] !== 0x4e || imageBytes[3] !== 0x47) {
      await settleCharacterReservation(budgetStub, reservationId, 0).catch(() => false);
      return characterJson({ error: "IMAGE_CONTENT_INVALID", message: "A imagem recebida não é válida ou ultrapassa o tamanho permitido. A reserva foi liberada." }, 502);
    }
  } catch {
    // Sem imagem entregue ao jogador: devolver integralmente a reserva.
    // O orçamento interno contabiliza apenas imagens armazenadas e disponibilizadas.
    const released = await settleCharacterReservation(budgetStub, reservationId, 0).catch(() => false);
    return characterJson({
      error: "IMAGE_GENERATION_FAILED",
      message: "A geração não entregou uma imagem utilizável. A reserva foi liberada; nenhum valor foi contabilizado no orçamento do aplicativo.",
      budgetReservationReleased: released
    }, 502);
  }

  const objectKey = `characters/${authentication.uid}/${characterId}/${generationId}.png`;
  try {
    await env.IMAGENS_R2.put(objectKey, imageBytes, {
      httpMetadata: {
        contentType: "image/png",
        cacheControl: "public, max-age=31536000, immutable"
      },
      customMetadata: {
        ownerUid: authentication.uid,
        characterId,
        generationId,
        model: CHARACTER_IMAGE_MODEL
      }
    });
  } catch {
    await settleCharacterReservation(budgetStub, reservationId, 0).catch(() => false);
    return characterJson({ error: "IMAGE_STORAGE_FAILED", message: "A imagem não ficou disponível para o jogador. A reserva foi liberada." }, 503);
  }

  const settlementOk = await settleCharacterReservation(
    budgetStub, reservationId, IMAGE_RESERVATION_MICROS
  ).catch(() => false);

  const imageUrl = new URL(
    `/images/characters/${authentication.uid}/${characterId}/${generationId}.png`,
    request.url
  ).toString();

  return characterJson({
    status: "stored",
    imageUrl,
    objectKey,
    sizeBytes: imageBytes.byteLength,
    budgetSettlementPending: !settlementOk
  }, 201);
}

export async function handleCharacterImageRequest(url, env) {
  const match = url.pathname.match(/^\/images\/characters\/([A-Za-z0-9_-]{1,100})\/([A-Za-z0-9_-]{1,100})\/([A-Za-z0-9_-]{1,100})\.png$/);
  if (!match || !env.IMAGENS_R2) return new Response("Not found", { status: 404 });
  const [, uid, characterId, generationId] = match;
  const object = await env.IMAGENS_R2.get(`characters/${uid}/${characterId}/${generationId}.png`);
  if (!object) return new Response("Not found", { status: 404 });
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("Content-Type", "image/png");
  headers.set("Cache-Control", "public, max-age=31536000, immutable");
  headers.set("Access-Control-Allow-Origin", "*");
  return new Response(object.body, { headers });
}
