import {
  handleCharacterVisualGeneration,
  handleCharacterImageRequest
} from "./character-visual-route.js";
import {
  handleCreatureImageGeneration,
  handleCreatureImageRequest
} from "./creature-image-route.js";

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


async function readJsonBodyLimited(request, maxBytes) {
  if (!request.body) return { ok: false, tooLarge: false };

  const reader = request.body.getReader();
  const chunks = [];
  let totalBytes = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel();
        return { ok: false, tooLarge: true };
      }
      chunks.push(value);
    }
  } catch {
    return { ok: false, tooLarge: false };
  }

  const combined = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    combined.set(chunk, offset);
    offset += chunk.byteLength;
  }

  try {
    return {
      ok: true,
      value: JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(combined))
    };
  } catch {
    return { ok: false, tooLarge: false };
  }
}


function matchesImageSignature(bytes, contentType) {
  if (contentType === "image/png") {
    return bytes.length >= 8 &&
      bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 &&
      bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a;
  }
  if (contentType === "image/jpeg") {
    return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  if (contentType === "image/webp") {
    return bytes.length >= 12 &&
      bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
      bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50;
  }
  return false;
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
  if (tokenMatch[1].length > 8192) return { valid: false, reason: "TOKEN_INVALIDO" };

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
      payload.iat > now + 60 ||
      payload.iat > payload.exp ||
      !Number.isFinite(payload.auth_time) ||
      payload.auth_time > now + 60 ||
      payload.auth_time > payload.iat
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
      ? { valid: true, uid: payload.sub, displayName: typeof payload.name === "string" ? payload.name : "" }
      : { valid: false, reason: "ASSINATURA_INVALIDA" };
  } catch {
    return { valid: false, reason: "FALHA_NA_VALIDACAO" };
  }
}


const CREATURE_RANKS = ["E", "D", "C", "B", "A", "S", "SS", "SSS"];
const CREATURE_RARITIES = ["COMUM", "INCOMUM", "RARO", "ÉPICO", "LENDÁRIO", "MÍTICO", "MUNDO"];
const EQUIPMENT_RARITIES = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC"];

const creatureSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    nome: { type: "string" },
    descricao: { type: "string" },
    rank: { type: "string", enum: CREATURE_RANKS },
    nivel: { type: "integer" },
    vidaMaxima: { type: "integer" },
    ataque: { type: "integer" },
    defesa: { type: "integer" },
    manaMaxima: { type: "integer" },
    agilidade: { type: "integer" },
    poderMagico: { type: "integer" },
    experienciaBase: { type: "integer" },
    perigo: { type: "integer" },
    bioma: { type: "string" },
    habitat: { type: "string" },
    raridade: { type: "string", enum: CREATURE_RARITIES },
    atividadeNoturna: { type: "boolean" },
    habilidades: { type: "array", items: { type: "string" } },
    ataques: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          id: { type: "string" },
          nome: { type: "string" },
          descricao: { type: "string" },
          tipoDano: { type: "string" },
          elemento: { type: "string" },
          danoBase: { type: "integer" },
          multiplicador: { type: "number" },
          custoMana: { type: "integer" },
          custoManaMinimo: { type: "integer" },
          custoManaMaximo: { type: "integer" },
          efeitos: { type: "array", items: { type: "string" } },
          duracaoTurnos: { type: "integer" },
          chanceAplicacao: { type: "integer" },
          chanceUso: { type: "integer" },
          turnosCarregamento: { type: "integer" },
          turnosRecarga: { type: "integer" },
          podeSerInterrompida: { type: "boolean" },
          categoria: { type: "string", enum: ["NORMAL", "PODEROSO", "DEVASTADOR"] },
          danoQuebra: { type: "integer" }
        },
        required: ["id", "nome", "descricao", "tipoDano", "elemento", "danoBase", "multiplicador", "custoMana", "custoManaMinimo", "custoManaMaximo", "efeitos", "duracaoTurnos", "chanceAplicacao", "chanceUso", "turnosCarregamento", "turnosRecarga", "podeSerInterrompida", "categoria", "danoQuebra"]
      }
    },
    drops: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          itemId: { type: "string" },
          nome: { type: "string" },
          descricao: { type: "string" },
          tipo: { type: "string", enum: ["MATERIAL", "EQUIPAMENTO"] },
          raridade: { type: "string", enum: CREATURE_RARITIES },
          chancePercentual: { type: "number" },
          garantido: { type: "boolean" },
          quantidadeMinima: { type: "integer" },
          quantidadeMaxima: { type: "integer" },
          tipoEquipamento: { type: "string", enum: ["", "WEAPON", "ARMOR", "HELMET", "BOOTS", "GLOVES", "RING", "NECKLACE", "SHIELD"] },
          raridadeEquipamento: { type: "string", enum: ["", ...EQUIPMENT_RARITIES] },
          rankEquipamento: { type: "string", enum: CREATURE_RANKS },
          nivelRequerido: { type: "integer" },
          atributos: {
            type: "object",
            additionalProperties: false,
            properties: {
              strength: { type: "integer" },
              intelligence: { type: "integer" },
              agility: { type: "integer" },
              vitality: { type: "integer" },
              spirit: { type: "integer" },
              physicalDamage: { type: "integer" },
              magicalDamage: { type: "integer" },
              defense: { type: "integer" }
            },
            required: ["strength", "intelligence", "agility", "vitality", "spirit", "physicalDamage", "magicalDamage", "defense"]
          },
          efeitoEspecial: { type: "string" }
        },
        required: ["itemId", "nome", "descricao", "tipo", "raridade", "chancePercentual", "garantido", "quantidadeMinima", "quantidadeMaxima", "tipoEquipamento", "raridadeEquipamento", "rankEquipamento", "nivelRequerido", "atributos", "efeitoEspecial"]
      }
    }
  },
  required: ["nome", "descricao", "rank", "nivel", "vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico", "experienciaBase", "perigo", "bioma", "habitat", "raridade", "atividadeNoturna", "habilidades", "ataques", "drops"]
};

