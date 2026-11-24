# Registro da visão de Ascensão do Soberano

Este documento preserva as decisões de design já estabelecidas. **Registrar uma ideia não significa que ela esteja implementada.** O estado de cada sistema deve ser atualizado somente após código e testes verificáveis.

## Regras fundamentais

- RPG online persistente, com interface e textos visíveis em português.
- Exploração livre: nenhuma missão, tutorial, guilda ou linha principal é obrigatória.
- Missões podem ser oferecidas, recusadas, adiadas ou abandonadas quando o sistema permitir; elas enriquecem o mundo, mas não bloqueiam a exploração.
- O multiplayer de grupo é narrativo e por texto, sem mapa espacial, câmera ou movimentação de personagens na tela compartilhada.
- O mundo/mapa espacial continua sendo uma experiência solo.
- Não contratar hospedagem, APIs de IA, geração paga de imagens, funções em nuvem ou serviços pagos sem aprovação explícita do usuário.
- APK é a última etapa, depois de validação, servidor e testes reais.

## Mundo e narrativa

- Aurelia é a cidade principal e referência inicial do mundo.
- Novos personagens começam na Clareira Inicial, na borda sul da Floresta Arcana, com Aurelia visível ao longe.
- Ecossistemas/regiões planejados: Montanhas Geladas, Floresta Arcana, Império, Central, Sombras, Deserto Ancestral e Mar Eterno. Cidades como Aurelia e Malachar podem constituir ecossistemas próprios, sem limitar o mundo a quatro regiões fixas.
- A abertura apresenta o mundo, criaturas, aldeias ameaçadas, Aurelia e a Grande Serpente, mas não força o jogador a aceitar uma missão.
- NPCs podem oferecer ajuda, esconder informações, negociar, mentir e reagir às escolhas.
- O mundo deve continuar explorável mesmo quando o jogador ignora missões.

## Personagem e progressão

- Atributos: força, inteligência, agilidade, vitalidade e espírito.
- Valores-base inicialmente definidos em 5; ao subir de nível, o personagem recebe 5 pontos para distribuir.
- Experiência necessária para o próximo nível: nível atual × 100.
- Classes representam afinidades e especializações, não bloqueios absolutos de habilidades.
- Raça, aparência, anatomia e equipamentos devem refletir a identidade escolhida.
- Derrota: retornar ao último ponto de ressurgimento, restaurar completamente vida e mana, perder 50% da experiência acumulada total e 20% do ouro. A semântica exata do saldo de XP deve ser confirmada antes de implementar a perda.
- Equipamento: espada de uma mão sozinha ou com escudo; arma de duas mãos ocupa ambas as mãos; arma pesada ocupa o espaço do escudo. No máximo um anel e um colar. Escudo restrito às classes de combate corpo a corpo.
- Um companheiro ativo por vez; o seguidor usa deslocamento relativo e velocidade superior à do jogador.

## Criaturas, IA e chefes

- A IA deve criar criaturas do zero, não depender de um banco de inimigos artesanais como fonte principal.
- Depois da geração, criaturas válidas são registradas no catálogo global para descoberta e reutilização.
- Dados previstos: identificador, nome, descrição, rank E–SSS, nível, vida, ataque, defesa, mana, agilidade, poder mágico, experiência-base, perigo, bioma, habitat, habilidades, chefe, versão e referências visuais.
- Geração deve respeitar ecossistema, identidade regional, raridade, rank, habitat e condições de aparição.
- Cada região pode ter mais de um chefe regional, com condições próprias de aparição.
- Habilidades podem ser originais e variadas; não limitar a IA a uma lista pequena de habilidades predefinidas.
- Catálogo global: total de derrotas, primeiro descobridor, primeiro derrotador, data da descoberta, maior dano, jogador com mais derrotas e total de jogadores que encontraram a criatura.
- Raridades devem cobrir todos os níveis definidos, não apenas comum.
- Combate considera ações da IA (atacar, defender, especial, recuar), ranks E–SSS e eventos de dado natural 1/20, com balanceamento.

