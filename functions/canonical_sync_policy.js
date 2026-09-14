/* eslint-disable require-jsdoc */
"use strict";

const {
  canonicalDocumentId,
  ROOT_COLLECTIONS,
} = require("./audit/multi_tenant_manifest");
const {
  inspectPatientLink,
  inspectTenant,
  inspectUserRole,
  isMigrationQuarantined,
} = require("./audit/multi_tenant_policy");

const SYNC_VERSION = 1;
const DEFINITIONS = new Map(ROOT_COLLECTIONS.map((definition) => [
  definition.name,
  definition,
]));

function canonicalSyncDestination(collectionName, documentId, data) {
  const definition = DEFINITIONS.get(collectionName);
  if (!definition) return {status: "ignored", reason: "global_or_unknown"};
  if ([
    "clinicas",
    "usuariosSaaS",
    "vinculosAuthPaciente",
    "vinculosPacienteAuth",
    "vinculosAuthEntidade",
    "vinculosEntidadeAuth",
  ].includes(collectionName)) {
    return {status: "ignored", reason: "directory_or_lock"};
  }

  if (collectionName === "clinicasSaaS") {
    const tenant = inspectTenant(data);
    if (!tenant.canonical || tenant.resolved !== documentId) {
      return {status: "blocked", reason: "invalid_clinic_aliases"};
    }
    return {
      status: "ready",
      path: `clinicas/${documentId}`,
      data: {
        ...data,
        sincronizacaoOrigem: `${collectionName}/${documentId}`,
        sincronizacaoVersao: SYNC_VERSION,
      },
    };
  }

  const tenant = inspectTenant(data);
  if (!tenant.canonical) {
    return {status: "blocked", reason: "invalid_tenant_aliases"};
  }
  const tenantId = tenant.resolved;
  let path;

  if (collectionName === "usuarios") {
    if (inspectUserRole(data).resolved === "superAdmin") {
      return {status: "ignored", reason: "superadmin_global"};
    }
    path = `clinicas/${tenantId}/usuarios/${documentId}`;
  } else if (collectionName === "gestantes") {
    const link = inspectPatientLink(data, false);
    if (link.ids.values.length !== 1 || link.ids.values[0] !== documentId) {
      return {status: "blocked", reason: "invalid_patient_identity"};
    }
    path = `clinicas/${tenantId}/pacientes/${documentId}`;
  } else if (["planos", "biblioteca"].includes(collectionName)) {
    path = `clinicas/${tenantId}/${collectionName}/${documentId}`;
  } else if (definition.canonicalDisposition === "mapped") {
    const quarantined = isMigrationQuarantined(data);
    if (quarantined) {
      if (!definition.quarantineCopy) {
        return {status: "blocked", reason: "quarantine_destination_missing"};
      }
      path = `clinicas/${tenantId}/${definition.quarantineCopy.collection}/` +
        canonicalDocumentId(definition, documentId, {quarantine: true});
    } else if (definition.canonicalCopy.scope === "patient") {
      const link = inspectPatientLink(data, definition.inspectPayload);
      if (link.ids.values.length !== 1) {
        return {status: "blocked", reason: "invalid_patient_link"};
      }
      path = `clinicas/${tenantId}/pacientes/${link.ids.values[0]}/` +
        `${definition.canonicalCopy.collection}/` +
        canonicalDocumentId(definition, documentId);
    } else {
      path = `clinicas/${tenantId}/${definition.canonicalCopy.collection}/` +
        canonicalDocumentId(definition, documentId);
    }
  } else {
    return {status: "ignored", reason: "special_without_mirror"};
  }

  return {
    status: "ready",
    path,
    data: {
      ...data,
      sincronizacaoOrigem: `${collectionName}/${documentId}`,
      sincronizacaoVersao: SYNC_VERSION,
    },
  };
}

module.exports = {
  SYNC_VERSION,
  canonicalSyncDestination,
};
