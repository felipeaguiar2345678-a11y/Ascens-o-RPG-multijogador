# Critérios visuais obrigatórios — Mini Versão Completa

Este documento é um bloqueio de aceite da mini versão. Não autoriza distribuir APK de teste antes de todos os itens obrigatórios estarem integrados e verificados no jogo executável.

## Regra de qualidade

- Não aceitar retângulos, formas geométricas, ícones genéricos ou sprites temporários como representação final de cenário, personagem, criatura, arma ou habilidade.
- Não considerar uma arte promocional, mockup ou imagem isolada como integração concluída: o recurso precisa aparecer no gameplay, respeitar escala, orientação, colisão quando aplicável, animação e estado de equipamento.
- A área jogável pode ser pequena, mas tudo que estiver nela deve ter acabamento final coerente entre si.
- Priorizar recursos originais/gratuitos e cache local. Não contratar, ativar ou consumir serviço pago de geração sem aprovação explícita do responsável pelo projeto.
- Manter desempenho em Android: atlas/spritesheets quando adequado, texturas dimensionadas, animações econômicas, carregamento sob demanda e ausência de geração de arte em tempo real durante exploração.

## Entregas visuais obrigatórias

### 1. Mundo — Clareira Inicial e Floresta Arcana
- [ ] Cenário top-down contínuo com terreno pintado/detalhado, variação de solo e transições naturais entre biomas.
- [ ] Vegetação em camadas: árvores com copas, arbustos, grama, flores, raízes e elementos de primeiro plano.
- [ ] Rios e margens legíveis, pedras, elevações, trilhas, clareiras e limites naturais.
- [ ] Construções/vilas com silhueta, telhados, portas, janelas e detalhes; sem caixas provisórias.
- [ ] Aurelia reconhecível ao sul/ao fundo, com composição de distância e atmosfera.
- [ ] Iluminação, sombras e paleta coerentes durante dia/noite; eventos celestes sem halo artificial ao redor da lua.
- [ ] Colisões alinhadas à arte, sem bloquear áreas visualmente livres nem permitir atravessar obstáculos sólidos.

### 2. Personagens, raças e equipamento
- [ ] Modelos/sprites finais de frente, costas, esquerda e direita.
- [ ] Humano, elfo (orelhas), anão (proporção menor) e draconiano (chifres/asas), com silhuetas distinguíveis.
- [ ] Apresentações masculina e feminina sem quebrar a compatibilidade com equipamentos.
- [ ] Animações de repouso, caminhada e ações essenciais nas quatro direções.
- [ ] Armaduras leves, médias e pesadas visivelmente diferentes e realmente aplicadas ao personagem.
- [ ] Arma equipada aparece na mão correta e acompanha as animações sem atravessar o corpo.
- [ ] Companheiro/pet possui corpo, animação e escala próprios; não criar seguidores humanos.

### 3. Criaturas e ecologia
- [ ] Cada espécie incluída tem arte própria, anatomia legível, escala e paleta identificáveis.
- [ ] Animações mínimas de repouso, deslocamento e ataque; reações de dano/derrota quando aplicável.
- [ ] Líderes, filhotes e variantes raras distinguíveis por sinais visuais coerentes, não apenas texto/cor de etiqueta.
- [ ] Criaturas aquáticas, florestais e montanhosas aparecem em ambientes compatíveis.
- [ ] Efeitos de habilidades e elementos não escondem a leitura da criatura nem prejudicam a taxa de quadros.

### 4. Combate, habilidades e Supremas
- [ ] Palco de combate ilustrado e coerente com o bioma, com profundidade e posições claras de jogador e inimigo.
- [ ] Personagem visto por trás e criatura pela frente, usando os mesmos modelos/identidade do mundo.
- [ ] Animações de ataque, defesa, dano, carga, quebra de postura e derrota.
- [ ] Habilidades têm efeitos próprios e legíveis; quatro espaços visuais de ação não podem ser apenas botões genéricos.
- [ ] Supremas têm escala visual de chefe, impacto no cenário e efeitos sincronizados para participantes da luta.
- [ ] Até três alvos devem permanecer visualmente selecionáveis sem confusão.

