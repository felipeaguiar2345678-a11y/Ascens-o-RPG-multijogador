// Publicacao de producao para aplicar os secrets configurados no Worker Cloudflare.
import { handleTradeAction } from "./trade-service.js";
import { handleGuildAction } from "./guild-service.js";
import { handleMultiplayerAction } from "./multiplayer-service.js";
import { handleCharacterPosition } from "./character-service.js";
import { getFirebaseAdminAccessToken } from "./firebase-admin.js";
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


const WORLD_POINT_IDS = new Set([
  "aurelia", "cidade_do_sol", "arkanis", "mina_dourada", "torre_sabedoria",
  "vila_esperanca", "clareira_inicial", "eldarion", "vila_verdejante",
  "torre_natureza", "ruinas_elficas", "fortaleza_glacial", "caverna_gelo",
  "pico_aurora", "valdracon", "forte_guarda", "catacumbas_reais",
  "vila_helios", "malachar", "templo_sombrio", "covil_mortos",
  "vila_necropole", "tharion", "oasis_perdido", "ruinas_antigas",
  "caverna_escorpiao", "kyrath", "ilha_serpente", "torre_oceano",
  // IDs de ecossistema antigos continuam aceitos para compatibilidade.
  "dark_forest", "floresta_sombras", "forgotten_ruins", "abyss_valley",
  "dead_lands", "terras_mortas", "nhar_zul"
]);

// A presença compartilhada do beta só aceita a Floresta Arcana e Aurelia.
// A lista global continua preservada para preparar futuras regiões sem liberá-las agora.
const BETA_WORLD_POINT_IDS = new Set([
  "aurelia",
  "clareira_inicial",
  "eldarion",
  "vila_verdejante",
  "torre_natureza",
  "ruinas_elficas"
]);

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



const storySceneSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    chapterTitle: { type: "string" },
    sceneTitle: { type: "string" },
    narrativeText: { type: "string" },
    choices: { type: "array", items: { type: "string" } },
    eventType: { type: "string", enum: ["NARRATIVE", "QUEST", "ENCOUNTER", "BOSS_CLUE", "REWARD", "TRAVEL"] },
    questTitle: { type: "string" },
    questObjective: { type: "string" },
    questLocationHint: { type: "string" },
    encounterHint: { type: "string", enum: ["NONE", "COMMON", "ELITE", "BOSS"] },
    memorySummary: { type: "string" }
  },
  required: ["chapterTitle", "sceneTitle", "narrativeText", "choices", "eventType", "questTitle", "questObjective", "questLocationHint", "encounterHint", "memorySummary"]
};

async function generateStoryScene(env, context) {
  const prompt = [
    "Você é o Mestre de Jogo oficial de Ascensão do Soberano. Conduza uma campanha de RPG contínua, rica e coerente, como um mestre humano que conhece o grupo.",
    "Responda exclusivamente em JSON conforme o schema. Toda escrita visível deve ser português brasileiro natural.",
    "Narre uma cena concreta e jogável, não um resumo genérico. Use detalhes sensoriais, NPCs com intenção e diálogos curtos quando fizer sentido.",
    "Respeite rigorosamente o histórico e o resumo de memória fornecidos. Não contradiga acontecimentos passados nem ressuscite personagens mortos.",
    "A ação livre do jogador deve ser interpretada como tentativa, não como sucesso automático. Resolva consequências de forma justa e preserve a agência do jogador.",
    "Ofereça de 2 a 4 escolhas distintas, incluindo uma opção cautelosa e uma opção criativa quando apropriado. As escolhas devem levar a consequências diferentes.",
    "Missões devem ter objetivo concreto, motivo narrativo e, quando possível, um local específico dentro da região atual. Não invente coordenadas.",
    "Não conceda experiência, ouro, itens, vitórias ou alterações de atributos diretamente: o jogo valida e concede recompensas pelo sistema próprio.",
    "Use encounterHint COMMON para ameaça comum, ELITE para ameaça forte e BOSS apenas quando a narrativa justificar um chefe. Não force combate em toda cena.",
    "Crie progressão: alternar investigação, diálogo, exploração, perigo, descanso e revelações. Não repita a mesma estrutura de cena consecutivamente.",
    "Mantenha a cena entre 100 e 450 palavras, memorySummary entre 1 e 5 frases e escolhas curtas.",
    "CONTEXTO DO JOGO: " + JSON.stringify(context)
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
        max_output_tokens: 1800,
        text: { format: { type: "json_schema", name: "ascensao_story_scene", strict: true, schema: storySceneSchema } }
      }),
      signal: AbortSignal.timeout(45000)
    });
  } catch {
    return jsonResponse({ error: "OPENAI_CONNECTION_FAILED", message: "Não foi possível conectar ao Mestre de História." }, 502);
  }
  if (!response.ok) {
    return jsonResponse({ error: "OPENAI_REQUEST_FAILED", message: "O Mestre de História não conseguiu responder.", upstreamStatus: response.status }, 502);
  }
  let result;
  try { result = await response.json(); } catch {
    return jsonResponse({ error: "OPENAI_INVALID_RESPONSE", message: "A resposta da história veio inválida." }, 502);
  }
  const outputText = (result.output || []).flatMap((item) => item.content || [])
    .find((item) => item.type === "output_text")?.text;
  if (!outputText) return jsonResponse({ error: "OPENAI_EMPTY_OUTPUT", message: "A IA não retornou uma cena." }, 502);
  let scene;
  try { scene = JSON.parse(outputText); } catch {
    return jsonResponse({ error: "OPENAI_INVALID_JSON", message: "A cena retornou em formato inválido." }, 502);
  }
  if (typeof scene.chapterTitle !== "string" || scene.chapterTitle.length < 1 || scene.chapterTitle.length > 120 ||
      typeof scene.sceneTitle !== "string" || scene.sceneTitle.length < 1 || scene.sceneTitle.length > 140 ||
      typeof scene.narrativeText !== "string" || scene.narrativeText.length < 80 || scene.narrativeText.length > 5000 ||
      !Array.isArray(scene.choices) || scene.choices.length < 2 || scene.choices.length > 4 ||
      scene.choices.some((choice) => typeof choice !== "string" || choice.length < 2 || choice.length > 140) ||
      typeof scene.memorySummary !== "string" || scene.memorySummary.length > 1200 ||
      !["NARRATIVE", "QUEST", "ENCOUNTER", "BOSS_CLUE", "REWARD", "TRAVEL"].includes(scene.eventType) ||
      !["NONE", "COMMON", "ELITE", "BOSS"].includes(scene.encounterHint)) {
    return jsonResponse({ error: "STORY_VALIDATION_FAILED", message: "A cena não passou pelas validações do jogo." }, 422);
  }
  return jsonResponse({ ...scene, generatedAt: Date.now(), model: "gpt-6-luna" }, 200);
}


const characterSkillSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    classDescription: { type: "string" },
    affinities: {
      type: "object",
      additionalProperties: false,
      properties: {
        PHYSICAL: { type: "string", enum: ["LOW", "MEDIUM", "HIGH"] },
        MAGIC: { type: "string", enum: ["LOW", "MEDIUM", "HIGH"] },
        AGILITY: { type: "string", enum: ["LOW", "MEDIUM", "HIGH"] },
        DEFENSE: { type: "string", enum: ["LOW", "MEDIUM", "HIGH"] },
        SUMMONING: { type: "string", enum: ["LOW", "MEDIUM", "HIGH"] }
      },
      required: ["PHYSICAL", "MAGIC", "AGILITY", "DEFENSE", "SUMMONING"]
    },
    powers: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          name: { type: "string" },
          description: { type: "string" },
          type: { type: "string", enum: ["PHYSICAL", "MAGIC", "DEFENSE", "AGILITY", "SUMMONING", "ELEMENTAL", "SPATIAL", "GRAVITY", "HYBRID"] },
          manaCost: { type: "integer" },
          baseDamage: { type: "integer" },
          cooldown: { type: "integer" },
          effects: { type: "array", items: { type: "string" } },
          limitations: { type: "array", items: { type: "string" } }
        },
        required: ["name", "description", "type", "manaCost", "baseDamage", "cooldown", "effects", "limitations"]
      }
    }
  },
  required: ["classDescription", "affinities", "powers"]
};

