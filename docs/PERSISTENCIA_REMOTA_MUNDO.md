# Persistência remota do mundo único

## O que foi preparado

A API Cloudflare Worker oferece armazenamento de documentos globais em D1:

- Um único identificador lógico: `ascensao_global`.
- Documentos separados para personagens, catálogo de criaturas, grupos ecológicos, recursos, salas, chefe mundial, relógio e eventos.
- Acesso somente servidor-servidor por segredo `WORLD_STORAGE_TOKEN`; o cliente do jogo não recebe essa credencial.
- Controle otimista de concorrência por revisão. Uma gravação só é aceita se `expectedRevision` ainda for a revisão atual; conflito retorna HTTP 409 e não sobrescreve dados recentes.
- Payload JSON limitado a 900 KB por documento.
- Nomes de documentos permitidos por lista explícita.
- Banco ausente, segredo ausente ou inválido resultam em falha fechada, sem fallback silencioso.

## Arquivos

- `migrations/0001_world_documents.sql`: tabela D1 com chave composta por mundo/documento, revisão e JSON validado.
- `worker.js`: rotas `GET` e `PUT /api/server/world-state/{documento}`.
- `tests/world-state.test.mjs`: testes de autenticação, configuração ausente, gravação inicial, conflito de revisão e leitura.
- `../godot/scripts/repositorio_mundo_remoto.gd`: cliente HTTP exclusivo do servidor Godot, configurado por variáveis de ambiente.

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

## Limitação importante

O cliente remoto e a API estão preparados e testados isoladamente, mas os repositórios de jogo ainda leem e gravam seus arquivos locais. **O mundo ainda não está migrado para D1.** A próxima etapa é migrar os repositórios em sequência, com cópia inicial, verificação de integridade, escrita remota autoritativa e plano de rollback. Só então a troca de host poderá recuperar o mundo a partir do banco remoto.

Não habilite múltiplas instâncias do servidor antes de concluir a migração transacional e o controle de concorrência de todas as operações de jogo.
