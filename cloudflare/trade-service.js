import {
  decodeFirestoreFields,
  encodeFirestoreFields,
  firestoreAdminBeginTransaction,
  firestoreAdminGetInTransaction,
  firestoreAdminRunQuery,
  firestoreAdminCommitTransaction
} from "./firebase-admin.js";

const emptyOffer = () => ({ itens: [], ovos: [], equipamentos: [] });
const validId = value => typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const documentPath = (projectId, collection, id) =>
  `projects/${projectId}/databases/(default)/documents/${collection}/${id}`;

function asDocumentData(document) {
  if (!document || !document.fields) return null;
  return decodeFirestoreFields(document.fields);
}

export function validateTradeOffer(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new Error("OFERTA_INVALIDA");
  }
  if (Object.keys(raw).some(key => !["itens", "ovos", "equipamentos"].includes(key))) {
    throw new Error("OFERTA_CAMPO_PROIBIDO");
  }
  const rawItems = Array.isArray(raw.itens) ? raw.itens : [];
  const eggs = Array.isArray(raw.ovos) ? raw.ovos : [];
  const equipment = Array.isArray(raw.equipamentos) ? raw.equipamentos : [];
  if (rawItems.length + eggs.length + equipment.length > 40) {
    throw new Error("OFERTA_LIMITE_EXCEDIDO");
  }
  const items = rawItems.map(item => {
    if (!item || !validId(item.id) || !Number.isSafeInteger(item.quantidade) ||
        item.quantidade < 1 || item.quantidade > 100000) {
      throw new Error("ITEM_OFERTA_INVALIDO");
    }
    return { id: item.id, quantidade: item.quantidade };
  });
  if (![...eggs, ...equipment].every(validId)) throw new Error("OBJETO_OFERTA_INVALIDO");
  if (new Set(items.map(item => item.id)).size !== items.length ||
      new Set(eggs).size !== eggs.length ||
      new Set(equipment).size !== equipment.length) {
    throw new Error("OBJETO_OFERTA_DUPLICADO");
  }
  return { itens: items, ovos: [...eggs], equipamentos: [...equipment] };
}

function loadoutContainsEquipment(value, equipmentId) {
  if (value === equipmentId) return true;
  if (Array.isArray(value)) return value.some(item => loadoutContainsEquipment(item, equipmentId));
  if (!value || typeof value !== "object") return false;
  if (value.id === equipmentId) return true;
  return Object.values(value).some(item => loadoutContainsEquipment(item, equipmentId));
}

export function validateTradePossessions(inventory, offer, equipmentLoadout = {}) {
  const items = Array.isArray(inventory?.items) ? inventory.items : [];
  const eggs = Array.isArray(inventory?.eggs) ? inventory.eggs : [];
  const equipment = Array.isArray(inventory?.equipment) ? inventory.equipment : [];
  for (const requested of offer.itens) {
    const matches = items.filter(item => item?.id === requested.id);
    if (matches.length !== 1 || !Number.isSafeInteger(matches[0].quantity) ||
        matches[0].quantity < requested.quantidade) {
      throw new Error("ITEM_NAO_PERTENCE_AO_JOGADOR");
    }
    const item = matches[0];
    const normalize = value => String(value ?? "").normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "").toUpperCase();
    if (["XP", "EXPERIENCIA", "EXPERIENCE"].includes(normalize(item.type)) ||
        ["XP", "EXPERIENCIA", "EXPERIENCE"].includes(normalize(item.name)) ||
        normalize(item.id) === "XP") {
      throw new Error("XP_NAO_NEGOCIAVEL");
    }
  }
  for (const id of offer.ovos) {
    if (eggs.filter(item => item?.id === id).length !== 1) {
      throw new Error("OVO_NAO_PERTENCE_AO_JOGADOR");
    }
  }
  for (const id of offer.equipamentos) {
    if (equipment.filter(item => item?.id === id).length !== 1) {
      throw new Error("EQUIPAMENTO_NAO_PERTENCE_AO_JOGADOR");
    }
    if (loadoutContainsEquipment(equipmentLoadout, id)) {
      throw new Error("EQUIPAMENTO_EQUIPADO");
    }
  }
}

