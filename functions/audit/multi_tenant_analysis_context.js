/* eslint-disable require-jsdoc, max-len */
"use strict";

const {ROOT_COLLECTIONS} = require("./multi_tenant_manifest");
const {
  inspectTextField,
} = require("./multi_tenant_policy");

const SEVERITY_ORDER = {critical: 0, error: 1, warning: 2, info: 3};

function asDocument(collection, input) {
  const id = String(input && input.id || "").trim();
  return {
    collection,
    id,
    path: String(input && input.path || `${collection}/${id}`),
    data: input && input.data && typeof input.data === "object" ?
      input.data : {},
  };
}

function documentsFor(collections, name) {
  const values = collections && Array.isArray(collections[name]) ?
    collections[name] : [];
  return values.map((value) => asDocument(name, value));
}

function indexById(documents) {
  return new Map(documents.map((document) => [document.id, document]));
}

function issueLocation(document) {
  return {
    collection: document.collection,
    path: document.path,
  };
}

function addIssue(report, document, options) {
  const issue = {
    severity: options.severity,
    blocker: options.blocker === true,
    code: options.code,
    location: issueLocation(document),
    message: options.message,
    identifiers: options.identifiers || {},
    details: options.details || {},
  };
  report.findings.push(issue);
}

function addVirtualIssue(report, options) {
  addIssue(report, {
    collection: options.collection || "__audit__",
    path: options.path || "__audit__",
  }, options);
}

function identifierPayload(tenant, patientLink, extra) {
  const identifiers = {...(extra || {})};

  if (tenant) {
    if (tenant.clinicaId) identifiers.clinicaId = tenant.clinicaId;
    if (tenant.adminDonoId) identifiers.adminDonoId = tenant.adminDonoId;
  }
  if (patientLink) {
    if (patientLink.ids.values.length > 0) {
      identifiers.patientIds = patientLink.ids.values;
    }
    if (patientLink.uids.values.length > 0) {
      identifiers.patientUids = patientLink.uids.values;
    }
  }

  return identifiers;
}

function normalizedStatus(document) {
  const status = inspectTextField(document.data, "status");
  return status.validType ? status.value.toLowerCase() : "";
}

function auditTextGroupQuality(report, document, group, codes) {
  if (group.invalidFields.length > 0) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: codes.invalid,
      message: "Há alias com tipo inválido; o acesso deve falhar fechado.",
      details: {fields: group.invalidFields},
    });
  }
  if (group.notNormalizedFields.length > 0) {
    addIssue(report, document, {
      severity: "error",
      blocker: true,
      code: codes.notNormalized,
      message: "Há alias com espaços externos e valor não normalizado.",
      details: {fields: group.notNormalizedFields},
    });
  }
}

function auditAliasLinkQuality(report, document, patientLink) {
  auditTextGroupQuality(report, document, patientLink.ids, {
    invalid: "PATIENT_ID_ALIAS_INVALID_TYPE",
    notNormalized: "PATIENT_ID_ALIAS_NOT_NORMALIZED",
  });
  auditTextGroupQuality(report, document, patientLink.uids, {
    invalid: "PATIENT_UID_ALIAS_INVALID_TYPE",
    notNormalized: "PATIENT_UID_ALIAS_NOT_NORMALIZED",
  });

  if (patientLink.ids.values.length > 1) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_ID_ALIAS_DIVERGENT",
      message: "Os aliases de ID apontam para pacientes diferentes.",
      identifiers: identifierPayload(null, patientLink),
    });
  }
  if (patientLink.uids.values.length > 1) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_UID_ALIAS_DIVERGENT",
      message: "Os aliases de UID apontam para logins diferentes.",
      identifiers: identifierPayload(null, patientLink),
    });
  }
}

function initializeReport(input) {
  const report = {
    schemaVersion: "1.0.0",
    generatedAt: input.generatedAt || new Date().toISOString(),
    source: input.source || {},
    scan: input.scan || {},
    complete: Boolean(input.scan && input.scan.complete === true),
    collections: {},
    findings: [],
    summary: {},
  };

  for (const definition of ROOT_COLLECTIONS) {
    report.collections[definition.name] = {
      scanned: 0,
      tenantAliasMissing: 0,
      tenantAliasDivergent: 0,
      hardCutoverInvisible: 0,
      truncated: Boolean(input.scan && input.scan.truncatedCollections &&
        input.scan.truncatedCollections.includes(definition.name)),
    };
  }
  return report;
}

