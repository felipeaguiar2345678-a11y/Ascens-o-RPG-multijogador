# Interface de inventário e equipamentos — Godot

## Implementado
- Botão **Mochila** na tela do mundo.
- Painel com todos os espaços de equipamento e seus itens atuais.
- Inventário com nome, quantidade e ação **Usar** para itens reconhecidos pelo catálogo de equipamentos.
- Ação **Retirar** em cada espaço ocupado.
- Mensagens de retorno para pedidos aceitos ou recusados.
- Atualização da tela a partir do perfil recebido do servidor.

## Autoridade e persistência
A interface chama somente `RedeMultiplayer.solicitar_equipar_item` e `solicitar_desequipar_slot`. O servidor identifica o jogador pelo peer autenticado, valida propriedade e regras no repositório, salva o perfil e devolve a atualização. O cliente não altera diretamente o inventário nem os espaços equipados.

## Limites atuais
- A interface é funcional e provisória; ainda precisa de refinamento visual e adaptação de layout para diferentes resoluções.
- Itens que não pertencem ao catálogo de equipamentos aparecem no inventário, mas não exibem a ação **Usar**.
- Ainda não há tela de detalhes, comparação de atributos, filtros, organização por raridade ou confirmação de substituição.
- A aparência do avatar ainda não renderiza as peças equipadas.
- Bônus de acessórios ainda não estão incorporados aos atributos efetivos de combate.
- O salvamento atual do servidor é local ao processo dedicado de desenvolvimento; ainda não é persistência em nuvem nem hospedagem de produção.

## Arquivos
- `godot/scripts/interface_inventario_equipamentos.gd`
- `godot/scripts/mundo_principal.gd`
- `godot/scripts/rede_multiplayer.gd`
- `godot/scripts/repositorio_personagem_servidor.gd`
- `godot/scripts/sistema_equipamentos.gd`
