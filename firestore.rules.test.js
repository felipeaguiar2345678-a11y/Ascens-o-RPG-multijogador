import { readFile } from "node:fs/promises";
import test, { before, after, beforeEach } from "node:test";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails
} from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc, deleteDoc, serverTimestamp, getDoc, getDocs, query, where, collection } from "firebase/firestore";

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
  defenseTrainingXp: 0,
  guildRank: "E",
  promotionBossesDefeated: [],
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

test("criação do app funciona sem campos opcionais de posição e equipamento", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  const character = validCharacter();
  delete character.worldX;
  delete character.worldY;
  delete character.equipmentLoadout;
  await assertSucceeds(setDoc(doc(db, "characters/character-1"), character));
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

test("XP defensivo negativo é recusado", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(
    doc(db, "characters/character-1"),
    { ...validCharacter(), defenseTrainingXp: -0.1 }
  ));
});

test("XP defensivo válido é aceito", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(
    doc(db, "characters/character-1"),
    { ...validCharacter(), defenseTrainingXp: 12.5 }
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

test("jogador lista somente seus próprios personagens por ownerUid", async () => {
  const ownerDb = env.authenticatedContext("player-1").firestore();
  const otherDb = env.authenticatedContext("player-2").firestore();

  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), "characters/character-1"), validCharacter("player-1"));
    await setDoc(doc(context.firestore(), "characters/character-2"), {
      ...validCharacter("player-2"),
      id: "character-2"
    });
  });

  const ownQuery = query(
    collection(ownerDb, "characters"),
    where("ownerUid", "==", "player-1")
  );
  const result = await assertSucceeds(getDocs(ownQuery));
  if (result.size !== 1 || result.docs[0].id !== "character-1") {
    throw new Error("A consulta deve retornar somente o personagem do jogador.");
  }

  await assertFails(getDocs(query(collection(otherDb, "characters"))));
});

test("jogador autenticado pode confirmar que o ID de um rascunho visual ainda não existe", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(getDoc(doc(db, "characters/rascunho-visual-novo")));
});

test("consulta de ID inexistente não permite ler personagem existente de outra conta", async () => {
  const ownerDb = env.authenticatedContext("player-1").firestore();
  const otherDb = env.authenticatedContext("player-2").firestore();
  await assertSucceeds(setDoc(doc(ownerDb, "characters/character-1"), validCharacter()));
  await assertFails(getDoc(doc(otherDb, "characters/character-1")));
});

test("personagem pode atualizar sua posição sem alterar a identidade", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  const ref = doc(db, "characters/character-1");
  await assertSucceeds(setDoc(ref, validCharacter()));
  await assertSucceeds(updateDoc(ref, { worldX: 0.6, worldY: 0.7 }));
  await assertFails(updateDoc(ref, { worldX: 1000 }));
});

test("recompensa solo mantém registro permanente e privado de retirada", async () => {
  const ownerDb = env.authenticatedContext("player-1").firestore();
  const otherDb = env.authenticatedContext("player-2").firestore();
  const parent = doc(ownerDb, "characters/character-1");
  await assertSucceeds(setDoc(parent, validCharacter()));
  const claim = doc(ownerDb, "characters/character-1/battleRewardClaims/battle-123");
  await assertSucceeds(setDoc(claim, {
    ownerUid: "player-1",
    battleId: "battle-123",
    createdAt: serverTimestamp()
  }));
  await assertFails(setDoc(claim, {
    ownerUid: "player-1",
    battleId: "battle-123",
    createdAt: serverTimestamp()
  }));
  await assertFails(getDoc(doc(otherDb, "characters/character-1/battleRewardClaims/battle-123")));
  await assertFails(updateDoc(claim, { ownerUid: "player-2" }));
  await assertFails(deleteDoc(claim));
});

