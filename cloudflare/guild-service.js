import {
  decodeFirestoreFields,
  encodeFirestoreFields,
  firestoreAdminBeginTransaction,
  firestoreAdminGetInTransaction,
  firestoreAdminRunQuery,
  firestoreAdminCommitTransaction
} from "./firebase-admin.js";

const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const validUid = value => typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const docName = (projectId, collection, id) =>
  `projects/${projectId}/databases/(default)/documents/${collection}/${id}`;
const nowIso = () => new Date().toISOString();

function newGuildCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, byte => CODE_ALPHABET[byte % CODE_ALPHABET.length]).join("");
}

function readData(document) {
  return document?.fields ? decodeFirestoreFields(document.fields) : null;
}

function updateWrite(name, data, fieldPaths) {
  return {
    update: { name, fields: encodeFirestoreFields(data) },
    updateMask: { fieldPaths }
  };
}

function createWrite(name, data) {
  return {
    update: { name, fields: encodeFirestoreFields(data) },
    currentDocument: { exists: false }
  };
}

function deleteWrite(name) {
  return { delete: name };
}

export async function handleGuildAction(env, uid, input, fetchImpl = fetch) {
  if (!validUid(uid)) return { status: 401, body: { error: "UNAUTHORIZED" } };
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    return { status: 400, body: { error: "INVALID_REQUEST" } };
  }

  const action = input.acao;
  if (!["criar", "entrar", "sair"].includes(action)) {
    return { status: 400, body: { error: "INVALID_ACTION" } };
  }

  const projectId = env.FIREBASE_PROJECT_ID || "ascensao-do-soberano";
  const membershipName = docName(projectId, "guildMembership", uid);

  try {
    if (action === "criar") {
      const name = typeof input.nome === "string" ? input.nome.trim() : "";
      const playerName = typeof input.nomeJogador === "string"
        ? input.nomeJogador.trim().slice(0, 32) : "Aventureiro";
      if (name.length < 3 || name.length > 24) {
        return { status: 400, body: { error: "INVALID_GUILD_NAME" } };
      }

      let code = "";
      let available = false;
      for (let attempt = 0; attempt < 8; attempt++) {
        code = newGuildCode();
        const existing = await firestoreAdminRunQuery(
          env, "guilds", "inviteCode", code, null, fetchImpl
        );
        if (!existing) { available = true; break; }
      }
      if (!available) return { status: 503, body: { error: "GUILD_CODE_GENERATION_FAILED" } };

      const guildId = crypto.randomUUID();
      const guildName = docName(projectId, "guilds", guildId);
      const leaderboardName = docName(projectId, "leaderboards", "guildas") + "/entries/" + guildId;
      const transaction = await firestoreAdminBeginTransaction(env, fetchImpl);
      const membership = await firestoreAdminGetInTransaction(
        env, "guildMembership", uid, transaction, fetchImpl
      );
      if (membership) return { status: 409, body: { error: "ALREADY_IN_GUILD" } };

      const now = nowIso();
      await firestoreAdminCommitTransaction(env, transaction, [
        createWrite(guildName, {
          name, inviteCode: code, leaderUid: uid, members: [uid],
          memberNames: { [uid]: playerName }, createdAt: now, updatedAt: now,
          level: 1, experience: 0, campLevel: 1, campExperience: 0
        }),
        createWrite(membershipName, { guildId, joinedAt: now }),
        updateWrite(leaderboardName, {
          uid: guildId, nome: name, score: 1, atualizadoEm: now
        }, ["uid", "nome", "score", "atualizadoEm"])
      ], fetchImpl);
      return { status: 200, body: { guildaId: guildId, codigo: code } };
    }

    if (action === "entrar") {
      const code = typeof input.codigo === "string" ? input.codigo.trim().toUpperCase() : "";
      const playerName = typeof input.nomeJogador === "string"
        ? input.nomeJogador.trim().slice(0, 32) : "Aventureiro";
      if (!/^[A-HJ-NP-Z2-9]{6}$/.test(code)) {
        return { status: 400, body: { error: "INVALID_GUILD_CODE" } };
      }
      const found = await firestoreAdminRunQuery(env, "guilds", "inviteCode", code, null, fetchImpl);
      if (!found?.name) return { status: 404, body: { error: "GUILD_NOT_FOUND" } };
      const guildId = found.name.split("/").pop();
      if (!validUid(guildId)) return { status: 404, body: { error: "GUILD_NOT_FOUND" } };

      const transaction = await firestoreAdminBeginTransaction(env, fetchImpl);
      const [membership, guildDocument] = await Promise.all([
        firestoreAdminGetInTransaction(env, "guildMembership", uid, transaction, fetchImpl),
        firestoreAdminGetInTransaction(env, "guilds", guildId, transaction, fetchImpl)
      ]);
      if (membership) return { status: 409, body: { error: "ALREADY_IN_GUILD" } };
      const guild = readData(guildDocument);
      if (!guild) return { status: 404, body: { error: "GUILD_NOT_FOUND" } };
      const members = Array.isArray(guild.members) ? guild.members : [];
      if (members.length >= 30) return { status: 409, body: { error: "GUILD_FULL" } };
      if (members.includes(uid)) return { status: 409, body: { error: "ALREADY_IN_GUILD" } };

      const names = { ...(guild.memberNames || {}), [uid]: playerName };
      const nextMembers = [...members, uid];
      const now = nowIso();
      const leaderboardName = docName(projectId, "leaderboards", "guildas") + "/entries/" + guildId;
      await firestoreAdminCommitTransaction(env, transaction, [
        updateWrite(guildDocument.name, {
          members: nextMembers, memberNames: names, updatedAt: now
        }, ["members", "memberNames", "updatedAt"]),
        createWrite(membershipName, { guildId, joinedAt: now }),
        updateWrite(leaderboardName, {
          uid: guildId, nome: guild.name || "Guilda",
          score: nextMembers.length, atualizadoEm: now
        }, ["uid", "nome", "score", "atualizadoEm"])
      ], fetchImpl);
      return { status: 200, body: { guildaId: guildId } };
    }

    const transaction = await firestoreAdminBeginTransaction(env, fetchImpl);
    const membershipDocument = await firestoreAdminGetInTransaction(
      env, "guildMembership", uid, transaction, fetchImpl
    );
    const membershipData = readData(membershipDocument);
    if (!membershipData) return { status: 409, body: { error: "NOT_IN_GUILD" } };
    const guildId = membershipData.guildId;
    if (!validUid(guildId)) return { status: 409, body: { error: "INVALID_GUILD_MEMBERSHIP" } };
    const guildDocument = await firestoreAdminGetInTransaction(
      env, "guilds", guildId, transaction, fetchImpl
    );
    const guild = readData(guildDocument);
    const writes = [deleteWrite(membershipName)];
    const now = nowIso();

    if (!guild) {
      await firestoreAdminCommitTransaction(env, transaction, writes, fetchImpl);
      return { status: 200, body: { status: "SAIU" } };
    }

    const members = Array.isArray(guild.members) ? guild.members : [];
    const remaining = members.filter(member => member !== uid);
    const names = { ...(guild.memberNames || {}) };
    delete names[uid];
    const leaderboardName = docName(projectId, "leaderboards", "guildas") + "/entries/" + guildId;

    if (remaining.length === 0) {
      writes.push(deleteWrite(guildDocument.name), deleteWrite(leaderboardName));
    } else {
      writes.push(updateWrite(guildDocument.name, {
        members: remaining, memberNames: names,
        leaderUid: guild.leaderUid === uid ? remaining[0] : guild.leaderUid,
        updatedAt: now
      }, ["members", "memberNames", "leaderUid", "updatedAt"]));
      writes.push(updateWrite(leaderboardName, {
        uid: guildId, nome: guild.name || "Guilda",
        score: remaining.length, atualizadoEm: now
      }, ["uid", "nome", "score", "atualizadoEm"]));
    }

    await firestoreAdminCommitTransaction(env, transaction, writes, fetchImpl);
    return { status: 200, body: { status: "SAIU" } };
  } catch (error) {
    const code = String(error?.message || "GUILD_SERVER_ERROR");
    if (code.includes("FIREBASE_ADMIN_NOT_CONFIGURED") ||
        code.includes("FIREBASE_ADMIN_TOKEN") ||
        code.includes("FIRESTORE_ADMIN_") ||
        code.includes("FIRESTORE_TRANSACTION_")) {
      return { status: 503, body: { error: "GUILD_SERVER_UNAVAILABLE" } };
    }
    return { status: 500, body: { error: "GUILD_SERVER_ERROR" } };
  }
}
