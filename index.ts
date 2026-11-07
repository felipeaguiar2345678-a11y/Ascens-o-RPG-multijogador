import { initializeApp } from "firebase-admin/app";
import { randomInt } from "node:crypto";
import { FieldValue, getFirestore, DocumentData, Transaction, QueryDocumentSnapshot } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

initializeApp();
const db = getFirestore();
type Oferta = { itens: Array<{id:string; quantidade:number}>; ovos: string[]; equipamentos: string[] };
const vazia = (): Oferta => ({ itens: [], ovos: [], equipamentos: [] });

function validarOferta(raw: unknown): Oferta {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new HttpsError("invalid-argument", "Oferta inválida.");
  const o = raw as Record<string, unknown>;
  if (Object.keys(o).some(k => !["itens", "ovos", "equipamentos"].includes(k))) throw new HttpsError("invalid-argument", "Somente itens, materiais, ovos e equipamentos podem ser negociados. XP e pets eclodidos não são permitidos.");
  const ir = Array.isArray(o.itens) ? o.itens : [];
  const ovos = Array.isArray(o.ovos) ? o.ovos : [];
  const eq = Array.isArray(o.equipamentos) ? o.equipamentos : [];
  if (ir.length + ovos.length + eq.length > 40) throw new HttpsError("invalid-argument", "A oferta excede o limite de 40 objetos.");
  const itens = ir.map((v: any) => {
    if (!v || typeof v.id !== "string" || !v.id || !Number.isSafeInteger(v.quantidade) || v.quantidade < 1) throw new HttpsError("invalid-argument", "Item ou quantidade inválida.");
    return { id: v.id, quantidade: v.quantidade };
  });
  if (![...ovos, ...eq].every(v => typeof v === "string" && v.length > 0)) throw new HttpsError("invalid-argument", "Ovo ou equipamento inválido.");
  if (new Set(itens.map(v => v.id)).size !== itens.length || new Set(ovos).size !== ovos.length || new Set(eq).size !== eq.length) throw new HttpsError("invalid-argument", "Não repita objetos na oferta.");
  return { itens, ovos: ovos as string[], equipamentos: eq as string[] };
}

async function personagemDaTransacao(tx: Transaction, uid: string) {
  const snap = await tx.get(db.collection("characters").where("ownerUid", "==", uid).limit(1));
  if (snap.empty) throw new HttpsError("failed-precondition", "Personagem não encontrado.");
  return snap.docs[0];
}