function buildIndexes(collections) {
  const all = new Map();
  for (const definition of ROOT_COLLECTIONS) {
    all.set(definition.name, documentsFor(collections, definition.name));
  }
  const canonicalClinics = indexById(all.get("clinicas"));
  const legacyClinics = indexById(all.get("clinicasSaaS"));
  return {
    collections: all,
    canonicalClinics,
    legacyClinics,
    clinicIndex: {
      canonical: canonicalClinics,
      legacy: legacyClinics,
      any: new Map([...legacyClinics, ...canonicalClinics]),
    },
    users: indexById(all.get("usuarios")),
    legacyUsers: indexById(all.get("usuariosSaaS")),
    patients: indexById(all.get("gestantes")),
    patientLocksByUser: indexById(all.get("vinculosAuthPaciente")),
    patientLocksByPatient: indexById(all.get("vinculosPacienteAuth")),
    staffLocksByUser: indexById(all.get("vinculosAuthEntidade")),
    staffLocksByEntity: indexById(all.get("vinculosEntidadeAuth")),
    staffIndexes: {
      enfermeiras: indexById(all.get("enfermeiras")),
      obstetras: indexById(all.get("obstetras")),
      profissionais: indexById(all.get("profissionais")),
    },
  };
}

function finalizeReport(report, input) {
  const hasRootDocuments = Object.values(report.collections)
      .some((stats) => stats.scanned > 0);
  const hasCanonicalDocuments = Array.isArray(input.canonicalDocuments) &&
    input.canonicalDocuments.length > 0;
  const hasAuthenticationUsers = Array.isArray(input.authUsers) &&
    input.authUsers.length > 0;
  if (!hasRootDocuments && !hasCanonicalDocuments &&
      !hasAuthenticationUsers) {
    addVirtualIssue(report, {
      severity: "critical",
      blocker: true,
      code: "AUDIT_EMPTY",
      message: "Nenhum documento ou conta foi encontrado no alvo auditado.",
      details: {
        authIncluded: Array.isArray(input.authUsers),
      },
    });
  }

  if (!report.complete) {
    addVirtualIssue(report, {
      severity: "critical",
      blocker: true,
      code: "AUDIT_INCOMPLETE",
      message: "A varredura foi truncada ou não percorreu toda a hierarquia.",
      details: {
        truncatedCollections: input.scan &&
          input.scan.truncatedCollections || [],
        depthLimitReached: Boolean(input.scan && input.scan.depthLimitReached),
      },
    });
  }

  report.findings.sort((left, right) => {
    const severity = SEVERITY_ORDER[left.severity] -
      SEVERITY_ORDER[right.severity];
    if (severity !== 0) return severity;
    const code = left.code.localeCompare(right.code);
    if (code !== 0) return code;
    return left.location.path.localeCompare(right.location.path);
  });

  const bySeverity = {critical: 0, error: 0, warning: 0, info: 0};
  const byCode = {};
  let blockers = 0;
  let scannedDocuments = 0;

  for (const finding of report.findings) {
    bySeverity[finding.severity] += 1;
    byCode[finding.code] = (byCode[finding.code] || 0) + 1;
    if (finding.blocker) blockers += 1;
  }
  for (const stats of Object.values(report.collections)) {
    scannedDocuments += stats.scanned;
  }

  report.summary = {
    scannedRootDocuments: scannedDocuments,
    scannedCanonicalDocuments: (input.canonicalDocuments || []).length,
    totalFindings: report.findings.length,
    blockers,
    bySeverity,
    byCode,
    releaseReady: report.complete && blockers === 0,
  };
  return report;
}

module.exports = {
  addIssue,
  addVirtualIssue,
  auditAliasLinkQuality,
  auditTextGroupQuality,
  buildIndexes,
  finalizeReport,
  identifierPayload,
  initializeReport,
  normalizedStatus,
};
