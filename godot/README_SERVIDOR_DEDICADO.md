# Servidor dedicado — primeira versão cooperativa

Este pacote prepara o servidor ENet do Ascensão do Soberano para execução em um computador Linux ou hospedagem que aceite **UDP**. Ele não contrata nem publica uma hospedagem automaticamente.

## Configuração do Firebase (necessária)

O cliente Godot usa `res://firebase_config.json`. Para configurar outro projeto Firebase, copie `firebase_config.json.example` para `godot/firebase_config.json` e informe a chave Web correspondente. No Firebase Authentication, habilite o provedor **E-mail/senha**.

O servidor dedicado em Docker não leva esse arquivo para dentro da imagem: ele exige a variável `ASCENSAO_FIREBASE_API_KEY` no `.env` da raiz do repositório. A variável tem precedência sobre o arquivo local quando está preenchida.

A chave Web Firebase é um identificador público do projeto, não uma credencial administrativa. Restrinja-a às APIs Firebase utilizadas e proteja os dados com Firebase Security Rules/App Check. Nunca use chave de conta de serviço, token administrativo ou credencial privada nessa configuração.

## Requisitos

- Docker Engine e Docker Compose.
- Acesso de rede UDP à porta 2456.
- O arquivo `godot/firebase_config.json` com a chave pública de API do projeto Firebase já configurado no jogo.
- Um host que permita tráfego UDP de entrada e saída. Hospedagens que aceitam somente HTTP não servem para o transporte ENet atual.

## Configurar a lease do mundo global

O servidor dedicado agora exige uma autorização exclusiva antes de abrir a porta ENet. Configure no ambiente do host as variáveis `ASCENSAO_WORLD_STORAGE_URL` (URL HTTPS do Cloudflare Worker publicado) e `ASCENSAO_WORLD_STORAGE_TOKEN` (o mesmo segredo configurado como `WORLD_STORAGE_TOKEN` no Worker). O host adquire uma lease de 30 segundos e tenta renová-la a cada 10 segundos. Se a renovação falhar, fecha o ENet e encerra o processo; assim, um host sem autorização não continua aceitando jogadores. No encerramento normal, tenta liberar a lease; se o processo for encerrado abruptamente, a lease expira sozinha.

Na raiz do repositório, copie `.env.example` para `.env` e preencha os três valores:

```bash
cp .env.example .env
```

```dotenv
ASCENSAO_FIREBASE_API_KEY=SUA_CHAVE_WEB_FIREBASE
ASCENSAO_WORLD_STORAGE_URL=https://SEU-WORKER.workers.dev
ASCENSAO_WORLD_STORAGE_TOKEN=SEU_SEGREDO_FORTE
```

A chave Web Firebase é pública por natureza; não coloque aqui credenciais administrativas. O `ASCENSAO_WORLD_STORAGE_TOKEN`, por outro lado, é segredo servidor-servidor: mantenha-o somente no `.env` local e no segredo `WORLD_STORAGE_TOKEN` do Worker. O `.env` é ignorado pelo Git.

Antes de iniciar, o Worker e o D1 precisam ser configurados seguindo `../docs/PERSISTENCIA_REMOTA_MUNDO.md`. Não há banco, Worker, segredo ou hospedagem criados automaticamente por este repositório.

## Iniciar

Na raiz do repositório:

```bash
docker compose -f docker-compose.servidor.yml up -d --build
docker compose -f docker-compose.servidor.yml logs -f
```

O servidor usa a porta UDP 2456 e aceita até 40 conexões no mundo principal. Para encerrar:

```bash
docker compose -f docker-compose.servidor.yml down
```

O volume `ascensao_dados` preserva caches/espelhos locais e repositórios ainda não migrados entre reinicializações do contêiner. **Não remova o volume** ao atualizar a imagem. Faça também backups externos regulares. A lease impede dois hosts dedicados ativos; os principais estados compartilhados já usam D1 como fonte autoritativa no código, mas a implantação Cloudflare e a validação com clientes reais continuam pendentes.

## Conectar os dois celulares

1. Descubra o endereço público do host.
2. Libere/encaminhe a porta **UDP 2456** no firewall e no painel da hospedagem.
3. Em cada celular, use o mesmo endereço do servidor e a porta 2456 na tela inicial.
4. Cada pessoa entra com sua própria conta Firebase.
5. Para aventura compartilhada, uma pessoa escolhe criar sala e envia o código de seis caracteres; a outra escolhe entrar com código.

## Limitações conhecidas antes de chamar de versão jogável