function validGeneratedCreature(creature, requestData) {
  const rankIndex = CREATURE_RANKS.indexOf(creature.rank);
  const requestedRankIndex = CREATURE_RANKS.indexOf(requestData.rank);
  const integerFields = ["nivel", "vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico", "experienciaBase", "perigo"];

  if (!creature.nome?.trim() || creature.nome.length > 80 || !creature.descricao?.trim() || creature.descricao.length > 1200) return false;
  if (rankIndex < 0 || rankIndex > requestedRankIndex) return false;
  if (integerFields.some((field) => !Number.isInteger(creature[field]) || creature[field] < 0 || creature[field] > 1000000)) return false;
  if (creature.nivel < 1 || creature.vidaMaxima < 1 || creature.ataque < 1 || creature.experienciaBase < 1) return false;
  if (creature.perigo > 100 || !CREATURE_RARITIES.includes(creature.raridade) || typeof creature.atividadeNoturna !== "boolean") return false;
  if (!creature.bioma?.trim() || creature.bioma.length > 100 || !creature.habitat?.trim() || creature.habitat.length > 300) return false;
  if (!Array.isArray(creature.habilidades) || creature.habilidades.length < 1 || creature.habilidades.length > 8 ||
      creature.habilidades.some((skill) => typeof skill !== "string" || !skill.trim() || skill.length > 160)) return false;
  if (!Array.isArray(creature.ataques) || creature.ataques.length < 1 || creature.ataques.length > 6) return false;
  if (!Array.isArray(creature.drops) || creature.drops.length > 8) return false;

  for (const attack of creature.ataques) {
    if (!attack.id?.trim() || attack.id.length > 80 || !attack.nome?.trim() || attack.nome.length > 80 ||
        !attack.descricao?.trim() || attack.descricao.length > 500 ||
        !attack.tipoDano?.trim() || attack.tipoDano.length > 40 ||
        !attack.elemento?.trim() || attack.elemento.length > 40) return false;

    const attackIntegers = [
      attack.danoBase, attack.custoMana, attack.custoManaMinimo, attack.custoManaMaximo,
      attack.duracaoTurnos, attack.chanceAplicacao, attack.chanceUso,
      attack.turnosCarregamento, attack.turnosRecarga, attack.danoQuebra
    ];
    if (!attackIntegers.every(Number.isInteger)) return false;
    if (!Number.isFinite(attack.multiplicador) || attack.multiplicador < 0 || attack.multiplicador > 20) return false;
    if (attack.danoBase < 0 || attack.danoBase > 100000 || attack.custoMana < 0 ||
        attack.custoManaMinimo < 0 || attack.custoManaMaximo < attack.custoManaMinimo ||
        attack.custoMana > attack.custoManaMaximo || attack.custoManaMaximo > 100000) return false;
    if (attack.duracaoTurnos < 0 || attack.duracaoTurnos > 20 ||
        attack.chanceAplicacao < 0 || attack.chanceAplicacao > 100 ||
        attack.chanceUso < 0 || attack.chanceUso > 100 ||
        attack.turnosCarregamento < 0 || attack.turnosCarregamento > 2 ||
        attack.turnosRecarga < 0 || attack.turnosRecarga > 20) return false;
    if (!["NORMAL", "PODEROSO", "DEVASTADOR"].includes(attack.categoria) || attack.danoQuebra < 0 || attack.danoQuebra > 100000) return false;
    if (attack.categoria === "PODEROSO" && (attack.turnosCarregamento !== 0 || attack.turnosRecarga < 1 || attack.turnosRecarga > 3)) return false;
    if (attack.categoria === "DEVASTADOR" && attack.turnosCarregamento < 1) return false;
    if (typeof attack.podeSerInterrompida !== "boolean" ||
        !Array.isArray(attack.efeitos) || attack.efeitos.length > 8 ||
        attack.efeitos.some((effect) => typeof effect !== "string" || !effect.trim() || effect.length > 120)) return false;
  }

  for (const drop of creature.drops) {
    if (!drop.itemId?.trim() || drop.itemId.length > 100 || !drop.nome?.trim() || drop.nome.length > 80 ||
        !drop.descricao?.trim() || drop.descricao.length > 500 || !CREATURE_RARITIES.includes(drop.raridade)) return false;
    if (!["MATERIAL", "EQUIPAMENTO"].includes(drop.tipo) || typeof drop.garantido !== "boolean") return false;
    if (!Number.isFinite(drop.chancePercentual) || drop.chancePercentual < 0 || drop.chancePercentual > 100) return false;
    if (drop.garantido && drop.chancePercentual !== 100) return false;
    if (!Number.isInteger(drop.quantidadeMinima) || !Number.isInteger(drop.quantidadeMaxima) ||
        drop.quantidadeMinima < 1 || drop.quantidadeMaxima < drop.quantidadeMinima || drop.quantidadeMaxima > 999) return false;
    if (!Number.isInteger(drop.nivelRequerido) || drop.nivelRequerido < 1 || drop.nivelRequerido > 10000) return false;

    const attributeKeys = ["strength", "intelligence", "agility", "vitality", "spirit", "physicalDamage", "magicalDamage", "defense"];
    if (!drop.atributos || attributeKeys.some((key) =>
      !Number.isInteger(drop.atributos[key]) || drop.atributos[key] < 0 || drop.atributos[key] > 100000
    )) return false;

    if (drop.tipo === "EQUIPAMENTO") {
      if (!["WEAPON", "ARMOR", "HELMET", "BOOTS", "GLOVES", "RING", "NECKLACE", "SHIELD"].includes(drop.tipoEquipamento)) return false;
      if (!CREATURE_RANKS.includes(drop.rankEquipamento) || !EQUIPMENT_RARITIES.includes(drop.raridadeEquipamento)) return false;
      if (drop.quantidadeMinima !== 1 || drop.quantidadeMaxima !== 1) return false;
      if (CREATURE_RANKS.indexOf(drop.rankEquipamento) > CREATURE_RANKS.indexOf(creature.rank)) return false;
      if (typeof drop.efeitoEspecial !== "string" || drop.efeitoEspecial.length > 300) return false;
    } else {
      if (drop.tipoEquipamento !== "" || drop.raridadeEquipamento !== "" || drop.rankEquipamento !== "E") return false;
      if (attributeKeys.some((key) => drop.atributos[key] !== 0) || drop.efeitoEspecial !== "") return false;
    }
  }

  if (requestData.isBoss && !creature.drops.some((drop) =>
    drop.tipo === "EQUIPAMENTO" && drop.garantido && drop.chancePercentual === 100 && drop.efeitoEspecial?.trim()
  )) return false;

  return true;
}