test("jogador pode criar e remover apenas seu rascunho visual temporário", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  const ref = doc(db, "characters/character-1");
  await assertSucceeds(setDoc(ref, { ...validCharacter(), isVisualDraft: true }));
  await assertSucceeds(deleteDoc(ref));
});

test("jogador não pode apagar um personagem definitivo", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  const ref = doc(db, "characters/character-1");
  await assertSucceeds(setDoc(ref, validCharacter()));
  await assertFails(deleteDoc(ref));
});

test("jogador não pode transformar um rascunho em personagem definitivo por atualização", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  const ref = doc(db, "characters/character-1");
  await assertSucceeds(setDoc(ref, { ...validCharacter(), isVisualDraft: true }));
  await assertFails(updateDoc(ref, { isVisualDraft: false }));
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

const validAdventureSession = (ownerUid = "player-1") => ({
  ownerUid,
  characterId: "character-1",
  history: [
    { role: "player", text: "Investigar os rastros" },
    { role: "assistant", text: "Você encontra marcas profundas na lama." }
  ],
  chapterTitle: "Rastros na floresta",
  narrative: "O vento move as folhas enquanto você observa as marcas.",
  choices: ["Seguir", "Investigar", "Esperar", "Recuar"],
  updatedAt: serverTimestamp()
});

test("memória narrativa é salva somente na conta dona do personagem", async () => {
  const ownerDb = env.authenticatedContext("player-1").firestore();
  const otherDb = env.authenticatedContext("player-2").firestore();
  await assertSucceeds(setDoc(doc(ownerDb, "characters/character-1"), validCharacter()));
  await assertSucceeds(setDoc(
    doc(ownerDb, "users/player-1/adventureSessions/character-1"),
    validAdventureSession()
  ));
  await assertFails(setDoc(
    doc(otherDb, "users/player-1/adventureSessions/character-1"),
    validAdventureSession()
  ));
  await assertFails(getDoc(doc(otherDb, "users/player-1/adventureSessions/character-1")));
});

test("jogador pode salvar sua própria memória mesmo se a ficha ainda não foi sincronizada", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(
    doc(db, "users/player-1/adventureSessions/character-1"),
    validAdventureSession()
  ));
});

test("memória narrativa não pode ser criada para personagem de outra conta", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), "characters/character-1"), validCharacter("player-2"));
  });
  await assertFails(setDoc(
    doc(db, "users/player-1/adventureSessions/character-1"),
    validAdventureSession()
  ));
});

test("memória narrativa rejeita histórico acima do limite e campos extras", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(doc(db, "characters/character-1"), validCharacter()));
  const tooMuchHistory = Array.from({ length: 25 }, (_, index) => ({
    role: index % 2 === 0 ? "player" : "assistant",
    text: "Acontecimento"
  }));
  await assertFails(setDoc(
    doc(db, "users/player-1/adventureSessions/character-1"),
    { ...validAdventureSession(), history: tooMuchHistory }
  ));
  await assertFails(setDoc(
    doc(db, "users/player-1/adventureSessions/character-1"),
    { ...validAdventureSession(), admin: true }
  ));
});


const validGeneratedCreature = (ownerUid = "player-1") => ({
  id: "criatura-singular",
  nome: "Entidade do Horizonte",
  descricao: "Uma criatura original que dobra distâncias e atravessa fendas entre dimensões.",
  rank: "TRANSCENDENTE-ALFA",
  nivel: 900000,
  vidaMaxima: 1000000,
  ataque: 900000,
  defesa: 800000,
  manaMaxima: 2000000,
  agilidade: 700000,
  poderMagico: 950000,
  experienciaBase: 1000000,
  perigo: 1000000,
  ecosystemId: "abyss_valley",
  bioma: "Oceano celeste de cristal",
  habitat: "Fendas entre dimensões e regiões onde a distância deixa de obedecer às leis comuns.",
  raridade: "SINGULARIDADE ETERNA",
  atividadeNoturna: false,
  imagemId: "",
  imagemIconeCaminho: "",
  imagemDetalhadaCaminho: "",
  habilidades: Array.from({ length: 12 }, (_, i) => "Habilidade original " + i),
  ataques: Array.from({ length: 12 }, (_, i) => ({ id: "ataque-" + i, nome: "Técnica " + i })),
  drops: Array.from({ length: 12 }, (_, i) => ({ itemId: "drop-" + i })),
  chefe: true,
  criadoPorUid: ownerUid,
  versao: 1
});

