# Auditoria de segurança — 06/08/2026

> Atualização: a rodada ofensiva complementar, provas em produção, testes de
> exploração no Emulator e novas correções estão documentados em
> `docs/PENTEST_OFENSIVO_2026-08-06.md`.

## Resultado executivo

A revisão estática e os testes locais corrigiram os vetores exploráveis que
podiam ser tratados com segurança no repositório. Nenhuma alteração foi
implantada em produção.

O código local passou a ter CORS restrito, limitação de uso, validação de
sessões revogadas, mensagens e logs sem dados pessoais, notificações push
privadas, validação binária de uploads, navegação externa HTTPS, cabeçalhos de
segurança, dependências sem vulnerabilidades conhecidas e build Android sem
assinatura de depuração em release.

Produção ainda não pode ser considerada corrigida. Em 06/08/2026, a página
pública retornou HTTP 200, mas sem CSP, `X-Frame-Options`, `nosniff`, política de
referência ou de permissões. O endpoint HTTP legado aceitou preflight de origem
arbitrária e respondeu `Access-Control-Allow-Origin: *`. Isso confirma que as
correções locais ainda não estão publicadas.

## Correções implementadas

### Backend e APIs

- CORS deixou de aceitar `*` e agora permite somente os domínios oficiais ou
  origens adicionais configuradas explicitamente.
- Requisições sem `Origin` continuam permitidas para clientes móveis e
  integrações servidor-servidor; origens web desconhecidas falham fechadas.
- Funções sensíveis têm limites por ação e identidade, com identificadores
  irreversivelmente resumidos no Firestore.
- Sessões são confrontadas com o estado atual do Firebase Auth, incluindo
  usuário desabilitado e tokens emitidos antes de uma revogação.
- O proxy ZapSign limita método, caminho, tamanho de payload, tempo de resposta
  e tamanho da resposta; erros internos não são devolvidos ao cliente.
- Logs registram somente contexto e códigos sanitizados, sem e-mail, nome,
  documento, URL de arquivo ou objeto de erro bruto.
- Push clínico não inclui nome, conteúdo de atendimento, intensidade, duração,
  tenant ou identificador de paciente.
- Tokens FCM têm validação de formato e limites por usuário e por envio.
- A coleção técnica do limitador de uso é explicitamente negada nas Rules.

### Flutter e web

- Persistência do Firebase Auth no navegador foi reduzida para a sessão atual.
- Mensagens visíveis não exibem `exception.toString()` nem detalhes internos.
- Senhas são removidas do controlador após a tentativa de login.
- URLs externas aceitam apenas HTTPS, sem credenciais embutidas, portas
  alternativas ou caracteres de controle; telefone usa formato validado.
- Imagens remotas de perfil e capa carregam somente de hosts controlados do
  Firebase Storage, evitando pixels de rastreamento inseridos nos documentos.
- PDFs, JPEGs, PNGs, WebP e MP4 são validados pela assinatura binária antes do
  upload, além de extensão, MIME e tamanho.
- O service worker exibe notificações genéricas e descarta dados clínicos mesmo
  ao receber um payload antigo.
- O Hosting recebeu HSTS, CSP mínima anti-embedding/objetos, `nosniff`, bloqueio
  de frame, política de referência e política de permissões.
- Mapas de origem e arquivos de símbolos são excluídos do pacote de Hosting.
- O CORS de Storage deixou de aceitar qualquer origem.

### Android

- A chave Google Maps saiu do manifesto versionado e deve ser injetada pela
  variável `GOOGLE_MAPS_ANDROID_API_KEY` ou propriedade Gradle de mesmo nome.
- Backup em nuvem, transferência de dispositivo e tráfego HTTP em texto claro
  foram desabilitados para reduzir extração de dados locais.
- Release não usa mais o keystore de depuração. Sem
  `android/key.properties` completo, a criação de APK/AAB de release é
  bloqueada de forma explícita.
- `android/key.properties.example` documenta apenas os nomes esperados; valores
  reais permanecem fora do Git.

## Dependências, segredos e portas

- `npm audit --omit=dev`: 15 vulnerabilidades antes da correção, incluindo 1
  crítica e 3 altas; 0 depois da atualização do Firebase Admin/Functions e da
  resolução segura de `uuid`.
- Consulta em lote dos 113 pacotes Dart à base OSV: 0 vulnerabilidades
  conhecidas no momento da auditoria.
- Varredura dos arquivos de texto versionáveis: nenhum segredo privado
  reconhecido e nenhum arquivo de credencial, chave privada ou keystore
  versionado.
- Não existe servidor TCP/HTTP próprio, socket de escuta ou porta pública
  configurada pelo app. Os emuladores usam somente loopback
  (`127.0.0.1`) e não fazem parte do artefato de produção.

Chaves de cliente Firebase são identificadores públicos por desenho e não
substituem Rules. A chave Google Maps que já esteve versionada deve ser
rotacionada e restrita no Google Cloud por aplicativo Android, assinatura,
bundle iOS e referers web, com somente as APIs necessárias.

## Validações concluídas

