/* eslint-disable require-jsdoc, max-len */
"use strict";

const {
  PATIENT_ID_FIELDS,
  PATIENT_UID_FIELDS,
} = require("./multi_tenant_manifest");
const {
  inspectAliasGroup,
  inspectPatientLink,
  inspectTenant,
  inspectTextField,
  isMigrationQuarantined,
  inspectUserRole,
} = require("./multi_tenant_policy");
const {
  addIssue,
  auditAliasLinkQuality,
  identifierPayload,
} = require("./multi_tenant_analysis_context");

function auditPatientEntity(report, document, tenant, users, duplicateUids) {
  const link = inspectPatientLink(document.data, false);
  auditAliasLinkQuality(report, document, link);

  const canonicalId = inspectTextField(document.data, "pacienteId");
  if (!canonicalId.nonEmpty) {
    addIssue(report, document, {
      severity: "error",
      blocker: true,
      code: "PATIENT_CANONICAL_ID_MISSING",
      message: "A entidade do paciente não possui pacienteId canônico.",
      identifiers: {expectedPatientId: document.id},
    });
  }
  if (link.ids.values.length === 1 && link.ids.values[0] !== document.id) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_DOCUMENT_ID_MISMATCH",
      message: "O ID do documento difere dos aliases do paciente.",
      identifiers: identifierPayload(tenant, link, {
        expectedPatientId: document.id,
      }),
    });
  }

  if (link.uids.values.length === 1) {
    const uid = link.uids.values[0];
    if (!duplicateUids.has(uid)) duplicateUids.set(uid, []);
    duplicateUids.get(uid).push(document);

    const user = users.get(uid);
    if (!user) {
      addIssue(report, document, {
        severity: "critical",
        blocker: true,
        code: "PATIENT_UID_ORPHAN",
        message: "O paciente aponta para um perfil de usuário inexistente.",
        identifiers: identifierPayload(tenant, link),
      });
    } else {
      const userTenant = inspectTenant(user.data).resolved;
      const userRole = inspectUserRole(user.data).resolved;
      const userPatientIds = inspectPatientLink(user.data, false).ids.values;
      const mismatches = [];
      if (userTenant !== tenant.resolved) mismatches.push("tenant");
      if (userRole !== "gestante") mismatches.push("perfil");
      if (userPatientIds.length !== 1 || userPatientIds[0] !== document.id) {
        mismatches.push("pacienteId");
      }
      if (mismatches.length > 0) {
        addIssue(report, document, {
          severity: "critical",
          blocker: true,
          code: "PATIENT_ID_UID_CROSS_LINK",
          message: "Paciente e perfil de login não formam um vínculo recíproco.",
          identifiers: identifierPayload(tenant, link, {
            userTenantId: userTenant,
            userPatientIds,
          }),
          details: {fields: mismatches},
        });
      }
    }

    const portalUid = inspectTextField(document.data, "uidGestante");
    if (!portalUid.nonEmpty) {
      addIssue(report, document, {
        severity: "critical",
        blocker: true,
        code: "PATIENT_QUERY_FIELD_MISSING",
        message: "Falta uidGestante, campo exato da consulta do portal.",
        identifiers: identifierPayload(tenant, link),
        details: {field: "uidGestante"},
      });
    }
  }

  return link;
}

function userLinkedToPatient(users, patientId) {
  for (const user of users.values()) {
    const role = inspectUserRole(user.data);
    const ids = inspectPatientLink(user.data, false).ids.values;
    if (role.resolved === "gestante" && ids.includes(patientId)) return user;
  }
  return null;
}

