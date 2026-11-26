# Padrão visual global — todas as armas e equipamentos de Ascensão do Soberano

Este guia transforma a referência visual aprovada em padrão obrigatório de produção para **todo o jogo**, desde a mini versão até as expansões futuras. Não se limita às sete armas prioritárias.

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

## Primeiro lote de produção da mini versão

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


## Escopo global obrigatório — jogo inteiro

O padrão de qualidade da referência se aplica a **100% das armas e equipamentos existentes ou que forem adicionados ao jogo**, não apenas ao primeiro lote. Nenhum item pode ficar permanentemente representado por um ícone genérico, quadrado colorido, silhueta provisória ou desenho geométrico.

### Armas

Cada arma terá identidade artística própria e, conforme seu uso, arte de inventário e modelo/recorte equipado:
- espadas, katanas, nodachis, sabres, adagas e conjuntos de lâminas;
- bisentos, lanças, tridentes, machados, martelos e foices;
- arcos, bestas, armas de fogo e munições, quando disponíveis no jogo;
- cajados, varinhas, grimórios, focos mágicos e instrumentos de invocação;
- escudos, armas duplas, garras, manoplas, chicotes e armas especiais;
- armas vivas, lendárias, míticas, supremas, transformáveis e itens com formas alternativas.

### Armaduras e vestimentas

Cada peça terá miniatura própria e aparência real no corpo do personagem:
- capacetes, elmos, máscaras, coroas, capuzes e acessórios de cabeça;
- peitorais, túnicas, robes, casacos, mantos, capas e ombreiras;
- luvas, manoplas, braçadeiras, cintos e acessórios de braço;
- calças, saias, grevas, botas e calçados;
- armaduras leves, médias e pesadas, com silhuetas e materiais diferentes;
- conjuntos raciais, peças cosméticas, roupas comuns, equipamentos raros e peças de chefe.

### Acessórios e equipamentos especiais

Anéis, colares, amuletos, brincos, talismãs, relíquias, mochilas, instrumentos, artefatos, itens de mão secundária e equipamentos de mascote também seguem o mesmo padrão de acabamento no inventário. Quando equipáveis e visíveis, precisam aparecer no local correto do modelo.

### Consistência entre inventário e personagem

- A miniatura e a representação equipada devem usar o mesmo ID canônico do item.
- A miniatura deve mostrar o item completo, em composição limpa e legível.
- A representação equipada deve respeitar escala, anatomia, encaixe, material, iluminação e orientação.
- Equipamentos em camadas precisam respeitar a ordem de desenho e não atravessar corpo, roupa ou outras peças.
- As quatro direções do personagem devem ser tratadas; itens assimétricos não podem ser espelhados incorretamente.
- Raça, sexo, porte corporal e tipo de armadura devem ser considerados nos encaixes.
- Mascotes e montarias equipáveis, se introduzidos, também precisam de seus próprios visuais e pontos de encaixe.

### Qualidade e desempenho

A exigência é acabamento final, não significa usar texturas enormes sem otimização. Os arquivos devem ser otimizados para Android, com transparência real, compressão/importação adequada, atlas quando fizer sentido e variantes de resolução. A otimização não pode apagar detalhes essenciais nem substituir arte individual por placeholders.

### Critério de aceite para qualquer item

Um item só é considerado concluído quando:
1. tem arte original/definitiva de inventário;
2. tem modelo/arte equipada compatível, se for equipável e visível;
3. está ligado ao ID correto do item e aos dados de raridade/categoria;
4. aparece corretamente no personagem em todas as direções e animações pertinentes;
5. foi conferido em tela de inventário e em gameplay;
6. não usa placeholder nem textura de outro item como substituto.

### Regra de produção

O catálogo de armas de One Piece é apenas uma parte do universo de itens. A produção deve seguir por lotes organizados por categoria e raridade, mantendo uma lista de progresso por ID. **A mini versão só precisa conter o conjunto de itens definido para ela, mas cada item incluído já deve usar arte final. O restante do jogo deverá receber o mesmo padrão antes de ser disponibilizado em suas respectivas atualizações.** Não é permitido relaxar o padrão visual nas expansões.


## Cobertura do catálogo atual — 26/11/2026

Foi criado `scripts/catalogo_visual_equipamentos.gd` com IDs e caminhos visuais individuais para **85 itens** encontrados nos catálogos atuais de equipamentos e armas de One Piece. O registro contempla armas base, escudos, armaduras, acessórios e as armas nomeadas.

Estrutura global:
- `assets/equipamentos/inventario/<id>.png`
- `assets/equipamentos/equipados/<id>.png`

O sistema de apresentação de armas consulta primeiro os registros especiais (quando existem) e depois o catálogo visual global. Isso permite estender a apresentação sem manter um catálogo isolado por categoria.

**Importante:** o registro de caminhos não significa que as 170 imagens estejam prontas. Os arquivos finais ainda precisam ser produzidos, adicionados, ligados aos slots/camadas adequados e validados visualmente. O escopo visual cobre todos os itens do jogo, enquanto os lotes de produção são entregues progressivamente.
