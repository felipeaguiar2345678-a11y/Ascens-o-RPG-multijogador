# Sincronização inicial de movimento multiplayer

## Implementado

- O cliente envia sua posição ao servidor em intervalos de aproximadamente 100 ms.
- O servidor verifica se o peer entrou no mundo e limita a posição aos limites da região central (2400 × 1600).
- O servidor mede o tempo usando seu próprio relógio monotônico, rejeita pacotes recebidos com intervalo inferior a 35 ms e calcula a distância permitida conforme o tempo decorrido e a velocidade-base de 165 px/s, com tolerância inicial para variações de rede.
- Pacotes fora dos limites ou com deslocamento excessivo são rejeitados e o servidor envia a última posição aceita ao cliente.
- Posições aceitas são retransmitidas aos clientes.
- Após operações assíncronas de visita/persistência, o servidor revalida UID e geração da sessão antes de alterar o perfil ou retransmitir a posição. Se chegarem novos pacotes durante a espera, publica a posição aceita mais recente, evitando que uma coroutine antiga sobrescreva uma sessão reconectada.
- O cliente atualiza a posição dos jogadores remotos e corrige sua própria posição quando recebe confirmação/correção do servidor.
- O canal de posição usa RPC não confiável e ordenado, adequado para atualizações frequentes em que a posição mais recente substitui a anterior.

## Limites

Esta é uma barreira inicial contra spam e teletransporte grosseiro, não um sistema antitrapaça completo. A tolerância de movimento ainda precisa ser calibrada com latência real e teste de carga. Ainda faltam validação de colisões e rotas no servidor, sincronização com autoridade completa do estado do personagem, interpolação visual, predição e reconciliação, autenticação, persistência e testes com vários clientes. Não usar esta etapa como segurança suficiente para PvP, economia ou recompensas.

A tela inicial agora exige endereço e conexão ENet confirmada antes de carregar o mapa. Isso impede a entrada offline, mas não significa que exista servidor público: o servidor dedicado ainda precisa ser hospedado e configurado. Sem um endereço de servidor ativo, o jogador não consegue entrar. A conexão ENet também ainda não autentica a identidade do jogador.

O movimento local continua sendo preditivo simples no cliente; a posição aceita pelo servidor é retransmitida como confirmação/correção. O teste real exige dois clientes conectados ao mesmo servidor ENet acessível.

## Proteção de operações assíncronas por geração de sessão

A validação de sessão também é reaplicada depois de confirmações remotas que podem aguardar I/O. Atualizações de missão e de equipamento capturam UID e geração da sessão no início; após a espera, só atualizam o perfil em memória ou enviam RPC se o peer ainda representar exatamente a mesma sessão. Isso impede que uma resposta atrasada de uma conexão antiga publique dados para uma reconexão que reutilizou o mesmo identificador de peer.