function auditPatientUidRelationship({
  report,
  document,
  tenant,
  link,
  patientId,
  patient,
  users,
}) {
  if (link.uids.values.length !== 1) return;

  const uid = link.uids.values[0];
  const patientUids = inspectPatientLink(patient.data, false).uids.values;
  if (patientUids.length !== 1 || patientUids[0] !== uid) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_ID_UID_CROSS_LINK",
      message: "O UID do registro não pertence ao paciente informado.",
      identifiers: identifierPayload(tenant, link, {patientUids}),
      details: {fields: ["patientUid"]},
    });
  }

  const user = users.get(uid);
  if (!user) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_UID_ORPHAN",
      message: "O registro aponta para um perfil de login inexistente.",
      identifiers: identifierPayload(tenant, link),
    });
    return;
  }

  const userTenant = inspectTenant(user.data).resolved;
  const userRole = inspectUserRole(user.data).resolved;
  const userPatientIds = inspectPatientLink(user.data, false).ids.values;
  const mismatches = [];
  if (userTenant !== tenant.resolved) mismatches.push("tenant");
  if (userRole !== "gestante") mismatches.push("perfil");
  if (userPatientIds.length !== 1 || userPatientIds[0] !== patientId) {
    mismatches.push("pacienteId");
  }
  if (mismatches.length > 0) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_ID_UID_CROSS_LINK",
      message: "Registro, paciente e perfil não formam um vínculo recíproco.",
      identifiers: identifierPayload(tenant, link, {
        userTenantId: userTenant,
        userPatientIds,
      }),
      details: {fields: mismatches},
    });
  }
}

function auditPatientUser(report, document, tenant, role, link, patients) {
  if (role.resolved !== "gestante") return;

  if (isMigrationQuarantined(document.data)) {
    addIssue(report, document, {
      severity: "warning",
      blocker: false,
      code: "PATIENT_USER_QUARANTINED",
      message: "Perfil legado sem paciente foi desativado e preservado.",
      identifiers: {userUid: document.id, tenantId: tenant.resolved},
    });
    return;
  }

  if (link.ids.values.length === 0) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_USER_WITHOUT_PATIENT_ID",
      message: "O perfil de paciente não possui cadastro vinculado.",
      identifiers: {userUid: document.id},
    });
    return;
  }
  if (!inspectTextField(document.data, "pacienteId").nonEmpty) {
    addIssue(report, document, {
      severity: "error",
      blocker: true,
      code: "PATIENT_CANONICAL_ID_MISSING",
      message: "O perfil não possui pacienteId canônico.",
      identifiers: identifierPayload(tenant, link, {userUid: document.id}),
    });
  }
  if (link.uids.values.length > 0 &&
      (link.uids.values.length !== 1 || link.uids.values[0] !== document.id)) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_USER_UID_MISMATCH",
      message: "Os aliases de UID do perfil não correspondem ao documento.",
      identifiers: identifierPayload(tenant, link, {userUid: document.id}),
    });
  }
  if (link.ids.values.length !== 1) return;

  const patient = patients.get(link.ids.values[0]);
  if (!patient) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_REFERENCE_ORPHAN",
      message: "O perfil aponta para um paciente inexistente.",
      identifiers: identifierPayload(tenant, link, {userUid: document.id}),
    });
    return;
  }

  const patientTenant = inspectTenant(patient.data).resolved;
  const patientUids = inspectPatientLink(patient.data, false).uids.values;
  const mismatches = [];
  if (patientTenant !== tenant.resolved) mismatches.push("tenant");
  if (patientUids.length !== 1 || patientUids[0] !== document.id) {
    mismatches.push("uid");
  }
  if (mismatches.length > 0) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_ID_UID_CROSS_LINK",
      message: "Perfil e entidade de paciente não formam vínculo recíproco.",
      identifiers: identifierPayload(tenant, link, {
        userUid: document.id,
        patientTenantId: patientTenant,
        patientUids,
      }),
      details: {fields: mismatches},
    });
  }
}

