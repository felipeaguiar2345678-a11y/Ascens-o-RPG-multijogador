# Ascensão do Soberano — projeto Android MVP

Projeto-fonte Android nativo (Kotlin + Jetpack Compose), preparado para Firebase Authentication e Cloud Firestore.

## Funcionalidades no protótipo
- Ficha inicial da Entidade da Ascensão Cósmica com valores confirmados.
- Poderes e custos conhecidos; valores não consolidados aparecem como “a confirmar”.
- Rolagem D20.
- Criar campanha privada e gerar código de convite.
- Entrar em campanha por código.
- Abas de Personagem, Combate, Multiplayer e Mundo.

## Configurar o multiplayer
1. Instale Android Studio (Ladybug ou mais recente) e JDK 17.
2. Crie um projeto Firebase e registre o app Android com pacote `br.com.ascensaodosoberano`.
3. Baixe `google-services.json` e coloque em `app/google-services.json`.
4. Ative Authentication > Anonymous e crie um banco Cloud Firestore.
5. Publique `firestore.rules` (regras de protótipo; endurecer antes de produção).
6. Abra o projeto no Android Studio e sincronize o Gradle.

## Gerar APK de teste
Android Studio: Build > Build Bundle(s) / APK(s) > Build APK(s).
Ou `./gradlew assembleDebug` com JDK e Android SDK configurados.
Saída: `app/build/outputs/apk/debug/app-debug.apk`.

## Limites atuais
Este arquivo é o projeto-fonte inicial, não um APK assinado. Ainda exige credenciais Firebase e compilação no Android Studio. O multiplayer é um esqueleto funcional de criação/entrada em campanhas, não um MMO pronto: falta backend autoritativo, presença em tempo real, mapa jogável, salas cooperativas sincronizadas, combate server-side, chat, moderação e proteção anti-fraude. Em produção, convites, membros, XP, itens, dano e recompensas devem ser controlados por Cloud Functions/backend, nunca confiados ao cliente.

## Ficha inicial carregada
- Nível 14; XP 825/1.000.
- HP 485/485; Mana 230/330.
- Rank não consolidado; Soberano da Evolução continua bloqueada.
- Título Matador de Calamidades.
- Couraça do Titã Imortal (SSS) e Anel da Singularidade (SS) equipados.
- Escudo das Sete Virtudes (S) guardado.
- Matriz Primordial em Integração Parcial.
- Dano-base dos punhos e parâmetros não confirmados não foram inventados.

## Próximas fases
Backend seguro; mapa e regiões; instâncias co-op em tempo real; sistema de combate completo; inventário e crafting; guildas/PvP; chefes mundiais; migração de todo o histórico da campanha.
