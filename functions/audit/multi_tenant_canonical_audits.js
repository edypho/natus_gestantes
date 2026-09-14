/* eslint-disable require-jsdoc, max-len */
"use strict";

const {isDeepStrictEqual} = require("node:util");

const {
  canonicalDocumentId,
  PATIENT_ID_FIELDS,
  PATIENT_UID_FIELDS,
  ROOT_COLLECTIONS,
  TECHNICAL_CANONICAL_CLINIC_COLLECTIONS,
} = require("./multi_tenant_manifest");

const {
  isMigrationQuarantined,
  inspectPatientLink,
  inspectTenant,
  inspectTextField,
  inspectUserRole,
  valueAtPath,
} = require("./multi_tenant_policy");
const {
  addIssue,
  addVirtualIssue,
  auditAliasLinkQuality,
  identifierPayload,
  normalizedStatus,
} = require("./multi_tenant_analysis_context");
const {
  auditUserDocumentBasics,
} = require("./multi_tenant_directory_audits");
const {
  auditPatientUidRelationship,
} = require("./multi_tenant_patient_audits");

const TECHNICAL_CANONICAL_COLLECTIONS = new Set(
    TECHNICAL_CANONICAL_CLINIC_COLLECTIONS,
);

function canonicalPatientId(document) {
  if (document.ancestorPatientId) return document.ancestorPatientId;
  const parts = document.path.split("/");
  const patientIndex = parts.indexOf("pacientes");
  return patientIndex >= 0 && patientIndex + 1 < parts.length ?
    parts[patientIndex + 1] : "";
}

function isCanonicalPatientParent(document) {
  const parts = document.path.split("/");
  return document.collection === "pacientes" && parts.length === 4 &&
    parts[0] === "clinicas" && parts[2] === "pacientes";
}

function canonicalCopyComparisonPaths(definition) {
  const paths = new Set([
    ...PATIENT_ID_FIELDS,
    ...PATIENT_UID_FIELDS,
    ...(definition.queryPatientIdFields || []),
  ]);
  if (definition.portalUidField) paths.add(definition.portalUidField);
  if (definition.inspectPayload) {
    for (const field of [...PATIENT_ID_FIELDS, ...PATIENT_UID_FIELDS]) {
      paths.add(`payload.${field}`);
    }
  }
  return [...paths].sort();
}

function divergentCanonicalCopyFields(definition, legacy, canonical) {
  return canonicalCopyComparisonPaths(definition).filter((path) =>
    !isDeepStrictEqual(
        valueAtPath(legacy.data, path),
        valueAtPath(canonical.data, path),
    ));
}

