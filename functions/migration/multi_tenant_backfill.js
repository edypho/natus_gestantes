/* eslint-disable require-jsdoc, max-len */
"use strict";

const {
  canonicalDocumentId,
  PATIENT_ID_FIELDS,
  PATIENT_UID_FIELDS,
  ROOT_COLLECTIONS,
} = require("../audit/multi_tenant_manifest");
const {
  inspectPatientLink,
  inspectTenant,
  inspectUserRole,
} = require("../audit/multi_tenant_policy");

const MIGRATION_VERSION = 1;
const QUARANTINE_STATUS = "quarentena";

function text(value) {
  return String(value === undefined || value === null ? "" : value).trim();
}

function normalizedName(value) {
  return text(value)
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, " ")
      .trim()
      .replace(/\s+/g, " ");
}

function valueAtPath(data, fieldPath) {
  return String(fieldPath).split(".").reduce((value, segment) => {
    if (!value || typeof value !== "object") return undefined;
    return value[segment];
  }, data);
}

function documentMap(documents) {
  return new Map((documents || []).map((document) => [document.id, document]));
}

function uniqueNonEmpty(values) {
  return [...new Set(values.map(text).filter(Boolean))].sort();
}

function addToIndex(index, key, value) {
  if (!key) return;
  if (!index.has(key)) index.set(key, []);
  index.get(key).push(value);
}

function singleIndexValue(index, key) {
  const values = index.get(key) || [];
  return values.length === 1 ? values[0] : null;
}

function buildPatientIndexes(patients) {
  const byId = documentMap(patients);
  const byName = new Map();
  const byEmail = new Map();
  const byUid = new Map();

  for (const patient of patients || []) {
    addToIndex(byName, normalizedName(patient.data.nomeGestante), patient.id);
    addToIndex(
        byEmail,
        text(patient.data.emailGestante).toLowerCase(),
        patient.id,
    );
    const link = inspectPatientLink(patient.data, false);
    for (const uid of link.uids.values) addToIndex(byUid, uid, patient.id);
  }

  return {byEmail, byId, byName, byUid};
}

function resolvePatientId(data, definition, indexes) {
  const idFields = [...PATIENT_ID_FIELDS];
  const uidFields = [...PATIENT_UID_FIELDS];
  if (definition.inspectPayload) {
    idFields.push(...PATIENT_ID_FIELDS.map((field) => `payload.${field}`));
    uidFields.push(...PATIENT_UID_FIELDS.map((field) => `payload.${field}`));
  }

  const suppliedIds = uniqueNonEmpty(
      idFields.map((field) => valueAtPath(data, field)),
  );
  const validIds = suppliedIds.filter((id) => indexes.byId.has(id));
  if (validIds.length === 1 && suppliedIds.every((id) => id === validIds[0])) {
    return {patientId: validIds[0], method: "id"};
  }

  const suppliedUids = uniqueNonEmpty(
      uidFields.map((field) => valueAtPath(data, field)),
  );
  const uidMatches = uniqueNonEmpty(
      suppliedUids.map((uid) => singleIndexValue(indexes.byUid, uid)),
  );
  if (uidMatches.length === 1) {
    return {patientId: uidMatches[0], method: "uid"};
  }

  const nameFields = [
    "gestanteNome",
    "nomeGestante",
    "gestante",
    "payload.gestanteNome",
    "payload.nomeGestante",
    "payload.gestante",
  ];
  const names = uniqueNonEmpty(nameFields.map((field) => {
    const value = valueAtPath(data, field);
    return typeof value === "string" ? normalizedName(value) : "";
  }));
  const nameMatches = uniqueNonEmpty(
      names.map((name) => singleIndexValue(indexes.byName, name)),
  );
  if (nameMatches.length === 1) {
    return {patientId: nameMatches[0], method: "name"};
  }

  return {
    patientId: "",
    method: "unresolved",
    reason: suppliedIds.length > 0 ?
      "referencia_paciente_orfa" :
      (nameMatches.length > 1 ? "nome_paciente_ambiguo" : "paciente_nao_resolvido"),
  };
}

