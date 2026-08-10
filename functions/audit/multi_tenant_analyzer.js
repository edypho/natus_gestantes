/* eslint-disable require-jsdoc, max-len */
"use strict";

const {ROOT_COLLECTIONS} = require("./multi_tenant_manifest");
const {
  addIssue,
  buildIndexes,
  finalizeReport,
  initializeReport,
  normalizedStatus,
} = require("./multi_tenant_analysis_context");
const {
  auditCanonicalCopies,
  auditCanonicalDocuments,
} = require("./multi_tenant_canonical_audits");
const {
  auditAuthentication,
  auditClinicDocumentBasics,
  auditClinicMirrors,
  auditClinicOwners,
  auditUserDocumentBasics,
  auditUserMirrors,
} = require("./multi_tenant_directory_audits");
const {
  auditDuplicatePatientUids,
  auditPatientEntity,
  auditPatientLocks,
  auditPatientRecord,
  auditPatientUser,
} = require("./multi_tenant_patient_audits");
const {
  auditStaffEntity,
  auditStaffLocks,
  auditStaffUser,
} = require("./multi_tenant_staff_audits");
const {
  auditTenant,
  auditUnknownCollections,
} = require("./multi_tenant_tenant_audits");

const ACTIVE_CLINIC_STATUSES = new Set(["ativa", "teste"]);

function auditActiveUserClinic(report, document, tenant, clinicIndex) {
  if (normalizedStatus(document) !== "ativo" || !tenant.resolved) return;

  const clinic = clinicIndex.any.get(tenant.resolved);
  if (!clinic || ACTIVE_CLINIC_STATUSES.has(normalizedStatus(clinic))) return;

  addIssue(report, document, {
    severity: "critical",
    blocker: true,
    code: "ACTIVE_USER_IN_INACTIVE_CLINIC",
    message: "Usuário ativo está ligado a uma clínica inativa.",
    identifiers: {userUid: document.id, tenantId: tenant.resolved},
    details: {clinicStatus: normalizedStatus(clinic)},
  });
}

function auditRootDocument(report, document, definition, indexes, state) {
  const tenant = auditTenant(
      report,
      document,
      definition,
      indexes.clinicIndex,
  );

  if (["clinic", "clinicLegacy"].includes(definition.kind)) {
    auditClinicDocumentBasics(report, document);
  } else if (["user", "userLegacy"].includes(definition.kind)) {
    const basics = auditUserDocumentBasics(report, document, definition);
    if (definition.kind !== "user") return;
    auditPatientUser(
        report,
        document,
        tenant,
        basics.role,
        basics.link,
        indexes.patients,
    );
    auditStaffUser(
        report,
        document,
        tenant,
        basics.role,
        indexes.staffIndexes,
    );
    auditActiveUserClinic(report, document, tenant, indexes.clinicIndex);
  } else if (definition.kind === "patient") {
    auditPatientEntity(
        report,
        document,
        tenant,
        indexes.users,
        state.duplicateUids,
    );
  } else if (definition.kind === "patientRecord") {
    auditPatientRecord(report, document, definition, tenant, indexes);
  } else if (definition.kind === "staff") {
    auditStaffEntity(report, document, definition, tenant, indexes.users);
  }
}

function auditRootCollections(report, indexes, state) {
  for (const definition of ROOT_COLLECTIONS) {
    const documents = indexes.collections.get(definition.name);
    report.collections[definition.name].scanned = documents.length;

    for (const document of documents) {
      auditRootDocument(report, document, definition, indexes, state);
    }
  }
}

function analyzeMultiTenantData(input) {
  const normalizedInput = input || {};
  const report = initializeReport(normalizedInput);
  const indexes = buildIndexes(normalizedInput.collections || {});
  const state = {duplicateUids: new Map()};

  auditClinicMirrors(
      report,
      indexes.canonicalClinics,
      indexes.legacyClinics,
  );
  auditUserMirrors(report, indexes.users, indexes.legacyUsers);
  auditClinicOwners(report, indexes.clinicIndex.any, indexes.users);
  auditAuthentication(report, normalizedInput, indexes.users);
  auditUnknownCollections(report, normalizedInput);
  auditRootCollections(report, indexes, state);
  auditDuplicatePatientUids(report, state.duplicateUids);
  auditPatientLocks(report, indexes);
  auditStaffLocks(report, indexes, indexes.staffIndexes);

  const canonicalPaths = auditCanonicalDocuments(
      report,
      normalizedInput.canonicalDocuments || [],
      indexes,
  );
  auditCanonicalCopies(report, indexes, canonicalPaths);
  return finalizeReport(report, normalizedInput);
}

module.exports = {
  analyzeMultiTenantData,
};
