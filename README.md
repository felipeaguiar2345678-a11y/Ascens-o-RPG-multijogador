# Ascensão do Soberano

Projeto ativo do RPG 2D online, atualmente em migração e desenvolvimento com **Godot 4.7.2**.

## Projeto ativo

- Projeto Godot em `godot/`.
- Cena inicial: `godot/scenes/conexao_multiplayer.tscn`.
- Renderização compatível com dispositivos móveis usando GL Compatibility.
- Rede ENet e autenticação de conta Firebase validadas pelo servidor.
- Mundo compartilhado com jogadores, criaturas persistentes, ecologia, ciclo celeste e eventos globais.
- Combate, inventário, equipamentos, companheiros e recompensas processados por lógica autoritativa do servidor.
- Salas cooperativas com aventura narrativa compartilhada; a sala não usa mapa espacial próprio.

## Missões opcionais do mundo

As missões são oportunidades narrativas, não uma trilha obrigatória. O jogador pode explorar o mundo sem aceitar missões.

- NPCs podem apresentar ofertas próprias; o jogador pode aceitar ou recusar.
- Missões aceitas podem ser abandonadas quando permitido e entregues ao NPC responsável após os objetivos serem concluídos.
- O servidor valida identidade, proximidade do NPC, vínculo da missão e estado dos objetivos.
- Derrotas de criaturas só avançam objetivos depois da vitória confirmada pelo motor de combate.
- O catálogo de ofertas do mundo é salvo em `user://dados/ofertas_missoes_mundo.json` e recarregado quando o serviço do servidor é recriado.
- O painel de Iren já consulta ofertas e progresso. **O catálogo ainda não contém uma missão autoral registrada para ela**, portanto a lista pode aparecer vazia. Nenhuma missão fictícia foi inserida para preencher a interface.
- Eventos de coleta e visita a locais ainda precisam ser conectados aos respectivos pontos de confirmação autoritativa.

## Validação

O fluxo de integração contínua está em `.github/workflows/validar-godot.yml`. Ele instala Godot 4.7.2, importa o projeto, inicia uma execução headless e roda os scripts em `godot/tests/teste_*.gd`.

Para validar localmente com Godot 4.7.2:

```bash
godot --headless --editor --path godot --quit
godot --headless --path godot --quit-after 5

for arquivo in godot/tests/teste_*.gd; do
  godot --headless --path godot --script "res://tests/$(basename "$arquivo")"
done
```

## Estado da entrega

- O projeto Godot está em desenvolvimento; os sistemas descritos acima não significam que o jogo esteja finalizado.
- A validação automatizada mais recente deve ser conferida na aba **Actions** antes de considerar uma alteração aprovada.
- **APK ainda não é a etapa atual.** A exportação Android fica para depois da estabilização e validação do projeto.
- Não há geração de criaturas por IA externa ativa neste código apenas por existir catálogo/ecologia; qualquer integração paga ou que exija chave/API precisa de aprovação explícita antes de ser adicionada.

## Estrutura principal

- `godot/scripts/`: sistemas de jogo, rede e serviços do servidor.
- `godot/scenes/`: cenas do jogo.
- `godot/tests/`: testes automatizados.
- `.github/workflows/validar-godot.yml`: validação contínua do Godot.