function migrationMetadata(sourcePath) {
  return {
    migracaoOrigem: sourcePath,
    migracaoVersao: MIGRATION_VERSION,
  };
}

function tenantPatch(tenantId) {
  return {adminDonoId: tenantId, clinicaId: tenantId};
}

function patientIdPatch(patientId) {
  return Object.fromEntries(PATIENT_ID_FIELDS.map((field) => [field, patientId]));
}

function patientUidPatch(uid) {
  if (!uid) return {};
  return Object.fromEntries(PATIENT_UID_FIELDS.map((field) => [field, uid]));
}

function rolePatch(role) {
  const legacyRole = role === "paciente" ? "gestante" : role;
  return {tipo: legacyRole, tipoUsuario: legacyRole};
}

function mergePatch(base, patch) {
  const merged = {...base, ...patch};
  if (base.payload || patch.payload) {
    merged.payload = {...(base.payload || {}), ...(patch.payload || {})};
  }
  return merged;
}

class MigrationPlanBuilder {
  constructor() {
    this._sets = new Map();
    this.authUpdates = [];
    this.blockers = [];
    this.warnings = [];
  }

  set(path, data, reason) {
    const existing = this._sets.get(path);
    if (existing) {
      existing.data = mergePatch(existing.data, data);
      if (!existing.reasons.includes(reason)) existing.reasons.push(reason);
      return;
    }
    this._sets.set(path, {path, data: {...data}, merge: true, reasons: [reason]});
  }

  blocker(code, sourcePath, details = {}) {
    this.blockers.push({code, sourcePath, details});
  }

  warning(code, sourcePath, details = {}) {
    this.warnings.push({code, sourcePath, details});
  }

  build(metadata) {
    const firestoreSets = [...this._sets.values()].sort((left, right) =>
      left.path.localeCompare(right.path));
    return {
      schemaVersion: "1.0.0",
      migrationVersion: MIGRATION_VERSION,
      ...metadata,
      firestoreSets,
      authUpdates: [...this.authUpdates].sort((left, right) =>
        left.uid.localeCompare(right.uid)),
      blockers: [...this.blockers],
      warnings: [...this.warnings],
      summary: {
        firestoreSets: firestoreSets.length,
        authUpdates: this.authUpdates.length,
        blockers: this.blockers.length,
        warnings: this.warnings.length,
      },
    };
  }
}

function resolveExistingTenant(data, sourcePath, builder) {
  const tenant = inspectTenant(data);
  if (tenant.divergent) {
    builder.blocker("TENANT_ALIAS_DIVERGENT", sourcePath, {
      values: tenant.values,
    });
    return "";
  }
  return tenant.resolved;
}

function ensureTenant(data, tenantId, sourcePath, builder) {
  const existing = resolveExistingTenant(data, sourcePath, builder);
  if (existing && existing !== tenantId) {
    builder.blocker("TENANT_CONFLICT", sourcePath, {
      expectedTenantId: tenantId,
      existingTenantId: existing,
    });
    return "";
  }
  return tenantId;
}

function canonicalPath(definition, tenantId, documentId, patientId = "") {
  const copy = definition.canonicalCopy;
  const canonicalId = canonicalDocumentId(definition, documentId);
  if (copy.scope === "patient") {
    return `clinicas/${tenantId}/pacientes/${patientId}/` +
      `${copy.collection}/${canonicalId}`;
  }
  return `clinicas/${tenantId}/${copy.collection}/${canonicalId}`;
}

function quarantinePath(definition, tenantId, documentId) {
  const copy = definition.quarantineCopy;
  return `clinicas/${tenantId}/${copy.collection}/` +
    canonicalDocumentId(definition, documentId, {quarantine: true});
}