## Drops, companheiros e economia

- Drops automáticos após derrotas confirmadas.
- Em grupo, experiência dividida igualmente; itens/ovos destinados ao participante que causou maior dano, conforme regra definida para cada recompensa.
- Chance-base de ovos por rank: E 5%, D 4%, C 3%, B/A 2%, S/SS/SSS 1%.
- Companheiros obtidos de ovos preservam a aparência da criatura de origem.
- Materiais possíveis incluem pele, carne e dentes; raridade acompanha a força/raridade da criatura.
- Roleta visual mostra falha (X) ou sucesso (✓), mas o servidor calcula a chance e o resultado antes da animação. A animação nunca altera o sorteio.
- Moedas: Bronzhar (bronze, ⛨), Ferrak (ferro, ⚒), Auréon (ouro, ☼), Diamyr (diamante, ◈), Jaderys (jade, ❖) e Ankhar (moeda ancestral especial, ⟁). Ankhar fica fora da conversão comum entre moedas.

## Mundo vivo e fenômenos celestes

- Relógio compacto deve mostrar horário e período do mundo.
- Eventos noturnos: lua cheia, eclipse e lua de sangue.
- Fenômenos celestes afetam aparição, força, comportamento e recompensas das criaturas.
- O tempo e os eventos relevantes devem ser compartilhados entre participantes do multiplayer.

## Multiplayer narrativo

- Fluxo de grupo: criar sala e compartilhar código; ou entrar usando código.
- A aventura compartilhada começa quando há pelo menos dois jogadores, embora uma sala possa guardar estado antes disso.
- Tela compartilhada apresenta participantes, registro narrativo e ações em texto; não deve introduzir mapa espacial.
- Ações e progresso precisam ser validados pelo servidor. Nunca confiar em UID, progresso, derrotas ou recompensas enviados livremente pelo cliente.
- Missões cooperativas, encontros, combate textual, progresso e recompensas devem ser sincronizados e persistidos por sala.
- Mensagens de uma sala não podem vazar para outra.

## Estado técnico registrado em 24/11/2026

### Implementado no repositório (ainda sujeito à validação automatizada e testes reais)

- Projeto migrado para Godot 4.7.2.
- Login Firebase por e-mail/senha e validação da sessão no servidor.
- Servidor ENet dedicado e empacotamento Docker preparados; hospedagem ainda não escolhida.
- Mundo solo com cena própria.
- Salas de até quatro jogadores, códigos de convite e persistência em arquivo do servidor.
- Tela inicial da aventura cooperativa em texto.
- Mensagens de sala com validação de membro/UID no servidor, limite de 300 caracteres, intervalo mínimo entre envios, histórico limitado a 100 mensagens e persistência.
- Participantes de sala são mantidos fora da simulação espacial solo.

### Em desenvolvimento ou ainda não concluído

- Catálogo e geração real de criaturas por IA, sem API paga não aprovada.
- Catálogo completo de missões cooperativas e fluxo de objetivos.
- Combate cooperativo narrativo e autoridade do servidor para ações/recompensas compartilhadas.
- Recompensas cooperativas, roleta, ovos e distribuição final.
- Interface completa de participantes, ações e progresso da aventura.
- Testes de integração em dois celulares e reinício real do servidor.
- Escolha e configuração de hospedagem UDP.
- Arte final, animações, áudio e polimento visual.
- Exportação e teste do APK.

## Política de atualização

Ao concluir cada sistema, registrar aqui:
1. Arquivos e sistemas alterados.
2. O que realmente funciona.
3. Testes automatizados executados e resultado.
4. O que ainda depende de teste em dispositivo ou servidor real.

Nunca marcar uma ideia como concluída apenas porque existe uma tela, uma estrutura de dados ou um protótipo.
