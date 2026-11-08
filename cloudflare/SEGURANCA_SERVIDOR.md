# Configuração segura do Firebase Admin no Cloudflare Worker

Esta configuração prepara o Worker para executar mutações administrativas no Firestore sem colocar credenciais no aplicativo Android ou no repositório.

## Segredos necessários

No projeto correto do Google Cloud/Firebase, crie uma conta de serviço dedicada ao Worker. Conceda somente as permissões mínimas de leitura e gravação necessárias no Firestore (não use Owner, Editor ou uma chave pessoal).

No painel Cloudflare:
1. Abra **Workers & Pages** e selecione o Worker `ascensao-soberano-api`.
2. Abra **Settings → Variables and Secrets**.
3. Adicione os três valores abaixo como **Secrets**:
   - `FIREBASE_SERVICE_ACCOUNT_EMAIL`: campo `client_email` do JSON da conta de serviço.
   - `FIREBASE_PRIVATE_KEY`: campo `private_key` completo, incluindo as linhas BEGIN/END.
   - `FIREBASE_PROJECT_ID`: ID exato do projeto Firebase.
4. Salve e publique uma nova versão do Worker.

Não envie o JSON da conta de serviço, a chave privada ou tokens por chat, GitHub Issues ou commits. Não coloque esses valores no código, em arquivos `.env` versionados ou em variáveis públicas.

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

## Fluxos que ainda não foram migrados

- Batalhas Ally: o aplicativo ainda grava estado e turnos diretamente no Firestore. A validação atual de turno não impede que um cliente modificado invente dano ou vitória.
- Personagem: o cliente ainda consegue alterar XP, ouro, atributos, inventário, equipamentos e outros campos do próprio documento, respeitando apenas limites estruturais.
- Recompensas de batalha: a retirada atual ainda aceita um perfil completo fornecido pelo cliente; precisa passar a calcular e aplicar a recompensa no servidor.
- Forja e mercado: as validações de receita e preço ainda são executadas no aplicativo.
- Guildas e o módulo de multiplayer expandido ainda chamam Firebase Cloud Functions. O código TypeScript existente está na raiz como `index.ts`, mas `firebase.json` aponta para uma pasta `functions`; não foi feito deploy nem ativado faturamento. Esses fluxos não devem ser considerados operacionais pelo Worker até serem migrados.


Esta configuração não cria Cloud Functions. O uso do Firestore e do Google Cloud pode estar sujeito aos limites e à cobrança do plano do projeto; confirme isso no console antes de ativar permissões ou recursos adicionais.