function validarPosses(inv: DocumentData, o: Oferta) {
  const itens = Array.isArray(inv.items) ? inv.items : [];
  const ovos = Array.isArray(inv.eggs) ? inv.eggs : [];
  const eq = Array.isArray(inv.equipment) ? inv.equipment : [];
  for (const req of o.itens) {
    const item = itens.find((v: any) => v?.id === req.id);
    if (!item || !Number.isInteger(item.quantity) || item.quantity < req.quantidade) throw new HttpsError("failed-precondition", "Um item oferecido não está mais no inventário.");
    const tipo = String(item.type ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase();
    const nome = String(item.name ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase();
    const identificador = String(item.id ?? "").toUpperCase();
    if (["XP", "EXPERIENCIA", "EXPERIENCE"].includes(tipo) || ["XP", "EXPERIENCIA", "EXPERIENCE"].includes(nome) || identificador === "XP")
      throw new HttpsError("invalid-argument", "XP não pode ser negociada.");
  }
  for (const id of o.ovos) if (!ovos.some((v: any) => v?.id === id)) throw new HttpsError("failed-precondition", "Um ovo oferecido não está mais no inventário.");
  for (const id of o.equipamentos) if (!eq.some((v: any) => v?.id === id)) throw new HttpsError("failed-precondition", "Um equipamento oferecido não está mais no inventário.");
}

function transferir(origem: DocumentData, destino: DocumentData, o: Oferta) {
  const a = { ...origem }, b = { ...destino };
  const ai = Array.isArray(a.items) ? [...a.items] : [], bi = Array.isArray(b.items) ? [...b.items] : [];
  for (const req of o.itens) {
    const i = ai.findIndex((v: any) => v?.id === req.id), item = ai[i];
    if (!item || item.quantity < req.quantidade) throw new HttpsError("aborted", "O inventário mudou durante a troca.");
    if (item.quantity === req.quantidade) ai.splice(i, 1); else ai[i] = { ...item, quantity: item.quantity - req.quantidade };
    const j = bi.findIndex((v: any) => v?.id === req.id);
    if (j >= 0) bi[j] = { ...bi[j], quantity: bi[j].quantity + req.quantidade }; else bi.push({ ...item, quantity: req.quantidade });
  }
  const ae = Array.isArray(a.eggs) ? [...a.eggs] : [], be = Array.isArray(b.eggs) ? [...b.eggs] : [];
  for (const id of o.ovos) { const i = ae.findIndex((v: any) => v?.id === id); if (i < 0 || be.some((v: any) => v?.id === id)) throw new HttpsError("aborted", "O ovo não pode ser transferido."); be.push(ae.splice(i, 1)[0]); }
  const aq = Array.isArray(a.equipment) ? [...a.equipment] : [], bq = Array.isArray(b.equipment) ? [...b.equipment] : [];
  for (const id of o.equipamentos) { const i = aq.findIndex((v: any) => v?.id === id); if (i < 0 || bq.some((v: any) => v?.id === id)) throw new HttpsError("aborted", "O equipamento não pode ser transferido."); bq.push(aq.splice(i, 1)[0]); }
  return { origem: { ...a, items: ai, eggs: ae, equipment: aq }, destino: { ...b, items: bi, eggs: be, equipment: bq } };
}

export const gerenciarTroca = onCall({ region: "southamerica-east1" }, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre na sua conta.");
  const data = request.data ?? {};
  if (data.acao === "criar") {
    const alvo = data.destinatarioUid;
    if (typeof alvo !== "string" || !alvo || alvo === uid) throw new HttpsError("invalid-argument", "Destinatário inválido.");
    const ref = db.collection("trades").doc();
    await db.runTransaction(async tx => {
      const [a, b] = await Promise.all([personagemDaTransacao(tx, uid), personagemDaTransacao(tx, alvo)]);
      if (a.id === b.id) throw new HttpsError("failed-precondition", "Os jogadores precisam ter personagens diferentes.");
      tx.create(ref, { remetenteUid: uid, destinatarioUid: alvo, status: "PENDENTE", ofertas: { [uid]: vazia(), [alvo]: vazia() }, aceitoPor: [], criadoEm: FieldValue.serverTimestamp(), atualizadoEm: FieldValue.serverTimestamp() });
    });
    return { trocaId: ref.id };
  }
  const id = data.trocaId;
  if (typeof id !== "string" || !id) throw new HttpsError("invalid-argument", "Troca inválida.");
  const ref = db.collection("trades").doc(id);
  if (data.acao === "cancelar") {
    await db.runTransaction(async tx => {
      const s = await tx.get(ref); if (!s.exists) throw new HttpsError("not-found", "Troca não encontrada.");
      const d = s.data()!; if (uid !== d.remetenteUid && uid !== d.destinatarioUid) throw new HttpsError("permission-denied", "Você não participa dessa troca.");
      if (d.status !== "PENDENTE") throw new HttpsError("failed-precondition", "A troca não pode mais ser cancelada.");
      tx.update(ref, { status: "CANCELADA", canceladaPor: uid, atualizadoEm: FieldValue.serverTimestamp() });
    }); return { status: "CANCELADA" };
  }
  if (data.acao === "ofertar") {
    const oferta = validarOferta(data.oferta);
    await db.runTransaction(async tx => {
      const s = await tx.get(ref); if (!s.exists) throw new HttpsError("not-found", "Troca não encontrada.");
      const d = s.data()!; if (d.status !== "PENDENTE" || (uid !== d.remetenteUid && uid !== d.destinatarioUid)) throw new HttpsError("permission-denied", "Você não pode alterar essa oferta.");
      const c = await personagemDaTransacao(tx, uid); validarPosses((c.get("inventory") as DocumentData) ?? {}, oferta);
      tx.update(ref, { [`ofertas.${uid}`]: oferta, aceitoPor: [], atualizadoEm: FieldValue.serverTimestamp() });
    }); return { status: "OFERTA_ATUALIZADA" };
  }
  if (data.acao === "aceitar") {
    await db.runTransaction(async tx => {
      const s = await tx.get(ref); if (!s.exists) throw new HttpsError("not-found", "Troca não encontrada.");
      const d = s.data()!; const uids = [d.remetenteUid, d.destinatarioUid] as string[];
      if (!uids.includes(uid)) throw new HttpsError("permission-denied", "Você não participa dessa troca.");
      if (d.status !== "PENDENTE") throw new HttpsError("failed-precondition", "A troca não está pendente.");
      const aceitos = Array.isArray(d.aceitoPor) ? d.aceitoPor as string[] : [];
      if (aceitos.includes(uid)) throw new HttpsError("already-exists", "Você já confirmou essa proposta.");
      const confirmacoes = [...aceitos, uid];
      if (confirmacoes.length < 2) { tx.update(ref, { aceitoPor: confirmacoes, atualizadoEm: FieldValue.serverTimestamp() }); return; }
      const [ca, cb] = await Promise.all([personagemDaTransacao(tx, uids[0]), personagemDaTransacao(tx, uids[1])]);
      const ia = (ca.get("inventory") as DocumentData) ?? {}, ib = (cb.get("inventory") as DocumentData) ?? {};
      const ofertas = d.ofertas ?? {}; const oa = validarOferta(ofertas[uids[0]] ?? vazia()), ob = validarOferta(ofertas[uids[1]] ?? vazia());
      if (oa.itens.length + oa.ovos.length + oa.equipamentos.length + ob.itens.length + ob.ovos.length + ob.equipamentos.length === 0) throw new HttpsError("failed-precondition", "A troca precisa conter pelo menos um objeto.");
      validarPosses(ia, oa); validarPosses(ib, ob);
      const primeiro = transferir(ib, ia, ob); // oferta do destinatário vai para o remetente
      const segundo = transferir(primeiro.destino, primeiro.origem, oa); // oferta do remetente vai para o destinatário
      tx.update(ca.ref, { inventory: segundo.origem }); tx.update(cb.ref, { inventory: segundo.destino });
      tx.update(ref, { status: "CONCLUIDA", aceitoPor: confirmacoes, concluidaEm: FieldValue.serverTimestamp(), atualizadoEm: FieldValue.serverTimestamp() });
    }); return { status: "ACEITE_REGISTRADO" };
  }
  throw new HttpsError("invalid-argument", "Ação de troca desconhecida.");
});



// Guildas permanentes: separadas dos grupos Ally e das campanhas.
const guildCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
function gerarCodigoGuilda(): string {
  let code = "";
  for (let i = 0; i < 6; i++) code += guildCodeAlphabet[randomInt(guildCodeAlphabet.length)];
  return code;
}

export const gerenciarGuilda = onCall({ region: "southamerica-east1" }, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre na sua conta.");
  const data = request.data ?? {};
  const membershipRef = db.collection("guildMembership").doc(uid);

  if (data.acao === "criar") {
    const nome = typeof data.nome === "string" ? data.nome.trim() : "";
    const nomeJogador = typeof data.nomeJogador === "string" ? data.nomeJogador.trim().slice(0, 32) : "Aventureiro";
    if (nome.length < 3 || nome.length > 24) throw new HttpsError("invalid-argument", "Nome de guilda inválido.");
    const guildRef = db.collection("guilds").doc();
    let codigo = gerarCodigoGuilda();
    for (let tentativas = 0; tentativas < 5; tentativas++) {
      const existente = await db.collection("guilds").where("inviteCode", "==", codigo).limit(1).get();
      if (existente.empty) break;
      codigo = gerarCodigoGuilda();
      if (tentativas === 4) throw new HttpsError("resource-exhausted", "Não foi possível gerar um código. Tente novamente.");
    }
    await db.runTransaction(async tx => {
      const membership = await tx.get(membershipRef);
      if (membership.exists) throw new HttpsError("already-exists", "Você já pertence a uma guilda. Saia dela antes de criar outra.");
      tx.create(guildRef, {
        name: nome, inviteCode: codigo, leaderUid: uid, members: [uid],
        memberNames: { [uid]: nomeJogador }, createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(), level: 1, experience: 0,
        campLevel: 1, campExperience: 0
      });
      tx.create(membershipRef, { guildId: guildRef.id, joinedAt: FieldValue.serverTimestamp() });
      tx.set(db.collection("leaderboards").doc("guildas").collection("entries").doc(guildRef.id), {
        uid: guildRef.id, nome, score: 1, atualizadoEm: FieldValue.serverTimestamp()
      });
    });
    return { guildaId: guildRef.id, codigo };
  }

  if (data.acao === "entrar") {
    const codigo = typeof data.codigo === "string" ? data.codigo.trim().toUpperCase() : "";
    const nomeJogador = typeof data.nomeJogador === "string" ? data.nomeJogador.trim().slice(0, 32) : "Aventureiro";
    if (!/^[A-HJ-NP-Z2-9]{6}$/.test(codigo)) throw new HttpsError("invalid-argument", "Código inválido.");
    const query = await db.collection("guilds").where("inviteCode", "==", codigo).limit(1).get();
    if (query.empty) throw new HttpsError("not-found", "Guilda não encontrada.");
    const guildRef = query.docs[0].ref;
    await db.runTransaction(async tx => {
      const [membership, guild] = await Promise.all([tx.get(membershipRef), tx.get(guildRef)]);
      if (membership.exists) throw new HttpsError("already-exists", "Você já pertence a uma guilda.");
      if (!guild.exists) throw new HttpsError("not-found", "Guilda não encontrada.");
      const members = (guild.get("members") as string[] | undefined) ?? [];
      if (members.length >= 30) throw new HttpsError("failed-precondition", "A guilda já atingiu o limite de 30 membros.");
      if (members.includes(uid)) throw new HttpsError("already-exists", "Você já está nessa guilda.");
      tx.update(guildRef, {
        members: [...members, uid], [`memberNames.${uid}`]: nomeJogador,
        updatedAt: FieldValue.serverTimestamp()
      });
      tx.create(membershipRef, { guildId: guildRef.id, joinedAt: FieldValue.serverTimestamp() });
      tx.set(db.collection("leaderboards").doc("guildas").collection("entries").doc(guildRef.id), {
        uid: guildRef.id, nome: guild.get("name") ?? "Guilda", score: members.length + 1, atualizadoEm: FieldValue.serverTimestamp()
      }, { merge: true });
    });
    return { guildaId: guildRef.id };
  }

  if (data.acao === "sair") {
    await db.runTransaction(async tx => {
      const membership = await tx.get(membershipRef);
      if (!membership.exists) throw new HttpsError("failed-precondition", "Você não pertence a uma guilda.");
      const guildId = membership.get("guildId");
      if (typeof guildId !== "string") throw new HttpsError("data-loss", "Associação inválida.");
      const guildRef = db.collection("guilds").doc(guildId);
      const guild = await tx.get(guildRef);
      if (!guild.exists) { tx.delete(membershipRef); return; }
      const members = (guild.get("members") as string[] | undefined) ?? [];
      const remaining = members.filter(member => member !== uid);
      const names = { ...((guild.get("memberNames") as Record<string, string> | undefined) ?? {}) };
      delete names[uid];
      tx.delete(membershipRef);
      const rankingGuildaRef = db.collection("leaderboards").doc("guildas").collection("entries").doc(guildId);
      if (remaining.length === 0) {
        tx.delete(guildRef);
        tx.delete(rankingGuildaRef);
      } else if (guild.get("leaderUid") === uid) {
        tx.set(rankingGuildaRef, { uid: guildId, nome: guild.get("name") ?? "Guilda", score: remaining.length, atualizadoEm: FieldValue.serverTimestamp() }, { merge: true });
        tx.update(guildRef, { members: remaining, memberNames: names, leaderUid: remaining[0], updatedAt: FieldValue.serverTimestamp() });
      } else {
        tx.update(guildRef, { members: remaining, memberNames: names, updatedAt: FieldValue.serverTimestamp() });
        tx.set(rankingGuildaRef, { uid: guildId, nome: guild.get("name") ?? "Guilda", score: remaining.length, atualizadoEm: FieldValue.serverTimestamp() }, { merge: true });
      }
    });
    return { status: "SAIU" };
  }

  throw new HttpsError("invalid-argument", "Ação de guilda desconhecida.");
});