function auditContractPayload(report, document) {
  const topIds = inspectAliasGroup(document.data, PATIENT_ID_FIELDS);
  const payloadIds = inspectAliasGroup(
      document.data,
      PATIENT_ID_FIELDS.map((field) => `payload.${field}`),
  );
  const topUids = inspectAliasGroup(document.data, PATIENT_UID_FIELDS);
  const payloadUids = inspectAliasGroup(
      document.data,
      PATIENT_UID_FIELDS.map((field) => `payload.${field}`),
  );
  const differences = [];

  if (topIds.values.length > 0 && payloadIds.values.length > 0 &&
      topIds.values.join("|") !== payloadIds.values.join("|")) {
    differences.push("patientIds");
  }
  if (topUids.values.length > 0 && payloadUids.values.length > 0 &&
      topUids.values.join("|") !== payloadUids.values.join("|")) {
    differences.push("patientUids");
  }

  if (differences.length > 0) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "CONTRACT_PAYLOAD_DIVERGENT",
      message: "O vínculo do contrato diverge entre raiz e payload.",
      identifiers: {
        topPatientIds: topIds.values,
        payloadPatientIds: payloadIds.values,
        topPatientUids: topUids.values,
        payloadPatientUids: payloadUids.values,
      },
      details: {fields: differences},
    });
  }
}

function auditPatientRecord(report, document, definition, tenant, indexes) {
  const link = inspectPatientLink(document.data, definition.inspectPayload);
  auditAliasLinkQuality(report, document, link);

  if (isMigrationQuarantined(document.data)) {
    addIssue(report, document, {
      severity: "warning",
      blocker: false,
      code: "PATIENT_RECORD_QUARANTINED",
      message: "Registro legado sem paciente resolvível foi preservado.",
      identifiers: identifierPayload(tenant, link),
      details: {sourceCollection: definition.name},
    });
    return link;
  }

  if (definition.inspectPayload) auditContractPayload(report, document);

  if (definition.patientLink === "required" && link.ids.values.length === 0) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: definition.name === "atendimentos" ?
        "PATIENT_NAME_ONLY" : "PATIENT_REFERENCE_MISSING",
      message: definition.name === "atendimentos" ?
        "Atendimento sem ID estável; não é seguro vinculá-lo só por nome." :
        "Registro de paciente sem nenhum ID estável.",
      identifiers: identifierPayload(tenant, link),
    });
  }

  if (link.ids.values.length > 0 &&
      !inspectTextField(document.data, "pacienteId").nonEmpty) {
    addIssue(report, document, {
      severity: "error",
      blocker: true,
      code: "PATIENT_CANONICAL_ID_MISSING",
      message: "O registro não possui pacienteId canônico.",
      identifiers: identifierPayload(tenant, link),
    });
  }

  for (const field of definition.queryPatientIdFields || []) {
    if (link.ids.values.length > 0 &&
        !inspectTextField(document.data, field).nonEmpty) {
      addIssue(report, document, {
        severity: "critical",
        blocker: true,
        code: "PATIENT_QUERY_FIELD_MISSING",
        message: `Falta ${field}, campo exato usado pela consulta atual.`,
        identifiers: identifierPayload(tenant, link),
        details: {field},
      });
    }
  }

  let portalFieldMissingReported = false;
  if (definition.portalUidField && link.uids.values.length > 0 &&
      !inspectTextField(document.data, definition.portalUidField).nonEmpty) {
    portalFieldMissingReported = true;
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_QUERY_FIELD_MISSING",
      message: `Falta ${definition.portalUidField}, campo exato do portal.`,
      identifiers: identifierPayload(tenant, link),
      details: {field: definition.portalUidField},
    });
  }

  if (link.ids.values.length === 0 && link.uids.values.length > 0) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_UID_WITHOUT_PATIENT_ID",
      message: "O registro possui UID de paciente sem um pacienteId estavel.",
      identifiers: identifierPayload(tenant, link),
    });
  }

  if (link.ids.values.length !== 1) return link;
  const patientId = link.ids.values[0];
  const patient = indexes.patients.get(patientId);

  if (!patient) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_REFERENCE_ORPHAN",
      message: "O registro aponta para um paciente inexistente.",
      identifiers: identifierPayload(tenant, link),
    });
    return link;
  }

  const patientTenant = inspectTenant(patient.data).resolved;
  const patientUids = inspectPatientLink(patient.data, false).uids.values;
  if (tenant.resolved && patientTenant && tenant.resolved !== patientTenant) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "PATIENT_REFERENCE_CROSS_TENANT",
      message: "Registro e paciente pertencem a clínicas diferentes.",
      identifiers: identifierPayload(tenant, link, {patientTenantId: patientTenant}),
    });
  }

  auditPatientUidRelationship({
    report,
    document,
    tenant,
    link,
    patientId,
    patient,
    users: indexes.users,
  });

  if (definition.portalUidField) {
    const linkedUser = userLinkedToPatient(indexes.users, patientId);
    const expectedPortal = patientUids.length > 0 || Boolean(linkedUser) ||
      link.uids.values.length > 0;
    const exactPortalField = inspectTextField(
        document.data,
        definition.portalUidField,
    );
    if (expectedPortal && !exactPortalField.nonEmpty &&
        !portalFieldMissingReported) {
      addIssue(report, document, {
        severity: "critical",
        blocker: true,
        code: "PATIENT_QUERY_FIELD_MISSING",
        message: `Falta ${definition.portalUidField}, campo exato do portal.`,
        identifiers: identifierPayload(tenant, link),
        details: {field: definition.portalUidField},
      });
    }
  }

  return link;
}

