# Criação de personagem — raças, classes e identidade

A criação inicial passa a oferecer:
- Sexo: masculino ou feminino.
- 8 aparências por sexo (16 opções iniciais). Os identificadores são opções de catálogo; sprites finais ainda precisam ser produzidos.
- 8 raças: Humano, Elfo, Anão, Orc, Fera, Draconiano, Silvestre e Umbral.
- 8 classes: Guerreiro, Cavaleiro, Assassino, Arqueiro, Mago, Curandeiro, Monge e Invocador.

Raça e classe aplicam modificadores somados aos cinco atributos base (5 cada). O catálogo define descrições e afinidades físicas/mágicas; vida e mana máximas são calculadas a partir de vitalidade, espírito e inteligência. As escolhas são enviadas ao servidor, validadas lá e persistidas no perfil do jogador. O cliente não escolhe os valores finais dos atributos.

A classe é uma afinidade inicial, não uma trava permanente de habilidades. Evolução futura deve permitir aprender técnicas de outras escolas por treinamento, itens, mestres e eventos, respeitando requisitos e balanceamento.

As opções e modificadores atuais são uma primeira tabela de balanceamento e podem ser ajustados. Nenhum serviço pago ou API externa foi adicionado.

## Anatomia e identidade visual das raças

A raça também define dados anatômicos persistidos e validados pelo servidor, usados pelo futuro montador de aparência do avatar:
- Humano: proporções comuns, altura de referência, orelhas humanas e sem apêndices raciais.
- Elfo: corpo esguio e orelhas longas pontudas.
- Anão: escala de altura 0,72 em relação ao humano, corpo baixo e robusto, ombros largos.
- Orc: maior estatura, corpo muito forte, mandíbula marcada e presas.
- Fera: orelhas bestiais, garras, cauda e pele/pelagem variável.
- Draconiano: escamas, chifres, asas recolhidas, cauda dracônica e olhos reptilianos.
- Silvestre: orelhas alongadas e marcas vegetais.
- Umbral: orelhas sutilmente pontudas, olhos luminosos e runas sombrias.

A tela de criação mostra a descrição física e a altura relativa antes da confirmação. Os dados anatômicos são calculados pelo catálogo no servidor e gravados no perfil; o cliente não pode inventar uma anatomia diferente da raça escolhida.

Nota de produção: os metadados e a prévia textual estão implementados; sprites/peças 2D finais e o montador visual em tempo real ainda precisam ser produzidos para que essas características apareçam graficamente no mapa.
