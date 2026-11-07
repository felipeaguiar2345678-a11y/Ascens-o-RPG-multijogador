import { readFile } from "node:fs/promises";
import { after, before, beforeEach, describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
  arrayUnion,
  writeBatch,
} from "firebase/firestore";

const PROJECT_ID = "demo-ascensao";
let testEnv;

before(async () => {
  const rules = await readFile(new URL("../firestore.rules", import.meta.url), "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

const alice = () => testEnv.authenticatedContext("alice").firestore();
const bob = () => testEnv.authenticatedContext("bob").firestore();
const anonymous = () => testEnv.unauthenticatedContext().firestore();
const admin = () => testEnv.withSecurityRulesDisabled((context) => context.firestore());

describe("Regras Firestore — dados de jogador", () => {
  it("impede acesso anônimo e impede um jogador de ler ou gravar o perfil de outro", async () => {
    await assertFails(getDoc(doc(anonymous(), "users/alice")));
    await assertSucceeds(setDoc(doc(alice(), "users/alice"), { nome: "Alice" }));
    await assertSucceeds(getDoc(doc(alice(), "users/alice")));
    await assertFails(getDoc(doc(bob(), "users/alice")));
    await assertFails(setDoc(doc(bob(), "users/alice"), { nome: "Invadido" }));
  });

  it("protege personagens pelo ownerUid e bloqueia falsificação de proprietário", async () => {
    await assertSucceeds(setDoc(doc(alice(), "characters/personagem-1"), {
      ownerUid: "alice",
      nome: "Herói",
    }));
    await assertSucceeds(getDoc(doc(alice(), "characters/personagem-1")));
    await assertFails(getDoc(doc(bob(), "characters/personagem-1")));
    await assertFails(setDoc(doc(bob(), "characters/personagem-2"), {
      ownerUid: "alice",
      nome: "Falso",
    }));
    await assertFails(updateDoc(doc(alice(), "characters/personagem-1"), {
      ownerUid: "bob",
    }));
    await assertSucceeds(deleteDoc(doc(alice(), "characters/personagem-1")));
  });

  it("exige personagem próprio antes de criar dados visuais", async () => {
    await assertFails(setDoc(doc(alice(), "characterVisuals/sem-personagem"), {
      characterId: "sem-personagem",
      ownerUid: "alice",
    }));

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "characters/personagem-alice"), {
        ownerUid: "alice",
      });
      await setDoc(doc(context.firestore(), "characters/personagem-bob"), {
        ownerUid: "bob",
      });
    });

    await assertSucceeds(setDoc(doc(alice(), "characterVisuals/personagem-alice"), {
      characterId: "personagem-alice",
      ownerUid: "alice",
      imagemUrl: "https://example.invalid/alice.png",
    }));
    await assertFails(setDoc(doc(alice(), "characterVisuals/personagem-bob"), {
      characterId: "personagem-bob",
      ownerUid: "alice",
    }));
    await assertFails(setDoc(doc(alice(), "characterVisuals/id-incorreto"), {
      characterId: "personagem-alice",
      ownerUid: "alice",
    }));
    await assertFails(getDoc(doc(bob(), "characterVisuals/personagem-alice")));
  });
});

describe("Regras Firestore — criaturas e bestiário", () => {
  it("permite leitura autenticada do catálogo, mas não alteração após o registro", async () => {
    await assertSucceeds(setDoc(doc(alice(), "criaturas/lobo-arcano"), {
      id: "lobo-arcano",
      criadoPorUid: "alice",
      nome: "Lobo Arcano",
      ecosystemId: "floresta_arcana",
    }));
    await assertSucceeds(getDoc(doc(bob(), "criaturas/lobo-arcano")));
    await assertFails(updateDoc(doc(alice(), "criaturas/lobo-arcano"), {
      nome: "Nome alterado",
    }));
    await assertFails(deleteDoc(doc(alice(), "criaturas/lobo-arcano")));
    await assertFails(setDoc(doc(bob(), "criaturas/criatura-falsa"), {
      id: "criatura-falsa",
      criadoPorUid: "alice",
      nome: "Falsa",
      ecosystemId: "floresta_arcana",
    }));
  });

  it("restringe metadados de imagem ao primeiro registrador da criatura", async () => {
    await assertSucceeds(setDoc(doc(alice(), "criaturas/lobo-arcano"), {
      id: "lobo-arcano",
      criadoPorUid: "alice",
      nome: "Lobo Arcano",
      ecosystemId: "floresta_arcana",
    }));

    await assertSucceeds(setDoc(doc(alice(), "criaturas/lobo-arcano/imagens/principal"), {
      imagemId: "principal",
      criaturaId: "lobo-arcano",
      criadoPorUid: "alice",
    }));
    await assertFails(setDoc(doc(bob(), "criaturas/lobo-arcano/imagens/roubada"), {
      imagemId: "roubada",
      criaturaId: "lobo-arcano",
      criadoPorUid: "bob",
    }));
    await assertFails(updateDoc(doc(alice(), "criaturas/lobo-arcano/imagens/principal"), {
      criadoPorUid: "bob",
    }));
    await assertFails(deleteDoc(doc(alice(), "criaturas/lobo-arcano/imagens/principal")));
  });

  it("permite descoberta somente no bestiário do próprio jogador e impede alteração posterior", async () => {
    await assertSucceeds(setDoc(doc(alice(), "criaturas/lobo-arcano"), {
      id: "lobo-arcano",
      criadoPorUid: "alice",
      nome: "Lobo Arcano",
      ecosystemId: "floresta_arcana",
    }));
    await assertSucceeds(setDoc(doc(alice(), "jogadores/alice/bestiario/lobo-arcano"), {
      criaturaId: "lobo-arcano",
      descobertoEm: 123,
    }));
    await assertSucceeds(getDoc(doc(alice(), "jogadores/alice/bestiario/lobo-arcano")));
    await assertFails(getDoc(doc(bob(), "jogadores/alice/bestiario/lobo-arcano")));
    await assertFails(setDoc(doc(bob(), "jogadores/alice/bestiario/lobo-arcano"), {
      criaturaId: "lobo-arcano",
    }));
    await assertFails(updateDoc(doc(alice(), "jogadores/alice/bestiario/lobo-arcano"), {
      criaturaId: "outra-criatura",
    }));
    await assertFails(deleteDoc(doc(alice(), "jogadores/alice/bestiario/lobo-arcano")));
  });
});

