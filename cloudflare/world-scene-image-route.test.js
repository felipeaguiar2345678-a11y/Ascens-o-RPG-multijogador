import test from "node:test";
import assert from "node:assert/strict";
import { handleWorldSceneGeneration, handleWorldSceneRequest } from "./world-scene-image-route.js";
test("id de cenário é limitado à lista oficial e não reserva orçamento",async()=>{
 let calls=0;const env={AI_BUDGET:{get:()=>({fetch:async()=>{calls++;return new Response("{}")}})},IMAGENS_R2:{head:async()=>null}};
 const r=await handleWorldSceneGeneration(new Request("https://x/api/scenes/image",{method:"POST",body:JSON.stringify({sceneId:"prompt_injetado"}),headers:{"Content-Type":"application/json"}}),env,{uid:"u"});
 assert.equal(r.status,400);assert.equal(calls,0);
});
test("cenário existente no R2 é reutilizado sem IA nem reserva",async()=>{
 const env={IMAGENS_R2:{head:async()=>({size:123})}};
 const r=await handleWorldSceneGeneration(new Request("https://x/api/scenes/image",{method:"POST",body:JSON.stringify({sceneId:"neve"}),headers:{"Content-Type":"application/json"}}),env,{uid:"u"});
 const b=await r.json();assert.equal(r.status,200);assert.equal(b.status,"cached");assert.equal(b.actualBRL,0);
});
test("imagem de cenário só é servida para identificador oficial",async()=>{
 const env={IMAGENS_R2:{get:async key=>key==="cenarios/neve.png"?{body:new Uint8Array([1]),writeHttpMetadata:()=>{}}:null}};
 const ok=await handleWorldSceneRequest(new Request("https://x/api/scenes/image/neve"),env);
 const bad=await handleWorldSceneRequest(new Request("https://x/api/scenes/image/qualquer"),env);
 assert.equal(ok.status,200);assert.equal(bad.status,404);
});