- Este contêiner apenas executa o servidor existente; não substitui os testes reais com dois clientes.
- Os perfis de personagens, catálogo de criaturas, Allys, salas, fauna, recursos ecológicos, Serpente do Mundo, calendário, eventos e sistemas de mímicos/piedade já possuem integração de persistência D1 no código. O volume local continua obrigatório para cache/backup e repositórios que ainda não foram migrados; isso não substitui a configuração do Worker/D1 real nem o teste operacional.
- As salas cooperativas e o progresso narrativo usam o documento D1 `cooperative_rooms` como fonte autoritativa, com controle de revisão CAS; `user://dados/salas_multiplayer.json` permanece como espelho/backup local. Na inicialização, D1 prevalece e os IDs antigos de conexão não são restaurados; cada participante precisa reconectar usando o mesmo código de sala. O volume `ascensao_dados` preserva o espelho local e os demais repositórios que ainda não migraram.
- Uma sala sem jogadores permanece registrada para permitir retorno posterior pelo código. O pareamento público automático não coloca jogadores em salas vazias restauradas.
- O painel da sala mantém o diário e o combate cooperativo; a exploração acontece no mapa mundial compartilhado. A transição entre mapa e painel não desconecta a sessão.
- Membros de salas cooperativas também são registrados na simulação espacial compartilhada. A exploração usa o mesmo mapa, as mesmas posições validadas pelo servidor e o mesmo estado global; o botão “ALLY • GRUPO” abre o painel da equipe e do combate da sala.
- O motor de missões cooperativas ainda não possui catálogo de missões pronto; a tela narrativa e o registro de mensagens não significam que combate ou missões compartilhadas estejam concluídos.
- O servidor não possui descoberta automática de endereço público.
- É necessário confirmar no painel do Firebase que o login por e-mail/senha está habilitado.
- O projeto ainda precisa passar integralmente pelo workflow `Validar projeto Godot` e por um teste real de conexão, combate, sala e reconexão em dois dispositivos.

## Segurança operacional

Não exponha a porta UDP antes de configurar o firewall. Use contas de teste, mantenha backups do volume e não compartilhe arquivos de credenciais administrativas. A chave `apiKey` do Firebase usada pelo cliente não é uma credencial administrativa; as regras do Firebase continuam sendo necessárias para proteger os dados.


## Exploração mundial em salas cooperativas

### Interação com criaturas e entrada cooperativa

- Criaturas persistentes e indivíduos de grupos selvagens recebem uma área de toque no próprio marcador. Nos grupos, o cliente usa o prefixo `grupo:` apenas para identificar visualmente o marcador e remove esse prefixo antes de enviar a solicitação.
- O servidor recebe o ID real do indivíduo, procura primeiro no catálogo persistente e, quando necessário, no repositório de grupos selvagens. Em ambos os caminhos, valida a existência, a distância de até 92 unidades e a correspondência de ecossistema e bioma antes de iniciar o encontro.
- Se o jogador estiver em uma Ally, integrantes autenticados que estejam no mundo e a até 260 unidades da criatura podem compor a batalha. São necessários pelo menos dois participantes próximos; integrantes distantes ou ocupados em outro combate ficam de fora.
- A criatura, seus atributos e suas recompensas vêm do catálogo do servidor. O snapshot identifica quem participa, e somente os participantes são encaminhados automaticamente à tela cooperativa.
- Sem outro integrante próximo, o jogador inicia o combate individual normal.


Ao autenticar em uma sala, cada membro também é inserido na simulação espacial global, com posição inicial carregada do perfil e validação autoritativa de movimento. O mapa não é duplicado por sala. A entrada na incursão da Serpente continua exigindo posição validada dentro do raio da arena e uma solicitação explícita do próprio jogador. O painel “ALLY • GRUPO” permite abrir o estado e o combate cooperativo da sala e retornar ao mapa sem encerrar a conexão. A posição local é mantida no cache do perfil durante a troca de cenas; o servidor continua sendo a autoridade e persiste o perfil no ciclo normal de gravação.


### Segurança da posição ao trocar de tela

O cliente mantém o cache de posição apenas quando recebe a confirmação de posição do servidor. A posição provisória usada para enviar o próximo pacote não é reutilizada ao reconstruir o mapa; isso evita reaparecimento em coordenadas rejeitadas pela validação autoritativa.


## Encontros cooperativos contra grupos selvagens

- O servidor identifica o indivíduo selecionado dentro do repositório ecológico e reúne até três indivíduos vivos do mesmo grupo, próximos ao ponto de interação e no mesmo ecossistema/bioma.
- Em uma Ally, somente membros autenticados da mesma sala que estejam a até 260 unidades do encontro participam; os demais permanecem no mundo e não entram automaticamente.
- O estado cooperativo guarda IDs próprios de cada indivíduo, vida individual, alvo selecionado, contribuição de dano e histórico compartilhado.
- O jogador escolhe o alvo no painel da batalha. O ID escolhido é enviado ao servidor, validado contra os inimigos vivos e preservado no estado publicado para toda a equipe.
- Cada criatura viva responde ao turno do aventureiro ativo. Derrotar uma delas não encerra a batalha; a vitória só ocorre quando todas estiverem derrotadas. A derrota coletiva só ocorre quando todos os participantes ficam sem HP.
- Após a vitória, o servidor registra cada indivíduo no repositório ecológico antes de liberar recompensas. O registro de morte do grupo é idempotente por grupo/indivíduo; os recibos de recompensa continuam protegendo a concessão de XP e itens.
- A experiência base do encontro é a soma dos indivíduos. A equipe recebe a divisão prevista pelo motor cooperativo e os drops agregados ficam com o participante de maior dano.

A validação automatizada inclui cenários de motor com três inimigos e registro do encontro em sala, mas a aprovação final depende da execução do workflow GitHub Actions e de um teste conectado com dois clientes reais.
