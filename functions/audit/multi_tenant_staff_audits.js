/* eslint-disable require-jsdoc, max-len */
"use strict";

const {
  inspectAliasGroup,
  inspectTextField,
  inspectTenant,
  inspectUserRole,
  isMigrationQuarantined,
  normalizeRole,
} = require("./multi_tenant_policy");
const {
  addIssue,
  auditTextGroupQuality,
} = require("./multi_tenant_analysis_context");

function auditStaffEntity(report, document, definition, tenant, users) {
  if (isMigrationQuarantined(document.data)) {
    addIssue(report, document, {
      severity: "warning",
      blocker: false,
      code: "STAFF_ENTITY_QUARANTINED",
      message: "Entidade profissional divergente foi preservada e desativada.",
      identifiers: {tenantId: tenant.resolved},
    });
    return;
  }
  const group = inspectAliasGroup(document.data, definition.staffUidFields);
  auditTextGroupQuality(report, document, group, {
    invalid: "STAFF_UID_INVALID_TYPE",
    notNormalized: "STAFF_UID_NOT_NORMALIZED",
  });
  if (group.values.length > 1) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "STAFF_UID_ALIAS_DIVERGENT",
      message: "A entidade profissional aponta para logins diferentes.",
      identifiers: {staffUids: group.values},
    });
    return;
  }
  if (group.values.length === 0) return;

  const uid = group.values[0];
  const user = users.get(uid);
  if (!user) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "STAFF_ENTITY_ORPHAN",
      message: "A entidade profissional aponta para usuário inexistente.",
      identifiers: {staffUid: uid, tenantId: tenant.resolved},
    });
    return;
  }

  const userTenant = inspectTenant(user.data).resolved;
  const userRole = inspectUserRole(user.data).resolved;
  const userLink = inspectTextField(user.data, "idVinculo").value;
  const mismatches = [];
  if (userTenant !== tenant.resolved) mismatches.push("tenant");
  if (!definition.expectedRoles.includes(userRole)) mismatches.push("perfil");
  if (userLink && userLink !== document.id) mismatches.push("idVinculo");

  if (mismatches.length > 0) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "STAFF_ENTITY_LINK_DIVERGENT",
      message: "Entidade e perfil profissional não formam vínculo coerente.",
      identifiers: {
        staffUid: uid,
        entityId: document.id,
        entityTenantId: tenant.resolved,
        userTenantId: userTenant,
        userEntityId: userLink,
      },
      details: {fields: mismatches},
    });
  }
}

function expectedStaffEntity(role, id, staffIndexes) {
  if (role === "enfermeira") return staffIndexes.enfermeiras.get(id);
  if (role === "obstetra") return staffIndexes.obstetras.get(id);
  if (role === "profissional") return staffIndexes.profissionais.get(id);
  return null;
}

function staffUidFields(role) {
  if (role === "enfermeira") return ["uidEnfermeira", "uidProfissional"];
  if (role === "obstetra") return ["uidObstetra", "uidProfissional"];
  if (role === "profissional") return ["uidProfissional"];
  return [];
}

function auditStaffUser(report, document, tenant, role, staffIndexes) {
  if (!["enfermeira", "obstetra", "profissional"].includes(role.resolved)) {
    return;
  }

  const entityId = inspectTextField(document.data, "idVinculo").value;
  if (!entityId) {
    addIssue(report, document, {
      severity: role.resolved === "profissional" ? "error" : "critical",
      blocker: true,
      code: "STAFF_USER_WITHOUT_ENTITY_ID",
      message: "Perfil profissional sem entidade clínica vinculada.",
      identifiers: {userUid: document.id, tenantId: tenant.resolved},
      details: {role: role.resolved},
    });
    return;
  }

  const entity = expectedStaffEntity(role.resolved, entityId, staffIndexes);
  if (!entity) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "STAFF_ENTITY_ORPHAN",
      message: "O perfil aponta para uma entidade profissional inexistente.",
      identifiers: {
        userUid: document.id,
        tenantId: tenant.resolved,
        entityId,
      },
      details: {role: role.resolved},
    });
    return;
  }

  const entityTenant = inspectTenant(entity.data).resolved;
  const entityUids = inspectAliasGroup(
      entity.data,
      staffUidFields(role.resolved),
  ).values;
  const mismatches = [];
  if (entityTenant !== tenant.resolved) mismatches.push("tenant");
  if (entityUids.length !== 1 || entityUids[0] !== document.id) {
    mismatches.push("uid");
  }
  if (mismatches.length > 0) {
    addIssue(report, document, {
      severity: "critical",
      blocker: true,
      code: "STAFF_ENTITY_LINK_DIVERGENT",
      message: "Perfil e entidade profissional não formam vínculo recíproco.",
      identifiers: {
        userUid: document.id,
        entityId,
        userTenantId: tenant.resolved,
        entityTenantId: entityTenant,
        entityUids,
      },
      details: {fields: mismatches, role: role.resolved},
    });
  }
}

function addTenantMismatch(fields, field, lockTenant, relatedTenant) {
  if (lockTenant && relatedTenant && lockTenant !== relatedTenant) {
    fields.push(field);
  }
}