describe("Regras Firestore — campanhas multiplayer", () => {
  async function seedCampaign() {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "campaigns/campanha-1"), {
        ownerUid: "alice",
        inviteCode: "ABCDEF",
        name: "Campanha original",
        visibility: "private",
        members: ["alice"],
      });
      await setDoc(doc(db, "campaignInvites/ABCDEF"), {
        campaignId: "campanha-1",
        inviteCode: "ABCDEF",
        ownerUid: "alice",
        active: true,
      });
    });
  }

  it("cria campanha e convite juntos, e permite consultar somente o convite por código", async () => {
    const db = alice();
    const batch = writeBatch(db);
    batch.set(doc(db, "campaigns/campanha-nova"), {
      ownerUid: "alice",
      inviteCode: "QWERTY",
      name: "Campanha nova",
      visibility: "private",
      members: ["alice"],
    });
    batch.set(doc(db, "campaignInvites/QWERTY"), {
      campaignId: "campanha-nova",
      inviteCode: "QWERTY",
      ownerUid: "alice",
      active: true,
    });
    await assertSucceeds(batch.commit());

    await assertSucceeds(getDoc(doc(bob(), "campaignInvites/QWERTY")));
    await assertFails(getDocs(collection(bob(), "campaignInvites")));
    await assertFails(getDoc(doc(anonymous(), "campaignInvites/QWERTY")));
    await assertFails(setDoc(doc(alice(), "campaignInvites/ISOLADO"), {
      campaignId: "campanha-nova",
      inviteCode: "ISOLADO",
      ownerUid: "alice",
      active: true,
    }));
  });

  it("permite entrada legítima somente com comprovante criado na mesma operação", async () => {
    await seedCampaign();
    const db = bob();
    const batch = writeBatch(db);
    batch.set(doc(db, "campaignInvites/ABCDEF/joins/bob"), {
      userUid: "bob",
      campaignId: "campanha-1",
      inviteCode: "ABCDEF",
      joinedAt: 123,
    });
    batch.update(doc(db, "campaigns/campanha-1"), {
      members: arrayUnion("bob"),
    });
    await assertSucceeds(batch.commit());

    const ownerCampaign = await getDoc(doc(alice(), "campaigns/campanha-1"));
    assert.deepEqual(ownerCampaign.data().members.sort(), ["alice", "bob"]);
  });

  it("nega entrada sem convite válido, sem comprovante ou com comprovante isolado", async () => {
    await seedCampaign();
    await assertFails(updateDoc(doc(bob(), "campaigns/campanha-1"), {
      members: arrayUnion("bob"),
    }));

    await assertFails(setDoc(doc(bob(), "campaignInvites/NAOEXISTE/joins/bob"), {
      userUid: "bob",
      campaignId: "campanha-1",
      inviteCode: "NAOEXISTE",
    }));

    await assertFails(setDoc(doc(bob(), "campaignInvites/ABCDEF/joins/bob"), {
      userUid: "bob",
      campaignId: "campanha-1",
      inviteCode: "ABCDEF",
    }));
  });

  it("impede membros de tomar a campanha, alterar dados ou manipular a lista de membros", async () => {
    await seedCampaign();

    await assertFails(updateDoc(doc(bob(), "campaigns/campanha-1"), {
      ownerUid: "bob",
    }));
    await assertFails(updateDoc(doc(alice(), "campaigns/campanha-1"), {
      ownerUid: "bob",
    }));
    await assertFails(updateDoc(doc(bob(), "campaigns/campanha-1"), {
      name: "Campanha invadida",
    }));
    await assertFails(updateDoc(doc(alice(), "campaigns/campanha-1"), {
      members: ["alice", "bob", "intruso"],
    }));
    await assertFails(updateDoc(doc(alice(), "campaigns/campanha-1"), {
      inviteCode: "NOVO1A",
    }));
    await assertSucceeds(updateDoc(doc(alice(), "campaigns/campanha-1"), {
      name: "Nome alterado pelo dono",
    }));
    await assertSucceeds(getDoc(doc(alice(), "campaigns/campanha-1")));
    await assertFails(getDoc(doc(bob(), "campaigns/campanha-1")));
  });
});