function finalData(original, patch, sourcePath) {
  return mergePatch(original, {
    ...patch,
    ...migrationMetadata(sourcePath),
  });
}

function setRootAndCanonical({
  builder,
  definition,
  document,
  patch,
  tenantId,
  patientId = "",
  quarantined = false,
}) {
  const sourcePath = document.path || `${definition.name}/${document.id}`;
  const rootPatch = {...patch, ...migrationMetadata(sourcePath)};
  builder.set(sourcePath, rootPatch, "backfill_root");
  const data = finalData(document.data, patch, sourcePath);
  const destination = quarantined ?
    quarantinePath(definition, tenantId, document.id) :
    canonicalPath(definition, tenantId, document.id, patientId);
  builder.set(destination, data, quarantined ? "quarantine_copy" : "canonical_copy");
}

function clinicByAdminUid(clinics) {
  const result = new Map();
  for (const clinic of clinics || []) {
    const uid = text(clinic.data.adminUid);
    if (uid) addToIndex(result, uid, clinic.id);
  }
  return result;
}

function userTenant({user, clinicsByAdmin, targetTenantId, patientTenantById}) {
  const existing = inspectTenant(user.data).resolved;
  if (existing) return existing;
  const ownerClinic = singleIndexValue(clinicsByAdmin, user.id);
  if (ownerClinic) return ownerClinic;
  const patientIds = inspectPatientLink(user.data, false).ids.values;
  if (patientIds.length === 1 && patientTenantById.has(patientIds[0])) {
    return patientTenantById.get(patientIds[0]);
  }
  return targetTenantId;
}

function findStaffEntity(user, collections) {
  const role = inspectUserRole(user.data).resolved;
  const collectionName = role === "enfermeira" ? "enfermeiras" :
    (role === "obstetra" ? "obstetras" :
      (role === "profissional" ? "profissionais" : ""));
  if (!collectionName) return null;
  const uidFields = role === "enfermeira" ?
    ["uidEnfermeira", "uidProfissional"] :
    (role === "obstetra" ? ["uidObstetra", "uidProfissional"] :
      ["uidProfissional"]);
  const matches = (collections[collectionName] || []).filter((entity) =>
    uidFields.some((field) => text(entity.data[field]) === user.id));
  return matches.length === 1 ? {collectionName, document: matches[0], role} :
    null;
}

function buildCanonicalClinicCopies(builder, collections) {
  const canonicalClinics = documentMap(collections.clinicas);
  for (const clinic of collections.clinicasSaaS || []) {
    const sourcePath = clinic.path || `clinicasSaaS/${clinic.id}`;
    const patch = tenantPatch(clinic.id);
    builder.set(sourcePath, {
      ...patch,
      id: clinic.id,
      ...migrationMetadata(sourcePath),
    }, "clinic_aliases");
    const current = canonicalClinics.get(clinic.id);
    const canonicalData = finalData(clinic.data, {
      ...patch,
      id: clinic.id,
    }, sourcePath);
    if (current) {
      const currentAdmin = text(current.data.adminUid);
      const sourceAdmin = text(clinic.data.adminUid);
      if (currentAdmin && sourceAdmin && currentAdmin !== sourceAdmin) {
        builder.blocker("CANONICAL_CLINIC_OWNER_CONFLICT", current.path, {
          tenantId: clinic.id,
        });
        continue;
      }
    }
    builder.set(`clinicas/${clinic.id}`, canonicalData, "canonical_clinic");
  }
}

