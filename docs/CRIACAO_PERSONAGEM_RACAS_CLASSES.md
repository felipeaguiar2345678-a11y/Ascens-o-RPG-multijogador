# Criação de personagem — raças, classes e identidade

A criação inicial passa a oferecer:
- Sexo: masculino ou feminino.
- 8 aparências por sexo (16 opções iniciais). Os identificadores são opções de catálogo; sprites finais ainda precisam ser produzidos.
- 8 raças: Humano, Elfo, Anão, Orc, Fera, Draconiano, Silvestre e Umbral.
- 8 classes: Guerreiro, Cavaleiro, Assassino, Arqueiro, Mago, Curandeiro, Monge e Invocador.

Raça e classe aplicam modificadores somados aos cinco atributos base (5 cada). O catálogo define descrições e afinidades físicas/mágicas; vida e mana máximas são calculadas a partir de vitalidade, espírito e inteligência. As escolhas são enviadas ao servidor, validadas lá e persistidas no perfil do jogador. O cliente não escolhe os valores finais dos atributos.

A classe é uma afinidade inicial, não uma trava permanente de habilidades. Evolução futura deve permitir aprender técnicas de outras escolas por treinamento, itens, mestres e eventos, respeitando requisitos e balanceamento.

As opções e modificadores atuais são uma primeira tabela de balanceamento e podem ser ajustados. Nenhum serviço pago ou API externa foi adicionado.
