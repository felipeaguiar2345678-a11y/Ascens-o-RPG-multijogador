// Catálogo global e geração controlada de artes de equipamentos.
import { firestoreAdminGet, firestoreAdminCommit, encodeFirestoreFields } from "./firebase-admin.js";

const MODEL = "gpt-image-2";
const FORMAT_VERSION = 4;
const OUTPUT_SIZE = "2048x1024";
const RESERVE_MICROS = 250000; // R$ 0,25 por geração em qualidade baixa, câmbio interno de R$ 9/US$.
const MAX_BYTES = 7_000_000;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Content-Type": "application/json; charset=utf-8"
  }});
}
function validVisualId(value) {
  return typeof value === "string" && /^equip_[a-f0-9]{64}$/.test(value);
}
function imageUrl(request, visualId) {
  return new URL(`/api/equipment/image/${visualId}`, request.url).toString();
}
function monthBR(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Sao_Paulo", year: "numeric", month: "2-digit"
  }).formatToParts(date);
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  return year && month ? `${year}-${month}` : null;
}
function decodeBase64(value) {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}
function validEquipmentPng(bytes) {
  // A assinatura sozinha não garante que a folha tenha o tamanho ou transparência esperados.
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < 33 || !signature.every((value, index) => bytes[index] === value)) return false;

  const readUint32 = (offset) =>
    (((bytes[offset] << 24) >>> 0) + (bytes[offset + 1] << 16) +
      (bytes[offset + 2] << 8) + bytes[offset + 3]) >>> 0;
  const width = readUint32(16);
  const height = readUint32(20);
  const bitDepth = bytes[24];
  const colorType = bytes[25];
  const compression = bytes[26];
  const filter = bytes[27];
  const interlace = bytes[28];

  // A arte v4 precisa ser exatamente 4x2 células de 512px, com canal alfa.
  if (width !== 2048 || height !== 1024 || compression !== 0 || filter !== 0 || interlace > 1) {
    return false;
  }
  if (![8, 16].includes(bitDepth) || ![4, 6].includes(colorType)) return false;

  // Percorre os chunks para confirmar que o PNG está estruturalmente completo
  // e termina em IEND. Não decodifica nem altera a imagem recebida.
  let offset = 8;
  let encontrouIHDR = false;
  let encontrouIDAT = false;
  let encontrouIEND = false;
  while (offset + 12 <= bytes.length) {
    const length = readUint32(offset);
    const typeOffset = offset + 4;
    const dataOffset = offset + 8;
    const nextOffset = dataOffset + length + 4;
    if (nextOffset > bytes.length) return false;
    const type = String.fromCharCode(
      bytes[typeOffset], bytes[typeOffset + 1],
      bytes[typeOffset + 2], bytes[typeOffset + 3]
    );
    if (offset === 8 && type !== "IHDR") return false;
    if (type === "IHDR") {
      if (encontrouIHDR || length !== 13) return false;
      encontrouIHDR = true;
    } else if (type === "IDAT") {
      encontrouIDAT = true;
    } else if (type === "IEND") {
      if (length !== 0) return false;
      encontrouIEND = true;
      return encontrouIHDR && encontrouIDAT && nextOffset === bytes.length;
    }
    offset = nextOffset;
  }
  return false;
}
async function budgetAction(stub, month, action, values = {}) {
  return stub.fetch("https://budget/equipment-image-budget", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ month, action, ...values })
  });
}
async function settle(stub, month, reservationId, actualMicros) {
  const response = await budgetAction(stub, month, "settle", { reservationId, actualMicros });
  return response.ok;
}
async function markUncertain(stub, month, reservationId) {
  return budgetAction(stub, month, "mark_uncertain", { reservationId }).then((response) => response.ok).catch(() => false);
}
function firestoreArray(fields, key) {
  return (fields?.[key]?.arrayValue?.values || [])
    .map((entry) => entry.stringValue)
    .filter((value) => typeof value === "string");
}
function firestoreString(fields, key) {
  return fields?.[key]?.stringValue || "";
}
async function publishExisting(request, env, visualId, document, object) {
  const url = imageUrl(request, visualId);
  const fields = document.fields || {};
  if (fields.visualFrenteCaminho?.stringValue !== url ||
      fields.visualCostasCaminho?.stringValue !== url ||
      fields.visualLadoEsquerdoCaminho?.stringValue !== url ||
      fields.visualLadoDireitoCaminho?.stringValue !== url ||
      fields.visualCamadaTraseiraCaminho?.stringValue !== url ||
      fields.visualCamadaDianteiraCaminho?.stringValue !== url ||
      fields.versaoVisualEquipamento?.integerValue !== String(FORMAT_VERSION) ||
      fields.status?.stringValue !== "pronto") {
    await firestoreAdminCommit(env, [{
      update: {
        name: `projects/${env.FIREBASE_PROJECT_ID || "ascensao-do-soberano"}/databases/(default)/documents/equipamentos_visuais/${visualId}`,
        fields: encodeFirestoreFields({
          visualFrenteCaminho: url, visualCostasCaminho: url,
          visualLadoEsquerdoCaminho: url, visualLadoDireitoCaminho: url,
          visualCamadaTraseiraCaminho: url, visualCamadaDianteiraCaminho: url,
          versaoVisualEquipamento: FORMAT_VERSION,
          formatoFolhaVisual: "folha_4x2_profundidade",
          status: "pronto", atualizadoEm: Date.now()
        })
      }
    }]);
  }
  return json({
    status: "already_generated", visualId, imageUrl: url,
    objectKey: `equipamentos/${visualId}_v4.png`, sizeBytes: object.size,
    visualFrenteCaminho: url, visualCostasCaminho: url,
    visualLadoEsquerdoCaminho: url, visualLadoDireitoCaminho: url,
    visualCamadaTraseiraCaminho: url, visualCamadaDianteiraCaminho: url,
    formatVersion: FORMAT_VERSION, actualBRL: 0
  });
}

