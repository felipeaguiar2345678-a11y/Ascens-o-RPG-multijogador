# Persistência remota do mundo único

## Estado atual da migração

O documento `world_boss` (Serpente do Mundo/Jǫrmungandr) agora usa D1 como fonte autoritativa no fluxo do servidor dedicado. O documento `world_clock` também passou a fixar a semente imutável do calendário global em D1, com migração única do cache local e leitura obrigatória antes de abrir a porta ENet. A inicialização lê primeiro a revisão remota antes de expor a porta ENet. Se o documento remoto ainda não existir (revisão zero), importa o estado local validado como migração inicial; se já existir, o banco remoto prevalece e atualiza o cache local. Cada mudança da Serpente é confirmada por revisão CAS antes de ser publicada aos clientes. Falha de rede, conflito de revisão, lease perdida ou falha do cache local fecha o host para impedir divergência. O JSON local permanece como cache/backup de recuperação, não como autoridade.

O documento `ecological_resources` agora também usa D1 como fonte autoritativa: o servidor importa uma única vez o estoque local validado quando a revisão remota é zero, carrega o snapshot remoto antes de simular a ecologia e confirma cada ciclo alimentar com revisão CAS antes de continuar. Payload inválido, conflito ou falha de rede fecha o host. O arquivo local permanece como cache/backup.

A fauna usa D1 em 16 fragmentos estáveis, de wildlife_groups_00 a wildlife_groups_0f. Cada grupo é atribuído por hash determinístico do identificador e mantém indivíduos, população, liderança, carcaças, relações, migração e histórico no mesmo registro. Na inicialização, fragmentos remotos existentes prevalecem; fragmentos sem revisão recebem a migração local correspondente. Alterações são comparadas e gravadas por revisão CAS após ciclos ecológicos e salvamento periódico do movimento. Fragmento inválido, acima do limite de 900 KB, conflito ou falha de rede fecha o host. Uma importação interrompida pode ser retomada sem reimportar fragmentos já confirmados.

Os perfis de personagens também passaram a usar documentos D1 individuais (`character_` + SHA-256 do UID). A chave não revela o UID e cada perfil fica abaixo do limite de 900 KB. Na autenticação, o servidor lê o documento remoto antes de carregar o cache local; se a revisão for zero, valida e migra somente aquele perfil por CAS. A partir daí, o documento remoto prevalece. Salvamentos locais validados são sincronizados por UID com escritas serializadas e revisão CAS; o host fecha se a confirmação remota falhar. No desligamento normal, o servidor aguarda gravações pendentes e confirma os perfis antes de liberar a lease. O cliente nunca recebe o segredo D1.

Catálogo de criaturas, salas, eventos e descobertas ainda não foram migrados e continuam usando os repositórios locais. A sincronização global completa ainda não está concluída.

## O que foi preparado

A API Cloudflare Worker oferece armazenamento de documentos globais em D1:

- Um único identificador lógico: `ascensao_global`.
- Documentos separados para personagens, catálogo de criaturas, grupos ecológicos, recursos, salas, chefe mundial, relógio e eventos.
- Acesso somente servidor-servidor por segredo `WORLD_STORAGE_TOKEN`; o cliente do jogo não recebe essa credencial.
- Controle otimista de concorrência por revisão. Uma gravação só é aceita se `expectedRevision` ainda for a revisão atual; conflito retorna HTTP 409 e não sobrescreve dados recentes.
- Lease de escritor único por mundo, com expiração de 15 a 60 segundos, renovação e liberação condicionadas à identidade/token do host. Um segundo host recebe HTTP 409 enquanto o lease anterior estiver válido.
- Payload JSON limitado a 900 KB por documento.
- Nomes de documentos permitidos por lista explícita.
- Banco ausente, segredo ausente ou inválido resultam em falha fechada, sem fallback silencioso.

## Arquivos

- `migrations/0001_world_documents.sql`: tabelas D1 de documentos globais e lease de escritor único.
- `worker.js`: rotas `GET` e `PUT /api/server/world-state/{documento}`.
- `tests/world-state.test.mjs`: testes de autenticação, configuração ausente, gravação inicial, conflito de revisão e leitura.
- `../godot/scripts/repositorio_mundo_remoto.gd`: cliente HTTP exclusivo do servidor Godot, configurado por variáveis de ambiente, com geração de identidade efêmera e operações de lease.

## Ativação manual futura

A integração de código está preparada, mas a persistência de produção permanece DESATIVADA: nenhum banco D1 foi criado nem segredo configurado. A ativação depende da configuração manual descrita abaixo. O primeiro início real exige configurar o Worker/D1 e os segredos antes de subir o servidor dedicado.

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

A eleição de host único e a persistência remota autoritativa da Serpente, do calendário celeste e dos estoques ecológicos estão integradas no código. Entretanto, grupos/indivíduos da fauna, personagens, salas e demais sistemas continuam locais. Portanto, **o mundo inteiro ainda não está sincronizado entre instalações/hosts**. A próxima etapa é migrar os repositórios restantes em sequência, com importação segura, revisões CAS, integridade e plano de rollback.

A lease está conectada ao ciclo de inicialização/renovação do servidor dedicado. Não considere a persistência global concluída antes da migração transacional dos repositórios restantes e da validação em ambiente Cloudflare real.
