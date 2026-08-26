/* eslint-disable require-jsdoc */
"use strict";

const TENANT_FIELDS = Object.freeze(["clinicaId", "adminDonoId"]);
const PATIENT_ID_FIELDS = Object.freeze([
  "pacienteId",
  "gestanteId",
  "idGestante",
]);
const PATIENT_UID_FIELDS = Object.freeze([
  "uidPaciente",
  "pacienteUid",
  "uidGestante",
  "gestanteUid",
]);

const KNOWN_USER_ROLES = Object.freeze([
  "admin",
  "superAdmin",
  "enfermeira",
  "obstetra",
  "profissional",
  "gestante",
]);

const CANONICAL_DISPOSITIONS = Object.freeze([
  "mapped",
  "special",
  "unresolved",
]);
const SPECIAL_CANONICAL_COLLECTIONS = Object.freeze([
  "clinicas",
  "clinicasSaaS",
  "usuarios",
  "usuariosSaaS",
  "gestantes",
  "planos",
  "biblioteca",
  "vinculosAuthPaciente",
  "vinculosPacienteAuth",
  "vinculosAuthEntidade",
  "vinculosEntidadeAuth",
]);

const ROOT_COLLECTIONS = Object.freeze([
  {
    name: "clinicas",
    kind: "clinic",
    hardCutover: true,
    canonicalDisposition: "special",
  },
  {
    name: "clinicasSaaS",
    kind: "clinicLegacy",
    hardCutover: true,
    canonicalDisposition: "special",
  },
  {
    name: "usuarios",
    kind: "user",
    hardCutover: false,
    canonicalDisposition: "special",
  },
  {
    name: "usuariosSaaS",
    kind: "userLegacy",
    hardCutover: false,
    canonicalDisposition: "special",
  },
  {
    name: "assinaturasSaaS",
    kind: "tenant",
    hardCutover: true,
    canonicalDisposition: "mapped",
    canonicalCopy: {
      scope: "clinic",
      collection: "configuracoes",
      documentIdPrefix: "assinatura_",
    },
  },
  {
    name: "gestantes",
    kind: "patient",
    hardCutover: true,
    canonicalDisposition: "special",
    patientLink: "entity",
    portalUidField: "uidGestante",
  },
  {
    name: "enfermeiras",
    kind: "staff",
    hardCutover: true,
    canonicalDisposition: "mapped",
    canonicalCopy: {
      scope: "clinic",
      collection: "profissionais",
      documentIdPrefix: "enfermeira_",
    },
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_enfermeiras_",
    },
    expectedRoles: ["enfermeira"],
    staffUidFields: ["uidEnfermeira", "uidProfissional"],
  },
  {
    name: "obstetras",
    kind: "staff",
    hardCutover: true,
    canonicalDisposition: "mapped",
    canonicalCopy: {
      scope: "clinic",
      collection: "profissionais",
      documentIdPrefix: "obstetra_",
    },
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_obstetras_",
    },
    expectedRoles: ["obstetra"],
    staffUidFields: ["uidObstetra", "uidProfissional"],
  },
  {
    name: "profissionais",
    kind: "staff",
    hardCutover: true,
    canonicalDisposition: "mapped",
    canonicalCopy: {
      scope: "clinic",
      collection: "profissionais",
      documentIdPrefix: "profissional_",
    },
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_profissionais_",
    },
    expectedRoles: ["profissional"],
    staffUidFields: ["uidProfissional"],
  },
  {
    name: "agenda",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "optional",
    portalUidField: "gestanteUid",
    queryPatientIdFields: ["gestanteId"],
    canonicalCopy: {scope: "clinic", collection: "agenda"},
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_agenda_",
    },
  },
  {
    name: "atendimentos",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "required",
    canonicalCopy: {scope: "patient", collection: "atendimentos"},
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_atendimentos_",
    },
  },
  {
    name: "exames",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "required",
    portalUidField: "uidGestante",
    queryPatientIdFields: ["idGestante"],
    canonicalCopy: {scope: "patient", collection: "exames"},
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_exames_",
    },
  },
  {
    name: "documentos",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "required",
    portalUidField: "uidGestante",
    canonicalCopy: {scope: "patient", collection: "documentos"},
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_documentos_",
    },
  },
  {
    name: "prontuario_atendimentos",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "required",
    queryPatientIdFields: ["idGestante"],
    canonicalCopy: {
      scope: "patient",
      collection: "prontuario",
      documentIdPrefix: "atendimento_",
    },
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_prontuario_atendimentos_",
    },
  },
  {
    name: "prontuarios",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "required",
    queryPatientIdFields: ["idGestante"],
    canonicalCopy: {
      scope: "patient",
      collection: "prontuario",
      documentIdPrefix: "prontuario_",
    },
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_prontuarios_",
    },
  },
  {
    name: "contracoes",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "required",
    portalUidField: "uidGestante",
    canonicalCopy: {
      scope: "patient",
      collection: "prontuario",
      documentIdPrefix: "contracao_",
    },
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_contracoes_",
    },
  },
  {
    name: "contratos",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "required",
    inspectPayload: true,
    portalUidField: "pacienteUid",
    canonicalCopy: {scope: "patient", collection: "contratos"},
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_contratos_",
    },
  },
  {
    name: "materiais",
    kind: "tenant",
    hardCutover: true,
    canonicalDisposition: "mapped",
    canonicalCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "material_",
    },
  },
  {
    name: "parcelas",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "required",
    portalUidField: "uidGestante",
    queryPatientIdFields: ["gestanteId"],
    canonicalCopy: {
      scope: "patient",
      collection: "financeiro",
      documentIdPrefix: "parcela_",
    },
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_parcelas_",
    },
  },
  {
    name: "parcelasFinanceiras",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "required",
    queryPatientIdFields: ["gestanteId"],
    canonicalCopy: {
      scope: "patient",
      collection: "financeiro",
      documentIdPrefix: "parcela_financeira_",
    },
    quarantineCopy: {
      scope: "clinic",
      collection: "operacao",
      documentIdPrefix: "quarentena_parcelas_financeiras_",
    },
  },
  {
    name: "notificacoesCentral",
    kind: "patientRecord",
    hardCutover: true,
    canonicalDisposition: "mapped",
    patientLink: "optional",
    canonicalCopy: {
      scope: "clinic",
      collection: "notificacoes",
      documentIdPrefix: "central_",
    },
  },
  {
    name: "planos",
    kind: "tenant",
    hardCutover: true,
    canonicalDisposition: "special",
  },
  {
    name: "biblioteca",
    kind: "tenant",
    hardCutover: true,
    canonicalDisposition: "special",
  },
  {
    name: "logsAdministrativos",
    kind: "tenant",
    hardCutover: false,
    canonicalDisposition: "mapped",
    canonicalCopy: {
      scope: "clinic",
      collection: "logs",
      documentIdPrefix: "administrativo_",
    },
  },
  {
    name: "vinculosAuthPaciente",
    kind: "patientLockByUser",
    hardCutover: false,
    canonicalDisposition: "special",
  },
  {
    name: "vinculosPacienteAuth",
    kind: "patientLockByPatient",
    hardCutover: false,
    canonicalDisposition: "special",
  },
  {
    name: "vinculosAuthEntidade",
    kind: "staffLockByUser",
    hardCutover: false,
    canonicalDisposition: "special",
  },
  {
    name: "vinculosEntidadeAuth",
    kind: "staffLockByEntity",
    hardCutover: false,
    canonicalDisposition: "special",
  },
]);

