/* eslint-disable require-jsdoc */
"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  canonicalSyncDestination,
} = require("../canonical_sync_policy");

function tenantData(extra) {
  return {
    adminDonoId: "clinic-a",
    clinicaId: "clinic-a",
    ...(extra || {}),
  };
}

test("sincroniza registros de paciente no destino prefixado", () => {
  const result = canonicalSyncDestination(
      "parcelas",
      "installment-a",
      tenantData({
        gestanteId: "patient-a",
        idGestante: "patient-a",
        pacienteId: "patient-a",
      }),
  );

  assert.equal(result.status, "ready");
  assert.equal(
      result.path,
      "clinicas/clinic-a/pacientes/patient-a/financeiro/" +
        "parcela_installment-a",
  );
});

test("preserva quarentena na área operacional da clínica", () => {
  const result = canonicalSyncDestination(
      "contracoes",
      "legacy-a",
      tenantData({
        migracaoMotivo: "paciente_nao_resolvido",
        migracaoStatus: "quarentena",
      }),
  );

  assert.equal(result.status, "ready");
  assert.equal(
      result.path,
      "clinicas/clinic-a/operacao/quarentena_contracoes_legacy-a",
  );
});

test("recusa aliases incompletos e ignora coleção global", () => {
  assert.deepEqual(
      canonicalSyncDestination("parcelas", "a", {clinicaId: "clinic-a"}),
      {status: "blocked", reason: "invalid_tenant_aliases"},
  );
  assert.deepEqual(
      canonicalSyncDestination("orders", "a", {}),
      {status: "ignored", reason: "global_or_unknown"},
  );
});

test("não cria perfil canônico para Super Admin global", () => {
  assert.deepEqual(
      canonicalSyncDestination(
          "usuarios",
          "root",
          tenantData({tipo: "superAdmin", uid: "root"}),
      ),
      {status: "ignored", reason: "superadmin_global"},
  );
});