function sameItemIdentity(a, b) {
  return [
    "name", "description", "type", "imagemIconeCaminho", "imagemDetalhadaCaminho",
    "materialRank", "materialOrigin", "sourceCreatureId"
  ].every(key => String(a?.[key] ?? "") === String(b?.[key] ?? "")) &&
    JSON.stringify(a?.materialTraits ?? []) === JSON.stringify(b?.materialTraits ?? []);
}

export function transferTradeInventory(sourceInventory, targetInventory, offer) {
  const source = { ...(sourceInventory || {}) };
  const target = { ...(targetInventory || {}) };
  const sourceItems = Array.isArray(source.items) ? [...source.items] : [];
  const targetItems = Array.isArray(target.items) ? [...target.items] : [];
  for (const requested of offer.itens) {
    const matches = sourceItems.map((item, index) => ({ item, index }))
      .filter(entry => entry.item?.id === requested.id);
    if (matches.length !== 1 || !Number.isSafeInteger(matches[0].item.quantity) ||
        matches[0].item.quantity < requested.quantidade) {
      throw new Error("INVENTARIO_ALTERADO");
    }
    const { item, index } = matches[0];
    if (item.quantity === requested.quantidade) sourceItems.splice(index, 1);
    else sourceItems[index] = { ...item, quantity: item.quantity - requested.quantidade };
    const targetMatches = targetItems.map((entry, targetIndex) => ({ entry, targetIndex }))
      .filter(value => value.entry?.id === requested.id);
    if (targetMatches.length > 1) throw new Error("INVENTARIO_DESTINO_DUPLICADO");
    if (targetMatches.length === 1) {
      const current = targetMatches[0].entry;
      if (!sameItemIdentity(current, item) || current.quantity + requested.quantidade > 1000000000) {
        throw new Error("ITEM_DESTINO_INCOMPATIVEL");
      }
      targetItems[targetMatches[0].targetIndex] = {
        ...current,
        quantity: current.quantity + requested.quantidade
      };
    } else {
      targetItems.push({ ...item, quantity: requested.quantidade });
    }
  }
  const sourceEggs = Array.isArray(source.eggs) ? [...source.eggs] : [];
  const targetEggs = Array.isArray(target.eggs) ? [...target.eggs] : [];
  for (const id of offer.ovos) {
    const index = sourceEggs.findIndex(item => item?.id === id);
    if (index < 0 || targetEggs.some(item => item?.id === id)) throw new Error("OVO_TRANSFERENCIA_INVALIDA");
    targetEggs.push(sourceEggs.splice(index, 1)[0]);
  }
  const sourceEquipment = Array.isArray(source.equipment) ? [...source.equipment] : [];
  const targetEquipment = Array.isArray(target.equipment) ? [...target.equipment] : [];
  for (const id of offer.equipamentos) {
    const index = sourceEquipment.findIndex(item => item?.id === id);
    if (index < 0 || targetEquipment.some(item => item?.id === id)) {
      throw new Error("EQUIPAMENTO_TRANSFERENCIA_INVALIDA");
    }
    targetEquipment.push(sourceEquipment.splice(index, 1)[0]);
  }
  return {
    source: { ...source, items: sourceItems, eggs: sourceEggs, equipment: sourceEquipment },
    target: { ...target, items: targetItems, eggs: targetEggs, equipment: targetEquipment }
  };
}

async function getCharacter(env, uid, transaction, fetchImpl) {
  const result = await firestoreAdminRunQuery(
    env, "characters", "ownerUid", uid, transaction, fetchImpl
  );
  if (!result?.name || !result.data || result.data.ownerUid !== uid) return null;
  return { name: result.name, data: result.data };
}

