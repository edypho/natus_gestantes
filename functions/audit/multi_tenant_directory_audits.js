/* eslint-disable require-jsdoc, max-len */
"use strict";

const {
  inspectPatientLink,
  inspectTenant,
  inspectTextField,
  inspectUserRole,
} = require("./multi_tenant_policy");
const {
  addIssue,
  addVirtualIssue,
  auditAliasLinkQuality,
  normalizedStatus,
} = require("./multi_tenant_analysis_context");

const KNOWN_CLINIC_STATUSES = new Set([
  "ativa",
  "teste",
  "pausada",
  "bloqueada",
  "excluida",
]);
const KNOWN_USER_STATUSES = new Set(["ativo", "inativo", "bloqueado"]);
const ACTIVE_CLINIC_STATUSES = new Set(["ativa", "teste"]);

function auditStatusField(report, document, options) {
  const state = inspectTextField(document.data, "status");
  const normalized = state.validType ? state.value.toLowerCase() : "";
  if (state.validType && state.nonEmpty && !state.notNormalized &&
      options.allowed.has(normalized)) {
    return normalized;
  }

  addIssue(report, document, {
    severity: "critical",
    blocker: true,
    code: options.code,
    message: options.message,
    details: {
      field: "status",
      reason: !state.exists ? "missing" :
        (!state.validType ? "invalid_type" :
          (state.notNormalized ? "not_normalized" : "unknown_value")),
      status: normalized,
    },
  });
  return normalized;
}

function auditClinicDocumentBasics(report, document) {
  return auditStatusField(report, document, {
    allowed: KNOWN_CLINIC_STATUSES,
    code: "CLINIC_STATUS_INVALID",
    message: "A clínica não possui um status conhecido e normalizado.",
  });
}

function auditClinicMirrors(report, canonicalClinics, legacyClinics) {
  const allIds = new Set([
    ...canonicalClinics.keys(),
    ...legacyClinics.keys(),
  ]);

  for (const id of allIds) {
    const canonical = canonicalClinics.get(id);
    const legacy = legacyClinics.get(id);

    if (!canonical) {
      addIssue(report, legacy, {
        severity: "critical",
        blocker: true,
        code: "CANONICAL_CLINIC_MISSING",
        message: "A clínica existe apenas no diretório legado.",
        identifiers: {tenantId: id},
      });
      continue;
    }
    if (!legacy) {
      addIssue(report, canonical, {
        severity: "warning",
        blocker: false,
        code: "CLINIC_MIRROR_MISSING",
        message: "A clínica canônica não possui espelho legado.",
        identifiers: {tenantId: id},
      });
      continue;
    }

    const differences = [];
    const canonicalStatus = normalizedStatus(canonical);
    const legacyStatus = normalizedStatus(legacy);
    const canonicalAdmin = inspectTextField(canonical.data, "adminUid").value;
    const legacyAdmin = inspectTextField(legacy.data, "adminUid").value;

    if (canonicalStatus !== legacyStatus) differences.push("status");
    if (canonicalAdmin !== legacyAdmin) differences.push("adminUid");

    if (differences.length > 0) {
      addIssue(report, canonical, {
        severity: "critical",
        blocker: true,
        code: "CLINIC_MIRROR_DIVERGENT",
        message: "Os diretórios canônico e legado da clínica divergem.",
        identifiers: {
          tenantId: id,
          canonicalAdminUid: canonicalAdmin,
          legacyAdminUid: legacyAdmin,
        },
        details: {
          fields: differences,
          canonicalStatus,
          legacyStatus,
        },
      });
    }
  }
}

