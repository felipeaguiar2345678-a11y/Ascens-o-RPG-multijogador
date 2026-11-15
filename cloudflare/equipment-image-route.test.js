import test from "node:test";
import assert from "node:assert/strict";
import {
  handleEquipmentImageResolution,
  handleEquipmentImageRequest
} from "./equipment-image-route.js";

function request(body) {
  return new Request("https://ascensao-soberano-api.test/api/equipment/image", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
}

const validId = "equip_" + "a".repeat(64);

test("identificador inválido é rejeitado antes de consultar catálogo ou armazenamento", async () => {
  let storageCalls = 0;
  const response = await handleEquipmentImageResolution(
    request({ visualId: "../equipamento" }),
    { IMAGENS_R2: { head: async () => { storageCalls += 1; return null; } } }
  );
  const body = await response.json();
  assert.equal(response.status, 400);
  assert.equal(body.error, "INVALID_EQUIPMENT_VISUAL_ID");
  assert.equal(storageCalls, 0);
});

test("consulta não tenta geração nem exige chave de IA quando armazenamento não está configurado", async () => {
  const response = await handleEquipmentImageResolution(
    request({ visualId: validId }),
    {}
  );
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, "EQUIPMENT_IMAGE_STORAGE_NOT_CONFIGURED");
});

test("leitura pública rejeita identificadores fora do padrão do catálogo", async () => {
  const response = await handleEquipmentImageRequest(
    new Request("https://ascensao-soberano-api.test/api/equipment/image/equip_invalido"),
    { IMAGENS_R2: { get: async () => { throw new Error("não deveria consultar R2"); } } }
  );
  assert.equal(response.status, 404);
});
