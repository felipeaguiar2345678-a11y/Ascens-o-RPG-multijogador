# Servidor dedicado — primeira versão cooperativa

Este pacote prepara o servidor ENet do Ascensão do Soberano para execução em um computador Linux ou hospedagem que aceite **UDP**. Ele não contrata nem publica uma hospedagem automaticamente.

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

O volume `ascensao_dados` preserva os arquivos locais de personagens e estado do servidor entre reinicializações do contêiner. **Não remova o volume** ao atualizar a imagem. Faça também backups externos regulares.

## Conectar os dois celulares

1. Descubra o endereço público do host.
2. Libere/encaminhe a porta **UDP 2456** no firewall e no painel da hospedagem.
3. Em cada celular, use o mesmo endereço do servidor e a porta 2456 na tela inicial.
4. Cada pessoa entra com sua própria conta Firebase.
5. Para aventura compartilhada, uma pessoa escolhe criar sala e envia o código de seis caracteres; a outra escolhe entrar com código.

## Limitações conhecidas antes de chamar de versão jogável

- Este contêiner apenas executa o servidor existente; não substitui os testes reais com dois clientes.
- Os perfis são persistidos em arquivo JSON local do servidor, não em Firestore. O volume persistente é obrigatório para não perder os dados ao recriar o contêiner.
- Salas e estado narrativo compartilhado vivem na memória do processo; uma reinicialização encerra as salas ativas.
- O servidor não possui descoberta automática de endereço público.
- É necessário confirmar no painel do Firebase que o login por e-mail/senha está habilitado.
- O projeto ainda precisa passar integralmente pelo workflow `Validar projeto Godot` e por um teste real de conexão, combate, sala e reconexão em dois dispositivos.

## Segurança operacional

Não exponha a porta UDP antes de configurar o firewall. Use contas de teste, mantenha backups do volume e não compartilhe arquivos de credenciais administrativas. A chave `apiKey` do Firebase usada pelo cliente não é uma credencial administrativa; as regras do Firebase continuam sendo necessárias para proteger os dados.
