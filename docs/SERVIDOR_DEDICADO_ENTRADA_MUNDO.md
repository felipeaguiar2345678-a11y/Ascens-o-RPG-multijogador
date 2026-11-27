# Servidor dedicado e entrada no mundo — etapa inicial

## Entrega

- Cena dedicada: `res://scenes/servidor_dedicado.tscn`.
- Script: `res://scripts/servidor_dedicado.gd`.
- Execução headless: `godot --headless --path godot res://scenes/servidor_dedicado.tscn`.
- Porta padrão UDP: 2456; pode ser alterada com `--porta=NUMERO`.
- Limite padrão configurado: 100 conexões; pode ser alterado com `--limite=NUMERO`.
- O singleton `RedeMultiplayer` aceita entrada no mundo, mantém presença básica por ID de peer e envia a lista inicial de jogadores.
- O cliente cria representações provisórias para os outros jogadores e remove a representação quando o peer desconecta.

## Limitações conhecidas

Esta etapa não implementa ainda:
- sincronização contínua/validada de movimento;
- autenticação e associação com conta/personagem;
- persistência de posição ou sessão;
- autoridade de combate, economia, itens ou estado mundial;
- reconexão automática;
- servidor publicado na internet ou hospedagem configurada.

O servidor dedicado atual é uma base técnica de transporte/presença, não um servidor de produção. O mundo ainda não deve ser considerado multiplayer completo nem seguro para competição.

## Segurança e implantação

- Não expor o servidor publicamente sem firewall, limites de conexão, autenticação e validação de protocolo.
- ENet utiliza UDP; a porta precisa ser liberada em UDP na infraestrutura escolhida.
- Não confiar em dados do cliente para determinar dano, posição final, inventário ou recompensas.
- Nenhuma hospedagem paga foi contratada ou ativada. Custos e limites precisam ser comparados antes de publicar.
