import {
  firestoreAdminBeginTransaction,
  firestoreAdminGetInTransaction,
  firestoreAdminRunQuery,
  firestoreAdminStructuredQuery,
  firestoreAdminCommitTransaction,
  encodeFirestoreFields,
  decodeFirestoreFields
} from "./firebase-admin.js";

const validUid = v => typeof v === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const project = env => env.FIREBASE_PROJECT_ID || "ascensao-do-soberano";
const path = (env, collection, id) => `projects/${project(env)}/databases/(default)/documents/${collection}/${id}`;
const stamp = () => new Date().toISOString();
const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const code6 = () => Array.from(crypto.getRandomValues(new Uint8Array(6)), b => alphabet[b % alphabet.length]).join("");
const dataOf = d => d?.fields ? decodeFirestoreFields(d.fields) : null;
const setWrite = (name, data, masks) => ({ update: { name, fields: encodeFirestoreFields(data) }, ...(masks ? { updateMask: { fieldPaths: masks } } : {}) });
const createWrite = (name, data) => ({ update: { name, fields: encodeFirestoreFields(data) }, currentDocument: { exists: false } });
const deleteWrite = name => ({ delete: name });

async function txRead(env, collection, id, tx) {
  return firestoreAdminGetInTransaction(env, collection, id, tx);
}
async function query(env, collection, field, value, tx = null) {
  return firestoreAdminRunQuery(env, collection, field, value, tx);
}
async function character(env, uid, tx) {
  const d = await query(env, "characters", "ownerUid", uid, tx);
  if (!d?.data) throw new Error("CHARACTER_NOT_FOUND");
  return { name: d.name, id: d.name.split("/").pop(), data: d.data };
}
function stats(c) {
  const a = c.attributes || {};
  const n = (v, fallback) => Number.isFinite(Number(v)) ? Math.max(1, Math.min(10000, Math.floor(Number(v)))) : fallback;
  return { level:n(c.level,1), strength:n(a.strength,5), intelligence:n(a.intelligence,5), agility:n(a.agility,5), vitality:n(a.vitality,5), spirit:n(a.spirit,5), name:String(c.name || "Aventureiro").slice(0,32) };
}
function characterWrite(c, patch) {
  return setWrite(c.name, patch, Object.keys(patch));
}
function response(status, body) { return { status, body }; }
function errCode(e) { return String(e?.message || "MULTIPLAYER_SERVER_ERROR").replace(/[^A-Z0-9_]/g,"_").slice(0,80); }
function seasonKey() {
  const p = new Intl.DateTimeFormat("en-US",{timeZone:"America/Sao_Paulo",year:"numeric",month:"2-digit"}).formatToParts(new Date());
  return `${p.find(x=>x.type==="year")?.value}_${p.find(x=>x.type==="month")?.value}`;
}
function seasonName() {
  return ["Despertar da Primavera","Festival das Chamas","Maré dos Aventureiros","Convergência das Sombras","Colheita dos Heróis","Lua dos Dragões","Ecos do Abismo","Coroa das Estrelas","Vigília dos Guardiões","Caminho dos Titãs","Aurora Arcana","Inverno dos Soberanos"][Number(seasonKey().slice(-2))-1] || "Temporada dos Soberanos";
}
function addXp(c, amount) {
  let level=Math.max(1,Number(c.data.level||1)), xp=Math.max(0,Number(c.data.xp||0))+amount, points=Math.max(0,Number(c.data.attributePoints||0));
  while(xp>=level*100 && level<10000){xp-=level*100;level++;points+=5;}
  return {level,xp,attributePoints:points};
}
function addItem(c, id, name, quantity, rank, origin, traits=[]) {
  const inv=c.data.inventory||{}, items=Array.isArray(inv.items)?[...inv.items]:[];
  const i=items.findIndex(x=>x?.id===id);
  if(i>=0) items[i]={...items[i],quantity:Number(items[i].quantity||0)+quantity};
  else items.push({id,name,description:"Recompensa obtida em atividades multiplayer.",type:"Material de criação",quantity,imagemIconeCaminho:"",imagemDetalhadaCaminho:"",materialRank:rank,materialOrigin:origin,materialTraits:traits,sourceCreatureId:""});
  return { ...inv, items };
}
function rankGold(rank) { return ({E:1,D:1.25,C:1.6,B:2.1,A:3,S:4.5,SS:7,SSS:11})[String(rank).toUpperCase()]||1; }
function rankFragment(difficulty) { return difficulty==="ABISMO"?"EPICO":difficulty==="DIFICIL"?"RARO":"INCOMUM"; }
async function readCollection(env, collection, limit=100, tx=null) {
  const rows=await firestoreAdminStructuredQuery(env,{from:[{collectionId:collection}],limit},tx);
  return rows;
}
function rankingSet(env, category, uid, name, score, tx) {
  const ref=path(env,`leaderboards/${category}/entries`,uid);
  return setWrite(ref,{uid,nome:name,score,category,atualizadoEm:stamp()},["uid","nome","score","category","atualizadoEm"]);
}
async function updateEventProgress(env, uid, points, tx) {
  const sid=seasonKey(), event=path(env,"seasonalEvents",sid), player=path(env,`seasonalEvents/${sid}/players`,uid);
  const oldEvent=dataOf(await txRead(env,"seasonalEvents",sid,tx))||{};
  const oldPlayer=dataOf(await txRead(env,`seasonalEvents/${sid}/players`,uid,tx))||{};
  return [
    setWrite(event,{...oldEvent,globalPoints:Number(oldEvent.globalPoints||0)+points,updatedAt:stamp(),seasonId:sid},["globalPoints","updatedAt","seasonId"]),
    setWrite(player,{...oldPlayer,uid,points:Number(oldPlayer.points||0)+points,atualizadoEm:stamp()},["uid","points","atualizadoEm"])
  ];
}
async function guildContributionWrite(env, uid, points, tx) {
  const membership = dataOf(await txRead(env, "guildMembership", uid, tx));
  if (!membership?.guildId || !/^[A-Za-z0-9_-]{1,128}$/.test(String(membership.guildId))) return null;
  const guildRaw = await txRead(env, "guilds", String(membership.guildId), tx);
  const guild = dataOf(guildRaw);
  if (!guildRaw || !guild) return null;
  let level = Math.max(1, Number(guild.campLevel || 1));
  let experience = Math.max(0, Number(guild.campExperience || 0)) + Math.max(0, points);
  while (experience >= level * 100 && level < 100) { experience -= level * 100; level++; }
  return { write: setWrite(guildRaw.name, { ...guild, campLevel: level, campExperience: experience, campUpdatedAt: stamp() }), level };
}
async function membershipDungeon(env, uid, tx) {
  const m=dataOf(await txRead(env,"dungeonMembership",uid,tx));
  return m?.dungeonId ? m : null;
}

