# Atualização visual do combate — plano completo

## Direção visual aprovada

A batalha deve seguir a referência enviada: câmera cinematográfica em paisagem, herói visto de costas no primeiro plano à esquerda, criatura em destaque à direita, cenário pixel art de fantasia com profundidade, painéis de retrato/nível/vida/mana no alto, caixa de fala no canto inferior esquerdo e quatro comandos grandes no canto inferior direito.

O combate continua sendo por turnos e narrativo. Não introduzir mapa de navegação, coordenadas, joystick ou movimentação espacial no multiplayer.

## Implementado nesta etapa

- [x] Novo CombatSceneVisual: cenário 2.5D procedural local para floresta, sombras, neve, deserto, mar, ruínas, império e região central.
- [x] Camadas de céu, lua/sol, montanhas, muralhas/castelo, árvores, cristais, tochas, partículas, piso em perspectiva e plataformas/sombras de contato.
- [x] Brilho ambiental animado e chamas com oscilação leve.
- [x] Cenário recebe o bioma e o nível de destruição já acumulado na batalha.
- [x] Integrado à arena existente, atrás dos personagens e painéis.
- [x] Retratos superiores ampliados e criatura com maior presença na composição.
- [x] Preservada a arte oficial do personagem, recorte traseiro e camadas de equipamentos existentes, com fallback quando a imagem falhar.
- [x] Preservadas as artes oficiais/procedurais das criaturas e a escala especial dos chefes.
- [x] Mantidos os controles de ataque, habilidades, defesa, fuga, carregamento e encerramento conectados às ações já existentes.
- [x] Testes unitários de resolução de bioma adicionados.
- [x] Workflow separado para compilar Kotlin e executar testes unitários na branch de desenvolvimento sem gerar APK.

## Próximas entregas visuais necessárias

### 1. Arte de cenários finais
- Criar cenários pixel art dedicados de alta qualidade para cada ecossistema, sem reutilizar uma única composição para todos.
- Variar hora do dia, clima, iluminação, elementos de fundo e elementos interativos puramente visuais.
- Criar variações de arena para chefes regionais e chefes mundiais.
- Definir cache, tamanho máximo, carregamento assíncrono e fallback offline antes de incorporar imagens grandes.

### 2. Personagens e criaturas
- Validar em aparelho real o recorte da folha de personagem, vista traseira e camadas dianteira/traseira dos equipamentos.
- Ajustar proporções, encaixe de armas, escudos, capas, elmos e armaduras em diferentes classes e corpos.
- Criar animações de repouso e ataque para as criaturas geradas, mantendo identidade e anatomia próprias.
- Tratar criatura sem imagem oficial com fallback que preserve espécie, rank, raridade e traços, sem substituir o registro global.

### 3. Animações e efeitos
- Coreografar ataque físico, esquiva, defesa, investida, salto, teleporte e habilidades mágicas.
- Acrescentar impacto localizado, faíscas, poeira, rachaduras, congelamento, fogo, veneno e efeitos persistentes.
- Criar entrada e derrota de chefes com transições curtas, sem atrasar o turno ou permitir ações duplicadas.
- Respeitar acessibilidade e desempenho: efeitos reduzidos em aparelhos lentos e sem animações que bloqueiem comandos.

### 4. Interface e experiência
- Finalizar molduras ornamentadas, tipografia legível, ícones e estados pressionado/desabilitado.
- Mostrar claramente turno atual, estados negativos, carga/quebra de habilidades e recargas sem poluir a arena.
- Em telas estreitas, manter versão retrato funcional; em paisagem, priorizar a composição cinematográfica da referência.
- Garantir que a caixa de diálogo não esconda o herói, inimigo ou informações importantes.
- Mostrar companheiro ao lado do herói sem cobrir arma ou silhueta principal.

### 5. Qualidade e validação
- Executar :app:compileDebugKotlin e :app:testDebugUnitTest no GitHub Actions.
- Corrigir todos os erros de compilação/teste encontrados antes de avançar.
- Testar retrato/paisagem, telas pequenas, baixa memória, perda de conexão e imagens ausentes.
- Verificar que animações não alteram dano, turnos, recompensas ou sincronização cooperativa.
- Fazer teste visual no aparelho antes de considerar a etapa pronta.

## Custos e serviços

Esta atualização de cenário é procedural e local: não solicita novas imagens a uma API paga, não altera limites de orçamento e não habilita geração paga. Se uma futura etapa precisar de geração externa, o custo e o limite serão apresentados antes de qualquer mudança.

## Estado atual

Código e testes foram enviados à branch combate-cinematico-integrado. O workflow de validação Kotlin/testes foi habilitado separadamente do job de APK. A etapa só deve ser considerada validada após o workflow concluir com sucesso e depois de uma inspeção visual no aparelho. Nenhum APK foi gerado nesta atualização.
