/* eslint-disable require-jsdoc */
"use strict";

const MAX_SAFE_BATCH_WRITES = 490;

// Este mapa e deliberadamente menor que o manifesto canonico completo: ele
// inclui apenas as colecoes que vincularUidAPaciente ja altera e cujo destino
// foi aprovado. Colecoes sem destino aprovado devem continuar sem dual-write.
const APPROVED_PATIENT_LINK_DESTINATIONS = Object.freeze({
  agenda: Object.freeze({scope: "clinic", collection: "agenda"}),
  documentos: Object.freeze({scope: "patient", collection: "documentos"}),
  exames: Object.freeze({scope: "patient", collection: "exames"}),
  contratos: Object.freeze({scope: "patient", collection: "contratos"}),
});

function canonicalUserPath(clinicaId, uidUsuario) {
  return `clinicas/${clinicaId}/usuarios/${uidUsuario}`;
}

function canonicalPatientPath(clinicaId, pacienteId) {
  return `clinicas/${clinicaId}/pacientes/${pacienteId}`;
}

function canonicalPatientLinkedRecordPath({
  collection,
  documentId,
  clinicaId,
  pacienteId,
}) {
  const destination = APPROVED_PATIENT_LINK_DESTINATIONS[collection];
  if (!destination) return "";

  if (destination.scope === "clinic") {
    return `clinicas/${clinicaId}/${destination.collection}/${documentId}`;
  }

  return `clinicas/${clinicaId}/pacientes/${pacienteId}/` +
    `${destination.collection}/${documentId}`;
}

function countPatientLinkBatchWrites({
  legacyRecordWrites,
  canonicalRecordWrites,
  writesLegacyUser,
}) {
  // usuario raiz + paciente raiz + usuario canonico + paciente canonico +
  // dois locks + log administrativo.
  const fixedWrites = 7 + (writesLegacyUser ? 1 : 0);
  return legacyRecordWrites + canonicalRecordWrites + fixedWrites;
}

module.exports = {
  APPROVED_PATIENT_LINK_DESTINATIONS,
  MAX_SAFE_BATCH_WRITES,
  canonicalPatientLinkedRecordPath,
  canonicalPatientPath,
  canonicalUserPath,
  countPatientLinkBatchWrites,
};
