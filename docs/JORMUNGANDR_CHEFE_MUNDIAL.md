# Jǫrmungandr — Chefe Mundial e Ciclos de Renascimento

> Documento de referência do projeto **Ascensão do Soberano**. Reúne as ideias e decisões definidas para a Serpente do Mundo, para que sejam preservadas durante a migração para Godot.

**Estado:** especificação de projeto; a maior parte deste sistema ainda precisa ser implementada.  
**Branch de trabalho:** `godot-migracao-definitiva`  
**Última consolidação:** 20/11/2026

---

## 1. Conceito central

Jǫrmungandr é a Serpente do Mundo e guardiã colossal do perímetro da região explorável. Ela não é um monstro comum: é um **Chefe Mundial lendário**, extremamente perigoso, cuja presença e evolução afetam o mundo inteiro.

- Seu corpo serpentino acompanha o perímetro da área de mundo liberada.
- A cabeça colossal fica na borda norte, com olhos dourados e escamas.
- Ela impede a saída da área atual; não é necessário derrotá-la para explorar Aurelia.
- Quando o mapa for expandido, o perímetro/traçado da serpente deverá se adaptar à nova área.
- O aviso de proximidade deve alertar o jogador antes de chegar ao limite.

A inspiração mitológica vem do confronto entre Thor e Jǫrmungandr no Ragnarök. A cena do jogo deve ser uma interpretação original dessa inspiração, não uma reprodução obrigatória e literal do mito.

## 2. Chefe Mundial compartilhado

Todos os jogadores enfrentam **a mesma entidade global**, não cópias independentes.

- Existe uma única vida global compartilhada.
- O dano validado de cada jogador reduz essa mesma vida.
- As alterações de vida e o placar são refletidos para todos.
- Ao tocar/interagir com o corpo da serpente quando ela estiver pronta, o jogador pode iniciar um combate por turnos.
- Ao terminar o combate, o personagem retorna exatamente ao ponto do mapa em que estava antes do encontro.
- O dano causado deve continuar registrado no estado mundial, mesmo depois de o jogador sair do combate.
- A entidade não pode ser derrotada várias vezes por corridas simultâneas: quando a vida global chega a zero, o ciclo é encerrado uma única vez.

### Placar e recompensas

- Manter um placar mundial de contribuição/dano por ciclo.
- Congelar o ranking no instante em que a vida global chegar a zero.
- Os três primeiros colocados recebem oportunidades especiais de recompensas raras; a sorte influencia quais itens cada um obtém.
- Os demais participantes também devem ter incentivo/recompensa, idealmente proporcional à contribuição, sem retirar a importância do top 3.
- Recompensas e encerramento do ciclo devem ser concedidos uma única vez por jogador.
- O histórico de ciclos anteriores deve ser preservado, mesmo quando o placar do novo ciclo começar.

## 3. Derrota, animação e ruptura temporal

Quando a vida global chegar a zero:

1. Encerrar a batalha mundial e impedir novos ataques naquele ciclo.
2. Exibir um acontecimento mundial compartilhado, com o céu escurecendo e sinais de que algo extraordinário está ocorrendo.
3. Mostrar uma animação especial inspirada no confronto de Thor com a serpente: Thor surge e atinge Jǫrmungandr com seu poder/arma.
4. A serpente começa a desaparecer e provoca uma ruptura temporal.
5. O tempo retrocede visualmente; o mundo testemunha a passagem para um novo ciclo.
6. Jǫrmungandr não é simplesmente removida para sempre: ela retorna pequena, iniciando um novo período de crescimento.

A animação deve ser sincronizada como evento mundial, para que todos vejam a mesma sequência e o mesmo resultado. A implementação visual final ainda está pendente.

## 4. Renascimento e crescimento global

**Decisão confirmada:** Jǫrmungandr retorna pequena, cresce gradualmente e não pode iniciar combate enquanto estiver nessa fase.

O crescimento usa o relógio do mundo, não o tempo individual de cada jogador:

- O progresso continua mesmo quando um jogador está offline.
- Todos os jogadores observam a mesma fase, tamanho e estado da entidade.
- O estágio global deve ser persistido e calculado a partir de uma referência temporal mundial confiável.
- Durante o crescimento, não há combate contra o Chefe Mundial e a barra de vida global de combate não fica disponível.
- Ela pode ser vista ou percebida em aparições distantes, sombras, movimentos no oceano, tremores e outros sinais ambientais, sem permitir que o jogador a desafie.

