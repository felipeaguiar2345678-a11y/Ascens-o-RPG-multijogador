# Avatares raciais no mundo multiplayer

## Estado atual

O projeto agora possui uma camada visual procedural provisória em `godot/scripts/avatar_personagem.gd`. Ela usa somente dados cosméticos recebidos do perfil validado pelo servidor: nome, sexo, aparência, raça, classe e anatomia racial.

O personagem local e os jogadores remotos usam o mesmo gerador visual. O servidor transmite aos outros clientes apenas os campos públicos necessários para identificar e desenhar o avatar. UID, inventário, atributos e demais dados privados não são enviados nesse pacote visual.

## Traços representados

- Humano: proporção equilibrada e aparência humana.
- Elfo: silhueta esguia e orelhas pontudas.
- Anão: estatura reduzida e corpo mais largo/robusto.
- Orc: pele esverdeada, orelhas características e presas.
- Fera: orelhas animais e cauda.
- Draconiano: chifres, asas recolhidas, cauda e detalhes de escamas.
- Silvestre: marcas vegetais e orelhas alongadas.
- Umbral: tons sombrios e olhos luminosos.\n- Gigante: corpo colossal, muito mais alto e largo, com bônus de vida e defesa e penalidades de velocidade.

Sexo e opção de aparência alteram cabelo e detalhes disponíveis. A altura vem da anatomia racial armazenada no perfil.

## Limitações assumidas

Esta etapa usa polígonos simples para provar o contrato de dados e a diferenciação das silhuetas. Não é a arte final pixel art, não possui animações de caminhada/ataque, equipamentos visuais completos, iluminação, retratos ou variações detalhadas de rosto. As asas draconianas são representadas recolhidas e não têm animação.

A próxima evolução visual deve substituir os polígonos por sprites pixel art modulares, mantendo o perfil e os identificadores de raça/aparência. Equipamentos devem ser camadas separadas e jamais esconder traços anatômicos raciais como orelhas, chifres, asas ou caudas.

## Validação

O teste headless verifica que os avatares anão, élfico e draconiano geram partes visuais e respeitam as alturas configuradas. O fluxo multiplayer também sincroniza a aparência pública dos jogadores que entram no mundo.

## Gigante\n\nA raça Gigante possui bônus racial de 25% na vida máxima e 20% na defesa, além de +4 Força e +5 Vitalidade nos atributos-base. Em contrapartida, recebe -2 Agilidade, movimento 12% mais lento e velocidade de ataque 8% menor (o modificador de ataque fica registrado no perfil para aplicação pelo sistema de combate). Sua anatomia usa escala de 1,35 na altura e 1,32 na largura.\n