async function generateCreature(env, requestData) {
  if (!env.OPENAI_API_KEY) {
    return jsonResponse({ error: "AI_NOT_CONFIGURED", message: "A chave da IA não está configurada." }, 503);
  }

  const bossInstruction = requestData.isBoss
    ? "Crie um CHEFE regional único, imponente e mais perigoso, adequado para uma batalha de chefe. chefe deve ser true."
    : "Crie uma criatura comum de encontro, não um chefe. chefe deve ser false.";

  const prompt = [
    "Crie exatamente uma criatura original para o RPG Ascensão do Soberano.",
    "Responda somente no formato JSON definido pelo schema.",
    "Toda a escrita visível ao jogador deve estar em português do Brasil.",
    "Respeite o ecossistema e o bioma recebidos; não misture temas de outras regiões.",
    "O rank gerado deve ser igual ou inferior ao rank máximo solicitado.",
    "Crie atributos coerentes com rank, nível e perigo, sem números absurdos.",
    "Inclua habilidades, ao menos um ataque funcional e drops temáticos.",
    "Defina atividadeNoturna como true para espécies exclusivas da noite (cerca de 30% das criaturas), e false para espécies diurnas ou comuns a qualquer horário.",
    "Ataques PODEROSO são instantâneos e devem ter recarga de 1 a 3 turnos. Ataques DEVASTADOR podem carregar no máximo 2 turnos; informe danoQuebra coerente e permita interrupção, salvo exceções narrativas raras.",
    "Cada drop deve indicar tipo MATERIAL ou EQUIPAMENTO, quantidade mínima e máxima; materiais devem combinar com anatomia, espécie, bioma e habitat.",
    "Equipamentos devem usar os espaços válidos do jogo, raridadeEquipamento exatamente em COMMON, UNCOMMON, RARE, EPIC, LEGENDARY ou MYTHIC, rank, nível requerido, atributos numéricos e efeito especial coerentes com a criatura.",
    "Para CHEFES, inclua obrigatoriamente pelo menos um EQUIPAMENTO garantido com efeitoEspecial não vazio. O equipamento garantido pode ter raridade COMUM; o efeito especial deve refletir a origem do chefe.",
    "Para materiais, tipoEquipamento e raridadeEquipamento devem ser strings vazias, rankEquipamento deve ser E e atributos devem ser zero. Para equipamentos, quantidadeMinima e quantidadeMaxima devem ser 1.",
    "Use raridades exatamente desta lista: COMUM, INCOMUM, RARO, ÉPICO, LENDÁRIO, MÍTICO, MUNDO.",
    "Não gere caminhos de imagem nem URLs; os campos de imagem serão preenchidos pelo jogo depois.",
    bossInstruction,
    "Contexto: " + JSON.stringify(requestData)
  ].join("\n");

  let response;
  try {
    response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-6-luna",
        reasoning: { effort: "none" },
        input: prompt,
        max_output_tokens: 2200,
        text: {
          format: {
            type: "json_schema",
            name: "ascensao_creature",
            strict: true,
            schema: creatureSchema
          }
        }
      }),
      signal: AbortSignal.timeout(45000)
    });
  } catch {
    return jsonResponse({ error: "OPENAI_CONNECTION_FAILED", message: "Não foi possível conectar ao serviço de geração." }, 502);
  }

  if (!response.ok) {
    return jsonResponse({ error: "OPENAI_REQUEST_FAILED", message: "O serviço de geração recusou a solicitação.", upstreamStatus: response.status }, 502);
  }

  let result;
  try {
    result = await response.json();
  } catch {
    return jsonResponse({ error: "OPENAI_INVALID_RESPONSE", message: "A resposta da IA não pôde ser interpretada." }, 502);
  }

  const outputText = (result.output || [])
    .flatMap((item) => item.content || [])
    .find((item) => item.type === "output_text")?.text;

  if (!outputText) {
    return jsonResponse({ error: "OPENAI_EMPTY_OUTPUT", message: "A IA não retornou os dados da criatura." }, 502);
  }

  let generated;
  try {
    generated = JSON.parse(outputText);
  } catch {
    return jsonResponse({ error: "OPENAI_INVALID_JSON", message: "A IA retornou dados em formato inválido." }, 502);
  }

  if (!validGeneratedCreature(generated, requestData)) {
    return jsonResponse({ error: "CREATURE_VALIDATION_FAILED", message: "A criatura gerada não passou pelas validações do jogo." }, 422);
  }

  return jsonResponse({
    id: "criatura_" + crypto.randomUUID(),
    ...generated,
    ecosystemId: requestData.ecosystemId,
    bioma: requestData.biome,
    chefe: requestData.isBoss,
    imagemId: "",
    imagemIconeCaminho: "",
    imagemDetalhadaCaminho: "",
    versao: 1
  }, 201);
}


const MAX_MONTHLY_AI_REQUESTS = 4000;

