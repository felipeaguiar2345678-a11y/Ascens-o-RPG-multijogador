// Geração visual de criaturas usando o Worker Cloudflare já existente.
// A integração está documentada em INTEGRAR_IMAGENS_CRIATURAS_NO_WORKER.md.
const RESERVE_MICROS = 5000000; // Reserva máxima de segurança: R$ 5,00
const MODEL = "gpt-image-2";
const MAX_BYTES = 7_000_000;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Content-Type": "application/json; charset=utf-8"
  }});
}
function monthBR(date = new Date()) {
  const p = new Intl.DateTimeFormat("en-US", { timeZone: "America/Sao_Paulo", year: "numeric", month: "2-digit" }).formatToParts(date);
  const y = p.find(x => x.type === "year")?.value;
  const m = p.find(x => x.type === "month")?.value;
  return y && m ? `${y}-${m}` : null;
}
function validId(v) { return typeof v === "string" && /^[A-Za-z0-9_-]{1,100}$/.test(v); }
function decode(v) { return Uint8Array.from(atob(v), c => c.charCodeAt(0)); }
async function settle(stub, month, id, actualMicros) {
  const r = await stub.fetch("https://budget/settle", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ month, action: "settle", reservationId: id, actualMicros }) });
  return r.ok;
}

export async function handleCreatureImageGeneration(request, env, authentication) {
  const body = await request.json().catch(() => null);
  if (!body || !validId(body.creatureId))
    return json({ error: "INVALID_CREATURE_IMAGE_REQUEST", message: "Os identificadores da criatura ou da imagem são inválidos." }, 400);
  if (!env.OPENAI_API_KEY) return json({ error: "AI_NOT_CONFIGURED", message: "A chave de geração de imagens não está configurada. Nenhum valor foi reservado." }, 503);
  if (!env.IMAGENS_R2 || !env.AI_BUDGET) return json({ error: "CREATURE_IMAGE_STORAGE_NOT_CONFIGURED", message: "O orçamento ou armazenamento de imagens não está configurado." }, 503);

  const generationId = body.creatureId;
  const objectKey = `criaturas/${body.creatureId}.png`;
  const auth = request.headers.get("Authorization") || "";
  const firestoreUrl = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID || "ascensao-do-soberano")}/databases/(default)/documents/criaturas/${encodeURIComponent(body.creatureId)}`;
  let docResponse;
  try { docResponse = await fetch(firestoreUrl, { headers: { Authorization: auth } }); }
  catch { return json({ error: "CREATURE_LOOKUP_FAILED", message: "Não foi possível consultar o catálogo de criaturas." }, 503); }
  if (docResponse.status === 404 || docResponse.status === 403)
    return json({ error: "CREATURE_NOT_FOUND", message: "A criatura não existe no catálogo global." }, 404);
  if (!docResponse.ok) return json({ error: "CREATURE_LOOKUP_FAILED", message: "Não foi possível confirmar a criatura no catálogo." }, 503);

  const f = (await docResponse.json()).fields || {};
  if (!f.criadoPorUid?.stringValue || f.criadoPorUid.stringValue !== authentication.uid)
    return json({ error: "FORBIDDEN", message: "Somente quem registrou originalmente esta criatura pode solicitar sua imagem oficial." }, 403);
  const existing = await env.IMAGENS_R2.head(objectKey);
  if (existing) return json({ status: "already_generated", creatureId: body.creatureId, imageId: body.creatureId, objectKey, imageUrl: new URL(`/api/creatures/image/${body.creatureId}`, request.url).toString(), sizeBytes: existing.size, actualBRL: 0 });
  const nome = f.nome?.stringValue || "";
  const descricao = f.descricao?.stringValue || "";
  const rank = f.rank?.stringValue || "E";
  const bioma = f.bioma?.stringValue || "";
  const habitat = f.habitat?.stringValue || "";
  const raridade = f.raridade?.stringValue || "COMUM";
  const ecosystemId = f.ecosystemId?.stringValue || "";
  const boss = f.chefe?.booleanValue === true;
  const rankIndex = ["E", "D", "C", "B", "A", "S", "SS", "SSS"].indexOf(rank);
  const rarityHigh = ["LENDÁRIO", "MÍTICO", "MUNDO"].includes(raridade.trim().toUpperCase());
  // Criaturas comuns usam low; chefes, ranks S+ e raridades especiais usam high.
  const imageQuality = boss || rankIndex >= 5 || rarityHigh ? "high" : "low";
  if (!nome.trim() || !descricao.trim() || !ecosystemId.trim())
    return json({ error: "CREATURE_DATA_INCOMPLETE", message: "A criatura não possui os dados necessários para criar a arte." }, 422);

  const reservationId = `creature_image_${crypto.randomUUID()}`;
  const month = monthBR();
  if (!month) return json({ error: "BUDGET_MONTH_UNAVAILABLE", message: "Não foi possível determinar o mês do orçamento." }, 503);
  const stub = env.AI_BUDGET.get(env.AI_BUDGET.idFromName("ascensao-global-monthly-ai"));
  let reserve;
  try {
    reserve = await stub.fetch("https://budget/reserve", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ month, action: "reserve", category: "other_ai", reservationId, reserveMicros: RESERVE_MICROS, minimumReserveMicros: RESERVE_MICROS }) });
  } catch { return json({ error: "BUDGET_GUARD_UNAVAILABLE", message: "A proteção do orçamento está indisponível. Nenhuma imagem foi solicitada." }, 503); }
  if (reserve.status === 429) return json({ error: "CREATURE_IMAGE_BUDGET_REACHED", message: "O orçamento mensal de R$ 48,00 para criaturas e outros sistemas de IA foi atingido ou está reservado." }, 429);
  if (!reserve.ok) return json({ error: "BUDGET_RESERVATION_FAILED", message: "Não foi possível reservar o orçamento. Nenhuma imagem foi solicitada." }, 503);

  const prompt = [
    "Crie uma ilustração original de criatura para o RPG de fantasia Ascensão do Soberano.",
    "Estilo pixel art muito detalhada com apresentação 2.5D, profundidade, iluminação volumétrica, sombras coerentes, silhueta clara, anatomia coerente e textura rica.",
    "Mostre a criatura inteira, centralizada, isolada, sem interface, sem texto, sem letras, sem marca d'água e com fundo transparente.",
    "A aparência deve refletir fielmente nome, descrição, ecossistema, bioma, habitat, raridade e rank. Não misture temas de outros ecossistemas.",
    boss ? "É um CHEFE regional: presença imponente, design único e escala visual marcante." : "É uma criatura de encontro; ameaça e proporções coerentes com rank e raridade.",
    `Nome: ${nome}`, `Descrição: ${descricao}`, `Rank: ${rank}`, `Raridade: ${raridade}`,
    `Ecossistema: ${ecosystemId}`, `Bioma: ${bioma}`, `Habitat: ${habitat}`
  ].join("\n");

  let bytes;
  let actualMicros = 0;
  try {
    const imageResponse = await fetch("https://api.openai.com/v1/images/generations", { method: "POST", headers: { Authorization: `Bearer ${env.OPENAI_API_KEY}`, "Content-Type": "application/json" }, body: JSON.stringify({ model: MODEL, prompt, size: "1024x1024", quality: imageQuality, background: "transparent", output_format: "png", n: 1 }), signal: AbortSignal.timeout(110000) });
    if (!imageResponse.ok) return json({ error: "IMAGE_PROVIDER_FAILED", message: "O serviço de imagens não concluiu a geração. A reserva permanece pendente para conferência." }, 502);
    const result = await imageResponse.json();
    const usage = result.usage || {};
    const inputDetails = usage.input_tokens_details || {};
    const outputDetails = usage.output_tokens_details || {};
    const textInputTokens = inputDetails.text_tokens ?? usage.input_tokens;
    const imageInputTokens = inputDetails.image_tokens ?? 0;
    const outputTokens = outputDetails.image_tokens ?? usage.output_tokens;
    const outputTextTokens = outputDetails.text_tokens ?? 0;
    if (!Number.isSafeInteger(textInputTokens) || textInputTokens < 0 ||
        !Number.isSafeInteger(imageInputTokens) || imageInputTokens < 0 ||
        !Number.isSafeInteger(outputTokens) || outputTokens < 0 ||
        !Number.isSafeInteger(outputTextTokens) || outputTextTokens !== 0) return json({ error: "IMAGE_USAGE_UNAVAILABLE", message: "Não foi possível confirmar o custo da imagem; a reserva permanece para revisão." }, 503);
    // Tarifas oficiais do GPT Image 2: texto de entrada US$ 2,50/M,
    // imagem de entrada US$ 4/M e imagem de saída US$ 15/M. Câmbio interno: R$ 9/US$.
    actualMicros = Math.ceil((textInputTokens * 2.5 + imageInputTokens * 4 + outputTokens * 15) * 9);
    if (actualMicros > RESERVE_MICROS) return json({ error: "IMAGE_COST_EXCEEDS_RESERVE", message: "O custo estimado ultrapassou a reserva; a imagem não será publicada." }, 503);
    if (typeof result?.data?.[0]?.b64_json !== "string") { await settle(stub, month, reservationId, actualMicros).catch(() => false); return json({ error: "IMAGE_RESPONSE_INVALID", message: "O serviço não retornou uma imagem válida." }, 502); }
    bytes = decode(result.data[0].b64_json);
    const png = bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a;
    if (!png || bytes.byteLength > MAX_BYTES) { await settle(stub, month, reservationId, actualMicros).catch(() => false); return json({ error: "IMAGE_CONTENT_INVALID", message: "A imagem recebida não é um PNG válido ou ultrapassa o tamanho permitido." }, 502); }
  } catch {
    return json({ error: "IMAGE_GENERATION_FAILED", message: "A geração visual falhou ou excedeu o tempo limite. A reserva permanece pendente para conferência." }, 502);
  }

  const key = objectKey;
  try {
    await env.IMAGENS_R2.put(key, bytes, { httpMetadata: { contentType: "image/png", cacheControl: "public, max-age=31536000, immutable" }, customMetadata: { creatureId: body.creatureId, generationId, criadoPorUid: authentication.uid, model: MODEL } });
  } catch { await settle(stub, month, reservationId, actualMicros).catch(() => false); return json({ error: "IMAGE_STORAGE_FAILED", message: "A imagem foi gerada, mas não pôde ser armazenada." }, 503); }

  const settled = await settle(stub, month, reservationId, actualMicros).catch(() => false);
  const imageUrl = new URL(`/api/creatures/image/${body.creatureId}`, request.url).toString();
  return json({ status: "generated", creatureId: body.creatureId, imageId: body.creatureId, imageUrl, objectKey: key, sizeBytes: bytes.byteLength, actualBRL: actualMicros / 1000000, budgetSettlementPending: !settled }, 201);
}

export async function handleCreatureImageRequest(request, env) {
  const url = new URL(request.url);
  const m = url.pathname.match(/^\/api\/creatures\/image\/([A-Za-z0-9_-]{1,100})$/);
  if (!m || !env.IMAGENS_R2) return new Response("Not found", { status: 404 });
  const object = await env.IMAGENS_R2.get(`criaturas/${m[1]}.png`);
  if (!object) return new Response("Not found", { status: 404 });
  const headers = new Headers(); object.writeHttpMetadata(headers);
  headers.set("Content-Type", "image/png"); headers.set("Cache-Control", "public, max-age=31536000, immutable"); headers.set("Access-Control-Allow-Origin", "*");
  return new Response(object.body, { headers });
}