function auditStaffLocks(report, indexes, staffIndexes) {
  const staffGroups = [
    ["enfermeira", staffIndexes.enfermeiras, [
      "uidEnfermeira",
      "uidProfissional",
    ]],
    ["obstetra", staffIndexes.obstetras, [
      "uidObstetra",
      "uidProfissional",
    ]],
    ["profissional", staffIndexes.profissionais, ["uidProfissional"]],
  ];
  for (const [role, entities, uidFields] of staffGroups) {
    for (const entity of entities.values()) {
      if (isMigrationQuarantined(entity.data)) continue;
      const uids = inspectAliasGroup(entity.data, uidFields).values;
      if (uids.length !== 1) continue;
      const uid = uids[0];
      const direct = indexes.staffLocksByUser.get(uid);
      const reverse = indexes.staffLocksByEntity.get(`${role}_${entity.id}`);
      if (!direct || !reverse) {
        addIssue(report, entity, {
          severity: "critical",
          blocker: true,
          code: "LOCK_ONE_SIDED",
          message: "Profissional com login não possui os dois locks de vínculo.",
          identifiers: {userUid: uid, entityId: entity.id, role},
          details: {
            missingDirectLock: !direct,
            missingReverseLock: !reverse,
          },
        });
      }
    }
  }

  for (const lock of indexes.staffLocksByUser.values()) {
    const tenant = inspectTenant(lock.data);
    const uid = inspectTextField(lock.data, "uidUsuario").value;
    const role = normalizeRole(inspectTextField(lock.data, "tipoUsuario").value);
    const entityId = inspectTextField(lock.data, "idVinculo").value;
    const reverseId = `${role}_${entityId}`;
    const reverse = indexes.staffLocksByEntity.get(reverseId);
    const entity = expectedStaffEntity(role, entityId, staffIndexes);
    const user = indexes.users.get(uid);
    const reverseTenant = reverse ? inspectTenant(reverse.data).resolved : "";
    const entityTenant = entity ? inspectTenant(entity.data).resolved : "";
    const userTenant = user ? inspectTenant(user.data).resolved : "";
    const mismatches = [];

    if (!uid || uid !== lock.id) mismatches.push("uidUsuario");
    if (!user) mismatches.push("usuario");
    if (!entity) mismatches.push("entidade");
    if (user) {
      const userRole = inspectUserRole(user.data).resolved;
      const userEntityId = inspectTextField(user.data, "idVinculo").value;
      if (userRole !== role) mismatches.push("userRole");
      if (!userEntityId || userEntityId !== entityId) {
        mismatches.push("userIdVinculo");
      }
    }
    if (entity) {
      const entityUids = inspectAliasGroup(
          entity.data,
          staffUidFields(role),
      ).values;
      if (entityUids.length !== 1 || entityUids[0] !== uid) {
        mismatches.push("entityUid");
      }
    }
    if (!reverse || inspectTextField(reverse.data, "uidUsuario").value !== uid) {
      mismatches.push("lockReciproco");
    }
    addTenantMismatch(
        mismatches,
        "reverseLockTenant",
        tenant.resolved,
        reverseTenant,
    );
    addTenantMismatch(
        mismatches,
        "entityTenant",
        tenant.resolved,
        entityTenant,
    );
    addTenantMismatch(
        mismatches,
        "userTenant",
        tenant.resolved,
        userTenant,
    );
    if (mismatches.length > 0) {
      addIssue(report, lock, {
        severity: "critical",
        blocker: true,
        code: "LOCK_DIVERGENT",
        message: "Lock profissional sem referências recíprocas e coerentes.",
        identifiers: {
          userUid: uid,
          entityId,
          role,
          directLockTenantId: tenant.resolved,
          reverseLockTenantId: reverseTenant,
          entityTenantId: entityTenant,
          userTenantId: userTenant,
        },
        details: {fields: mismatches},
      });
    }
  }

  for (const lock of indexes.staffLocksByEntity.values()) {
    const tenant = inspectTenant(lock.data);
    const uid = inspectTextField(lock.data, "uidUsuario").value;
    const role = normalizeRole(inspectTextField(lock.data, "tipoUsuario").value);
    const entityId = inspectTextField(lock.data, "idVinculo").value;
    const expectedId = `${role}_${entityId}`;
    const direct = indexes.staffLocksByUser.get(uid);
    if (lock.id !== expectedId || !direct ||
        inspectTextField(direct.data, "idVinculo").value !== entityId) {
      addIssue(report, lock, {
        severity: "critical",
        blocker: true,
        code: "LOCK_ONE_SIDED",
        message: "Lock reverso profissional ausente ou incompatível.",
        identifiers: {userUid: uid, entityId, role, lockDocumentId: lock.id},
      });
    }

    const entity = expectedStaffEntity(role, entityId, staffIndexes);
    const user = indexes.users.get(uid);
    const directTenant = direct ? inspectTenant(direct.data).resolved : "";
    const entityTenant = entity ? inspectTenant(entity.data).resolved : "";
    const userTenant = user ? inspectTenant(user.data).resolved : "";
    const tenantMismatches = [];
    if (user) {
      const userRole = inspectUserRole(user.data).resolved;
      const userEntityId = inspectTextField(user.data, "idVinculo").value;
      if (userRole !== role) tenantMismatches.push("userRole");
      if (!userEntityId || userEntityId !== entityId) {
        tenantMismatches.push("userIdVinculo");
      }
    }
    if (entity) {
      const entityUids = inspectAliasGroup(
          entity.data,
          staffUidFields(role),
      ).values;
      if (entityUids.length !== 1 || entityUids[0] !== uid) {
        tenantMismatches.push("entityUid");
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
        "entityTenant",
        tenant.resolved,
        entityTenant,
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
        message: "Lock reverso profissional pertence a outro tenant.",
        identifiers: {
          userUid: uid,
          entityId,
          role,
          reverseLockTenantId: tenant.resolved,
          directLockTenantId: directTenant,
          entityTenantId: entityTenant,
          userTenantId: userTenant,
        },
        details: {fields: tenantMismatches},
      });
    }
  }
}

module.exports = {
  auditStaffEntity,
  auditStaffLocks,
  auditStaffUser,
};
