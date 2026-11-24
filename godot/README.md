# Ascensão do Soberano — projeto Godot

Este diretório contém a migração do jogo para Godot 4.7.2 estável, usando GDScript e renderizador Compatibility para priorizar dispositivos Android. **Direção oficial: jogo exclusivamente online e multiplayer, em um único mundo persistente compartilhado. Não haverá modo offline ou campanha separada.**

## Abrir
Abra este diretório no Godot 4.7.2 ou superior. A cena inicial é `scenes/conexao_multiplayer.tscn`; o mapa só abre após conexão ENet confirmada.

## Implementado na base atual
- Mapa regional amplo de referência para a Região Central e a cidade de Aurelia.
- Câmera 2D acompanhando o personagem, com limites do mundo.
- Movimento por teclado para testes no computador.
- Joystick virtual na tela para controle por toque.
- Estrutura opcional de companheiro seguidor, desativada até o jogador desbloquear um pet.
- Jǫrmungandr contorna o perímetro da área liberada como guardião lendário, com barreiras físicas no limite.
- Aviso visual de perigo que aparece quando o jogador se aproxima do perímetro protegido por Jǫrmungandr.
- Cena de personagem e companheiro com formas geométricas temporárias para validar escala e movimentação.

- Personagem opcional Iren na Clareira Inicial, com conversa contextual sobre Aurelia, a Floresta Arcana e suas viagens; a interação não inicia missões automaticamente. A personagem ainda é local ao cliente e permanece parada.
- Módulo de domínio para missões opcionais oferecidas por NPCs: listar ofertas sem aceitar automaticamente, aceitar, recusar e voltar depois, abandonar e reaceitar, validar progresso por eventos confirmados pelo servidor e preparar conclusão sem duplicar recompensa. O módulo ainda precisa ser conectado ao fluxo de interação do mundo, à persistência por personagem e aos eventos reais do servidor.

## Próximas etapas
- Substituir a composição geométrica e o guardião provisório por arte pixelada final, tilesets e construções modulares.
- Desenvolver a presença ativa, animações, regras de encontro e combate lendário de Jǫrmungandr; ainda não implementados.
- Implementar colisões reais, passagens entre áreas e salvamento da posição.
- Conectar exploração, encontros e retorno ao ponto exato após combate por turnos.
- Portar personagem, criaturas, inventário, progressão e catálogo global.
- Camada inicial de conexão ENet em `scripts/rede_multiplayer.gd`, registrada como singleton `RedeMultiplayer`.
- Tela inicial em `scenes/conexao_multiplayer.tscn` com cadastro/login Firebase por e-mail e senha e endereço/porta UDP; o mapa só abre após validação da conta pelo servidor.
- Validação inicial de movimento no servidor com intervalo mínimo entre pacotes, medição de tempo no servidor e rejeição de deslocamentos excessivos.
- Entrada dedicada de servidor headless em `scenes/servidor_dedicado.tscn`, com porta e limite configuráveis por argumentos.
- Protocolo inicial de entrada no mundo: o servidor mantém uma lista de presença e envia a lista de jogadores já conectados; clientes exibem representações provisórias dos demais.
- Relógio acelerado calculado no servidor e compartilhado com todos; a semente dos fenômenos celestes é persistida em disco para não mudar quando o processo reinicia.
- Combates iniciados e resolvidos pelo servidor usando o mesmo período celeste do mundo; ações repetidas são limitadas por intervalo mínimo.
- Persistência local de personagens, posição, inventário, equipamentos e dados ecológicos no disco do servidor, com cópias de segurança nos repositórios correspondentes.
- Integrar autenticação e persistência de forma segura antes de abrir o acesso público.
- Completar a arquitetura online autoritativa: validar colisões, movimento, combate, inventário, economia, eventos e chefes mundiais no servidor; clientes Godot apenas exibem e solicitam ações.
- Sincronizar todos os jogadores no mesmo mundo/região, com progressão individual e estado coletivo persistente.
- Configurar exportação Android e validar o APK em aparelho real, além de testar dois ou mais clientes simultâneos.

