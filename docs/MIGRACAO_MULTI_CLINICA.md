# Migração multi-clínica — artefatos staged

> **ATENÇÃO: estas regras NÃO estão ativas em produção.** Os arquivos em
> `firebase/security/` estão vinculados ao `firebase.json` local e protegidos
> por um gate de predeploy, mas não foram publicados. Não faça deploy direto:
> siga o rollout controlado documentado em
> [`PLANO_RELEASE_SEM_INTERRUPCAO.md`](PLANO_RELEASE_SEM_INTERRUPCAO.md).

Este documento descreve o caminho seguro para migrar o Natus do modelo legado,
com coleções operacionais globais, para isolamento por clínica. A nova raiz é:

```text
clinicas/{tenantId}/...
```

O inventário automatizado e seus comandos estão documentados em
[`AUDITORIA_MULTI_CLINICA.md`](AUDITORIA_MULTI_CLINICA.md). Ele é estritamente
read-only e deve ser executado antes de qualquer backfill.

No primeiro ciclo, `tenantId`, `clinicaId` e `adminDonoId` representam o ID do
documento da clínica. `adminUid` continua representando apenas o UID da conta
administradora e não pode ser usado como chave de tenant.

## Invariantes de segurança

1. Todo usuário precisa existir em `usuarios/{uid}`, ter `status: ativo`, perfil
   conhecido e vínculo com uma clínica ativa ou em teste.
2. Superadministrador exige **custom claim** `superAdmin: true`, perfil
   normalizado `superAdmin` e usuário ativo. Um campo editável no Firestore não
   concede acesso global sozinho.
3. Durante a migração, leituras aceitam `clinicaId` ou `adminDonoId`. Se os dois
   existirem e forem diferentes, o acesso é negado.
4. Todo create/update após a ativação precisa gravar os dois aliases, iguais ao
   tenant do caminho e iguais entre si.
5. Clínica ausente, pausada, bloqueada ou excluída resulta em negação.
   Quando `clinicas/{tenantId}` existir, seu status é autoritativo e não há
   fallback para um status legado possivelmente desatualizado.
6. O Admin SDK ignora regras do Firestore e Storage. Portanto, cada Cloud
   Function deve resolver o tenant pelo usuário autenticado e validar origem e
   destino antes de ler, escrever, notificar ou excluir.
7. Nenhuma consulta cliente pode depender de filtro em memória. O cliente de
   produção faz hard cutover e filtra simultaneamente por
   `adminDonoId == tenantId` e `clinicaId == tenantId`. Ferramentas de migração
   podem fazer dual-read separado para localizar registros incompletos, mas não
   devem expor esse fallback global à UI.
8. `planos` e `biblioteca` pertencem à clínica. Não existe leitura de catálogo
   global entre tenants; inclusive na compatibilidade top-level, cada documento
   precisa carregar aliases de tenant válidos.

## Modelo de caminhos proposto

```text
usuarios/{uid}                              # diretório mínimo de bootstrap
clinicas/{tenantId}
  usuarios/{uid}
  profissionais/{profissionalId}
  pacientes/{pacienteId}
    prontuario/{registro...}
    atendimentos/{atendimento...}
    exames/{exame...}
    documentos/{documento...}
    contratos/{contrato...}
    agenda/{evento...}
    financeiro/{lancamento...}
  agenda/{eventoId}
  operacao/{documento...}
  financeiro/{lancamento...}
  planos/{planoId}
  biblioteca/{materialId}
  configuracoes/{documento...}
  notificacoes/{notificacaoId}
  logs/{logId}
```

Separação intencional:

- **clínica/operação:** profissionais autenticados da clínica;
- **paciente:** profissionais e o próprio paciente, apenas nos recursos
  explicitamente disponibilizados;
- **financeiro:** administrador da clínica e, quando vinculado por ID, o próprio
  paciente em modo somente leitura;
- **prontuário interno:** equipe clínica, sem liberação automática ao portal;
- **contratos:** leitura pela equipe da clínica e pela própria paciente;
  create/update/delete somente pelo admin do tenant. SuperAdmin passa pelo gate
  de claim/perfil ativo e deve operar pelo fluxo de governança;
- **planos e biblioteca:** leitura pelos membros da própria clínica e escrita
  somente pelo administrador da clínica;
- **superAdmin:** acesso global somente via custom claim e usuário ativo.

## Pré-requisitos obrigatórios antes de vincular as regras