async function settleSkillReservation(budgetStub, month, reservationId, actualMicros) {
  const response = await budgetStub.fetch("https://budget/settle", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ month, action: "settle", reservationId, actualMicros })
  });
  return response.ok;
}

async function generateCharacterSkills(env, context, budgetStub, month, reservationId) {
  const prompt = [
    "Você é o sistema oficial de criação de classes e habilidades de Ascensão do Soberano.",
    "Analise o conceito livre do jogador, a classe escolhida, as afinidades sugeridas e os atributos.",
    "Crie exatamente quatro habilidades iniciais originais, específicas para ESTE personagem. Nunca reutilize um pacote genérico.",
    "Interprete raças, híbridos, linhagens, elementos, poderes e combinações descritas pelo jogador. Um híbrido deve misturar de verdade suas naturezas.",
    "Identifique a especialidade principal e secundária. HIGH representa afinidade forte; MEDIUM representa aptidão normal; LOW representa aptidão limitada, mas nunca bloqueia aprendizado futuro.",
    "Distribua as quatro habilidades de acordo com a descrição. Para conceitos híbridos, inclua ao menos uma habilidade que combine os domínios quando fizer sentido.",
    "Toda escrita visível deve estar em português brasileiro. Nomes e efeitos devem ser distintos, coerentes, jogáveis e adequados a um personagem de nível 1.",
    "Balanceamento inicial: dano entre 4 e 24; custo de mana entre 0 e 18; recarga entre 0 e 4 turnos. Habilidades defensivas ou utilitárias podem ter dano zero.",
    "Cada habilidade deve ter 1 a 3 efeitos e pelo menos uma limitação real. Não crie poderes absolutos, infinitos ou que ignorem o equilíbrio do jogo.",
    "Não copie habilidades de franquias existentes. Não dê equipamentos, níveis, experiência ou recompensas.",
    "Retorne somente JSON conforme o schema.",
    "Nome: " + context.characterName,
    "Classe: " + context.className,
    "Conceito e descrição: " + context.classDescription,
    "Classe personalizada: " + String(context.isCustom),
    "Afinidades sugeridas: " + JSON.stringify(context.affinities),
    "Atributos: " + JSON.stringify(context.attributes)
  ].join("\n");

  let actualMicros = 0;
  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": "Bearer " + env.OPENAI_API_KEY,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-6-luna",
        reasoning: { effort: "none" },
        input: prompt,
        max_output_tokens: 1400,
        text: {
          format: {
            type: "json_schema",
            name: "ascensao_character_skills",
            strict: true,
            schema: characterSkillSchema
          }
        }
      }),
      signal: AbortSignal.timeout(45000)
    });

    if (!response.ok) {
      await settleSkillReservation(budgetStub, month, reservationId, 0).catch(() => false);
      return jsonResponse({
        error: "SKILL_GENERATION_FAILED",
        message: "A IA não conseguiu criar as habilidades agora. Tente novamente."
      }, 502);
    }

    const result = await response.json();
    const usage = result.usage || {};
    const inputTokens = Number(usage.input_tokens);
    const outputTokens = Number(usage.output_tokens);
    if (!Number.isSafeInteger(inputTokens) || inputTokens < 0 ||
        !Number.isSafeInteger(outputTokens) || outputTokens < 0) {
      await settleSkillReservation(budgetStub, month, reservationId, 10000).catch(() => false);
      return jsonResponse({
        error: "SKILL_USAGE_UNAVAILABLE",
        message: "Não foi possível confirmar o custo da geração."
      }, 502);
    }

    // GPT-6 Luna: US$ 0,10/M entrada e US$ 0,50/M saída.
    // Reserva e limite desta categoria são contabilizados em micros de real;
    // câmbio de segurança fixado em R$ 9 por dólar.
    actualMicros = Math.ceil((inputTokens * 0.1 + outputTokens * 0.5) * 9);
    if (actualMicros > 10000) {
      await settleSkillReservation(budgetStub, month, reservationId, 10000).catch(() => false);
      return jsonResponse({
        error: "SKILL_COST_LIMIT",
        message: "A geração ultrapassou a reserva máxima permitida."
      }, 503);
    }

    const outputText = (result.output || [])
      .flatMap((item) => item.content || [])
      .find((item) => item.type === "output_text")?.text;
    if (!outputText) {
      await settleSkillReservation(budgetStub, month, reservationId, actualMicros).catch(() => false);
      return jsonResponse({ error: "SKILL_EMPTY_OUTPUT", message: "A IA não retornou habilidades." }, 502);
    }

    let generated;
    try { generated = JSON.parse(outputText); } catch {
      await settleSkillReservation(budgetStub, month, reservationId, actualMicros).catch(() => false);
      return jsonResponse({ error: "SKILL_INVALID_JSON", message: "A resposta de habilidades veio inválida." }, 502);
    }

    const validAffinity = (value) => ["LOW", "MEDIUM", "HIGH"].includes(value);
    const affinityKeys = ["PHYSICAL", "MAGIC", "AGILITY", "DEFENSE", "SUMMONING"];
    if (!generated.classDescription || generated.classDescription.length > 500 ||
        !generated.affinities || affinityKeys.some((key) => !validAffinity(generated.affinities[key])) ||
        !Array.isArray(generated.powers) || generated.powers.length !== 4) {
      await settleSkillReservation(budgetStub, month, reservationId, actualMicros).catch(() => false);
      return jsonResponse({ error: "SKILL_VALIDATION_FAILED", message: "As habilidades não passaram pela validação do jogo." }, 422);
    }

    const allowedTypes = ["PHYSICAL", "MAGIC", "DEFENSE", "AGILITY", "SUMMONING", "ELEMENTAL", "SPATIAL", "GRAVITY", "HYBRID"];
    for (const power of generated.powers) {
      if (typeof power.name !== "string" || power.name.trim().length < 2 || power.name.length > 70 ||
          typeof power.description !== "string" || power.description.trim().length < 10 || power.description.length > 500 ||
          !allowedTypes.includes(power.type) ||
          !Number.isInteger(power.manaCost) || power.manaCost < 0 || power.manaCost > 18 ||
          !Number.isInteger(power.baseDamage) || power.baseDamage < 0 || power.baseDamage > 24 ||
          !Number.isInteger(power.cooldown) || power.cooldown < 0 || power.cooldown > 4 ||
          !Array.isArray(power.effects) || power.effects.length < 1 || power.effects.length > 3 ||
          power.effects.some((effect) => typeof effect !== "string" || effect.length > 140) ||
          !Array.isArray(power.limitations) || power.limitations.length < 1 || power.limitations.length > 3 ||
          power.limitations.some((limit) => typeof limit !== "string" || limit.length > 180)) {
        await settleSkillReservation(budgetStub, month, reservationId, actualMicros).catch(() => false);
        return jsonResponse({ error: "SKILL_VALIDATION_FAILED", message: "Uma habilidade não passou pela validação do jogo." }, 422);
      }
    }

    const settled = await settleSkillReservation(budgetStub, month, reservationId, actualMicros);
    if (!settled) {
      return jsonResponse({ error: "SKILL_BUDGET_SETTLEMENT_FAILED", message: "Não foi possível concluir a conferência do orçamento. Tente novamente mais tarde." }, 503);
    }

    return jsonResponse({
      classDescription: generated.classDescription,
      affinities: generated.affinities,
      powers: generated.powers,
      model: "gpt-6-luna",
      actualCostBRL: actualMicros / 1000000
    }, 201);
  } catch {
    await settleSkillReservation(budgetStub, month, reservationId, actualMicros).catch(() => false);
    return jsonResponse({ error: "SKILL_GENERATION_ERROR", message: "Não foi possível gerar as habilidades neste momento." }, 502);
  }
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
  const enemyFields = stateFields.enemy?.mapValue?.fields || {};
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
    enemyHp: Number(enemyFields.hp?.integerValue || enemyFields.hp?.doubleValue || 0),
    enemyMaxHp: Number(enemyFields.maxHp?.integerValue || enemyFields.maxHp?.doubleValue || 0),
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
  if (requireVictory) {
    const participantSet = new Set(battle.participantUids);
    const memberSet = new Set(battle.members.map((member) => member.uid));
    const validRoster = participantSet.size === battle.participantUids.length &&
      battle.participantUids.length > 0 && battle.participantUids.length <= 4 &&
      memberSet.size === battle.members.length &&
      memberSet.size === participantSet.size &&
      battle.participantUids.every((participantUid) => memberSet.has(participantUid)) &&
      battle.members.every((member) => Number.isFinite(member.damageDealt) && member.damageDealt >= 0);
    if (!validRoster || battle.status !== "FINISHED" ||
        battle.phase !== "VICTORY" ||
        battle.enemyHp > 0 ||
        battle.enemyMaxHp < 1 ||
        battle.members.reduce((total, member) => total + member.damageDealt, 0) < battle.enemyMaxHp ||
        !battle.claimedUids.includes(uid) ||
        !participantSet.has(battle.activePlayerUid) ||
        !memberSet.has(battle.activePlayerUid)) {
      return { ok: false, status: 409, message: "A vitória ainda não foi confirmada, reivindicada ou possui participantes inconsistentes." };
    }
  }
  return { ok: true, battle };
}