### Etapas visuais/conceituais

1. **Renascimento:** forma pequena; vulnerável apenas no sentido narrativo, mas não atacável.
2. **Crescimento:** aumenta de tamanho gradualmente; surgem sinais de sua presença pelo mundo; ainda não pode ser desafiada.
3. **Maturidade:** alcança tamanho e poder necessários; o combate mundial é liberado.
4. **Nova derrota:** inicia outra ruptura temporal e um novo renascimento.

Quando ela atingir a maturidade, todos recebem uma notificação mundial, por exemplo:

> **O DESPERTAR DA SERPENTE**  
> Jǫrmungandr despertou! A Serpente do Mundo cresceu. Seu poder voltou a ameaçar as terras conhecidas. O Chefe Mundial está disponível novamente.

Mensagens durante o crescimento podem incluir:
- “Algo se movimenta nas profundezas...”
- “Uma criatura colossal foi avistada.”
- “O mundo sente uma presença cada vez mais poderosa.”

## 5. Evolução a cada ciclo — alternativa C escolhida

**Decisão confirmada:** cada derrota provoca uma evolução progressiva de perigo. Ela sempre retorna, mas cada ciclo pode ser mais perigoso e provocar mudanças mais profundas no mundo.

O retorno não deve ser sempre idêntico. A cada ciclo, o sistema escolhe/gera uma nova encarnação, respeitando a identidade de Jǫrmungandr, mas podendo variar:

- forma corporal, tamanho, cores, escamas, olhos e marcas;
- mutações e características visuais;
- vida, ataque, defesa, agilidade, resistência e outros atributos;
- habilidades, efeitos, padrões e combinações de ataques;
- elementos ou afinidades, como veneno, eletricidade, corrupção ou poderes temporais;
- materiais, itens e recompensas exclusivos daquela encarnação;
- raridade da mutação e condições especiais de aparecimento.

Possibilidades de direção visual (não são uma lista fechada nem formas obrigatórias):
- **Original:** escamas escuras, olhos dourados e poderes venenosos.
- **Mutada:** corpo alterado, corrupção e habilidades inesperadas.
- **Evoluída:** aparência mais imponente, poderes temporais ou energia extraordinária.
- **Ancestral:** aparência antiga, sombria ou óssea, com poderes próprios.

A IA poderá propor mutações e variações novas, em vez de ficar limitada a quatro modelos fixos. As gerações precisam manter coerência com a identidade da serpente e respeitar limites de balanceamento.

## 6. Consequências no mapa e no mundo

A derrota e o retorno podem provocar alterações persistentes no mundo. Exemplos de consequências possíveis:

- mudanças no céu, clima, iluminação e efeitos ambientais;
- alterações em construções, monumentos e partes de Aurelia;
- florestas corrompidas ou ecossistemas transformados;
- surgimento de cavernas, ruínas e áreas de exploração;
- abertura de novas rotas ou bloqueio temporário de caminhos;
- desaparecimento de algumas criaturas e surgimento de outras;
- mudanças em encontros, eventos, missões e recursos da região;
- marcas físicas deixadas pela passagem ou pelo despertar da serpente.

Essas consequências devem ser registradas por ciclo e aplicadas de forma consistente para todos. Nem toda derrota precisa alterar tudo: a intensidade e o tipo de mudança podem variar conforme a encarnação e o ciclo.

## 7. Histórico mundial

Guardar o registro de cada encarnação/ciclo, incluindo, quando disponível:

- número/identificador do ciclo;
- datas de início, maturidade e derrota;
- aparência, mutações, atributos e habilidades daquela versão;
- vida global e duração do combate;
- participantes e contribuições individuais;
- top 3 e ranking final congelado;
- recompensas concedidas;
- animação/evento de encerramento;
- alterações do mapa e do mundo provocadas pelo ciclo.

O novo ciclo pode reiniciar o placar ativo, mas nunca apagar o histórico anterior.

## 8. Segurança, sincronização e integridade

