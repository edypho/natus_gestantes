# Plano de release sem interrupção

Este plano mantém o site e os dados atuais disponíveis durante a migração. O
backfill é aditivo: nenhuma coleção legada, conta do Auth ou objeto do Storage é
apagado ou desativado. Contas do Auth sem perfil no app são preservadas porque o
projeto também atende outros fluxos; as regras continuam negando acesso clínico
sem perfil válido. Registros ambíguos são preservados em quarentena para revisão.

## Gates antes da janela

- diff revisado e aprovado;
- `dart format`, `flutter analyze`, testes Flutter, lint e testes das Functions
  verdes;
- builds web e Android assinados e validados;
- backup completo de Firestore, Auth e Storage, com checksums verificados;
- restauração integral e backfill idempotente aprovados nos Emulators;
- dry-run cloud recente com zero bloqueadores;
- responsáveis pela execução, validação e rollback disponíveis.

## Credenciais externas preparadas em 10/08/2026

- `Natus Android Produção`: restrita ao pacote `br.enf.natus.app`, ao
  certificado de release e somente ao Maps SDK for Android;
- `Natus Web Produção`: restrita a `natus-gestantes.web.app` e
  `natus-gestantes.firebaseapp.com`, somente para Maps JavaScript API;
- Maps JavaScript API ativada no projeto;
- valores das chaves não foram gravados em arquivo ou no Git; foram usados
  apenas durante as builds locais;
- a chave legada permanece inalterada durante a transição para não interromper
  clientes existentes;
- reCAPTCHA Enterprise e App Check Web registrados com TTL de uma hora, sem
  enforcement durante a fase de observação;
- App Check Android permanece desativado por padrão enquanto o APK for
  distribuído fora da Play Store. Ativá-lo exige provedor compatível ou build
  com `NATUS_ENABLE_ANDROID_APP_CHECK=true` depois da distribuição pela Play.

## Ordem controlada

1. Registrar a versão candidata, hashes dos artefatos e horário da janela.
2. Implantar somente a Function `sincronizarRaizCanonica` e validar seus logs.
3. Gerar outro backup completo de produção e verificar todos os checksums.
4. Repetir a auditoria e o dry-run cloud. Qualquer bloqueador encerra a janela.
5. Aplicar o backfill com o projeto explícito, confirmação de produção e caminho
   do backup recém-validado. Não usar credencial ou projeto implícito.
6. Repetir imediatamente a auditoria read-only. Exigir `releaseReady: true`.
7. Implantar índices e aguardar todos ficarem prontos.
8. Implantar regras do Firestore e Storage.
9. Executar smoke autenticado com uma conta interna: login, pacientes, agenda,
   prontuário, financeiro, documentos, upload permitido e negações cruzadas.
10. Publicar o web, validar em `800x600`, `1024x900` e viewport móvel e só então
    substituir o APK disponível no site. Não publicar na Play Store.
11. Monitorar erros de permissão, Functions, agenda, autenticação, contratos,
    notificações e uploads durante toda a janela de estabilização.

## Comandos de gate verificados

Antes da migração, o gate local deve terminar verde e confirmar que o guard de
dados ainda bloqueia o cliente:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tool\verify_release_candidate.ps1 -DataGate PreMigration
```

Os scripts cloud aceitam `--firebase-cli-login --confirm-account <email>` para
reutilizar explicitamente a sessão local confirmada. Esse modo sincroniza a
credencial de aplicação mantida pelo próprio Firebase CLI fora do repositório;
nenhum token é escrito no projeto, em relatório ou em log.

Depois do backfill, a auditoria cloud deve ser repetida em
`functions/audit-reports/` e o mesmo gate deve passar em modo pós-migração:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tool\verify_release_candidate.ps1 -DataGate PostMigration
```

O deploy da sincronização foi validado com `--dry-run` no alvo explícito
`functions:default:sincronizarRaizCanonica`. Não usar `--force`: os codebases e
Functions existentes que não fazem parte deste app devem ser preservados.

## Critérios de interrupção e rollback

Interromper antes de regras/web se a restauração falhar, checksums divergirem,
o dry-run criar bloqueadores, a auditoria não ficar verde ou os índices não
ficarem prontos. Como a migração é aditiva, mantenha o cliente atual nas
coleções legadas e desative a sincronização candidata; não faça exclusão em
massa. Se regras ou Hosting causarem regressão, reverta apenas esses artefatos
para a versão anterior já registrada e preserve os dados canônicos para análise.

Nenhuma etapa produtiva deste plano deve ser executada automaticamente a partir
do repositório local. A janela exige autorização explícita depois da revisão do
diff e dos resultados de validação.
