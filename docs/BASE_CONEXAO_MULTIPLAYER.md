# Base de conexão multiplayer — Godot

## Decisão desta etapa

O projeto passa a ter uma camada inicial de transporte ENet por meio de `ENetMultiplayerPeer`, usando a API multiplayer de alto nível do Godot.

- O cliente Android se conecta a um servidor dedicado.
- O servidor será a autoridade do estado do mundo.
- A conexão usa UDP/ENet; a porta padrão inicial documentada é 2456, configurável.
- O singleton `RedeMultiplayer` oferece operações para conectar como cliente, iniciar um servidor para testes controlados e desconectar.
- Eventos de conexão, falha e entrada/saída de peers são expostos por sinais em português.

## Estado da autenticação

A tela Godot agora oferece cadastro/login por e-mail e senha via Firebase Authentication. O cliente recebe um ID token e o servidor consulta o Firebase para validar o token e obter o UID antes de aceitar a entrada no mundo. Consulte `docs/AUTENTICACAO_FIREBASE_GODOT.md`.

## Limite desta entrega

A autenticação está implementada em código, mas ainda precisa de teste real com E-mail/senha habilitado no Firebase. Ainda não há:
- autenticação persistente/renovação automática de sessão;
- recuperação de senha ou verificação obrigatória de e-mail;
- sincronização de posição/representação dos jogadores;
- replicação de regiões e estado do mundo;
- servidor dedicado publicado/hospedado;
- validação autoritativa de combate, inventário, economia ou chefes.

Não tratar `iniciar_servidor()` como servidor de produção. Ele existe para testes técnicos locais. O próximo passo é definir o protocolo de sessão e autenticação e, em seguida, implementar entrada/saída e sincronização de jogadores com o servidor como autoridade.

## Segurança e custos

Nunca aceitar do cliente valores finais de dano, vida, itens, moedas, recompensas ou estado do chefe mundial. O cliente deve enviar intenções; o servidor valida e calcula os resultados.

Nenhuma hospedagem, API paga, Cloud Function paga ou outro serviço com cobrança foi ativado. Antes de escolher infraestrutura pública, comparar opções gratuitas/open-source, limites, segurança, disponibilidade e custos, e pedir aprovação explícita para qualquer opção paga.