/**
 * Valida o contrato fail-closed das coleções raiz auditadas.
 * @param {Array<Object>} definitions Definições do manifest.
 * @return {boolean} Verdadeiro quando todas as definições são válidas.
 */
function validateRootCollectionManifest(definitions) {
  const allowed = new Set(CANONICAL_DISPOSITIONS);
  const allowedSpecial = new Set(SPECIAL_CANONICAL_COLLECTIONS);
  const names = new Set();

  for (const definition of definitions || []) {
    if (!definition || typeof definition.name !== "string" ||
        definition.name.trim().length === 0) {
      throw new Error("Toda coleção raiz precisa ter um nome válido.");
    }
    if (names.has(definition.name)) {
      throw new Error(`Coleção raiz duplicada: ${definition.name}.`);
    }
    names.add(definition.name);

    if (!allowed.has(definition.canonicalDisposition)) {
      throw new Error(
          `Disposição canônica inválida para ${definition.name}.`,
      );
    }

    if (definition.canonicalDisposition === "mapped") {
      const copy = definition.canonicalCopy;
      if (!copy || !["clinic", "patient"].includes(copy.scope) ||
          typeof copy.collection !== "string" ||
          copy.collection.trim().length === 0) {
        throw new Error(
            `Coleção mapeada sem canonicalCopy válido: ${definition.name}.`,
        );
      }
      if (copy.documentIdPrefix !== undefined &&
          (typeof copy.documentIdPrefix !== "string" ||
            copy.documentIdPrefix.trim().length === 0 ||
            copy.documentIdPrefix !== copy.documentIdPrefix.trim())) {
        throw new Error(
            `Prefixo canônico inválido: ${definition.name}.`,
        );
      }
    } else if (definition.canonicalCopy) {
      throw new Error(
          `canonicalCopy exige disposição mapped: ${definition.name}.`,
      );
    }
    if (definition.canonicalDisposition === "special" &&
        !allowedSpecial.has(definition.name)) {
      throw new Error(
          `Coleção sem auditoria dedicada não pode ser special: ` +
          `${definition.name}.`,
      );
    }
    if (definition.quarantineCopy) {
      const copy = definition.quarantineCopy;
      if (!["patientRecord", "staff"].includes(definition.kind) ||
          copy.scope !== "clinic" ||
          typeof copy.collection !== "string" ||
          copy.collection.trim().length === 0 ||
          typeof copy.documentIdPrefix !== "string" ||
          copy.documentIdPrefix.trim().length === 0) {
        throw new Error(
            `Destino de quarentena inválido: ${definition.name}.`,
        );
      }
    }
  }

  const destinations = new Set();
  for (const definition of definitions || []) {
    if (!definition.canonicalCopy) continue;
    const copy = definition.canonicalCopy;
    const key = [
      copy.scope,
      copy.collection,
      copy.documentIdPrefix || "",
    ].join("|");
    if (destinations.has(key)) {
      throw new Error(`Destino canônico ambíguo: ${key}.`);
    }
    destinations.add(key);
  }

  return true;
}

