# Guia de Publicação iOS — Natus Gestantes

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
- iOS: Podfile (iOS 15), deployment target atualizado, permissões no
  Info.plist, Google Maps no AppDelegate (falta sua chave)
- pubspec corrigido (apontava para logo inexistente)
- Teste de CI corrigido + codemagic.yaml com 2 workflows

## O que VOCÊ precisa fazer (em ordem)

### 1. Firebase para iOS (obrigatório — o app crasha sem isso)
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
Selecione o projeto existente, marque **iOS**, bundle id `com.natusgestantes.app`.

### 2. Chave do Google Maps iOS
Google Cloud Console → chave com "Maps SDK for iOS" → restrinja ao bundle id
→ cole em `ios/Runner/AppDelegate.swift`.

### 3. Conta Apple Developer (US$ 99/ano)
https://developer.apple.com

### 4. App no App Store Connect
Bundle ID `com.natusgestantes.app`, anote o Apple ID numérico e coloque em
`APP_STORE_APPLE_ID` no codemagic.yaml.

### 5. Codemagic
Suba num repositório Git → conecte em codemagic.io → crie a integração
App Store Connect com nome `NatusAppleKey`.
**Sem conta Apple ainda?** Rode o workflow `ios-check` — ele valida
compilação, análise e testes num Mac real de graça.

### 6. TestFlight → revisão
- Teste no seu iPhone via TestFlight
- Política de privacidade publicada numa URL é OBRIGATÓRIA (dados de saúde
  de gestantes = revisão rigorosa; preencha o questionário de privacidade
  com cuidado: saúde, localização, identificadores)
- Screenshots + descrição no App Store Connect
- Quando aprovar internamente: `submit_to_app_store: true` no codemagic.yaml

## Validação do redesign

Rode o app (`flutter run -d chrome` funciona) e revise as telas. O redesign
foi feito no tema central, então tudo muda junto — se quiser ajustar um tom,
edite as constantes em `lib/shared/natus_app.dart` e o app inteiro acompanha.

## Dívida técnica (Fase 2 — não bloqueia publicação)

1. `lib/main.dart` (~15 mil linhas): migrar para os módulos existentes
2. ~50 `print()` em produção → logger
3. Duplicações: formatadores/formatters, dialogs/natus_dialogs
4. Gerenciador de estado (Provider/Riverpod) durante a migração
5. Ampliar cobertura de testes
