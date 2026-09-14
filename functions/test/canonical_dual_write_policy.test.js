/* eslint-disable require-jsdoc */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  MAX_SAFE_BATCH_WRITES,
  canonicalPatientLinkedRecordPath,
  canonicalPatientPath,
  canonicalUserPath,
  countPatientLinkBatchWrites,
} = require("../canonical_dual_write_policy");

test("resolve copias canonicas aprovadas do vinculo de paciente", () => {
  assert.equal(
      canonicalUserPath("clinic-a", "user-a"),
      "clinicas/clinic-a/usuarios/user-a",
  );
  assert.equal(
      canonicalPatientPath("clinic-a", "patient-a"),
      "clinicas/clinic-a/pacientes/patient-a",
  );
  assert.equal(canonicalPatientLinkedRecordPath({
    collection: "agenda",
    documentId: "event-a",
    clinicaId: "clinic-a",
    pacienteId: "patient-a",
  }), "clinicas/clinic-a/agenda/event-a");

  for (const collection of ["documentos", "exames", "contratos"]) {
    assert.equal(canonicalPatientLinkedRecordPath({
      collection,
      documentId: "record-a",
      clinicaId: "clinic-a",
      pacienteId: "patient-a",
    }), `clinicas/clinic-a/pacientes/patient-a/${collection}/record-a`);
  }
});

test("nao inventa destino para colecoes unresolved ou fora do vinculo", () => {
  for (const collection of [
    "parcelas",
    "parcelasFinanceiras",
    "contracoes",
    "atendimentos",
    "enfermeiras",
  ]) {
    assert.equal(canonicalPatientLinkedRecordPath({
      collection,
      documentId: "record-a",
      clinicaId: "clinic-a",
      pacienteId: "patient-a",
    }), "", collection);
  }
});

test("conta todas as escritas do batch com margem operacional", () => {
  assert.equal(countPatientLinkBatchWrites({
    legacyRecordWrites: 241,
    canonicalRecordWrites: 241,
    writesLegacyUser: true,
  }), MAX_SAFE_BATCH_WRITES);
  assert.ok(countPatientLinkBatchWrites({
    legacyRecordWrites: 242,
    canonicalRecordWrites: 242,
    writesLegacyUser: true,
  }) > MAX_SAFE_BATCH_WRITES);
});
