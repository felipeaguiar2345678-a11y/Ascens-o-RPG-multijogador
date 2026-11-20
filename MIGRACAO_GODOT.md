# Migração para Godot — Ascensão do Soberano

## Decisão técnica
Motor: Godot 4.7.2 estável, renderizador Compatibility e GDScript. A versão 4.8 ainda está em beta na data desta decisão; portanto, não será usada em produção.

## Objetivo de produto
RPG 2D de ação e exploração em tempo real, com câmera acompanhando o personagem, joystick virtual, colisões, cidades e grandes regiões conectadas. O combate ocorre em uma tela própria por turnos, com regras e identidade visual do Ascensão.

## Preservação
O projeto Android/Kotlin atual não será apagado durante a migração. A branch de backup do RPG de texto será mantida intacta. A migração ocorre nesta branch isolada.

## Sistemas que devem ser reaproveitados/adaptados
- Perfil, atributos, nível, experiência e salvamento do personagem.
- Catálogo global de criaturas, raridades, ecossistemas, chefes e descoberta individual.
- Regras de combate, habilidades, efeitos, turnos, vitória/derrota e recompensas.
- Inventário, equipamentos, ovos, companheiros e progressão.
- Contas e dados persistidos no Firebase.

## Regras de descoberta visual
Criaturas com visual já registrado e armazenado podem aparecer com sua arte existente. Criaturas sem visual conhecido podem ser representadas por silhueta escura e interrogação ou por encontro surpresa, sem revelar uma arte inexistente. Descoberta global não substitui descoberta individual.

## Arquitetura alvo
- Godot: cenas, exploração 2D, câmera, controles, colisões, animações e apresentação do combate.
- GDScript: lógica de jogo executada no motor.
- Firebase: autenticação e persistência. A integração será avaliada entre REST com token Firebase e ponte Android nativa; nenhuma credencial será colocada no cliente.
- Kotlin existente: referência e fonte dos contratos/regras a portar, não dependência automática do runtime Godot.
- GitHub Actions: validação headless e, em etapa posterior, exportação Android.

## Etapas
1. Criar projeto Godot isolado e validar abertura/headless.
2. Definir contratos de dados e adaptadores para os sistemas Kotlin.
3. Construir controle móvel, personagem, câmera, colisões e mapa de exploração.
4. Construir áreas, biomas, cidades e transições.
5. Portar combate por turnos e recompensas.
6. Portar persistência e autenticação Firebase.
7. Configurar exportação Android, gerar APK e testar em dispositivo real.
8. Migrar dados e fluxo principal somente após testes de compatibilidade.

## Restrições
- Não apagar nem sobrescrever o projeto antigo nesta fase.
- Não habilitar serviços pagos, APIs pagas ou geração paga de arte sem autorização específica após explicar custos.
- Não usar EnemyDatabase manual como fonte de criaturas; a geração e o catálogo de criaturas devem seguir o sistema dinâmico já definido.
- Não declarar APK pronto sem exportação e teste reais.
