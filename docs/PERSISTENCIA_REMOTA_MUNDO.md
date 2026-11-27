# Persistência remota do mundo único

## Estado atual da migração

O documento `world_boss` (Serpente do Mundo/Jǫrmungandr) agora usa D1 como fonte autoritativa no fluxo do servidor dedicado. O documento `world_clock` também passou a fixar a semente imutável do calendário global em D1, com migração única do cache local e leitura obrigatória antes de abrir a porta ENet. A inicialização lê primeiro a revisão remota antes de expor a porta ENet. Se o documento remoto ainda não existir (revisão zero), importa o estado local validado como migração inicial; se já existir, o banco remoto prevalece e atualiza o cache local. Cada mudança da Serpente é confirmada por revisão CAS antes de ser publicada aos clientes. Falha de rede, conflito de revisão, lease perdida ou falha do cache local fecha o host para impedir divergência. O JSON local permanece como cache/backup de recuperação, não como autoridade.

O documento `ecological_resources` agora também usa D1 como fonte autoritativa: o servidor importa uma única vez o estoque local validado quando a revisão remota é zero, carrega o snapshot remoto antes de simular a ecologia e confirma cada ciclo alimentar com revisão CAS antes de continuar. Payload inválido, conflito ou falha de rede fecha o host. O arquivo local permanece como cache/backup.

A fauna usa D1 em 16 fragmentos estáveis, de wildlife_groups_00 a wildlife_groups_0f. Cada grupo é atribuído por hash determinístico do identificador e mantém indivíduos, população, liderança, carcaças, relações, migração e histórico no mesmo registro. Na inicialização, fragmentos remotos existentes prevalecem; fragmentos sem revisão recebem a migração local correspondente. Alterações são comparadas e gravadas por revisão CAS após ciclos ecológicos e salvamento periódico do movimento. Fragmento inválido, acima do limite de 900 KB, conflito ou falha de rede fecha o host. Uma importação interrompida pode ser retomada sem reimportar fragmentos já confirmados.

Os perfis de personagens também passaram a usar documentos D1 individuais (`character_` + SHA-256 do UID). A chave não revela o UID e cada perfil fica abaixo do limite de 900 KB. Na autenticação, o servidor lê o documento remoto antes de carregar o cache local; se a revisão for zero, valida e migra somente aquele perfil por CAS. A partir daí, o documento remoto prevalece. Salvamentos locais validados são sincronizados por UID com escritas serializadas e revisão CAS; o host fecha se a confirmação remota falhar. No desligamento normal, o servidor aguarda gravações pendentes e confirma os perfis antes de liberar a lease. O cliente nunca recebe o segredo D1.

As trocas entre dois personagens agora usam a rota `/api/server/character-trade`: o D1 confirma as duas revisões e atualiza os dois documentos dentro de um único `batch` transacional. Um ledger com identificador e impressão digital torna a operação idempotente; se uma das revisões não corresponder, nenhuma das duas alterações é aplicada. O servidor só anuncia a troca depois de receber as duas novas revisões. A migração `0002_atomic_character_trades.sql` cria o ledger necessário.

O catálogo de espécies e suas estatísticas globais usam o documento D1 `creatures`, carregado antes de abrir ENet e sincronizado com revisão CAS. Eventos temporários e narrativas globais usam `world_events`; a semente do calendário usa `world_clock`. Mímicos e suas reservas usam `mimics`, enquanto o progresso de piedade/recompensas pendentes por UID usa `mimic_pity`. Allys usam `allies`; salas cooperativas e progresso narrativo usam `cooperative_rooms`. Esses documentos são recuperados do D1 na inicialização e suas alterações são confirmadas antes da publicação quando passam pelos respectivos fluxos do servidor. O catálogo também guarda estatísticas de descoberta/derrotas das espécies; não há um repositório independente de descobertas nesta arquitetura.

## Ciclo ecológico atômico (migração 0003)

A atualização dos recursos e da fauna agora é confirmada como uma única transação D1. A migração `0003_atomic_world_cycles.sql` cria o ledger `world_cycle_transactions`, que registra o identificador e a impressão digital de cada ciclo para impedir reaplicação com conteúdo diferente.

O endpoint `POST /api/server/world-cycle` exige autenticação servidor-servidor e lease ativa. Cada chamada precisa conter exatamente 17 documentos: `ecological_resources` e os 16 fragmentos `wildlife_groups_00` a `wildlife_groups_0f`. O Worker valida o conjunto completo e as 17 revisões esperadas antes de gravar. O marcador de transação e as alterações dos documentos são enviados em um único `D1Database.batch()`; no D1, o batch é transacional. Um conflito de revisão rejeita o ciclo inteiro (HTTP 409), e a repetição com o mesmo identificador e impressão digital é idempotente.

O bootstrap inicial também foi ajustado: recursos e fragmentos de fauna começam na revisão zero e são criados juntos no primeiro commit atômico, evitando migração parcial. No servidor Godot, o ciclo alimentar calcula os novos snapshots e só publica a confirmação depois do commit conjunto. A execução dos ciclos alimentares é serializada para evitar duas simulações concorrentes no mesmo host.