function auditClinicOwners(report, clinicIndex, users) {
  for (const [tenantId, clinic] of clinicIndex.entries()) {
    const adminUid = inspectTextField(clinic.data, "adminUid").value;
    if (!adminUid) {
      addIssue(report, clinic, {
        severity: "critical",
        blocker: true,
        code: "CLINIC_OWNER_MISSING",
        message: "A clínica não possui um administrador proprietário.",
        identifiers: {tenantId},
      });
      continue;
    }

    const owner = users.get(adminUid);
    if (!owner) {
      addIssue(report, clinic, {
        severity: "critical",
        blocker: true,
        code: "CLINIC_OWNER_ORPHAN",
        message: "O proprietário da clínica não possui perfil canônico.",
        identifiers: {tenantId, adminUid},
      });
      continue;
    }

    const ownerTenant = inspectTenant(owner.data).resolved;
    const ownerRole = inspectUserRole(owner.data).resolved;
    const ownerStatus = normalizedStatus(owner);
    if (ownerTenant !== tenantId || ownerRole !== "admin") {
      addIssue(report, clinic, {
        severity: "critical",
        blocker: true,
        code: "CLINIC_OWNER_DIVERGENT",
        message: "O proprietário não é admin da própria clínica.",
        identifiers: {tenantId, adminUid, ownerTenantId: ownerTenant},
        details: {ownerRole},
      });
    }
    if (ACTIVE_CLINIC_STATUSES.has(normalizedStatus(clinic)) &&
        ownerStatus !== "ativo") {
      addIssue(report, clinic, {
        severity: "critical",
        blocker: true,
        code: "CLINIC_OWNER_INACTIVE",
        message: "A clínica ativa não possui proprietário com acesso ativo.",
        identifiers: {tenantId, adminUid},
        details: {ownerStatus},
      });
    }
  }
}

function auditUserDocumentBasics(report, document, definition) {
  const uidField = inspectTextField(document.data, "uid");
  const role = inspectUserRole(document.data);
  const link = inspectPatientLink(document.data, false);

  auditStatusField(report, document, {
    allowed: KNOWN_USER_STATUSES,
    code: "USER_STATUS_INVALID",
    message: "O usuário não possui um status conhecido e normalizado.",
  });

  if (!uidField.nonEmpty) {
    addIssue(report, document, {
      severity: "error",
      blocker: definition.kind === "user",
      code: "USER_UID_FIELD_MISSING",
      message: "O diretório de usuário não registra o próprio UID.",
      identifiers: {expectedUserUid: document.id},
    });
  } else if (uidField.value !== document.id) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "USER_DOC_UID_MISMATCH",
      message: "O campo uid difere do ID do documento do usuário.",
      identifiers: {documentUid: document.id, storedUid: uidField.value},
    });
  }

  if (role.invalidFields.length > 0) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "USER_ROLE_INVALID_TYPE",
      message: "Há alias de perfil com tipo inválido.",
      details: {fields: role.invalidFields},
    });
  }
  if (role.notNormalizedFields.length > 0) {
    addIssue(report, document, {
      severity: "error",
      blocker: true,
      code: "USER_ROLE_NOT_NORMALIZED",
      message: "Há alias de perfil com espaços externos.",
      details: {fields: role.notNormalizedFields},
    });
  }
  if (role.divergent) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "USER_ROLE_ALIAS_DIVERGENT",
      message: "tipo e tipoUsuario representam perfis diferentes.",
      details: {tipo: role.tipo, tipoUsuario: role.tipoUsuario},
    });
  } else if (!role.known) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "USER_UNKNOWN_ROLE",
      message: "O usuário não possui um perfil conhecido e consistente.",
    });
  }

  auditAliasLinkQuality(report, document, link);
  return {link, role};
}

