# Multiplayer Ally — Etapa 3

## Sistemas integrados no código

### Presença e mundo aberto
- Publica UID, nome, nível, ponto do mundo, coordenadas, vida e atributos de combate.
- Atualiza a presença a cada 3 segundos, sem gravar a cada quadro de movimento.
- Exibe jogadores da mesma área na cena do mundo.
- Presenças com mais de 30 segundos sem atualização são tratadas como offline.
- Tocar em **Interagir** no marcador de outro jogador abre o convite para Ally.

### Grupos Ally
- Coleções próprias, separadas das campanhas.
- Limite de 4 jogadores contando o líder.
- Convites individuais com aceitar/recusar.
- Líder pode remover integrantes; integrantes podem sair.
- A lista mostra nome, nível, vida e estado online/offline.
- O grupo não permite alterar integrantes enquanto uma batalha estiver ativa ou enquanto alguém ainda não tiver retirado a recompensa da última batalha.

### Batalha cooperativa compartilhada
- Um único documento de batalha por grupo, com um inimigo e vida compartilhados.
- Aliados online na mesma área e dentro do alcance entram automaticamente quando o combate começa.
- Um aliado distante pode se aproximar e tocar em **Entrar no combate**.
- Depois que a batalha termina, ninguém mais pode entrar nela.
- Os jogadores agem em turnos sequenciais; apenas o integrante indicado como dono do turno pode agir.
- Se o jogador atual for derrotado, o turno passa para o próximo integrante vivo.
- O XP da vitória é dividido entre os participantes da batalha.
- Os itens ficam com o participante que causou mais dano; empate é resolvido por um critério estável para evitar duplicação.
- Cada participante registra a retirada da recompensa uma única vez.

## Limitações ainda pendentes antes de produção

- O combate compartilhado ainda precisa de testes com duas ou mais contas reais e do emulador Firestore.
- Se o jogador dono do turno ficar offline durante a batalha, ainda não há transferência automática do turno por tempo limite.
- A geração dos itens ainda acontece no cliente do vencedor; deve ser validada em teste para garantir que o inventário e as recompensas persistam corretamente.
- Regras Firestore ainda não foram implantadas no projeto Firebase.
- O APK ainda não foi compilado, conforme a decisão de integrar primeiro os sistemas e compilar depois.

## Segurança e custos

- As regras locais restringem presença ao próprio UID, convites ao remetente/destinatário, grupo aos integrantes e ações de batalha ao jogador do turno.
- Nenhuma Cloud Function, API paga ou serviço adicional foi contratado.
- Não houve implantação no Firebase nem alteração de dados de produção.