validateRootCollectionManifest(ROOT_COLLECTIONS);

function canonicalDocumentId(definition, sourceDocumentId, options = {}) {
  const copy = options.quarantine ?
    definition.quarantineCopy : definition.canonicalCopy;
  if (!copy) {
    throw new Error(`Coleção sem destino canônico: ${definition.name}.`);
  }
  return `${copy.documentIdPrefix || ""}${sourceDocumentId}`;
}

const GLOBAL_ROOT_COLLECTIONS = Object.freeze([
  "_backendRateLimits",
  "admins",
  "checkoutRateLimits",
  "integracoes",
  "logsSuperAdmin",
  "orders",
  "operacoesSistema",
  "planosNatus",
  "products",
]);

const TECHNICAL_CANONICAL_CLINIC_COLLECTIONS = Object.freeze([
  "operacoesSistema",
]);

const CANONICAL_CLINIC_COLLECTIONS = Object.freeze([
  "usuarios",
  "profissionais",
  "pacientes",
  "agenda",
  "operacao",
  ...TECHNICAL_CANONICAL_CLINIC_COLLECTIONS,
  "financeiro",
  "planos",
  "biblioteca",
  "configuracoes",
  "notificacoes",
  "logs",
]);

const CANONICAL_PATIENT_COLLECTIONS = Object.freeze([
  "prontuario",
  "atendimentos",
  "exames",
  "documentos",
  "contratos",
  "agenda",
  "financeiro",
]);

const AUDIT_FIELD_PATHS = Object.freeze(Array.from(new Set([
  ...TENANT_FIELDS,
  ...PATIENT_ID_FIELDS,
  ...PATIENT_UID_FIELDS,
  "uid",
  "uidUsuario",
  "uidProfissional",
  "uidEnfermeira",
  "uidObstetra",
  "tipo",
  "tipoUsuario",
  "status",
  "migracaoStatus",
  "migracaoMotivo",
  "adminUid",
  "idVinculo",
  "pacienteId",
  "profissionalId",
  "payload.pacienteId",
  "payload.gestanteId",
  "payload.idGestante",
  "payload.uidPaciente",
  "payload.pacienteUid",
  "payload.uidGestante",
  "payload.gestanteUid",
])));

module.exports = {
  AUDIT_FIELD_PATHS,
  CANONICAL_DISPOSITIONS,
  CANONICAL_CLINIC_COLLECTIONS,
  CANONICAL_PATIENT_COLLECTIONS,
  canonicalDocumentId,
  GLOBAL_ROOT_COLLECTIONS,
  KNOWN_USER_ROLES,
  PATIENT_ID_FIELDS,
  PATIENT_UID_FIELDS,
  ROOT_COLLECTIONS,
  SPECIAL_CANONICAL_COLLECTIONS,
  TECHNICAL_CANONICAL_CLINIC_COLLECTIONS,
  TENANT_FIELDS,
  validateRootCollectionManifest,
};