export async function handleMultiplayerAction(env, uid, input) {
  if(!validUid(uid)) return response(401,{error:"UNAUTHORIZED"});
  if(!input || typeof input!=="object" || Array.isArray(input)) return response(400,{error:"INVALID_REQUEST"});
  const action=String(input.acao||"");
  try {
    if(action==="criarMasmorra") {
      const difficulty=["NORMAL","DIFICIL","ABISMO"].includes(input.dificuldade)?input.dificuldade:"NORMAL";
      const creatures=await readCollection(env,"criaturas",300);
      const pool=creatures.filter(x=>x.data?.chefe!==true && x.data?.nome && Number(x.data?.vidaMaxima)>0);
      if(!pool.length) return response(409,{error:"BESTIARY_EMPTY"});
      const scale=difficulty==="ABISMO"?2.4:difficulty==="DIFICIL"?1.6:1;
      const rooms=Array.from({length:5},(_,i)=>{
        const c=pool[crypto.getRandomValues(new Uint32Array(1))[0]%pool.length].data;
        return {creatureId:String(c.id||""),name:String(c.nome),maxHp:Math.max(40,Math.floor(Number(c.vidaMaxima||100)*scale*(1+i*.18))),attack:Math.max(5,Math.floor(Number(c.ataque||10)*scale)),rank:String(c.rank||"E")};
      });
      const tx=await firestoreAdminBeginTransaction(env), c=await character(env,uid,tx);
      const p=stats(c.data), hp=100+p.vitality*10, id=crypto.randomUUID(), code=code6();
      const d={leaderUid:uid,leaderName:p.name,inviteCode:code,difficulty,members:[uid],memberNames:{[uid]:p.name},memberStats:{[uid]:{hp,maxHp:hp,damage:0,role:p.intelligence>=p.strength?"MAGO":p.vitality>=p.strength?"GUARDIÃO":"ATACANTE"}},room:1,totalRooms:5,roomEnemies:rooms,enemyCreatureId:rooms[0].creatureId,enemyName:rooms[0].name,enemyHp:rooms[0].maxHp,enemyMaxHp:rooms[0].maxHp,enemyAttack:rooms[0].attack,enemyRank:rooms[0].rank,status:"FORMANDO",lastActionAt:{},claimedUids:[],createdAt:stamp(),updatedAt:stamp()};
      await firestoreAdminCommitTransaction(env,tx,[createWrite(path(env,"dungeons",id),d),createWrite(path(env,"dungeonMembership",uid),{dungeonId:id,joinedAt:stamp()})]);
      return response(200,{dungeonId:id,codigo:code,status:"FORMANDO"});
    }
    if(action==="entrarMasmorra") {
      const code=String(input.codigo||"").trim().toUpperCase();
      if(!/^[A-HJ-NP-Z2-9]{6}$/.test(code)) return response(400,{error:"INVALID_DUNGEON_CODE"});
      const found=await query(env,"dungeons","inviteCode",code);
      if(!found) return response(404,{error:"DUNGEON_NOT_FOUND"});
      const id=found.name.split("/").pop(), tx=await firestoreAdminBeginTransaction(env);
      const [membership,dungeon,char]=await Promise.all([txRead(env,"dungeonMembership",uid,tx),txRead(env,"dungeons",id,tx),character(env,uid,tx)]);
      const d=dataOf(dungeon);
      if(membership) return response(409,{error:"ALREADY_IN_DUNGEON"});
      if(!d||d.status!=="FORMANDO") return response(409,{error:"DUNGEON_NOT_OPEN"});
      if(!Array.isArray(d.members)||d.members.length>=4) return response(409,{error:"DUNGEON_FULL"});
      const p=stats(char.data),hp=100+p.vitality*10;
      const next={...d,members:[...d.members,uid],memberNames:{...d.memberNames,[uid]:p.name},memberStats:{...d.memberStats,[uid]:{hp,maxHp:hp,damage:0,role:p.intelligence>=p.strength?"MAGO":p.vitality>=p.strength?"GUARDIÃO":"ATACANTE"}},updatedAt:stamp()};
      await firestoreAdminCommitTransaction(env,tx,[setWrite(dungeon.name,next),createWrite(path(env,"dungeonMembership",uid),{dungeonId:id,joinedAt:stamp()})]);
      return response(200,{dungeonId:id});
    }
    if(action==="buscarMasmorra") {
      const tx=await firestoreAdminBeginTransaction(env), membership=await membershipDungeon(env,uid,tx);
      if(!membership) return response(200,{dungeon:null});
      const raw=await txRead(env,"dungeons",String(membership.dungeonId),tx);
      return response(200,{dungeon:raw?{id:String(membership.dungeonId),...dataOf(raw)}:null});
    }
    if(["iniciarMasmorra","acaoMasmorra","reivindicarMasmorra"].includes(action)) {
      const id=String(input.dungeonId||"");
      if(!/^[A-Za-z0-9_-]{1,128}$/.test(id)) return response(400,{error:"INVALID_DUNGEON_ID"});
      const tx=await firestoreAdminBeginTransaction(env), raw=await txRead(env,"dungeons",id,tx), d=dataOf(raw);
      if(!d) return response(404,{error:"DUNGEON_NOT_FOUND"});
      if(action==="iniciarMasmorra") {
        if(d.leaderUid!==uid||d.status!=="FORMANDO") return response(403,{error:"LEADER_ONLY"});
        const formation=["BALANCEADA","AGRESSIVA","DEFENSIVA"].includes(input.formacao)?input.formacao:"BALANCEADA";
        await firestoreAdminCommitTransaction(env,tx,[setWrite(raw.name,{...d,status:"ACTIVE",formation,updatedAt:stamp()})]);
        return response(200,{status:"ACTIVE"});
      }
      if(!Array.isArray(d.members)||!d.members.includes(uid)) return response(403,{error:"NOT_A_MEMBER"});
      if(action==="acaoMasmorra") {
        if(d.status!=="ACTIVE") return response(409,{error:"DUNGEON_NOT_ACTIVE"});
        const kind=String(input.tipo||"ATACAR");
        if(!["ATACAR","MAGIA","COMBO","REVIVER","DEFENDER"].includes(kind)) return response(400,{error:"INVALID_ACTION"});
        const chars=await character(env,uid,tx),p=stats(chars.data),memberStats={...(d.memberStats||{})},me=memberStats[uid]||{};
        if(Date.now()-Number(d.lastActionAt?.[uid]||0)<900) return response(429,{error:"ACTION_COOLDOWN"});
        let enemyHp=Number(d.enemyHp||0),damage=0;
        if(kind==="REVIVER") {
          const target=String(input.alvoUid||"");
          if(!d.members.includes(target)||target===uid||Number(memberStats[target]?.hp||0)>0) return response(409,{error:"INVALID_REVIVE_TARGET"});
          memberStats[target]={...memberStats[target],hp:Math.max(1,Math.floor(Number(memberStats[target].maxHp||100)*.35))};
        } else if(kind==="DEFENDER") {
          memberStats[uid]={...me,hp:Math.min(Number(me.maxHp||100),Number(me.hp||0)+8+p.vitality)};
        } else {
          if(Number(me.hp||0)<=0) return response(409,{error:"PLAYER_DOWN"});
          damage=kind==="MAGIA"?p.intelligence*3+p.spirit*2+5:p.strength*3+p.agility+5;
          damage+=crypto.getRandomValues(new Uint32Array(1))[0]%11;
          const formation=String(d.formation||"BALANCEADA");
          if(formation==="AGRESSIVA") damage=Math.floor(damage*1.2);
          if(formation==="DEFENSIVA") damage=Math.floor(damage*.9);
          if(kind==="COMBO") { if(!d.members.some(m=>m!==uid&&Number(memberStats[m]?.hp||0)>0)) return response(409,{error:"ALLY_REQUIRED"}); damage+=Math.floor((p.strength+p.intelligence)*2.5); }
          enemyHp=Math.max(0,enemyHp-damage);
          memberStats[uid]={...me,damage:Number(me.damage||0)+damage};
          if(enemyHp>0) {
            const alive=d.members.filter(m=>Number(memberStats[m]?.hp||0)>0);
            if(alive.length) { const target=alive[crypto.getRandomValues(new Uint32Array(1))[0]%alive.length]; const factor=formation==="DEFENSIVA"?.75:formation==="AGRESSIVA"?1.2:1; const hit=Math.max(1,Math.floor((Number(d.enemyAttack||10)*(.65+(crypto.getRandomValues(new Uint32Array(1))[0]%51)/100))*factor)); memberStats[target]={...memberStats[target],hp:Math.max(0,Number(memberStats[target].hp||0)-hit)}; }
          }
        }
        let room=Number(d.room||1),status="ACTIVE",enemyName=d.enemyName,enemyCreatureId=d.enemyCreatureId,enemyMaxHp=Number(d.enemyMaxHp||enemyHp),enemyAttack=Number(d.enemyAttack||10),enemyRank=d.enemyRank||"E",goldReward=Number(d.goldReward||0);
        if(enemyHp<=0) {
          goldReward+=Math.max(5,Math.floor(enemyMaxHp/50))*rankGold(enemyRank);
          if(room>=5) status="COMPLETED";
          else { room++; const next=d.roomEnemies?.[room-1]; if(!next) return response(409,{error:"NEXT_ROOM_MISSING"}); enemyHp=Number(next.maxHp);enemyMaxHp=enemyHp;enemyCreatureId=next.creatureId;enemyAttack=next.attack;enemyRank=next.rank;enemyName=next.name; }
        }
        if(d.members.every(m=>Number(memberStats[m]?.hp||0)<=0)) status="FAILED";
        const updated={...d,memberStats,enemyHp,enemyMaxHp,enemyCreatureId,enemyAttack,enemyRank,room,enemyName,status,goldReward,lastActionAt:{...(d.lastActionAt||{}),[uid]:Date.now()},updatedAt:stamp()};
        await firestoreAdminCommitTransaction(env,tx,[setWrite(raw.name,updated)]);
        return response(200,{status:"AÇÃO_REGISTRADA",dungeon:updated});
      }
      if(d.status!=="COMPLETED") return response(409,{error:"DUNGEON_NOT_COMPLETED"});
      const claimed=d.claimedUids||[];
      if(claimed.includes(uid)) return response(409,{error:"ALREADY_CLAIMED"});
      const c=await character(env,uid,tx),p=stats(c.data),xpBase=d.difficulty==="ABISMO"?500:d.difficulty==="DIFICIL"?300:180;
      const guildProgress=await guildContributionWrite(env,uid,10,tx);
      const xpAmount=Math.floor(xpBase*(guildProgress?1+Math.min(.2,(guildProgress.level-1)*.02):1));
      const xp=addXp(c,xpAmount),fragment=rankFragment(d.difficulty),inventory=addItem(c,`fragmento_masmorra_${fragment.toLowerCase()}`,`Fragmento de Masmorra ${fragment}`,2,fragment,"Masmorra",["MINERAL"]);
      const totalGold=Math.max(0,Math.floor(Number(d.goldReward||0))),members=[...d.members].sort(),base=Math.floor(totalGold/members.length),rem=totalGold%members.length,index=members.indexOf(uid);
      inventory.gold=Math.max(0,Number(inventory.gold||0)) + base + (index>=0&&index<rem?1:0);
      const guildWrite=guildProgress?.write;
      const writes=[characterWrite(c,{...xp,inventory}),rankingSet(env,"masmorras",uid,p.name,Number((await txRead(env,"leaderboards/masmorras/entries",uid,tx))?.fields?.score?.integerValue||0)+1,tx),rankingSet(env,"nivel",uid,p.name,xp.level,tx),...(await updateEventProgress(env,uid,1,tx)),...(guildWrite?[guildWrite]:[]),setWrite(raw.name,{...d,claimedUids:[...claimed,uid],updatedAt:stamp()}),deleteWrite(path(env,"dungeonMembership",uid))];
      await firestoreAdminCommitTransaction(env,tx,writes);
      return response(200,{status:"RECOMPENSA_ENTREGUE",xp:xpAmount,ouro:base});
    }
    if(action==="sairMasmorra") {
      const tx=await firestoreAdminBeginTransaction(env),m=dataOf(await txRead(env,"dungeonMembership",uid,tx));
      if(!m) return response(200,{status:"SAIU"});
      const raw=await txRead(env,"dungeons",String(m.dungeonId),tx),d=dataOf(raw);
      const writes=[deleteWrite(path(env,"dungeonMembership",uid))];
      if(d&&["FORMANDO","FAILED","CANCELLED"].includes(d.status)) writes.push(setWrite(raw.name,{...d,members:(d.members||[]).filter(x=>x!==uid),updatedAt:stamp()}));
      await firestoreAdminCommitTransaction(env,tx,writes);
      return response(200,{status:"SAIU"});
    }
    if(action==="consultarRanking") {
      const category=String(input.categoria||"masmorras");
      if(!["nivel","masmorras","chefes","arena","guildas"].includes(category)) return response(400,{error:"INVALID_RANKING"});
      const rows=await firestoreAdminStructuredQuery(env,{from:[{collectionId:"entries",allDescendants:true}],where:{fieldFilter:{field:{fieldPath:"category"},op:"EQUAL",value:{stringValue:category}}},limit:300});
      const entries=rows.sort((a,b)=>Number(b.data.score||0)-Number(a.data.score||0)).slice(0,20).map((x,i)=>({posicao:i+1,uid:x.id,nome:x.data.nome||"Aventureiro",score:x.data.score||0}));
      return response(200,{categoria:category,entradas:entries});
    }
    if(["consultarEvento","participarEvento","reivindicarEvento"].includes(action)) {
      const sid=seasonKey(),eventPath=path(env,"seasonalEvents",sid),playerPath=path(env,`seasonalEvents/${sid}/players`,uid);
      const tx=await firestoreAdminBeginTransaction(env);
      const [eventRaw,playerRaw]=await Promise.all([txRead(env,"seasonalEvents",sid,tx),txRead(env,`seasonalEvents/${sid}/players`,uid,tx)]);
      const event=dataOf(eventRaw)||{title:seasonName(),description:"Conclua masmorras e participe de chefes regionais para ganhar pontos nesta temporada.",goal:5000,seasonId:sid,globalPoints:0};
      const player=dataOf(playerRaw)||{uid,points:0,joined:false,claimed:false};
      if(action==="consultarEvento") {
        const writes=eventRaw?[]:[createWrite(eventPath,event)];
        if(writes.length) await firestoreAdminCommitTransaction(env,tx,writes);
        return response(200,{evento:event,pontos:Number(player.points||0),reivindicado:player.claimed===true});
      }
      if(action==="participarEvento") {
        await firestoreAdminCommitTransaction(env,tx,[setWrite(playerPath,{...player,uid,joined:true,joinedAt:stamp()})]);
        return response(200,{status:"INSCRITO"});
      }
      const global=Number(event.globalPoints||0)>=Number(event.goal||5000);
      if(!player.joined||(!global&&Number(player.points||0)<3)) return response(409,{error:"EVENT_REQUIREMENTS_NOT_MET"});
      if(player.claimed) return response(409,{error:"ALREADY_CLAIMED"});
      const c=await character(env,uid,tx),p=stats(c.data),xp=addXp(c,global?500:250),inv=addItem(c,"insignia_convergencia","Insígnia da Convergência",global?2:1,"COMUM","Evento sazonal",[]);
      const writes=[characterWrite(c,{...xp,inventory:inv}),rankingSet(env,"nivel",uid,p.name,xp.level,tx),setWrite(playerPath,{...player,claimed:true,claimedAt:stamp()})];
      await firestoreAdminCommitTransaction(env,tx,writes);
      return response(200,{status:"RECOMPENSA_ENTREGUE"});
    }
    if(["buscarChefe","entrarChefe","atacarChefe","reivindicarChefe"].includes(action)) {
      const ecosystem=String(input.ecosystemId||"");
      if(!/^[a-z0-9_]{2,40}$/i.test(ecosystem)) return response(400,{error:"INVALID_ECOSYSTEM"});
      const bossId=ecosystem+"_"+seasonKey(),tx=await firestoreAdminBeginTransaction(env);
      const raw=await txRead(env,"worldBosses",bossId,tx),boss=dataOf(raw);
      if(action==="buscarChefe") return response(200,{chefe:boss?{id:bossId,...boss}:null});
      if(action==="entrarChefe") {
        const c=await character(env,uid,tx);
        if(!boss) {
          const creatures=await readCollection(env,"criaturas",300);
          const candidates=creatures.filter(x=>x.data?.chefe===true&&(x.data?.ecosystemId===ecosystem||x.data?.habitat===ecosystem));
          if(!candidates.length) return response(409,{error:"NO_BOSS_FOR_ECOSYSTEM"});
          const chosen=candidates[crypto.getRandomValues(new Uint32Array(1))[0]%candidates.length].data;
          const hp=Math.max(100,Number(chosen.vidaMaxima||1000)*10);
          const created={name:chosen.nome||"Chefe regional",creatureId:chosen.id||"",rank:chosen.rank||"S",hp,maxHp:hp,participants:[uid],contributions:{[uid]:0},claimedUids:[],status:"ACTIVE",ecosystemId:ecosystem,seasonId:seasonKey(),createdAt:stamp()};
          await firestoreAdminCommitTransaction(env,tx,[createWrite(path(env,"worldBosses",bossId),created)]);
          return response(200,{status:"BOSS_CREATED",chefe:{id:bossId,...created}});
        }
        if(boss.status!=="ACTIVE") return response(409,{error:"BOSS_NOT_ACTIVE"});
        const participants=[...new Set([...(boss.participants||[]),uid])];
        if(participants.length>50) return response(409,{error:"BOSS_FULL"});
        const updated={...boss,participants,contributions:{...(boss.contributions||{}),[uid]:Number(boss.contributions?.[uid]||0)}};
        await firestoreAdminCommitTransaction(env,tx,[setWrite(raw.name,updated)]);
        return response(200,{status:"PARTICIPANDO",chefe:{id:bossId,...updated}});
      }
      if(!boss) return response(404,{error:"BOSS_NOT_FOUND"});
      if(action==="atacarChefe") {
        if(boss.status!=="ACTIVE"||!(boss.participants||[]).includes(uid)) return response(403,{error:"NOT_ACTIVE_PARTICIPANT"});
        const c=await character(env,uid,tx),p=stats(c.data),damage=Math.max(1,p.strength*3+p.agility+crypto.getRandomValues(new Uint32Array(1))[0]%16);
        const hp=Math.max(0,Number(boss.hp||0)-damage),next={...boss,hp,status:hp<=0?"DEFEATED":"ACTIVE",lastDamageUid:uid,lastDamage:damage,contributions:{...(boss.contributions||{}),[uid]:Number(boss.contributions?.[uid]||0)+damage}};
        await firestoreAdminCommitTransaction(env,tx,[setWrite(raw.name,next)]);
        return response(200,{status:"DANO_REGISTRADO",chefe:{id:bossId,...next}});
      }
      if(boss.status!=="DEFEATED"||!(boss.participants||[]).includes(uid)||Number(boss.contributions?.[uid]||0)<=0) return response(409,{error:"BOSS_REWARD_UNAVAILABLE"});
      if((boss.claimedUids||[]).includes(uid)) return response(409,{error:"ALREADY_CLAIMED"});
      const c=await character(env,uid,tx),p=stats(c.data),xp=addXp(c,300),inv=addItem(c,"essencia_chefe_regional","Essência de Chefe Regional",1,"LENDARIO","Chefe regional",["ESPIRITUAL"]);
      const guildProgress=await guildContributionWrite(env,uid,20,tx);
      await firestoreAdminCommitTransaction(env,tx,[characterWrite(c,{...xp,inventory:inv}),rankingSet(env,"chefes",uid,p.name,Number((await txRead(env,"leaderboards/chefes/entries",uid,tx))?.fields?.score?.integerValue||0)+1,tx),rankingSet(env,"nivel",uid,p.name,xp.level,tx),...(await updateEventProgress(env,uid,1,tx)),...(guildProgress?.write?[guildProgress.write]:[]),setWrite(raw.name,{...boss,claimedUids:[...(boss.claimedUids||[]),uid]})]);
      return response(200,{status:"RECOMPENSA_ENTREGUE"});
    }
    if(["buscarArena","filaArena","cancelarFila","acaoArena","desistirArena"].includes(action)) {
      const queuePath=path(env,"arenaQueue",uid),tx=await firestoreAdminBeginTransaction(env);
      const queueRaw=await txRead(env,"arenaQueue",uid,tx),queue=dataOf(queueRaw);
      if(action==="buscarArena") {
        const matchId=queue?.matchId,matchRaw=matchId?await txRead(env,"arenaMatches",String(matchId),tx):null;
        return response(200,{fila:queue?{status:queue.status,matchId}:null,partida:matchRaw?{id:matchId,...dataOf(matchRaw)}:null});
      }
      if(action==="cancelarFila") {
        if(queue?.status==="WAITING") await firestoreAdminCommitTransaction(env,tx,[deleteWrite(queuePath)]);
        return response(200,{status:"FILA_CANCELADA"});
      }
      if(action==="filaArena") {
        const c=await character(env,uid,tx),p=stats(c.data),ratingRaw=await txRead(env,"arenaRatings",uid,tx),rating=Number(dataOf(ratingRaw)?.rating||1000);
        if(queue?.status==="WAITING"||queue?.status==="MATCHED") return response(200,{status:"AGUARDANDO"});
        const candidates=await firestoreAdminStructuredQuery(env,{from:[{collectionId:"arenaQueue"}],where:{fieldFilter:{field:{fieldPath:"status"},op:"EQUAL",value:{stringValue:"WAITING"}}},limit:20},tx);
        const rival=candidates.find(x=>x.id!==uid&&Math.abs(Number(x.data.rating||1000)-rating)<=250);
        if(!rival) {
          await firestoreAdminCommitTransaction(env,tx,[setWrite(queuePath,{uid,nome:p.name,rating,status:"WAITING",joinedAt:stamp()})]);
          return response(200,{status:"AGUARDANDO"});
        }
        const rivalChar=await character(env,rival.id,tx),rp=stats(rivalChar.data),matchId=crypto.randomUUID(),hpA=100+p.vitality*10,hpB=100+rp.vitality*10;
        const match={participants:[uid,rival.id],names:{[uid]:p.name,[rival.id]:rp.name},stats:{[uid]:{hp:hpA,maxHp:hpA,attack:p.strength*3+p.agility,defense:p.vitality},[rival.id]:{hp:hpB,maxHp:hpB,attack:rp.strength*3+rp.agility,defense:rp.vitality}},activeUid:uid,status:"ACTIVE",createdAt:stamp()};
        await firestoreAdminCommitTransaction(env,tx,[createWrite(path(env,"arenaMatches",matchId),match),setWrite(queuePath,{uid,nome:p.name,rating,status:"MATCHED",matchId}),setWrite(path(env,"arenaQueue",rival.id),{...rival.data,status:"MATCHED",matchId})]);
        return response(200,{status:"PAREAMENTO_TENTADO",matchId});
      }
      const matchId=String(input.matchId||queue?.matchId||"");
      if(!/^[A-Za-z0-9_-]{1,128}$/.test(matchId)) return response(400,{error:"INVALID_MATCH"});
      const matchRaw=await txRead(env,"arenaMatches",matchId,tx),match=dataOf(matchRaw);
      if(!match||match.status!=="ACTIVE"||!(match.participants||[]).includes(uid)) return response(409,{error:"MATCH_NOT_ACTIVE"});
      const rival=match.participants.find(x=>x!==uid),mstats={...(match.stats||{})};
      if(action==="desistirArena") {
        const winner=rival;
        const [winnerChar,loserChar,winnerRatingRaw,loserRatingRaw]=await Promise.all([
          character(env,winner,tx),character(env,uid,tx),txRead(env,"arenaRatings",winner,tx),txRead(env,"arenaRatings",uid,tx)
        ]);
        const winnerScore=Number(dataOf(winnerRatingRaw)?.rating||1000)+25;
        const loserScore=Math.max(0,Number(dataOf(loserRatingRaw)?.rating||1000)-20);
        await firestoreAdminCommitTransaction(env,tx,[
          setWrite(matchRaw.name,{...match,status:"FINISHED",winnerUid:winner,loserUid:uid}),
          setWrite(queuePath,{...(queue||{}),status:"FINISHED"}),
          setWrite(path(env,"arenaQueue",rival),{status:"FINISHED"}),
          setWrite(path(env,"arenaRatings",winner),{uid:winner,rating:winnerScore,updatedAt:stamp()}),
          setWrite(path(env,"arenaRatings",uid),{uid,rating:loserScore,updatedAt:stamp()}),
          rankingSet(env,"arena",winner,winnerChar.data.name||"Aventureiro",winnerScore,tx),
          rankingSet(env,"arena",uid,loserChar.data.name||"Aventureiro",loserScore,tx)
        ]);
        return response(200,{status:"DESISTENCIA_REGISTRADA"});
      }
      if(match.activeUid!==uid) return response(403,{error:"NOT_YOUR_TURN"});
      const kind=String(input.tipo||"ATACAR");
      if(!["ATACAR","DEFENDER"].includes(kind)) return response(400,{error:"INVALID_ARENA_ACTION"});
      const attack=Number(mstats[uid]?.attack||1),defense=Number(mstats[rival]?.defense||0);
      if(kind==="DEFENDER") mstats[uid]={...mstats[uid],hp:Math.min(Number(mstats[uid].maxHp),Number(mstats[uid].hp)+5+Number(mstats[uid].defense||0))};
      else mstats[rival]={...mstats[rival],hp:Math.max(0,Number(mstats[rival].hp)-Math.max(1,attack+5+crypto.getRandomValues(new Uint32Array(1))[0]%12-Math.floor(defense/2)))};
      const finished=Number(mstats[rival].hp)<=0;
      const writes=[setWrite(matchRaw.name,{...match,stats:mstats,status:finished?"FINISHED":"ACTIVE",winnerUid:finished?uid:"",loserUid:finished?rival:"",activeUid:finished?uid:rival}),...(finished?[setWrite(queuePath,{...(queue||{}),status:"FINISHED"}),setWrite(path(env,"arenaQueue",rival),{status:"FINISHED"})]:[])];
      if(finished) {
        const [winnerChar,loserChar,winnerRatingRaw,loserRatingRaw]=await Promise.all([
          character(env,uid,tx),character(env,rival,tx),txRead(env,"arenaRatings",uid,tx),txRead(env,"arenaRatings",rival,tx)
        ]);
        const winnerScore=Number(dataOf(winnerRatingRaw)?.rating||1000)+25;
        const loserScore=Math.max(0,Number(dataOf(loserRatingRaw)?.rating||1000)-20);
        writes.push(
          setWrite(path(env,"arenaRatings",uid),{uid,rating:winnerScore,updatedAt:stamp()}),
          setWrite(path(env,"arenaRatings",rival),{uid:rival,rating:loserScore,updatedAt:stamp()}),
          rankingSet(env,"arena",uid,winnerChar.data.name||"Aventureiro",winnerScore,tx),
          rankingSet(env,"arena",rival,loserChar.data.name||"Aventureiro",loserScore,tx)
        );
      }
      await firestoreAdminCommitTransaction(env,tx,writes);
      return response(200,{status:"AÇÃO_REGISTRADA"});
    }
    return response(400,{error:"UNKNOWN_MULTIPLAYER_ACTION"});
  } catch(error) {
    const code=errCode(error);
    const client=["CHARACTER_NOT_FOUND","BESTIARY_EMPTY","DUNGEON_NOT_FOUND","DUNGEON_FULL","DUNGEON_NOT_OPEN","ALREADY_IN_DUNGEON","NOT_A_MEMBER","DUNGEON_NOT_ACTIVE","PLAYER_DOWN","NEXT_ROOM_MISSING","DUNGEON_NOT_COMPLETED","ALREADY_CLAIMED","INVALID_ECOSYSTEM","NO_BOSS_FOR_ECOSYSTEM","BOSS_NOT_FOUND","BOSS_NOT_ACTIVE","NOT_ACTIVE_PARTICIPANT","BOSS_REWARD_UNAVAILABLE","BOSS_FULL","INVALID_MATCH","MATCH_NOT_ACTIVE","NOT_YOUR_TURN","INVALID_ARENA_ACTION","EVENT_REQUIREMENTS_NOT_MET"].includes(code);
    return response(client?409:503,{error:client?code:"MULTIPLAYER_SERVER_UNAVAILABLE"});
  }
}
