const FIRESTORE_SCOPE = "https://www.googleapis.com/auth/datastore";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const tokenCache = new Map();

function base64Url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function pemToBytes(pem) {
  if (typeof pem !== "string" || !pem.includes("BEGIN PRIVATE KEY")) {
    throw new Error("FIREBASE_PRIVATE_KEY_INVALID");
  }
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\\n/g, "\n")
    .replace(/\s/g, "");
  const binary = atob(body);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function requiredServiceAccount(env) {
  const email = env?.FIREBASE_SERVICE_ACCOUNT_EMAIL;
  const privateKey = env?.FIREBASE_PRIVATE_KEY;
  const projectId = env?.FIREBASE_PROJECT_ID || "ascensao-do-soberano";
  if (typeof email !== "string" || !/^[^@\s]+@[^@\s]+\.iam\.gserviceaccount\.com$/.test(email) ||
      typeof privateKey !== "string" || privateKey.length > 12000 || !privateKey.trim() ||
      typeof projectId !== "string" || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) {
    throw new Error("FIREBASE_ADMIN_NOT_CONFIGURED");
  }
  return { email, privateKey, projectId };
}

export async function getFirebaseAdminAccessToken(env, fetchImpl = fetch) {
  const account = requiredServiceAccount(env);
  const cached = tokenCache.get(account.email);
  if (cached && cached.expiresAt > Date.now() + 60_000) return cached.token;

  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = base64Url(new TextEncoder().encode(JSON.stringify({
    iss: account.email,
    scope: FIRESTORE_SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600
  })));
  const unsigned = header + "." + claims;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(account.privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned)
  );
  const assertion = unsigned + "." + base64Url(new Uint8Array(signature));
  const response = await fetchImpl(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion
    })
  });
  if (!response.ok) throw new Error("FIREBASE_ADMIN_TOKEN_EXCHANGE_FAILED");
  const result = await response.json();
  if (typeof result.access_token !== "string" || !result.access_token.trim() ||
      !Number.isFinite(result.expires_in) || result.expires_in <= 0) {
    throw new Error("FIREBASE_ADMIN_TOKEN_RESPONSE_INVALID");
  }
  tokenCache.set(account.email, {
    token: result.access_token,
    expiresAt: Date.now() + Math.max(60, result.expires_in) * 1000
  });
  return result.access_token;
}

export async function firestoreAdminGet(env, collection, documentId, fetchImpl = fetch) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(collection) ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(documentId)) {
    throw new Error("FIRESTORE_DOCUMENT_PATH_INVALID");
  }
  const token = await getFirebaseAdminAccessToken(env, fetchImpl);
  const projectId = env.FIREBASE_PROJECT_ID || "ascensao-do-soberano";
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${encodeURIComponent(documentId)}`;
  const response = await fetchImpl(url, { headers: { Authorization: "Bearer " + token } });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error("FIRESTORE_ADMIN_READ_FAILED");
  return response.json();
}

export async function firestoreAdminCommit(env, writes, fetchImpl = fetch) {
  if (!Array.isArray(writes) || writes.length < 1 || writes.length > 20) {
    throw new Error("FIRESTORE_WRITE_BATCH_INVALID");
  }
  const token = await getFirebaseAdminAccessToken(env, fetchImpl);
  const projectId = env.FIREBASE_PROJECT_ID || "ascensao-do-soberano";
  const response = await fetchImpl(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: {
        Authorization: "Bearer " + token,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ writes })
    }
  );
  if (!response.ok) throw new Error("FIRESTORE_ADMIN_COMMIT_FAILED");
  return response.json();
}