function auditCanonicalDocuments(report, documents, indexes) {
  const pathIndex = new Map();

  for (const input of documents || []) {
    const document = {
      collection: input.collection || "__canonical__",
      id: String(input.id || ""),
      path: String(input.path || ""),
      data: input.data && typeof input.data === "object" ? input.data : {},
      ancestorTenantId: String(input.ancestorTenantId || ""),
      ancestorPatientId: String(input.ancestorPatientId || ""),
    };
    pathIndex.set(document.path, document);
  }

  for (const document of pathIndex.values()) {
    // Journals internos sao inventariados para que o adapter continue
    // detectando filhos desconhecidos, pais orfaos e limites. O conteudo deles,
    // porem, e tecnico e deliberadamente nao carrega aliases de negocio.
    if (TECHNICAL_CANONICAL_COLLECTIONS.has(document.collection)) continue;

    const tenant = inspectTenant(document.data);

    if (!tenant.canonical || tenant.resolved !== document.ancestorTenantId) {
      addIssue(report, document, {
        severity: "critical",
        blocker: true,
        code: "TENANT_PATH_MISMATCH",
        message: "Documento canônico não pertence ao tenant do caminho.",
        identifiers: identifierPayload(tenant, null, {
          expectedTenantId: document.ancestorTenantId,
        }),
      });
    }

    const patientId = canonicalPatientId(document);
    if (patientId) {
      const link = inspectPatientLink(document.data, false);
      auditAliasLinkQuality(report, document, link);
      const canonicalId = inspectTextField(document.data, "pacienteId");
      if (!canonicalId.nonEmpty || canonicalId.value !== patientId) {
        addIssue(report, document, {
          severity: "critical",
          blocker: true,
          code: "PATIENT_PATH_MISMATCH",
          message: "Documento canônico não corresponde ao paciente do caminho.",
          identifiers: identifierPayload(tenant, link, {
            expectedPatientId: patientId,
          }),
        });
      }

      if (indexes && indexes.patients && indexes.users) {
        if (isCanonicalPatientParent(document) &&
            !indexes.patients.has(patientId)) {
          addIssue(report, document, {
            severity: "critical",
            blocker: true,
            code: "CANONICAL_PATIENT_WITHOUT_ROOT_ENTITY",
            message: "Paciente canônico não possui entidade raiz durante a migração.",
            identifiers: {
              tenantId: document.ancestorTenantId,
              patientId,
            },
          });
        }
        const patientPath =
          `clinicas/${document.ancestorTenantId}/pacientes/${patientId}`;
        const patient = pathIndex.get(patientPath) ||
          indexes.patients.get(patientId);
        if (!patient) {
          addIssue(report, document, {
            severity: "critical",
            blocker: true,
            code: "CANONICAL_PATIENT_PARENT_MISSING",
            message: "Documento canônico aponta para um paciente inexistente.",
            identifiers: identifierPayload(tenant, link, {
              expectedPatientId: patientId,
            }),
            details: {expectedPath: patientPath},
          });
        } else {
          auditPatientUidRelationship({
            report,
            document,
            tenant,
            link,
            patientId,
            patient,
            users: indexes.users,
          });
        }
      }
    }

    if (document.collection === "usuarios") {
      const basics = auditUserDocumentBasics(report, document, {kind: "user"});
      if (!indexes.users.has(document.id)) {
        addIssue(report, document, {
          severity: "critical",
          blocker: true,
          code: "CANONICAL_USER_WITHOUT_ROOT_PROFILE",
          message: "Usuário canônico não possui perfil no diretório raiz.",
          identifiers: {
            tenantId: document.ancestorTenantId,
            userUid: document.id,
          },
        });
      }
      if (["enfermeira", "obstetra", "profissional"].includes(
          basics.role.resolved,
      ) && !inspectTextField(document.data, "idVinculo").nonEmpty) {
        addIssue(report, document, {
          severity: "critical",
          blocker: true,
          code: "STAFF_USER_WITHOUT_ENTITY_ID",
          message: "Perfil profissional canônico sem entidade vinculada.",
          identifiers: {userUid: document.id},
          details: {role: basics.role.resolved},
        });
      }
      if (basics.role.resolved === "gestante" &&
          !isMigrationQuarantined(document.data) &&
          basics.link.ids.values.length !== 1) {
        addIssue(report, document, {
          severity: "critical",
          blocker: true,
          code: "PATIENT_USER_WITHOUT_PATIENT_ID",
          message: "Perfil canônico de paciente sem cadastro vinculado.",
          identifiers: {userUid: document.id},
        });
      }
    }
  }

  return pathIndex;
}

function auditUndefinedCanonicalDestinations(report, indexes) {
  for (const definition of ROOT_COLLECTIONS) {
    if (definition.canonicalDisposition !== "unresolved") continue;

    addVirtualIssue(report, {
      severity: "critical",
      blocker: true,
      code: "CANONICAL_DESTINATION_POLICY_UNDEFINED",
      collection: "__manifest__",
      path: `__manifest__/${definition.name}`,
      message: "A coleção raiz não possui política canônica aprovada.",
      details: {sourceCollection: definition.name},
    });

    for (const document of indexes.collections.get(definition.name) || []) {
      const tenant = inspectTenant(document.data);
      const link = inspectPatientLink(
          document.data,
          definition.inspectPayload,
      );
      addIssue(report, document, {
        severity: "critical",
        blocker: true,
        code: "CANONICAL_DESTINATION_UNDEFINED",
        message: "A coleção ainda não possui destino canônico aprovado.",
        identifiers: identifierPayload(tenant, link, {
          documentId: document.id,
        }),
        details: {sourceCollection: definition.name},
      });
    }
  }
}