// Com GPT-6 Luna, reservamos conservadoramente até US$ 0,0015 por chamada:
// até ~4.000 tokens de entrada + 2.200 tokens de saída. O teto de 4.000
// chamadas fica em US$ 6,00, abaixo de R$ 50 usando R$ 8,00/US$.
export class MonthlyAIBudget {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS monthly_ai_usage (
        month TEXT PRIMARY KEY,
        reservations INTEGER NOT NULL DEFAULT 0
      )
    `);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS monthly_ai_category_usage (
        month TEXT NOT NULL,
        category TEXT NOT NULL,
        reserved_micros INTEGER NOT NULL DEFAULT 0,
        spent_micros INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (month, category)
      )
    `);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS ai_image_reservations (
        reservation_id TEXT PRIMARY KEY,
        month TEXT NOT NULL,
        category TEXT NOT NULL,
        reserved_micros INTEGER NOT NULL,
        actual_micros INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'RESERVED'
      )
    `);
  }

  json(data, status = 200) {
    return new Response(JSON.stringify(data), {
      status,
      headers: { "Content-Type": "application/json; charset=utf-8" }
    });
  }

  categoryLimit(category) {
    if (category === "characters") return 2_000_000;
    if (category === "other_ai") return 48_000_000;
    return null;
  }

  async fetch(request) {
    const url = new URL(request.url);

    if (request.method === "GET") {
      const month = url.searchParams.get("month");
      if (typeof month !== "string" || !/^\d{4}-\d{2}$/.test(month)) {
        return new Response("Invalid month", { status: 400 });
      }
      const rows = this.ctx.storage.sql.exec(
        "SELECT reservations FROM monthly_ai_usage WHERE month = ?",
        month
      ).toArray();
      const categories = this.ctx.storage.sql.exec(
        "SELECT category, reserved_micros, spent_micros FROM monthly_ai_category_usage WHERE month = ?",
        month
      ).toArray();
      return this.json({
        used: rows.length ? rows[0].reservations : 0,
        limit: MAX_MONTHLY_AI_REQUESTS,
        categories
      });
    }

    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return new Response("Invalid JSON", { status: 400 });
    }

    const month = body?.month;
    if (typeof month !== "string" || !/^\d{4}-\d{2}$/.test(month)) {
      return new Response("Invalid month", { status: 400 });
    }

    // Contrato legado: geração de dados de criatura usa contador mensal por chamada.
    if (!body.action) {
      const rows = this.ctx.storage.sql.exec(
        `INSERT INTO monthly_ai_usage (month, reservations)
         VALUES (?, 1)
         ON CONFLICT(month) DO UPDATE
         SET reservations = reservations + 1
         WHERE reservations < ?
         RETURNING reservations`,
        month,
        MAX_MONTHLY_AI_REQUESTS
      ).toArray();

      if (rows.length === 0) {
        return this.json({ allowed: false, limit: MAX_MONTHLY_AI_REQUESTS }, 429);
      }
      return this.json({ allowed: true, used: rows[0].reservations, limit: MAX_MONTHLY_AI_REQUESTS });
    }

    if (body.action === "reserve") {
      const { category, reservationId, reserveMicros, minimumReserveMicros = 0 } = body;
      const limitMicros = this.categoryLimit(category);
      if (!limitMicros || typeof reservationId !== "string" ||
          !/^[A-Za-z0-9_-]{1,120}$/.test(reservationId) ||
          !Number.isSafeInteger(reserveMicros) || reserveMicros <= 0 ||
          !Number.isSafeInteger(minimumReserveMicros) || minimumReserveMicros < 0 ||
          reserveMicros < minimumReserveMicros) {
        return this.json({ error: "INVALID_RESERVATION" }, 400);
      }

      try {
        const result = this.ctx.storage.transactionSync(() => {
          const existing = this.ctx.storage.sql.exec(
            "SELECT month, category, reserved_micros, status FROM ai_image_reservations WHERE reservation_id = ?",
            reservationId
          ).toArray()[0];
          if (existing) {
            if (existing.month !== month || existing.category !== category ||
                existing.reserved_micros !== reserveMicros) return { conflict: true };
            return { existing: true, status: existing.status };
          }

          this.ctx.storage.sql.exec(
            `INSERT INTO monthly_ai_category_usage (month, category, reserved_micros, spent_micros)
             VALUES (?, ?, 0, 0) ON CONFLICT(month, category) DO NOTHING`,
            month, category
          );
          const updated = this.ctx.storage.sql.exec(
            `UPDATE monthly_ai_category_usage
             SET reserved_micros = reserved_micros + ?
             WHERE month = ? AND category = ?
               AND spent_micros + reserved_micros + ? <= ?
             RETURNING reserved_micros, spent_micros`,
            reserveMicros, month, category, reserveMicros, limitMicros
          ).toArray()[0];
          if (!updated) return { exhausted: true };

          this.ctx.storage.sql.exec(
            `INSERT INTO ai_image_reservations
             (reservation_id, month, category, reserved_micros, actual_micros, status)
             VALUES (?, ?, ?, ?, 0, 'RESERVED')`,
            reservationId, month, category, reserveMicros
          );
          return { reserved: true, ...updated };
        });

        if (result.conflict) return this.json({ error: "RESERVATION_ID_CONFLICT" }, 409);
        if (result.exhausted) return this.json({ allowed: false, limitMicros }, 429);
        return this.json({
          allowed: true,
          reused: Boolean(result.existing),
          status: result.status || "RESERVED",
          reservedMicros: result.reserved_micros || reserveMicros,
          spentMicros: result.spent_micros || 0,
          limitMicros
        });
      } catch {
        return this.json({ error: "RESERVATION_FAILED" }, 503);
      }
    }

    if (body.action === "settle") {
      const { reservationId, actualMicros } = body;
      if (typeof reservationId !== "string" ||
          !/^[A-Za-z0-9_-]{1,120}$/.test(reservationId) ||
          !Number.isSafeInteger(actualMicros) || actualMicros < 0) {
        return this.json({ error: "INVALID_SETTLEMENT" }, 400);
      }

      try {
        const result = this.ctx.storage.transactionSync(() => {
          const reservation = this.ctx.storage.sql.exec(
            "SELECT month, category, reserved_micros, actual_micros, status FROM ai_image_reservations WHERE reservation_id = ?",
            reservationId
          ).toArray()[0];
          if (!reservation) return { missing: true };
          if (reservation.month !== month) return { monthMismatch: true };
          if (reservation.status === "SETTLED") {
            return { settled: true, actualMicros: reservation.actual_micros };
          }
          if (actualMicros > reservation.reserved_micros) return { exceeds: true };

          this.ctx.storage.sql.exec(
            `UPDATE monthly_ai_category_usage
             SET reserved_micros = MAX(0, reserved_micros - ?),
                 spent_micros = spent_micros + ?
             WHERE month = ? AND category = ?`,
            reservation.reserved_micros, actualMicros, reservation.month, reservation.category
          );
          this.ctx.storage.sql.exec(
            `UPDATE ai_image_reservations
             SET actual_micros = ?, status = 'SETTLED'
             WHERE reservation_id = ?`,
            actualMicros, reservationId
          );
          return { settled: true, actualMicros };
        });

        if (result.missing) return this.json({ error: "RESERVATION_NOT_FOUND" }, 404);
        if (result.monthMismatch) return this.json({ error: "RESERVATION_MONTH_MISMATCH" }, 409);
        if (result.exceeds) return this.json({ error: "SETTLEMENT_EXCEEDS_RESERVATION" }, 400);
        return this.json({ settled: true, actualMicros: result.actualMicros });
      } catch {
        return this.json({ error: "SETTLEMENT_FAILED" }, 503);
      }
    }

    return this.json({ error: "UNKNOWN_BUDGET_ACTION" }, 400);
  }
}

/**
 * Estado mundial global. A simulação avança em intervalos quando qualquer jogador
 * consulta o mundo; o armazenamento do Durable Object mantém o progresso offline.
 */
/**
 * Estado mundial global. O Durable Object mantém dados entre sessões e executa
 * intervalos atrasados quando um jogador retorna, sem loops por segundo.
 * A agregação por ecossistema mantém o custo proporcional ao número de espécies.
 */

async function readFirestoreDocument(request, collection, documentId) {
  const authorization = request.headers.get("Authorization") || "";
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/${collection}/${encodeURIComponent(documentId)}`;
  const response = await fetch(url, { headers: { Authorization: authorization } });
  if (!response.ok) return { ok: false, status: response.status };
  return { ok: true, document: await response.json() };
}

function firestoreString(fields, key) {
  return fields?.[key]?.stringValue ?? "";
}

function firestoreArray(fields, key) {
  return (fields?.[key]?.arrayValue?.values || [])
    .map((item) => item.stringValue)
    .filter((value) => typeof value === "string" && value.length > 0);
}

function parseFirestoreBattle(document) {
  const fields = document?.fields || {};
  const stateFields = fields.state?.mapValue?.fields || {};
  const members = (fields.members?.arrayValue?.values || []).map((item) => {
    const member = item.mapValue?.fields || {};
    return {
      uid: firestoreString(member, "uid"),
      name: firestoreString(member, "name") || "Aventureiro",
      damageDealt: Number(member.damageDealt?.integerValue || member.damageDealt?.doubleValue || 0)
    };
  }).filter((member) => member.uid);
  return {
    id: document.name?.split("/").pop() || "",
    groupId: firestoreString(fields, "groupId"),
    creatureId: firestoreString(fields, "creatureId"),
    starterUid: firestoreString(fields, "starterUid"),
    activePlayerUid: firestoreString(fields, "activePlayerUid"),
    status: firestoreString(fields, "status"),
    phase: firestoreString(stateFields, "phase"),
    participantUids: firestoreArray(fields, "participantUids"),
    claimedUids: firestoreArray(fields, "claimedUids"),
    members,
    createdAt: fields.createdAt?.timestampValue || ""
  };
}

async function verifiedBattleForUser(request, battleId, uid, requireVictory) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(battleId)) {
    return { ok: false, status: 400, message: "Identificador de batalha inválido." };
  }
  const result = await readFirestoreDocument(request, "allyBattles", battleId);
  if (!result.ok) {
    return {
      ok: false,
      status: result.status === 404 ? 404 : 403,
      message: "Não foi possível confirmar essa batalha no registro oficial."
    };
  }
  const battle = parseFirestoreBattle(result.document);
  if (!battle.creatureId || !battle.participantUids.includes(uid)) {
    return { ok: false, status: 403, message: "Você não participou dessa batalha." };
  }
  if (requireVictory && (
    battle.status !== "FINISHED" ||
    battle.phase !== "VICTORY" ||
    !battle.claimedUids.includes(uid)
  )) {
    return { ok: false, status: 409, message: "A vitória ainda não foi confirmada e reivindicada." };
  }
  return { ok: true, battle };
}

