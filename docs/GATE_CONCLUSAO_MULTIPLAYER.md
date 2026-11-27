# Gate de conclusão do multiplayer

Este gate separa o que a suíte automatizada consegue comprovar do que depende de infraestrutura externa.

## Cobertura automatizada obrigatória

O workflow `Validar projeto Godot` executa todos os arquivos `godot/tests/teste_*.gd`, incluindo:

- `teste_salas_multiplayer.gd`: criação, lotação, matchmaking, isolamento de aventura, restauração, reconexão e recuperação de encontros.
- `teste_validacao_sessao.gd`: invalidação de callbacks antigos e proteção contra reutilização de `peer_id`.
- `teste_integracao_sessao_sala_coop.gd`: integração das duas proteções anteriores com retomada de um combate ativo.
- `teste_combate_cooperativo.gd`, `teste_morte_cooperativa.gd` e `teste_recompensas_cooperativas.gd`: turnos, morte individual/coletiva, recompensas e retomada idempotente.
- `teste_duelo_pvp.gd`, `teste_troca_inventario.gd` e testes de limpeza: regras sociais, integridade do inventário e expiração de propostas/convites.
- Testes do servidor autoritativo, movimento, snapshots públicos, persistência global e Worker/D1.

## Critérios para declarar a etapa concluída

1. O workflow Godot da branch `main` termina com sucesso em todos os testes.
2. A configuração Firebase real é aplicada fora do Git e o login por e-mail/senha é validado.
3. O Worker/D1 e os segredos do host são configurados sem expor credenciais ao cliente.
4. Um servidor dedicado real inicia com lease válida e porta UDP 2456 acessível.
5. Dois ou mais dispositivos entram no mesmo mundo e confirmam movimento/snapshots em tempo real.
6. Em dispositivos reais são verificados: criação/entrada por código, Ally, troca, PvP, combate cooperativo, desconexão, reconexão e persistência após reinício.
7. Backups e restauração do volume persistente são verificados.

## Limites conhecidos

- O teste integrado novo simula a reutilização de identidade de sessão e a reconexão sobre os serviços reais de sala/combate, mas não substitui um teste ENet entre dispositivos.
- O repositório não publica nem contrata hospedagem. O endereço público, firewall UDP e credenciais Cloudflare/Firebase dependem da configuração da conta do responsável.
- Não habilitar múltiplas instâncias independentes enquanto o armazenamento local dos repositórios ainda existir.
- Não gerar APK de teste como critério intermediário; a exportação Android permanece para o fim da Mini Versão Completa.