function auditUserMirrors(report, users, legacyUsers) {
  const allUids = new Set([...users.keys(), ...legacyUsers.keys()]);

  for (const uid of allUids) {
    const canonical = users.get(uid);
    const legacy = legacyUsers.get(uid);

    if (!canonical) {
      addIssue(report, legacy, {
        severity: "critical",
        blocker: true,
        code: "USER_CANONICAL_PROFILE_MISSING",
        message: "Há usuário legado sem perfil canônico para o AuthGate.",
        identifiers: {userUid: uid},
      });
      continue;
    }
    if (!legacy) continue;

    const canonicalTenant = inspectTenant(canonical.data).resolved;
    const legacyTenant = inspectTenant(legacy.data).resolved;
    const canonicalRole = inspectUserRole(canonical.data).resolved;
    const legacyRole = inspectUserRole(legacy.data).resolved;
    const canonicalPatient = inspectPatientLink(canonical.data, false)
        .ids.values.join("|");
    const legacyPatient = inspectPatientLink(legacy.data, false)
        .ids.values.join("|");
    const differences = [];

    if (canonicalTenant !== legacyTenant) differences.push("tenant");
    if (canonicalRole !== legacyRole) differences.push("perfil");
    if (normalizedStatus(canonical) !== normalizedStatus(legacy)) {
      differences.push("status");
    }
    if (canonicalPatient !== legacyPatient) differences.push("pacienteId");

    if (differences.length > 0) {
      addIssue(report, canonical, {
        severity: "critical",
        blocker: true,
        code: "USER_MIRROR_DIVERGENT",
        message: "Os diretórios de usuário divergem em identidade ou acesso.",
        identifiers: {
          userUid: uid,
          canonicalTenantId: canonicalTenant,
          legacyTenantId: legacyTenant,
          canonicalPatientId: canonicalPatient,
          legacyPatientId: legacyPatient,
        },
        details: {fields: differences},
      });
    }
  }
}

function auditAuthentication(report, input, users) {
  if (!Array.isArray(input.authUsers)) {
    addVirtualIssue(report, {
      severity: "critical",
      blocker: true,
      code: "AUTH_AUDIT_SKIPPED",
      collection: "firebaseAuth",
      path: "firebaseAuth",
      message: "O Firebase Auth não foi incluído nesta auditoria.",
      details: {authIncluded: false},
    });
    return;
  }

  const authUsers = new Map(input.authUsers.map((user) => [
    String(user.uid || ""),
    user,
  ]));

  for (const user of users.values()) {
    const authUser = authUsers.get(user.id);
    if (!authUser) {
      addIssue(report, user, {
        severity: "critical",
        blocker: true,
        code: "USER_WITHOUT_AUTH",
        message: "O perfil canônico não possui conta no Firebase Auth.",
        identifiers: {userUid: user.id},
      });
      continue;
    }

    const role = inspectUserRole(user.data).resolved;
    const claim = Boolean(authUser.superAdmin);
    if ((role === "superAdmin") !== claim) {
      addIssue(report, user, {
        severity: "critical",
        blocker: true,
        code: "SUPERADMIN_CLAIM_MISMATCH",
        message: "Perfil e custom claim de SuperAdmin são incompatíveis.",
        identifiers: {userUid: user.id},
        details: {profileIsSuperAdmin: role === "superAdmin", claim},
      });
    }
    if (normalizedStatus(user) === "ativo" && authUser.disabled === true) {
      addIssue(report, user, {
        severity: "error",
        blocker: true,
        code: "ACTIVE_USER_DISABLED_IN_AUTH",
        message: "Usuário ativo no Firestore está desabilitado no Auth.",
        identifiers: {userUid: user.id},
      });
    }
  }

  for (const authUser of authUsers.values()) {
    const uid = String(authUser.uid || "");
    if (!users.has(uid)) {
      addVirtualIssue(report, {
        severity: "warning",
        blocker: false,
        code: authUser.disabled === true ?
          "DISABLED_AUTH_WITHOUT_USER_PROFILE" :
          "AUTH_WITHOUT_USER_PROFILE",
        collection: "firebaseAuth",
        path: `firebaseAuth/${uid}`,
        message: authUser.disabled === true ?
          "Conta Auth órfã está desativada e não concede acesso." :
          "Conta Auth ativa sem perfil do app; pode pertencer a outro produto " +
            "e não recebe acesso clínico sem perfil válido.",
        identifiers: {userUid: uid},
      });
    }
  }
}

module.exports = {
  auditAuthentication,
  auditClinicDocumentBasics,
  auditClinicMirrors,
  auditClinicOwners,
  auditUserDocumentBasics,
  auditUserMirrors,
};
