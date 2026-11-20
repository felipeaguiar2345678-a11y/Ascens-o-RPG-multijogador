# Sincronização inicial de movimento multiplayer

## Implementado

- O cliente envia sua posição ao servidor em intervalos de aproximadamente 100 ms.
- O servidor verifica se o peer entrou no mundo, limita a posição aos limites da região central (2400 × 1600) e rejeita saltos acima de 52 pixels por atualização.
- Posições aceitas são retransmitidas aos demais clientes.
- O cliente atualiza a posição dos jogadores remotos e corrige sua própria posição quando recebe confirmação/correção do servidor.
- O canal de posição usa RPC não confiável e ordenado, adequado para atualizações frequentes em que a posição mais recente substitui a anterior.

## Limites

A checagem de distância é uma proteção inicial, não um sistema antitrapaça completo: ainda faltam controle de velocidade por tempo real do servidor, validação de colisões/rotas, tolerância de latência adaptativa, interpolação visual, predição, autenticação, persistência e testes de carga. O cliente ainda tem movimento local preditivo simples. Não usar esta etapa como segurança suficiente para PvP, economia ou recompensas.

O servidor continua sem estar hospedado/publicado. A sincronização só pode ser testada quando dois clientes alcançarem o mesmo servidor ENet acessível.
