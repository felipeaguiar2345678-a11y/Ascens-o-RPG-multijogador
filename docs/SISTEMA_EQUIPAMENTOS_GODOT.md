# Sistema de equipamentos — Godot

## Implementado nesta etapa

- Catálogo de armas físicas, mágicas e híbridas.
- Armas de uma mão e de duas mãos.
- Escudos leves, médios, pesados e arcanos.
- Armaduras leves, médias e pesadas em cabeça, torso, pernas, mãos e pés, além de capa/manto.
- Acessórios: um anel, um colar, bracelete e cinto.
- Inventário persistente e espaços equipados guardados no perfil do personagem.
- Equipar e desequipar executados pelo repositório do servidor, não por RPC livre do cliente.
- Verificação de posse do item no inventário antes de equipar.
- Cálculo inicial de defesa, peso, penalidade de agilidade e redução de velocidade.

## Regras de mãos

- Arma de uma mão pode ser usada sozinha.
- Arma de uma mão pode combinar com escudo na mão secundária.
- Arma de duas mãos ocupa a mão principal e reserva a secundária.
- Arma pesada do catálogo usa duas mãos.
- Escudo só pode ser equipado pelas classes corpo a corpo definidas no sistema (Guerreiro, Cavaleiro, Assassino e Monge).
- A mão secundária é reservada para escudo.

## Categorias e efeitos

- Armadura leve: menor peso e menor penalidade de mobilidade.
- Armadura média: equilíbrio entre proteção e peso.
- Armadura pesada: defesa maior, peso elevado e penalidade maior conforme a força do personagem.
- Classes não têm bloqueio geral de armaduras leves/médias/pesadas; o impacto é calculado pelo peso e atributos.
- O catálogo inclui armas mágicas além de cajados e varinhas: foice arcana, orbe, grimório, corrente etérea, espada rúnica, lança elemental e arco híbrido.

## Anatomia racial e aparência

Equipamentos são armazenados em espaços próprios, separados dos dados raciais. O sistema não substitui nem apaga o campo de anatomia racial do personagem. A representação visual de peças vestidas em sprites modulares ainda precisa ser desenvolvida; nesta fase as regras e persistência estão implementadas, mas o avatar ainda não renderiza todas as peças.

## Limitações e próximos passos

- O catálogo atual é uma base inicial e pode crescer com itens gerados pela IA.
- Bônus de atributos de acessórios já são descritos no catálogo, mas ainda precisam ser somados ao cálculo geral de atributos em combate.
- Afinidade/classe e requisitos de atributo podem ganhar regras mais granulares sem proibir escolhas criativas.
- Ainda falta interface visual de inventário/equipamento e animação/camadas de sprites.
- Não existe integração com combate real ainda; o combate por turnos é uma etapa futura.
