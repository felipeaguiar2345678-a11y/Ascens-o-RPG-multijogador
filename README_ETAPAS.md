# Histórico de etapas — Ascensão do Soberano

- **Etapa 01 — Segurança e estrutura:** auditoria das regras Firestore, propriedade dos documentos e repositório visual. Consulte `ALTERACOES_ETAPA_01_SEGURANCA.md`.
- **Etapa 02 — Geração visual de personagens:** serviço Android autenticado, controle de geração única, atualização do perfil e extensão Cloudflare com orçamento reservado e R2. Consulte `ALTERACOES_ETAPA_02_GERACAO_VISUAL.md` e `cloudflare/INTEGRAR_GERACAO_VISUAL_NO_WORKER.md`.
- **Etapa 03 — Criaturas:** validação da geração, catálogo global imutável, UID do primeiro registrador e regras do bestiário. Consulte `ALTERACOES_ETAPA_03_CRIATURAS.md`.
- **Etapa 04 — Imagens das criaturas:** serviço Android, registro dos metadados em subcoleção imutável, regras de acesso e extensão Cloudflare com orçamento `other_ai` e armazenamento R2. Consulte `ALTERACOES_ETAPA_04_IMAGENS_CRIATURAS.md` e `cloudflare/INTEGRAR_IMAGENS_CRIATURAS_NO_WORKER.md`.

Cada ZIP de etapa é uma cópia completa do projeto naquele ponto. Mantenha os ZIPs anteriores como backups e não os substitua. O `worker.js` permanece no GitHub na branch `feature/ai-budget-categories`; as rotas da Etapa 04 já foram integradas, mas ainda exigem deploy e validação no Cloudflare.

- **Multiplayer Etapa 05 — Guildas e expansão:** criação/entrada/saída segura de guildas e painel na aba Multiplayer. Consulte `MULTIPLAYER_ETAPA_05_GUILDAS_E_EXPANSAO.md`.

## Etapa 06 — Expansão do Multiplayer
- Masmorras cooperativas com cinco salas, três dificuldades, criaturas do bestiário global, formação e funções de equipe.
- Acampamento compartilhado da guilda, evoluindo com atividades e concedendo bônus de XP.
- Chefes mundiais compartilhados por ecossistema e temporada.
- Arena PvP voluntária com pareamento por rating.
- Rankings globais de nível, masmorras, chefes, arena e guildas.
- Eventos sazonais mensais com progresso individual/global e recompensa única.
- Combos Ally e reanimação de aliados.
- Ver `MULTIPLAYER_ETAPA_06_EXPANSAO_COMPLETA.md` para detalhes e limitações de implantação.

## Etapa 07 — Economia e Ferreiros
- Ouro como moeda persistente, recebido ao derrotar criaturas e dividido entre participantes de combate Ally.
- Materiais com ranks de Comum a World, origem e propriedades herdadas da criatura/bioma.
- Ferreiros nas capitais, cidades e vilas; especialidades regionais.
- Consulta em português com interpretação local gratuita, receitas derivadas dos materiais do inventário e fabricação com custo em ouro.
- Consulte `ECONOMIA_FERREIRO_ETAPA_07.md` para fórmulas, regras e limitações.