// Conteúdo multiplayer adicional. Todas as decisões de combate, progresso e recompensas
// são calculadas no servidor; o aplicativo envia somente a intenção da ação.
const ecosystemValido = (valor: string) => /^[a-z0-9_]{2,40}$/i.test(valor);
const categoriasRanking = new Set(["nivel", "masmorras", "chefes", "arena", "guildas"]);
const codigoCurto = () => {
  const alfabeto = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let valor = "";
  for (let i = 0; i < 6; i++) valor += alfabeto[randomInt(alfabeto.length)];
  return valor;
};
const partesDataBrasil = () => new Intl.DateTimeFormat("en-US", {
  timeZone: "America/Sao_Paulo", year: "numeric", month: "2-digit"
}).formatToParts(new Date());
const chaveTemporada = () => {
  const partes = partesDataBrasil();
  const ano = partes.find(p => p.type === "year")?.value ?? "0000";
  const mes = partes.find(p => p.type === "month")?.value ?? "01";
  return `${ano}_${mes}`;
};
const nomeTemporada = () => {
  const nomes = ["Despertar da Primavera", "Festival das Chamas", "Maré dos Aventureiros", "Convergência das Sombras", "Colheita dos Heróis", "Lua dos Dragões", "Ecos do Abismo", "Coroa das Estrelas", "Vigília dos Guardiões", "Caminho dos Titãs", "Aurora Arcana", "Inverno dos Soberanos"];
  const mes = Number(partesDataBrasil().find(p => p.type === "month")?.value ?? "01");
  return nomes[Math.max(0, Math.min(11, mes - 1))];
};

