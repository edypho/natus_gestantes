/* eslint-disable require-jsdoc, max-len */
"use strict";

const {
  GLOBAL_ROOT_COLLECTIONS,
  ROOT_COLLECTIONS,
} = require("./multi_tenant_manifest");
const {
  inspectTenant,
  inspectUserRole,
} = require("./multi_tenant_policy");
const {
  addIssue,
  addVirtualIssue,
  auditTextGroupQuality,
  identifierPayload,
} = require("./multi_tenant_analysis_context");

function isSuperAdminUser(definition, document) {
  if (!["user", "userLegacy"].includes(definition.kind)) return false;
  return inspectUserRole(document.data).resolved === "superAdmin";
}

function auditTenant(report, document, definition, clinicIndex) {
  const tenant = inspectTenant(document.data);
  const exempt = isSuperAdminUser(definition, document);
  const stats = report.collections[definition.name];

  auditTextGroupQuality(report, document, tenant, {
    invalid: "TENANT_ALIAS_INVALID_TYPE",
    notNormalized: "TENANT_ALIAS_NOT_NORMALIZED",
  });

  if (tenant.divergent) {
    stats.tenantAliasDivergent += 1;
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "TENANT_ALIAS_DIVERGENT",
      message: "Os aliases de clínica apontam para tenants diferentes.",
      identifiers: identifierPayload(tenant),
    });
  }

  if (!exempt && tenant.missingFields.length > 0) {
    const bothMissing = tenant.missingFields.length === 2;
    stats.tenantAliasMissing += 1;
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: bothMissing ?
        "TENANT_BOTH_MISSING" : "TENANT_ONE_ALIAS_MISSING",
      message: bothMissing ?
        "Documento sem vínculo estável com uma clínica." :
        "Documento possui apenas um dos dois aliases de clínica.",
      identifiers: identifierPayload(tenant),
      details: {missingFields: tenant.missingFields},
    });
  }

  if (!exempt && definition.hardCutover && !tenant.canonical) {
    stats.hardCutoverInvisible += 1;
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "HARD_CUTOVER_INVISIBLE",
      message: "O documento ficará invisível nas consultas do app novo.",
      identifiers: identifierPayload(tenant),
    });
  }

  if (["clinic", "clinicLegacy"].includes(definition.kind) &&
      tenant.resolved && tenant.resolved !== document.id) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "TENANT_PATH_MISMATCH",
      message: "O tenant dos dados difere do ID do documento da clínica.",
      identifiers: identifierPayload(tenant, null, {
        expectedTenantId: document.id,
      }),
    });
  }

  if (!exempt && tenant.resolved &&
      !["clinic", "clinicLegacy"].includes(definition.kind)) {
    if (!clinicIndex.any.has(tenant.resolved)) {
      addIssue(report, document, {
        severity: "critical",
        blocker: true,
        code: "TENANT_NOT_FOUND",
        message: "O tenant referenciado não existe em nenhum diretório.",
        identifiers: identifierPayload(tenant),
      });
    } else if (!clinicIndex.canonical.has(tenant.resolved)) {
      addIssue(report, document, {
        severity: "error",
        blocker: true,
        code: "CANONICAL_CLINIC_MISSING",
        message: "Existe somente a clínica legada; falta a cópia canônica.",
        identifiers: identifierPayload(tenant),
      });
    }
  }

  return tenant;
}

function auditUnknownCollections(report, input) {
  const configured = new Set(ROOT_COLLECTIONS.map((item) => item.name));
  const globals = new Set(GLOBAL_ROOT_COLLECTIONS);
  for (const collection of input.rootCollections || []) {
    if (configured.has(collection) || globals.has(collection)) continue;
    addVirtualIssue(report, {
      severity: "critical",
      blocker: true,
      code: "UNKNOWN_COLLECTION",
      collection,
      path: collection,
      message: "Coleção raiz descoberta, mas ainda não modelada pelo auditor.",
    });
  }
  for (const collectionPath of input.unknownCanonicalCollections || []) {
    addVirtualIssue(report, {
      severity: "critical",
      blocker: true,
      code: "UNKNOWN_CANONICAL_COLLECTION",
      collection: "__canonical__",
      path: collectionPath,
      message: "Subcoleção canônica descoberta, mas não modelada pelo auditor.",
      identifiers: {collectionPath},
    });
  }
  for (const collectionPath of input.unknownLegacySubcollections || []) {
    addVirtualIssue(report, {
      severity: "critical",
      blocker: true,
      code: "UNKNOWN_LEGACY_SUBCOLLECTION",
      collection: "__legacy__",
      path: collectionPath,
      message: "Subcoleção legada descoberta, mas não modelada pelo auditor.",
      identifiers: {collectionPath},
    });
  }

  for (const inputParent of input.missingCanonicalParents || []) {
    const parent = inputParent && typeof inputParent === "object" ?
      inputParent : {};
    const path = String(parent.path || "__canonical__");
    const kind = ["clinic", "patient", "document"].includes(parent.kind) ?
      parent.kind : "document";
    const code = kind === "clinic" ?
      "CANONICAL_CLINIC_PARENT_MISSING" : kind === "patient" ?
        "CANONICAL_PATIENT_PARENT_MISSING" :
        "CANONICAL_DOCUMENT_PARENT_MISSING";
    const message = kind === "clinic" ?
      "Há subcoleções sob uma clínica canônica inexistente." :
      kind === "patient" ?
        "Há subcoleções sob um paciente canônico inexistente." :
        "Há subcoleções sob um documento canônico inexistente.";
    addVirtualIssue(report, {
      severity: "critical",
      blocker: true,
      code,
      collection: "__canonical__",
      path,
      message,
      identifiers: {
        ancestorTenantId: String(parent.ancestorTenantId || ""),
        ancestorPatientId: String(parent.ancestorPatientId || ""),
      },
      details: {parentKind: kind},
    });
  }
}

module.exports = {
  auditTenant,
  auditUnknownCollections,
};