/** Cache-first: resolver uma arte existente nunca reserva orçamento nem chama IA. */
export async function handleEquipmentImageResolution(request, env) {
  const body = await request.json().catch(() => null);
  if (!body || !validVisualId(body.visualId)) return json({ error: "INVALID_EQUIPMENT_VISUAL_ID" }, 400);
  if (!env.IMAGENS_R2) return json({ error: "EQUIPMENT_IMAGE_STORAGE_NOT_CONFIGURED" }, 503);
  let document;
  try { document = await firestoreAdminGet(env, "equipamentos_visuais", body.visualId); }
  catch { return json({ error: "EQUIPMENT_CATALOG_UNAVAILABLE" }, 503); }
  if (!document) return json({ error: "EQUIPMENT_VISUAL_NOT_FOUND" }, 404);
  let object;
  try { object = await env.IMAGENS_R2.head(`equipamentos/${body.visualId}_v4.png`); }
  catch { return json({ error: "EQUIPMENT_IMAGE_STORAGE_UNAVAILABLE" }, 503); }
  if (!object) return json({
    status: "pending", visualId: body.visualId,
    generationEnabled: env.ENABLE_EQUIPMENT_IMAGE_GENERATION === "true",
    message: "A peça permanece disponível no inventário. A arte oficial ainda não foi publicada."
  }, 202);
  try { return await publishExisting(request, env, body.visualId, document, object); }
  catch {
    return json({ error: "EQUIPMENT_IMAGE_METADATA_PENDING", message: "A arte já existe; o catálogo está sincronizando. Nenhuma nova imagem será gerada." }, 503);
  }
}

/**
 * Uma trava global por identidade impede cobranças duplicadas entre jogadores.
 * A entrega do equipamento ocorre no jogo e não depende desta rota visual.
 */
