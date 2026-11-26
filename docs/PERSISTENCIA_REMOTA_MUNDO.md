# Persistência remota do mundo único

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

A persistência remota permanece DESATIVADA. Nenhum banco D1 foi criado, nenhum segredo foi configurado e nenhum serviço foi contratado.

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

A eleição de host único está integrada, mas o cliente remoto e a API ainda não substituem os repositórios locais. Personagens, serpente, ecologia, salas e demais dados continuam gravados localmente no volume do contêiner. Portanto, **a lease não significa que o mundo já esteja sincronizado entre instalações/hosts**. A migração dos repositórios para D1, com importação segura dos dados existentes, revisões CAS e recuperação testada, continua pendente. **O mundo ainda não está migrado para D1.** A próxima etapa é migrar os repositórios em sequência, com cópia inicial, verificação de integridade, escrita remota autoritativa e plano de rollback. Só então a troca de host poderá recuperar o mundo a partir do banco remoto.

O lease é uma proteção de infraestrutura preparada e testada, mas ainda não está conectado ao ciclo de inicialização/renovação do servidor de jogo. Não habilite múltiplas instâncias do servidor antes dessa integração e da migração transacional de todas as operações de jogo.