function planPatients(builder, patients, targetTenantId) {
  const patientTenantById = new Map();
  const finalPatients = new Map();
  for (const patient of patients || []) {
    const sourcePath = patient.path || `gestantes/${patient.id}`;
    const tenantId = ensureTenant(
        patient.data,
        resolveExistingTenant(patient.data, sourcePath, builder) || targetTenantId,
        sourcePath,
        builder,
    );
    if (!tenantId) continue;
    const currentIds = inspectPatientLink(patient.data, false).ids.values;
    if (currentIds.some((id) => id !== patient.id)) {
      builder.blocker("PATIENT_ID_CONFLICT", sourcePath, {
        expectedPatientId: patient.id,
        existingPatientIds: currentIds,
      });
      continue;
    }
    const uids = inspectPatientLink(patient.data, false).uids.values;
    if (uids.length > 1) {
      builder.blocker("PATIENT_UID_CONFLICT", sourcePath, {patientUids: uids});
      continue;
    }
    const patch = {
      ...tenantPatch(tenantId),
      ...patientIdPatch(patient.id),
      ...patientUidPatch(uids[0] || ""),
    };
    const final = finalData(patient.data, patch, sourcePath);
    builder.set(sourcePath, {...patch, ...migrationMetadata(sourcePath)}, "patient_identity");
    builder.set(
        `clinicas/${tenantId}/pacientes/${patient.id}`,
        final,
        "canonical_patient",
    );
    patientTenantById.set(patient.id, tenantId);
    finalPatients.set(patient.id, final);
  }
  return {finalPatients, patientTenantById};
}

function planUsers({
  authUsers,
  builder,
  clinics,
  collections,
  patientIndexes,
  patientTenantById,
  targetTenantId,
}) {
  const authByUid = new Map((authUsers || []).map((user) => [user.uid, user]));
  const usersById = documentMap(collections.usuarios);
  const clinicsByAdmin = clinicByAdminUid(clinics);
  const finalUsers = new Map();

  for (const user of collections.usuarios || []) {
    const sourcePath = user.path || `usuarios/${user.id}`;
    const role = inspectUserRole(user.data).resolved;
    if (!role) {
      builder.blocker("USER_ROLE_UNRESOLVED", sourcePath);
      continue;
    }
    const authUser = authByUid.get(user.id);
    if (!authUser) {
      builder.blocker("USER_WITHOUT_AUTH", sourcePath);
      continue;
    }
    const tenantId = role === "superAdmin" ?
      inspectTenant(user.data).resolved :
      userTenant({
        user,
        clinicsByAdmin,
        targetTenantId,
        patientTenantById,
      });
    if (role !== "superAdmin" && !ensureTenant(
        user.data,
        tenantId,
        sourcePath,
        builder,
    )) continue;

    let patch = {
      uid: user.id,
      status: "ativo",
      ...rolePatch(role),
    };
    if (role !== "superAdmin") patch = {...patch, ...tenantPatch(tenantId)};

    if (role === "gestante") {
      const currentIds = inspectPatientLink(user.data, false).ids.values;
      let patientId = currentIds.length === 1 &&
        patientIndexes.byId.has(currentIds[0]) ? currentIds[0] : "";
      if (!patientId) {
        patientId = singleIndexValue(patientIndexes.byUid, user.id) ||
          singleIndexValue(
              patientIndexes.byEmail,
              text(user.data.email).toLowerCase(),
          ) || "";
      }
      if (patientId) {
        const patientTenant = patientTenantById.get(patientId);
        if (patientTenant !== tenantId) {
          builder.blocker("PATIENT_USER_TENANT_CONFLICT", sourcePath, {
            patientId,
            patientTenantId: patientTenant,
            userTenantId: tenantId,
          });
          continue;
        }
        patch = {
          ...patch,
          ...patientIdPatch(patientId),
          ...patientUidPatch(user.id),
        };
        const patient = patientIndexes.byId.get(patientId);
        builder.set(
            patient.path,
            {...patientUidPatch(user.id), ...migrationMetadata(patient.path)},
            "patient_user_cross_link",
        );
        builder.set(
            `clinicas/${tenantId}/pacientes/${patientId}`,
            {...patientUidPatch(user.id), ...migrationMetadata(patient.path)},
            "canonical_patient_user_cross_link",
        );
      } else {
        patch = {
          ...patch,
          status: "inativo",
          migracaoStatus: QUARANTINE_STATUS,
          migracaoMotivo: "perfil_paciente_sem_cadastro",
        };
        builder.warning("PATIENT_USER_QUARANTINED", sourcePath);
      }
    }

    if (["enfermeira", "obstetra", "profissional"].includes(role)) {
      const entity = findStaffEntity(user, collections);
      if (!entity) {
        builder.blocker("STAFF_ENTITY_UNRESOLVED", sourcePath, {role});
        continue;
      }
      patch.idVinculo = entity.document.id;
    }

    const full = finalData(user.data, patch, sourcePath);
    builder.set(sourcePath, {...patch, ...migrationMetadata(sourcePath)}, "user_identity");
    if (role !== "superAdmin") {
      builder.set(
          `clinicas/${tenantId}/usuarios/${user.id}`,
          full,
          "canonical_user",
      );
    }
    finalUsers.set(user.id, full);

    const currentClaims = authUser.customClaims || {};
    const shouldBeSuperAdmin = role === "superAdmin";
    if (Boolean(currentClaims.superAdmin) !== shouldBeSuperAdmin) {
      builder.authUpdates.push({
        uid: user.id,
        disabled: Boolean(authUser.disabled),
        customClaims: {...currentClaims, superAdmin: shouldBeSuperAdmin},
        reason: "normalize_superadmin_claim",
      });
    }
  }

  for (const authUser of authUsers || []) {
    if (usersById.has(authUser.uid)) continue;
    // O projeto Firebase também atende fluxos fora do aplicativo clínico.
    // Ausência em `usuarios` não prova que a conta é órfã; desativá-la durante
    // um backfill poderia interromper outro produto. As regras do app exigem um
    // perfil válido, portanto preservar a conta não concede acesso clínico.
    builder.warning("UNSCOPED_AUTH_ACCOUNT_PRESERVED", "firebaseAuth");
  }

  return finalUsers;
}