export class PersistentWorldState {
  constructor(ctx) { this.ctx = ctx; this.lock = Promise.resolve(); }

  async load() {
    let state = await this.ctx.storage.get("world");
    if (state) return state;
    const now = Date.now();
    const cities = [
      ["aurelia", "Aurelia", 1000, true],
      ["malachar", "Malachar", 25, false],
      ["cidade_do_sol", "Cidade do Sol", 18, false],
      ["arkanis", "Arkanis", 20, false],
      ["vila_esperanca", "Vila Esperança", 10, false],
      ["mina_dourada", "Mina Dourada", 14, false],
      ["torre_da_sabedoria", "Torre da Sabedoria", 15, false]
    ].map(([id, name, defense, isAurelia]) => ({
      id, name, ecosystemId: id, defense, hostileInvaders: 0,
      condition: "NORMAL", recoveryProgress: 0, isAurelia,
      prosperity: 100, guardStrength: defense, npcPopulation: 100,
      merchantsOpen: true, blacksmithOpen: true, guardPatrol: true,
      tradeStock: 100, evacuatedNpcs: 0
    }));
    state = {
      lastSimulatedAtMillis: now,
      populations: [],
      settlements: cities,
      factions: cities.map((city) => ({
        id: "defenders_" + city.id, name: "Defensores de " + city.name,
        type: "HUMANA", ecosystemId: city.ecosystemId, strength: city.defense
      })),
      wars: [],
      quests: [],
      history: [],
      simulationRevision: 0
    };
    await this.ctx.storage.put("world", state);
    return state;
  }

  async advance(state, now) {
    const interval = 15 * 60 * 1000;
    const steps = Math.min(30 * 24 * 4, Math.max(0, Math.floor((now - state.lastSimulatedAtMillis) / interval)));
    const events = [];
    const neighbors = {
      aurelia: ["cidade_do_sol", "arkanis", "vila_esperanca"],
      malachar: ["mina_dourada", "torre_da_sabedoria"],
      cidade_do_sol: ["aurelia", "vila_esperanca"],
      arkanis: ["aurelia", "torre_da_sabedoria"],
      vila_esperanca: ["aurelia", "cidade_do_sol"],
      mina_dourada: ["malachar"],
      torre_da_sabedoria: ["arkanis", "malachar"]
    };

    for (let i = 0; i < steps; i++) {
      const at = state.lastSimulatedAtMillis + (i + 1) * interval;
      const ecosystemTotals = new Map();
      for (const population of state.populations) {
        ecosystemTotals.set(
          population.ecosystemId,
          (ecosystemTotals.get(population.ecosystemId) || 0) + population.population
        );
      }
      state.populations = state.populations.map((p) => {
        const ecosystemTotal = ecosystemTotals.get(p.ecosystemId) || 0;
        const competition = ecosystemTotal > 160 ? Math.max(1, Math.floor((ecosystemTotal - 160) / 80)) : 0;
        const growth = p.danger >= 80 ? 1 : p.danger >= 45 ? 2 : 3;
        const population = Math.max(1, Math.min(10000, p.population + growth - competition));
        const rankOrder = ["E", "D", "C", "B", "A", "S", "SS", "SSS"];
        const currentRank = rankOrder.indexOf(p.evolvedRank || p.rank || "E");
        const targetEvolution = population >= 2000 ? 7 : population >= 1500 ? 6 : population >= 1200 ? 5 : population >= 900 ? 4 : population >= 700 ? 3 : population >= 400 ? 2 : population >= 180 ? 1 : 0;
        const targetRank = Math.min(7, targetEvolution);
        const evolvedRank = rankOrder[Math.min(targetRank, Math.max(0, currentRank) + (currentRank < targetRank ? 1 : 0))];
        return {
          ...p,
          population,
          hasNest: Boolean(p.hasNest || population >= 12),
          hasLeader: Boolean(p.hasLeader || population >= 30),
          evolvedRank,
          variantId: p.variantId || (population >= 75 && p.danger >= 70 ? "variante_" + p.speciesId : ""),
          factionId: p.factionId || (population >= 30 ? "horda_" + p.ecosystemId : "")
        };
      });

      // Migração de bandos para ecossistemas vizinhos quando há superpopulação.
      if (i % 4 === 3) {
        const migrants = [];
        const populationByKey = new Map(
          state.populations.map((p) => [p.speciesId + "|" + p.ecosystemId, p])
        );
        for (const population of state.populations) {
          if (population.population < 80) continue;
          const destinations = neighbors[population.ecosystemId] || [];
          if (!destinations.length) continue;
          const destination = destinations[(state.simulationRevision + i) % destinations.length];
          const amount = Math.max(1, Math.floor(population.population * 0.05));
          population.population -= amount;
          const key = population.speciesId + "|" + destination;
          const existing = populationByKey.get(key);
          if (existing) existing.population += amount;
          else {
            const migrant = { ...population, ecosystemId: destination, population: amount, hasNest: false, hasLeader: false };
            migrants.push(migrant);
            populationByKey.set(key, migrant);
          }
          events.push({
            id: "migration-" + population.speciesId + "-" + at,
            type: "MIGRACAO", locationId: destination,
            description: "Um bando migrou para um ecossistema vizinho.",
            occurredAtMillis: at
          });
        }
        state.populations.push(...migrants);
      }

      // Forma facções monstruosas quando uma espécie estabelece uma população estável.
      for (const p of state.populations) {
        if (p.population >= 30 && p.factionId && !state.factions.some((f) => f.id === p.factionId)) {
          state.factions.push({
            id: p.factionId, name: "Horda de " + p.ecosystemId,
            type: "MONSTRO", ecosystemId: p.ecosystemId,
            speciesIds: [p.speciesId], strength: p.population,
            leaderFormed: Boolean(p.hasLeader)
          });
          events.push({
            id: "faction-" + p.factionId + "-" + at, type: "FACCAO_FORMADA",
            locationId: p.ecosystemId, description: "Criaturas organizaram uma nova horda territorial.",
            occurredAtMillis: at
          });
        }
      }

      state.settlements = state.settlements.map((city) => {
        const pressure = state.populations
          .filter((p) => p.ecosystemId === city.ecosystemId || (neighbors[city.ecosystemId] || []).includes(p.ecosystemId))
          .reduce((sum, p) => sum + Math.min(10, Math.floor(p.population / 20)), 0);
        if (city.isAurelia) {
          const condition = pressure >= city.defense ? "BESIEGED" : "NORMAL";
          if (condition !== city.condition) events.push({
            id: "aurelia-" + at, type: "DEFESA_AURELIA", locationId: city.id,
            description: condition === "BESIEGED" ? "Aurelia está sob ataque, mas suas defesas resistem." : "As ameaças recuaram das muralhas de Aurelia.",
            occurredAtMillis: at
          });
          return { ...city, condition, guardPatrol: true, merchantsOpen: true, blacksmithOpen: true };
        }
        if (city.condition === "CONQUERED") {
          return {
            ...city, prosperity: Math.max(0, city.prosperity - 1),
            merchantsOpen: false, blacksmithOpen: false, guardPatrol: false,
            npcPopulation: 0
          };
        }
        if (city.condition === "RECOVERING") {
          const progress = city.recoveryProgress + 1;
          const restored = progress >= 8;
          return {
            ...city, condition: restored ? "NORMAL" : "RECOVERING",
            recoveryProgress: restored ? 0 : progress,
            npcPopulation: Math.min(100, city.npcPopulation + 15),
            guardStrength: Math.min(city.defense, city.guardStrength + 2),
            merchantsOpen: progress >= 3,
            blacksmithOpen: progress >= 5,
            guardPatrol: progress >= 6,
            prosperity: Math.min(100, city.prosperity + 5)
          };
        }
        const hostile = pressure >= Math.ceil(city.defense / 2)
          ? city.hostileInvaders + 1 : Math.max(0, city.hostileInvaders - 1);
        const condition = hostile >= city.defense * 2 ? "CONQUERED"
          : hostile >= city.defense ? "BESIEGED"
          : hostile >= Math.ceil(city.defense / 2) ? "THREATENED" : "NORMAL";
        if (condition !== city.condition) {
          events.push({
            id: condition + "-" + city.id + "-" + at, type: condition,
            locationId: city.id,
            description: condition === "CONQUERED" ? city.name + " foi tomada por forças hostis."
              : condition === "BESIEGED" ? city.name + " está sob cerco."
              : condition === "THREATENED" ? city.name + " está ameaçada."
              : city.name + " voltou a ficar estável.",
            occurredAtMillis: at
          });
        }
        return {
          ...city, hostileInvaders: hostile, condition,
          prosperity: Math.max(0, Math.min(100, city.prosperity + (hostile > 0 ? -1 : 1))),
          guardStrength: hostile > 0
            ? Math.max(0, city.guardStrength - 1)
            : Math.min(city.defense, city.guardStrength + 1),
          tradeStock: Math.max(0, Math.min(100, city.tradeStock + (hostile > 0 ? -2 : 2))),
          merchantsOpen: condition !== "CONQUERED",
          blacksmithOpen: condition !== "CONQUERED",
          guardPatrol: condition !== "CONQUERED",
          npcPopulation: condition === "CONQUERED" ? 0 : Math.min(100, city.npcPopulation + (hostile === 0 ? 1 : 0)),
          evacuatedNpcs: condition === "CONQUERED" ? city.npcPopulation : city.evacuatedNpcs
        };
      });

      // Missões dinâmicas acompanham a situação real de cada cidade.
      for (const city of state.settlements) {
        if (city.condition === "THREATENED" || city.condition === "BESIEGED" || city.condition === "CONQUERED") {
          if (!state.quests.some((q) => q.id === "defend-" + city.id)) {
            state.quests.push({
              id: "defend-" + city.id, type: "DEFESA_CIDADE",
              settlementId: city.id, status: "ACTIVE",
              title: "Defender " + city.name,
              description: "Elimine as forças invasoras e proteja a população."
            });
          }
        } else {
          state.quests = state.quests.filter((q) => q.id !== "defend-" + city.id);
        }
      }

      // Guerras persistem enquanto houver ameaça territorial.
      for (const city of state.settlements) {
        const warId = "war-" + city.id;
        const active = city.condition === "THREATENED" || city.condition === "BESIEGED" || city.condition === "CONQUERED";
        const war = state.wars.find((w) => w.id === warId);
        if (active && !war) state.wars.push({
          id: warId, settlementId: city.id, status: "ACTIVE",
          startedAtMillis: at, attacker: "Hordas locais",
          defender: "Defensores de " + city.name
        });
        if (!active && war?.status === "ACTIVE") {
          war.status = "ENDED";
          war.endedAtMillis = at;
        }
      }
    }

    if (steps > 0) {
      state.lastSimulatedAtMillis += steps * interval;
      state.simulationRevision += steps;
      state.history = [...state.history, ...events].slice(-500);
      await this.ctx.storage.put("world", state);
    }
    return { state, elapsedIntervals: steps, eventsCreated: events.length, serverEpochMillis: now };
  }