export class PersistentWorldState {
  constructor(ctx) { this.ctx = ctx; this.lock = Promise.resolve(); }

  async load() {
    let state = await this.ctx.storage.get("world");
    const now = Date.now();

    // Reconstrução controlada da simulação mundial. A cópia anterior fica
    // preservada para recuperação; contas, personagens, bestiário e presença
    // ficam em chaves/coleções separadas e não são tocados por esta migração.
    const WORLD_SCHEMA_VERSION = 3;
    if (state && (state.schemaVersion || 1) < WORLD_SCHEMA_VERSION) {
      const backupKey = "world_backup_before_schema_" + WORLD_SCHEMA_VERSION;
      if (!(await this.ctx.storage.get(backupKey))) {
        await this.ctx.storage.put(backupKey, state);
      }
      state = null;
    }

    if (state) {
      // Migração segura de mundos já existentes: adiciona os sistemas de NPC
      // sem apagar população, guerras, missões ou histórico já persistidos.
      state.npcs ||= [];
      state.npcProblems ||= [];
      const cities = state.settlements || [];
      const existingNpcIds = new Set(state.npcs.map((npc) => npc.id));
      for (const city of cities) {
        const definitions = [
          {
            suffix: "comerciante",
            name: city.id === "aurelia" ? "Liora" : "Comerciante de " + city.name,
            role: "COMERCIANTE", activity: "TRADING", mood: "TRANQUILO"
          },
          {
            suffix: "guarda",
            name: city.id === "aurelia" ? "Capitão Daren" : "Guarda de " + city.name,
            role: "GUARDA", activity: "GUARDING", mood: "ATENTO"
          },
          {
            suffix: "morador",
            name: city.id === "aurelia" ? "Mira" : "Morador de " + city.name,
            role: "MORADOR", activity: "WORKING", mood: "TRANQUILO"
          }
        ];
        for (const definition of definitions) {
          const id = "npc_" + city.id + "_" + definition.suffix;
          if (existingNpcIds.has(id)) continue;
          state.npcs.push({
            id, name: definition.name, role: definition.role,
            homeLocationId: city.id, currentLocationId: city.id,
            activity: definition.activity, alive: true,
            foodNeed: 0, waterNeed: 0, restNeed: 0, safetyNeed: 0,
            relationship: 0, mood: definition.mood, lastNeedUpdateAt: now
          });
          existingNpcIds.add(id);
        }
      }
      state.schemaVersion = WORLD_SCHEMA_VERSION;
      state.lastSimulatedAtMillis ||= now;
      await this.ctx.storage.put("world", state);
      return state;
    }
    const cities = [
      ["aurelia", "Aurelia", 1000, true],
      ["malachar", "Malachar", 25, false],
      ["cidade_do_sol", "Cidade do Sol", 18, false],
      ["arkanis", "Arkanis", 20, false],
      ["vila_esperanca", "Vila Esperança", 10, false],
      ["mina_dourada", "Mina Dourada", 14, false],
      ["torre_da_sabedoria", "Torre da Sabedoria", 15, false],
      ["vila_verdejante", "Vila Verdejante", 12, false],
      ["eldarion", "Eldarion", 20, false],
      ["torre_natureza", "Torre da Natureza", 14, false]
    ].map(([id, name, defense, isAurelia]) => ({
      id, name, ecosystemId: id, defense, hostileInvaders: 0,
      condition: "NORMAL", recoveryProgress: 0, isAurelia,
      prosperity: 100, guardStrength: defense, npcPopulation: 100,
      merchantsOpen: true, blacksmithOpen: true, guardPatrol: true,
      tradeStock: 100, evacuatedNpcs: 0
    }));
    state = {
      schemaVersion: WORLD_SCHEMA_VERSION,
      lastSimulatedAtMillis: now,
      populations: [],
      settlements: cities,
      factions: cities.map((city) => ({
        id: "defenders_" + city.id, name: "Defensores de " + city.name,
        type: "HUMANA", ecosystemId: city.ecosystemId, strength: city.defense
      })),
      wars: [],
      quests: [],
      npcs: cities.flatMap((city, cityIndex) => [
        {
          id: "npc_" + city.id + "_comerciante",
          name: city.id === "aurelia" ? "Liora" : "Comerciante de " + city.name,
          role: "COMERCIANTE", homeLocationId: city.id, currentLocationId: city.id,
          activity: "TRADING", alive: true, foodNeed: 0, waterNeed: 0, restNeed: 0,
          safetyNeed: 0, relationship: 0, mood: "TRANQUILO", lastNeedUpdateAt: now
        },
        {
          id: "npc_" + city.id + "_guarda",
          name: city.id === "aurelia" ? "Capitão Daren" : "Guarda de " + city.name,
          role: "GUARDA", homeLocationId: city.id, currentLocationId: city.id,
          activity: "GUARDING", alive: true, foodNeed: 0, waterNeed: 0, restNeed: 0,
          safetyNeed: 0, relationship: 0, mood: "ATENTO", lastNeedUpdateAt: now
        },
        {
          id: "npc_" + city.id + "_morador",
          name: city.id === "aurelia" ? "Mira" : "Morador de " + city.name,
          role: "MORADOR", homeLocationId: city.id, currentLocationId: city.id,
          activity: "WORKING", alive: true, foodNeed: 0, waterNeed: 0, restNeed: 0,
          safetyNeed: 0, relationship: 0, mood: "TRANQUILO", lastNeedUpdateAt: now
        }
      ]),
      npcProblems: [],
      history: [],
      simulationRevision: 0
    };
    await this.ctx.storage.put("world", state);
    return state;
  }