### 5. Armas One Piece
- [ ] Modelos reconhecíveis e fiéis às referências aprovadas, com bainha, guarda, lâmina e proporções coerentes.
- [ ] Wado Ichimonji, Sandai Kitetsu e Enma podem compor a Tripla Katana em um único espaço de equipamento.
- [ ] Murakumogiri/Bisento deve ter silhueta de bisento, não uma espada genérica.
- [ ] Materiais, raridade, efeitos e animações de ataque devem ser visíveis no gameplay.
- [ ] Supremas exclusivas devem demonstrar seu efeito no mundo; a Murakumogiri precisa transmitir distorção/rachaduras espaciais e ondas de choque devastadoras.

## Integração técnica e aceite

- [ ] Recursos organizados em pastas por domínio (mundo, personagens, criaturas, armas, combate e interface), com nomes estáveis.
- [ ] Cada recurso referenciado por cenas/scripts reais; nenhum arquivo órfão contado como entrega.
- [ ] Spritesheets/atlas com pivôs, margens e quadros documentados; transparência limpa e sem fundos acidentais.
- [ ] Verificação de orientação, escala, recorte, camadas, colisão e animação em execução.
- [ ] Capturas de cada área/tela de gameplay e checklist de revisão visual registrados no repositório.
- [ ] Testes automatizados verificam referências ausentes e carregamento dos recursos visuais centrais.
- [ ] Revisão de desempenho em dispositivo Android de referência antes de declarar a mini versão pronta.

## Bloqueio de distribuição

A mini versão só pode ser declarada completa quando os sistemas multiplayer, mundo, ecologia, combate, progressão e persistência estiverem integrados **e** todos os critérios visuais obrigatórios acima tiverem evidência de execução. Compilar scripts ou carregar cenas vazias não comprova acabamento visual. Até lá, não gerar nem entregar APK para teste do usuário.


## Referência oficial de apresentação das armas (aprovada em 26/11/2026)

A imagem de referência enviada pelo responsável define o padrão de acabamento e apresentação:

- **Inventário:** miniatura individual da arma em moldura ornamental, com fundo escuro e leitura clara da silhueta, mantendo nome e raridade na interface.
- **Personagem equipado:** arte da arma em tamanho proporcional ao corpo, presa ao ponto da mão/empunhadura do personagem. A arma acompanha orientação, movimento, saque, guarda e animações de combate; não pode flutuar como ícone solto.
- **Identidade consistente:** miniatura e arte equipada pertencem ao mesmo ID persistente de item. Não criar duas armas desconectadas.
- **Acabamento:** preservar lâmina, guarda, bainha, empunhadura, ornamentos, materiais e cores próprios de cada arma. A Kikoku e a Gryphon da referência são exemplos de silhueta e detalhamento, não modelos genéricos a serem copiados para todas.
- **Orientação:** cada direção do personagem precisa de posicionamento/pivô de mão ajustado, sem atravessar o corpo nem inverter detalhes assimétricos.
- **Implementação atual:** `scripts/apresentacao_arma.gd` define o vínculo de IDs com caminhos separados de miniatura e textura equipada, e o avatar passa a usar esse nó. As texturas finais ainda precisam ser criadas e integradas em `assets/armas/inventario/` e `assets/armas/equipadas/`; ausência de textura não pode gerar desenho geométrico substituto.
- **Armas prioritárias para o primeiro pacote:** Kikoku, Gryphon, Wado Ichimonji, Sandai Kitetsu, Enma, Tripla Katana e Murakumogiri.

A implementação do vínculo técnico não significa que a arte esteja pronta. O aceite visual exige os arquivos finais, inspeção em jogo nas quatro direções e capturas de evidência.