A garantia de atomicidade é implementada pelo D1 e exercitada por testes automatizados, incluindo conflito de revisão, repetição idempotente e falha simulada no meio do batch com rollback. A CI local não substitui um teste de implantação contra a conta Cloudflare de produção.

## O que foi preparado

A API Cloudflare Worker oferece armazenamento de documentos globais em D1:

- Um único identificador lógico: `ascensao_global`.
- Documentos separados para personagens, catálogo de criaturas, grupos ecológicos, recursos, salas, chefe mundial, relógio e eventos.
- Acesso somente servidor-servidor por segredo `WORLD_STORAGE_TOKEN`; o cliente do jogo não recebe essa credencial.
- Controle otimista de concorrência por revisão. Uma gravação só é aceita se `expectedRevision` ainda for a revisão atual; conflito retorna HTTP 409 e não sobrescreve dados recentes.
- Lease de escritor único por mundo, com expiração de 15 a 60 segundos, renovação e liberação condicionadas à identidade/token do host. Um segundo host recebe HTTP 409 enquanto o lease anterior estiver válido.
- Payload JSON limitado a 900 KB por documento.
- Nomes de documentos permitidos por lista explícita e padrões fechados: 16 fragmentos de fauna e documentos individuais `character_` com sufixo SHA-256 hexadecimal de 64 caracteres.
- Banco ausente, segredo ausente ou inválido resultam em falha fechada, sem fallback silencioso.

## Arquivos

- `migrations/0001_world_documents.sql`: tabelas D1 de documentos globais e lease de escritor único.
- `migrations/0002_atomic_character_trades.sql`: ledger idempotente para trocas bilaterais atômicas.
- `migrations/0003_atomic_world_cycles.sql`: ledger idempotente para commits ecológicos atômicos de 17 documentos.
- `worker.js`: rotas `GET` e `PUT /api/server/world-state/{documento}`, além de `POST /api/server/character-trade` e `POST /api/server/world-cycle`.
- `tests/world-state.test.mjs`: testes de autenticação, configuração ausente, gravação inicial, conflito de revisão e leitura.
- `tests/world-cycle.test.mjs`: testes de atomicidade, conflito, replay idempotente, autorização e rollback após falha simulada.
- `../godot/scripts/repositorio_mundo_remoto.gd`: cliente HTTP exclusivo do servidor Godot, configurado por variáveis de ambiente, com geração de identidade efêmera e operações de lease.

## Ativação manual futura

A integração de código está preparada, mas a persistência de produção permanece DESATIVADA até confirmar a configuração real: nenhum banco D1 foi criado nem segredo configurado. A ativação depende da configuração manual descrita abaixo. O primeiro início real exige configurar o Worker/D1 e os segredos antes de subir o servidor dedicado.

Quando houver aprovação para habilitar:

1. Conferir os limites e preços vigentes do Cloudflare D1/Workers para o uso esperado.
2. Criar o banco D1 `ascensao-world-state` na conta Cloudflare escolhida.
3. Preencher o `database_id` real e ativar o binding `WORLD_STATE` em `wrangler.toml`.
4. Aplicar a migração com Wrangler no ambiente correto.
5. Criar um segredo aleatório forte com `npx wrangler secret put WORLD_STORAGE_TOKEN`.
6. Configurar no host dedicado `ASCENSAO_WORLD_STORAGE_URL` e `ASCENSAO_WORLD_STORAGE_TOKEN`.

Nunca coloque o token em Git, no APK ou em variáveis enviadas ao cliente.

## Ciclo de vida da lease no servidor dedicado

O entrypoint `godot/scripts/servidor_dedicado.gd` agora exige endpoint HTTPS, segredo e aquisição bem-sucedida da lease antes de iniciar ENet. Renova a cada 10 segundos com TTL de 30 segundos, fecha o servidor ao perder a autorização e tenta liberar a lease no encerramento normal. `RedeMultiplayer.iniciar_servidor` também recusa inicialização sem confirmação explícita da lease. O `docker-compose.servidor.yml` exige as duas variáveis no `.env` local.

## Limitação importante

A eleição de host único e a persistência remota autoritativa da Serpente, do calendário celeste, dos estoques ecológicos, dos 16 fragmentos de fauna, dos perfis de personagens, do catálogo de criaturas, das Allys, das salas cooperativas, dos eventos globais e dos sistemas de mímicos/piedade estão integradas no código. Isso cobre os principais estados compartilhados identificados na arquitetura atual, mas não equivale a implantação nem validação operacional em produção. Ainda é necessário verificar cada fluxo de mutação, a recuperação de backups e quaisquer novos dados de jogo adicionados no futuro. Portanto, **o mundo ainda não foi validado entre instalações reais**; a próxima etapa é auditar a cobertura de escrita/leitura dos sistemas restantes e executar os testes de implantação Cloudflare.

A lease está conectada ao ciclo de inicialização/renovação do servidor dedicado. Não considere a persistência global concluída antes da migração transacional dos repositórios restantes e da validação em ambiente Cloudflare real.