  async advance(state, now) {
    state.npcs ||= [];
    state.npcProblems ||= [];
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
      torre_da_sabedoria: ["arkanis", "malachar"],
      vila_verdejante: ["eldarion", "aurelia"],
      eldarion: ["vila_verdejante", "torre_natureza"],
      torre_natureza: ["eldarion"]
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

      // Necessidades e rotinas dos habitantes avançam no mesmo relógio global.
      state.npcs = (state.npcs || []).map((npc) => {
        if (!npc.alive) return npc;
        const city = state.settlements.find((entry) => entry.id === npc.homeLocationId);
        const threatened = city && ["THREATENED", "BESIEGED", "CONQUERED"].includes(city.condition);
        const hour = new Date(at).getUTCHours();
        let activity = npc.activity;
        if (npc.role === "COMERCIANTE") activity = hour >= 7 && hour < 19 ? "TRADING" : "SLEEPING";
        else if (npc.role === "GUARDA") activity = hour >= 20 || hour < 1 ? "GUARDING"
          : hour >= 1 && hour < 5 ? "SLEEPING" : "PATROLLING";
        else activity = hour >= 22 || hour < 6 ? "SLEEPING" : hour < 16 ? "WORKING" : "SOCIALIZING";

        // Necessidades não ficam permanentemente acumuladas: em cidades seguras
        // os habitantes conseguem se alimentar, beber água e descansar.
        const foodRelief = city && city.merchantsOpen && !threatened ? 2 : 0;
        const waterRelief = city && city.condition !== "CONQUERED" ? 2 : 0;
        const foodNeed = Math.max(0, Math.min(100, (npc.foodNeed || 0) + 1 - foodRelief));
        const waterNeed = Math.max(0, Math.min(100, (npc.waterNeed || 0) + 2 - waterRelief));
        const restDelta = activity === "SLEEPING" ? -8
          : (activity === "WORKING" || activity === "GUARDING" ? 1 : 0);
        const restNeed = Math.max(0, Math.min(100, (npc.restNeed || 0) + restDelta));
        const safetyNeed = Math.max(0, Math.min(100, (npc.safetyNeed || 0) + (threatened ? 4 : -3)));
        const mood = safetyNeed >= 75 ? "ASSUSTADO" : waterNeed >= 85 || foodNeed >= 85 ? "DESESPERADO"
          : restNeed >= 85 ? "EXAUSTO" : threatened ? "PREOCUPADO" : "TRANQUILO";
        return { ...npc, foodNeed, waterNeed, restNeed, safetyNeed, activity, mood, lastNeedUpdateAt: at };
      });

      // Problemas concretos surgem das necessidades e da situação do povoado.
      for (const npc of state.npcs || []) {
        if (!npc.alive) continue;
        const urgent = Math.max(npc.foodNeed || 0, npc.waterNeed || 0, npc.restNeed || 0, npc.safetyNeed || 0);
        if (urgent < 70) continue;
        const existing = state.npcProblems.find((problem) => problem.npcId === npc.id && problem.status === "ACTIVE");
        const problemId = "npc_problem_" + npc.id + "_" + at;
        if (!existing) {
          const type = (npc.safetyNeed || 0) >= 70 ? "PROTEGER_HABITANTE"
            : (npc.waterNeed || 0) >= (npc.foodNeed || 0) && (npc.waterNeed || 0) >= (npc.restNeed || 0) ? "BUSCAR_AGUA"
            : (npc.foodNeed || 0) >= (npc.restNeed || 0) ? "CONSEGUIR_ALIMENTOS" : "AJUDAR_A_DESCANSAR";
          state.npcProblems.push({
            id: problemId, npcId: npc.id, settlementId: npc.homeLocationId,
            type, status: "ACTIVE",
            title: type === "PROTEGER_HABITANTE" ? "Proteger " + npc.name
              : type === "BUSCAR_AGUA" ? "Encontrar água para " + npc.name
              : type === "AJUDAR_A_DESCANSAR" ? "Ajudar " + npc.name + " a descansar"
              : "Conseguir alimentos para " + npc.name,
            description: type === "PROTEGER_HABITANTE"
              ? npc.name + " está em perigo devido às ameaças na região."
              : type === "BUSCAR_AGUA" ? npc.name + " está precisando de água."
              : type === "AJUDAR_A_DESCANSAR" ? npc.name + " está exausto e precisa de repouso."
              : npc.name + " está sem alimentos e precisa de ajuda.",
            createdAtMillis: at,
            expiresAtMillis: at + 24 * 60 * 60 * 1000,
            consequence: type === "PROTEGER_HABITANTE" ? "SEGURANCA_E_RELACIONAMENTO"
              : "NECESSIDADES_E_RELACIONAMENTO"
          });
          events.push({
            id: problemId + "-" + at, type: "PROBLEMA_NPC",
            locationId: npc.homeLocationId,
            description: npc.name + " precisa de ajuda em " + (npc.homeLocationId || "sua região") + ".",
            occurredAtMillis: at
          });
        }
      }
      state.npcProblems = (state.npcProblems || []).map((problem) =>
        problem.status === "ACTIVE" && problem.expiresAtMillis <= at
          ? { ...problem, status: "EXPIRED", expiredAtMillis: at }
          : problem
      ).slice(-500);

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

      if (request.method === "GET" && url.pathname === "/npcs") {
        const settlementId = url.searchParams.get("settlementId") || "";
        const uid = url.searchParams.get("uid") || "";
        if (!BETA_WORLD_POINT_IDS.has(settlementId) || !/^[A-Za-z0-9_-]{1,128}$/.test(uid)) {
          return Response.json({ error: "INVALID_SETTLEMENT" }, { status: 400 });
        }
        return Response.json({
          settlementId,
          npcs: (state.npcs || [])
            .filter((npc) => npc.homeLocationId === settlementId && npc.alive)
            .map((npc) => ({
              id: npc.id, name: npc.name, role: npc.role, activity: npc.activity,
              mood: npc.mood, relationship: (npc.relationshipByUid || {})[uid] || 0
            })),
          problems: (state.npcProblems || [])
            .filter((problem) => problem.settlementId === settlementId && problem.status === "ACTIVE")
            .map(({ acceptedByUid, resolvedByUid, resolvedAtByUid, ...problem }) => ({
              ...problem,
              acceptedByMe: Boolean(acceptedByUid?.[uid]),
              resolvedByMe: Boolean(resolvedByUid?.[uid])
            }))
        });
      }

      if (request.method === "POST" && url.pathname === "/npc/interact") {
        let body;
        try { body = await request.json(); } catch {
          return Response.json({ error: "INVALID_JSON" }, { status: 400 });
        }
        const uid = typeof body?.uid === "string" ? body.uid : "";
        const npcId = typeof body?.npcId === "string" ? body.npcId : "";
        const action = typeof body?.action === "string" ? body.action : "";
        const problemId = typeof body?.problemId === "string" ? body.problemId : "";
        if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid) ||
            !/^npc_[A-Za-z0-9_-]{1,120}$/.test(npcId) ||
            !["CONVERSAR", "ACEITAR_PEDIDO", "AJUDAR_HABITANTE"].includes(action)) {
          return Response.json({ error: "INVALID_NPC_INTERACTION" }, { status: 400 });
        }
        const npc = (state.npcs || []).find((entry) => entry.id === npcId && entry.alive);
        if (!npc || !BETA_WORLD_POINT_IDS.has(npc.homeLocationId)) {
          return Response.json({ error: "NPC_NOT_FOUND" }, { status: 404 });
        }
        const now = Date.now();
        const presence = await this.ctx.storage.get("presence:" + uid);
        const atNpcSettlement = presence &&
          now - (presence.updatedAt || 0) <= 30000 &&
          (presence.worldPointId === npc.homeLocationId ||
            (npc.homeLocationId === "vila_verdejante" && presence.worldPointId === "clareira_inicial"));
        if (!atNpcSettlement) {
          return Response.json({ error: "PLAYER_NOT_AT_NPC_LOCATION" }, { status: 403 });
        }
        npc.relationshipByUid ||= {};

