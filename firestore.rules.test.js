import { readFile } from "node:fs/promises";
import test, { before, after, beforeEach } from "node:test";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails
} from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp } from "firebase/firestore";

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
  currentHp: -1,
  currentMana: -1,
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


const validPresence = (uid = "player-1") => ({
  uid,
  nome: "Aventureiro",
  nivel: 1,
  worldPointId: "clareira_inicial",
  x: 0.52,
  y: 0.78,
  vida: 100,
  vidaMaxima: 100,
  ataque: 10,
  defesa: 5,
  mana: 50,
  manaMaxima: 50,
  agilidade: 5,
  poderMagico: 5,
  ultimaAtualizacao: new Date(),
  online: true
});

test("jogador publica apenas a própria presença com atributos dentro dos limites", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(doc(db, "worldPresence/player-1"), validPresence()));
});

test("presença não aceita vida acima do máximo", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(doc(db, "worldPresence/player-1"), {
    ...validPresence(), vida: 101
  }));
});

test("presença não aceita atributos absurdos", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(doc(db, "worldPresence/player-1"), {
    ...validPresence(), ataque: 999999999
  }));
});

test("jogador não publica presença em nome de outra conta", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(doc(db, "worldPresence/player-2"), validPresence("player-2")));
});

test("presença com data muito antiga é recusada", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(doc(db, "worldPresence/player-1"), {
    ...validPresence(), ultimaAtualizacao: new Date(Date.now() - 10 * 60 * 1000)
  }));
});


test("líder cria mundo com código e outros dois jogadores entram por ele", async () => {
  const leaderDb = env.authenticatedContext("leader").firestore();
  const create = writeBatch(leaderDb);
  create.set(doc(leaderDb, "allyGroups/leader"), {
    leaderUid: "leader",
    members: ["leader"],
    memberNames: { leader: "Líder" },
    inviteCode: "123456",
    activeBattleId: ""
  });
  create.set(doc(leaderDb, "allyMembership/leader"), { groupId: "leader" });
  create.set(doc(leaderDb, "allyGroupCodes/123456"), {
    groupId: "leader",
    ownerUid: "leader",
    active: true
  });
  await assertSucceeds(create.commit());

  const player2Db = env.authenticatedContext("player-2").firestore();
  const join2 = writeBatch(player2Db);
  join2.update(doc(player2Db, "allyGroups/leader"), {
    members: ["leader", "player-2"],
    memberNames: { leader: "Líder", "player-2": "Jogador 2" },
    lastJoinCode: "123456",
    updatedAt: serverTimestamp()
  });
  join2.set(doc(player2Db, "allyMembership/player-2"), { groupId: "leader" });
  await assertSucceeds(join2.commit());

  const player3Db = env.authenticatedContext("player-3").firestore();
  const join3 = writeBatch(player3Db);
  join3.update(doc(player3Db, "allyGroups/leader"), {
    members: ["leader", "player-2", "player-3"],
    memberNames: { leader: "Líder", "player-2": "Jogador 2", "player-3": "Jogador 3" },
    lastJoinCode: "123456",
    updatedAt: serverTimestamp()
  });
  join3.set(doc(player3Db, "allyMembership/player-3"), { groupId: "leader" });
  await assertSucceeds(join3.commit());

  const player4Db = env.authenticatedContext("player-4").firestore();
  const join4 = writeBatch(player4Db);
  join4.update(doc(player4Db, "allyGroups/leader"), {
    members: ["leader", "player-2", "player-3", "player-4"],
    memberNames: {
      leader: "Líder", "player-2": "Jogador 2",
      "player-3": "Jogador 3", "player-4": "Jogador 4"
    },
    lastJoinCode: "123456",
    updatedAt: serverTimestamp()
  });
  join4.set(doc(player4Db, "allyMembership/player-4"), { groupId: "leader" });
  await assertFails(join4.commit());
});