- [ ] Aprovação do responsável técnico e do responsável pelos dados.
- [ ] Export completo e testado do Firestore.
- [ ] Inventário/cópia dos objetos do Storage com checksums e metadados.
- [ ] Export ou procedimento documentado de recuperação do Firebase Auth.
- [ ] Retenção do backup em local separado e teste de restauração.
- [ ] Inventário de todos os documentos sem tenant, com tenant divergente ou
      associação ambígua.
- [ ] Backfill de **ambos** os aliases concluído em todo registro usado pelo
      cliente atual. As regras aceitam dual-read para migração, mas o app exige
      os dois filtros simultaneamente; registro sem qualquer um deles fica
      invisível.
- [ ] Backfill validado em ambiente não produtivo.
- [ ] Cloud Functions endurecidas para isolamento de tenant.
- [ ] Service agent do Cloud Storage autorizado para `firestore.get/exists`
      nas regras cross-service, conforme a documentação oficial do Firebase.
- [ ] Aplicativo lendo e gravando os novos caminhos atrás de feature flag.
- [ ] Testes das regras no Firebase Emulator com pelo menos duas clínicas.
- [ ] Índices construídos e estáveis antes de liberar consultas.
- [ ] Plano de observabilidade, plantão e rollback aprovado.

## Backfill e cópia de dados

1. Gere uma tabela imutável `uid -> tenantId` a partir de `usuarios`,
   `usuariosSaaS`, `clinicasSaaS` e vínculos profissionais/pacientes.
2. Não atribua automaticamente documentos ambíguos à primeira clínica. Coloque
   esses registros em quarentena para revisão humana.
3. Em cada usuário e documento operacional, grave:

   ```json
   {
     "clinicaId": "<tenantId>",
     "adminDonoId": "<tenantId>"
   }
   ```

4. Troque relações por nome por IDs estáveis (`pacienteId`, `profissionalId`).
   O diretório `usuarios/{uid}` de cada paciente deve conter `pacienteId`, pois
   as regras de Storage não fazem um terceiro lookup para inferir esse vínculo.
5. Copie os documentos para `clinicas/{tenantId}/...`; não apague os legados
   nesta fase. A criação do documento canônico `clinicas/{tenantId}` é
   obrigatória antes de testar Storage: para respeitar o limite de lookups
   cross-service, as regras de arquivos não consultam `clinicasSaaS` como
   fallback.
6. Copie arquivos para caminhos com tenant e paciente explícitos. Nos novos
   uploads, grave também `clinicaId`, `adminDonoId` e `enviadoPorUid` em custom
   metadata; arquivos de paciente devem incluir `pacienteId`. Os caminhos legados
   `documentos/{arquivo}` e `exames/{pacienteId}/{arquivo}` não oferecem
   isolamento suficiente sem lookups adicionais e permanecem bloqueados para
   usuários comuns no arquivo staged.
7. Migre fotos de `perfis/{uid}/...` para
   `clinicas/{tenantId}/usuarios/{uid}/perfil/...`. O caminho legado fica apenas
   para leitura do próprio usuário durante a transição e não aceita novos uploads.
8. Trate `planos` e `biblioteca` como dados do tenant. Faça backfill dos aliases
   nos documentos top-level e copie o catálogo para
   `clinicas/{tenantId}/planos` e `clinicas/{tenantId}/biblioteca`. Arquivos da
   biblioteca devem ir para `clinicas/{tenantId}/biblioteca/...`; o caminho de
   Storage legado sem tenant não é liberado aos membros da clínica.
9. Compare contagem, IDs, hashes e valores financeiros entre origem e destino.
10. Registre cada lote, horário, versão do script e resultado. O script deve ser
   idempotente e retomável.

## Contrato exato de uploads no Storage

Toda gravação canônica usa `putData(bytes, SettableMetadata(...))`. A extensão
do nome não autoriza o arquivo: `contentType` precisa ser enviado explicitamente
e coincidir exatamente com um dos valores permitidos abaixo. Os limites são
exclusivos (`size < limite`), não inclusivos.

