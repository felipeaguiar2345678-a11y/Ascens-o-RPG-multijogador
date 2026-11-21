# Catálogo global de criaturas geradas

## Objetivo
O catálogo recebe criaturas completas fornecidas por um gerador confiável executado no servidor. Ele não mantém uma lista artesanal de inimigos e não finge produzir IA: a integração com um provedor de geração será uma etapa separada, sujeita à escolha e aprovação de custos.

## Registro e validação
- Arquivo de desenvolvimento: `user://dados/criaturas_online.json`, com cópia `.bak` e gravação temporária.
- Cada criatura precisa de ID único, nome, descrição, rank E–SSS, raridade, nível, atributos de combate, experiência, perigo, ecossistema, bioma, habitat, habilidades e tabela de drops válida.
- IDs duplicados são recusados; dados inválidos não entram no catálogo.
- Cada registro guarda campos de versão, descoberta global e total de derrotas.

## Descoberta e histórico global
- A primeira descoberta registra o UID do primeiro descobridor e o horário.
- Cada jogador conta apenas uma vez no total de descobertas de uma criatura.
- Derrotas são contabilizadas individualmente e no total global.
- O primeiro derrotador e o horário da primeira derrota também são preservados.
- O catálogo pode listar criaturas por ecossistema e recuperar estatísticas globais.

## Segurança e limites
- O repositório é uma classe de armazenamento para uso no processo servidor; não cria RPC público para o cliente.
- O servidor deve validar a origem dos dados antes de chamar `registrar_criatura_gerada`.
- O arquivo local é adequado somente ao desenvolvimento em um servidor com disco persistente. Ainda não é banco distribuído nem persistência em nuvem.
- Ainda não há gerador de IA conectado, gerenciador de encontros, sorteio de spawn ou sincronização de descobertas entre servidores. Não iniciar encontros a partir de dados enviados pelo cliente.
- Não há uso de API paga ou serviço externo nesta etapa.

## Integração com a sessão multiplayer
- `RedeMultiplayer.registrar_criatura_gerada_servidor` só aceita chamadas no processo servidor.
- Ao iniciar um combate, o servidor recupera a criatura pelo ID no catálogo; se ainda não estiver registrada, tenta registrar os dados recebidos da lógica interna confiável.
- O estado de combate usa os atributos da cópia persistida, e não um pacote de atributos enviado pelo cliente.
- O início do encontro registra a descoberta para o UID autenticado.
- Uma vitória confirmada registra a derrota global e individual antes de conceder os drops.
- Ainda não existe gerador de IA conectado nem um sistema que escolha quando e onde gerar encontros. A função de início continua dependendo de uma futura lógica confiável de encontros.

## Seleção de encontros
- `SistemaSelecaoEncontros` seleciona somente criaturas que já existem no catálogo.
- A seleção exige correspondência exata de ecossistema e bioma e não ultrapassa o nível de perigo informado pelo servidor.
- Chefes ficam excluídos por padrão e só entram quando a lógica confiável autoriza explicitamente.
- A raridade determina o peso relativo da seleção: criaturas comuns são mais frequentes; raridades superiores são progressivamente mais difíceis de selecionar.
- A semente é fornecida pelo servidor para permitir testes reproduzíveis.
- Este componente ainda não determina a posição do jogador, não sorteia o momento do encontro e não cria criaturas. A integração automática depende de biomas reais no mapa e de um gerador de criaturas aprovado/conectado.