- `dart format`: concluído nos arquivos Dart alterados.
- `flutter analyze`: 0 problemas.
- `flutter test`: 156 testes aprovados na revalidação de 10/08/2026.
- `flutter build web --release`: aprovado, inclusive dry-run Wasm.
- `flutter build apk --release`: aprovado; pacote `br.enf.natus.app`, versão
  `1.1.0+3` e certificado compatível com o APK `1.0.0+2`.
- Gate Android de release sem keystore: bloqueado como esperado.
- ESLint das Functions: aprovado.
- Testes Node: 115 testes, 114 aprovados e 1 teste de Emulator ignorado fora
  do Emulator.
- Firestore + Auth + Storage Emulator: regras compiladas e teste de backend
  aprovado, incluindo negação entre clínicas.
- `npm audit --omit=dev`: 0 vulnerabilidades.
- `npm ls`: árvore consistente.
- `git diff --check`: sem erro de whitespace.

## Riscos residuais e bloqueios de publicação

### Críticos antes do cutover de Rules/Storage

1. A auditoria multi-clínica de produção de 22/07/2026 registrou 1.035
   bloqueadores e nenhum documento na árvore canônica. Publicar as Rules
   endurecidas sem backfill pode interromper o produto.
2. As Rules de Storage permanecem intencionalmente fora de `firebase.json`.
   Ative-as somente após copiar os objetos legados para caminhos com tenant e
   validar metadados canônicos em homologação.
3. O app ainda persiste URLs de download do Storage. URLs com token podem
   sobreviver à mudança de Rules. O fluxo deve migrar para caminhos de objeto e
   leitura autenticada pelo SDK; depois, revogar os tokens legados.
4. O inventário de Functions não pôde ser atualizado porque a CLI local não
   possui autenticação. A fotografia de 22/07/2026 apontava 6 exports locais e
   5 callables usadas pelo app ainda ausentes em produção.

### Configuração externa obrigatória

- Ativar Firebase App Check gradualmente para Firestore, Storage e Functions,
  primeiro em métricas/homologação e depois em enforcement.
- Rotacionar e restringir todas as chaves Google Maps; não basta ocultá-las do
  código porque aplicativos cliente podem ser inspecionados.
- Exigir MFA para administradores e Super Admin, política de senha forte,
  verificação de e-mail e procedimento de revogação de sessões.
- Migrar tokens FCM para uma coleção privada escrita por callable/backend. Hoje
  eles ainda ficam no documento de usuário, embora limitados e validados.
- Configurar alertas de Auth, Functions, Firestore, Storage, orçamento e erros;
  habilitar retenção, backups/PITR e um processo de resposta a incidentes/LGPD.
- Adicionar varredura contínua de segredos e dependências no CI, incluindo
  histórico Git. A auditoria atual cobriu a árvore de trabalho, não todo o
  histórico ou os consoles dos provedores.
- Para uploads clínicos, complementar a validação de assinatura com quarentena
  e análise antimalware assíncrona no backend.

## Ordem segura para publicação

1. Rotacionar/restringir a chave Google Maps exposta e preparar segredos de CI.
2. Criar homologação isolada com cópia pseudonimizada dos dados.
3. Aprovar os destinos multi-clínica, executar backfill idempotente e zerar os
   bloqueadores aplicáveis.
4. Aplicar e testar Rules de Firestore/Storage em homologação.
5. Publicar seletivamente Functions e repetir o checker de contratos.
6. Publicar app/Hosting e confirmar cabeçalhos, CORS, App Check e fluxos por
   perfil.
7. Revogar URLs/tokens antigos e monitorar negações, erros e abuso após o
   rollout.

## Arquivos desta auditoria

Criados:

- `functions/security/{http_cors,private_push,rate_limiter,safe_logging}.js`;
- `functions/test/security_hardening.test.js`;
- `lib/seguranca/{arquivo_upload_seguro,erro_publico,log_seguro,url_externa_segura}.dart`;
- `test/seguranca/{arquivo_upload_seguro_test,url_externa_segura_test}.dart`;
- `android/key.properties.example`;
- `android/app/src/main/res/xml/{backup_rules,data_extraction_rules}.xml`;
- `docs/AUDITORIA_SEGURANCA_2026-08-06.md`.

Alterados nesta rodada:

- `.gitignore`, `cors.json`, `firebase.json`;
- `firebase/firebase.audit-emulator.json` e
  `firebase/security/firestore.rules`;
- `functions/.gitignore`, `functions/index.js`, `functions/package.json`,
  `functions/package-lock.json` e
  `functions/test/backend_functions_emulator.test.js`;
- `lib/main.dart`, `lib/auth/tela_login.dart`, `lib/agenda/agenda_page.dart`,
  `lib/services/push_notifications_service.dart`,
  `lib/super_admin/primeiro_login_saas_dialog.dart` e
  `lib/super_admin/super_admin_crud_dialogs.dart`;
- `web/firebase-messaging-sw.js`;
- `android/app/build.gradle.kts`,
  `android/app/src/main/AndroidManifest.xml` e `android/gradle.properties`
  (os dois flags deste último foram adicionados automaticamente pelo migrador
  do Flutter 3.44 durante o build Android).

Nenhum arquivo foi movido ou removido. O worktree já continha outras mudanças
não relacionadas; elas foram preservadas.

Até essa sequência ser revisada e executada, o estado correto é: **código local
endurecido e validado; produção ainda vulnerável e sem confirmação do backend
atual**.