Este sistema é global e competitivo; não se deve confiar cegamente nos dados enviados pelo cliente.

- Validar dano e contribuições em uma autoridade central.
- Evitar duplicação de ataques/requisições e recompensas.
- Usar identificadores idempotentes para que uma mesma ação não seja contabilizada duas vezes.
- Proteger a vida global contra atualizações concorrentes e impedir que fique abaixo de zero.
- Encerrar o ciclo e congelar o ranking atomicamente.
- Garantir que cada jogador receba cada recompensa de ciclo no máximo uma vez.
- Sincronizar estágio de crescimento e eventos mundiais para todos os jogadores.
- Usar horário mundial persistido/confiável, sem depender do relógio local do aparelho.

**Atenção a custos:** não contratar nem ativar APIs pagas, Cloud Functions pagas ou outros serviços pagos sem explicar previamente os custos e obter aprovação explícita do usuário. Firestore e regras executadas no cliente, isoladamente, não devem ser tratados como proteção suficiente contra trapaça em um placar/economia competitivos. Antes de escolher a arquitetura definitiva, avaliar opções gratuitas e seus limites; apresentar qualquer custo antes de ativar serviços.

## 9. Estado atual da implementação na Godot

Já existe uma primeira implementação técnica de **perímetro/guardião**, ainda provisória:

- cena `godot/scenes/guardiao_jormungandr.tscn`;
- script `godot/scripts/guardiao_jormungandr.gd`;
- o mundo instancia o guardião e informa o tamanho do mapa;
- corpo e cabeça são desenhados com formas geométricas provisórias;
- colisões físicas retangulares bloqueiam o perímetro;
- o HUD avisa quando o jogador se aproxima do limite:
  - a até 300 px: “ALGO COLOSSAL OBSERVA VOCE...”;
  - a até 130 px: “JǪRMUNGANDR BLOQUEIA SEU CAMINHO”.

Isso **não** significa que o Chefe Mundial esteja pronto. Ainda precisam ser implementados:

- arte final, sprites e animações;
- comportamento e aparições durante o crescimento;
- relógio global e persistência dos estágios;
- interação e início do combate por turnos;
- vida global compartilhada e placar;
- validação segura de dano e recompensas;
- animação mundial de derrota e ruptura temporal;
- renascimento, mutações e evolução entre ciclos;
- notificações de maturidade;
- alterações persistentes no mapa;
- histórico mundial de encarnações.

A validação automatizada/headless do projeto Godot não equivale a testar a experiência visual no Android nem significa que exista um APK final.

## 10. Decisões já tomadas e pontos ainda em aberto

### Decisões confirmadas
- Jǫrmungandr é o guardião colossal do perímetro e um Chefe Mundial.
- Todos compartilham a mesma entidade e a mesma vida global.
- O combate é por turnos e o jogador retorna ao ponto exato do mapa após o combate.
- O placar mundial registra contribuições; top 3 têm chances especiais de itens raros, influenciadas por sorte.
- A derrota desencadeia uma animação mundial inspirada em Thor e uma ruptura temporal.
- Ela retorna pequena, cresce gradualmente e não pode ser desafiada durante o crescimento.
- O crescimento continua com jogadores offline e é igual para todos.
- Ao atingir a maturidade, todos recebem uma notificação e o combate é liberado.
- Foi escolhida a alternativa C: cada derrota torna o próximo ciclo potencialmente mais perigoso e pode mudar o mundo.
- Cada ciclo e suas mudanças devem permanecer no histórico.

### A definir durante o planejamento técnico
- Duração exata do crescimento e se haverá variação entre ciclos.
- Tamanho, estágios e ritmo visual de crescimento.
- Fórmula de aumento de dificuldade e limites de balanceamento.
- Probabilidades e regras de mutações/raridades.
- Regras exatas de recompensas para participantes fora do top 3.
- Quais mudanças do mapa serão temporárias ou permanentes.
- Como será apresentada a animação e como sincronizá-la tecnicamente.
- Arquitetura global gratuita/segura e limites de escala antes de qualquer serviço pago.

---

**Regra de preservação:** antes de implementar ou alterar Jǫrmungandr, consultar este documento. Se uma nova ideia mudar alguma decisão confirmada, atualizar este arquivo para manter uma única referência oficial.
