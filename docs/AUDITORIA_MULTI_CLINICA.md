# Auditoria multi-clínica read-only

O auditor desta etapa inventaria os dados que precisam ser corrigidos antes do
hard cutover de tenant. Ele não executa backfill, não altera documentos e não
faz deploy.

## Resultado read-only de produção — 10/08/2026

A varredura completa de Firestore e Firebase Auth foi executada no projeto
`natus-gestantes`, sem `--include-identifiers` e sem qualquer escrita.

- 315 documentos raiz lidos;
- 0 documentos encontrados na árvore canônica `clinicas/{tenantId}/...`;
- 315 referências percorridas, sem truncamento ou limite atingido;
- 1.014 achados, sendo 997 bloqueadores: 829 críticos, 168 erros e 17
  avisos de contas do Auth fora do escopo do app;
- `releaseReady: false`.

O resultado confirma que o corte direto do estado produtivo atual não é seguro.
O relatório privado com identificadores permaneceu somente na pasta ignorada
`functions/audit-reports/private-current-identifiers/` para sustentar o plano;
identificadores não devem ser copiados para documentação, logs ou commits.

Um backup lógico completo e validado foi então restaurado nos Emulators. O
backfill aditivo foi aplicado duas vezes consecutivas e a segunda passagem não
produziu nova atualização no Auth. Após o ensaio:

- 383 documentos raiz e 310 documentos canônicos foram auditados;
- 693 referências foram percorridas;
- 29 achados permaneceram como avisos de quarentena/contas fora do escopo do
  app, sem exclusão ou desativação automática;
- 0 bloqueadores e `releaseReady: true`;
- 10 de 10 testes integrados de Firestore, Auth e Storage passaram, incluindo
  o lote atômico de paciente + financeiro e a negação entre clínicas.

Esse verde comprova o procedimento sobre a cópia isolada; não significa que a
produção já foi migrada. Nenhuma escrita de produção foi executada.

O dry-run cloud mais recente do backfill planejou 693 gravações aditivas no
Firestore, 1 atualização de claim no Auth, 0 bloqueadores e 29 avisos. As 17
contas do Auth sem perfil clínico foram preservadas sem atualização.

## O que ele verifica

- ausência, tipo inválido, espaços externos e divergência entre `clinicaId` e
  `adminDonoId`;
- documentos que ficarão invisíveis porque o app filtra simultaneamente pelos
  dois aliases;
- tenant inexistente, clínica canônica ausente e divergência entre `clinicas`
  e `clinicasSaaS`;
- coerência entre proprietário, usuários, perfis, status e tenant;
- aliases de ID do paciente (`pacienteId`, `gestanteId`, `idGestante`);
- aliases de UID do paciente (`uidPaciente`, `pacienteUid`, `uidGestante`,
  `gestanteUid`);
- referência órfã, vínculo cruzado entre clínicas, UID ligado a dois pacientes
  e inconsistência entre `usuarios`, entidade do paciente e locks;
- campos exatos usados pelas consultas atuais, inclusive `gestanteUid` na
  agenda e `uidGestante` nos recursos do portal;
- prontuário, atendimento e financeiro sem ID estável do paciente;
- vínculos de profissionais e locks recíprocos, incluindo igualdade de tenant,
  perfil compatível, `pacienteId` ou `idVinculo` e UID recíproco entre lock
  direto, lock reverso, usuário e paciente ou entidade profissional;
- divergência entre contrato e `payload`;
- cópias ausentes, incompatíveis ou sem origem legada correspondente sob
  `clinicas/{tenantId}/...`, apenas nos pares aprovados nesta fase;
- subcoleções deixadas sob documentos-pai inexistentes, inclusive
  `clinicas/{tenantId}` e `pacientes/{pacienteId}` órfãos;
- registros em coleções cujo destino canônico ainda não foi aprovado;
- coleções desconhecidas e qualquer subcoleção abaixo de um documento
  terminal, para evitar um falso resultado verde;
- subcoleções sob documentos das coleções raiz legadas, inclusive quando o
  documento-pai não existe, reportadas como `UNKNOWN_LEGACY_SUBCOLLECTION`;
- alvo completamente vazio, que gera o bloqueador `AUDIT_EMPTY` e nunca é
  considerado pronto para release;
- contas órfãs, contas desabilitadas e custom claim de SuperAdmin no Firebase
  Auth. Uma execução sem Auth pode servir como diagnóstico preliminar, mas gera
  `AUTH_AUDIT_SKIPPED` e nunca libera o release.