const validEquipmentVisual = (uid = "player-1") => ({
  visualId: "equip_" + "a".repeat(64),
  nomeReferencia: "Espada de Ferro",
  tipo: "WEAPON",
  descricaoVisual: "Espada longa de ferro escuro com guarda simples.",
  raridadeVisual: "COMMON",
  rankVisual: "E",
  efeitoCombateReferencia: "",
  craftingMaterials: ["ferro"],
  materialTraits: ["metal escuro"],
  perfilEncaixeVisual: "corpo_base_v3",
  versaoVisualEquipamento: 3,
  status: "aguardando_arte",
  visualFrenteCaminho: "",
  visualCostasCaminho: "",
  visualLadoEsquerdoCaminho: "",
  visualLadoDireitoCaminho: "",
  criadoPorUid: uid,
  criadoEm: 123
});

test("jogador registra uma identidade visual global de equipamento uma única vez", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  const ref = doc(db, "equipamentos_visuais/" + validEquipmentVisual().visualId);
  await assertSucceeds(setDoc(ref, validEquipmentVisual()));
  await assertSucceeds(getDoc(ref));
  await assertFails(updateDoc(ref, { status: "pronto" }));
  await assertFails(deleteDoc(ref));
});

test("jogador não registra equipamento em nome de outra conta nem publica caminhos de arte", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  const id = validEquipmentVisual().visualId;
  await assertFails(setDoc(doc(db, "equipamentos_visuais/" + id), validEquipmentVisual("player-2")));
  await assertFails(setDoc(
    doc(db, "equipamentos_visuais/" + id),
    { ...validEquipmentVisual(), visualFrenteCaminho: "equipamentos/arte.png" }
  ));
});

test("catálogo aceita rank, raridade e quantidade de habilidades e ataques criados pela IA", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(
    doc(db, "criaturas/criatura-singular"),
    validGeneratedCreature()
  ));
});

test("catálogo continua exigindo ao menos um ataque utilizável", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(
    doc(db, "criaturas/criatura-singular"),
    { ...validGeneratedCreature(), ataques: [] }
  ));
});

test("catálogo não permite que outro jogador registre a criatura em nome do criador", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(setDoc(
    doc(db, "criaturas/criatura-singular"),
    validGeneratedCreature("player-2")
  ));
});


test("jogador não pode promover o próprio rank pelo cliente", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  const ref = doc(db, "characters/character-1");
  await assertSucceeds(setDoc(ref, validCharacter()));
  await assertFails(updateDoc(ref, { guildRank: "D" }));
  await assertFails(updateDoc(ref, { promotionBossesDefeated: ["promocao_E_D"] }));
});

const validGuildContract = (overrides = {}) => ({
  contractId: "forest_wolves",
  characterId: "character-1",
  ownerUid: "player-1",
  title: "Uivos na Trilha Verde",
  rank: "E",
  region: "Floresta Arcana",
  ecosystemId: "arcane_forest",
  biome: "Mata antiga",
  location: "Trilha da Vila Verdejante",
  kind: "HUNT",
  objective: "Reduzir a ameaça sem destruir o ecossistema",
  threat: "Matilha de feras",
  rewardPreview: "Moedas e reputação",
  status: "ACCEPTED",
  acceptedAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides
});

test("dono pode consultar contrato inexistente antes de aceitá-lo", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(doc(db, "characters/character-1"), validCharacter()));
  const missingRef = doc(db, "characters/character-1/guildContracts/forest_wolves");
  await assertSucceeds(getDoc(missingRef));
});

