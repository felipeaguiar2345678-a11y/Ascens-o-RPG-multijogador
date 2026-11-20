# Ascensão do Soberano — projeto Godot

Este diretório contém a migração do jogo para Godot 4.7.2 estável, usando GDScript e renderizador Compatibility para priorizar dispositivos Android.

## Abrir
Abra este diretório no Godot 4.7.2 ou superior. A cena inicial é `scenes/mundo_principal.tscn`.

## Implementado na base atual
- Mapa regional amplo de referência para a Região Central e a cidade de Aurelia.
- Câmera 2D acompanhando o personagem, com limites do mundo.
- Movimento por teclado para testes no computador.
- Joystick virtual na tela para controle por toque.
- Estrutura opcional de companheiro seguidor, desativada até o jogador desbloquear um pet.
- Cena de personagem e companheiro com formas geométricas temporárias para validar escala e movimentação.

## Próximas etapas
- Substituir a composição geométrica por arte pixelada final, tilesets e construções modulares.
- Implementar colisões reais, passagens entre áreas e salvamento da posição.
- Conectar exploração, encontros e retorno ao ponto exato após combate por turnos.
- Portar personagem, criaturas, inventário, progressão e catálogo global.
- Integrar autenticação e persistência de forma segura.
- Configurar exportação e validar o APK em aparelho Android.

## Regras da migração
- O projeto Android/Kotlin anterior permanece preservado durante a migração.
- A branch de migração é isolada; não substituir a versão principal nem o backup sem validação.
- Sistemas antigos serão portados em módulos, não copiados como um bloco único.
- Nenhuma API paga, geração paga de imagens ou serviço com cobrança será ativado sem aprovação explícita.

## Estado de validação
A validação headless anterior passou. As alterações recentes de mapa, joystick e companheiro precisam passar pela execução automática atual; isso ainda não equivale a um APK Android pronto.
