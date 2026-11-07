# Etapa 07 — Economia, materiais e ferreiros

## Ouro
- O ouro é guardado em `PlayerInventory.gold` como `Long` e persiste no documento do personagem.
- Toda criatura derrotada gera ouro. O cálculo considera nível, XP-base, rank E–SSS, perigo e chefe.
- Fórmula-base: `(nível × 2 + XP-base × 0,35) × multiplicador de rank × (1 + perigo/100) × multiplicador de chefe`.
- Multiplicadores de rank: E 1,00; D 1,25; C 1,60; B 2,10; A 3,00; S 4,50; SS 7,00; SSS 11,00. Chefes multiplicam por 5.
- A variação é determinística por criatura para que todos os participantes de uma batalha compartilhada recebam a mesma parcela. Em grupo, o ouro é dividido igualmente entre participantes; em combate solo, o jogador recebe tudo.
- Nas masmorras, cada sala vencida acumula ouro pelo HP e rank da criatura; ao concluir, o total é dividido igualmente entre os participantes. Chefes mundiais também pagam ouro conforme o rank e a contribuição de dano de cada jogador.
- Materiais, equipamentos e ovos do combate Ally continuam seguindo a regra anterior de recompensa para quem causou mais dano.

## Materiais
- Materiais guardam rank, criatura de origem, ID da criatura e propriedades herdadas.
- Escala de rank: COMUM, INCOMUM, RARO, EPICO, LENDARIO, MITICO, DIVINO, ANCESTRAL e WORLD.
- A raridade do material acompanha a raridade da criatura quando o drop não informa uma raridade superior.
- Quando uma criatura não possui drop de material configurado, há 65% de chance de deixar um material natural de fallback, derivado de seu corpo/bioma.
- Propriedades reconhecidas incluem PREDADOR, NATUREZA, DRACONICO, GELO, FOGO, VENENO, ESPIRITUAL, MINERAL e AQUATICO.

## Ferreiros
- A aba **Ferreiro** usa a localização atual do personagem. Há ferreiro em capitais, cidades e vilas do mapa; locais sem povoado não permitem fabricação.
- Cidades principais têm especialidades próprias; demais povoados recebem um ferreiro local automaticamente.
- A caixa de conversa interpreta pedidos comuns em português por palavras-chave, sem chamar uma API paga. Exemplo: “O que consigo fazer com esses itens, velho?” mostra todas as receitas possíveis; “quero uma espada” filtra armas.
- As opções são montadas com materiais realmente disponíveis. Os atributos e efeitos vêm das propriedades dos materiais usados. Ex.: presa de criatura predadora favorece dano físico/agilidade; material vegetal favorece vitalidade/magia; mineral favorece defesa.
- A fabricação verifica ouro e quantidades, consome os materiais, desconta ouro e adiciona o equipamento ao inventário.
- O custo cresce com rank e poder calculado; equipamento de material WORLD é muito mais caro que equipamento comum. Os valores-base de material vão de 5 moedas (Comum) a 8.000 (World), antes do multiplicador de poder da receita.
- Equipamentos registram materiais e propriedades de origem para preservar rastreabilidade.

## Limites e segurança
- Esta etapa adiciona o sistema funcional no cliente e persiste os dados pelo repositório de perfil existente.
- Não foi ativado Blaze, não foram implantadas Cloud Functions nem regras Firebase e não houve deploy.
- Antes de economia competitiva pública, ouro, drops e fabricação precisam migrar para operações autoritativas no servidor, com transações e validação de propriedade, para impedir edição de inventário por cliente modificado.
- A conversa do ferreiro é uma interpretação local e gratuita nesta etapa; não usa modelo generativo externo nem cria custo de IA.
- Não há desgaste/durabilidade de equipamento implementado ainda; por isso não foi cobrada taxa de reparo. Melhorias e reparos poderão ser adicionados quando houver regras de desgaste e progressão definidas.
