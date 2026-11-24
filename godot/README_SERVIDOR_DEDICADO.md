# Servidor dedicado — primeira versão cooperativa

Este pacote prepara o servidor ENet do Ascensão do Soberano para execução em um computador Linux ou hospedagem que aceite **UDP**. Ele não contrata nem publica uma hospedagem automaticamente.

## Configuração do Firebase (necessária)

O repositório não contém a configuração específica do seu projeto Firebase. Antes de exportar o cliente ou iniciar o servidor:

1. Abra as configurações do projeto Firebase e copie a **chave de API da aplicação Web**.
2. Dentro da pasta `godot/`, crie um arquivo chamado `firebase_config.json`.
3. Copie o conteúdo de `firebase_config.json.example` e substitua o texto de exemplo pela chave real.
4. No Firebase Authentication, habilite o provedor **E-mail/senha**.

O arquivo real `godot/firebase_config.json` está no `.gitignore` e não deve ser enviado ao GitHub. O modelo versionado não contém segredo real. A chave de API Firebase de cliente não substitui regras de segurança nem deve ser confundida com uma chave administrativa.

## Requisitos

- Docker Engine e Docker Compose.
- Acesso de rede UDP à porta 2456.
- O arquivo `godot/firebase_config.json` com a chave pública de API do projeto Firebase já configurado no jogo.
- Um host que permita tráfego UDP de entrada e saída. Hospedagens que aceitam somente HTTP não servem para o transporte ENet atual.

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

O volume `ascensao_dados` preserva os arquivos locais de personagens, estado do servidor e salas cooperativas entre reinicializações do contêiner. **Não remova o volume** ao atualizar a imagem. Faça também backups externos regulares.

## Conectar os dois celulares

1. Descubra o endereço público do host.
2. Libere/encaminhe a porta **UDP 2456** no firewall e no painel da hospedagem.
3. Em cada celular, use o mesmo endereço do servidor e a porta 2456 na tela inicial.
4. Cada pessoa entra com sua própria conta Firebase.
5. Para aventura compartilhada, uma pessoa escolhe criar sala e envia o código de seis caracteres; a outra escolhe entrar com código.

## Limitações conhecidas antes de chamar de versão jogável

- Este contêiner apenas executa o servidor existente; não substitui os testes reais com dois clientes.
- Os perfis são persistidos em arquivo JSON local do servidor, não em Firestore. O volume persistente é obrigatório para não perder os dados ao recriar o contêiner.
- As salas e o progresso narrativo agora são gravados em `user://dados/salas_multiplayer.json`. Após reiniciar o servidor, os códigos e o estado da aventura são restaurados sem manter IDs antigos de conexão; cada participante precisa reconectar usando o mesmo código de sala. O volume `ascensao_dados` é obrigatório para preservar esse arquivo.
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

Ao autenticar em uma sala, cada membro também é inserido na simulação espacial global, com posição inicial carregada do perfil e validação autoritativa de movimento. O mapa não é duplicado por sala. A entrada na incursão da Serpente continua exigindo posição validada dentro do raio da arena e uma solicitação explícita do próprio jogador. O painel “ALLY • GRUPO” permite abrir o estado e o combate cooperativo da sala e retornar ao mapa sem encerrar a conexão. A posição local é mantida no cache do perfil durante a troca de cenas; o servidor continua sendo a autoridade e persiste o perfil no ciclo normal de gravação.


### Segurança da posição ao trocar de tela

O cliente mantém o cache de posição apenas quando recebe a confirmação de posição do servidor. A posição provisória usada para enviar o próximo pacote não é reutilizada ao reconstruir o mapa; isso evita reaparecimento em coordenadas rejeitadas pela validação autoritativa.