function mappedDefinitions(scope, canonicalCollection) {
  return ROOT_COLLECTIONS.filter((definition) =>
    definition.canonicalDisposition === "mapped" &&
    definition.canonicalCopy.scope === scope &&
    definition.canonicalCopy.collection === canonicalCollection);
}

function sourceIdFromCanonical(definition, documentId, options = {}) {
  const copy = options.quarantine ?
    definition.quarantineCopy : definition.canonicalCopy;
  const prefix = copy && copy.documentIdPrefix || "";
  if (prefix && !documentId.startsWith(prefix)) return null;
  return prefix ? documentId.slice(prefix.length) : documentId;
}

function sourceMatchesCanonicalPath(source, definition, tenantId, patientId) {
  if (!source || inspectTenant(source.data).resolved !== tenantId) return false;
  if (!patientId) return true;
  const link = inspectPatientLink(source.data, definition.inspectPayload);
  return link.ids.values.length === 1 && link.ids.values[0] === patientId;
}

function reverseCopySource(document, indexes) {
  const parts = document.path.split("/");
  if (parts[0] !== "clinicas") return null;
  const tenantId = parts[1] || "";

  if (parts.length === 4) {
    const canonicalCollection = parts[2];
    const documentId = parts[3];
    if (canonicalCollection === "usuarios") {
      const source = indexes.users.get(documentId);
      return {
        sourceCollection: "usuarios",
        source,
        matches: sourceMatchesCanonicalPath(source, {}, tenantId, ""),
      };
    }
    if (canonicalCollection === "pacientes") {
      const source = indexes.patients.get(documentId);
      return {
        sourceCollection: "gestantes",
        source,
        matches: sourceMatchesCanonicalPath(source, {}, tenantId, ""),
      };
    }
    if (["planos", "biblioteca"].includes(canonicalCollection)) {
      const source = indexes.collections.get(canonicalCollection).find(
          (candidate) => candidate.id === documentId,
      );
      return {
        sourceCollection: canonicalCollection,
        source,
        matches: sourceMatchesCanonicalPath(source, {}, tenantId, ""),
      };
    }

    const directDefinitions = mappedDefinitions(
        "clinic",
        canonicalCollection,
    );
    const quarantineDefinitions = ROOT_COLLECTIONS.filter((definition) =>
      definition.quarantineCopy &&
      definition.quarantineCopy.collection === canonicalCollection);
    for (const [definition, quarantine] of [
      ...directDefinitions.map((item) => [item, false]),
      ...quarantineDefinitions.map((item) => [item, true]),
    ]) {
      const sourceId = sourceIdFromCanonical(
          definition,
          documentId,
          {quarantine},
      );
      if (sourceId === null) continue;
      const source = indexes.collections.get(definition.name).find(
          (candidate) => candidate.id === sourceId,
      );
      if (quarantine && source && !isMigrationQuarantined(source.data)) {
        continue;
      }
      return {
        sourceCollection: definition.name,
        source,
        matches: sourceMatchesCanonicalPath(source, definition, tenantId, ""),
      };
    }
    return null;
  }

  if (parts.length === 6 && parts[2] === "pacientes") {
    const patientId = parts[3];
    const canonicalCollection = parts[4];
    const documentId = parts[5];
    for (const definition of mappedDefinitions(
        "patient",
        canonicalCollection,
    )) {
      const sourceId = sourceIdFromCanonical(definition, documentId);
      if (sourceId === null) continue;
      const source = indexes.collections.get(definition.name).find(
          (candidate) => candidate.id === sourceId,
      );
      return {
        sourceCollection: definition.name,
        source,
        matches: sourceMatchesCanonicalPath(
            source,
            definition,
            tenantId,
            patientId,
        ),
      };
    }
    return null;
  }

  return null;
}