O auditor não seleciona documentos completos nem campos de nome, e-mail,
telefone, CPF, prontuário ou valores financeiros. Ainda assim, IDs legados
podem conter dados pessoais. Os hashes determinísticos do relatório padrão são
pseudônimos, não dados anônimos, e devem receber a mesma proteção operacional.

## Destinos canônicos aprovados

Toda coleção raiz do manifest possui uma disposição canônica explícita e
validada ao carregar o módulo:

- `mapped`: exige um `canonicalCopy` com escopo, coleção e, quando necessário,
  prefixo determinístico válidos;
- `special`: somente diretórios de clínicas, usuários e pacientes, os
  catálogos `planos` e `biblioteca`, e os locks que possuem auditoria dedicada;
- `unresolved`: destino ainda não aprovado, sem inferência automática.

Não permanece nenhuma coleção `unresolved`. Os destinos aprovados incluem:

- assinatura em `configuracoes` da clínica;
- enfermeiras, obstetras e demais profissionais em `profissionais` da clínica,
  com prefixos que impedem colisão de IDs;
- prontuários, seus atendimentos e contrações em `prontuario` do paciente;
- parcelas e parcelas financeiras em `financeiro` do paciente;
- materiais em `operacao`, notificações em `notificacoes` e logs em `logs` da
  clínica.

O manifest continua fail-closed: uma coleção desconhecida ou uma futura
definição `unresolved` volta a bloquear a liberação automaticamente. Registros
sem associação inequívoca não são atribuídos por aproximação; recebem cópia
aditiva em quarentena para revisão humana.

Nas cópias `mapped`, o auditor compara somente aliases de ID/UID do paciente,
campos exatos usados por query e portal e, em contratos, os mesmos aliases sob
`payload`. Conteúdo clínico ou financeiro fora desses campos selecionados não é
comparado. O finding `CANONICAL_COPY_DIVERGENT` sinaliza diferenças. O sentido
inverso emite `CANONICAL_COPY_WITHOUT_LEGACY_SOURCE` para cópias sem origem nos
pares aprovados.

## Garantias de execução

O adapter Firebase expõe somente listagem e leitura. O código não chama
`set`, `update`, `delete`, `add`, `batch`, `bulkWriter` ou deploy. Ainda assim,
o Admin SDK ignora as regras do Firestore: em cloud, use uma credencial separada
com o menor acesso de leitura possível. Não coloque arquivo de credencial no
repositório.

A hierarquia canônica combina consultas paginadas com
`CollectionReference.listDocuments()`. Essa listagem é necessária porque o
Firestore permite manter subcoleções sob um documento-pai que não existe. A
referência órfã é registrada separadamente e gera um bloqueador
`CANONICAL_CLINIC_PARENT_MISSING`, `CANONICAL_PATIENT_PARENT_MISSING` ou
`CANONICAL_DOCUMENT_PARENT_MISSING`; ela nunca é contabilizada como documento
existente. Subcoleções encontradas abaixo de um nó terminal geram também
`UNKNOWN_CANONICAL_COLLECTION`.

A enumeração tem um teto global independente, `--max-references`, com padrão
de 10.000 referências e faixa aceita de 1 a 1.000.000. O relatório registra
`referencesListed` (referências devolvidas por `listDocuments()`) e
`referencesVisited` (referências efetivamente percorridas). Ao atingir o teto,
o adapter deixa de processar novas referências e de disparar o fan-out
subsequente de `listCollections()`/`listDocuments()`, marca
`referenceLimitReached: true` e encerra a auditoria como incompleta.

Nas demais coleções raiz modeladas, o auditor não tenta adivinhar o schema de
subcoleções legadas. Ele percorre somente referências, inclui pais ausentes
descobertos por `listDocuments()` e emite `UNKNOWN_LEGACY_SUBCOLLECTION` para
cada caminho. `clinicas` fica fora dessa segunda passagem porque sua hierarquia
é tratada pela varredura canônica mais específica.

O script nunca usa o projeto padrão de `.firebaserc`:

- `--project` é obrigatório;
- é obrigatório escolher `--emulator-host` ou `--cloud`;
- o Emulator aceita apenas host loopback;
- cloud exige repetir o alvo em `--confirm-project`;
- `natus-gestantes` exige também `--allow-production-read`;
- variáveis `FIRESTORE_EMULATOR_HOST` ou
  `FIREBASE_AUTH_EMULATOR_HOST` herdadas bloqueiam o modo cloud;
- `--include-auth` no Emulator exige `--auth-emulator-host` loopback explícito,
  impedindo combinar Firestore local com Auth cloud.

## Uso no Emulator

