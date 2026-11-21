# Persistência segura do personagem no Godot

## Objetivo
Cada UID autenticado pelo Firebase identifica exatamente um personagem persistente no mundo lógico compartilhado. O personagem e o progresso pertencem à conta; a posição online e os dados públicos de presença são compartilhados com os demais jogadores.

## Situação verificada
- O servidor ENet valida o ID token com Firebase Authentication e associa UID ao peer.
- A conexão ainda cria uma posição temporária em memória; não carrega personagem persistido.
- O arquivo `firestore.rules` legado permite ao proprietário alterar livremente documentos em `characters`. Isso não é uma fronteira segura para o novo jogo online autoritativo.
- O cliente não deve gravar XP, nível, atributos, vida, mana, inventário, moedas, posição validada, drops ou recompensas.
- Não há credencial administrativa nem backend persistente configurado para o servidor dedicado. Não colocar service account no APK, repositório ou arquivo público.

## Separação de dados proposta

| Documento | Conteúdo | Permissão |
|---|---|---|
| `godotCharacterProfiles/{uid}` | Nome, identidade visual escolhida e metadados editáveis seguros | Leitura do dono; criação/edição limitada por regras |
| `godotCharacterProgress/{uid}` | Nível, XP, atributos, HP/MP, inventário, ouro, equipamentos, posição salva, revisão | Leitura do dono; escrita somente por backend autoritativo |
| `worldPresence/{uid}` | Presença temporária e posição atual validada | Publicação validada pelo servidor; leitura conforme política do mundo |

O documento de progresso deve ter o UID como chave, para impedir que o cliente escolha o proprietário ou carregue o personagem de outra conta. Toda gravação precisa validar a sessão, a revisão esperada e as regras do jogo no servidor.

## Modelo Godot
`godot/scripts/personagem_perfil.gd` define o snapshot tipado usado pelo cliente. Ele valida o UID esperado, limites básicos e posição antes de aplicar os dados recebidos. Ele não é um mecanismo de persistência e não transforma dados locais em dados confiáveis.

## Bloqueio de segurança conhecido
O servidor atual valida o token Firebase, mas ainda não tem uma credencial segura para gravar progresso autoritativo no Firestore. As opções corretas são:
1. backend próprio gratuito/hospedado pelo operador, com credencial protegida fora do cliente; ou
2. serviço gerenciado/backend com custo potencial, aprovado previamente pelo proprietário.

Não habilitar Blaze, Cloud Functions, hospedagem paga nem serviço externo pago sem explicar preço e receber aprovação explícita. Até existir backend, o jogo não deve fingir que salvou progresso persistente nem aceitar progresso vindo do cliente como confiável.


## Regras Firestore adicionadas
As regras agora incluem as coleções específicas do Godot:
- `godotCharacterProfiles/{uid}`: o proprietário pode consultar e alterar somente nome/aparência, com validação de tamanho e campos permitidos.
- `godotCharacterProgress/{uid}`: leitura do próprio documento; criação, alteração e exclusão negadas ao cliente.
- `godotWorldPresence/{uid}`: leitura autenticada; gravação negada ao cliente.

O backend dedicado, quando implementado, deverá gravar progresso e presença com credencial administrativa protegida no ambiente do servidor. As regras do Firestore não substituem a validação do servidor de jogo. As regras antigas das coleções Android permanecem intactas para não quebrar o projeto legado; o cliente Godot deve usar apenas as coleções `godot*`.

## Próximas etapas técnicas
1. Implementar backend autoritativo com autenticação de sessão e acesso seguro ao Firestore.
2. Carregar/criar o perfil pelo UID durante a autenticação ENet; só então admitir o jogador no mundo.
3. Enviar snapshot inicial e posição persistida ao cliente.
4. Salvar alterações por comandos validados, com revisão monotônica e gravação atômica.
5. Implementar reconexão, expiração de sessão, desconexão e testes com duas contas.
6. Criar testes para impedir leitura cruzada, duplicação de personagem, XP/itens adulterados e gravações repetidas.

## Critério de conclusão
A persistência só será considerada concluída depois de: criar personagem com conta A, desconectar, entrar novamente e recuperar o mesmo personagem/progresso; repetir com conta B e comprovar isolamento; tentar adulterar XP/itens pelo cliente e receber rejeição do servidor.
