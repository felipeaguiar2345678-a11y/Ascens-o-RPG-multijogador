import { readFile } from "node:fs/promises";
import test, { before, after, beforeEach } from "node:test";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails
} from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc, deleteDoc } from "firebase/firestore";

let env;

const validCharacter = (ownerUid = "player-1") => ({
  id: "character-1",
  ownerUid,
  name: "Aventureiro",
  hasSeenIntro: false,
  currentWorldPointId: "clareira_inicial",
  respawnPointId: "clareira_inicial",
  worldX: 0.52,
  worldY: 0.78,
  level: 1,
  xp: 0,
  attributePoints: 0,
  equipmentLoadout: {},
  inventory: {
    items: [],
    eggs: [],
    companions: [],
    gold: 0,
    equipment: []
  },
  powerProfile: {
    desires: [],
    powers: [],
    observations: []
  },
  characterClass: {},
  attributes: {
    strength: 5,
    intelligence: 5,
    agility: 5,
    vitality: 5,
    spirit: 5
  },
  appearance: {}
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-ascensao",
    firestore: {
      rules: await readFile("firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080
    }
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

test("jogador cria o próprio personagem com estrutura válida", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(doc(db, "characters/character-1"), validCharacter()));
});

test("jogador não cria personagem em nome de outra conta", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(
    doc(db, "characters/character-1"),
    validCharacter("player-2")
  ));
});

test("documento não pode declarar ID diferente do caminho", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(
    doc(db, "characters/character-1"),
    { ...validCharacter(), id: "character-forged" }
  ));
});

test("campos desconhecidos são recusados", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(
    doc(db, "characters/character-1"),
    { ...validCharacter(), admin: true }
  ));
});

test("XP fora do limite é recusado", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(
    doc(db, "characters/character-1"),
    { ...validCharacter(), xp: -1 }
  ));
});

test("ouro negativo é recusado", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(
    doc(db, "characters/character-1"),
    { ...validCharacter(), inventory: { ...validCharacter().inventory, gold: -1 } }
  ));
});

test("jogador não transfere a propriedade do personagem", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  const ref = doc(db, "characters/character-1");
  await assertSucceeds(setDoc(ref, validCharacter()));
  await assertFails(updateDoc(ref, { ownerUid: "player-2" }));
});

test("outro jogador não lê personagem privado", async () => {
  const ownerDb = env.authenticatedContext("player-1").firestore();
  const otherDb = env.authenticatedContext("player-2").firestore();
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), "characters/character-1"), validCharacter());
  });
  const { getDoc } = await import("firebase/firestore");
  await assertFails(getDoc(doc(otherDb, "characters/character-1")));
  await assertSucceeds(getDoc(doc(ownerDb, "characters/character-1")));
});

test("personagem pode atualizar sua posição sem alterar a identidade", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  const ref = doc(db, "characters/character-1");
  await assertSucceeds(setDoc(ref, validCharacter()));
  await assertSucceeds(updateDoc(ref, { worldX: 0.6, worldY: 0.7 }));
  await assertFails(updateDoc(ref, { worldX: 1000 }));
});
