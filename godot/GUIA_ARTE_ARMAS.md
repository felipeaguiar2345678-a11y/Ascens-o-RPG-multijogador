# Guia de produção — arte final das armas

Este guia transforma a referência visual aprovada em especificação de produção para a mini versão.

## Duas artes do mesmo item

Cada arma usa um único `item_id` e dois arquivos relacionados:

- `assets/armas/inventario/<id>.png`: composição de inventário, arma inteira legível em miniatura, fundo transparente, moldura ornamental aplicada pela interface (não gravar texto ou raridade na imagem).
- `assets/armas/equipadas/<id>.png`: recorte transparente da arma isolada, vista lateral/diagonal adequada à mão do personagem, sem personagem, sem moldura e sem texto.

A moldura, nome, raridade e atributos são componentes da interface. A imagem da arma não deve conter letras, logotipos ou informações que fiquem ilegíveis em tamanhos pequenos.

## Requisitos técnicos

- PNG RGBA com transparência real; sem fundo quadriculado falso.
- Silhueta e detalhes reconhecíveis em escala reduzida.
- Resolução de origem suficiente para telas Android de alta densidade; exportar variantes otimizadas quando necessário.
- Pivô de empunhadura documentado por arma; a textura equipada deve ser posicionada pela empunhadura, não pelo centro geométrico.
- Manter a orientação original e os detalhes assimétricos; não espelhar arte que tenha inscrições, guarda ou ornamentos direcionais.
- Texturas comprimidas/importadas pelo Godot para reduzir memória, mantendo a nitidez das lâminas e ornamentos.
- Não usar uma imagem genérica para representar armas diferentes.

## Integração e aceite

1. Registrar o ID canônico em `scripts/apresentacao_arma.gd`.
2. Adicionar as duas imagens nos caminhos correspondentes.
3. Definir escala, pivô e offsets de mão para frente, costas, esquerda e direita.
4. Confirmar que o avatar usa a textura equipada e que o inventário usa a miniatura do mesmo ID.
5. Capturar evidência dentro do jogo em inventário e exploração, nas quatro orientações.
6. Verificar saque, guarda, caminhada, corrida e animações de ataque.
7. Não aprovar se a arma atravessar o corpo, flutuar, ficar desconectada da mão ou desaparecer numa direção.

## Pacote prioritário da mini versão

| ID | Nome | Referência de identidade |
|---|---|---|
| `kikoku` | Kikoku | Nodachi de Trafalgar Law; bainha escura com cruzes claras, empunhadura roxa e cordões vermelhos |
| `gryphon` | Gryphon | Sabre de Shanks; guarda dourada curva e empunhadura verde-escura |
| `wado_ichimonji` | Wado Ichimonji | Katana de lâmina clara e empunhadura branca |
| `sandai_kitetsu` | Sandai Kitetsu | Katana com identidade própria e detalhes vermelhos |
| `enma` | Enma | Katana com empunhadura roxa e guarda característica |
| `tripla_katana` | Tripla Katana | Equipamento único Santoryu, três lâminas visíveis, um espaço no inventário |
| `murakumogiri` | Murakumogiri (Bisento) | Bisento de Barba Branca, escala e ornamentação próprias |

A Tripla Katana é uma combinação de Wado Ichimonji, Sandai Kitetsu e Enma e ocupa um único espaço, conforme o catálogo do jogo. A apresentação precisa mostrar o conjunto, não uma quarta espada genérica.

## Estado real

O catálogo de caminhos e o ponto de integração no avatar/inventário estão implementados. **As imagens finais não estão presentes no repositório ainda.** Nenhuma arma pode ser considerada visualmente concluída até os arquivos reais estarem integrados e inspecionados no jogo.