test("jogador aceita contrato do próprio rank e pode abandoná-lo", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(doc(db, "characters/character-1"), validCharacter()));
  const ref = doc(db, "characters/character-1/guildContracts/forest_wolves");
  await assertSucceeds(setDoc(ref, validGuildContract()));
  await assertSucceeds(updateDoc(ref, {
    status: "ABANDONED",
    abandonedAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  }));
});

test("jogador pode registrar falha da própria missão após derrota", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(doc(db, "characters/character-1"), validCharacter()));
  const ref = doc(db, "characters/character-1/guildContracts/forest_wolves");
  await assertSucceeds(setDoc(ref, validGuildContract()));
  await assertSucceeds(updateDoc(ref, {
    status: "FAILED",
    failedAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  }));
});

test("jogador não aceita contrato acima do próprio rank", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(doc(db, "characters/character-1"), validCharacter()));
  await assertFails(setDoc(
    doc(db, "characters/character-1/guildContracts/ice_pass"),
    validGuildContract({
      contractId: "ice_pass",
      rank: "D",
      title: "Suprimentos para o Passo Gelado"
    })
  ));
});

test("jogador não conclui contrato nem concede recompensa pelo cliente", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(doc(db, "characters/character-1"), validCharacter()));
  const ref = doc(db, "characters/character-1/guildContracts/forest_wolves");
  await assertSucceeds(setDoc(ref, validGuildContract()));
  await assertFails(updateDoc(ref, {
    status: "COMPLETED",
    rewardGranted: true
  }));
});

test("outro jogador não lê nem aceita contratos de personagem alheio", async () => {
  const ownerDb = env.authenticatedContext("player-1").firestore();
  const otherDb = env.authenticatedContext("player-2").firestore();
  await assertSucceeds(setDoc(doc(ownerDb, "characters/character-1"), validCharacter()));
  const contractRef = doc(ownerDb, "characters/character-1/guildContracts/forest_wolves");
  await assertSucceeds(setDoc(contractRef, validGuildContract()));
  await assertFails(getDoc(doc(otherDb, "characters/character-1/guildContracts/forest_wolves")));
  await assertFails(setDoc(
    doc(otherDb, "characters/character-1/guildContracts/ice_pass"),
    validGuildContract({ contractId: "ice_pass" })
  ));
});
test("cliente não cria missão com recompensa; aceitação é exclusiva do servidor", async () => {
  const db = env.authenticatedContext("player-1").firestore();
  await assertSucceeds(setDoc(doc(db, "characters/character-1"), validCharacter()));
  const ref = doc(db, "characters/character-1/guildContracts/guild_dark_forest_e_00000000-0000-4000-8000-000000000000");
  await assertFails(setDoc(ref, validGuildContract({
    contractId: "guild_dark_forest_e_00000000-0000-4000-8000-000000000000",
    destinationId: "clareira_inicial",
    rewardGold: 100,
    rewardXp: 100,
    rarity: "Comum",
    rarityMultiplier: 1,
    difficultyMultiplier: 1
  })));
});

test("cliente não pode abandonar nem falhar missão gerenciada pelo servidor", async () => {
  const admin = await env.withSecurityRulesDisabled(context => context.firestore());
  await setDoc(doc(admin, "characters/character-1"), validCharacter());
  const refAdmin = doc(admin, "characters/character-1/guildContracts/server_mission");
  await setDoc(refAdmin, { ...validGuildContract({ contractId: "server_mission" }), rewardGold: 100, rewardXp: 100 });
  const db = env.authenticatedContext("player-1").firestore();
  await assertFails(updateDoc(doc(db, "characters/character-1/guildContracts/server_mission"), {
    status: "ABANDONED", abandonedAt: serverTimestamp(), updatedAt: serverTimestamp()
  }));
});