O arquivo `firebase/firebase.audit-emulator.json` existe apenas para teste e não
está ligado ao `firebase.json` de produção. Para um smoke test vazio, a partir
da raiz do projeto, use Java 21 ou superior:

```powershell
firebase --config firebase/firebase.audit-emulator.json emulators:exec --only firestore,auth --project demo-natus "npm --prefix functions run audit:multi-tenant -- --project demo-natus --emulator-host 127.0.0.1:8080 --include-auth --auth-emulator-host 127.0.0.1:9099 --allow-empty-smoke"
```

`--allow-empty-smoke` só é aceito no Emulator. Ele retorna exit code `0`
quando a varredura terminou por completo e os únicos bloqueadores são
`AUDIT_EMPTY` e as policies `CANONICAL_DESTINATION_POLICY_UNDEFINED` já
declaradas no manifest; o relatório continua com `releaseReady: false`. Sem
essa opção, um alvo vazio retorna `2`, como qualquer auditoria bloqueada. A
inclusão do Auth no smoke é obrigatória para essa exceção e evita confundir
Firestore vazio com um ambiente que ainda contém contas.

Para uma auditoria preliminar apenas de Firestore, inicie o mesmo Emulator,
carregue nele uma cópia sanitizada ou uma fixture e execute:

```powershell
npm --prefix functions run audit:multi-tenant -- --project demo-natus --emulator-host 127.0.0.1:8080
```

O auditor não inicia o Emulator e nunca faz fallback silencioso para cloud.
Esse comando sem `--include-auth` gera `AUTH_AUDIT_SKIPPED`; use o comando
seguinte, com os dois Emulators, para avaliar o gate de liberação.

Para incluir o Auth no teste local, inicie ambos os Emulators e informe os dois
endpoints explicitamente:

```powershell
firebase --config firebase/firebase.audit-emulator.json emulators:exec --only firestore,auth --project demo-natus "npm --prefix functions run audit:multi-tenant -- --project demo-natus --emulator-host 127.0.0.1:8080 --include-auth --auth-emulator-host 127.0.0.1:9099"
```

## Uso em homologação

Com credencial de leitura de Firestore e Auth configurada fora do repositório:

```powershell
npm --prefix functions run audit:multi-tenant -- --project ID_HOMOLOGACAO --cloud --confirm-project ID_HOMOLOGACAO --include-auth
```

Sem `--include-auth`, a execução preliminar continua disponível, mas recebe o
bloqueador `AUTH_AUDIT_SKIPPED`. A opção exige permissão de leitura do diretório
Auth.

## Leitura excepcional de produção

O comando exige confirmação dupla e continua sendo somente leitura:

```powershell
npm --prefix functions run audit:multi-tenant -- --project natus-gestantes --cloud --confirm-project natus-gestantes --allow-production-read --include-auth
```

Execute apenas em janela aprovada, considerando custo de leituras e acesso a
identificadores pseudônimos. Sem ADC ou outra credencial externa adequada, o
comando cloud falha sem fazer fallback para outro projeto.

## Relatórios

Por padrão, os artefatos são criados em
`functions/audit-reports/{projeto}_{timestamp}/`:

- `report.json`: resumo, contagens e findings;
- `findings.csv`: triagem e revisão humana;
- `findings.jsonl`: processamento automatizado.

IDs e caminhos são substituídos por hashes determinísticos. Para produzir um
arquivo operacional com IDs reais, use `--include-identifiers` e guarde o
resultado em local seguro e fora de controle de versão. A pasta padrão está no
`.gitignore` e também foi excluída do bundle de deploy das Functions.

Limites opcionais:

```powershell
npm --prefix functions run audit:multi-tenant -- --project demo-natus --emulator-host 127.0.0.1:8080 --page-size 250 --max-documents 10000 --max-references 10000 --max-depth 8
```

Se um limite for atingido, `complete` fica `false`, o finding
`AUDIT_INCOMPLETE` é emitido e o resultado nunca é considerado liberado.
`--max-documents` limita somente documentos lidos pelas consultas paginadas;
ele não cobre referências descobertas por `listDocuments()`. A paginação
opcional do Auth também não entra nessa contagem. O limite de profundidade é
aplicado às referências canônicas e legadas; se ainda houver subcoleções no
limite, a varredura falha de forma fechada.

O Admin SDK materializa o array completo de cada chamada a `listDocuments()`
antes que o auditor consiga ordená-lo e recortá-lo localmente. Portanto,
`--max-references` limita o processamento e os RPCs de fan-out posteriores,
mas não limita o tamanho da resposta nem a memória da chamada individual que
acabou de listar uma coleção. Por esse mesmo motivo, `referencesListed` pode
ser maior que `--max-references`; o teto efetivo é observado por
`referencesVisited`. Uma coleção excepcionalmente grande deve ser auditada em
uma restauração isolada e monitorada, pois essa API não oferece paginação.