| Caminho | Quem pode criar | MIME aceito | Limite |
| --- | --- | --- | --- |
| `clinicas/{tenantId}/pacientes/{patientId}/exames/...` | equipe da clínica ou o próprio paciente | `application/pdf`, `image/jpeg`, `image/png`, `image/webp` | menor que 25 MiB |
| `clinicas/{tenantId}/pacientes/{patientId}/documentos/...` | equipe da clínica ou o próprio paciente | `application/pdf`, `image/jpeg`, `image/png`, `image/webp` | menor que 25 MiB |
| `clinicas/{tenantId}/pacientes/{patientId}/contratos/...` | somente admin da clínica; SuperAdmin governado | `application/pdf`, `image/jpeg`, `image/png`, `image/webp` | menor que 25 MiB |
| `clinicas/{tenantId}/usuarios/{uid}/perfil/...` | o próprio usuário ou admin da clínica | `image/jpeg`, `image/png`, `image/webp` | menor que 10 MiB |
| `clinicas/{tenantId}/biblioteca/...` | admin da clínica | PDF/JPEG/PNG/WebP: os MIME acima; vídeo: somente `video/mp4` | arquivo comum menor que 25 MiB; MP4 menor que 250 MiB |
| `clinicas/{tenantId}/financeiro/...` e `clinicas/{tenantId}/operacao/...` | papel autorizado pelas regras | `application/pdf`, `image/jpeg`, `image/png`, `image/webp` | menor que 25 MiB |

Todo create/update canônico exige estas chaves em `customMetadata`, todas como
strings e sem inferência pelo nome do arquivo:

| Chave | Valor obrigatório |
| --- | --- |
| `clinicaId` | exatamente o `{tenantId}` do caminho |
| `adminDonoId` | exatamente o mesmo `{tenantId}` |
| `enviadoPorUid` | exatamente `request.auth.uid` |
| `pacienteId` | exatamente o `{patientId}` do caminho; obrigatória apenas nos caminhos de paciente e financeiro por paciente |

Exemplo para um PDF de paciente:

```dart
SettableMetadata(
  contentType: 'application/pdf',
  customMetadata: {
    'clinicaId': tenantId,
    'adminDonoId': tenantId,
    'enviadoPorUid': uidAutenticado,
    'pacienteId': pacienteId,
  },
)
```

O paciente tem somente `create` e `read` nos próprios exames/documentos. Não
pode sobrescrever nem excluir o objeto após o envio. O vínculo depende de
`usuarios/{uid}.pacienteId` (ou do alias temporário `idGestante`) igual ao
`{patientId}` do caminho. Ausência ou divergência nega o acesso.

No Firestore, a criação correspondente feita pelo paciente também precisa ter:

- `clinicaId` e `adminDonoId` iguais ao tenant autenticado;
- `criadoPorUid` igual a `request.auth.uid`;
- `uidPaciente` ou o alias temporário `uidGestante` igual a
  `request.auth.uid` (`gestanteUid` é o alias temporário específico da agenda);
- `pacienteId` no caminho canônico; no top-level temporário, as regras também
  reconhecem `gestanteId` ou `idGestante` durante a migração.

O picker da biblioteca deve aceitar somente os tipos da tabela. Vídeo fica
restrito a MP4; formatos genéricos, executáveis, documentos Office e outros
codecs permanecem negados. Os pickers de exame/documento não devem oferecer
MP4, mesmo que a biblioteca aceite vídeo.

## Compatibilidade temporária do cliente

Enquanto o Firestore ainda usa as coleções top-level `planos`, `biblioteca`,
`exames` e `documentos`, as regras staged aceitam esse formato sob estas
condições:

- toda consulta de clínica deve filtrar o tenant no servidor simultaneamente por
  `adminDonoId` e `clinicaId`; uma consulta global de membro comum é negada;
- creates e updates precisam resultar em `clinicaId` e `adminDonoId` presentes,
  iguais e pertencentes à clínica autenticada;
- plano e item de biblioteca podem ser gravados apenas pelo admin da clínica;
- paciente pode criar, mas não atualizar/excluir, um exame ou documento próprio
  com os campos de autoria e vínculo descritos acima;
- o destino final continua sendo a hierarquia `clinicas/{tenantId}/...`; a
  compatibilidade top-level deve ser removida após o shadow-read e a janela de
  estabilização.

Antes de ativar as regras, o cliente também deve validar MIME e tamanho por área
antes do `putData`, para que uma negação segura não apareça ao usuário apenas
como erro genérico de permissão. Essa validação melhora a experiência, mas não
substitui as regras do Storage.

O rollout deste cliente é um **hard cutover de aliases**: não existe fallback
global. Toda query tenant-scoped exige os dois campos iguais ao tenant. Portanto,
zero registro ativo sem qualquer alias é um gate absoluto de publicação. A
tolerância dual-read das regras serve para migração e diagnóstico; ela não torna
dados ausentes de um dos filtros visíveis ao app.

## Primeiro acesso de contas legadas

Toda conta com `usuarios/{uid}.primeiroLogin == true` deve ser interceptada no
`AuthGate` e forçada a definir uma nova senha antes de entrar no app. O fluxo é:

1. executar `FirebaseAuth.currentUser.updatePassword(novaSenha)`;
2. somente após sucesso no Auth, atualizar **apenas** `usuarios/{uid}` com
   `primeiroLogin: false` e `senhaAlteradaEm: FieldValue.serverTimestamp()`;
3. liberar a navegação apenas depois da confirmação do documento.

Não há write nem dependência de `usuariosSaaS/{uid}` nesse fluxo. A regra do
próprio usuário aceita a transição monotônica `true -> false` uma única vez e
exige que `senhaAlteradaEm == request.time`. Ela permite que a mesma operação
inclua campos de perfil já autorizados, mas continua negando alteração de
`clinicaId`, `adminDonoId`, papel (`tipo`/`tipoUsuario`), `status`, UID ou qualquer
outro campo privilegiado. Não é permitido mudar `false -> true`, repetir a troca
do timestamp ou criar `primeiroLogin: false` quando o campo estava ausente.

Antes do rollout, faça inventário das contas legadas marcadas com
`primeiroLogin: true`, valide que possuem `uid` igual ao ID do documento, ambos
os aliases e perfil/status consistentes e teste também o caso de
`requires-recent-login` retornado pelo Firebase Auth. Se o update do Auth
funcionar e o Firestore falhar, o gate deve continuar fechado e permitir nova
tentativa segura; nunca deve liberar a sessão apenas porque a senha já mudou no
Auth.

## Cloud Functions antes das regras

Antes da ativação, toda Function deve:

- exigir autenticação quando não for um trigger interno;
- carregar `usuarios/{request.auth.uid}` e validar status, perfil e tenant;
- validar que documentos alvo pertencem ao mesmo tenant;
- rejeitar aliases divergentes;
- propagar os dois aliases em contratos, documentos, notificações, usuários e
  lançamentos financeiros;
- exigir admin do tenant em toda mutação de contrato, inclusive geração,
  atualização de status, cancelamento, exclusão e persistência de callbacks da
  ZapSign; leituras podem atender staff e a própria paciente vinculada;
- filtrar destinatários de push pelo tenant do evento;
- validar o tenant antes de excluir usuários do Auth;
- nunca confiar em `tenantId`, `clinicaId`, `adminDonoId` ou IDs de documentos
  enviados pelo cliente sem conferência server-side;
- manter secrets e integrações no servidor. O cliente pode ler apenas dados
  explicitamente públicos, como a chave pública VAPID.
- configurar `GOOGLE_MAPS_GEOCODING_API_KEY` no Secret Manager da homologação e
  da produção. A chave que esteve no cliente deve ser revogada e substituída,
  pois continua presente no histórico anterior do Git.
- ensaiar retries e reconciliação das operações que atravessam Firebase Auth e
  Firestore. Como não existe transação única entre os dois serviços, uma falha
  parcial deve convergir sem deixar conta ou perfil órfão; a ativação em
  produção exige teste de falha injetada e trilha durável por `operacaoId`.

## Índices reconciliados com o cliente

O arquivo staged de índices cobre explicitamente as consultas compostas que o
cliente monta hoje:

- `gestantes`, `contracoes`, `exames`, `documentos` e `parcelas` por
  `adminDonoId + clinicaId + uidGestante` no portal do paciente;
- `exames`, `prontuario_atendimentos` e `prontuarios` por
  `adminDonoId + clinicaId + idGestante` para a equipe;
- `parcelas` por `adminDonoId + clinicaId + gestanteId`;
- `agenda` por `adminDonoId + clinicaId + gestanteUid` para o paciente e por
  `adminDonoId + clinicaId + dataHoraInicio` para listagem/período da clínica;
- notificações por tenant, destinatário e data, conforme as consultas já
  existentes.

Planos e biblioteca usam igualdade pelos dois aliases e ordenação em memória; o
arquivo staged inclui o índice composto do par de aliases. Se a ordenação migrar
para `orderBy`, o índice com esse terceiro campo deve ser adicionado antes do
rollout dessa versão.

## Matriz mínima de testes no Emulator

Use duas clínicas (`clinica-a`, `clinica-b`) e contas distintas:

- superAdmin com e sem custom claim;
- admin, profissional e paciente de cada clínica;
- usuário ativo, inativo e sem status;
- clínica ativa, teste, pausada, bloqueada e inexistente;
- documento somente com `clinicaId`;
- documento somente com `adminDonoId`;
- documento com aliases iguais;
- documento com aliases divergentes;
- create/update sem um alias;
- leitura e escrita cruzada entre clínicas;
- paciente lendo o próprio recurso e tentando ler outro paciente;
- paciente criando exame/documento próprio e tentando update/delete;
- paciente tentando criar exame/documento para outro `pacienteId` ou tenant;
- staff e paciente lendo contrato autorizado, mas recebendo negação em
  create/update/delete; admin do tenant concluindo essas mutações;
