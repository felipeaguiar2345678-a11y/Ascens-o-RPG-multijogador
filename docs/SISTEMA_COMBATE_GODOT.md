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

## Limites atuais
- Este é o núcleo de regras, ainda não conectado a uma tela de combate nem a um encontro real no mundo.
- Ainda não há sessão de combate persistida, RPC de ação, cooldowns, efeitos de estado, habilidades geradas por IA, fuga, partes corporais, experiência ou recompensas automáticas.
- O estado de combate é transitório; HP/MP após a batalha ainda não são gravados no perfil.
- O cálculo de dano é uma primeira base de balanceamento e precisará de testes com criaturas de diferentes níveis e ranks.
- Não representa ainda um teste multiplayer com dois clientes conectados.

## Segurança
A interface deverá enviar apenas o identificador da ação permitida. O servidor deve recuperar a sessão ativa pelo peer autenticado, gerar a semente, executar a rodada e publicar o estado resultante. Nunca aceitar do cliente dano, vida do inimigo, vitória, drops ou atributos de criatura.

## Próxima integração
Conectar a sessão autoritativa ao gerenciador multiplayer, persistir HP/MP com tratamento correto dos bônus temporários de equipamento e criar a interface de combate. Depois adicionar habilidades, efeitos, cooldowns e recompensas.
