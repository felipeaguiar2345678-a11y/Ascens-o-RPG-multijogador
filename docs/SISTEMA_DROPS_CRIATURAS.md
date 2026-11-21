# Sistema de drops das criaturas

## Direção do sistema

O motor de drops é genérico: não mantém uma lista fixa de monstros nem inventa um banco manual de inimigos. Cada criatura criada pelo sistema de geração de criaturas poderá fornecer sua própria `tabelaDrops`, validada antes de ser aceita pelo servidor.

Arquivo inicial: `godot/scripts/sistema_drops.gd`.

## Categorias previstas

- Materiais: couro, pele, escamas, ossos, dentes, presas, garras, chifres, carapaças e partes preservadas.
- Núcleos e essências: elementais, arcanos, espirituais, sombrios, dracônicos e outras afinidades que a criatura possuir.
- Equipamentos: armas físicas, mágicas e híbridas; armaduras leves, médias e pesadas; escudos e acessórios.
- Conhecimento: grimórios, pergaminhos, fragmentos de habilidade e receitas.
- Itens especiais: ovos, criaturas seladas, chaves, mapas, relíquias e componentes de evolução.

A categoria e o identificador do item vêm da tabela da criatura. O motor não limita o gerador a uma lista fechada de tipos de item.

## Raridades

Comum, incomum, raro, épico, lendário, mítico, divino, transcendente e único.

O motor aplica multiplicadores de chance por raridade. Esses valores são parâmetros iniciais de balanceamento, não probabilidades finais prometidas; deverão ser ajustados com testes de jogo e dados de economia.

## Condições da batalha

A tabela pode associar um material a uma parte corporal. O contexto da batalha informa quais partes foram danificadas ou preservadas:
- Parte danificada: o material correspondente não é gerado.
- Parte intacta: chance de obtenção recebe bônus.
- Sem informação: chance normal.

Isso permite que o modo de derrotar a criatura altere os materiais recuperados.

## Formato de uma entrada

```gdscript
{
    "itemId": "escama_draconica",
    "nome": "Escama dracônica",
    "categoria": "material",
    "raridade": "raro",
    "chance": 0.35,
    "quantidadeMinima": 1,
    "quantidadeMaxima": 3,
    "parteCorporal": "escamas"
}
```

## Segurança e multiplayer

A tabela deve ser validada e o sorteio executado no servidor dedicado. O cliente não escolhe item, quantidade, raridade nem resultado. O servidor também deve validar participação, elegibilidade e distribuição de recompensas antes de creditar inventário.

## Próximas integrações

1. Integrar a tabela gerada pela IA ao registro global de criaturas.
2. Conectar a resolução de combate ao motor de drops.
3. Implementar inventário e persistência autoritativa de itens.
4. Criar descoberta global de itens desconhecidos, primeiro descobridor e histórico.
5. Implementar distribuição de grupo, ovos e regras de contribuição.
6. Adicionar tabelas específicas para chefes e eventos mundiais.

## Estado honesto

O motor genérico e seus testes básicos estão sendo adicionados ao projeto Godot. Ainda não está conectado a um combate jogável, inventário persistente, catálogo global de descobertas ou distribuição multiplayer. Nenhum serviço pago ou API externa é necessário para esta base.