- plano e item de biblioteca de uma clínica consultados por outra;
- profissional tentando acessar financeiro;
- upload com metadata ausente, alias divergente ou `enviadoPorUid` de terceiro;
- upload com tipo permitido, tipo proibido e tamanho exatamente no limite;
- MP4 na biblioteca e MP4 negado em exame, documento e foto de perfil;
- conta com `primeiroLogin: true` concluindo `true -> false` com serverTimestamp;
- tentativa de `false -> true`, timestamp sem transição e alteração conjunta de
  tenant, perfil ou status no primeiro acesso;
- caminho legado de documento sem tenant;
- query filtrada e query global sem filtro.

Critério: todos os casos negativos devem falhar explicitamente. Um erro de
leitura de contexto também deve negar acesso.

## Rollout

1. Restaure uma cópia recente em projeto Firebase de homologação.
2. Rode backfill e cópia para os novos caminhos.
3. Suba as Functions endurecidas em homologação.
4. Inicie Emulator Suite com as regras staged e execute a matriz completa.
5. Execute testes de integração do app com feature flag nos novos caminhos.
6. Faça shadow-read: compare resposta legada e canônica sem mudar a UI.
7. Corrija toda divergência antes de prosseguir.
8. Construa os índices e aguarde o status pronto.
9. Somente após aprovação, confirme que o `firebase.json` mantém as referências:

   ```json
   {
     "firestore": {
       "rules": "firebase/security/firestore.rules",
       "indexes": "firebase/security/firestore.indexes.json"
     },
     "storage": {
       "rules": "firebase/security/storage.rules"
     }
   }
   ```

   O repositório já contém essa vinculação, mas o gate de predeploy recusa o
   ambiente produtivo enquanto a auditoria cloud recente não estiver completa
   e sem bloqueadores.
10. Publique primeiro para um grupo interno, depois uma clínica piloto e só
    então amplie gradualmente.
11. Monitore `permission-denied`, falhas de Functions, divergências de shadow
    read, notificações, cobranças, contratos e uploads.
12. Mantenha as coleções legadas somente pelo período de estabilização aprovado.

## Checklist de ativação

- [ ] Backups e restauração testados.
- [ ] Zero documento ativo sem tenant.
- [ ] Zero documento ativo sem `clinicaId` ou sem `adminDonoId`; todos os aliases
      são iguais entre si e ao tenant esperado.
- [ ] Zero alias divergente.
- [ ] Zero relação financeira ou clínica baseada apenas em nome.
- [ ] Claims de superAdmin conferidas e tokens revogados/renovados.
- [ ] Functions validadas em homologação.
- [ ] Chave antiga de geocodificação revogada e novo secret configurado.
- [ ] Saga/reconciliador do ciclo de usuários validado com falhas parciais e
      repetição idempotente da mesma operação.
- [ ] Regras Firestore e Storage aprovadas no Emulator.
- [ ] Consultas do app cobertas pelos índices.
- [ ] Feature flags e telemetria disponíveis.
- [ ] Janela de mudança e responsáveis definidos.
- [ ] Rollback ensaiado.

## Rollback

Rollback não significa abrir regras. Nunca substitua estas regras por
`allow read, write: if true`.

1. Acione a feature flag para interromper novos writes e retornar o app ao
   último caminho conhecido, mantendo filtro de tenant.
2. Pause Functions escritoras e filas que possam ampliar a divergência.
3. Reaplique a última versão **segura e versionada** das regras e índices.
4. Preserve os dados canônicos e legados; não faça exclusão durante o incidente.
5. Compare logs e restaure somente a partir do backup validado, se necessário.
6. Revogue tokens quando claims ou vínculos estiverem incorretos.
7. Registre causa, intervalo afetado, tenants envolvidos e reconciliação.
8. Só retome o rollout após nova execução integral da matriz do Emulator.

## Remoção dos caminhos legados

A exclusão definitiva só pode ocorrer depois de uma janela de estabilidade,
reconciliação completa, confirmação de backup e aprovação formal. Em seguida:

1. desative dual-read;
2. bloqueie todos os writes legados;
3. observe por uma janela adicional;
4. exporte novamente;
5. remova dados legados em lote auditável e recuperável;
6. simplifique regras e índices em uma mudança separada.
