# Auditoria de Cloud Functions — 22/07/2026

Esta é uma fotografia datada, obtida por consulta read-only dos metadados do
projeto `natus-gestantes`. Nenhuma Function foi publicada, alterada ou removida.

## Resultado executivo

O código local está coerente, mas ainda não está pronto para um deploy completo
em produção.

- Produção possui 8 Functions ativas e todas continuam presentes localmente.
- O backend local possui 14 exports; 6 ainda não estão implantados.
- O app possui 8 chamadas callable estáticas e nenhuma URL fixa de Function.
- 5 callables usadas pelo app ainda não estão implantadas.
- O checker encontrou exatamente 5 bloqueadores de disponibilidade e nenhuma
  divergência de trigger, região ou codebase.
- Todas as chamadas do app agora usam `us-central1` explicitamente.
- O endpoint HTTP legado de redefinição de senha foi preservado apenas para
  compatibilidade; o app usa a nova callable regional.
- O checker inventaria exports `onRequest` sem consumidor HTTP estático com o
  aviso `unused_http_export`; o endpoint legado aparece nesse inventário sem
  criar um bloqueador adicional.
- `vincularLoginPaciente` permanece local, sem chamada estática no cliente e
  sem implantação.
- As implementações não utilizadas de Asaas e NFS-e/Focus foram retiradas
  intencionalmente do produto. Nenhum dado remoto foi apagado.

## Functions implantadas

- `consultarContratoZapSign`
- `criarUsuarioGestanteAoCadastrar`
- `excluirUsuarioAuth`
- `gerarContratoZapSign`
- `notificarContracaoGestante`
- `prepararContratoZapSignAoAtualizar`
- `prepararContratoZapSignAoCadastrar`
- `reenviarLinkTrocaSenhaGestante`

## Exports locais ainda não implantados

- `alterarTipoUsuarioClinica`
- `buscarCoordenadaEndereco`
- `criarClinicaComAdminSaaS`
- `criarUsuarioClinica`
- `solicitarRedefinicaoSenhaPaciente`
- `vincularLoginPaciente`

Os cinco primeiros são usados pelo app atual. `vincularLoginPaciente` existe no
backend local, mas não possui chamada estática localizada no cliente.

## Correções validadas localmente

- ZapSign usa `FirebaseFunctions.instanceFor(region: 'us-central1')`.
- A redefinição de senha não depende mais de URL Cloud Run fixa e verifica
  explicitamente token revogado.
- As quatro Functions administrativas pendentes declaram `us-central1`.
- Criação e alteração de usuários fazem dual-write canônico atômico.
- As duas criações que atravessam Auth + Firestore usam journal idempotente,
  IDs determinísticos, retomada e rollback protegido contra concorrência.
- O app envia um UUID por submissão: retentativas idênticas reutilizam o mesmo
  identificador e formulários corrigidos iniciam uma nova operação.
- As Rules e os índices agora estão declarados no `firebase.json`; os journals
  técnicos são inacessíveis pelo SDK cliente.
- O vínculo de paciente duplica somente os destinos já aprovados: `agenda`,
  `documentos`, `exames` e `contratos`.
- Batches acima de 490 writes falham de forma fechada.
- Os fluxos administrativos, de geocodificação, vínculo e redefinição foram
  cobertos por testes unitários e/ou pelo Firestore + Auth Emulator.

## Gate de liberação

1. Preparar um ambiente de homologação isolado e aplicar primeiro as Rules.
2. Implantar somente as Functions candidatas; em especial, a nova redefinição
   de senha deve existir antes de qualquer publicação do app.
3. Executar testes de aceite e repetir o checker com o snapshot de homologação.
4. Resolver o plano de migração multi-clínica documentado na auditoria de dados.
5. Só então preparar um deploy seletivo e reversível para produção, mantendo a
   ordem Rules → Functions → app.

O deploy completo de Functions permanece bloqueado nesta etapa.
