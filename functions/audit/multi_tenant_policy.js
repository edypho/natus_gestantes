/* eslint-disable require-jsdoc */
"use strict";

const {
  KNOWN_USER_ROLES,
  PATIENT_ID_FIELDS,
  PATIENT_UID_FIELDS,
  TENANT_FIELDS,
} = require("./multi_tenant_manifest");

function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object || {}, key);
}

function valueAtPath(data, path) {
  const parts = String(path || "").split(".");
  let current = data;

  for (const part of parts) {
    if (!current || typeof current !== "object" || !hasOwn(current, part)) {
      return {exists: false, value: undefined};
    }
    current = current[part];
  }

  return {exists: true, value: current};
}

function inspectTextField(data, path) {
  const located = valueAtPath(data, path);

  if (!located.exists || located.value === null) {
    return {
      field: path,
      exists: located.exists,
      validType: located.value === null ? false : true,
      nonEmpty: false,
      notNormalized: false,
      value: "",
    };
  }

  if (typeof located.value !== "string") {
    return {
      field: path,
      exists: true,
      validType: false,
      nonEmpty: false,
      notNormalized: false,
      value: "",
    };
  }

  const normalized = located.value.trim();
  return {
    field: path,
    exists: true,
    validType: true,
    nonEmpty: normalized.length > 0,
    notNormalized: normalized.length > 0 && normalized !== located.value,
    value: normalized,
  };
}

function inspectAliasGroup(data, fields, options) {
  const settings = options || {};
  const paths = [];

  for (const field of fields) paths.push(field);
  if (settings.includePayload) {
    for (const field of fields) paths.push(`payload.${field}`);
  }

  const states = paths.map((path) => inspectTextField(data, path));
  const values = new Set();

  for (const state of states) {
    if (state.validType && state.nonEmpty) values.add(state.value);
  }

  return {
    states,
    values: Array.from(values).sort(),
    populatedFields: states
        .filter((state) => state.validType && state.nonEmpty)
        .map((state) => state.field),
    invalidFields: states
        .filter((state) => state.exists && !state.validType)
        .map((state) => state.field),
    notNormalizedFields: states
        .filter((state) => state.notNormalized)
        .map((state) => state.field),
  };
}

function inspectTenant(data) {
  const group = inspectAliasGroup(data, TENANT_FIELDS);
  const clinica = inspectTextField(data, "clinicaId");
  const admin = inspectTextField(data, "adminDonoId");
  const canonical = clinica.validType && clinica.nonEmpty &&
    admin.validType && admin.nonEmpty && clinica.value === admin.value &&
    group.notNormalizedFields.length === 0;

  return {
    ...group,
    clinicaId: clinica.validType ? clinica.value : "",
    adminDonoId: admin.validType ? admin.value : "",
    canonical,
    resolved: group.values.length === 1 ? group.values[0] : "",
    divergent: group.values.length > 1,
    missingFields: TENANT_FIELDS.filter((field) => {
      const state = field === "clinicaId" ? clinica : admin;
      return !state.validType || !state.nonEmpty;
    }),
  };
}

function inspectPatientLink(data, includePayload) {
  return {
    ids: inspectAliasGroup(data, PATIENT_ID_FIELDS, {includePayload}),
    uids: inspectAliasGroup(data, PATIENT_UID_FIELDS, {includePayload}),
  };
}

function normalizeRole(value) {
  if (typeof value !== "string") return "";
  const normalized = value.trim().toLowerCase();

  if (["superadmin", "super_admin", "super-admin"].includes(normalized)) {
    return "superAdmin";
  }
  if (normalized === "paciente") return "gestante";
  return normalized;
}

function inspectUserRole(data) {
  const tipoState = inspectTextField(data, "tipo");
  const tipoUsuarioState = inspectTextField(data, "tipoUsuario");
  const tipo = normalizeRole(tipoState.value);
  const tipoUsuario = normalizeRole(tipoUsuarioState.value);
  const values = new Set([tipo, tipoUsuario].filter(Boolean));
  const resolved = values.size === 1 ? Array.from(values)[0] : "";

  return {
    tipo,
    tipoUsuario,
    resolved,
    divergent: values.size > 1,
    missing: values.size === 0,
    known: values.size === 1 && KNOWN_USER_ROLES.includes(resolved),
    invalidFields: [tipoState, tipoUsuarioState]
        .filter((state) => state.exists && !state.validType)
        .map((state) => state.field),
    notNormalizedFields: [tipoState, tipoUsuarioState]
        .filter((state) => state.notNormalized)
        .map((state) => state.field),
  };
}

function isMigrationQuarantined(data) {
  const status = inspectTextField(data, "migracaoStatus");
  const reason = inspectTextField(data, "migracaoMotivo");
  return status.validType && status.value.toLowerCase() === "quarentena" &&
    reason.validType && reason.nonEmpty;
}

function sameNonEmptyValue(left, right) {
  return Boolean(left && right && left === right);
}

module.exports = {
  inspectAliasGroup,
  inspectPatientLink,
  inspectTenant,
  inspectTextField,
  inspectUserRole,
  isMigrationQuarantined,
  normalizeRole,
  sameNonEmptyValue,
  valueAtPath,
};