async function personagemPorUid(tx: Transaction, uid: string) {
  const encontrados = await tx.get(db.collection("characters").where("ownerUid", "==", uid).limit(1));
  if (encontrados.empty) throw new HttpsError("failed-precondition", "Crie um personagem antes de participar.");
  return encontrados.docs[0];
}
function atributosPersonagem(doc: DocumentData) {
  const a = (doc.attributes ?? {}) as Record<string, unknown>;
  const numero = (v: unknown, padrao: number) => Number.isFinite(Number(v)) ? Math.max(1, Math.min(10000, Math.floor(Number(v)))) : padrao;
  return {
    level: numero(doc.level, 1),
    strength: numero(a.strength, 5), intelligence: numero(a.intelligence, 5),
    agility: numero(a.agility, 5), vitality: numero(a.vitality, 5), spirit: numero(a.spirit, 5),
    name: typeof doc.name === "string" ? doc.name.slice(0, 32) : "Aventureiro"
  };
}
function aplicarXp(tx: Transaction, personagem: QueryDocumentSnapshot<DocumentData>, quantidade: number) {
  const doc = personagem.data();
  let level = Math.max(1, Number(doc.level ?? 1));
  let xp = Math.max(0, Number(doc.xp ?? 0)) + Math.max(0, Math.floor(quantidade));
  let pontos = Math.max(0, Number(doc.attributePoints ?? 0));
  while (xp >= level * 100 && level < 10000) { xp -= level * 100; level++; pontos += 5; }
  tx.update(personagem.ref, { level, xp, attributePoints: pontos });
  return level;
}
function adicionarItem(
  tx: Transaction,
  personagem: QueryDocumentSnapshot<DocumentData>,
  id: string,
  nome: string,
  quantidade = 1,
  materialRank = "COMUM",
  materialOrigin = "",
  materialTraits: string[] = [],
  sourceCreatureId = "",
  tipo = "Material de criação"
) {
  const inventario = (personagem.get("inventory") ?? {}) as DocumentData;
  const itens = Array.isArray(inventario.items) ? [...inventario.items] : [];
  const indice = itens.findIndex((i: any) => i?.id === id);
  if (indice >= 0) itens[indice] = { ...itens[indice], quantity: Math.max(0, Number(itens[indice].quantity ?? 0)) + quantidade };
  else itens.push({ id, name: nome, description: "Recompensa obtida em atividades multiplayer.", type: tipo, quantity: quantidade, imagemIconeCaminho: "", imagemDetalhadaCaminho: "", materialRank, materialOrigin, materialTraits, sourceCreatureId });
  tx.update(personagem.ref, { "inventory.items": itens });
}
function adicionarOuro(tx: Transaction, personagem: QueryDocumentSnapshot<DocumentData>, quantidade: number) {
  const inventario = (personagem.get("inventory") ?? {}) as DocumentData;
  const atual = Math.max(0, Math.floor(Number(inventario.gold ?? 0)));
  tx.update(personagem.ref, { "inventory.gold": atual + Math.max(0, Math.floor(quantidade)) });
}
function rankMaterialPorRankCriatura(rank: string): string {
  return ({ E: "COMUM", D: "INCOMUM", C: "RARO", B: "EPICO", A: "LENDARIO", S: "MITICO", SS: "DIVINO", SSS: "ANCESTRAL" } as Record<string, string>)[rank.toUpperCase()] ?? "COMUM";
}
function propriedadesMaterialDaCriatura(criatura: DocumentData | undefined): string[] {
  if (!criatura) return ["ESPIRITUAL"];
  const texto = [criatura.nome, criatura.descricao, criatura.bioma, criatura.habitat, criatura.ecosystemId].join(" ").toLowerCase();
  const traits = new Set<string>();
  const add = (termos: string[], trait: string) => { if (termos.some(t => texto.includes(t))) traits.add(trait); };
  add(["lobo", "canino", "presa", "garra", "predador"], "PREDADOR");
  add(["planta", "flor", "raiz", "vinha", "musgo", "floresta"], "NATUREZA");
  add(["dragão", "dracon", "escama"], "DRACONICO");
  add(["gelo", "neve", "glacial"], "GELO");
  add(["fogo", "lava", "brasas"], "FOGO");
  add(["veneno", "toxina", "ácido", "pântano"], "VENENO");
  add(["espírito", "alma", "fantasma", "sombra", "abismo"], "ESPIRITUAL");
  add(["pedra", "minério", "metal", "cristal", "montanha"], "MINERAL");
  add(["água", "marinho", "oceano", "rio"], "AQUATICO");
  if (traits.size === 0) traits.add("BESTIAL");
  return [...traits];
}
function atualizarRankingTx(tx: Transaction, categoria: string, uid: string, nome: string, incremento: number, extra: Record<string, unknown> = {}) {
  const ref = db.collection("leaderboards").doc(categoria).collection("entries").doc(uid);
  tx.set(ref, {
    uid, nome, score: FieldValue.increment(Math.max(0, incremento)),
    atualizadoEm: FieldValue.serverTimestamp(), ...extra
  }, { merge: true });
}
function definirRankingTx(tx: Transaction, categoria: string, uid: string, nome: string, score: number) {
  const ref = db.collection("leaderboards").doc(categoria).collection("entries").doc(uid);
  tx.set(ref, { uid, nome, score: Math.max(0, Math.floor(score)), atualizadoEm: FieldValue.serverTimestamp() }, { merge: true });
}
async function registrarContribuicaoGuildaTx(tx: Transaction, uid: string, pontos: number): Promise<number> {
  const membership = await tx.get(db.collection("guildMembership").doc(uid));
  if (!membership.exists) return 0;
  const guildId = membership.get("guildId");
  if (typeof guildId !== "string") return 0;
  const guildRef = db.collection("guilds").doc(guildId);
  const guild = await tx.get(guildRef);
  if (!guild.exists) return 0;
  let nivel = Math.max(1, Number(guild.get("campLevel") ?? 1));
  let experiencia = Math.max(0, Number(guild.get("campExperience") ?? 0)) + Math.max(0, pontos);
  while (experiencia >= nivel * 100 && nivel < 100) {
    experiencia -= nivel * 100;
    nivel++;
  }
  tx.update(guildRef, { campLevel: nivel, campExperience: experiencia, campUpdatedAt: FieldValue.serverTimestamp() });
  return nivel;
}
function registrarPontosTemporadaTx(tx: Transaction, uid: string, pontos: number) {
  const eventoRef = db.collection("seasonalEvents").doc(chaveTemporada());
  const ref = eventoRef.collection("players").doc(uid);
  tx.set(eventoRef, { globalPoints: FieldValue.increment(pontos), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  tx.set(ref, { uid, points: FieldValue.increment(pontos), atualizadoEm: FieldValue.serverTimestamp() }, { merge: true });
}

export const multiplayerExpandido = onCall({ region: "southamerica-east1", timeoutSeconds: 60 }, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre na sua conta.");
  const data = request.data ?? {};
  const acao = String(data.acao ?? "");

  // MASMORRAS: expedições de até quatro jogadores, cinco salas, combo e reanimação.
  if (acao === "criarMasmorra") {
    const dificuldade = ["NORMAL", "DIFICIL", "ABISMO"].includes(data.dificuldade) ? data.dificuldade : "NORMAL";
    const catalogo = await db.collection("criaturas").limit(300).get();
    const criaturas = catalogo.docs.filter(c => c.get("chefe") !== true && c.get("nome") && c.get("vidaMaxima"));
    if (criaturas.length < 1) throw new HttpsError("failed-precondition", "O bestiário global ainda não possui criaturas geradas para montar a masmorra.");
    const escala = dificuldade === "ABISMO" ? 2.4 : dificuldade === "DIFICIL" ? 1.6 : 1;
    const salas = Array.from({ length: 5 }, (_, i) => {
      const criatura = criaturas[randomInt(criaturas.length)];
      return { creatureId: criatura.id, name: String(criatura.get("nome")), maxHp: Math.max(40, Math.floor(Number(criatura.get("vidaMaxima") ?? 100) * escala * (1 + i * 0.18))), attack: Math.max(5, Math.floor(Number(criatura.get("ataque") ?? 10) * escala)), rank: String(criatura.get("rank") ?? "E") };
    });
    const ref = db.collection("dungeons").doc();
    const codigo = codigoCurto();
    await db.runTransaction(async tx => {
      const personagem = await personagemPorUid(tx, uid);
      const p = atributosPersonagem(personagem.data());
      const hp = 100 + p.vitality * 10;
      tx.create(ref, {
        leaderUid: uid, leaderName: p.name, inviteCode: codigo, difficulty: dificuldade,
        members: [uid], memberNames: { [uid]: p.name },
        memberStats: { [uid]: { hp, maxHp: hp, damage: 0, role: p.intelligence >= p.strength ? "MAGO" : p.vitality >= p.strength ? "GUARDIÃO" : "ATACANTE" } },
        room: 1, totalRooms: 5, roomEnemies: salas, enemyCreatureId: salas[0].creatureId,
        enemyName: salas[0].name, enemyHp: salas[0].maxHp, enemyMaxHp: salas[0].maxHp, enemyAttack: salas[0].attack, enemyRank: salas[0].rank,
        status: "FORMANDO", lastActionAt: {}, claimedUids: [], createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()
      });
      tx.create(db.collection("dungeonMembership").doc(uid), { dungeonId: ref.id, joinedAt: FieldValue.serverTimestamp() });
    });
    return { dungeonId: ref.id, codigo };
  }
  if (acao === "entrarMasmorra") {
    const codigo = String(data.codigo ?? "").trim().toUpperCase();
    if (!/^[A-HJ-NP-Z2-9]{6}$/.test(codigo)) throw new HttpsError("invalid-argument", "Código de masmorra inválido.");
    const q = await db.collection("dungeons").where("inviteCode", "==", codigo).limit(1).get();
    if (q.empty) throw new HttpsError("not-found", "Masmorra não encontrada.");
    const ref = q.docs[0].ref;
    await db.runTransaction(async tx => {
      const [m, d, c] = await Promise.all([tx.get(db.collection("dungeonMembership").doc(uid)), tx.get(ref), personagemPorUid(tx, uid)]);
      if (m.exists) throw new HttpsError("already-exists", "Você já está em uma expedição.");
      if (!d.exists || d.get("status") !== "FORMANDO") throw new HttpsError("failed-precondition", "A expedição já começou ou terminou.");
      const membros = (d.get("members") as string[]) ?? [];
      if (membros.length >= 4) throw new HttpsError("resource-exhausted", "A expedição já está cheia.");
      const p = atributosPersonagem(c.data()); const hp = 100 + p.vitality * 10;
      tx.update(ref, { members: [...membros, uid], [`memberNames.${uid}`]: p.name,
        [`memberStats.${uid}`]: { hp, maxHp: hp, damage: 0, role: p.intelligence >= p.strength ? "MAGO" : p.vitality >= p.strength ? "GUARDIÃO" : "ATACANTE" }, updatedAt: FieldValue.serverTimestamp() });
      tx.create(db.collection("dungeonMembership").doc(uid), { dungeonId: ref.id, joinedAt: FieldValue.serverTimestamp() });
    });
    return { dungeonId: ref.id };
  }
  if (acao === "iniciarMasmorra" || acao === "acaoMasmorra" || acao === "reivindicarMasmorra") {
    const id = String(data.dungeonId ?? ""); if (!id) throw new HttpsError("invalid-argument", "Expedição inválida.");
    const ref = db.collection("dungeons").doc(id);
    if (acao === "iniciarMasmorra") {
      await db.runTransaction(async tx => {
        const d = await tx.get(ref); if (!d.exists) throw new HttpsError("not-found", "Expedição não encontrada.");
        if (d.get("leaderUid") !== uid || d.get("status") !== "FORMANDO") throw new HttpsError("permission-denied", "Somente o líder pode iniciar a expedição.");
        const formacao = ["BALANCEADA", "AGRESSIVA", "DEFENSIVA"].includes(data.formacao) ? data.formacao : "BALANCEADA";
        tx.update(ref, { status: "ACTIVE", formation: formacao, updatedAt: FieldValue.serverTimestamp() });
      }); return { status: "ACTIVE" };
    }
    if (acao === "acaoMasmorra") {
      const tipo = String(data.tipo ?? "ATACAR");
      if (!["ATACAR", "MAGIA", "COMBO", "REVIVER", "DEFENDER"].includes(tipo)) throw new HttpsError("invalid-argument", "Ação inválida.");
      await db.runTransaction(async tx => {
        const d = await tx.get(ref); if (!d.exists || d.get("status") !== "ACTIVE") throw new HttpsError("failed-precondition", "A expedição não está em andamento.");
        const membros = (d.get("members") as string[]) ?? []; if (!membros.includes(uid)) throw new HttpsError("permission-denied", "Você não participa dessa expedição.");
        const stats = { ...((d.get("memberStats") as Record<string, any>) ?? {}) };
        const personagem = await personagemPorUid(tx, uid); const p = atributosPersonagem(personagem.data());
        const ultima = Number((d.get("lastActionAt") as Record<string, number> | undefined)?.[uid] ?? 0);
        if (Date.now() - ultima < 900) throw new HttpsError("resource-exhausted", "Aguarde um instante antes de agir novamente.");
        let hpInimigo = Number(d.get("enemyHp") ?? 0); let dano = 0;
        if (tipo === "REVIVER") {
          const alvo = String(data.alvoUid ?? ""); if (!membros.includes(alvo) || alvo === uid) throw new HttpsError("invalid-argument", "Escolha um aliado válido.");
          if (Number(stats[alvo]?.hp ?? 0) > 0) throw new HttpsError("failed-precondition", "Esse aliado ainda está de pé.");
          stats[alvo] = { ...stats[alvo], hp: Math.max(1, Math.floor(Number(stats[alvo]?.maxHp ?? 100) * 0.35)) };
        } else if (tipo === "DEFENDER") {
          stats[uid] = { ...stats[uid], hp: Math.min(Number(stats[uid]?.maxHp ?? 100), Number(stats[uid]?.hp ?? 0) + 8 + p.vitality) };
        } else {
          if (Number(stats[uid]?.hp ?? 0) <= 0) throw new HttpsError("failed-precondition", "Você precisa ser reanimado por um aliado.");
          dano = tipo === "MAGIA" ? p.intelligence * 3 + p.spirit * 2 + randomInt(5, 16) : p.strength * 3 + p.agility + randomInt(5, 16);
          const formacao = String(d.get("formation") ?? "BALANCEADA");
          if (formacao === "AGRESSIVA") dano = Math.floor(dano * 1.2);
          if (formacao === "DEFENSIVA") dano = Math.floor(dano * 0.9);
          if (tipo === "COMBO") {
            const aliado = membros.find(m => m !== uid && Number(stats[m]?.hp ?? 0) > 0);
            if (!aliado) throw new HttpsError("failed-precondition", "Combo exige pelo menos um aliado vivo.");
            dano += Math.floor((p.strength + p.intelligence) * 2.5);
          }
          hpInimigo = Math.max(0, hpInimigo - dano);
          stats[uid] = { ...stats[uid], damage: Number(stats[uid]?.damage ?? 0) + dano };
          if (hpInimigo > 0) {
            const alvo = membros.filter(m => Number(stats[m]?.hp ?? 0) > 0)[randomInt(Math.max(1, membros.filter(m => Number(stats[m]?.hp ?? 0) > 0).length))];
            if (alvo) {
              const defesa = tipo === "DEFENDER" ? 0 : 0;
              const ataqueInimigo = Math.max(5, Number(d.get("enemyAttack") ?? 10));
              const fatorFormacao = String(d.get("formation") ?? "BALANCEADA") === "DEFENSIVA" ? 0.75 : String(d.get("formation") ?? "BALANCEADA") === "AGRESSIVA" ? 1.2 : 1;
              const danoRecebido = Math.max(1, Math.floor(randomInt(Math.max(2, Math.floor(ataqueInimigo * 0.65)), Math.max(3, Math.floor(ataqueInimigo * 1.15)) + 1) * fatorFormacao) - defesa);
              stats[alvo] = { ...stats[alvo], hp: Math.max(0, Number(stats[alvo]?.hp ?? 0) - danoRecebido) };
            }
          }
        }
        const todosCaidos = membros.every(m => Number(stats[m]?.hp ?? 0) <= 0);
        let sala = Number(d.get("room") ?? 1); let status = "ACTIVE"; let nomeInimigo = d.get("enemyName") ?? "Sentinela";
        let enemyCreatureId = d.get("enemyCreatureId") ?? "";
        let enemyMaxHp = Number(d.get("enemyMaxHp") ?? hpInimigo);
        let enemyAttack = Number(d.get("enemyAttack") ?? 10);
        let enemyRank = d.get("enemyRank") ?? "E";
        let ouroAcumulado = Math.max(0, Number(d.get("goldReward") ?? 0));
        if (hpInimigo <= 0) {
          const multiplicadorOuro = ({ E: 1, D: 1.25, C: 1.6, B: 2.1, A: 3, S: 4.5, SS: 7, SSS: 11 } as Record<string, number>)[String(enemyRank).toUpperCase()] ?? 1;
          ouroAcumulado += Math.max(5, Math.floor(enemyMaxHp / 50)) * multiplicadorOuro;
          if (sala >= 5) status = "COMPLETED";
          else {
            sala++;
            const salas = (d.get("roomEnemies") as Array<Record<string, unknown>>) ?? [];
            const proxima = salas[sala - 1];
            if (!proxima) throw new HttpsError("data-loss", "A próxima sala não possui criatura cadastrada.");
            hpInimigo = Number(proxima.maxHp); enemyMaxHp = hpInimigo; enemyCreatureId = String(proxima.creatureId);
            enemyAttack = Number(proxima.attack); enemyRank = String(proxima.rank); nomeInimigo = String(proxima.name);
          }
        }
        if (todosCaidos) status = "FAILED";
        const last = { ...((d.get("lastActionAt") as Record<string, number>) ?? {}), [uid]: Date.now() };
        tx.update(ref, { memberStats: stats, enemyHp: hpInimigo, enemyMaxHp, enemyCreatureId, enemyAttack, enemyRank, room: sala, enemyName: nomeInimigo, status, goldReward: ouroAcumulado, lastActionAt: last, updatedAt: FieldValue.serverTimestamp() });
      }); return { status: "AÇÃO_REGISTRADA" };
    }
    await db.runTransaction(async tx => {
      const d = await tx.get(ref); if (!d.exists || d.get("status") !== "COMPLETED") throw new HttpsError("failed-precondition", "Conclua as cinco salas para receber a recompensa.");
      const membros = (d.get("members") as string[]) ?? []; if (!membros.includes(uid)) throw new HttpsError("permission-denied", "Você não participou dessa expedição.");
      const claimed = (d.get("claimedUids") as string[]) ?? []; if (claimed.includes(uid)) throw new HttpsError("already-exists", "Recompensa já retirada.");
      const c = await personagemPorUid(tx, uid); const p = atributosPersonagem(c.data());
      const nivelAcampamento = await registrarContribuicaoGuildaTx(tx, uid, 10);
      const xpBase = d.get("difficulty") === "ABISMO" ? 500 : d.get("difficulty") === "DIFICIL" ? 300 : 180;
      const xp = Math.floor(xpBase * (nivelAcampamento > 0 ? 1 + Math.min(0.2, (nivelAcampamento - 1) * 0.02) : 1));
      const novoNivel = aplicarXp(tx, c, xp);
      const dificuldade = String(d.get("difficulty") ?? "NORMAL");
      const rankFragmento = dificuldade === "ABISMO" ? "EPICO" : dificuldade === "DIFICIL" ? "RARO" : "INCOMUM";
      adicionarItem(tx, c, `fragmento_masmorra_${rankFragmento.toLowerCase()}`, `Fragmento de Masmorra ${rankFragmento}`, 2, rankFragmento, "Masmorra", ["MINERAL"]);
      const ouroTotal = Math.max(0, Math.floor(Number(d.get("goldReward") ?? 0)));
      const membrosOrdenados = [...membros].sort();
      const parteBase = Math.floor(ouroTotal / Math.max(1, membrosOrdenados.length));
      const restoOuro = ouroTotal % Math.max(1, membrosOrdenados.length);
      const indiceMembro = membrosOrdenados.indexOf(uid);
      adicionarOuro(tx, c, parteBase + (indiceMembro >= 0 && indiceMembro < restoOuro ? 1 : 0));
      atualizarRankingTx(tx, "masmorras", uid, p.name, 1); definirRankingTx(tx, "nivel", uid, p.name, novoNivel); registrarPontosTemporadaTx(tx, uid, 1);
      tx.update(ref, { claimedUids: [...claimed, uid], updatedAt: FieldValue.serverTimestamp() });
      tx.delete(db.collection("dungeonMembership").doc(uid));
    }); return { status: "RECOMPENSA_ENTREGUE" };
  }
  if (acao === "sairMasmorra") {
    const membershipRef = db.collection("dungeonMembership").doc(uid);
    await db.runTransaction(async tx => {
      const membership = await tx.get(membershipRef);
      if (!membership.exists) return;
      const dungeonRef = db.collection("dungeons").doc(String(membership.get("dungeonId")));
      const dungeon = await tx.get(dungeonRef);
      if (!dungeon.exists) { tx.delete(membershipRef); return; }
      if (!["FORMANDO", "FAILED", "CANCELLED"].includes(String(dungeon.get("status"))))
        throw new HttpsError("failed-precondition", "Só é possível sair antes do início ou após a derrota.");
      const members = ((dungeon.get("members") as string[]) ?? []).filter(m => m !== uid);
      const names = { ...((dungeon.get("memberNames") as Record<string, string>) ?? {}) }; delete names[uid];
      const stats = { ...((dungeon.get("memberStats") as Record<string, unknown>) ?? {}) }; delete stats[uid];
      tx.delete(membershipRef);
      if (members.length === 0) tx.update(dungeonRef, { members, memberNames: names, memberStats: stats, status: "CANCELLED", updatedAt: FieldValue.serverTimestamp() });
      else tx.update(dungeonRef, { members, memberNames: names, memberStats: stats, leaderUid: dungeon.get("leaderUid") === uid ? members[0] : dungeon.get("leaderUid"), updatedAt: FieldValue.serverTimestamp() });
    });
    return { status: "SAIU_DA_MASMORRA" };
  }
  if (acao === "buscarMasmorra") {
    const m = await db.collection("dungeonMembership").doc(uid).get();
    if (!m.exists) return { dungeon: null };
    const d = await db.collection("dungeons").doc(String(m.get("dungeonId"))).get();
    return { dungeon: d.exists ? { id: d.id, ...d.data() } : null };
  }

  // CHEFES MUNDIAIS: a criatura precisa existir no catálogo gerado por IA para seu ecossistema.
  if (["entrarChefe", "atacarChefe", "buscarChefe", "reivindicarChefe"].includes(acao)) {
    const regiao = String(data.ecosystemId ?? "");
    if (!ecosystemValido(regiao)) throw new HttpsError("invalid-argument", "Ecossistema inválido.");
    const bossId = `${regiao}_${chaveTemporada()}`; const ref = db.collection("worldBosses").doc(bossId);
    if (acao === "buscarChefe") { const s = await ref.get(); return { chefe: s.exists ? { id: s.id, ...s.data() } : null }; }
    if (acao === "entrarChefe") {
      const criaturas = await db.collection("criaturas").where("chefe", "==", true).get();
      const candidatas = criaturas.docs.filter(d => d.get("ecosystemId") === regiao);
      if (candidatas.length === 0) throw new HttpsError("failed-precondition", "Ainda não existe um chefe gerado e cadastrado para esta região.");
      const escolhido = candidatas[randomInt(candidatas.length)];
      await db.runTransaction(async tx => {
        const [boss, personagem] = await Promise.all([tx.get(ref), personagemPorUid(tx, uid)]);
        const p = atributosPersonagem(personagem.data());
        if (!boss.exists) {
          const rank = String(escolhido.get("rank") ?? "A");
          const multiplicador = ({ E: 1, D: 1.5, C: 2, B: 3, A: 4, S: 6, SS: 9, SSS: 14 } as Record<string, number>)[rank] ?? 4;
          const vida = Math.floor(Math.max(1, Number(escolhido.get("nivel") ?? 1)) * 500 * multiplicador);
          tx.create(ref, { ecosystemId: regiao, creatureId: escolhido.id, name: escolhido.get("nome") ?? "Chefe Regional", rank, maxHp: vida, hp: vida, participants: [uid], contributions: {}, claimedUids: [], status: "ACTIVE", season: chaveTemporada(), createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
        } else {
          if (boss.get("status") !== "ACTIVE") throw new HttpsError("failed-precondition", "O encontro regional desta temporada já terminou.");
          const atual = (boss.get("participants") as string[]) ?? [];
          if (!atual.includes(uid)) {
            if (atual.length >= 50) throw new HttpsError("resource-exhausted", "Este encontro já atingiu o limite de 50 participantes.");
            tx.update(ref, { participants: [...atual, uid], updatedAt: FieldValue.serverTimestamp() });
          }
        }
      }); return { bossId };
    }
    if (acao === "atacarChefe") {
      await db.runTransaction(async tx => {
        const [boss, personagem] = await Promise.all([tx.get(ref), personagemPorUid(tx, uid)]);
        if (!boss.exists || boss.get("status") !== "ACTIVE") throw new HttpsError("failed-precondition", "Não há chefe ativo nesta região.");
        const participantes = (boss.get("participants") as string[]) ?? []; if (!participantes.includes(uid)) throw new HttpsError("permission-denied", "Entre no encontro antes de atacar.");
        const ultimoAtaque = Number(((boss.get("lastAttackAt") as Record<string, number>) ?? {})[uid] ?? 0);
        if (Date.now() - ultimoAtaque < 1000) throw new HttpsError("resource-exhausted", "Aguarde um instante entre os ataques ao chefe.");
        const p = atributosPersonagem(personagem.data()); const dano = p.strength * 4 + p.agility * 2 + p.intelligence + randomInt(10, 31);
        const hp = Math.max(0, Number(boss.get("hp") ?? 0) - dano);
        const contribuicoes = { ...((boss.get("contributions") as Record<string, number>) ?? {}) };
        contribuicoes[uid] = (contribuicoes[uid] ?? 0) + dano;
        const lastAttackAt = { ...((boss.get("lastAttackAt") as Record<string, number>) ?? {}), [uid]: Date.now() };
        tx.update(ref, { hp, contributions: contribuicoes, lastAttackAt, status: hp <= 0 ? "DEFEATED" : "ACTIVE", defeatedAt: hp <= 0 ? FieldValue.serverTimestamp() : null, updatedAt: FieldValue.serverTimestamp() });
      }); return { status: "DANO_REGISTRADO" };
    }
    await db.runTransaction(async tx => {
      const [boss, personagem] = await Promise.all([tx.get(ref), personagemPorUid(tx, uid)]);
      if (!boss.exists || boss.get("status") !== "DEFEATED") throw new HttpsError("failed-precondition", "O chefe ainda não foi derrotado.");
      const participantes = (boss.get("participants") as string[]) ?? []; const dano = Number((boss.get("contributions") as Record<string, number> ?? {})[uid] ?? 0);
      if (!participantes.includes(uid) || dano <= 0) throw new HttpsError("permission-denied", "Você precisa ter contribuído para a batalha.");
      const claimed = (boss.get("claimedUids") as string[]) ?? []; if (claimed.includes(uid)) throw new HttpsError("already-exists", "Recompensa já retirada.");
      const p = atributosPersonagem(personagem.data());
      const rankChefe = String(boss.get("rank") ?? "A").toUpperCase();
      const nomeChefe = String(boss.get("name") ?? "Chefe Regional");
      const idCriaturaChefe = String(boss.get("creatureId") ?? "");
      const criaturaChefeDoc = idCriaturaChefe ? await tx.get(db.collection("criaturas").doc(idCriaturaChefe)) : null;
      const criaturaChefeData = criaturaChefeDoc?.exists ? criaturaChefeDoc.data() : undefined;
      const raridadeEssencia = String(criaturaChefeData?.raridade ?? "").toUpperCase();
      const rankEssencia = ["MUNDO", "MUNDIAL", "WORLD"].includes(raridadeEssencia) ? "WORLD" : rankMaterialPorRankCriatura(rankChefe);
      const origemEssencia = String(criaturaChefeData?.nome ?? nomeChefe);
      const traitsEssencia = propriedadesMaterialDaCriatura(criaturaChefeData);
      const nivelAcampamento = await registrarContribuicaoGuildaTx(tx, uid, 20);
      const xpBase = Math.min(1500, Math.max(100, Math.floor(dano / 3)));
      const xp = Math.floor(xpBase * (nivelAcampamento > 0 ? 1 + Math.min(0.2, (nivelAcampamento - 1) * 0.02) : 1));
      const novoNivel = aplicarXp(tx, personagem, xp);
      adicionarItem(tx, personagem, `essencia_chefe_regional_${rankChefe.toLowerCase()}_${idCriaturaChefe}`, "Essência de Chefe Regional", 1, rankEssencia, origemEssencia, traitsEssencia, idCriaturaChefe);
      const ouroPorRank = ({ E: 50, D: 90, C: 150, B: 250, A: 400, S: 700, SS: 1200, SSS: 2000 } as Record<string, number>)[rankChefe] ?? 400;
      const ouroChefe = Math.floor(ouroPorRank * (1 + Math.min(4, dano / 10000)));
      adicionarOuro(tx, personagem, ouroChefe);
      atualizarRankingTx(tx, "chefes", uid, p.name, dano); definirRankingTx(tx, "nivel", uid, p.name, novoNivel); registrarPontosTemporadaTx(tx, uid, 2);
      tx.update(ref, { claimedUids: [...claimed, uid], updatedAt: FieldValue.serverTimestamp() });
    }); return { status: "RECOMPENSA_ENTREGUE" };
  }

  // ARENA: pareamento por faixa de rating; turno, dano e resultado são decididos no servidor.
  if (["filaArena", "buscarArena", "cancelarFila", "acaoArena", "desistirArena"].includes(acao)) {
    const filaRef = db.collection("arenaQueue").doc(uid);
    if (acao === "cancelarFila") { const s = await filaRef.get(); if (s.exists && s.get("status") === "WAITING") await filaRef.delete(); return { status: "FILA_CANCELADA" }; }
    if (acao === "buscarArena") {
      const s = await filaRef.get(); if (!s.exists) return { fila: null, partida: null };
      const partidaId = s.get("matchId"); const partida = typeof partidaId === "string" ? await db.collection("arenaMatches").doc(partidaId).get() : null;
      return { fila: { status: s.get("status"), matchId: partidaId ?? null }, partida: partida?.exists ? { id: partida.id, ...partida.data() } : null };
    }
    if (acao === "filaArena") {
      const ratingDoc = await db.collection("arenaRatings").doc(uid).get(); const rating = Number(ratingDoc.get("rating") ?? 1000);
      const candidatos = await db.collection("arenaQueue").where("status", "==", "WAITING").limit(20).get();
      const candidato = candidatos.docs.find(d => d.id !== uid && Math.abs(Number(d.get("rating") ?? 1000) - rating) <= 250);
      const partidaRef = db.collection("arenaMatches").doc();
      await db.runTransaction(async tx => {
        const [self, personagem] = await Promise.all([tx.get(filaRef), personagemPorUid(tx, uid)]);
        if (self.exists && (self.get("status") === "WAITING" || self.get("status") === "MATCHED")) return;
        const p = atributosPersonagem(personagem.data());
        if (candidato) {
          const rivalRef = candidato.ref; const rival = await tx.get(rivalRef);
          if (!rival.exists || rival.get("status") !== "WAITING") { tx.set(filaRef, { uid, nome: p.name, rating, status: "WAITING", joinedAt: FieldValue.serverTimestamp() }); return; }
          const rivalChar = await personagemPorUid(tx, String(candidato.id)); const rp = atributosPersonagem(rivalChar.data());
          const hpA = 100 + p.vitality * 10, hpB = 100 + rp.vitality * 10;
          tx.create(partidaRef, { participants: [uid, candidato.id], names: { [uid]: p.name, [candidato.id]: rp.name }, stats: { [uid]: { hp: hpA, maxHp: hpA, attack: p.strength * 3 + p.agility, defense: p.vitality }, [candidato.id]: { hp: hpB, maxHp: hpB, attack: rp.strength * 3 + rp.agility, defense: rp.vitality } }, activeUid: uid, status: "ACTIVE", createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
          tx.set(filaRef, { uid, nome: p.name, rating, status: "MATCHED", matchId: partidaRef.id });
          tx.update(rivalRef, { status: "MATCHED", matchId: partidaRef.id });
        } else tx.set(filaRef, { uid, nome: p.name, rating, status: "WAITING", joinedAt: FieldValue.serverTimestamp() });
      }); return { status: candidato ? "PAREAMENTO_TENTADO" : "AGUARDANDO" };
    }
    const matchId = String(data.matchId ?? ""); const tipo = String(data.tipo ?? "ATACAR");
    if (!matchId) throw new HttpsError("invalid-argument", "Partida inválida.");
    if (acao === "desistirArena") {
      await db.runTransaction(async tx => {
        const ref = db.collection("arenaMatches").doc(matchId); const m = await tx.get(ref);
        if (!m.exists || m.get("status") !== "ACTIVE") throw new HttpsError("failed-precondition", "Partida encerrada.");
        const participantes = (m.get("participants") as string[]) ?? [];
        if (!participantes.includes(uid)) throw new HttpsError("permission-denied", "Você não participa desta partida.");
        const rival = participantes.find(p => p !== uid)!;
        const [ca, cb, ratingA, ratingB] = await Promise.all([
          personagemPorUid(tx, rival), personagemPorUid(tx, uid),
          tx.get(db.collection("arenaRatings").doc(rival)), tx.get(db.collection("arenaRatings").doc(uid))
        ]);
        tx.set(db.collection("arenaRatings").doc(rival), { uid: rival, rating: Math.max(0, Number(ratingA.get("rating") ?? 1000) + 25), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
        tx.set(db.collection("arenaRatings").doc(uid), { uid, rating: Math.max(0, Number(ratingB.get("rating") ?? 1000) - 20), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
        atualizarRankingTx(tx, "arena", rival, atributosPersonagem(ca.data()).name, 1);
        atualizarRankingTx(tx, "arena", uid, atributosPersonagem(cb.data()).name, 0);
        tx.update(ref, { status: "FINISHED", winnerUid: rival, loserUid: uid, desistiuUid: uid, updatedAt: FieldValue.serverTimestamp() });
        tx.update(db.collection("arenaQueue").doc(uid), { status: "FINISHED" });
        tx.update(db.collection("arenaQueue").doc(rival), { status: "FINISHED" });
      });
      return { status: "DESISTENCIA_REGISTRADA" };
    }
    if (!["ATACAR", "DEFENDER"].includes(tipo)) throw new HttpsError("invalid-argument", "Ação de arena inválida.");
    await db.runTransaction(async tx => {
      const ref = db.collection("arenaMatches").doc(matchId); const m = await tx.get(ref);
      if (!m.exists || m.get("status") !== "ACTIVE") throw new HttpsError("failed-precondition", "Partida encerrada.");
      const participantes = (m.get("participants") as string[]) ?? []; if (!participantes.includes(uid) || m.get("activeUid") !== uid) throw new HttpsError("permission-denied", "Não é seu turno.");
      const rival = participantes.find(p => p !== uid)!; const stats = { ...((m.get("stats") as Record<string, any>) ?? {}) };
      const ataque = Number(stats[uid]?.attack ?? 1); const defesa = Number(stats[rival]?.defense ?? 0);
      const dano = tipo === "DEFENDER" ? 0 : Math.max(1, ataque + randomInt(5, 16) - Math.floor(defesa / 2));
      if (tipo === "DEFENDER") stats[uid] = { ...stats[uid], hp: Math.min(Number(stats[uid].maxHp), Number(stats[uid].hp) + 5 + defesa) };
      else stats[rival] = { ...stats[rival], hp: Math.max(0, Number(stats[rival].hp) - dano) };
      const fim = Number(stats[rival].hp) <= 0;
      if (fim) {
        const [ca, cb, ratingA, ratingB] = await Promise.all([
          personagemPorUid(tx, uid), personagemPorUid(tx, rival),
          tx.get(db.collection("arenaRatings").doc(uid)), tx.get(db.collection("arenaRatings").doc(rival))
        ]);
        tx.set(db.collection("arenaRatings").doc(uid), { uid, rating: Math.max(0, Number(ratingA.get("rating") ?? 1000) + 25), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
        tx.set(db.collection("arenaRatings").doc(rival), { uid: rival, rating: Math.max(0, Number(ratingB.get("rating") ?? 1000) - 20), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
        atualizarRankingTx(tx, "arena", uid, atributosPersonagem(ca.data()).name, 1);
        atualizarRankingTx(tx, "arena", rival, atributosPersonagem(cb.data()).name, 0);
        tx.update(ref, { stats, status: "FINISHED", winnerUid: uid, loserUid: rival, updatedAt: FieldValue.serverTimestamp() });
        tx.update(filaRef, { status: "FINISHED" }); tx.update(db.collection("arenaQueue").doc(rival), { status: "FINISHED" });
      } else tx.update(ref, { stats, activeUid: rival, updatedAt: FieldValue.serverTimestamp() });
    }); return { status: "AÇÃO_REGISTRADA" };
  }

  if (acao === "consultarRanking") {
    const categoria = String(data.categoria ?? "masmorras"); if (!categoriasRanking.has(categoria)) throw new HttpsError("invalid-argument", "Ranking inválido.");
    const s = await db.collection("leaderboards").doc(categoria).collection("entries").orderBy("score", "desc").limit(20).get();
    return { categoria, entradas: s.docs.map((d, i) => ({ posicao: i + 1, uid: d.id, nome: d.get("nome") ?? "Aventureiro", score: d.get("score") ?? 0 })) };
  }

  // EVENTO SAZONAL mensal: progresso individual e recompensa única por conta.
  if (["consultarEvento", "participarEvento", "reivindicarEvento"].includes(acao)) {
    const seasonId = chaveTemporada(); const eventRef = db.collection("seasonalEvents").doc(seasonId);
    if (acao === "consultarEvento") {
      await eventRef.set({ title: nomeTemporada(), description: "Participe de masmorras e derrote chefes regionais para ganhar pontos durante esta temporada. Alcance três pontos pessoais ou ajude a comunidade a completar a meta global.", goal: 5000, seasonId, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      const [event, player] = await Promise.all([eventRef.get(), eventRef.collection("players").doc(uid).get()]);
      const progress = Number(player.get("points") ?? 0);
      return { evento: event.data(), pontos: progress, reivindicado: player.get("claimed") === true, metaIndividual: 3 };
    }
    if (acao === "participarEvento") { await eventRef.collection("players").doc(uid).set({ uid, joined: true, joinedAt: FieldValue.serverTimestamp() }, { merge: true }); return { status: "INSCRITO" }; }
    await db.runTransaction(async tx => {
      const [player, eventoAtual, personagem] = await Promise.all([
        tx.get(eventRef.collection("players").doc(uid)), tx.get(eventRef), personagemPorUid(tx, uid)
      ]);
      const pontosPessoais = Number(player.get("points") ?? 0);
      const metaGlobalAtingida = Number(eventoAtual.get("globalPoints") ?? 0) >= Number(eventoAtual.get("goal") ?? 5000);
      if (!player.exists || player.get("joined") !== true || (pontosPessoais < 3 && !metaGlobalAtingida)) throw new HttpsError("failed-precondition", "Inscreva-se e consiga três pontos pessoais ou aguarde a comunidade completar a meta global.");
      if (player.get("claimed") === true) throw new HttpsError("already-exists", "Recompensa sazonal já retirada.");
      const p = atributosPersonagem(personagem.data());
      const xpEvento = metaGlobalAtingida ? 500 : 250;
      const novoNivel = aplicarXp(tx, personagem, xpEvento);
      adicionarItem(tx, personagem, "insignia_convergencia", "Insígnia da Convergência", metaGlobalAtingida ? 2 : 1, "COMUM", "Evento sazonal", [], "", "Recompensa sazonal");
      definirRankingTx(tx, "nivel", uid, p.name, novoNivel);
      tx.update(eventRef.collection("players").doc(uid), { claimed: true, claimedAt: FieldValue.serverTimestamp() });
    }); return { status: "RECOMPENSA_ENTREGUE" };
  }
  throw new HttpsError("invalid-argument", "Ação multiplayer desconhecida.");
});