function auditCanonicalCopiesWithoutLegacySource(
    report,
    indexes,
    canonicalPaths,
) {
  for (const canonical of canonicalPaths.values()) {
    const reverse = reverseCopySource(canonical, indexes);
    if (!reverse || reverse.matches) continue;
    addIssue(report, canonical, {
      severity: "critical",
      blocker: true,
      code: "CANONICAL_COPY_WITHOUT_LEGACY_SOURCE",
      message: "Cópia canônica não possui origem legada correspondente.",
      identifiers: {
        tenantId: canonical.ancestorTenantId,
        patientId: canonical.ancestorPatientId,
        documentId: canonical.id,
      },
      details: {sourceCollection: reverse.sourceCollection},
    });
  }
}

function auditCanonicalCopies(report, indexes, canonicalPaths) {
  auditUndefinedCanonicalDestinations(report, indexes);

  for (const patient of indexes.patients.values()) {
    const tenant = inspectTenant(patient.data).resolved;
    if (!tenant) continue;
    const expectedPath = `clinicas/${tenant}/pacientes/${patient.id}`;
    const canonical = canonicalPaths.get(expectedPath);
    if (!canonical) {
      addIssue(report, patient, {
        severity: "error",
        blocker: true,
        code: "CANONICAL_COPY_MISSING",
        message: "Paciente ainda não possui cópia no caminho canônico.",
        identifiers: {tenantId: tenant, patientId: patient.id},
        details: {expectedPath},
      });
    } else {
      const legacyLink = inspectPatientLink(patient.data, false);
      const canonicalLink = inspectPatientLink(canonical.data, false);
      const differences = [];
      if (legacyLink.ids.values.join("|") !==
          canonicalLink.ids.values.join("|")) {
        differences.push("patientIds");
      }
      if (legacyLink.uids.values.join("|") !==
          canonicalLink.uids.values.join("|")) {
        differences.push("patientUids");
      }
      if (differences.length > 0) {
        addIssue(report, patient, {
          severity: "critical",
          blocker: true,
          code: "CANONICAL_COPY_DIVERGENT",
          message: "Paciente legado e cópia canônica possuem vínculos diferentes.",
          identifiers: {
            tenantId: tenant,
            patientId: patient.id,
            legacyPatientIds: legacyLink.ids.values,
            canonicalPatientIds: canonicalLink.ids.values,
            legacyPatientUids: legacyLink.uids.values,
            canonicalPatientUids: canonicalLink.uids.values,
          },
          details: {fields: differences},
        });
      }
    }
  }

  for (const user of indexes.users.values()) {
    const role = inspectUserRole(user.data).resolved;
    const tenant = inspectTenant(user.data).resolved;
    if (!tenant || role === "superAdmin") continue;
    const expectedPath = `clinicas/${tenant}/usuarios/${user.id}`;
    const canonical = canonicalPaths.get(expectedPath);
    if (!canonical) {
      addIssue(report, user, {
        severity: "error",
        blocker: true,
        code: "CANONICAL_COPY_MISSING",
        message: "Usuário ainda não possui cópia no caminho canônico.",
        identifiers: {tenantId: tenant, userUid: user.id},
        details: {expectedPath},
      });
    } else {
      const differences = [];
      const canonicalRole = inspectUserRole(canonical.data).resolved;
      const legacyStatus = normalizedStatus(user);
      const canonicalStatus = normalizedStatus(canonical);
      const legacyPatientIds = inspectPatientLink(user.data, false).ids.values;
      const canonicalPatientIds = inspectPatientLink(
          canonical.data,
          false,
      ).ids.values;
      const exactUserFields = [
        "uid",
        "uidUsuario",
        "uidProfissional",
        "uidEnfermeira",
        "uidObstetra",
        "idVinculo",
        ...PATIENT_ID_FIELDS,
        ...PATIENT_UID_FIELDS,
      ];
      if (role !== canonicalRole) differences.push("perfil");
      if (legacyStatus !== canonicalStatus) differences.push("status");
      for (const path of exactUserFields) {
        if (!isDeepStrictEqual(
            valueAtPath(user.data, path),
            valueAtPath(canonical.data, path),
        )) {
          differences.push(path);
        }
      }
      if (differences.length > 0) {
        addIssue(report, user, {
          severity: "critical",
          blocker: true,
          code: "CANONICAL_COPY_DIVERGENT",
          message: "Usuário legado e cópia canônica divergem em identidade.",
          identifiers: {
            tenantId: tenant,
            userUid: user.id,
            legacyPatientIds,
            canonicalPatientIds,
          },
          details: {
            fields: differences,
            legacyRole: role,
            canonicalRole,
            legacyStatus,
            canonicalStatus,
          },
        });
      }
    }
  }

  for (const collection of ["planos", "biblioteca"]) {
    for (const document of indexes.collections.get(collection) || []) {
      const tenant = inspectTenant(document.data).resolved;
      if (!tenant) continue;
      const expectedPath = `clinicas/${tenant}/${collection}/${document.id}`;
      if (!canonicalPaths.has(expectedPath)) {
        addIssue(report, document, {
          severity: "error",
          blocker: true,
          code: "CANONICAL_COPY_MISSING",
          message: "Catálogo ainda não possui cópia no caminho canônico.",
          identifiers: {tenantId: tenant, documentId: document.id},
          details: {expectedPath},
        });
      }
    }
  }

  for (const definition of ROOT_COLLECTIONS) {
    if (!definition.canonicalCopy) continue;
    for (const document of indexes.collections.get(definition.name) || []) {
      const tenant = inspectTenant(document.data).resolved;
      if (!tenant) continue;

      let expectedPath;
      const identifiers = {tenantId: tenant, documentId: document.id};
      const quarantined = isMigrationQuarantined(document.data);
      if (quarantined) {
        const copy = definition.quarantineCopy;
        if (!copy) {
          addIssue(report, document, {
            severity: "critical",
            blocker: true,
            code: "QUARANTINE_DESTINATION_MISSING",
            message: "Registro em quarentena não possui destino aprovado.",
            identifiers,
          });
          continue;
        }
        expectedPath = `clinicas/${tenant}/${copy.collection}/` +
          canonicalDocumentId(definition, document.id, {quarantine: true});
      } else if (definition.canonicalCopy.scope === "patient") {
        const link = inspectPatientLink(document.data, definition.inspectPayload);
        if (link.ids.values.length !== 1) continue;
        const patientId = link.ids.values[0];
        identifiers.patientId = patientId;
        expectedPath = `clinicas/${tenant}/pacientes/${patientId}/` +
          `${definition.canonicalCopy.collection}/` +
          canonicalDocumentId(definition, document.id);
      } else {
        expectedPath = `clinicas/${tenant}/` +
          `${definition.canonicalCopy.collection}/` +
          canonicalDocumentId(definition, document.id);
      }

      const canonical = canonicalPaths.get(expectedPath);
      if (!canonical) {
        addIssue(report, document, {
          severity: "critical",
          blocker: true,
          code: "CANONICAL_COPY_MISSING",
          message: "Registro legado ainda não possui cópia no caminho canônico.",
          identifiers,
          details: {expectedPath},
        });
        continue;
      }

      const differences = divergentCanonicalCopyFields(
          definition,
          document,
          canonical,
      );
      if (differences.length > 0) {
        addIssue(report, document, {
          severity: "critical",
          blocker: true,
          code: "CANONICAL_COPY_DIVERGENT",
          message: "Registro legado e cópia canônica divergem nos vínculos auditados.",
          identifiers,
          details: {fields: differences},
        });
      }
    }
  }

  auditCanonicalCopiesWithoutLegacySource(report, indexes, canonicalPaths);
}

module.exports = {
  auditCanonicalCopies,
  auditCanonicalDocuments,
};