function planPatientLocks(builder, finalPatients, finalUsers) {
  for (const [patientId, patient] of finalPatients) {
    const uids = inspectPatientLink(patient, false).uids.values;
    if (uids.length !== 1) continue;
    const uid = uids[0];
    const user = finalUsers.get(uid);
    if (!user || inspectUserRole(user).resolved !== "gestante") continue;
    const tenantId = inspectTenant(patient).resolved;
    const data = {
      ...tenantPatch(tenantId),
      pacienteId: patientId,
      uidUsuario: uid,
      tipoUsuario: "gestante",
      migracaoVersao: MIGRATION_VERSION,
    };
    builder.set(`vinculosAuthPaciente/${uid}`, data, "patient_direct_lock");
    builder.set(
        `vinculosPacienteAuth/${patientId}`,
        data,
        "patient_reverse_lock",
    );
  }
}

function planStaff(builder, collections, finalUsers, targetTenantId) {
  const definitions = ROOT_COLLECTIONS.filter((definition) =>
    definition.kind === "staff");
  for (const definition of definitions) {
    for (const entity of collections[definition.name] || []) {
      const sourcePath = entity.path || `${definition.name}/${entity.id}`;
      const quarantine = (reason) => {
        const tenantId = resolveExistingTenant(
            entity.data,
            sourcePath,
            builder,
        ) || targetTenantId;
        if (!ensureTenant(entity.data, tenantId, sourcePath, builder)) return;
        setRootAndCanonical({
          builder,
          definition,
          document: entity,
          patch: {
            ...tenantPatch(tenantId),
            status: "inativo",
            migracaoStatus: QUARANTINE_STATUS,
            migracaoMotivo: reason,
          },
          tenantId,
          quarantined: true,
        });
        builder.warning("STAFF_ENTITY_QUARANTINED", sourcePath, {reason});
      };
      const suppliedUids = uniqueNonEmpty(
          definition.staffUidFields.map((field) => entity.data[field]),
      );
      if (suppliedUids.length !== 1) {
        quarantine("uid_profissional_nao_resolvido");
        continue;
      }
      const uid = suppliedUids[0];
      const user = finalUsers.get(uid);
      if (!user) {
        quarantine("usuario_profissional_nao_resolvido");
        continue;
      }
      const role = inspectUserRole(user).resolved;
      if (!definition.expectedRoles.includes(role)) {
        quarantine("perfil_profissional_divergente");
        continue;
      }
      const tenantId = inspectTenant(user).resolved || targetTenantId;
      if (!ensureTenant(entity.data, tenantId, sourcePath, builder)) continue;
      const uidPatch = Object.fromEntries(
          definition.staffUidFields.map((field) => [field, uid]),
      );
      const patch = {
        ...tenantPatch(tenantId),
        ...uidPatch,
        idVinculo: entity.id,
        tipoUsuario: role,
      };
      setRootAndCanonical({
        builder,
        definition,
        document: entity,
        patch,
        tenantId,
      });
      const lock = {
        ...tenantPatch(tenantId),
        idVinculo: entity.id,
        tipoUsuario: role,
        uidUsuario: uid,
        migracaoVersao: MIGRATION_VERSION,
      };
      builder.set(`vinculosAuthEntidade/${uid}`, lock, "staff_direct_lock");
      builder.set(
          `vinculosEntidadeAuth/${role}_${entity.id}`,
          lock,
          "staff_reverse_lock",
      );
    }
  }
}

