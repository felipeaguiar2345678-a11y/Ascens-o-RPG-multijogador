import {
  firestoreAdminBeginTransaction,
  firestoreAdminGetInTransaction,
  firestoreAdminCommitTransaction,
  decodeFirestoreFields,
  encodeFirestoreFields
} from "./firebase-admin.js";

export async function handleCharacterPosition(env, uid, input, fetchImpl = fetch) {
  if (typeof uid !== "string" || !uid || !input || typeof input !== "object" || Array.isArray(input)) {
    return { status: 400, body: { error: "CHARACTER_POSITION_INVALID" } };
  }
  const allowed = new Set(["characterId", "x", "y", "worldPointId", "respawnPointId"]);
  if (Object.keys(input).some(key => !allowed.has(key)) ||
      typeof input.characterId !== "string" ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(input.characterId) ||
      typeof input.x !== "number" || !Number.isFinite(input.x) ||
      typeof input.y !== "number" || !Number.isFinite(input.y) ||
      input.x < -100 || input.x > 100 || input.y < -100 || input.y > 100 ||
      (input.worldPointId !== undefined &&
        (typeof input.worldPointId !== "string" || !/^[a-z0-9_-]{1,100}$/.test(input.worldPointId))) ||
      (input.respawnPointId !== undefined &&
        (typeof input.respawnPointId !== "string" || !/^[a-z0-9_-]{1,100}$/.test(input.respawnPointId)))) {
    return { status: 400, body: { error: "CHARACTER_POSITION_INVALID" } };
  }

  try {
    const transaction = await firestoreAdminBeginTransaction(env, fetchImpl);
    const document = await firestoreAdminGetInTransaction(
      env, "characters", input.characterId, transaction, fetchImpl
    );
    if (!document) {
      return { status: 404, body: { error: "CHARACTER_NOT_FOUND" } };
    }
    const data = decodeFirestoreFields(document.fields || {});
    if (data.ownerUid !== uid) {
      return { status: 403, body: { error: "CHARACTER_FORBIDDEN" } };
    }

    const updates = { worldX: input.x, worldY: input.y };
    const fieldPaths = ["worldX", "worldY"];
    if (input.worldPointId !== undefined) {
      updates.currentWorldPointId = input.worldPointId;
      fieldPaths.push("currentWorldPointId");
    }
    if (input.respawnPointId !== undefined) {
      updates.respawnPointId = input.respawnPointId;
      fieldPaths.push("respawnPointId");
    }
    await firestoreAdminCommitTransaction(env, transaction, [{
      update: {
        name: document.name,
        fields: encodeFirestoreFields(updates)
      },
      updateMask: { fieldPaths }
    }], fetchImpl);
    return { status: 200, body: { saved: true } };
  } catch (error) {
    const code = String(error?.message || "");
    if (code.includes("FIREBASE_ADMIN_NOT_CONFIGURED") ||
        code.includes("FIREBASE_ADMIN_TOKEN") ||
        code.includes("FIRESTORE_ADMIN_") ||
        code.includes("FIRESTORE_TRANSACTION_")) {
      return { status: 503, body: { error: "SERVER_STORAGE_NOT_READY" } };
    }
    return { status: 500, body: { error: "CHARACTER_POSITION_SAVE_FAILED" } };
  }
}
