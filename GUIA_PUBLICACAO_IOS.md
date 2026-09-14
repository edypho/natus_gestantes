# Guia de Publicação iOS — Natus

## O que este pacote já contém

**Rebrand completo** (veja DESIGN_SYSTEM.md):
- Design system novo em `lib/shared/natus_app.dart` com a paleta oficial
  (off-white, marsala #8A4247, dourado #C6A15B) e 16 componentes tematizados
- Nova marca (coração-árvore) em marsala aplicada no app, ícones iOS (19
  tamanhos) e Android (5 densidades)
- Fundo premium retintado para a paleta da marca

**Preparação técnica**:
- Código morto removido (lib/shared/main.dart, 11.664 linhas)
- Imagens otimizadas: 234MB → 12MB (o app ficaria com +250MB sem isso)
- iOS: Podfile (iOS 15), deployment target atualizado, notificações em segundo
  plano, entitlement de push e Google Maps configurável sem chave no Git
- pubspec corrigido (apontava para logo inexistente)
- Teste de CI corrigido + codemagic.yaml com 2 workflows

## O que VOCÊ precisa fazer (em ordem)

### 1. Unificar bundle ID e Firebase para iOS (obrigatório)
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
Selecione o projeto existente, marque **iOS**, bundle id
`com.natusgestantes.app`. Confirme também esse mesmo identificador no target
Runner do Xcode. O pipeline já usa esse bundle ID, mas o projeto e o arquivo
`lib/firebase_options.dart` ainda precisam ser regenerados juntos.

### 2. Chave do Google Maps iOS
Google Cloud Console → chave com "Maps SDK for iOS" → restrinja ao bundle ID.

Para desenvolvimento local:

```bash
cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
```

Preencha `GOOGLE_MAPS_IOS_API_KEY` no arquivo copiado. Ele é ignorado pelo Git.
No Codemagic, crie o grupo `ios_secrets`, adicione a variável secreta
`GOOGLE_MAPS_IOS_API_KEY` e não salve a chave no código-fonte. Se uma chave já
foi versionada anteriormente, restrinja ou rotacione-a no Google Cloud.

### 3. Conta Apple Developer (US$ 99/ano)
https://developer.apple.com

### 4. App no App Store Connect
Crie o app com o Bundle ID `com.natusgestantes.app`. O número do build é
preenchido automaticamente pelo `PROJECT_BUILD_NUMBER` do Codemagic.

### 5. Codemagic
Suba num repositório Git → conecte em codemagic.io → crie a integração
App Store Connect com nome `NatusAppleKey`.
**Sem conta Apple ainda?** Rode o workflow `ios-check` — ele valida
compilação, análise e testes num Mac real de graça.

Para notificações, habilite Push Notifications, Background fetch e Remote
notifications no target Runner; gere a chave APNs `.p8` e envie-a ao Firebase.

### 6. TestFlight → revisão
- Teste no seu iPhone via TestFlight
- Política de privacidade publicada numa URL é OBRIGATÓRIA (dados clínicos e
  de saúde exigem revisão rigorosa; preencha o questionário de privacidade
  com cuidado: saúde, localização e identificadores)
- Screenshots + descrição no App Store Connect
- Quando aprovar internamente: `submit_to_app_store: true` no codemagic.yaml

## Validação do redesign

Rode o app (`flutter run -d chrome` funciona) e revise as telas. O redesign
foi feito no tema central, então tudo muda junto — se quiser ajustar um tom,
edite as constantes em `lib/shared/natus_app.dart` e o app inteiro acompanha.

## Dívida técnica (Fase 2 — não bloqueia publicação)

1. `lib/main.dart` (~18 mil linhas): migrar para os módulos existentes
2. ~50 `print()` em produção → logger
3. Duplicações: formatadores/formatters, dialogs/natus_dialogs
4. Gerenciador de estado (Provider/Riverpod) durante a migração
5. Ampliar cobertura de testes