function patientRecordPatch(patientId, patient) {
  const uids = inspectPatientLink(patient, false).uids.values;
  return {
    ...patientIdPatch(patientId),
    ...patientUidPatch(uids.length === 1 ? uids[0] : ""),
  };
}

function planMappedCollections({
  builder,
  collections,
  finalPatients,
  patientIndexes,
  patientTenantById,
  targetTenantId,
}) {
  const definitions = ROOT_COLLECTIONS.filter((definition) =>
    definition.canonicalDisposition === "mapped" &&
    definition.kind !== "staff");

  for (const definition of definitions) {
    for (const document of collections[definition.name] || []) {
      const sourcePath = document.path || `${definition.name}/${document.id}`;
      let tenantId = resolveExistingTenant(document.data, sourcePath, builder);
      let patientId = "";
      let patch = {};
      let quarantined = false;

      if (definition.name === "assinaturasSaaS") {
        tenantId = tenantId || text(document.data.clinicaId);
      }

      if (definition.kind === "patientRecord") {
        const resolution = resolvePatientId(
            document.data,
            definition,
            patientIndexes,
        );
        patientId = resolution.patientId;
        if (patientId) {
          const patient = finalPatients.get(patientId);
          tenantId = patientTenantById.get(patientId);
          if (!patient || !tenantId) {
            builder.blocker("PATIENT_DESTINATION_UNRESOLVED", sourcePath, {
              patientId,
            });
            continue;
          }
          patch = patientRecordPatch(patientId, patient);
          if (definition.inspectPayload) {
            patch.payload = {
              ...(document.data.payload || {}),
              ...patientRecordPatch(patientId, patient),
            };
          }
        } else if (definition.patientLink === "required" ||
            definition.quarantineCopy) {
          if (!definition.quarantineCopy) {
            builder.blocker("PATIENT_REFERENCE_UNRESOLVED", sourcePath, {
              reason: resolution.reason,
            });
            continue;
          }
          tenantId = tenantId || targetTenantId;
          quarantined = true;
          patch = {
            migracaoStatus: QUARANTINE_STATUS,
            migracaoMotivo: resolution.reason,
          };
          builder.warning("PATIENT_RECORD_QUARANTINED", sourcePath, {
            sourceCollection: definition.name,
          });
        }
      }

      tenantId = tenantId || targetTenantId;
      if (!ensureTenant(document.data, tenantId, sourcePath, builder)) continue;
      patch = {...patch, ...tenantPatch(tenantId)};
      setRootAndCanonical({
        builder,
        definition,
        document,
        patch,
        tenantId,
        patientId,
        quarantined,
      });
    }
  }
}