  async fetch(request) {
    const previous = this.lock;
    let unlock;
    this.lock = new Promise((resolve) => { unlock = resolve; });
    await previous;
    try {
      const url = new URL(request.url);
      const state = await this.load();
      if (request.method === "GET" && url.pathname === "/state") {
        return Response.json(await this.advance(state, Date.now()));
      }

      if (request.method === "GET" && url.pathname === "/bestiary/stats") {
        const creatureId = url.searchParams.get("id") || "";
        if (!/^[A-Za-z0-9_-]{1,128}$/.test(creatureId)) {
          return Response.json({ error: "INVALID_CREATURE_ID" }, { status: 400 });
        }
        const stats = await this.ctx.storage.get("bestiary:" + creatureId);
        return Response.json(stats || {
          creatureId, totalPlayersEncountered: 0, firstDiscovererUid: "",
          firstDiscovererName: "", firstDiscoveryAt: 0, totalDefeats: 0,
          firstDefeaterUid: "", firstDefeaterName: "", firstDefeatAt: 0,
          highestDamage: 0, highestDamageUid: "", highestDamageName: "",
          mostDefeatsUid: "", mostDefeatsName: "", mostDefeatsCount: 0
        });
      }
      if (request.method === "POST" && url.pathname === "/bestiary/encounter") {
        let body;
        try { body = await request.json(); } catch { return Response.json({ error: "INVALID_JSON" }, { status: 400 }); }
        const { creatureId, uid, playerName } = body || {};
        if (!/^[A-Za-z0-9_-]{1,128}$/.test(creatureId || "") || typeof uid !== "string" || !uid) {
          return Response.json({ error: "INVALID_ENCOUNTER" }, { status: 400 });
        }
        const statsKey = "bestiary:" + creatureId;
        const playerKey = "encounter:" + creatureId + ":" + uid;
        let stats = await this.ctx.storage.get(statsKey) || {
          creatureId, totalPlayersEncountered: 0, firstDiscovererUid: "",
          firstDiscovererName: "", firstDiscoveryAt: 0, totalDefeats: 0,
          firstDefeaterUid: "", firstDefeaterName: "", firstDefeatAt: 0,
          highestDamage: 0, highestDamageUid: "", highestDamageName: "",
          mostDefeatsUid: "", mostDefeatsName: "", mostDefeatsCount: 0,
          playerDefeats: {}
        };
        const alreadyEncountered = await this.ctx.storage.get(playerKey);
        if (!alreadyEncountered) {
          const name = typeof playerName === "string" && playerName.trim()
            ? playerName.trim().slice(0, 60) : "Aventureiro";
          stats.totalPlayersEncountered += 1;
          if (!stats.firstDiscovererUid) {
            stats.firstDiscovererUid = uid;
            stats.firstDiscovererName = name;
            stats.firstDiscoveryAt = Date.now();
          }
          await this.ctx.storage.put(playerKey, { encounteredAt: Date.now(), name });
          await this.ctx.storage.put(statsKey, stats);
        }
        return Response.json(stats);
      }
      if (request.method === "POST" && url.pathname === "/bestiary/defeat") {
        let body;
        try { body = await request.json(); } catch { return Response.json({ error: "INVALID_JSON" }, { status: 400 }); }
        const battle = body?.battle;
        if (!battle || !battle.id || !battle.creatureId || !Array.isArray(battle.participantUids) ||
            !battle.participantUids.length || battle.status !== "FINISHED" || battle.phase !== "VICTORY") {
          return Response.json({ error: "INVALID_VICTORY" }, { status: 400 });
        }
        const eventKey = "defeat:" + battle.id;
        if (await this.ctx.storage.get(eventKey)) {
          return Response.json({ registered: false, duplicate: true,
            stats: await this.ctx.storage.get("bestiary:" + battle.creatureId) });
        }
        const statsKey = "bestiary:" + battle.creatureId;
        const stats = await this.ctx.storage.get(statsKey) || {
          creatureId: battle.creatureId, totalPlayersEncountered: 0,
          firstDiscovererUid: "", firstDiscovererName: "", firstDiscoveryAt: 0,
          totalDefeats: 0, firstDefeaterUid: "", firstDefeaterName: "",
          firstDefeatAt: 0, highestDamage: 0, highestDamageUid: "",
          highestDamageName: "", mostDefeatsUid: "", mostDefeatsName: "",
          mostDefeatsCount: 0, playerDefeats: {}
        };
        const members = Array.isArray(battle.members) ? battle.members : [];
        const killer = members.find((member) => member.uid === battle.activePlayerUid);
        const killerName = killer?.name || "Aventureiro";
        stats.totalDefeats += 1;
        if (!stats.firstDefeaterUid) {
          stats.firstDefeaterUid = battle.activePlayerUid || "";
          stats.firstDefeaterName = killerName;
          stats.firstDefeatAt = Date.now();
        }
        for (const member of members) {
          if (!member.uid) continue;
          const name = member.name || "Aventureiro";
          if (!await this.ctx.storage.get("encounter:" + battle.creatureId + ":" + member.uid)) {
            stats.totalPlayersEncountered += 1;
            await this.ctx.storage.put("encounter:" + battle.creatureId + ":" + member.uid,
              { encounteredAt: Date.now(), name });
            if (!stats.firstDiscovererUid) {
              stats.firstDiscovererUid = member.uid;
              stats.firstDiscovererName = name;
              stats.firstDiscoveryAt = Date.now();
            }
          }
          const damage = Math.max(0, Number(member.damageDealt) || 0);
          if (damage > stats.highestDamage) {
            stats.highestDamage = damage;
            stats.highestDamageUid = member.uid;
            stats.highestDamageName = name;
          }
        }
        const playerDefeats = stats.playerDefeats || {};
        const killerUid = battle.activePlayerUid || "";
        if (killerUid) playerDefeats[killerUid] = (playerDefeats[killerUid] || 0) + 1;
        stats.playerDefeats = playerDefeats;
        const topPlayer = Object.entries(playerDefeats).sort((a, b) => b[1] - a[1])[0];
        if (topPlayer) {
          stats.mostDefeatsUid = topPlayer[0];
          stats.mostDefeatsCount = topPlayer[1];
          stats.mostDefeatsName = members.find((member) => member.uid === topPlayer[0])?.name || topPlayer[0];
        }
        stats.lastDefeatAt = Date.now();
        await this.ctx.storage.put(statsKey, stats);
        await this.ctx.storage.put(eventKey, { creatureId: battle.creatureId, registeredAt: Date.now() });
        return Response.json({ registered: true, duplicate: false, stats });
      }
      if (request.method === "POST" && url.pathname === "/register-creature") {
        let body;
        try { body = await request.json(); } catch { return new Response("Invalid JSON", { status: 400 }); }
        if (!body || typeof body.id !== "string" || typeof body.ecosystemId !== "string" || !body.id || !body.ecosystemId) {
          return new Response("Invalid creature registration", { status: 400 });
        }
        if (!state.populations.some((p) => p.speciesId === body.id)) {
          state.populations.push({
            speciesId: body.id, ecosystemId: body.ecosystemId,
            population: 1, danger: Math.max(1, Math.min(100, Number(body.danger) || 1)),
            rank: String(body.rank || "E"), evolvedRank: String(body.rank || "E"),
            hasNest: false, hasLeader: false, variantId: "", factionId: ""
          });
          await this.ctx.storage.put("world", state);
        }
        return Response.json({ registered: true, speciesCount: state.populations.length });
      }
      return new Response("Not found", { status: 404 });
    } finally {
      unlock();
    }
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

    if (path === "/api/characters/visual/generate" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) {
        return jsonResponse({
          error: "UNAUTHORIZED",
          message: "É necessário entrar em uma conta válida.",
          reason: authentication.reason
        }, 401);
      }
      return handleCharacterVisualGeneration(request, env, authentication);
    }

