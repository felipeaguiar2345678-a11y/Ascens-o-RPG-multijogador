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
  it("limita leitura aos membros da campanha", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "campaigns/campanha-1"), {
        ownerUid: "alice",
        inviteCode: "ABCDEF",
        members: ["alice"],
      });
    });
    await assertSucceeds(getDoc(doc(alice(), "campaigns/campanha-1")));
    await assertFails(getDoc(doc(bob(), "campaigns/campanha-1")));
    // O fluxo Android atual procura por inviteCode antes de ser membro.
    // Esta consulta é negada pelas regras atuais; a entrada precisa de uma
    // rota de convite segura, em vez de abrir a leitura de todas as campanhas.
    await assertFails(getDocs(query(
      collection(bob(), "campaigns"),
      where("inviteCode", "==", "ABCDEF"),
    )));
  });
});
