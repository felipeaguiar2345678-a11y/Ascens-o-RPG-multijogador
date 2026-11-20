# Ascensão do Soberano — projeto Godot

Este diretório inicia a migração para Godot 4.7.2 estável, usando GDScript e renderizador Compatibility para priorizar dispositivos Android.

## Abrir
Abra este diretório no Godot 4.7.2 ou superior. A cena inicial é `scenes/mundo_principal.tscn`.

## Estado atual
- Estrutura inicial do projeto e cena principal.
- Personagem-base com física 2D e câmera acompanhando.
- Configuração inicial para tela 16:9 e filtro pixelado.
- A arte geométrica atual é apenas um marcador técnico, não a arte final do jogo.
- Joystick virtual, mapas finais, colisões de cenário, animações e integração de conta/Firebase ainda serão implementados e testados.

## Regras da migração
- O projeto Android/Kotlin anterior permanece preservado durante a migração.
- Sistemas de personagem, criaturas, combate, inventário e progressão serão portados em etapas, com validação.
- Nenhuma API paga, geração paga de imagens ou serviço com cobrança será ativado sem aprovação explícita.
