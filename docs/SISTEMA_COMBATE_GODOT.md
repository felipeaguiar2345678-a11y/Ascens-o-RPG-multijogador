# Núcleo de combate por turnos

## Implementado
- Regras isoladas em `godot/scripts/sistema_combate.gd`, sem dependência de cena ou interface.
- Estado inicial construído a partir do perfil e dos dados da criatura fornecidos pela lógica confiável do servidor.
- Atributos efetivos e defesa de equipamentos são calculados pelo sistema de equipamentos existente, sem alterar os atributos-base.
- Ações permitidas: ataque, magia, defender e esquivar.
- Magia consome 8 pontos de mana; criatura que usa poder mágico consome 5 pontos por ataque mágico.
- Dano considera poder ofensivo, defesa, esquiva baseada na agilidade do alvo e crítico baseado na agilidade do atacante, ambos com limites.
- A rodada resolve a ação do jogador e a resposta controlada da criatura, reconhecendo vitória e derrota.
- Histórico de combate limitado às 30 entradas mais recentes.
- A função recebe uma semente de sorteio que deve ser criada exclusivamente no servidor.

## Integração multiplayer realizada nesta etapa
- `RedeMultiplayer.iniciar_combate_servidor(peer_id, criatura)` cria uma sessão por jogador no servidor, usando o perfil autenticado e a criatura fornecida pela lógica interna confiável.
- O cliente envia somente uma das quatro ações permitidas por `solicitar_acao_combate`; o servidor executa o cálculo e envia o estado atualizado por RPC confiável.
- Ao encerrar a batalha, o servidor persiste HP/MP. Na vitória, conserva os valores finais e então concede drops; na derrota, recupera HP/MP ao máximo efetivo e não concede drops.
- Movimento e alterações de equipamento são recusados enquanto o jogador está em combate. A sessão é descartada na desconexão.
- A interface recebe os sinais `combate_atualizado`, `combate_finalizado` e `erro_combate` para construir a tela de batalha.

## Limites atuais
- Este é o núcleo de regras, ainda não conectado a uma tela de combate nem a um encontro real no mundo.
- Ainda não há sessão de combate persistida, RPC de ação, cooldowns, efeitos de estado, habilidades geradas por IA, fuga, partes corporais, experiência ou recompensas automáticas.
- HP/MP agora são persistidos no perfil. Bônus de vida/mana de equipamentos são considerados no limite efetivo sem alterar os máximos-base. Derrota restaura HP/MP ao máximo, mas a regra de respawn por ponto de retorno e as penalidades de XP/ouro ainda não foram integradas; por isso, o fluxo de derrota continua em desenvolvimento.
- O cálculo de dano é uma primeira base de balanceamento e precisará de testes com criaturas de diferentes níveis e ranks.
- Não representa ainda um teste multiplayer com dois clientes conectados. Ainda não existe um gerenciador de encontros do mundo chamando `iniciar_combate_servidor`, nem uma tela de combate.

## Segurança
A interface deverá enviar apenas o identificador da ação permitida. O servidor deve recuperar a sessão ativa pelo peer autenticado, gerar a semente, executar a rodada e publicar o estado resultante. Nunca aceitar do cliente dano, vida do inimigo, vitória, drops ou atributos de criatura.

## Próxima integração
Criar a interface de combate e conectar encontros autoritativos do mundo; depois integrar respawn e penalidades de XP/ouro. Depois adicionar habilidades, efeitos, cooldowns e recompensas.