export async function handleEquipmentImageGeneration(request, env, authentication) {
  if (env.ENABLE_EQUIPMENT_IMAGE_GENERATION !== "true") {
    return json({
      status: "disabled", generationEnabled: false,
      message: "A geração de imagens de equipamentos está desligada. O equipamento continua utilizável normalmente."
    }, 423);
  }
  const body = await request.json().catch(() => null);
  if (!body || !validVisualId(body.visualId)) return json({ error: "INVALID_EQUIPMENT_VISUAL_ID" }, 400);
  if (!env.OPENAI_API_KEY || !env.IMAGENS_R2 || !env.AI_BUDGET) {
    return json({ error: "EQUIPMENT_IMAGE_SERVICE_NOT_CONFIGURED" }, 503);
  }

  let document;
  try { document = await firestoreAdminGet(env, "equipamentos_visuais", body.visualId); }
  catch { return json({ error: "EQUIPMENT_CATALOG_UNAVAILABLE" }, 503); }
  if (!document) return json({ error: "EQUIPMENT_VISUAL_NOT_FOUND" }, 404);
  const objectKey = `equipamentos/${body.visualId}.png`;
  let cached;
  try { cached = await env.IMAGENS_R2.head(objectKey); }
  catch { return json({ error: "EQUIPMENT_IMAGE_STORAGE_UNAVAILABLE" }, 503); }
  if (cached) {
    try { return await publishExisting(request, env, body.visualId, document, cached); }
    catch { return json({ error: "EQUIPMENT_IMAGE_METADATA_PENDING" }, 503); }
  }

  const month = monthBR();
  if (!month) return json({ error: "BUDGET_MONTH_UNAVAILABLE" }, 503);
  const stub = env.AI_BUDGET.get(env.AI_BUDGET.idFromName("ascensao-global-monthly-ai"));
  const lockId = `equipment_lock_${crypto.randomUUID()}`;
  let lock;
  try {
    lock = await stub.fetch("https://budget/equipment-image-lock", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        month, action: "equipment_image_lock_acquire",
        visualId: body.visualId, lockId, ttlMs: 150000
      })
    });
  } catch {
    return json({ status: "pending", error: "EQUIPMENT_IMAGE_LOCK_UNAVAILABLE" }, 202);
  }
  if (lock.status === 409) return json({
    status: "pending", visualId: body.visualId,
    message: "Outro jogador já iniciou a arte compartilhada. Sua peça continua disponível; tente consultar novamente em instantes."
  }, 202);
  if (!lock.ok) return json({ status: "pending", error: "EQUIPMENT_IMAGE_LOCK_FAILED" }, 202);

  let reservationId = "";
  let reserved = false;
  let requestSent = false;
  try {
    // Confere novamente o cache depois de adquirir a trava.
    cached = await env.IMAGENS_R2.head(objectKey);
    if (cached) return await publishExisting(request, env, body.visualId, document, cached);

    reservationId = `equipment_image_${crypto.randomUUID()}`;
    let reserve;
    try {
      reserve = await budgetAction(stub, month, "reserve", {
        category: "equipment_images", reservationId,
        reserveMicros: RESERVE_MICROS, minimumReserveMicros: RESERVE_MICROS
      });
    } catch {
      return json({ status: "pending", error: "EQUIPMENT_IMAGE_BUDGET_UNAVAILABLE" }, 202);
    }
    if (reserve.status === 429) return json({
      status: "pending", error: "EQUIPMENT_IMAGE_MONTHLY_LIMIT",
      message: "O limite mensal de R$ 20,00 para imagens de equipamentos foi atingido. A peça continua utilizável."
    }, 202);
    if (!reserve.ok) return json({ status: "pending", error: "EQUIPMENT_IMAGE_RESERVATION_FAILED" }, 202);
    reserved = true;

    const fields = document.fields || {};
    const name = firestoreString(fields, "nomeReferencia");
    const type = firestoreString(fields, "tipo");
    const description = firestoreString(fields, "descricaoVisual");
    const materials = firestoreArray(fields, "craftingMaterials");
    const traits = firestoreArray(fields, "materialTraits");
    const profile = firestoreString(fields, "perfilEncaixeVisual");
    const visualVersion = Number(fields.versaoVisualEquipamento?.integerValue || 0);
    if (!name.trim() || !description.trim() || type !== type.toUpperCase() ||
        profile !== "corpo_base_v3" || visualVersion !== FORMAT_VERSION) {
      await settle(stub, month, reservationId, 0).catch(() => false);
      reserved = false;
      return json({ status: "pending", error: "EQUIPMENT_VISUAL_DATA_INCOMPLETE" }, 202);
    }

    const placementGuide = ({
      HELMET: "ÂNCORA: topo da cabeça; centro horizontal em 50% da célula, centro vertical em 18%; largura aproximada de 42% da célula.",
      ARMOR: "ÂNCORA: tronco; centro horizontal em 50%, centro vertical em 48%; largura aproximada de 62% da célula, cobrindo somente peito, abdômen e costas.",
      BOOTS: "ÂNCORA: pés e canelas inferiores; centro horizontal em 50%, centro vertical em 84%; largura aproximada de 52% da célula.",
      GLOVES: "ÂNCORA: mãos e punhos; duas peças simétricas nas laterais do corpo, por volta de 25% e 75% da largura, centro vertical em 61%; não cobrir antebraços inteiros.",
      SHIELD: "ÂNCORA: antebraço/mão do lado esquerdo do personagem; centro horizontal em 22%, centro vertical em 55%; manter silhueta compacta e afastada do tronco.",
      WEAPON: "ÂNCORA: mão do lado direito do personagem; centro horizontal em 78%, centro vertical em 55%; orientar o cabo para a mão e preservar o comprimento total da arma.",
      NECKLACE: "ÂNCORA: base do pescoço e parte superior do peito; centro horizontal em 50%, centro vertical em 32%; corrente acompanha o contorno do pescoço.",
      RING: "ÂNCORA: dedo da mão que aparece do lado direito do personagem; centro horizontal em 78%, centro vertical em 61%; escala pequena e legível."
    })[type] || "ÂNCORA: centro anatômico correspondente ao tipo de equipamento; mantenha escala coerente com o corpo-base.";

    const prompt = [
      "Crie uma folha de sprites ORIGINAL para um equipamento do RPG Ascensão do Soberano.",
      "Pixel art altamente detalhada, acabamento de RPG premium, silhueta limpa e materiais legíveis.",
      "Uma única imagem horizontal de 2048x1024 pixels, fundo totalmente transparente, organizada em grade exata de 4 colunas por 2 linhas. Cada célula mede 512x512 pixels.",
      "As colunas, da esquerda para a direita, são: vista frontal, vista lateral esquerda, vista traseira, vista lateral direita.",
      "A LINHA SUPERIOR contém exclusivamente a PARTE TRASEIRA do equipamento nas quatro vistas. A LINHA INFERIOR contém exclusivamente a PARTE DIANTEIRA do mesmo equipamento nas quatro vistas.",
      "As oito células devem representar o MESMO objeto e a mesma peça, com materiais, cores, ornamentos, escala, altura e ponto de encaixe consistentes entre as duas profundidades.",
      "Cada célula de 512x512 representa um quadro completo do corpo-base 512x512: mantenha a mesma âncora anatômica e reserve transparência em volta. Não coloque o objeto no centro por conveniência.",
      "A parte traseira deve conter somente elementos que realmente ficam atrás do corpo visto naquela direção; a parte dianteira deve conter somente os elementos que ficam à frente. Não repita a peça completa nas duas linhas e não deixe partes faltando.",
      "Use a mesma projeção, posição anatômica e proporção nas duas linhas. As quatro vistas devem alinhar com a folha do corpo-base 2x2 quando cada célula for recortada e ajustada para 512x512.",
      placementGuide,
      "O equipamento deve ser uma camada isolada que encaixe sobre personagem com corpo-base corpo_base_v3. Não desenhe personagem, manequim, corpo, mãos, suporte, cenário, moldura ou sombra de chão.",
      "Não inclua texto, letras, números, etiquetas, interface, marca d'água ou objetos extras.",
      `Nome: ${name}`, `Tipo: ${type}`, `Descrição visual: ${description}`,
      `Materiais: ${materials.join(", ") || "conforme descrição"}`,
      `Características visuais: ${traits.join(", ") || "conforme descrição"}`
    ].join("\n");

    requestSent = true;
    const imageResponse = await fetch("https://api.openai.com/v1/images/generations", {
      method: "POST",
      headers: { Authorization: `Bearer ${env.OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL, prompt, size: OUTPUT_SIZE, quality: "low",
        background: "transparent", output_format: "png", n: 1
      }),
      signal: AbortSignal.timeout(110000)
    });
    if (!imageResponse.ok) {
      await markUncertain(stub, month, reservationId);
      reserved = false;
      return json({ status: "pending", error: "EQUIPMENT_IMAGE_PROVIDER_FAILED", message: "A resposta do gerador não confirmou o custo. A reserva foi mantida para conferência; o equipamento não foi bloqueado." }, 202);
    }
    const result = await imageResponse.json();
    const usage = result.usage || {};
    const inputDetails = usage.input_tokens_details || {};
    const outputDetails = usage.output_tokens_details || {};
    const textTokens = inputDetails.text_tokens ?? usage.input_tokens;
    const inputImageTokens = inputDetails.image_tokens ?? 0;
    const outputImageTokens = outputDetails.image_tokens ?? usage.output_tokens;
    const outputTextTokens = outputDetails.text_tokens ?? 0;
    if (![textTokens, inputImageTokens, outputImageTokens, outputTextTokens].every(Number.isSafeInteger) ||
        textTokens < 0 || inputImageTokens < 0 || outputImageTokens < 0 || outputTextTokens !== 0) {
      await markUncertain(stub, month, reservationId);
      reserved = false;
      return json({ status: "pending", error: "EQUIPMENT_IMAGE_USAGE_UNAVAILABLE" }, 202);
    }
    // Tarifas GPT Image 2: texto US$2,50/M, imagem de entrada US$4/M,
    // imagem de saída US$15/M. Conversão orçamentária interna: R$9/US$.
    const actualMicros = Math.ceil((textTokens * 2.5 + inputImageTokens * 4 + outputImageTokens * 15) * 9);
    if (actualMicros > RESERVE_MICROS) {
      await markUncertain(stub, month, reservationId);
      reserved = false;
      return json({ status: "pending", error: "EQUIPMENT_IMAGE_COST_EXCEEDS_RESERVE" }, 202);
    }
    const encoded = result?.data?.[0]?.b64_json;
    if (typeof encoded !== "string") {
      await settle(stub, month, reservationId, actualMicros).catch(() => false);
      reserved = false;
      return json({ status: "pending", error: "EQUIPMENT_IMAGE_RESPONSE_INVALID" }, 202);
    }
    const bytes = decodeBase64(encoded);
    if (!validEquipmentPng(bytes) || bytes.byteLength > MAX_BYTES) {
      await settle(stub, month, reservationId, actualMicros).catch(() => false);
      reserved = false;
      return json({ status: "pending", error: "EQUIPMENT_IMAGE_CONTENT_INVALID" }, 202);
    }

    try {
      await env.IMAGENS_R2.put(objectKey, bytes, {
        httpMetadata: { contentType: "image/png", cacheControl: "public, max-age=31536000, immutable" },
        customMetadata: {
          visualId: body.visualId, criadoPorUid: authentication?.uid || "",
          model: MODEL, profile: "corpo_base_v3", layout: "4x2_profundidade", formatVersion: String(FORMAT_VERSION)
        }
      });
    } catch {
      await settle(stub, month, reservationId, actualMicros).catch(() => false);
      reserved = false;
      return json({ status: "pending", error: "EQUIPMENT_IMAGE_STORAGE_FAILED" }, 202);
    }

    const url = imageUrl(request, body.visualId);
    try {
      await firestoreAdminCommit(env, [{
        update: {
          name: `projects/${env.FIREBASE_PROJECT_ID || "ascensao-do-soberano"}/databases/(default)/documents/equipamentos_visuais/${body.visualId}`,
          fields: encodeFirestoreFields({
            visualFrenteCaminho: url, visualCostasCaminho: url,
            visualLadoEsquerdoCaminho: url, visualLadoDireitoCaminho: url,
            visualCamadaTraseiraCaminho: url, visualCamadaDianteiraCaminho: url,
            versaoVisualEquipamento: FORMAT_VERSION,
            formatoFolhaVisual: "folha_4x2_profundidade",
            status: "pronto", imagemFormato: "folha_4x2_profundidade",
            perfilEncaixeVisual: "corpo_base_v3",
            custoRealBRL: actualMicros / 1000000, atualizadoEm: Date.now()
          })
        }
      }]);
    } catch {
      await settle(stub, month, reservationId, actualMicros).catch(() => false);
      reserved = false;
      return json({ status: "pending", error: "EQUIPMENT_IMAGE_METADATA_PENDING" }, 202);
    }
    const settled = await settle(stub, month, reservationId, actualMicros).catch(() => false);
    reserved = false;
    return json({
      status: "generated", visualId, imageUrl: url, objectKey,
      sizeBytes: bytes.byteLength, formatVersion: FORMAT_VERSION,
      visualFrenteCaminho: url, visualCostasCaminho: url,
      visualLadoEsquerdoCaminho: url, visualLadoDireitoCaminho: url,
      visualCamadaTraseiraCaminho: url, visualCamadaDianteiraCaminho: url,
      actualBRL: actualMicros / 1000000, budgetSettlementPending: !settled
    }, 201);
  } catch {
    if (reserved && reservationId) {
      if (requestSent) await markUncertain(stub, month, reservationId);
      else await settle(stub, month, reservationId, 0);
    }
    return json({ status: "pending", error: "EQUIPMENT_IMAGE_GENERATION_FAILED", message: "A arte poderá ser tentada novamente. O equipamento continua disponível." }, 202);
  } finally {
    await budgetAction(stub, month, "equipment_image_lock_release", {
      visualId: body.visualId, lockId
    }).catch(() => null);
  }
}

export async function handleEquipmentImageRequest(request, env) {
  const url = new URL(request.url);
  const match = url.pathname.match(/^\/api\/equipment\/image\/(equip_[a-f0-9]{64})$/);
  if (!match || !env.IMAGENS_R2) return new Response("Not found", { status: 404 });
  // Novas identidades usam folha v4; o fallback preserva URLs de folhas antigas.
  const object = await env.IMAGENS_R2.get(`equipamentos/${match[1]}_v4.png`)
    || await env.IMAGENS_R2.get(`equipamentos/${match[1]}.png`);
  if (!object) return new Response("Not found", { status: 404 });
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("Content-Type", "image/png");
  headers.set("Cache-Control", "public, max-age=31536000, immutable");
  headers.set("Access-Control-Allow-Origin", "*");
  return new Response(object.body, { headers });
}
