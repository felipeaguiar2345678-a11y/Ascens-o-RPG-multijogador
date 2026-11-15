// Consulta de artes oficiais do catálogo global de equipamentos.
// A geração paga permanece desativada até aprovação explícita de preço e limite.
import { firestoreAdminGet, firestoreAdminCommit, encodeFirestoreFields } from "./firebase-admin.js";

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

/**
 * Resolve apenas arte já existente. Não chama provedor de IA, não reserva
 * orçamento e não publica caminhos fornecidos pelo cliente.
 */
export async function handleEquipmentImageResolution(request, env) {
  const body = await request.json().catch(() => null);
  if (!body || !validVisualId(body.visualId)) {
    return json({ error: "INVALID_EQUIPMENT_VISUAL_ID" }, 400);
  }
  if (!env.IMAGENS_R2) {
    return json({ error: "EQUIPMENT_IMAGE_STORAGE_NOT_CONFIGURED" }, 503);
  }

  let document;
  try {
    document = await firestoreAdminGet(env, "equipamentos_visuais", body.visualId);
  } catch {
    return json({ error: "EQUIPMENT_CATALOG_UNAVAILABLE" }, 503);
  }
  if (!document) {
    return json({ error: "EQUIPMENT_VISUAL_NOT_FOUND" }, 404);
  }

  const key = `equipamentos/${body.visualId}.png`;
  let object;
  try {
    object = await env.IMAGENS_R2.head(key);
  } catch {
    return json({ error: "EQUIPMENT_IMAGE_STORAGE_UNAVAILABLE" }, 503);
  }
  if (!object) {
    return json({
      status: "pending",
      visualId: body.visualId,
      generationEnabled: false,
      message: "A identidade visual já está registrada. A geração da arte permanece desativada até a aprovação do custo e do limite mensal."
    }, 202);
  }

  const url = imageUrl(request, body.visualId);
  const fields = document.fields || {};
  const existingUrl = fields.visualFrenteCaminho?.stringValue || "";
  if (existingUrl !== url) {
    try {
      await firestoreAdminCommit(env, [{
        update: {
          name: `projects/${env.FIREBASE_PROJECT_ID || "ascensao-do-soberano"}/databases/(default)/documents/equipamentos_visuais/${body.visualId}`,
          fields: encodeFirestoreFields({
            visualFrenteCaminho: url,
            visualCostasCaminho: url,
            visualLadoEsquerdoCaminho: url,
            visualLadoDireitoCaminho: url,
            status: "pronto",
            atualizadoEm: Date.now()
          })
        }
      }]);
    } catch {
      return json({ error: "EQUIPMENT_IMAGE_METADATA_PENDING", message: "A arte já existe, mas o catálogo está sincronizando. Tente novamente; nenhuma nova imagem será gerada." }, 503);
    }
  }

  return json({
    status: "already_generated",
    visualId: body.visualId,
    imageUrl: url,
    objectKey: key,
    sizeBytes: object.size,
    visualFrenteCaminho: url,
    visualCostasCaminho: url,
    visualLadoEsquerdoCaminho: url,
    visualLadoDireitoCaminho: url,
    actualBRL: 0
  });
}

export async function handleEquipmentImageRequest(request, env) {
  const url = new URL(request.url);
  const match = url.pathname.match(new RegExp("^/api/equipment/image/(equip_[a-f0-9]{64})$"));
  if (!match || !env.IMAGENS_R2) return new Response("Not found", { status: 404 });
  const object = await env.IMAGENS_R2.get(`equipamentos/${match[1]}.png`);
  if (!object) return new Response("Not found", { status: 404 });
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("Content-Type", "image/png");
  headers.set("Cache-Control", "public, max-age=31536000, immutable");
  headers.set("Access-Control-Allow-Origin", "*");
  return new Response(object.body, { headers });
}
