# Configuração segura do Firebase Admin no Cloudflare Worker

Esta configuração prepara o Worker para executar mutações administrativas no Firestore sem colocar credenciais no aplicativo Android ou no repositório.

## Segredos necessários

### 1. Criar uma conta de serviço dedicada

1. Abra o **Google Cloud Console** e selecione o projeto `ascensao-do-soberano` (o mesmo projeto do Firebase).
2. Entre em **IAM e administrador → Contas de serviço** e crie uma conta exclusiva para o Worker, por exemplo `ascensao-worker-admin`.
3. Conceda à conta somente a função **Cloud Datastore User** (`roles/datastore.user`), necessária para ler e gravar dados do Firestore. Não use Owner, Editor ou uma conta pessoal.
4. Na conta criada, abra **Chaves → Adicionar chave → Criar nova chave → JSON**. O navegador fará o download de um JSON. Guarde-o em local privado; não o envie para o repositório nem para esta conversa.

### 2. Cadastrar os segredos no Cloudflare

1. Abra o painel Cloudflare e entre em **Workers & Pages**.
2. Selecione o Worker `ascensao-soberano-api`.
3. Abra **Settings → Variables and Secrets** (em algumas versões aparece como **Settings → Bindings → Variables and Secrets**).
4. Adicione os três valores abaixo como **Secrets** (não como texto público):
   - `FIREBASE_SERVICE_ACCOUNT_EMAIL`: valor de `client_email` do JSON.
   - `FIREBASE_PRIVATE_KEY`: valor completo de `private_key`, incluindo `-----BEGIN PRIVATE KEY-----` e `-----END PRIVATE KEY-----`. Cole o valor original com as quebras de linha.
   - `FIREBASE_PROJECT_ID`: valor de `project_id`, que deve ser exatamente `ascensao-do-soberano`.
5. Salve as alterações e faça **Deploy** de uma nova versão do Worker.

Não envie o JSON da conta de serviço, a chave privada ou tokens por chat, GitHub Issues ou commits. Não coloque esses valores no código, em arquivos `.env` versionados ou em variáveis públicas. Se a chave for exposta, revogue-a no Google Cloud Console e gere outra.

## Verificação

Entre no jogo com a conta cujo UID está configurado em `ADMIN_UID`. Depois consulte:

`GET https://ascensao-soberano-api.felipeaguiar2345678.workers.dev/api/security/admin-check`

Envie o Firebase ID token no cabeçalho `Authorization: Bearer <token>`.

- HTTP 200 com `ready: true`: a assinatura JWT e a troca OAuth foram aceitas.
- HTTP 503: falta segredo, a chave está incorreta ou o Google recusou a troca.
- HTTP 403: a conta autenticada não corresponde ao `ADMIN_UID`.
- HTTP 401: token ausente, expirado ou inválido.

A rota não devolve email, chave, token OAuth ou qualquer segredo.

## Limites atuais

A camada `firebase-admin.js` fornece autenticação de conta de serviço, leitura REST, gravação REST em lote, consultas por proprietário, conversão segura de dados e operações transacionais. O fluxo de trocas do Android foi migrado para `POST /api/trades`; o Worker valida propriedade, bloqueia XP, impede transferir equipamento equipado e transfere itens, ovos e equipamentos em uma transação atômica. A rota de verificação confirma apenas a configuração; ela **não** torna automaticamente o combate, XP, ouro, inventário, forja, mercado ou trocas autoritativos.

Antes de bloquear as gravações atuais do cliente, é obrigatório migrar os fluxos Android para comandos específicos do servidor, implementar validação de regras de jogo e idempotência, e testar os fluxos completos. As regras atuais ainda permitem algumas gravações do cliente por compatibilidade; não as considere proteção antifraude completa.

## Auditoria do salvamento de personagem (branch de integração)

A auditoria do fluxo Android confirmou que `CharacterProfileRepository.save(profile)` serializa o perfil inteiro e usa `.set(data)` no documento `characters/{id}`. Portanto, não é seguro simplesmente fechar a escrita do cliente: isso interromperia vários recursos legítimos.

O ponto central é `MainActivity.kt`, na função local `salvarPerfil(...)`. Ela é usada atualmente para:
- atualizar inventário (itens, ovos e companheiros);
- equipar e retirar equipamentos;
- distribuir pontos de atributo;
- registrar observações, desejos e evolução de poderes;
- aplicar XP, nível, ouro, saque e penalidade de morte após combate;
- confirmar retirada de recompensa de batalha.

A criação inicial do personagem também usa `save()`, mas deve ser separada dos comandos de progressão. `CharacterVisualGenerationRunner.kt` também chama `save()` apenas para restaurar/persistir a imagem gerada; esse fluxo precisa de uma atualização restrita de aparência, sem permissão para alterar atributos ou economia.

### Ordem de migração necessária

1. Criar comandos de servidor pequenos e explícitos para inventário, equipamento, atributos e poderes, validando propriedade, limites, custo e idempotência.
2. Migrar recompensas e penalidades para o servidor, calculando XP, ouro e saque a partir de dados de batalha confiáveis — nunca de um perfil completo enviado pelo Android.
3. Migrar criação inicial e aparência para operações com campos permitidos e validação própria.
4. Remover os usos de gravação integral do cliente; então restringir as regras do Firestore e testar cada fluxo com dois usuários.
5. Só depois considerar a segurança do perfil concluída.

Não habilitar ainda regras que neguem todas as gravações do cliente: a migração acima ainda está pendente e isso quebraria o jogo.

## Fluxos que ainda não foram migrados

- Batalhas Ally: o aplicativo ainda grava estado e turnos diretamente no Firestore. A validação atual de turno não impede que um cliente modificado invente dano ou vitória.
- Personagem: posição, área atual e ponto de renascimento agora passam pelo Worker. Porém o cliente ainda consegue alterar XP, ouro, atributos, inventário, equipamentos, aparência e outros campos do próprio documento, respeitando apenas limites estruturais.
- Recompensas de batalha: a retirada atual ainda aceita um perfil completo fornecido pelo cliente; precisa passar a calcular e aplicar a recompensa no servidor.
- Forja e mercado: as validações de receita e preço ainda são executadas no aplicativo.
- Guildas e o módulo de multiplayer expandido ainda chamam Firebase Cloud Functions. O código TypeScript existente está na raiz como `index.ts`, mas `firebase.json` aponta para uma pasta `functions`; não foi feito deploy nem ativado faturamento. Esses fluxos não devem ser considerados operacionais pelo Worker até serem migrados.


Esta configuração não cria Cloud Functions. O uso do Firestore e do Google Cloud pode estar sujeito aos limites e à cobrança do plano do projeto; confirme isso no console antes de ativar permissões ou recursos adicionais.
