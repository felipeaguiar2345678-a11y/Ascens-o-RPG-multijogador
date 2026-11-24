# Convites e formação de Ally

## Fluxo implementado

- O jogador toca no avatar remoto e abre o menu contextual.
- A opção **Convidar para Ally** envia somente o peer de destino; o cliente não envia UID nem posição.
- O servidor resolve as identidades pela sessão autenticada e valida que os dois personagens estão no mundo, fora de combate, a até 150 unidades e na mesma sala cooperativa.
- Cada convite expira em 30 segundos e o jogador convidado precisa aceitar explicitamente.
- Uma Ally comporta até quatro integrantes. O servidor controla a associação entre UID e Ally e publica os membros conectados.
- Um convite pendente por destinatário e intervalo mínimo de 2,5 segundos por remetente reduzem spam.
- Convites são removidos ao expirar ou quando uma das contas desconecta. Ao desconectar, o membro é removido da Ally e a liderança é transferida se necessário.

## Limites desta entrega

- A Ally é mantida em memória no processo do servidor. Ainda não há persistência entre reinicializações.
- A formação inicial exige que ambos estejam na mesma sala cooperativa. Isso evita formar uma equipe que a implementação atual de combate por sala ainda não consegue representar.
- O convite e a composição da equipe estão implementados; painel completo de membros, sair da Ally, troca e PvP continuam pendentes.
- O teste de integração com dois clientes reais ainda é necessário. Não declarar o fluxo aprovado apenas pela presença do código.

## Roteiro de validação manual

1. Entrar com duas contas na mesma sala e aproximar os personagens.
2. Tocar no avatar remoto e enviar convite.
3. Confirmar que o outro cliente recebe o diálogo com o nome do remetente.
4. Aceitar e confirmar que os dois recebem o estado da Ally.
5. Repetir com recusa, distância acima de 150, combate ativo, salas diferentes e convite expirado.
6. Desconectar um membro e conferir remoção e transferência de liderança.
7. Tentar enviar convites em sequência e confirmar o bloqueio temporário.
