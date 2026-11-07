# Etapa 03 — Geração e catálogo global de criaturas

## O que foi atualizado nesta cópia

### Android — validação da geração
- A resposta da API agora é conferida também no aplicativo antes de entrar no catálogo:
  - ecossistema e bioma devem corresponder ao pedido;
  - rank deve ser válido e não pode ultrapassar o limite da região;
  - o campo de chefe deve corresponder ao tipo de encontro solicitado;
  - nível e vida precisam ser positivos;
  - a criatura precisa ter ao menos um ataque;
  - raridade precisa pertencer à lista oficial;
  - chefes precisam ter ao menos um equipamento garantido com efeito especial.
- A espera pela resposta HTTP foi ampliada para 60 segundos, compatível com a geração do Worker que pode levar até 45 segundos.
- Erros devolvidos pelo Worker agora são apresentados com a mensagem do servidor, em vez de mostrar somente o código HTTP.

### Catálogo global e segurança
- O modelo `CriaturaGerada` ganhou `criadoPorUid`, que registra a conta responsável pelo primeiro registro global.
- O repositório define esse UID a partir da sessão Firebase autenticada, nunca a partir de um valor informado livremente pela tela.
- O registro continua transacional: se a criatura já existir, o documento oficial existente é retornado e não é substituído.
- As regras Firestore agora permitem leitura autenticada do catálogo, criação vinculada ao UID autenticado e bloqueiam atualização/exclusão de criaturas já registradas.
- O bestiário individual permite leitura e criação somente pelo próprio jogador, exige que a criatura exista no catálogo e bloqueia alteração/exclusão de descobertas existentes.

## Worker Cloudflare existente no GitHub

A rota `/api/creatures/generate` já existe no Worker da branch `feature/ai-budget-categories`. Ela autentica o token Firebase, valida ecossistema/bioma/rank/perigo/tipo de encontro, reserva o orçamento da categoria `other_ai` antes da chamada à OpenAI e valida o JSON gerado antes de responder.

A rota atual usa o modelo `gpt-6-luna`, confirmado no catálogo oficial de modelos da OpenAI. O Worker mantém o limite mensal da categoria de criaturas e outras IAs em R$ 48,00. Nenhuma chamada paga foi executada nesta etapa.

**Atenção:** o Worker original não veio dentro do ZIP Android recebido; ele continua no GitHub e não foi alterado nem publicado por esta etapa. O ZIP mantém os arquivos Cloudflare disponíveis na cópia recebida e este relatório registra o que foi confirmado diretamente no Worker remoto.

## Imagens das criaturas — ainda pendentes

O Worker atual possui upload de imagens para R2, mas essa rota é restrita à conta administradora. A geração de criaturas atualmente cria ficha, ataques e drops em JSON; ela ainda não gera automaticamente a arte individual de cada criatura. Não foi criada uma chamada de geração de imagem nesta etapa para não introduzir custo ou mudar o orçamento sem apresentar previamente uma estimativa específica e obter aprovação.

## Verificações

- Conferência estática dos arquivos Kotlin alterados e das regras Firestore.
- Conferência do fluxo de geração, reserva e reconciliação de orçamento no Worker existente no GitHub.
- Não foi possível executar uma compilação Android completa: esta cópia não contém `gradlew` e o ambiente não possui Gradle instalado.
- As regras Firestore ainda precisam ser validadas no Firebase Emulator/Console antes de publicar.
- Nenhum commit, push, deploy ou chamada paga foi realizado.