## Direção multiplayer obrigatória
- O jogo exige conexão com o servidor para entrar; não existe modo offline separado.
- Todos os jogadores compartilham o mesmo mundo persistente, cidades, regiões, eventos, criaturas e chefes mundiais.
- Cada jogador mantém personagem, progressão, equipamentos e inventário próprios.
- O servidor é a autoridade do estado compartilhado e valida ações importantes; o cliente não decide sozinho dano, recompensas, economia ou resultado de eventos.
- Instâncias técnicas podem ser usadas apenas se necessárias à escala, mas não devem criar campanhas privadas ou mundos divergentes. A experiência deve preservar um único mundo lógico compartilhado.
- Antes de contratar ou ativar qualquer serviço pago, explicar custos e obter aprovação explícita.

## Regras da migração
- O projeto Android/Kotlin anterior permanece preservado durante a migração.
- A branch de migração é isolada; não substituir a versão principal nem o backup sem validação.
- Sistemas antigos serão portados em módulos, não copiados como um bloco único.
- Nenhuma API paga, geração paga de imagens ou serviço com cobrança será ativado sem aprovação explícita.

## Multiplayer online — estado atual
A direção oficial é exclusivamente online, com um único mundo lógico persistente. A camada ENet e a entrada headless dedicada foram adicionadas. O servidor valida o ID token Firebase, associa o UID ao peer e persiste localmente personagens, posição, inventário e equipamentos em arquivos JSON no disco do processo dedicado. O catálogo de criaturas e a ecologia também possuem repositórios locais. O relógio compartilhado e sua semente celeste são mantidos pelo servidor; o combate usa o mesmo período do mundo e limita a frequência das ações. **Limitações ainda abertas:** não há servidor público ativo nem banco de dados em nuvem compartilhado; a validação de movimento ainda não contempla colisões autoritativas completas, zonas seguras e antitrapaça abrangente; os encontros automáticos de exploração ainda não estão conectados a zonas validadas pelo servidor; falta teste real com dois ou mais aparelhos Android. O login precisa ser testado com E-mail/senha habilitado no Firebase. Consulte `docs/AUTENTICACAO_FIREBASE_GODOT.md`, `docs/BASE_CONEXAO_MULTIPLAYER.md` e `docs/SINCRONIZACAO_MOVIMENTO_MULTIPLAYER.md`.

## Estado de validação
A validação headless anterior passou. As alterações recentes de mapa, joystick e companheiro precisam passar pela execução automática atual; isso ainda não equivale a um APK Android pronto.


## Verificação automatizada

O fluxo `.github/workflows/validar-godot.yml` importa e abre o projeto em modo headless e, em seguida, descobre e executa todos os arquivos `godot/tests/teste_*.gd`. Assim, testes novos entram automaticamente na validação sem exigir uma alteração manual no YAML. Cada teste tem limite de 60 segundos; qualquer falha interrompe a execução e reprova o fluxo. Uma execução verde confirma apenas os testes automatizados, não substitui testes em Android real nem valida servidor público, arte final ou sincronização entre aparelhos.


### Persistência de missões opcionais

O perfil do personagem mantém o estado individual das missões em andamento, recusadas ou abandonadas no campo `missoes`, separado do histórico `missoesConcluidas`. O repositório valida o formato/status antes de salvar, aplica o controle de revisão já existente e inclui esse progresso no arquivo principal e no backup. Isso prepara a persistência, mas não significa que as ofertas de NPC ou os eventos de objetivos já estejam conectados ao servidor e à interface.

O repositório também oferece `salvar_missoes(uid, missoes)`: a operação recarrega a revisão mais recente do personagem, valida os estados permitidos e grava apenas o progresso de missões, evitando que uma cópia antiga do perfil apague alterações recentes. A operação é interna ao servidor e não deve ser exposta diretamente como RPC. A validação também restringe os campos persistidos, as dificuldades, o tamanho do progresso e os identificadores dos objetivos; valores negativos, campos de recompensa injetados e estruturas fora do formato esperado são rejeitados.

O pagamento de uma missão também exige que ela exista no perfil com estado `objetivos_concluidos` e que a dificuldade recebida corresponda à dificuldade registrada pelo servidor. O recibo de recompensa, o saldo de Bronzhar e a mudança do estado para `recompensada` são gravados juntos no perfil. Uma tentativa repetida é bloqueada pelo histórico idempotente. Isso protege a camada de persistência, mas ainda não substitui a integração das ofertas de NPC e dos eventos reais do mundo com o servidor.
