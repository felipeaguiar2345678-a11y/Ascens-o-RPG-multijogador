# Autenticação Firebase no cliente Godot

## Fluxo atual

1. A tela inicial oferece cadastro e login por e-mail e senha.
2. O Godot chama os endpoints HTTPS oficiais do Firebase Authentication: `accounts:signUp` ou `accounts:signInWithPassword`.
3. O Firebase retorna ID token, refresh token e UID. O cliente mantém os dois tokens somente em memória durante a sessão; senha e refresh token não são gravados em arquivo. O refresh token ainda está em fase de integração e não é usado para renovar automaticamente a sessão.
4. O cliente conecta ao servidor ENet e envia o ID token por RPC confiável.
5. O servidor consulta `accounts:lookup` diretamente no Firebase Authentication. Só libera a entrada se a resposta for válida, existir UID e a conta não estiver desativada.
6. O servidor associa o peer ao UID Firebase e impede que o mesmo UID entre duas vezes simultaneamente na mesma instância.
7. Só depois da validação o servidor cria a presença do jogador no mundo compartilhado.

## Configuração do projeto Firebase

- A configuração pública necessária ao cliente e ao servidor está em `godot/firebase_config.json`.
- A chave Web API do Firebase é identificador público do projeto, não uma credencial administrativa. Nunca adicionar service account, chave privada ou segredo de servidor ao repositório.
- No Console Firebase, habilitar o provedor **E-mail/senha** em Authentication > Sign-in method.
- A autenticação usa HTTPS e os endpoints REST oficiais do Firebase.
- Não foi criada Cloud Function, não foi habilitada hospedagem e nenhum serviço pago foi contratado.

## Limitações explícitas

- O login/cadastro e a validação remota do ID token estão implementados no código, mas precisam de teste real com o provedor E-mail/senha habilitado no projeto.
- O servidor dedicado ainda não está hospedado; o usuário precisa de um endereço ENet ativo para entrar.
- A sessão não é restaurada automaticamente após fechar o aplicativo. O usuário precisa fazer login novamente; tokens e senhas não são persistidos localmente nesta etapa.
- Ainda não há verificação obrigatória de e-mail, recuperação de senha, troca de senha ou vínculo com provedores sociais.
- O UID autenticado ainda não está conectado a um repositório de personagem persistente no Godot. A próxima etapa é carregar/criar o personagem pelo UID sem duplicar identidades.
- O refresh token já é recebido e mantido somente em memória, mas a renovação automática e a revalidação da sessão longa ainda não estão concluídas. O mecanismo atual comprova a conta no momento da entrada; o servidor ainda precisa revalidar sessões longas e autorizar cada ação de jogo.
- Não considerar esta camada, sozinha, segurança suficiente para economia, combate ou recompensas. O servidor autoritativo completo ainda está pendente.

## Segurança

O cliente nunca decide o UID final: o servidor extrai o UID da resposta do Firebase ao validar o token. O cliente não envia valores finais de dano, itens, moedas ou recompensas. A senha é enviada somente ao endpoint HTTPS do Firebase Authentication e não é transmitida pelo ENet.
