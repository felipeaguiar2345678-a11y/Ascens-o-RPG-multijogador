import test from "node:test";
import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import {
  getFirebaseAdminAccessToken,
  firestoreAdminGet,
  firestoreAdminCommit,
  firestoreAdminBeginTransaction,
  firestoreAdminGetInTransaction,
  firestoreAdminCommitTransaction
} from "./firebase-admin.js";

globalThis.crypto ||= webcrypto;

test("Firebase Admin falha fechado quando as credenciais não estão configuradas", async () => {
  await assert.rejects(
    () => getFirebaseAdminAccessToken({}),
    /FIREBASE_ADMIN_NOT_CONFIGURED/
  );
});

test("Firebase Admin assina JWT e troca por token OAuth sem expor a chave", async () => {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"]
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let pemBinary = "";
  for (const byte of pkcs8) pemBinary += String.fromCharCode(byte);
  const pem = "-----BEGIN PRIVATE KEY-----\n" +
    btoa(pemBinary).match(/.{1,64}/g).join("\n") +
    "\n-----END PRIVATE KEY-----";
  let calls = 0;
  const token = await getFirebaseAdminAccessToken({
    FIREBASE_SERVICE_ACCOUNT_EMAIL: "worker@ascensao-do-soberano.iam.gserviceaccount.com",
    FIREBASE_PRIVATE_KEY: pem,
    FIREBASE_PROJECT_ID: "ascensao-do-soberano"
  }, async (url, options) => {
    calls++;
    assert.equal(url, "https://oauth2.googleapis.com/token");
    assert.equal(options.method, "POST");
    const params = new URLSearchParams(options.body);
    assert.equal(params.get("grant_type"), "urn:ietf:params:oauth:grant-type:jwt-bearer");
    const jwt = params.get("assertion").split(".");
    assert.equal(jwt.length, 3);
    const header = JSON.parse(atob(jwt[0].replace(/-/g, "+").replace(/_/g, "/")));
    const claims = JSON.parse(atob(jwt[1].replace(/-/g, "+").replace(/_/g, "/")));
    assert.equal(header.alg, "RS256");
    assert.equal(claims.iss, "worker@ascensao-do-soberano.iam.gserviceaccount.com");
    assert.equal(claims.scope, "https://www.googleapis.com/auth/datastore");
    const valid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5", pair.publicKey,
      Uint8Array.from(atob(jwt[2].replace(/-/g, "+").replace(/_/g, "/") + "=="), c => c.charCodeAt(0)),
      new TextEncoder().encode(jwt[0] + "." + jwt[1])
    );
    assert.equal(valid, true);
    return Response.json({ access_token: "token-teste", expires_in: 3600 });
  });
  assert.equal(token, "token-teste");
  assert.equal(calls, 1);
});

test("Firestore Admin valida caminho de documento antes de fazer requisição", async () => {
  await assert.rejects(
    () => firestoreAdminGet({}, "../characters", "uid"),
    /FIRESTORE_DOCUMENT_PATH_INVALID/
  );
});

test("Firestore Admin limita lote de gravações", async () => {
  await assert.rejects(
    () => firestoreAdminCommit({}, []),
    /FIRESTORE_WRITE_BATCH_INVALID/
  );
});

test("Firebase Admin rejeita identificador de projeto inválido", async () => {
  await assert.rejects(
    () => getFirebaseAdminAccessToken({
      FIREBASE_SERVICE_ACCOUNT_EMAIL: "worker@ascensao-do-soberano.iam.gserviceaccount.com",
      FIREBASE_PRIVATE_KEY: "chave",
      FIREBASE_PROJECT_ID: "../projeto"
    }),
    /FIREBASE_ADMIN_NOT_CONFIGURED/
  );
});

test("Firebase Admin não aceita resposta OAuth sem token válido", async () => {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"]
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let binary = "";
  for (const byte of pkcs8) binary += String.fromCharCode(byte);
  const pem = "-----BEGIN PRIVATE KEY-----\\n" +
    btoa(binary).match(/.{1,64}/g).join("\\n") +
    "\\n-----END PRIVATE KEY-----";
  await assert.rejects(
    () => getFirebaseAdminAccessToken({
      FIREBASE_SERVICE_ACCOUNT_EMAIL: "worker-invalid@ascensao-do-soberano.iam.gserviceaccount.com",
      FIREBASE_PRIVATE_KEY: pem
    }, async () => Response.json({ access_token: "", expires_in: 3600 })),
    /FIREBASE_ADMIN_TOKEN_RESPONSE_INVALID/
  );
});

test("Firestore Admin executa leitura e gravação dentro de transação", async () => {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"]
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let binary = "";
  for (const byte of pkcs8) binary += String.fromCharCode(byte);
  const pem = "-----BEGIN PRIVATE KEY-----\\n" +
    btoa(binary).match(/.{1,64}/g).join("\\n") +
    "\\n-----END PRIVATE KEY-----";
  const env = {
    FIREBASE_SERVICE_ACCOUNT_EMAIL: "worker-transaction@ascensao-do-soberano.iam.gserviceaccount.com",
    FIREBASE_PRIVATE_KEY: pem,
    FIREBASE_PROJECT_ID: "ascensao-do-soberano"
  };
  const calls = [];
  const fetchMock = async (url, options = {}) => {
    calls.push({ url: String(url), options });
    if (String(url) === "https://oauth2.googleapis.com/token") {
      return Response.json({ access_token: "token-transacao", expires_in: 3600 });
    }
    if (String(url).endsWith(":beginTransaction")) {
      return Response.json({ transaction: "transacao-de-teste-123" });
    }
    if (String(url).includes("?transaction=")) {
      return Response.json({ name: "projects/ascensao-do-soberano/databases/(default)/documents/characters/player1" });
    }
    if (String(url).endsWith(":commit")) return Response.json({ writeResults: [{}] });
    throw new Error("URL inesperada");
  };
  const transaction = await firestoreAdminBeginTransaction(env, fetchMock);
  assert.equal(transaction, "transacao-de-teste-123");
  const document = await firestoreAdminGetInTransaction(env, "characters", "player1", transaction, fetchMock);
  assert.match(document.name, /characters\/player1$/);
  await firestoreAdminCommitTransaction(env, transaction, [{ delete: "projects/ascensao-do-soberano/databases/(default)/documents/test/doc" }], fetchMock);
  assert.equal(calls.length, 4);
  assert.ok(calls.slice(1).every(call => call.options.headers.Authorization === "Bearer token-transacao"));
});

test("Firestore Admin transacional rejeita caminhos e transações inválidas", async () => {
  await assert.rejects(
    () => firestoreAdminGetInTransaction({}, "../characters", "uid", "transaction-valid"),
    /FIRESTORE_TRANSACTION_READ_INVALID/
  );
  await assert.rejects(
    () => firestoreAdminCommitTransaction({}, "x", [], async () => { throw new Error("não deveria chamar"); }),
    /FIRESTORE_TRANSACTION_COMMIT_INVALID/
  );
});