function planSpecialCatalogs(builder, collections, targetTenantId) {
  for (const collectionName of ["planos", "biblioteca"]) {
    for (const document of collections[collectionName] || []) {
      const sourcePath = document.path || `${collectionName}/${document.id}`;
      const tenantId = resolveExistingTenant(document.data, sourcePath, builder) ||
        targetTenantId;
      if (!ensureTenant(document.data, tenantId, sourcePath, builder)) continue;
      const patch = tenantPatch(tenantId);
      builder.set(sourcePath, {
        ...patch,
        ...migrationMetadata(sourcePath),
      }, "catalog_tenant");
      builder.set(
          `clinicas/${tenantId}/${collectionName}/${document.id}`,
          finalData(document.data, patch, sourcePath),
          "canonical_catalog",
      );
    }
  }
}

function planLegacyUserMirrors(builder, collections) {
  for (const document of collections.usuariosSaaS || []) {
    const sourcePath = document.path || `usuariosSaaS/${document.id}`;
    const tenantId = inspectTenant(document.data).resolved;
    if (!tenantId) {
      builder.blocker("LEGACY_USER_TENANT_UNRESOLVED", sourcePath);
      continue;
    }
    const role = inspectUserRole(document.data).resolved;
    const patch = {
      ...tenantPatch(tenantId),
      uid: document.id,
      status: text(document.data.status).toLowerCase() || "ativo",
      ...rolePatch(role),
      ...migrationMetadata(sourcePath),
    };
    builder.set(sourcePath, patch, "legacy_user_mirror");
  }
}

function validateTargetTenant(collections, tenantId, builder) {
  const legacy = documentMap(collections.clinicasSaaS).get(tenantId);
  const canonical = documentMap(collections.clinicas).get(tenantId);
  if (!legacy && !canonical) {
    builder.blocker("TARGET_TENANT_NOT_FOUND", "clinicas", {tenantId});
  }
}

function planMultiTenantBackfill(input, options) {
  const collections = input.collections || {};
  const targetTenantId = text(options && options.targetTenantId);
  const builder = new MigrationPlanBuilder();
  if (!targetTenantId) {
    builder.blocker("TARGET_TENANT_REQUIRED", "__options__");
    return builder.build({targetTenantId: ""});
  }

  validateTargetTenant(collections, targetTenantId, builder);
  buildCanonicalClinicCopies(builder, collections);

  const patientIndexes = buildPatientIndexes(collections.gestantes || []);
  const {finalPatients, patientTenantById} = planPatients(
      builder,
      collections.gestantes || [],
      targetTenantId,
  );
  const finalUsers = planUsers({
    authUsers: input.authUsers || [],
    builder,
    clinics: collections.clinicasSaaS || [],
    collections,
    patientIndexes,
    patientTenantById,
    targetTenantId,
  });

  planPatientLocks(builder, finalPatients, finalUsers);
  planStaff(builder, collections, finalUsers, targetTenantId);
  planMappedCollections({
    builder,
    collections,
    finalPatients,
    patientIndexes,
    patientTenantById,
    targetTenantId,
  });
  planSpecialCatalogs(builder, collections, targetTenantId);
  planLegacyUserMirrors(builder, collections);

  return builder.build({
    generatedAt: options.generatedAt || new Date().toISOString(),
    targetTenantId,
  });
}

module.exports = {
  MIGRATION_VERSION,
  QUARANTINE_STATUS,
  normalizedName,
  planMultiTenantBackfill,
  resolvePatientId,
};
