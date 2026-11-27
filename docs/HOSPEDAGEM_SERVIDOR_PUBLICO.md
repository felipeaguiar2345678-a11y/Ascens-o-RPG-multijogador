# Hospedagem pública — Ascensão do Soberano

## Estado atual

O projeto possui um servidor ENet dedicado e uma imagem Docker. Isso prepara o processo para hospedagem, mas **não cria nem publica um servidor na internet**. É necessário um computador/servidor Linux acessível publicamente (por exemplo, uma VPS escolhida pelo responsável pelo projeto).

A arquitetura atual mantém personagens, Allys, salas, criaturas e eventos em arquivos locais do processo dedicado. Por isso, use **uma única instância** do servidor para preservar o mundo lógico compartilhado. Não faça escala horizontal com várias cópias independentes: elas não compartilham o banco local.

## Requisitos de rede

- Godot 4.7.2 no container (já instalado pelo Dockerfile).
- Porta UDP 2456 liberada no firewall do host e no firewall do provedor.
- DNS opcional apontando para o IP público do host (registro A).
- Volume persistente para `/home/godot/.local/share/godot/app_userdata/Ascensão do Soberano`.
- Capacidade máxima atual: 40 conexões simultâneas.

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
- Não há banco de dados compartilhado em nuvem nem replicação/recuperação entre servidores.
- A autenticação Firebase precisa ser validada no host público com as regras e configuração do projeto.
- O servidor deve passar por teste com dois ou mais celulares, inclusive desconexão, reconexão, troca, PvP e persistência após reinício.
- O projeto não inclui monitoramento externo, proteção DDoS ou sistema de escalabilidade. Não exponha a instância a tráfego amplo antes de validar os controles de abuso e os limites operacionais.

Nenhum serviço pago foi contratado ou ativado por esta alteração. A escolha de VPS, domínio e orçamento depende de aprovação do responsável pelo projeto.
