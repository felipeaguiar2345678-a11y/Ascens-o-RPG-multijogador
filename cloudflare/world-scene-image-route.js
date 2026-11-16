// Cenários oficiais gerados uma única vez por ecossistema e compartilhados via R2.
const MODEL = "gpt-image-2";
const RESERVE_MICROS = 5000000;
const MAX_BYTES = 7000000;
const SCENES = {
  floresta: { name:"Floresta Arcana", prompt:"ancient enchanted forest, giant mossy trees, luminous mushrooms, tangled roots, emerald magical fireflies, layered woodland depth" },
  sombras: { name:"Terras das Sombras", prompt:"cursed dark valley, black stone obelisks, violet rifts, dead twisted trees, eerie purple mist, ruined dark fantasy landscape" },
  neve: { name:"Montanhas Gélidas", prompt:"vast snowy mountain pass, icy cliffs, frost-covered pines, glacial waterfall, wind-shaped snowdrifts, crisp blue winter light" },
  deserto: { name:"Deserto Ancestral", prompt:"ancient golden desert, layered dunes, sandstone temple ruins, weathered pillars, distant mesas, warm dusty sunset" },
  mar: { name:"Mar Eterno", prompt:"fantasy sea coast, turquoise waves, rocky shore, distant islands, weathered lighthouse ruins, sea mist and dramatic ocean light" },
  ruinas: { name:"Ruínas Antigas", prompt:"forgotten temple courtyard, broken monumental columns, mossy carved stones, collapsed arches, shafts of mystical light" },
  imperio: { name:"Império", prompt:"grand imperial frontier battlefield, distant fortified walls, stone towers, banners, cultivated fields, warm cinematic light" },
  central: { name:"Região Central", prompt:"wide fantasy central wilderness, rolling grassland, ancient stone road, distant hills, scattered standing stones, open horizon" }
};
function json(data,status=200){return new Response(JSON.stringify(data),{status,headers:{"Access-Control-Allow-Origin":"*","Access-Control-Allow-Methods":"GET, POST, OPTIONS","Access-Control-Allow-Headers":"Content-Type, Authorization","Content-Type":"application/json; charset=utf-8"}});}
function monthBR(){const p=new Intl.DateTimeFormat("en-US",{timeZone:"America/Sao_Paulo",year:"numeric",month:"2-digit"}).formatToParts(new Date());return `${p.find(x=>x.type==="year")?.value}-${p.find(x=>x.type==="month")?.value}`;}
async function settle(stub,month,id,actualMicros){const r=await stub.fetch("https://budget/settle",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({month,action:"settle",reservationId:id,actualMicros})});return r.ok;}
export async function handleWorldSceneGeneration(request,env,auth){
 let body=await request.json().catch(()=>null); const id=body?.sceneId;
 if(typeof id!=="string"||!Object.hasOwn(SCENES,id)) return json({error:"INVALID_SCENE_ID"},400);
 if(!env.IMAGENS_R2||!env.AI_BUDGET||!env.OPENAI_API_KEY) return json({error:"SCENE_SERVICE_UNAVAILABLE",message:"Geração de cenários indisponível; nenhuma cobrança foi iniciada."},503);
 const key=`cenarios/${id}.png`; const cached=await env.IMAGENS_R2.head(key);
 if(cached) return json({status:"cached",sceneId:id,imageUrl:new URL(`/api/scenes/image/${id}`,request.url).toString(),sizeBytes:cached.size,actualBRL:0});
 const month=monthBR(); const stub=env.AI_BUDGET.get(env.AI_BUDGET.idFromName("ascensao-global-monthly-ai"));
 const lockId=`scene_${crypto.randomUUID()}`;
 let lock; try{lock=await stub.fetch("https://budget/creature-image-lock",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({month,action:"creature_image_lock_acquire",creatureId:`scene_${id}`,lockId,ttlMs:150000})});}catch{return json({error:"SCENE_LOCK_UNAVAILABLE"},503);}
 if(lock.status===409){const retry=await env.IMAGENS_R2.head(key);if(retry)return json({status:"cached",sceneId:id,imageUrl:new URL(`/api/scenes/image/${id}`,request.url).toString(),sizeBytes:retry.size,actualBRL:0});return json({error:"SCENE_ALREADY_GENERATING",message:"Este cenário já está sendo criado por outro jogador. Aguarde e tente novamente."},409);}
 if(!lock.ok)return json({error:"SCENE_LOCK_FAILED"},503);
 try{
  const again=await env.IMAGENS_R2.head(key);if(again)return json({status:"cached",sceneId:id,imageUrl:new URL(`/api/scenes/image/${id}`,request.url).toString(),sizeBytes:again.size,actualBRL:0});
  const reservationId=`scene_image_${crypto.randomUUID()}`;
  const reserve=await stub.fetch("https://budget/reserve",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({month,action:"reserve",category:"other_ai",reservationId,reserveMicros:RESERVE_MICROS,minimumReserveMicros:RESERVE_MICROS})});
  if(reserve.status===429)return json({error:"MONTHLY_AI_BUDGET_REACHED",message:"O limite mensal compartilhado de R$ 48,00 foi atingido ou está reservado."},429);
  if(!reserve.ok)return json({error:"BUDGET_RESERVATION_FAILED"},503);
  const spec=SCENES[id]; let actualMicros=0;
  try{
   const prompt=[ "Create an original 16:9 horizontal battle environment background for a premium fantasy JRPG.", "Richly hand-painted 2D game environment with subtle detailed pixel-art texture, cinematic 2.5D depth, layered foreground/midground/background, coherent perspective, detailed terrain and atmosphere.", "Environment only: absolutely no people, heroes, monsters, creatures, animals, UI, text, letters, logos or watermarks.", "Leave clear playable ground across the lower third for game combatants. Never use geometric zig-zag patterns or abstract triangles.", `Location: ${spec.name}`, spec.prompt ].join("\n");
   const response=await fetch("https://api.openai.com/v1/images/generations",{method:"POST",headers:{Authorization:`Bearer ${env.OPENAI_API_KEY}`,"Content-Type":"application/json"},body:JSON.stringify({model:MODEL,prompt,size:"1536x1024",quality:"high",output_format:"png",n:1}),signal:AbortSignal.timeout(110000)});
   if(!response.ok){await settle(stub,month,reservationId,0).catch(()=>false);return json({error:"SCENE_PROVIDER_FAILED"},502);}
   const result=await response.json();const usage=result.usage||{};const input=usage.input_tokens_details||{};const output=usage.output_tokens_details||{};
   const textTokens=input.text_tokens??usage.input_tokens;const imageTokens=input.image_tokens??0;const outTokens=output.image_tokens??usage.output_tokens;
   if(!Number.isSafeInteger(textTokens)||!Number.isSafeInteger(imageTokens)||!Number.isSafeInteger(outTokens)){return json({error:"SCENE_USAGE_UNAVAILABLE"},503);}
   actualMicros=Math.ceil((textTokens*2.5+imageTokens*4+outTokens*15)*9);
   if(actualMicros>RESERVE_MICROS){await settle(stub,month,reservationId,0).catch(()=>false);return json({error:"SCENE_COST_EXCEEDS_RESERVE"},503);}
   const encoded=result?.data?.[0]?.b64_json;if(typeof encoded!=="string")return json({error:"SCENE_IMAGE_INVALID"},502);
   const bytes=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
   const png=bytes.length>=8&&bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71&&bytes[4]===13&&bytes[5]===10&&bytes[6]===26&&bytes[7]===10;
   if(!png||bytes.length>MAX_BYTES){await settle(stub,month,reservationId,actualMicros).catch(()=>false);return json({error:"SCENE_IMAGE_INVALID"},502);}
   await env.IMAGENS_R2.put(key,bytes,{httpMetadata:{contentType:"image/png",cacheControl:"public, max-age=31536000, immutable"},customMetadata:{sceneId:id,model:MODEL,createdBy:auth.uid}});
   const settled=await settle(stub,month,reservationId,actualMicros).catch(()=>false);
   return json({status:"generated",sceneId:id,imageUrl:new URL(`/api/scenes/image/${id}`,request.url).toString(),sizeBytes:bytes.length,actualBRL:actualMicros/1000000,budgetSettlementPending:!settled},201);
  }catch{return json({error:"SCENE_GENERATION_FAILED",message:"Não foi possível concluir a geração do cenário."},502);}
 }finally{await stub.fetch("https://budget/creature-image-lock",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({month,action:"creature_image_lock_release",creatureId:`scene_${id}`,lockId})}).catch(()=>null);}
}
export async function handleWorldSceneRequest(request,env){
 const id=new URL(request.url).pathname.match(/^\/api\/scenes\/image\/([A-Za-z0-9_-]{1,40})$/)?.[1];
 if(!id||!Object.hasOwn(SCENES,id)||!env.IMAGENS_R2)return new Response("Not found",{status:404});
 const object=await env.IMAGENS_R2.get(`cenarios/${id}.png`);if(!object)return new Response("Not found",{status:404});
 const headers=new Headers();object.writeHttpMetadata(headers);headers.set("Content-Type","image/png");headers.set("Cache-Control","public, max-age=31536000, immutable");headers.set("Access-Control-Allow-Origin","*");return new Response(object.body,{headers});
}