async function readTrade(env, tradeId, transaction, fetchImpl) {
  const raw = await firestoreAdminGetInTransaction(
    env, "trades", tradeId, transaction, fetchImpl
  );
  if (!raw) return null;
  return { name: raw.name, data: asDocumentData(raw) };
}

function updateWrite(name, data, fieldPaths = null) {
  const write = { update: { name, fields: encodeFirestoreFields(data) } };
  if (fieldPaths) write.updateMask = { fieldPaths };
  return write;
}

export async function handleTradeAction(env, uid, input, fetchImpl = fetch) {
  if (!validId(uid)) return { status: 401, body: { error: "UNAUTHORIZED" } };
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    return { status: 400, body: { error: "INVALID_REQUEST" } };
  }
  const action = input.acao;
  if (!["criar", "ofertar", "aceitar", "cancelar"].includes(action)) {
    return { status: 400, body: { error: "INVALID_ACTION" } };
  }
  const projectId = env.FIREBASE_PROJECT_ID || "ascensao-do-soberano";

  try {
    if (action === "criar") {
      const recipientUid = input.destinatarioUid;
      if (!validId(recipientUid) || recipientUid === uid) {
        return { status: 400, body: { error: "INVALID_RECIPIENT" } };
      }
      const transaction = await firestoreAdminBeginTransaction(env, fetchImpl);
      const [sender, recipient] = await Promise.all([
        getCharacter(env, uid, transaction, fetchImpl),
        getCharacter(env, recipientUid, transaction, fetchImpl)
      ]);
      if (!sender || !recipient) return { status: 404, body: { error: "CHARACTER_NOT_FOUND" } };
      if (sender.name === recipient.name) return { status: 409, body: { error: "SAME_CHARACTER" } };
      const tradeId = crypto.randomUUID();
      const name = documentPath(projectId, "trades", tradeId);
      const now = new Date().toISOString();
      const data = {
        remetenteUid: uid,
        destinatarioUid: recipientUid,
        status: "PENDENTE",
        ofertas: { [uid]: emptyOffer(), [recipientUid]: emptyOffer() },
        aceitoPor: [],
        criadoEm: now,
        atualizadoEm: now
      };
      await firestoreAdminCommitTransaction(env, transaction, [{
        update: { name, fields: encodeFirestoreFields(data) },
        currentDocument: { exists: false }
      }], fetchImpl);
      return { status: 200, body: { trocaId: tradeId, status: "PENDENTE" } };
    }

    const tradeId = input.trocaId;
    if (!validId(tradeId)) return { status: 400, body: { error: "INVALID_TRADE_ID" } };
    const transaction = await firestoreAdminBeginTransaction(env, fetchImpl);
    const trade = await readTrade(env, tradeId, transaction, fetchImpl);
    if (!trade) return { status: 404, body: { error: "TRADE_NOT_FOUND" } };
    const data = trade.data;
    const participants = [data.remetenteUid, data.destinatarioUid];
    if (!participants.includes(uid)) return { status: 403, body: { error: "NOT_A_PARTICIPANT" } };
    if (data.status !== "PENDENTE") return { status: 409, body: { error: "TRADE_NOT_PENDING" } };
    const now = new Date().toISOString();

    if (action === "cancelar") {
      await firestoreAdminCommitTransaction(env, transaction, [updateWrite(trade.name, {
        ...data, status: "CANCELADA", canceladaPor: uid, atualizadoEm: now
      })], fetchImpl);
      return { status: 200, body: { status: "CANCELADA" } };
    }

    if (action === "ofertar") {
      const offer = validateTradeOffer(input.oferta);
      const character = await getCharacter(env, uid, transaction, fetchImpl);
      if (!character) return { status: 404, body: { error: "CHARACTER_NOT_FOUND" } };
      validateTradePossessions(character.data.inventory || {}, offer, character.data.equipmentLoadout || {});
      const offers = { ...(data.ofertas || {}), [uid]: offer };
      await firestoreAdminCommitTransaction(env, transaction, [updateWrite(trade.name, {
        ...data, ofertas: offers, aceitoPor: [], atualizadoEm: now
      })], fetchImpl);
      return { status: 200, body: { status: "OFERTA_ATUALIZADA" } };
    }

    const accepted = Array.isArray(data.aceitoPor) ? data.aceitoPor : [];
    if (accepted.includes(uid)) return { status: 409, body: { error: "ALREADY_ACCEPTED" } };
    const nextAccepted = [...accepted, uid];
    if (nextAccepted.length < 2) {
      await firestoreAdminCommitTransaction(env, transaction, [updateWrite(trade.name, {
        ...data, aceitoPor: nextAccepted, atualizadoEm: now
      })], fetchImpl);
      return { status: 200, body: { status: "ACEITE_REGISTRADO" } };
    }

    const [sender, recipient] = await Promise.all([
      getCharacter(env, data.remetenteUid, transaction, fetchImpl),
      getCharacter(env, data.destinatarioUid, transaction, fetchImpl)
    ]);
    if (!sender || !recipient) return { status: 404, body: { error: "CHARACTER_NOT_FOUND" } };
    const offers = data.ofertas || {};
    const senderOffer = validateTradeOffer(offers[data.remetenteUid] || emptyOffer());
    const recipientOffer = validateTradeOffer(offers[data.destinatarioUid] || emptyOffer());
    if (senderOffer.itens.length + senderOffer.ovos.length + senderOffer.equipamentos.length +
        recipientOffer.itens.length + recipientOffer.ovos.length + recipientOffer.equipamentos.length === 0) {
      return { status: 409, body: { error: "EMPTY_TRADE" } };
    }
    validateTradePossessions(sender.data.inventory || {}, senderOffer, sender.data.equipmentLoadout || {});
    validateTradePossessions(recipient.data.inventory || {}, recipientOffer, recipient.data.equipmentLoadout || {});
    const recipientToSender = transferTradeInventory(
      recipient.data.inventory || {}, sender.data.inventory || {}, recipientOffer
    );
    const senderToRecipient = transferTradeInventory(
      recipientToSender.target, recipientToSender.source, senderOffer
    );
    await firestoreAdminCommitTransaction(env, transaction, [
      updateWrite(sender.name, { inventory: senderToRecipient.source }, ["inventory"]),
      updateWrite(recipient.name, { inventory: senderToRecipient.target }, ["inventory"]),
      updateWrite(trade.name, {
        ...data, status: "CONCLUIDA", aceitoPor: nextAccepted,
        concluidaEm: now, atualizadoEm: now
      })
    ], fetchImpl);
    return { status: 200, body: { status: "TROCA_CONCLUIDA" } };
  } catch (error) {
    const code = error?.message || "TRADE_SERVER_ERROR";
    const clientErrors = new Set([
      "OFERTA_INVALIDA", "OFERTA_CAMPO_PROIBIDO", "OFERTA_LIMITE_EXCEDIDO",
      "ITEM_OFERTA_INVALIDO", "OBJETO_OFERTA_INVALIDO", "OBJETO_OFERTA_DUPLICADO",
      "ITEM_NAO_PERTENCE_AO_JOGADOR", "XP_NAO_NEGOCIAVEL",
      "OVO_NAO_PERTENCE_AO_JOGADOR", "EQUIPAMENTO_NAO_PERTENCE_AO_JOGADOR", "EQUIPAMENTO_EQUIPADO",
      "INVENTARIO_ALTERADO", "INVENTARIO_DESTINO_DUPLICADO",
      "ITEM_DESTINO_INCOMPATIVEL", "OVO_TRANSFERENCIA_INVALIDA",
      "EQUIPAMENTO_TRANSFERENCIA_INVALIDA"
    ]);
    return {
      status: clientErrors.has(code) ? 400 : 503,
      body: { error: clientErrors.has(code) ? code : "TRADE_SERVER_UNAVAILABLE" }
    };
  }
}