function auditDuplicatePatientUids(report, duplicateUids) {
  for (const [uid, documents] of duplicateUids.entries()) {
    if (documents.length < 2) continue;
    addIssue(report, documents[0], {
      severity: "critical",
      blocker: true,
      code: "PATIENT_UID_DUPLICATED",
      message: "O mesmo login está vinculado a mais de um paciente.",
      identifiers: {patientUid: uid, patientIds: documents.map((doc) => doc.id)},
      details: {count: documents.length},
    });
  }
}

function addTenantMismatch(fields, field, lockTenant, relatedTenant) {
  if (lockTenant && relatedTenant && lockTenant !== relatedTenant) {
    fields.push(field);
  }
}

function auditPatientLocks(report, indexes) {
  for (const patient of indexes.patients.values()) {
    const uids = inspectPatientLink(patient.data, false).uids.values;
    if (uids.length !== 1) continue;
    const uid = uids[0];
    const direct = indexes.patientLocksByUser.get(uid);
    const reverse = indexes.patientLocksByPatient.get(patient.id);
    if (!direct || !reverse) {
      addIssue(report, patient, {
        severity: "critical",
        blocker: true,
        code: "LOCK_ONE_SIDED",
        message: "Paciente com login não possui os dois locks de vínculo.",
        identifiers: {userUid: uid, patientId: patient.id},
        details: {
          missingDirectLock: !direct,
          missingReverseLock: !reverse,
        },
      });
    }
  }

  for (const lock of indexes.patientLocksByUser.values()) {
    const tenant = inspectTenant(lock.data);
    const uid = inspectTextField(lock.data, "uidUsuario").value;
    const patientId = inspectTextField(lock.data, "pacienteId").value;
    const user = indexes.users.get(uid);
    const patient = indexes.patients.get(patientId);
    const reverse = indexes.patientLocksByPatient.get(patientId);
    const userTenant = user ? inspectTenant(user.data).resolved : "";
    const patientTenant = patient ? inspectTenant(patient.data).resolved : "";
    const reverseTenant = reverse ? inspectTenant(reverse.data).resolved : "";
    const mismatches = [];
    if (!uid || uid !== lock.id) mismatches.push("uidUsuario");
    if (!patientId || !patient) {
      mismatches.push("pacienteId");
    }
    if (!user) mismatches.push("usuario");
    if (user) {
      const userRole = inspectUserRole(user.data).resolved;
      const userPatientIds = inspectPatientLink(
          user.data,
          false,
      ).ids.values;
      if (userRole !== "gestante") mismatches.push("userRole");
      if (userPatientIds.length !== 1 || userPatientIds[0] !== patientId) {
        mismatches.push("userPacienteId");
      }
    }
    if (patient) {
      const patientUids = inspectPatientLink(
          patient.data,
          false,
      ).uids.values;
      if (patientUids.length !== 1 || patientUids[0] !== uid) {
        mismatches.push("patientUid");
      }
    }
    if (!reverse || inspectTextField(reverse.data, "uidUsuario").value !== uid) {
      mismatches.push("lockReciproco");
    }
    addTenantMismatch(
        mismatches,
        "patientTenant",
        tenant.resolved,
        patientTenant,
    );
    addTenantMismatch(
        mismatches,
        "userTenant",
        tenant.resolved,
        userTenant,
    );
    addTenantMismatch(
        mismatches,
        "reverseLockTenant",
        tenant.resolved,
        reverseTenant,
    );
    if (mismatches.length > 0) {
      addIssue(report, lock, {
        severity: "critical",
        blocker: true,
        code: "LOCK_DIVERGENT",
        message: "Lock de paciente sem referências recíprocas e coerentes.",
        identifiers: {
          userUid: uid,
          patientId,
          directLockTenantId: tenant.resolved,
          reverseLockTenantId: reverseTenant,
          patientTenantId: patientTenant,
          userTenantId: userTenant,
        },
        details: {fields: mismatches},
      });
    }
  }

  for (const lock of indexes.patientLocksByPatient.values()) {
    const tenant = inspectTenant(lock.data);
    const uid = inspectTextField(lock.data, "uidUsuario").value;
    const patientId = inspectTextField(lock.data, "pacienteId").value || lock.id;
    const direct = indexes.patientLocksByUser.get(uid);
    if (lock.id !== patientId || !direct ||
        inspectTextField(direct.data, "pacienteId").value !== patientId) {
      addIssue(report, lock, {
        severity: "critical",
        blocker: true,
        code: "LOCK_ONE_SIDED",
        message: "Lock reverso de paciente ausente ou incompatível.",
        identifiers: {userUid: uid, patientId, lockDocumentId: lock.id},
      });
    }

    const user = indexes.users.get(uid);
    const patient = indexes.patients.get(patientId);
    const directTenant = direct ? inspectTenant(direct.data).resolved : "";
    const userTenant = user ? inspectTenant(user.data).resolved : "";
    const patientTenant = patient ? inspectTenant(patient.data).resolved : "";
    const tenantMismatches = [];
    if (user) {
      const userRole = inspectUserRole(user.data).resolved;
      const userPatientIds = inspectPatientLink(
          user.data,
          false,
      ).ids.values;
      if (userRole !== "gestante") tenantMismatches.push("userRole");
      if (userPatientIds.length !== 1 || userPatientIds[0] !== patientId) {
        tenantMismatches.push("userPacienteId");
      }
    }
    if (patient) {
      const patientUids = inspectPatientLink(
          patient.data,
          false,
      ).uids.values;
      if (patientUids.length !== 1 || patientUids[0] !== uid) {
        tenantMismatches.push("patientUid");
      }
    }
    addTenantMismatch(
        tenantMismatches,
        "directLockTenant",
        tenant.resolved,
        directTenant,
    );
    addTenantMismatch(
        tenantMismatches,
        "patientTenant",
        tenant.resolved,
        patientTenant,
    );
    addTenantMismatch(
        tenantMismatches,
        "userTenant",
        tenant.resolved,
        userTenant,
    );
    if (tenantMismatches.length > 0) {
      addIssue(report, lock, {
        severity: "critical",
        blocker: true,
        code: "LOCK_DIVERGENT",
        message: "Lock reverso de paciente pertence a outro tenant.",
        identifiers: {
          userUid: uid,
          patientId,
          reverseLockTenantId: tenant.resolved,
          directLockTenantId: directTenant,
          patientTenantId: patientTenant,
          userTenantId: userTenant,
        },
        details: {fields: tenantMismatches},
      });
    }
  }
}

module.exports = {
  auditDuplicatePatientUids,
  auditPatientEntity,
  auditPatientLocks,
  auditPatientRecord,
  auditPatientUidRelationship,
  auditPatientUser,
};
