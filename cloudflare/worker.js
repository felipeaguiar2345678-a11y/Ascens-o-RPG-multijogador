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
      ? { valid: true, uid: payload.sub }
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
          podeSerInterrompida: { type: "boolean" }
        },
        required: ["id", "nome", "descricao", "tipoDano", "elemento", "danoBase", "multiplicador", "custoMana", "custoManaMinimo", "custoManaMaximo", "efeitos", "duracaoTurnos", "chanceAplicacao", "chanceUso", "turnosCarregamento", "turnosRecarga", "podeSerInterrompida"]
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
  required: ["nome", "descricao", "rank", "nivel", "vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico", "experienciaBase", "perigo", "bioma", "habitat", "raridade", "habilidades", "ataques", "drops"]
};

function validGeneratedCreature(creature, requestData) {
  const rankIndex = CREATURE_RANKS.indexOf(creature.rank);
  const requestedRankIndex = CREATURE_RANKS.indexOf(requestData.rank);
  const integerFields = ["nivel", "vidaMaxima", "ataque", "defesa", "manaMaxima", "agilidade", "poderMagico", "experienciaBase", "perigo"];

  if (!creature.nome?.trim() || creature.nome.length > 80 || !creature.descricao?.trim() || creature.descricao.length > 1200) return false;
  if (rankIndex < 0 || rankIndex > requestedRankIndex) return false;
  if (integerFields.some((field) => !Number.isInteger(creature[field]) || creature[field] < 0 || creature[field] > 1000000)) return false;
  if (creature.nivel < 1 || creature.vidaMaxima < 1 || creature.ataque < 1 || creature.experienciaBase < 1) return false;
  if (creature.perigo > 100 || !CREATURE_RARITIES.includes(creature.raridade)) return false;
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
      attack.turnosCarregamento, attack.turnosRecarga
    ];
    if (!attackIntegers.every(Number.isInteger)) return false;
    if (!Number.isFinite(attack.multiplicador) || attack.multiplicador < 0 || attack.multiplicador > 20) return false;
    if (attack.danoBase < 0 || attack.danoBase > 100000 || attack.custoMana < 0 ||
        attack.custoManaMinimo < 0 || attack.custoManaMaximo < attack.custoManaMinimo ||
        attack.custoMana > attack.custoManaMaximo || attack.custoManaMaximo > 100000) return false;
    if (attack.duracaoTurnos < 0 || attack.duracaoTurnos > 20 ||
        attack.chanceAplicacao < 0 || attack.chanceAplicacao > 100 ||
        attack.chanceUso < 0 || attack.chanceUso > 100 ||
        attack.turnosCarregamento < 0 || attack.turnosCarregamento > 10 ||
        attack.turnosRecarga < 0 || attack.turnosRecarga > 20) return false;
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
  }

  async fetch(request) {
    if (request.method === "GET") {
      const month = new URL(request.url).searchParams.get("month");
      if (typeof month !== "string" || !/^\\d{4}-\\d{2}$/.test(month)) {
        return new Response("Invalid month", { status: 400 });
      }
      const rows = this.ctx.storage.sql.exec(
        "SELECT reservations FROM monthly_ai_usage WHERE month = ?",
        month
      ).toArray();
      return new Response(
        JSON.stringify({
          used: rows.length ? rows[0].reservations : 0,
          limit: MAX_MONTHLY_AI_REQUESTS
        }),
        { headers: { "Content-Type": "application/json; charset=utf-8" } }
      );
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

    // Uma única instrução SQL atômica impede que chamadas simultâneas
    // ultrapassem o limite mensal.
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
      return new Response(
        JSON.stringify({
          allowed: false,
          limit: MAX_MONTHLY_AI_REQUESTS
        }),
        {
          status: 429,
          headers: { "Content-Type": "application/json; charset=utf-8" }
        }
      );
    }

    return new Response(
      JSON.stringify({
        allowed: true,
        used: rows[0].reservations,
        limit: MAX_MONTHLY_AI_REQUESTS
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json; charset=utf-8" }
      }
    );
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
        !Number.isInteger(bossChance) ||
        bossChance < 0 ||
        bossChance > 100
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