        if (action === "CONVERSAR") {
          npc.interactionCooldowns ||= {};
          const lastInteraction = npc.interactionCooldowns[uid] || 0;
          if (now - lastInteraction < 15000) {
            return Response.json({ error: "INTERACTION_COOLDOWN", remainingMillis: 15000 - (now - lastInteraction) }, { status: 429 });
          }
          npc.relationshipByUid[uid] = Math.min(100, (npc.relationshipByUid[uid] || 0) + 1);
          npc.interactionCooldowns[uid] = now;
          npc.lastInteractionAtMillis = now;

          const relationship = npc.relationshipByUid[uid];
          const relationshipTier = relationship >= 90 ? "CONFIDENTE"
            : relationship >= 60 ? "ALIADO"
            : relationship >= 30 ? "AMIGO"
            : relationship >= 10 ? "CONHECIDO"
            : "ESTRANHO";
          const dialogueByRole = {
            COMERCIANTE: [
              "As estradas estão mais movimentadas hoje. Se procura algo raro, fique de olho nos viajantes.",
              "Tenho separado algumas mercadorias para quem conhece bem esta cidade.",
              "Ouvi rumores sobre materiais incomuns encontrados nas trilhas da floresta."
            ],
            GUARDA: [
              "Mantenha os olhos abertos. A floresta muda quando o sol desaparece.",
              "A patrulha encontrou rastros perto das antigas ruínas. Evite caminhar sem preparo.",
              "Você já provou ser confiável. Se notar algo estranho, avise a guarda imediatamente."
            ],
            MORADOR: [
              "A vida por aqui é tranquila, mas nem sempre a floresta nos deixa em paz.",
              "Os viajantes contam histórias diferentes sobre as criaturas que vivem além da estrada.",
              "É bom ver alguém disposto a ajudar esta comunidade. Sua presença faz diferença."
            ]
          };
          const friendDialogueByRole = {
            COMERCIANTE: ["Entre, amigo. Gosto de negociar com quem respeita esta cidade."],
            GUARDA: ["Já reconheço seus passos. É bom saber que podemos contar com você."],
            MORADOR: ["Guardei algumas histórias da minha família. Um dia quero compartilhar todas com você."]
          };
          const allyDialogueByRole = {
            COMERCIANTE: ["Entre nós: alguns viajantes encontraram materiais raros longe das estradas principais."],
            GUARDA: ["Confio em você. Há sinais de que criaturas estão mudando seus territórios na floresta."],
            MORADOR: ["Sua ajuda trouxe esperança para minha família. Você já é parte desta comunidade."]
          };
          const confidantDialogueByRole = {
            COMERCIANTE: ["Vou lhe contar um segredo: os melhores achados nem sempre estão à venda; às vezes estão escondidos nas histórias dos viajantes."],
            GUARDA: ["Poucos conhecem este segredo: os rastros mais antigos na floresta não pertencem às criaturas comuns."],
            MORADOR: ["Confio em você como alguém da família. Há uma antiga história sobre a Clareira Inicial que quase ninguém conhece."]
          };
          const lines = npc.mood === "ASSUSTADO"
            ? ["Por favor, tenha cuidado... algo assustador foi visto por perto.", "Não me sinto seguro enquanto a ameaça continuar por aqui."]
            : npc.mood === "PREOCUPADO" || npc.mood === "DESESPERADO"
              ? ["Há problemas que não conseguimos resolver sozinhos. Talvez você possa ajudar.", "A comunidade precisa de apoio. Não sabemos quanto tempo ainda temos."]
              : relationship >= 90
                ? (confidantDialogueByRole[npc.role] || confidantDialogueByRole.MORADOR)
                : relationship >= 60
                  ? (allyDialogueByRole[npc.role] || allyDialogueByRole.MORADOR)
                  : relationship >= 30
                    ? (friendDialogueByRole[npc.role] || friendDialogueByRole.MORADOR)
                    : (dialogueByRole[npc.role] || dialogueByRole.MORADOR);
          npc.dialogueCountByUid ||= {};
          const dialogueIndex = npc.dialogueCountByUid[uid] || 0;
          const dialogue = lines[dialogueIndex % lines.length];
          npc.dialogueCountByUid[uid] = dialogueIndex + 1;

          await this.ctx.storage.put("world", state);
          return Response.json({
            interacted: true,
            dialogue,
            relationshipTier,
            npc: { id: npc.id, name: npc.name, role: npc.role, mood: npc.mood,
              relationship, relationshipTier }
          });
        }

        if (!/^npc_problem_[A-Za-z0-9_-]{1,180}$/.test(problemId)) {
          return Response.json({ error: "INVALID_NPC_PROBLEM" }, { status: 400 });
        }
        const problem = (state.npcProblems || []).find((entry) =>
          entry.id === problemId && entry.npcId === npcId &&
          entry.settlementId === npc.homeLocationId
        );
        if (!problem) return Response.json({ error: "NPC_PROBLEM_NOT_FOUND" }, { status: 404 });
        if (problem.status === "ACTIVE" &&
            (!Number.isFinite(problem.expiresAtMillis) || problem.expiresAtMillis <= now)) {
          problem.status = "EXPIRED";
          problem.expiredAtMillis = now;
          await this.ctx.storage.put("world", state);
          return Response.json({ error: "NPC_PROBLEM_EXPIRED" }, { status: 410 });
        }

        problem.acceptedByUid ||= {};
        problem.resolvedByUid ||= {};
        problem.resolvedAtByUid ||= {};

        if (problem.resolvedByUid[uid]) {
          return Response.json({
            resolved: true, alreadyResolved: true, problemId,
            relationship: npc.relationshipByUid[uid] || 0
          });
        }

        if (action === "ACEITAR_PEDIDO") {
          if (problem.status !== "ACTIVE") {
            return Response.json({ error: "NPC_PROBLEM_UNAVAILABLE" }, { status: 409 });
          }
          const acceptedBy = problem.acceptedByUid[uid];
          if (acceptedBy) {
            return Response.json({ accepted: true, problemId, alreadyAccepted: true });
          }
          problem.acceptedByUid[uid] = now;
          await this.ctx.storage.put("world", state);
          return Response.json({ accepted: true, problemId, acceptedAtMillis: now });
        }

        if (problem.status !== "ACTIVE" || !problem.acceptedByUid[uid]) {
          return Response.json({ error: "NPC_PROBLEM_NOT_ACCEPTED" }, { status: 409 });
        }