    if (path.startsWith("/images/characters/") && method === "GET") {
      return handleCharacterImageRequest(url, env);
    }

    if (path === "/api/creatures/image" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) {
        return jsonResponse({
          error: "UNAUTHORIZED",
          message: "É necessário entrar em uma conta válida.",
          reason: authentication.reason
        }, 401);
      }
      return handleCreatureImageGeneration(request, env, authentication);
    }

    if (path.startsWith("/api/creatures/image/") && method === "GET") {
      return handleCreatureImageRequest(request, env);
    }

    if (path === "/api/world/clock" && method === "GET") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) {
        return jsonResponse({
          error: "UNAUTHORIZED",
          message: "É necessário entrar em uma conta válida para consultar o relógio mundial."
        }, 401);
      }

      const serverEpochMillis = Date.now();
      const cycleSeconds = 15 * 60;
      const secondOfCycle = Math.floor(serverEpochMillis / 1000) % cycleSeconds;
      return jsonResponse({
        serverEpochMillis,
        cycleSeconds,
        secondOfCycle,
        cycleNumber: Math.floor(serverEpochMillis / 1000 / cycleSeconds)
      });
    }

    if ((path === "/api/world/state" || path === "/api/world/creatures/register") && (method === "GET" || method === "POST")) {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) {
        return jsonResponse({ error: "UNAUTHORIZED", message: "Entre em uma conta válida para acessar o mundo." }, 401);
      }
      const worldId = env.WORLD_STATE.idFromName("ascensao-global-world");
      const world = env.WORLD_STATE.get(worldId);
      const internalPath = path.endsWith("/register") ? "/register-creature" : "/state";
      const response = await world.fetch("https://world" + internalPath, {
        method,
        headers: { "Content-Type": "application/json" },
        body: method === "POST" ? request.body : undefined
      });
      return new Response(response.body, {
        status: response.status,
        headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" }
      });
    }


    if (path === "/api/bestiary/encounter" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const parsed = await readJsonBodyLimited(request, 4000);
      if (!parsed.ok) return jsonResponse({ error: "INVALID_JSON" }, 400);
      const creatureId = parsed.value?.creatureId;
      if (typeof creatureId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(creatureId)) {
        return jsonResponse({ error: "INVALID_CREATURE_ID" }, 400);
      }
      const creature = await readFirestoreDocument(request, "criaturas", creatureId);
      if (!creature.ok) return jsonResponse({ error: "CREATURE_NOT_FOUND", message: "Criatura não encontrada no catálogo oficial." }, 404);
      const creatureFields = creature.document.fields || {};
      const displayName = typeof parsed.value?.playerName === "string" ? parsed.value.playerName.slice(0, 60) : "";
      const world = env.WORLD_STATE.get(env.WORLD_STATE.idFromName("ascensao-global-world"));
      const response = await world.fetch("https://world/bestiary/encounter", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ creatureId, uid: authentication.uid, playerName: displayName })
      });
      return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (path === "/api/bestiary/stats" && method === "GET") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const creatureId = url.searchParams.get("id") || "";
      if (!/^[A-Za-z0-9_-]{1,128}$/.test(creatureId)) return jsonResponse({ error: "INVALID_CREATURE_ID" }, 400);
      const creature = await readFirestoreDocument(request, "criaturas", creatureId);
      if (!creature.ok) return jsonResponse({ error: "CREATURE_NOT_FOUND" }, 404);
      const world = env.WORLD_STATE.get(env.WORLD_STATE.idFromName("ascensao-global-world"));
      const response = await world.fetch("https://world/bestiary/stats?id=" + encodeURIComponent(creatureId));
      return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (path === "/api/bestiary/defeat" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const parsed = await readJsonBodyLimited(request, 4000);
      if (!parsed.ok) return jsonResponse({ error: "INVALID_JSON" }, 400);
      const battleId = parsed.value?.battleId;
      const verified = await verifiedBattleForUser(request, battleId, authentication.uid, true);
      if (!verified.ok) return jsonResponse({ error: "BATTLE_NOT_VERIFIED", message: verified.message }, verified.status);
      const world = env.WORLD_STATE.get(env.WORLD_STATE.idFromName("ascensao-global-world"));
      const response = await world.fetch("https://world/bestiary/defeat", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ battle: verified.battle })
      });
      return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (path === "/health" && method === "GET") {
      let budgetStatus = {
        available: false,
        used: null,
        limit: MAX_MONTHLY_AI_REQUESTS
      };

      try {
        const budgetId = env.AI_BUDGET.idFromName("ascensao-global-monthly-ai");
        const budgetStub = env.AI_BUDGET.get(budgetId);
        const month = new Date().toISOString().slice(0, 7);
        const budgetResponse = await budgetStub.fetch(
          "https://budget/status?month=" + month
        );
        if (budgetResponse.ok) {
          budgetStatus = {
            available: true,
            ...(await budgetResponse.json())
          };
        }
      } catch {
        // Health remains available, but the budget guard is reported unavailable.
      }

      return jsonResponse({
        status: "online",
        service: "Ascensão do Soberano API",
        aiConfigured: Boolean(env.OPENAI_API_KEY),
        budgetGuardAvailable: budgetStatus.available,
        monthlyAIRequestsUsed: budgetStatus.used,
        monthlyAIRequestsLimit: budgetStatus.limit,
        imagesConfigured: Boolean(env.IMAGENS_R2),
        worldStateConfigured: Boolean(env.WORLD_STATE),
        firebaseProjectConfigured: Boolean(FIREBASE_PROJECT_ID),
        adminConfigured: Boolean(env.ADMIN_UID),
      });
    }

    if (path === "/api/creatures/generate" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) {
        return jsonResponse({
          error: "UNAUTHORIZED",
          message: "É necessário entrar em uma conta válida para continuar.",
          reason: authentication.reason,
        }, 401);
      }

      const parsedBody = await readJsonBodyLimited(request, 16000);
      if (!parsedBody.ok) {
        return jsonResponse({
          error: parsedBody.tooLarge ? "REQUEST_TOO_LARGE" : "INVALID_JSON",
          message: parsedBody.tooLarge
            ? "A solicitação ultrapassa o limite permitido."
            : "O corpo da solicitação não contém JSON válido.",
        }, parsedBody.tooLarge ? 413 : 400);
      }
      const body = parsedBody.value;

      const { ecosystemId, biome, rank, danger, isBoss, bossChance = 0 } = body || {};
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
        danger > 100 ||
        typeof isBoss !== "boolean" ||
        !Number.isFinite(bossChance) ||
        bossChance < 0 ||
        bossChance > danger ||
        Math.abs(bossChance * 100 - Math.round(bossChance * 100)) > 1e-7
      ) {
        return jsonResponse({
          error: "INVALID_CREATURE_REQUEST",
          message: "Os dados da região, dificuldade ou tipo de encontro são inválidos.",
        }, 400);
      }

      // Verifica a configuração antes de reservar uso mensal.
      // Assim, uma API sem chave não consome a cota de gerações.
      if (!env.OPENAI_API_KEY) {
        return jsonResponse({
          error: "AI_NOT_CONFIGURED",
          message: "A chave da IA não está configurada. Nenhuma geração foi iniciada."
        }, 503);
      }

      // A proteção é obrigatória: se o contador estiver indisponível,
      // a API não chama a OpenAI.
      let budgetResponse;
      try {
        const budgetId = env.AI_BUDGET.idFromName("ascensao-global-monthly-ai");
        const budgetStub = env.AI_BUDGET.get(budgetId);
        budgetResponse = await budgetStub.fetch("https://budget/reserve", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            month: new Date().toISOString().slice(0, 7)
          })
        });
      } catch {
        return jsonResponse({
          error: "BUDGET_GUARD_UNAVAILABLE",
          message: "A proteção de orçamento está indisponível. Nenhuma geração foi iniciada."
        }, 503);
      }

      if (budgetResponse.status === 429) {
        return jsonResponse({
          error: "MONTHLY_AI_BUDGET_REACHED",
          message: "O limite mensal de geração de criaturas foi atingido."
        }, 429);
      }

      if (!budgetResponse.ok) {
        return jsonResponse({
          error: "BUDGET_GUARD_FAILED",
          message: "Não foi possível confirmar o limite mensal. Nenhuma geração foi iniciada."
        }, 503);
      }

      return generateCreature(env, {
        ecosystemId: ecosystemId.trim(),
        biome: biome.trim(),
        rank,
        danger,
        isBoss,
        bossChance
      });
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

      const parsedBody = await readJsonBodyLimited(request, 7000000);
      if (!parsedBody.ok) {
        return jsonResponse({
          error: parsedBody.tooLarge ? "REQUEST_TOO_LARGE" : "INVALID_JSON",
          message: parsedBody.tooLarge
            ? "A imagem ultrapassa o limite de envio."
            : "O corpo da solicitação não contém JSON válido.",
        }, parsedBody.tooLarge ? 413 : 400);
      }
      const body = parsedBody.value;

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

      if (!matchesImageSignature(imageBytes, contentType)) {
        return jsonResponse({
          error: "IMAGE_CONTENT_MISMATCH",
          message: "O conteúdo do arquivo não corresponde ao formato de imagem informado.",
        }, 415);
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

// Deploy automático via GitHub Actions: validação de integração Cloudflare.
