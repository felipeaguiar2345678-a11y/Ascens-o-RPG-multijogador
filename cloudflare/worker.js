const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const FIREBASE_PROJECT_ID = "ascensao-do-soberano";
const FIREBASE_CERT_URL =
  "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

let cachedCertificates = null;
let certificatesExpireAt = 0;

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function decodeBase64Url(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

function decodeBase64(value) {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

async function getFirebaseCertificates() {
  if (cachedCertificates && Date.now() < certificatesExpireAt) {
    return cachedCertificates;
  }

  const response = await fetch(FIREBASE_CERT_URL);
  if (!response.ok) {
    throw new Error("Não foi possível consultar os certificados do Firebase.");
  }

  const certificates = await response.json();
  const cacheControl = response.headers.get("Cache-Control") || "";
  const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
  const maxAgeSeconds = maxAgeMatch ? Number(maxAgeMatch[1]) : 300;

  cachedCertificates = certificates;
  certificatesExpireAt = Date.now() + maxAgeSeconds * 1000;
  return certificates;
}

function extractSubjectPublicKeyInfo(certificateBytes) {
  const der = certificateBytes;
  let offset = 0;

  function readLength() {
    const first = der[offset++];
    if (first < 0x80) return first;
    const count = first & 0x7f;
    let length = 0;
    for (let i = 0; i < count; i++) {
      length = (length * 256) + der[offset++];
    }
    return length;
  }

  function skipElement() {
    offset++;
    offset += readLength();
  }

  if (der[offset++] !== 0x30) throw new Error("Certificado X.509 inválido.");
  readLength();
  if (der[offset++] !== 0x30) throw new Error("Certificado X.509 inválido.");
  readLength();

  if (der[offset] === 0xa0) skipElement();
  skipElement();
  skipElement();
  skipElement();
  skipElement();
  skipElement();

  const spkiStart = offset;
  if (der[offset++] !== 0x30) throw new Error("Chave pública inválida.");
  const spkiLength = readLength();
  const headerLength = offset - spkiStart;
  return der.slice(spkiStart, spkiStart + headerLength + spkiLength);
}

async function verifyFirebaseToken(request) {
  const authorization = request.headers.get("Authorization") || "";
  const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);

  if (!tokenMatch) return { valid: false, reason: "TOKEN_AUSENTE" };

  try {
    const parts = tokenMatch[1].split(".");
    if (parts.length !== 3) return { valid: false, reason: "TOKEN_INVALIDO" };

    const header = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[0])));
    const payload = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[1])));

    if (header.alg !== "RS256" || typeof header.kid !== "string") {
      return { valid: false, reason: "ASSINATURA_INVALIDA" };
    }

    const now = Math.floor(Date.now() / 1000);
    if (
      payload.aud !== FIREBASE_PROJECT_ID ||
      payload.iss !== `https://securetoken.google.com/${FIREBASE_PROJECT_ID}` ||
      typeof payload.sub !== "string" ||
      payload.sub.length === 0 ||
      payload.sub !== payload.user_id ||
      !Number.isFinite(payload.exp) ||
      payload.exp <= now ||
      !Number.isFinite(payload.iat) ||
      payload.iat > now ||
      !Number.isFinite(payload.auth_time) ||
      payload.auth_time > now
    ) {
      return { valid: false, reason: "TOKEN_EXPIRADO_OU_INVALIDO" };
    }

    const certificates = await getFirebaseCertificates();
    const certificate = certificates[header.kid];
    if (!certificate) return { valid: false, reason: "CERTIFICADO_NAO_ENCONTRADO" };

    const pemBody = certificate
      .replace("-----BEGIN CERTIFICATE-----", "")
      .replace("-----END CERTIFICATE-----", "")
      .replace(/\s/g, "");
    const spki = extractSubjectPublicKeyInfo(decodeBase64(pemBody));

    const cryptoKey = await crypto.subtle.importKey(
      "spki",
      spki,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"]
    );

    const validSignature = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      cryptoKey,
      decodeBase64Url(parts[2]),
      new TextEncoder().encode(parts[0] + "." + parts[1])
    );

    return validSignature
      ? { valid: true, uid: payload.sub }
      : { valid: false, reason: "ASSINATURA_INVALIDA" };
  } catch {
    return { valid: false, reason: "FALHA_NA_VALIDACAO" };
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    if (method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (path === "/health" && method === "GET") {
      return jsonResponse({
        status: "online",
        service: "Ascensão do Soberano API",
        aiConfigured: false,
        imagesConfigured: Boolean(env.IMAGENS_R2),
        firebaseProjectConfigured: Boolean(FIREBASE_PROJECT_ID),
        adminConfigured: Boolean(env.ADMIN_UID),
      });
    }

    if (path === "/api/creatures/generate" && method === "POST") {
      const contentLength = Number(request.headers.get("Content-Length") || 0);
      if (contentLength > 16000) {
        return jsonResponse({
          error: "REQUEST_TOO_LARGE",
          message: "A solicitação ultrapassa o limite permitido.",
        }, 413);
      }

      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) {
        return jsonResponse({
          error: "UNAUTHORIZED",
          message: "É necessário entrar em uma conta válida para continuar.",
          reason: authentication.reason,
        }, 401);
      }

      let body;
      try {
        body = await request.json();
      } catch {
        return jsonResponse({
          error: "INVALID_JSON",
          message: "O corpo da solicitação não contém JSON válido.",
        }, 400);
      }

      const { ecosystemId, biome, rank, danger } = body || {};
      const validRanks = ["E", "D", "C", "B", "A", "S", "SS", "SSS"];

      if (
        typeof ecosystemId !== "string" ||
        ecosystemId.trim().length === 0 ||
        ecosystemId.length > 100 ||
        typeof biome !== "string" ||
        biome.trim().length === 0 ||
        biome.length > 100 ||
        !validRanks.includes(rank) ||
        !Number.isInteger(danger) ||
        danger < 1 ||
        danger > 100
      ) {
        return jsonResponse({
          error: "INVALID_CREATURE_REQUEST",
          message: "Os dados da região ou dificuldade são inválidos.",
        }, 400);
      }

      return jsonResponse({
        error: "AI_NOT_CONFIGURED",
        message: "A geração de criaturas ainda não foi ativada.",
        received: { ecosystemId, biome, rank, danger },
      }, 503);
    }

    if (path === "/api/images/upload" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) {
        return jsonResponse({
          error: "UNAUTHORIZED",
          message: "É necessário entrar em uma conta válida.",
          reason: authentication.reason,
        }, 401);
      }

      if (!env.ADMIN_UID || authentication.uid !== env.ADMIN_UID) {
        return jsonResponse({
          error: "FORBIDDEN",
          message: "Somente a conta administradora pode enviar imagens oficiais.",
        }, 403);
      }

      if (!env.IMAGENS_R2) {
        return jsonResponse({
          error: "R2_NOT_CONFIGURED",
          message: "O armazenamento de imagens não está configurado.",
        }, 503);
      }

      const contentLength = Number(request.headers.get("Content-Length") || 0);
      if (contentLength > 7000000) {
        return jsonResponse({
          error: "REQUEST_TOO_LARGE",
          message: "A imagem ultrapassa o limite de envio.",
        }, 413);
      }

      let body;
      try {
        body = await request.json();
      } catch {
        return jsonResponse({
          error: "INVALID_JSON",
          message: "O corpo da solicitação não contém JSON válido.",
        }, 400);
      }

      const { imageId, contentType, imageBase64 } = body || {};
      const extensions = {
        "image/png": "png",
        "image/jpeg": "jpg",
        "image/webp": "webp",
      };

      if (
        typeof imageId !== "string" ||
        !/^[A-Za-z0-9_-]{1,100}$/.test(imageId) ||
        !extensions[contentType] ||
        typeof imageBase64 !== "string"
      ) {
        return jsonResponse({
          error: "INVALID_IMAGE",
          message: "Os dados da imagem são inválidos.",
        }, 400);
      }

      let imageBytes;
      try {
        imageBytes = decodeBase64(imageBase64);
      } catch {
        return jsonResponse({
          error: "INVALID_IMAGE_DATA",
          message: "Não foi possível interpretar os dados da imagem.",
        }, 400);
      }

      if (imageBytes.byteLength === 0 || imageBytes.byteLength > 5000000) {
        return jsonResponse({
          error: "IMAGE_SIZE_INVALID",
          message: "A imagem deve ter até 5 MB.",
        }, 413);
      }

      const objectKey = `criaturas/${imageId}.${extensions[contentType]}`;
      await env.IMAGENS_R2.put(objectKey, imageBytes, {
        httpMetadata: { contentType },
        customMetadata: {
          imageId,
          origem: "Ascensão do Soberano",
        },
      });

      return jsonResponse({
        status: "stored",
        imageId,
        objectKey,
        sizeBytes: imageBytes.byteLength,
      }, 201);
    }

    return jsonResponse({
      error: "NOT_FOUND",
      message: "Rota não encontrada.",
    }, 404);
  },
};
