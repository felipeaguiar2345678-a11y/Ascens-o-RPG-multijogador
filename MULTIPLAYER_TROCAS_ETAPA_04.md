# Etapa 04 — Sistema de trocas

Implementado nesta etapa:
- Ação **Propor troca** no diálogo de um jogador selecionado no mapa.
- Seção **TROCAS** na aba Multiplayer para acompanhar negociações pendentes/concluídas.
- Editor de oferta com itens/materiais, ovos e equipamentos do inventário.
- Confirmação individual pelos dois jogadores e cancelamento.
- Cloud Function callable `gerenciarTroca`, região `southamerica-east1`, que valida propriedade e quantidades e realiza a transferência em transação atômica.
- XP e companheiros já eclodidos não são aceitos pelo contrato do servidor.
- Firestore permite somente leitura aos participantes; clientes não podem gravar ou modificar negociações diretamente.

Ainda não executado: instalação npm, compilação Android/TypeScript com dependências instaladas, deploy das funções, deploy das regras ou ativação do faturamento Blaze. O deploy exige habilitar faturamento no projeto Firebase.

Antes de produção, testar com duas contas no emulador Firebase, incluindo ofertas simultâneas, desconexão, cancelamento, itens consumidos durante negociação e troca de ovos/equipamentos.
