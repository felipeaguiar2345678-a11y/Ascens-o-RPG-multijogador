# Hospedagem pública — Ascensão do Soberano

## Estado atual

O projeto possui um servidor ENet dedicado e uma imagem Docker. Isso prepara o processo para hospedagem, mas **não cria nem publica um servidor na internet**. É necessário um computador/servidor Linux acessível publicamente (por exemplo, uma VPS escolhida pelo responsável pelo projeto).

Os principais estados compartilhados possuem integração D1 no código. Em 28/11/2026, o Worker `ascensao-soberano-api` foi publicado com o binding `WORLD_STATE` apontando para o banco remoto `ascensao-world-state`; as migrações remotas foram verificadas e não havia migrações pendentes. O workflow de publicação também preservou o namespace Durable Object legado `PersistentWorldState`. A publicação do Worker foi concluída, mas a prontidão do endpoint público e do D1 deve ser confirmada pelo passo automatizado `Verificar saúde pública e persistência D1` no workflow. O volume local continua necessário para caches, backups e repositórios ainda não migrados. Use **uma única instância** do servidor; não faça escala horizontal enquanto todos os estados operacionais não estiverem compartilhados e validados.

## Requisitos de rede

- Godot 4.7.2 no container (já instalado pelo Dockerfile).
- Porta UDP 2456 liberada no firewall do host e no firewall do provedor.
- DNS opcional apontando para o IP público do host (registro A).
- Volume persistente para `/home/godot/.local/share/godot/app_userdata/Ascensão do Soberano`.
- Capacidade máxima atual: 40 conexões simultâneas.

## Publicação da API Cloudflare

O deploy do Worker é manual e usa o estado declarativo `exports` para o Durable Object `MonthlyAIBudget`, com backend SQLite. Esse backend corresponde à migração original `new_sqlite_classes` registrada no repositório. A documentação atual da Cloudflare permite migrar de `migrations` para `exports` sem mover os dados: os namespaces provisionados permanecem, desde que cada classe ainda ativa seja declarada com o mesmo backend.

Antes de publicar, o workflow consulta todos os namespaces da conta pela API somente de leitura. O deploy só continua se houver exatamente um namespace vinculado a `ascensao-soberano-api`, com classe `MonthlyAIBudget` e `use_sqlite = true`. Se houver classe extra, classe diferente, armazenamento incompatível, paginação incompleta ou falta de permissão, o workflow falha antes de chamar Wrangler. A configuração antiga com tag `v2` não é presumida nem reconstruída no escuro.

A CI também executa `wrangler deploy --dry-run`, que compila e valida a configuração sem enviar uma publicação. A ativação do D1 foi realizada: o binding `WORLD_STATE`, o banco remoto e as migrações SQL estão configurados, e o segredo `WORLD_STORAGE_TOKEN` foi cadastrado no Worker. O workflow agora executa um smoke test em `/health` e exige `worldStorageReady=true` antes de considerar a publicação saudável.

## Oracle Cloud Always Free (primeiro ambiente de testes)

A Oracle Cloud pode ser usada como primeira hospedagem sem mensalidade, desde que a conta e a instância permaneçam dentro dos limites **Always Free**. A disponibilidade de capacidade Ampere A1 varia por região e não é garantida. A Oracle também aplica regras de recuperação a instâncias ociosas; portanto, não trate o plano gratuito como SLA de produção.

### Perfil recomendado para o protótipo

- Criar uma VM Ampere A1 (ARM64) com Ubuntu 24.04 ARM.
- Dimensionar CPU e memória dentro da cota Always Free exibida pela própria conta. Começar com poucos jogadores e medir CPU, memória, tráfego e latência antes de aumentar.
- Usar uma única VM e uma única instância do servidor Godot.
- O Dockerfile seleciona automaticamente o binário Godot 4.7.2 para ARM64 ou x86-64 conforme a arquitetura de destino da imagem.
- Liberar UDP 2456 tanto nas regras de entrada da VCN/NSG da Oracle quanto no firewall Ubuntu. Manter SSH TCP 22 restrito ao IP administrativo sempre que possível.

### Preparação da VM