        // A conclusão é individual: todos podem ajudar a mesma comunidade,
        // sem que o primeiro jogador bloqueie a recompensa dos demais.
        problem.resolvedByUid[uid] = true;
        problem.resolvedAtByUid[uid] = now;
        npc.relationshipByUid[uid] = Math.min(100, (npc.relationshipByUid[uid] || 0) + 5);
        if (problem.type === "BUSCAR_AGUA") npc.waterNeed = 0;
        else if (problem.type === "CONSEGUIR_ALIMENTOS") npc.foodNeed = 0;
        else if (problem.type === "AJUDAR_A_DESCANSAR") npc.restNeed = 0;
        else if (problem.type === "PROTEGER_HABITANTE") npc.safetyNeed = 0;
        npc.mood = "GRATO";
        await this.ctx.storage.put("world", state);
        return Response.json({
          resolved: true, problemId, relationship: npc.relationshipByUid[uid],
          relationshipGained: 5
        });
      }

      if (request.method === "GET" && url.pathname === "/creature-placements") {
        const ecosystemId = url.searchParams.get("ecosystemId") || "";
        if (!/^[A-Za-z0-9_-]{1,100}$/.test(ecosystemId)) {
          return Response.json({ error: "INVALID_ECOSYSTEM" }, { status: 400 });
        }
        return Response.json({
          creatures: state.populations.filter((population) => population.ecosystemId === ecosystemId)
        });
      }

      // Presença e posição compartilhadas: a posição oficial fica no Durable Object,
      // nunca no documento gravado livremente pelo cliente.
      if (request.method === "POST" && url.pathname === "/presence") {
        let body;
        try { body = await request.json(); } catch {
          return Response.json({ error: "INVALID_JSON" }, { status: 400 });
        }
        const uid = typeof body.uid === "string" ? body.uid : "";
        const worldPointId = typeof body.worldPointId === "string" ? body.worldPointId.trim() : "";
        const x = Number(body.x);
        const y = Number(body.y);
        if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid) ||
            !BETA_WORLD_POINT_IDS.has(worldPointId) ||
            !Number.isFinite(x) || !Number.isFinite(y) ||
            Math.abs(x) > 100 || Math.abs(y) > 100) {
          return Response.json({ error: "INVALID_PRESENCE" }, { status: 400 });
        }
        const now = Date.now();
        const key = "presence:" + uid;
        const previousPresence = await this.ctx.storage.get(key);
        let acceptedX = x;
        let acceptedY = y;
        if (previousPresence && previousPresence.worldPointId === worldPointId) {
          const elapsedSeconds = Math.max(0.25, Math.min(30, (now - previousPresence.updatedAt) / 1000));
          const dx = x - previousPresence.x;
          const dy = y - previousPresence.y;
          const distance = Math.sqrt(dx * dx + dy * dy);
          const maximumDistance = 0.12 * elapsedSeconds * 1.8 + 0.035;
          if (distance > maximumDistance) {
            acceptedX = previousPresence.x;
            acceptedY = previousPresence.y;
          }
        }
        const presence = {
          uid,
          nome: typeof body.nome === "string" && body.nome.trim()
            ? body.nome.trim().slice(0, 60) : "Aventureiro",
          nivel: Math.max(1, Math.min(10000, Math.floor(Number(body.nivel) || 1))),
          worldPointId,
          x: acceptedX,
          y: acceptedY,
          vida: Math.max(0, Math.min(1000000, Math.floor(Number(body.vida) || 0))),
          vidaMaxima: Math.max(0, Math.min(1000000, Math.floor(Number(body.vidaMaxima) || 0))),
          ataque: Math.max(0, Math.min(1000000, Math.floor(Number(body.ataque) || 0))),
          defesa: Math.max(0, Math.min(1000000, Math.floor(Number(body.defesa) || 0))),
          mana: Math.max(0, Math.min(1000000, Math.floor(Number(body.mana) || 0))),
          manaMaxima: Math.max(0, Math.min(1000000, Math.floor(Number(body.manaMaxima) || 0))),
          agilidade: Math.max(0, Math.min(1000000, Math.floor(Number(body.agilidade) || 0))),
          poderMagico: Math.max(0, Math.min(1000000, Math.floor(Number(body.poderMagico) || 0))),
          imagemPersonagemUrl: typeof body.imagemPersonagemUrl === "string" &&
            /^https?:\/\//i.test(body.imagemPersonagemUrl)
            ? body.imagemPersonagemUrl.slice(0, 2048) : "",
          updatedAt: now
        };
        await this.ctx.storage.put(key, presence);
        return Response.json({
          accepted: acceptedX === x && acceptedY === y,
          presence
        });
      }

      if (request.method === "GET" && url.pathname === "/presence") {
        const worldPointId = url.searchParams.get("worldPointId") || "";
        if (!BETA_WORLD_POINT_IDS.has(worldPointId)) {
          return Response.json({ error: "INVALID_WORLD_POINT" }, { status: 400 });
        }
        const allPresence = await this.ctx.storage.list({ prefix: "presence:" });
        const now = Date.now();
        const players = [];
        for (const [key, presence] of allPresence) {
          if (now - (presence.updatedAt || 0) > 30000) {
            await this.ctx.storage.delete(key);
            continue;
          }
          if (presence.worldPointId === worldPointId) players.push(presence);
        }
        return Response.json({ players, serverEpochMillis: now });
      }

      if (request.method === "GET" && url.pathname === "/bestiary/stats-batch") {
        const ids = (url.searchParams.get("ids") || "").split(",").filter(Boolean);
        if (!ids.length || ids.length > 50 || ids.some((id) => !/^[A-Za-z0-9_-]{1,128}$/.test(id))) {
          return Response.json({ error: "INVALID_CREATURE_IDS" }, { status: 400 });
        }
        const stats = [];
        for (const creatureId of [...new Set(ids)]) {
          stats.push(await this.ctx.storage.get("bestiary:" + creatureId) || {
            creatureId, totalPlayersEncountered: 0, firstDiscovererUid: "",
            firstDiscovererName: "", firstDiscoveryAt: 0, totalDefeats: 0,
            firstDefeaterUid: "", firstDefeaterName: "", firstDefeatAt: 0,
            highestDamage: 0, highestDamageUid: "", highestDamageName: "",
            mostDefeatsUid: "", mostDefeatsName: "", mostDefeatsCount: 0
          });
        }
        return Response.json({ stats });
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
        let encounterToken = "";
        if (body.issueSoloToken !== false) {
          const activeTokenKey = "solo-encounter-active:" + creatureId + ":" + uid;
          const previousToken = await this.ctx.storage.get(activeTokenKey);
          const previousEncounter = previousToken
            ? await this.ctx.storage.get("solo-encounter:" + previousToken)
            : null;
          const now = Date.now();
          if (previousEncounter && !previousEncounter.used &&
              now - previousEncounter.issuedAt <= 12 * 60 * 60 * 1000) {
            encounterToken = previousToken;
          } else {
            if (previousToken) await this.ctx.storage.delete("solo-encounter:" + previousToken);
            encounterToken = crypto.randomUUID();
            await this.ctx.storage.put("solo-encounter:" + encounterToken, {
              creatureId, uid, issuedAt: now, used: false
            });
            await this.ctx.storage.put(activeTokenKey, encounterToken);
          }
        }
        return Response.json({ ...stats, encounterToken });
      }
      if (request.method === "POST" && url.pathname === "/bestiary/solo-defeat") {
        let body;
        try { body = await request.json(); } catch { return Response.json({ error: "INVALID_JSON" }, { status: 400 }); }
        const token = body?.encounterToken;
        const uid = body?.uid;
        if (typeof token !== "string" || typeof uid !== "string" || !uid) {
          return Response.json({ error: "INVALID_SOLO_ENCOUNTER" }, { status: 400 });
        }
        const encounterKey = "solo-encounter:" + token;
        const encounter = await this.ctx.storage.get(encounterKey);
        if (!encounter || encounter.uid !== uid || Date.now() - encounter.issuedAt > 12 * 60 * 60 * 1000) {
          return Response.json({ error: "SOLO_ENCOUNTER_NOT_VALID" }, { status: 403 });
        }
        if (encounter.used) {
          return Response.json({
            registered: false, duplicate: true,
            stats: await this.ctx.storage.get("bestiary:" + encounter.creatureId)
          });
        }
        const statsKey = "bestiary:" + encounter.creatureId;
        const stats = await this.ctx.storage.get(statsKey) || {
          creatureId: encounter.creatureId, totalPlayersEncountered: 0,
          firstDiscovererUid: "", firstDiscovererName: "", firstDiscoveryAt: 0,
          totalDefeats: 0, firstDefeaterUid: "", firstDefeaterName: "",
          firstDefeatAt: 0, highestDamage: 0, highestDamageUid: "",
          highestDamageName: "", mostDefeatsUid: "", mostDefeatsName: "",
          mostDefeatsCount: 0, playerDefeats: {}
        };
        const playerKey = "encounter:" + encounter.creatureId + ":" + uid;
        const player = await this.ctx.storage.get(playerKey);
        const playerName = player?.name || "Aventureiro";
        const damageDealt = Math.max(0, Math.min(1000000000, Number(body.damageDealt) || 0));
        stats.totalDefeats += 1;
        if (!stats.firstDefeaterUid) {
          stats.firstDefeaterUid = uid;
          stats.firstDefeaterName = playerName;
          stats.firstDefeatAt = Date.now();
        }
        if (damageDealt > stats.highestDamage) {
          stats.highestDamage = damageDealt;
          stats.highestDamageUid = uid;
          stats.highestDamageName = playerName;
        }
        const playerDefeatsKey = "bestiary-player-defeats:" + encounter.creatureId + ":" + uid;
        const playerDefeats = (await this.ctx.storage.get(playerDefeatsKey) || 0) + 1;
        await this.ctx.storage.put(playerDefeatsKey, playerDefeats);
        if (playerDefeats > (stats.mostDefeatsCount || 0)) {
          stats.mostDefeatsUid = uid;
          stats.mostDefeatsName = playerName;
          stats.mostDefeatsCount = playerDefeats;
        }
        stats.lastDefeatAt = Date.now();
        await this.ctx.storage.put(statsKey, stats);
        await this.ctx.storage.put(encounterKey, { ...encounter, used: true, usedAt: Date.now() });
        return Response.json({ registered: true, duplicate: false, stats });
      }
      if (request.method === "POST" && url.pathname === "/bestiary/defeat") {
        let body;
        try { body = await request.json(); } catch { return Response.json({ error: "INVALID_JSON" }, { status: 400 }); }
        const battle = body?.battle;
        const participants = Array.isArray(battle?.participantUids) ? battle.participantUids : [];
        const members = Array.isArray(battle?.members) ? battle.members : [];
        const participantSet = new Set(participants);
        const memberSet = new Set(members.map((member) => member?.uid));
        const validRoster = participants.length >= 1 && participants.length <= 4 &&
          participantSet.size === participants.length &&
          members.length === participants.length &&
          memberSet.size === members.length &&
          participants.every((uid) => typeof uid === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(uid) && memberSet.has(uid)) &&
          members.every((member) => Number.isSafeInteger(member.damageDealt) && member.damageDealt >= 0);
        const totalDamage = members.reduce((total, member) => total + member.damageDealt, 0);
        if (!battle || typeof battle.id !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(battle.id) ||
            typeof battle.creatureId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(battle.creatureId) ||
            !validRoster || typeof battle.activePlayerUid !== "string" ||
            !participantSet.has(battle.activePlayerUid) ||
            battle.status !== "FINISHED" || battle.phase !== "VICTORY" ||
            !Number.isSafeInteger(battle.enemyHp) || battle.enemyHp > 0 ||
            !Number.isSafeInteger(battle.enemyMaxHp) || battle.enemyMaxHp < 1 ||
            totalDamage < battle.enemyMaxHp) {
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
        // Cada participante que concluiu a batalha recebe crédito de uma derrota.
        // Os contadores individuais ficam em chaves separadas para evitar um mapa
        // crescente dentro do documento global da criatura.
        for (const member of members) {
          if (!member.uid) continue;
          const playerDefeatsKey = "bestiary-player-defeats:" + battle.creatureId + ":" + member.uid;
          const playerDefeats = (await this.ctx.storage.get(playerDefeatsKey) || 0) + 1;
          await this.ctx.storage.put(playerDefeatsKey, playerDefeats);
          if (playerDefeats > (stats.mostDefeatsCount || 0)) {
            stats.mostDefeatsUid = member.uid;
            stats.mostDefeatsName = member.name || "Aventureiro";
            stats.mostDefeatsCount = playerDefeats;
          }
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
          // Posição estável por espécie: todos os jogadores enxergam o mesmo ponto.
          let seed = 2166136261;
          for (const character of body.id) {
            seed ^= character.charCodeAt(0);
            seed = Math.imul(seed, 16777619);
          }
          const unsignedSeed = seed >>> 0;
          state.populations.push({
            speciesId: body.id, ecosystemId: body.ecosystemId,
            population: 1, danger: Math.max(1, Math.min(100, Number(body.danger) || 1)),
            rank: String(body.rank || "E"), evolvedRank: String(body.rank || "E"),
            spawnX: 0.16 + (unsignedSeed % 6800) / 10000,
            spawnY: 0.16 + ((unsignedSeed >>> 8) % 6800) / 10000,
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

    if (path === "/api/trades" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const parsed = await readJsonBodyLimited(request, 12000);
      if (!parsed.ok) {
        return jsonResponse({ error: parsed.tooLarge ? "REQUEST_TOO_LARGE" : "INVALID_JSON" }, parsed.tooLarge ? 413 : 400);
      }
      const result = await handleTradeAction(env, authentication.uid, parsed.value);
      return jsonResponse(result.body, result.status);
    }

    if (path === "/api/guilds" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const parsed = await readJsonBodyLimited(request, 6000);
      if (!parsed.ok) {
        return jsonResponse({ error: parsed.tooLarge ? "REQUEST_TOO_LARGE" : "INVALID_JSON" }, parsed.tooLarge ? 413 : 400);
      }
      const result = await handleGuildAction(env, authentication.uid, parsed.value);
      return jsonResponse(result.body, result.status);
    }

    if (path === "/api/multiplayer/expanded" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const parsed = await readJsonBodyLimited(request, 12000);
      if (!parsed.ok) {
        return jsonResponse({ error: parsed.tooLarge ? "REQUEST_TOO_LARGE" : "INVALID_JSON" }, parsed.tooLarge ? 413 : 400);
      }
      const result = await handleMultiplayerAction(env, authentication.uid, parsed.value);
      return jsonResponse(result.body, result.status);
    }

    if (path === "/api/characters/position" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const parsed = await readJsonBodyLimited(request, 2000);
      if (!parsed.ok) {
        return jsonResponse({ error: parsed.tooLarge ? "REQUEST_TOO_LARGE" : "INVALID_JSON" }, parsed.tooLarge ? 413 : 400);
      }
      const result = await handleCharacterPosition(env, authentication.uid, parsed.value);
      return jsonResponse(result.body, result.status);
    }

    if (path === "/api/security/admin-check" && method === "GET") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      if (!env.ADMIN_UID || authentication.uid !== env.ADMIN_UID) {
        return jsonResponse({ error: "FORBIDDEN" }, 403);
      }
      try {
        await getFirebaseAdminAccessToken(env);
        return jsonResponse({ ready: true, service: "firebase-admin-rest" });
      } catch {
        return jsonResponse({
          ready: false,
          error: "FIREBASE_ADMIN_NOT_READY",
          message: "As credenciais administrativas do Firebase ainda não estão configuradas ou não puderam ser validadas."
        }, 503);
      }
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

    if (path === "/api/world/creatures/placements" && method === "GET") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const ecosystemId = url.searchParams.get("ecosystemId") || "";
      if (!/^[A-Za-z0-9_-]{1,100}$/.test(ecosystemId)) {
        return jsonResponse({ error: "INVALID_ECOSYSTEM" }, 400);
      }
      const world = env.WORLD_STATE.get(env.WORLD_STATE.idFromName("ascensao-global-world"));
      const response = await world.fetch(
        "https://world/creature-placements?ecosystemId=" + encodeURIComponent(ecosystemId)
      );
      return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" } });
    }

    if (path === "/api/world/presence" && (method === "GET" || method === "POST")) {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) {
        return jsonResponse({ error: "UNAUTHORIZED", message: "Entre em uma conta válida para acessar a presença mundial." }, 401);
      }
      const world = env.WORLD_STATE.get(env.WORLD_STATE.idFromName("ascensao-global-world"));
      if (method === "GET") {
        const worldPointId = url.searchParams.get("worldPointId") || "";
        if (!BETA_WORLD_POINT_IDS.has(worldPointId)) {
          return jsonResponse({ error: "INVALID_WORLD_POINT" }, 400);
        }
        const response = await world.fetch("https://world/presence?worldPointId=" + encodeURIComponent(worldPointId));
        return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" } });
      }
      const parsed = await readJsonBodyLimited(request, 6000);
      if (!parsed.ok) return jsonResponse({ error: "INVALID_JSON" }, 400);
      const response = await world.fetch("https://world/presence", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...parsed.value, uid: authentication.uid })
      });
      return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" } });
    }

    if (path === "/api/world/npcs" && method === "GET") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const settlementId = url.searchParams.get("settlementId") || "";
      if (!BETA_WORLD_POINT_IDS.has(settlementId)) return jsonResponse({ error: "INVALID_SETTLEMENT" }, 400);
      const world = env.WORLD_STATE.get(env.WORLD_STATE.idFromName("ascensao-global-world"));
      const response = await world.fetch("https://world/npcs?settlementId=" + encodeURIComponent(settlementId) + "&uid=" + encodeURIComponent(authentication.uid));
      return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" } });
    }

    if (path === "/api/world/npcs/interact" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const parsed = await readJsonBodyLimited(request, 2000);
      if (!parsed.ok) return jsonResponse({ error: "INVALID_JSON" }, 400);
      const world = env.WORLD_STATE.get(env.WORLD_STATE.idFromName("ascensao-global-world"));
      const response = await world.fetch("https://world/npc/interact", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...parsed.value, uid: authentication.uid })
      });
      return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" } });
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
      const displayName = (authentication.displayName || parsed.value?.playerName || "Aventureiro").slice(0, 60);
      const issueSoloToken = parsed.value?.issueSoloToken !== false;
      const world = env.WORLD_STATE.get(env.WORLD_STATE.idFromName("ascensao-global-world"));
      const response = await world.fetch("https://world/bestiary/encounter", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ creatureId, uid: authentication.uid, playerName: displayName, issueSoloToken })
      });
      return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (path === "/api/bestiary/stats" && method === "GET") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const idsParameter = url.searchParams.get("ids");
      const world = env.WORLD_STATE.get(env.WORLD_STATE.idFromName("ascensao-global-world"));
      if (idsParameter) {
        const ids = idsParameter.split(",").filter(Boolean);
        if (!ids.length || ids.length > 50 || ids.some((id) => !/^[A-Za-z0-9_-]{1,128}$/.test(id))) {
          return jsonResponse({ error: "INVALID_CREATURE_IDS" }, 400);
        }
        const response = await world.fetch("https://world/bestiary/stats-batch?ids=" + encodeURIComponent(ids.join(",")));
        return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const creatureId = url.searchParams.get("id") || "";
      if (!/^[A-Za-z0-9_-]{1,128}$/.test(creatureId)) return jsonResponse({ error: "INVALID_CREATURE_ID" }, 400);
      const creature = await readFirestoreDocument(request, "criaturas", creatureId);
      if (!creature.ok) return jsonResponse({ error: "CREATURE_NOT_FOUND" }, 404);
      const response = await world.fetch("https://world/bestiary/stats?id=" + encodeURIComponent(creatureId));
      return new Response(response.body, { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (path === "/api/bestiary/solo-defeat" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED" }, 401);
      const parsed = await readJsonBodyLimited(request, 2000);
      if (!parsed.ok) return jsonResponse({ error: "INVALID_JSON" }, 400);
      const encounterToken = parsed.value?.encounterToken;
      if (typeof encounterToken !== "string" || !/^[A-Za-z0-9-]{20,80}$/.test(encounterToken)) {
        return jsonResponse({ error: "INVALID_SOLO_ENCOUNTER" }, 400);
      }
      const world = env.WORLD_STATE.get(env.WORLD_STATE.idFromName("ascensao-global-world"));
      const response = await world.fetch("https://world/bestiary/solo-defeat", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          encounterToken, uid: authentication.uid,
          damageDealt: Math.max(0, Math.min(1000000000, Number(parsed.value?.damageDealt) || 0))
        })
      });
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
      const creature = await readFirestoreDocument(request, "criaturas", verified.battle.creatureId);
      if (!creature.ok) return jsonResponse({ error: "CREATURE_NOT_FOUND", message: "A criatura não existe no catálogo oficial." }, 404);
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



    if (path === "/api/characters/skills/generate" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) {
        return jsonResponse({ error: "UNAUTHORIZED", message: "Entre na sua conta para criar as habilidades do personagem." }, 401);
      }
      if (!env.OPENAI_API_KEY) {
        return jsonResponse({ error: "AI_NOT_CONFIGURED", message: "A IA não está configurada. Nenhuma cobrança foi feita." }, 503);
      }
      if (!env.AI_BUDGET) {
        return jsonResponse({ error: "BUDGET_GUARD_UNAVAILABLE", message: "A proteção do orçamento está indisponível. Nenhuma geração foi iniciada." }, 503);
      }

      const parsed = await readJsonBodyLimited(request, 8000);
      if (!parsed.ok) return jsonResponse({ error: "INVALID_JSON", message: "Os dados da criação são inválidos." }, 400);
      const body = parsed.value || {};
      const textField = (value, max) => typeof value === "string" && value.trim().length > 0 && value.length <= max;
      const affinityKeys = ["PHYSICAL", "MAGIC", "AGILITY", "DEFENSE", "SUMMONING"];
      const validAffinityMap = body.affinities && affinityKeys.every((key) =>
        ["LOW", "MEDIUM", "HIGH"].includes(body.affinities[key])
      );
      const attributes = body.attributes || {};
      if (!textField(body.characterName, 60) || !textField(body.className, 80) ||
          !textField(body.classDescription, 800) || typeof body.isCustom !== "boolean" ||
          !validAffinityMap ||
          ["strength", "intelligence", "agility", "vitality", "spirit"].some((key) =>
            !Number.isInteger(attributes[key]) || attributes[key] < 0 || attributes[key] > 10000
          )) {
        return jsonResponse({ error: "INVALID_CHARACTER_CONCEPT", message: "O conceito ou os atributos do personagem são inválidos." }, 400);
      }

      const monthParts = new Intl.DateTimeFormat("en-US", {
        timeZone: "America/Sao_Paulo", year: "numeric", month: "2-digit"
      }).formatToParts(new Date());
      const monthYear = monthParts.find((part) => part.type === "year")?.value;
      const monthNumber = monthParts.find((part) => part.type === "month")?.value;
      const month = monthYear && monthNumber ? monthYear + "-" + monthNumber : null;
      if (!month) return jsonResponse({ error: "BUDGET_MONTH_UNAVAILABLE", message: "Não foi possível determinar o mês do orçamento." }, 503);

      const reservationId = "skills_" + crypto.randomUUID();
      const budgetStub = env.AI_BUDGET.get(env.AI_BUDGET.idFromName("ascensao-global-monthly-ai"));
      let reserve;
      try {
        reserve = await budgetStub.fetch("https://budget/reserve", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            month,
            action: "reserve",
            category: "characters",
            reservationId,
            reserveMicros: 10000,
            minimumReserveMicros: 10000
          })
        });
      } catch {
        return jsonResponse({ error: "BUDGET_GUARD_UNAVAILABLE", message: "Não foi possível reservar o limite de geração. Nenhuma chamada foi feita." }, 503);
      }
      if (reserve.status === 429) {
        return jsonResponse({ error: "CHARACTER_AI_BUDGET_REACHED", message: "O limite mensal de IA para personagens foi atingido. Nenhuma nova cobrança foi feita." }, 429);
      }
      if (!reserve.ok) {
        return jsonResponse({ error: "BUDGET_RESERVATION_FAILED", message: "Não foi possível confirmar o orçamento. Nenhuma chamada foi feita." }, 503);
      }

      return generateCharacterSkills(env, {
        characterName: body.characterName.trim(),
        className: body.className.trim(),
        classDescription: body.classDescription.trim(),
        isCustom: body.isCustom,
        affinities: body.affinities,
        attributes
      }, budgetStub, month, reservationId);
    }

    if (path === "/api/story/advance" && method === "POST") {
      const authentication = await verifyFirebaseToken(request);
      if (!authentication.valid) return jsonResponse({ error: "UNAUTHORIZED", message: "Entre em uma conta para continuar a campanha." }, 401);
      const parsed = await readJsonBodyLimited(request, 12000);
      if (!parsed.ok) return jsonResponse({ error: "INVALID_JSON", message: "O contexto da campanha é inválido." }, 400);
      const body = parsed.value || {};
      const allowedText = (value, max) => typeof value === "string" && value.length <= max;
      if (!allowedText(body.characterName, 60) || !allowedText(body.location, 100) ||
          !allowedText(body.region, 100) || !allowedText(body.action, 600) ||
          !allowedText(body.memorySummary || "", 1200) || !allowedText(body.previousScene || "", 2500) ||
          !Number.isInteger(body.level) || body.level < 1 || body.level > 10000 ||
          !Array.isArray(body.party) || body.party.length > 3 ||
          body.party.some((name) => typeof name !== "string" || name.length > 60)) {
        return jsonResponse({ error: "INVALID_STORY_CONTEXT", message: "Os dados do personagem ou da campanha são inválidos." }, 400);
      }
      if (!env.OPENAI_API_KEY) return jsonResponse({ error: "AI_NOT_CONFIGURED", message: "A IA ainda não está configurada. Nenhuma chamada foi feita." }, 503);
      let budgetResponse;
      try {
        const budgetId = env.AI_BUDGET.idFromName("ascensao-global-monthly-ai");
        const budgetStub = env.AI_BUDGET.get(budgetId);
        budgetResponse = await budgetStub.fetch("https://budget/reserve", {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ month: new Date().toISOString().slice(0, 7) })
        });
      } catch {
        return jsonResponse({ error: "BUDGET_GUARD_UNAVAILABLE", message: "A proteção de orçamento está indisponível. Nenhuma chamada foi feita." }, 503);
      }
      if (budgetResponse.status === 429) return jsonResponse({ error: "MONTHLY_AI_BUDGET_REACHED", message: "O limite mensal compartilhado de IA foi atingido. A campanha continua salva." }, 429);
      if (!budgetResponse.ok) return jsonResponse({ error: "BUDGET_GUARD_FAILED", message: "Não foi possível confirmar o limite mensal. Nenhuma chamada foi feita." }, 503);
      return generateStoryScene(env, {
        characterName: body.characterName.trim(), level: body.level,
        location: body.location.trim(), region: body.region.trim(),
        party: body.party, action: (body.action || "Continuar a história").trim(),
        memorySummary: body.memorySummary || "", previousScene: body.previousScene || "",
        campaignId: typeof body.campaignId === "string" ? body.campaignId.slice(0, 80) : ""
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