A varredura cloud faz leituras paginadas e não representa uma transação ou um
snapshot pontual de todo o banco. Para evitar divergências causadas por escritas
concorrentes, prefira uma janela sem mutações ou audite uma restauração isolada.

## Journals idempotentes de sistema

Os fluxos de criação usam journals sem PII em dois caminhos:

- `clinicas/{tenantId}/operacoesSistema/op_{hash}` para criação de usuário da
  clínica;
- `operacoesSistema/op_{hash}` para criação de clínica com administrador.

Esses documentos guardam somente hashes, estado técnico, contadores e datas. As
regras negam acesso do SDK cliente inclusive a SuperAdmin; somente o Admin SDK
das Functions pode reservá-los ou concluí-los. `operacoesSistema` é uma coleção
técnica dedicada, tanto global quanto dentro do tenant, reconhecida pelo manifest
e fora do conteúdo de negócio migrável.

As duas callables de criação exigem `operacaoId`. O app gera um UUID por
submissão, preserva-o ao repetir o mesmo payload depois de uma falha transitória
e troca o UUID quando o formulário é corrigido. Isso separa retentativa de uma
nova intenção sem gravar e-mail ou outros dados pessoais no identificador.

As Rules estão declaradas no `firebase.json`. Em qualquer liberação, a proteção
de `operacoesSistema` deve ser aplicada antes das Functions que usam os journals.

Exit codes:

- `0`: auditoria completa sem bloqueadores;
- `2`: auditoria completa com bloqueadores ou varredura incompleta;
- `1`: erro de configuração, credencial ou leitura.

A única exceção é o smoke local com `--allow-empty-smoke`, descrito acima: o
processo aceita somente `AUDIT_EMPTY` e os bloqueadores virtuais de policy já
declarados, mas o artefato permanece inequivocamente não liberável.

## Contrato local de Cloud Functions

O checker offline cruza todas as chamadas `httpsCallable(...)` e URLs Firebase
do app com os exports de `functions/index.js`:

```powershell
npm --prefix functions run check:function-contract
```

Sem snapshot, todas as callables usadas pelo app possuem export local, todas as
regiões são explícitas e não existe URL Firebase fixa no cliente. Há dois avisos
locais: `vincularLoginPaciente` não possui chamada estática no app, e o endpoint
HTTP legado `reenviarLinkTrocaSenhaGestante` não possui consumidor estático no
código atual porque foi mantido apenas para compatibilidade.

Para comparar um snapshot do ambiente implantado sem dar acesso de rede ao
checker:

```powershell
New-Item -ItemType Directory -Force functions/audit-reports | Out-Null
firebase functions:list --project ID_DO_PROJETO --json | Set-Content -Encoding utf8 functions/audit-reports/functions-list.json
npm --prefix functions run check:function-contract -- --deployed-json functions/audit-reports/functions-list.json
```

Função implantada ausente no código local é bloqueadora. Export local ainda não
implantado também é bloqueador quando o app já o utiliza; permanece como warning
somente quando não há uso estático localizado. O checker preserva o tipo de
trigger do snapshot e bloqueia incompatibilidades entre callable, HTTP e evento.
O snapshot fica em pasta ignorada e não deve ser commitado.

Não inclua `check:function-contract` no predeploy enquanto o drift do ambiente
implantado estiver aberto, pois os cinco bloqueadores de disponibilidade são
intencionais até a homologação. Valide as Functions candidatas no ambiente
isolado e compare novamente com o inventário implantado nesse ambiente.

O resultado datado da conferência atual está em
[`AUDITORIA_FUNCTIONS_2026-07-22.md`](AUDITORIA_FUNCTIONS_2026-07-22.md).

## Próximo passo depois do ensaio

1. Revisar o diff e obter aprovação explícita da janela de mudança.
2. Implantar primeiro a sincronização aditiva e confirmar a observabilidade.
3. Gerar novo backup completo imediatamente antes da janela.
4. Repetir o dry-run cloud e interromper se houver qualquer bloqueador novo.
5. Aplicar o backfill controlado, repetir a auditoria read-only e avançar apenas
   com `releaseReady: true`.
6. Seguir a ordem e os critérios de rollback em
   [`PLANO_RELEASE_SEM_INTERRUPCAO.md`](PLANO_RELEASE_SEM_INTERRUPCAO.md).