1. Na Oracle Cloud, criar a instância Ampere A1 com imagem Ubuntu 24.04 ARM e escolher apenas recursos que a tela identifique como Always Free.
2. Associar IP público e configurar uma regra de entrada UDP 2456 na NSG ou lista de segurança da VCN.
3. Conectar por SSH e instalar Docker Engine e o plugin Docker Compose para Ubuntu ARM64.
4. Clonar o repositório e entrar na pasta do projeto.
5. Copiar o modelo de ambiente e editar o arquivo local `.env` na raiz:
   ```bash
   cp .env.example .env
   nano .env
   ```
   Preencher:
   ```dotenv
   ASCENSAO_FIREBASE_API_KEY=SUA_CHAVE_WEB_FIREBASE
   ASCENSAO_WORLD_STORAGE_URL=https://SEU-WORKER-REAL
   ASCENSAO_WORLD_STORAGE_TOKEN=SEU_SEGREDO_REAL
   ```
   A chave Web Firebase identifica o projeto e não é uma credencial administrativa. Restrinja-a às APIs Firebase necessárias. O token `ASCENSAO_WORLD_STORAGE_TOKEN` é segredo e deve ser mantido apenas no `.env` local e no segredo do Worker; nunca o publique em issues, commits, prints ou mensagens.
6. Liberar a porta no firewall do Ubuntu e iniciar:
   ```bash
   sudo ufw allow OpenSSH
   sudo ufw allow 2456/udp
   sudo ufw enable
   docker compose -f docker-compose.servidor.yml up -d --build
   ```
7. Conferir o estado e os logs:
   ```bash
   docker compose -f docker-compose.servidor.yml ps
   docker compose -f docker-compose.servidor.yml logs -f ascensao-servidor
   ```
8. Usar o IP público da VM e a porta UDP 2456 no cliente do jogo.

### Limites antes de convidar jogadores

- A configuração Oracle não cria conta, VM, IP público, regra de firewall, banco D1 nem segredo automaticamente.
- O Worker Cloudflare e o D1 remoto foram publicados/configurados. A prontidão operacional deve ser confirmada pelo smoke test do workflow e, depois, por uma inicialização real do host dedicado usando o mesmo segredo no ambiente do servidor.
- O volume Docker mantém os dados locais da VM; configure cópias de segurança externas antes de confiar nele como único armazenamento.
- Primeiro validar login Firebase, entrada de dois aparelhos, desconexão/reconexão e recuperação após reiniciar a VM. Não anunciar disponibilidade pública antes desses testes.
- O limite de 40 jogadores configurado no servidor é um teto de código, não uma promessa de que a instância gratuita suportará 40 jogadores.
- Se a Oracle não disponibilizar capacidade gratuita, não criar instância paga automaticamente. Interromper e pedir aprovação antes de qualquer custo.

## Publicar no host

1. Instale Docker Engine e o plugin Docker Compose no host Linux.
2. Obtenha o repositório e entre na raiz do projeto.
3. Libere a porta UDP 2456 no firewall do sistema e do provedor.
4. Inicie o servidor:

   ```bash
   docker compose -f docker-compose.servidor.yml up -d --build
   ```

5. Confira o processo e os logs:

   ```bash
   docker compose -f docker-compose.servidor.yml ps
   docker compose -f docker-compose.servidor.yml logs -f ascensao-servidor
   ```

6. No jogo, informe o IP público ou domínio do host e a porta UDP 2456 na tela de conexão.

## Backup e atualização

- Faça backup do volume Docker `ascensao_dados` antes de atualizar a imagem.
- Para atualizar, baixe o commit desejado e execute novamente `docker compose -f docker-compose.servidor.yml up -d --build`.
- Não apague o volume `ascensao_dados` ao atualizar.
- Mantenha somente uma instância ativa enquanto o armazenamento continuar local.

## Limitações que ainda precisam ser resolvidas

- O servidor ainda não está implantado em um host real; nenhum IP ou domínio público foi configurado.
- A descoberta automática não existe: o jogador informa o IP/domínio manualmente.
- O Worker/D1 já foi ativado na Cloudflare; ainda falta validar o smoke test público, inicializar o host dedicado real e testar recuperação/reconexão. Não há replicação/recuperação entre múltiplos hosts validada.
- A autenticação Firebase precisa ser validada no host público com as regras e configuração do projeto.
- O servidor deve passar por teste com dois ou mais celulares, inclusive desconexão, reconexão, troca, PvP e persistência após reinício.
- O projeto não inclui monitoramento externo, proteção DDoS ou sistema de escalabilidade. Não exponha a instância a tráfego amplo antes de validar os controles de abuso e os limites operacionais.

Nenhum serviço pago foi contratado ou ativado por esta alteração. A escolha de VPS, domínio e orçamento depende de aprovação do responsável pelo projeto.
