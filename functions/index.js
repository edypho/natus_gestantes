/* eslint-disable require-jsdoc */
/* eslint-disable max-len */
/* eslint-disable quote-props */
const {setGlobalOptions} = require("firebase-functions");
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {
  FieldValue,
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {getStorage} = require("firebase-admin/storage");
const {defineSecret} = require("firebase-functions/params");
const {
  avaliarTransicaoPerfil,
} = require("./user_lifecycle_policy");
const {
  AuthTokenValidationError,
  verificarIdTokenNaoRevogado,
} = require("./password_reset_auth");
const {
  MAX_SAFE_BATCH_WRITES,
  canonicalPatientLinkedRecordPath,
  canonicalPatientPath,
  canonicalUserPath,
  countPatientLinkBatchWrites,
} = require("./canonical_dual_write_policy");
const {
  DurableOperationError,
  OPERATION_KIND,
  OPERATION_STATE,
  adicionarCommitAoBatch,
  consultarOperacao,
  criarDescritorOperacao,
  garantirUsuarioAuth,
  marcarFirestoreParaRetentativa,
  marcarRollbackNecessario,
  prepararCommitOperacao,
  reservarOperacao,
  reverterUsuarioAuth,
} = require("./durable_operation_journal");
const {
  applyRestrictedCors,
} = require("./security/http_cors");
const {
  buildPrivateClinicalPush,
} = require("./security/private_push");
const {
  RateLimitExceededError,
  consumeRateLimit,
} = require("./security/rate_limiter");
const {
  logSafeError,
  safeErrorCode,
} = require("./security/safe_logging");
const {
  validateCanonicalUpload,
} = require("./security/upload_content_validator");
const {
  canonicalSyncDestination,
} = require("./canonical_sync_policy");

const {onRequest} = require("firebase-functions/v2/https");


const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onObjectFinalized} = require("firebase-functions/v2/storage");

const zapsignApiToken = defineSecret("ZAPSIGN_API_TOKEN");
const googleMapsGeocodingApiKey = defineSecret(
    "GOOGLE_MAPS_GEOCODING_API_KEY",
);
// App Check e uma opcao de implantacao, nao uma configuracao lida em runtime.
// Permanece desligado ate os provedores serem cadastrados e monitorados.
const enforceAppCheck = false;
const ZAPSIGN_API_BASE_URL = "https://api.zapsign.com.br/api/v1";
const ZAPSIGN_SIGNER_BASE_URL = "https://app.zapsign.co/verificar";
const ZAPSIGN_CONFIG_PATH = "integracoes/zapsign";
const ZAPSIGN_TEMPLATE_IDS_PADRAO = {
  acolher_consultorio: "2037be9f-e33e-406b-98ad-e2b74b385c9f",
  acolher_residencial: "1953c005-2ca1-450c-a779-d77e8a680ab8",
  presenca_consultorio: "876e29dd-bb1f-4801-b146-d9e2e45cf6ed",
  presenca_residencial: "b7337535-0c05-4038-97f4-8f879d1a4012",
  plenitude_consultorio: "045ebda1-9835-4bd8-810f-7fb1bd2cf411",
  plenitude_residencial: "83503f6b-f179-4a20-afe4-dbdc9ad0f031",
};

const ZAPSIGN_PLANOS_POR_TEMPLATE = {
  acolher_consultorio: {
    planoNome: "Acolher",
    modalidadeNome: "Consultorio",
  },
  acolher_residencial: {
    planoNome: "Acolher",
    modalidadeNome: "Residencial",
  },
  presenca_consultorio: {
    planoNome: "Presenca",
    modalidadeNome: "Consultorio",
  },
  presenca_residencial: {
    planoNome: "Presenca",
    modalidadeNome: "Residencial",
  },
  plenitude_consultorio: {
    planoNome: "Plenitude",
    modalidadeNome: "Consultorio",
  },
  plenitude_residencial: {
    planoNome: "Plenitude",
    modalidadeNome: "Residencial",
  },
};

function normalizarTextoContrato(valor) {
  return String(valor || "")
      .toLowerCase()
      .trim()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "");
}

function descobrirTemplateKeyContrato(plano, consultorio) {
  const planoNormalizado = normalizarTextoContrato(plano);
  const consultorioNormalizado = normalizarTextoContrato(consultorio);

  if (planoNormalizado.includes("acolher") &&
    planoNormalizado.includes("consultorio")) {
    return "acolher_consultorio";
  }

  if (planoNormalizado.includes("acolher") &&
    planoNormalizado.includes("residencial")) {
    return "acolher_residencial";
  }

  if (planoNormalizado.includes("presenca") &&
    planoNormalizado.includes("consultorio")) {
    return "presenca_consultorio";
  }

  if (planoNormalizado.includes("presenca") &&
    planoNormalizado.includes("residencial")) {
    return "presenca_residencial";
  }

  if (planoNormalizado.includes("plenitude") &&
    planoNormalizado.includes("consultorio")) {
    return "plenitude_consultorio";
  }

  if (planoNormalizado.includes("plenitude") &&
    planoNormalizado.includes("residencial")) {
    return "plenitude_residencial";
  }

  if (planoNormalizado.includes("acolher")) {
    return consultorioNormalizado === "sim" ||
      consultorioNormalizado.includes("consultorio") ?
      "acolher_consultorio" :
      "acolher_residencial";
  }

  if (planoNormalizado.includes("presenca")) {
    return consultorioNormalizado === "sim" ||
      consultorioNormalizado.includes("consultorio") ?
      "presenca_consultorio" :
      "presenca_residencial";
  }

  if (planoNormalizado.includes("plenitude")) {
    return consultorioNormalizado === "sim" ||
      consultorioNormalizado.includes("consultorio") ?
      "plenitude_consultorio" :
      "plenitude_residencial";
  }

  return "";
}

// Adapter mínimo para preservar os fluxos existentes enquanto o SDK Admin 14
// expõe apenas as APIs modulares. Nenhum estado ou credencial é armazenado aqui.
const adminFirestore = () => getFirestore();
adminFirestore.FieldValue = FieldValue;
adminFirestore.Timestamp = Timestamp;
const admin = {
  auth: getAuth,
  firestore: adminFirestore,
  messaging: getMessaging,
  storage: getStorage,
};

initializeApp();

setGlobalOptions({maxInstances: 10});

exports.sincronizarRaizCanonica = onDocumentWritten(
    "{collectionId}/{documentId}",
    async (event) => {
      const change = event.data;
      if (!change) return;
      const collectionName = event.params.collectionId;
      const documentId = event.params.documentId;
      const before = change.before.exists ? canonicalSyncDestination(
          collectionName,
          documentId,
          change.before.data() || {},
      ) : null;
      const after = change.after.exists ? canonicalSyncDestination(
          collectionName,
          documentId,
          change.after.data() || {},
      ) : null;

      if (after && after.status === "blocked") {
        console.warn("Sincronização canônica recusada.", {
          collectionName,
          reason: after.reason,
        });
        return;
      }
      if ((!before || before.status !== "ready") &&
          (!after || after.status !== "ready")) {
        return;
      }

      const db = getFirestore();
      const batch = db.batch();
      let writes = 0;
      if (before && before.status === "ready" &&
          (!after || after.status !== "ready" || before.path !== after.path)) {
        batch.delete(db.doc(before.path));
        writes += 1;
      }
      if (after && after.status === "ready") {
        batch.set(db.doc(after.path), after.data, {merge: false});
        writes += 1;
      }
      if (writes > 0) await batch.commit();
    },
);

exports.validarConteudoUpload = onObjectFinalized(
    {
      region: "us-central1",
      timeoutSeconds: 30,
      memory: "256MiB",
    },
    async (event) => {
      try {
        const result = await validateCanonicalUpload({
          objectData: event.data,
          storage: admin.storage(),
        });
        if (result.deleted) {
          console.warn(
              "Upload canônico removido por assinatura de conteúdo inválida.",
          );
        }
      } catch (error) {
        logSafeError("Falha ao validar conteudo de upload canonico.", error);
        throw error;
      }
    },
);

const PERFIS_USUARIO_CONHECIDOS = new Set([
  "admin",
  "superAdmin",
  "enfermeira",
  "obstetra",
  "profissional",
  "gestante",
]);
const STATUS_CLINICA_ATIVOS = new Set(["ativa", "teste"]);

function textoSeguro(valor) {
  return String(valor || "").trim();
}

function exigirIdDocumento(valor, campo) {
  const id = textoSeguro(valor);

  if (!id || id.includes("/") || id.length > 1500) {
    throw new HttpsError(
        "invalid-argument",
        `${campo} inválido.`,
    );
  }

  return id;
}

function normalizarPerfilUsuario(valor) {
  const perfil = textoSeguro(valor).toLowerCase();

  if (["superadmin", "super_admin", "super-admin"].includes(perfil)) {
    return "superAdmin";
  }

  if (perfil === "paciente") {
    return "gestante";
  }

  return perfil;
}

function resolverPerfilUsuario(dados) {
  const tipo = normalizarPerfilUsuario(dados && dados.tipo);
  const tipoUsuario = normalizarPerfilUsuario(dados && dados.tipoUsuario);

  if (!tipo && !tipoUsuario) {
    return {
      perfil: "",
      consistente: false,
    };
  }

  if (tipo && tipoUsuario && tipo !== tipoUsuario) {
    return {
      perfil: "",
      consistente: false,
    };
  }

  const perfil = tipo || tipoUsuario;

  return {
    perfil,
    consistente: PERFIS_USUARIO_CONHECIDOS.has(perfil),
  };
}

function resolverTenant(dados) {
  const clinicaId = textoSeguro(dados && dados.clinicaId);
  const adminDonoId = textoSeguro(dados && dados.adminDonoId);
  const consistente = !(clinicaId && adminDonoId && clinicaId !== adminDonoId);

  return {
    clinicaId: consistente ? (clinicaId || adminDonoId) : "",
    consistente,
  };
}

function camposTenant(clinicaId) {
  const tenantId = textoSeguro(clinicaId);

  return {
    clinicaId: tenantId,
    adminDonoId: tenantId,
  };
}

function exigirTenant(dados, recurso) {
  const tenant = resolverTenant(dados);

  if (!tenant.consistente || !tenant.clinicaId) {
    throw new HttpsError(
        "failed-precondition",
        `${recurso} sem vinculo de clinica valido.`,
    );
  }

  return tenant.clinicaId;
}

async function exigirClinicaAtiva(clinicaId) {
  const tenantId = textoSeguro(clinicaId);

  if (!tenantId) {
    throw new HttpsError(
        "failed-precondition",
        "Vinculo de clinica nao informado.",
    );
  }

  const db = admin.firestore();
  const [snapshotCanonico, snapshotLegado] = await Promise.all([
    db.collection("clinicas").doc(tenantId).get(),
    db.collection("clinicasSaaS").doc(tenantId).get(),
  ]);
  const snapshot = snapshotCanonico.exists ?
    snapshotCanonico : snapshotLegado;
  const dados = snapshot.exists ? (snapshot.data() || {}) : {};
  const status = textoSeguro(dados.status).toLowerCase();
  const tenantClinica = resolverTenant(dados);

  if (!snapshot.exists ||
      !tenantClinica.consistente ||
      tenantClinica.clinicaId !== tenantId ||
      !STATUS_CLINICA_ATIVOS.has(status)) {
    throw new HttpsError(
        "permission-denied",
        "A clínica vinculada não está habilitada.",
    );
  }
}

async function exigirContextoUsuario(autenticacao, perfisPermitidos) {
  const uidNormalizado = textoSeguro(autenticacao && autenticacao.uid);
  const token = autenticacao && autenticacao.token ?
    autenticacao.token : (autenticacao || {});
  const claimSuperAdmin = token.superAdmin === true;

  if (!uidNormalizado) {
    throw new HttpsError(
        "unauthenticated",
        "Voce precisa estar logado.",
    );
  }

  await exigirSessaoAuthAtiva(autenticacao, uidNormalizado);

  const snapshot = await admin
      .firestore()
      .collection("usuarios")
      .doc(uidNormalizado)
      .get();

  if (!snapshot.exists) {
    throw new HttpsError(
        "permission-denied",
        "Perfil de acesso não encontrado.",
    );
  }

  const dados = snapshot.data() || {};
  const perfilResolvido = resolverPerfilUsuario(dados);
  const status = textoSeguro(dados.status).toLowerCase();

  if (!perfilResolvido.consistente || status !== "ativo") {
    throw new HttpsError(
        "permission-denied",
        "Perfil de acesso inválido ou inativo.",
    );
  }

  if ((perfilResolvido.perfil === "superAdmin") !== claimSuperAdmin) {
    throw new HttpsError(
        "permission-denied",
        "Perfil e credencial de Super Admin divergentes.",
    );
  }

  if (!perfisPermitidos.includes(perfilResolvido.perfil)) {
    throw new HttpsError(
        "permission-denied",
        "Seu perfil não possui permissão para esta operação.",
    );
  }

  if (perfilResolvido.perfil === "superAdmin") {
    return {
      uid: uidNormalizado,
      perfil: perfilResolvido.perfil,
      clinicaId: "",
      dados,
    };
  }

  const clinicaId = exigirTenant(dados, "Usuario");
  await exigirClinicaAtiva(clinicaId);

  return {
    uid: uidNormalizado,
    perfil: perfilResolvido.perfil,
    clinicaId,
    dados,
  };
}

async function exigirSessaoAuthAtiva(autenticacao, uid) {
  let usuarioAuth;

  try {
    usuarioAuth = await admin.auth().getUser(uid);
  } catch (error) {
    if (safeErrorCode(error) === "auth/user-not-found") {
      throw new HttpsError(
          "unauthenticated",
          "Sessão inválida ou expirada.",
      );
    }

    logSafeError("Falha ao validar a sessão no Firebase Auth.", error);
    throw new HttpsError(
        "unavailable",
        "Não foi possível validar a sessão. Tente novamente.",
    );
  }

  if (usuarioAuth.disabled) {
    throw new HttpsError(
        "permission-denied",
        "Usuario desabilitado.",
    );
  }

  const token = autenticacao && autenticacao.token ?
    autenticacao.token : (autenticacao || {});
  const authTimeSeconds = Number(token.auth_time);
  const tokensValidAfterMillis = Date.parse(
      usuarioAuth.tokensValidAfterTime || "",
  );

  if (!Number.isFinite(authTimeSeconds) ||
      (Number.isFinite(tokensValidAfterMillis) &&
       authTimeSeconds * 1000 < tokensValidAfterMillis)) {
    throw new HttpsError(
        "unauthenticated",
        "Sessão inválida ou expirada.",
    );
  }
}

async function exigirLimiteUso({
  action,
  subjects,
  limit,
  windowSeconds,
}) {
  try {
    await consumeRateLimit({
      db: admin.firestore(),
      action,
      subjects,
      limit,
      windowSeconds,
    });
  } catch (error) {
    if (error instanceof RateLimitExceededError) {
      throw new HttpsError(
          "resource-exhausted",
          "Muitas solicitacoes em pouco tempo. Aguarde e tente novamente.",
          {retryAfterSeconds: error.retryAfterSeconds},
      );
    }

    logSafeError("Falha ao aplicar limite de uso.", error);
    throw new HttpsError(
        "unavailable",
        "Não foi possível validar o limite de uso. Tente novamente.",
    );
  }
}

function exigirAcessoAoTenant(contexto, clinicaId) {
  const tenantId = textoSeguro(clinicaId);

  if (!tenantId) {
    throw new HttpsError(
        "failed-precondition",
        "Recurso sem vinculo de clinica valido.",
    );
  }

  if (contexto.perfil !== "superAdmin" && contexto.clinicaId !== tenantId) {
    throw new HttpsError(
        "permission-denied",
        "O recurso nao pertence a sua clinica.",
    );
  }
}

async function buscarContratoComTenant(contratoId) {
  const id = textoSeguro(contratoId);

  if (!id) {
    throw new HttpsError("invalid-argument", "ContratoId nao informado.");
  }

  const contratoRef = admin.firestore().collection("contratos").doc(id);
  const contratoSnapshot = await contratoRef.get();

  if (!contratoSnapshot.exists) {
    throw new HttpsError("not-found", "Contrato não encontrado.");
  }

  const contrato = contratoSnapshot.data() || {};
  const payload = contrato.payload && typeof contrato.payload === "object" ?
    contrato.payload : {};
  const pacienteContrato = textoSeguro(contrato.pacienteId);
  const pacientePayload = textoSeguro(payload.pacienteId);

  if (pacienteContrato && pacientePayload &&
      pacienteContrato !== pacientePayload) {
    throw new HttpsError(
        "failed-precondition",
        "Contrato com vinculo de paciente inconsistente.",
    );
  }

  const pacienteId = pacienteContrato || pacientePayload;

  if (!pacienteId) {
    throw new HttpsError(
        "failed-precondition",
        "Contrato sem paciente vinculado.",
    );
  }

  const pacienteRef = admin.firestore().collection("gestantes").doc(pacienteId);
  const pacienteSnapshot = await pacienteRef.get();

  if (!pacienteSnapshot.exists) {
    throw new HttpsError(
        "failed-precondition",
        "Paciente vinculado ao contrato não encontrado.",
    );
  }

  const paciente = pacienteSnapshot.data() || {};
  const tenantContrato = resolverTenant(contrato);
  const tenantPaciente = resolverTenant(paciente);

  if (!tenantContrato.consistente ||
      !tenantPaciente.consistente ||
      !tenantPaciente.clinicaId ||
      (tenantContrato.clinicaId &&
       tenantContrato.clinicaId !== tenantPaciente.clinicaId)) {
    throw new HttpsError(
        "failed-precondition",
        "Contrato com vinculo de clinica inconsistente.",
    );
  }

  const clinicaId = tenantContrato.clinicaId || tenantPaciente.clinicaId;
  await exigirClinicaAtiva(clinicaId);

  return {
    contratoRef,
    contrato: {
      ...contrato,
      pacienteId,
      ...camposTenant(clinicaId),
    },
    pacienteRef,
    paciente: {
      ...paciente,
      ...camposTenant(clinicaId),
    },
    pacienteId,
    clinicaId,
  };
}

async function propagarTenantContrato(contratoResolvido) {
  await Promise.all([
    contratoResolvido.contratoRef.set({
      pacienteId: contratoResolvido.pacienteId,
      ...camposTenant(contratoResolvido.clinicaId),
    }, {merge: true}),
    contratoResolvido.pacienteRef.set(
        camposTenant(contratoResolvido.clinicaId),
        {merge: true},
    ),
  ]);
}

async function buscarPacienteParaRedefinicao(contexto, entrada) {
  const idsSolicitados = valoresIdentificadores(
      entrada,
      CAMPOS_ID_PACIENTE,
  );
  if (idsSolicitados.size > 1) {
    throw new HttpsError(
        "invalid-argument",
        "Identificadores de paciente divergentes.",
    );
  }
  const idSolicitado = idsSolicitados.size === 1 ?
    [...idsSolicitados][0] : "";
  const idsUsuarioUnicos = [...valoresIdentificadores(
      contexto.dados,
      CAMPOS_ID_PACIENTE,
  )];

  if (idsUsuarioUnicos.length > 1) {
    throw new HttpsError(
        "failed-precondition",
        "Perfil com vinculo de paciente inconsistente.",
    );
  }

  if (contexto.perfil === "gestante" &&
      idSolicitado &&
      idsUsuarioUnicos.length === 1 &&
      idSolicitado !== idsUsuarioUnicos[0]) {
    throw new HttpsError(
        "permission-denied",
        "A paciente informada nao pertence ao usuario autenticado.",
    );
  }

  let pacienteId = idSolicitado || idsUsuarioUnicos[0] || "";
  let pacienteSnapshot;

  if (!pacienteId && contexto.perfil === "gestante") {
    const resultados = await buscarPacientesPorUid(contexto.uid);

    if (resultados.length === 1) {
      pacienteSnapshot = resultados[0];
      pacienteId = pacienteSnapshot.id;
    }
  }

  if (!pacienteId) {
    throw new HttpsError(
        "invalid-argument",
        "Cadastro do paciente não informado ou não vinculado ao usuário.",
    );
  }

  if (!pacienteSnapshot) {
    pacienteSnapshot = await admin
        .firestore()
        .collection("gestantes")
        .doc(pacienteId)
        .get();
  }

  if (!pacienteSnapshot.exists) {
    throw new HttpsError("not-found", "Paciente não encontrado.");
  }

  const paciente = pacienteSnapshot.data() || {};
  const clinicaId = exigirTenant(paciente, "Paciente");
  exigirAcessoAoTenant(contexto, clinicaId);

  if (contexto.perfil === "gestante") {
    const uidsPaciente = valoresIdentificadores(
        paciente,
        CAMPOS_UID_PACIENTE,
    );
    if (uidsPaciente.size > 1) {
      throw new HttpsError(
          "failed-precondition",
          "Paciente com vinculo de login inconsistente.",
      );
    }
    const uidPaciente = uidsPaciente.size === 1 ? [...uidsPaciente][0] : "";
    const idConfere = idsUsuarioUnicos.includes(pacienteSnapshot.id);
    const uidConfere = uidPaciente === contexto.uid;

    if ((uidPaciente && !uidConfere) || (!idConfere && !uidConfere)) {
      throw new HttpsError(
          "permission-denied",
          "A paciente nao pertence ao usuario autenticado.",
      );
    }
  }

  await pacienteSnapshot.ref.set(camposTenant(clinicaId), {merge: true});

  return {
    ref: pacienteSnapshot.ref,
    id: pacienteSnapshot.id,
    dados: {
      ...paciente,
      ...camposTenant(clinicaId),
    },
    clinicaId,
  };
}

async function buscarUsuarioAuthDaPaciente(contexto, paciente) {
  const uidsPaciente = valoresIdentificadores(
      paciente.dados,
      CAMPOS_UID_PACIENTE,
  );
  if (uidsPaciente.size > 1) {
    throw new HttpsError(
        "failed-precondition",
        "Paciente com vinculo de login inconsistente.",
    );
  }
  const uidPaciente = contexto.perfil === "gestante" ?
    contexto.uid : (uidsPaciente.size === 1 ? [...uidsPaciente][0] : "");

  if (!uidPaciente) {
    throw new HttpsError(
        "failed-precondition",
        "Paciente sem usuario de acesso vinculado.",
    );
  }

  const perfilSnapshot = await admin
      .firestore()
      .collection("usuarios")
      .doc(uidPaciente)
      .get();

  if (!perfilSnapshot.exists) {
    throw new HttpsError(
        "failed-precondition",
        "Perfil de acesso do paciente não encontrado.",
    );
  }

  const perfilDados = perfilSnapshot.data() || {};
  const perfil = resolverPerfilUsuario(perfilDados);
  const tenantPerfil = resolverTenant(perfilDados);
  const idsPerfil = valoresIdentificadores(perfilDados, CAMPOS_ID_PACIENTE);
  const pacientePerfil = idsPerfil.size === 1 ? [...idsPerfil][0] : "";

  if (idsPerfil.size > 1 || !perfil.consistente ||
      perfil.perfil !== "gestante" ||
      textoSeguro(perfilDados.status).toLowerCase() !== "ativo" ||
      !tenantPerfil.consistente ||
      tenantPerfil.clinicaId !== paciente.clinicaId ||
      pacientePerfil !== paciente.id) {
    throw new HttpsError(
        "failed-precondition",
        "Perfil da paciente com vinculo de acesso inconsistente.",
    );
  }

  const usuario = await admin.auth().getUser(uidPaciente);

  if (usuario.disabled || !usuario.email) {
    throw new HttpsError(
        "failed-precondition",
        "Acesso da paciente inativo ou sem e-mail no Firebase Authentication.",
    );
  }

  const emailPerfil = textoSeguro(perfilDados.email).toLowerCase();

  if (emailPerfil && emailPerfil !== textoSeguro(usuario.email).toLowerCase()) {
    throw new HttpsError(
        "failed-precondition",
        "E-mail da paciente divergente do Firebase Authentication.",
    );
  }

  return usuario;
}

async function autenticarRedefinicaoSenha(
    authorizationHeader,
    autenticacaoCallable = null,
) {
  const uidCallable = textoSeguro(
      autenticacaoCallable && autenticacaoCallable.uid,
  );

  if (autenticacaoCallable && !uidCallable) {
    throw new HttpsError(
        "unauthenticated",
        "Voce precisa estar logado.",
    );
  }

  try {
    return await verificarIdTokenNaoRevogado(
        admin.auth(),
        authorizationHeader,
        uidCallable,
    );
  } catch (error) {
    if (error instanceof AuthTokenValidationError) {
      throw new HttpsError(
          "unauthenticated",
          "Sessão inválida ou expirada.",
      );
    }

    throw error;
  }
}

async function solicitarRedefinicaoSenhaPacienteCore(
    autenticacao,
    entrada,
) {
  const contexto = await exigirContextoUsuario(
      autenticacao,
      ["admin", "gestante"],
  );
  const paciente = await buscarPacienteParaRedefinicao(
      contexto,
      entrada || {},
  );
  await exigirLimiteUso({
    action: "password-reset-request",
    subjects: [
      `actor:${contexto.uid}`,
      `patient:${paciente.clinicaId}:${paciente.id}`,
    ],
    limit: 3,
    windowSeconds: 15 * 60,
  });
  const usuarioAuth = await buscarUsuarioAuthDaPaciente(
      contexto,
      paciente,
  );
  const emailNormalizado = textoSeguro(usuarioAuth.email).toLowerCase();
  const agora = new Date().toISOString();

  await paciente.ref.set({
    ...camposTenant(paciente.clinicaId),
    linkSenhaInicial: admin.firestore.FieldValue.delete(),
    linkSenhaInicialGeradoEm: admin.firestore.FieldValue.delete(),
    linkSenhaInicialExpirado: true,
    redefinicaoSenhaPendente: true,
    redefinicaoSenhaSolicitadaEm: agora,
    redefinicaoSenhaSolicitadaPor: contexto.uid,
  }, {merge: true});

  return {
    sucesso: true,
    mensagem: "Solicitacao de redefinicao registrada com seguranca.",
    pacienteId: paciente.id,
    emailPaciente: emailNormalizado,
    telefonePaciente: textoSeguro(paciente.dados.telefoneGestante),
    nomePaciente: textoSeguro(paciente.dados.nomeGestante),
  };
}

function statusHttpParaErro(error) {
  if (error && error.code === "unauthenticated") return 401;
  if (error && error.code === "permission-denied") return 403;
  if (error && error.code === "not-found") return 404;
  if (error && error.code === "invalid-argument") return 400;
  if (error && error.code === "failed-precondition") return 400;
  if (error && error.code === "resource-exhausted") return 429;
  if (error && error.code === "auth/user-not-found") return 404;
  if (error && textoSeguro(error.code).startsWith("auth/")) return 401;
  return 500;
}

const MAX_REGISTROS_POR_VINCULO = 440;
const CAMPOS_ID_PACIENTE = [
  "pacienteId",
  "gestanteId",
  "idGestante",
];
const CAMPOS_UID_PACIENTE = [
  "uidPaciente",
  "pacienteUid",
  "uidGestante",
  "gestanteUid",
];
const COLECOES_VINCULO_PACIENTE = [
  {
    colecao: "agenda",
    camposId: ["pacienteId", "gestanteId", "idGestante"],
    camposUid: CAMPOS_UID_PACIENTE,
  },
  {
    colecao: "documentos",
    camposId: ["pacienteId", "gestanteId", "idGestante"],
    camposUid: CAMPOS_UID_PACIENTE,
  },
  {
    colecao: "exames",
    camposId: ["pacienteId", "idGestante", "gestanteId"],
    camposUid: CAMPOS_UID_PACIENTE,
  },
  {
    colecao: "parcelas",
    camposId: ["pacienteId", "gestanteId", "idGestante"],
    camposUid: CAMPOS_UID_PACIENTE,
  },
  {
    colecao: "parcelasFinanceiras",
    camposId: ["pacienteId", "gestanteId", "idGestante"],
    camposUid: CAMPOS_UID_PACIENTE,
  },
  {
    colecao: "contracoes",
    camposId: ["pacienteId", "idGestante", "gestanteId"],
    camposUid: CAMPOS_UID_PACIENTE,
  },
  {
    colecao: "contratos",
    camposId: ["pacienteId", "idGestante", "gestanteId"],
    camposUid: CAMPOS_UID_PACIENTE,
    payload: true,
  },
];

function valoresIdentificadores(dados, campos) {
  const valores = new Set();

  for (const campo of campos) {
    const valor = textoSeguro(dados && dados[campo]);
    if (valor) valores.add(valor);
  }

  return valores;
}

function camposIdentidadePaciente(pacienteId, uidPaciente) {
  return {
    pacienteId,
    gestanteId: pacienteId,
    idGestante: pacienteId,
    uidPaciente,
    pacienteUid: uidPaciente,
    uidGestante: uidPaciente,
    gestanteUid: uidPaciente,
  };
}

async function buscarPacientesPorUid(uidPaciente, limite = 3) {
  const uid = textoSeguro(uidPaciente);
  if (!uid) return [];

  const db = admin.firestore();
  const resultados = await Promise.all(CAMPOS_UID_PACIENTE.map((campo) => {
    return db.collection("gestantes")
        .where(campo, "==", uid)
        .limit(limite)
        .get();
  }));
  const pacientes = new Map();

  for (const resultado of resultados) {
    for (const documento of resultado.docs) {
      pacientes.set(documento.ref.path, documento);
    }
  }

  return [...pacientes.values()];
}

const MAX_VINCULOS_ENTIDADE_USUARIO = 20;
const CONFIGURACOES_ENTIDADE_USUARIO = [
  {
    perfil: "gestante",
    colecao: "gestantes",
    camposId: ["pacienteId", "gestanteId", "idGestante"],
    camposUid: [
      "uidPaciente",
      "pacienteUid",
      "uidGestante",
      "gestanteUid",
    ],
  },
  {
    perfil: "enfermeira",
    colecao: "enfermeiras",
    camposId: [],
    camposUid: ["uidEnfermeira", "uidProfissional"],
  },
  {
    perfil: "obstetra",
    colecao: "obstetras",
    camposId: [],
    camposUid: ["uidObstetra", "uidProfissional"],
  },
];

function resolverIdentidadeVinculoPerfis({
  dadosUsuario,
  dadosUsuarioSaaS,
  uidUsuario,
}) {
  const perfis = [dadosUsuario, dadosUsuarioSaaS].filter(Boolean);
  const pacienteIds = new Set();
  const idsVinculo = new Set();
  const uidsVinculo = new Set();

  for (const dados of perfis) {
    for (const id of valoresIdentificadores(
        dados,
        ["pacienteId", "gestanteId", "idGestante"],
    )) {
      pacienteIds.add(id);
    }
    const idVinculo = textoSeguro(dados.idVinculo);
    if (idVinculo) idsVinculo.add(idVinculo);
    for (const uid of valoresIdentificadores(
        dados,
        [
          "uidPaciente",
          "pacienteUid",
          "uidGestante",
          "gestanteUid",
        ],
    )) {
      uidsVinculo.add(uid);
    }
  }

  if (pacienteIds.size > 1 || idsVinculo.size > 1 ||
      uidsVinculo.size > 1 ||
      (uidsVinculo.size === 1 && !uidsVinculo.has(uidUsuario))) {
    throw new HttpsError(
        "failed-precondition",
        "Usuario com aliases de vinculo inconsistentes.",
    );
  }

  return {
    pacienteId: pacienteIds.size === 1 ? [...pacienteIds][0] : "",
    idVinculo: idsVinculo.size === 1 ? [...idsVinculo][0] : "",
    possuiAliasUid: uidsVinculo.size > 0,
  };
}

function idEntidadeEsperada(configuracao, identidade) {
  if (configuracao.perfil === "gestante") {
    return identidade.pacienteId;
  }

  return identidade.idVinculo;
}

async function buscarEntidadesVinculadasUsuario({
  db,
  uidUsuario,
  clinicaId,
  perfilAtual,
  identidade,
}) {
  const consultas = [];

  for (const configuracao of CONFIGURACOES_ENTIDADE_USUARIO) {
    for (const campoUid of configuracao.camposUid) {
      consultas.push({
        configuracao,
        promise: db.collection(configuracao.colecao)
            .where(campoUid, "==", uidUsuario)
            .limit(MAX_VINCULOS_ENTIDADE_USUARIO + 1)
            .get(),
      });
    }
  }

  const resultados = await Promise.all(
      consultas.map((consulta) => consulta.promise),
  );
  const entidades = new Map();

  for (let indice = 0; indice < resultados.length; indice += 1) {
    const snapshot = resultados[indice];
    const configuracao = consultas[indice].configuracao;

    if (snapshot.size > MAX_VINCULOS_ENTIDADE_USUARIO) {
      throw new HttpsError(
          "resource-exhausted",
          "Muitos vinculos encontrados para exclusao segura.",
      );
    }

    for (const documento of snapshot.docs) {
      entidades.set(documento.ref.path, {configuracao, documento});
    }
  }

  const configuracaoAtual = CONFIGURACOES_ENTIDADE_USUARIO.find(
      (configuracao) => configuracao.perfil === perfilAtual,
  );
  const idEsperado = configuracaoAtual ?
    idEntidadeEsperada(configuracaoAtual, identidade) : "";

  if (configuracaoAtual && idEsperado) {
    const referencia = db
        .collection(configuracaoAtual.colecao)
        .doc(idEsperado);
    if (!entidades.has(referencia.path)) {
      const documento = await referencia.get();
      if (documento.exists) {
        entidades.set(referencia.path, {
          configuracao: configuracaoAtual,
          documento,
        });
      }
    }
  }

  const vinculadas = [];

  for (const item of entidades.values()) {
    const dados = item.documento.data() || {};
    const tenant = resolverTenant(dados);
    const uids = valoresIdentificadores(dados, item.configuracao.camposUid);

    if (!tenant.consistente || tenant.clinicaId !== clinicaId) {
      throw new HttpsError(
          "failed-precondition",
          "Entidade vinculada fora da clínica do usuário.",
      );
    }

    if (uids.size > 1 || (uids.size === 1 && !uids.has(uidUsuario))) {
      throw new HttpsError(
          "failed-precondition",
          "Entidade possui aliases de login inconsistentes.",
      );
    }

    if (item.configuracao.perfil === "gestante") {
      exigirIdsCompativeis(
          dados,
          item.configuracao.camposId,
          item.documento.id,
          "Paciente",
      );
      if (identidade.pacienteId &&
          identidade.pacienteId !== item.documento.id) {
        throw new HttpsError(
            "failed-precondition",
            "Perfil e cadastro de paciente possuem IDs divergentes.",
        );
      }
    }

    if (uids.has(uidUsuario)) {
      vinculadas.push(item);
    }
  }

  return vinculadas;
}

async function buscarLocksVinculadosUsuario({
  db,
  uidUsuario,
  clinicaId,
  perfilAtual,
  identidade,
}) {
  const referencias = new Map();
  const diretas = [
    db.collection("vinculosAuthPaciente").doc(uidUsuario),
    db.collection("vinculosAuthEntidade").doc(uidUsuario),
  ];

  if (identidade.pacienteId) {
    diretas.push(
        db.collection("vinculosPacienteAuth").doc(identidade.pacienteId),
    );
  }
  if (identidade.idVinculo && perfilAtual !== "gestante") {
    diretas.push(
        db.collection("vinculosEntidadeAuth")
            .doc(`${perfilAtual}_${identidade.idVinculo}`),
    );
  }

  const [diretos, reversosPaciente, reversosEntidade] = await Promise.all([
    Promise.all(diretas.map((referencia) => referencia.get())),
    db.collection("vinculosPacienteAuth")
        .where("uidUsuario", "==", uidUsuario)
        .limit(MAX_VINCULOS_ENTIDADE_USUARIO + 1)
        .get(),
    db.collection("vinculosEntidadeAuth")
        .where("uidUsuario", "==", uidUsuario)
        .limit(MAX_VINCULOS_ENTIDADE_USUARIO + 1)
        .get(),
  ]);

  if (reversosPaciente.size > MAX_VINCULOS_ENTIDADE_USUARIO ||
      reversosEntidade.size > MAX_VINCULOS_ENTIDADE_USUARIO) {
    throw new HttpsError(
        "resource-exhausted",
        "Muitos locks encontrados para exclusao segura.",
    );
  }

  for (const documento of [
    ...diretos,
    ...reversosPaciente.docs,
    ...reversosEntidade.docs,
  ]) {
    if (documento.exists) referencias.set(documento.ref.path, documento);
  }

  for (const documento of referencias.values()) {
    const dados = documento.data() || {};
    const tenant = resolverTenant(dados);

    if (!tenant.consistente ||
        tenant.clinicaId !== clinicaId ||
        textoSeguro(dados.uidUsuario) !== uidUsuario) {
      throw new HttpsError(
          "failed-precondition",
          "Lock de login inconsistente ou fora da clinica.",
      );
    }
  }

  return [...referencias.values()];
}

async function inspecionarVinculosCicloUsuario({
  db,
  uidUsuario,
  clinicaId,
  perfilAtual,
  dadosUsuario,
  dadosUsuarioSaaS,
}) {
  const identidade = resolverIdentidadeVinculoPerfis({
    dadosUsuario,
    dadosUsuarioSaaS,
    uidUsuario,
  });
  const [entidades, locks] = await Promise.all([
    buscarEntidadesVinculadasUsuario({
      db,
      uidUsuario,
      clinicaId,
      perfilAtual,
      identidade,
    }),
    buscarLocksVinculadosUsuario({
      db,
      uidUsuario,
      clinicaId,
      perfilAtual,
      identidade,
    }),
  ]);

  return {
    identidade,
    entidades,
    locks,
    possuiVinculo: identidade.pacienteId !== "" ||
      identidade.idVinculo !== "" ||
      identidade.possuiAliasUid ||
      entidades.length > 0 ||
      locks.length > 0,
  };
}

async function exigirUsuarioNaoTitularClinica({
  db,
  uidUsuario,
  clinicaId,
}) {
  if (!clinicaId) return;

  const clinicas = await Promise.all([
    db.collection("clinicas").doc(clinicaId).get(),
    db.collection("clinicasSaaS").doc(clinicaId).get(),
  ]);
  const titulares = new Set();

  for (const documento of clinicas) {
    if (!documento.exists) continue;
    const dados = documento.data() || {};
    const tenant = resolverTenant(dados);
    if (!tenant.consistente || tenant.clinicaId !== clinicaId) {
      throw new HttpsError(
          "failed-precondition",
          "Cadastro da clinica possui vinculo inconsistente.",
      );
    }
    const adminUid = textoSeguro(dados.adminUid);
    if (adminUid) titulares.add(adminUid);
  }

  if (titulares.size > 1) {
    throw new HttpsError(
        "failed-precondition",
        "Cadastros da clinica possuem titulares divergentes.",
    );
  }

  if (titulares.has(uidUsuario)) {
    throw new HttpsError(
        "failed-precondition",
        "Transfira a titularidade da clinica antes de excluir este admin.",
    );
  }
}

function identificadoresRegistroPaciente(configuracao, dados) {
  const ids = valoresIdentificadores(dados, configuracao.camposId);
  const uids = valoresIdentificadores(dados, configuracao.camposUid);

  if (configuracao.payload &&
      dados.payload &&
      typeof dados.payload === "object") {
    for (const valor of valoresIdentificadores(
        dados.payload,
        configuracao.camposId,
    )) {
      ids.add(valor);
    }

    for (const valor of valoresIdentificadores(
        dados.payload,
        configuracao.camposUid,
    )) {
      uids.add(valor);
    }
  }

  return {ids, uids};
}

function registroPertenceAoPaciente({
  configuracao,
  dados,
  pacienteId,
  uidUsuario,
  documentoId,
}) {
  const {ids, uids} = identificadoresRegistroPaciente(configuracao, dados);
  const idCorreto = ids.has(pacienteId);
  const uidCorreto = uids.has(uidUsuario);

  if (ids.size > 1 ||
      uids.size > 1 ||
      (idCorreto && uids.size > 0 && !uidCorreto) ||
      (ids.size > 0 && !idCorreto && uidCorreto)) {
    throw new HttpsError(
        "failed-precondition",
        `Registro ${configuracao.colecao}/${documentoId} com ` +
          "vinculo de paciente ou login inconsistente.",
    );
  }

  if (idCorreto) {
    return true;
  }

  if (ids.size > 0 || !uidCorreto) {
    return false;
  }

  return true;
}

function montarAtualizacaoRegistroPaciente({
  configuracao,
  dados,
  pacienteId,
  uidUsuario,
  clinicaId,
  uidOperador,
}) {
  const atualizacao = {
    ...camposTenant(clinicaId),
    pacienteId,
    uidPaciente: uidUsuario,
    uidGestante: uidUsuario,
    vinculoLoginAtualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    vinculoLoginAtualizadoPor: uidOperador,
  };

  for (const campo of configuracao.camposId) {
    atualizacao[campo] = pacienteId;
  }

  for (const campo of configuracao.camposUid) {
    atualizacao[campo] = uidUsuario;
  }

  if (configuracao.payload &&
      dados.payload &&
      typeof dados.payload === "object") {
    const payloadAtualizado = {
      ...dados.payload,
      pacienteId,
      pacienteUid: uidUsuario,
      uidPaciente: uidUsuario,
      uidGestante: uidUsuario,
    };

    for (const campo of configuracao.camposId) {
      payloadAtualizado[campo] = pacienteId;
    }

    for (const campo of configuracao.camposUid) {
      payloadAtualizado[campo] = uidUsuario;
    }

    atualizacao.payload = payloadAtualizado;
  }

  return atualizacao;
}

async function buscarDocumentosDoTenant(colecao, clinicaId) {
  const db = admin.firestore();
  const [porClinica, porAdmin] = await Promise.all([
    db.collection(colecao).where("clinicaId", "==", clinicaId).get(),
    db.collection(colecao).where("adminDonoId", "==", clinicaId).get(),
  ]);
  const documentos = new Map();

  for (const snapshot of [porClinica, porAdmin]) {
    for (const documento of snapshot.docs) {
      documentos.set(documento.ref.path, documento);
    }
  }

  return Array.from(documentos.values());
}

async function prepararAtualizacoesVinculoPaciente({
  pacienteId,
  uidUsuario,
  clinicaId,
  uidOperador,
}) {
  const resultados = await Promise.all(
      COLECOES_VINCULO_PACIENTE.map(async (configuracao) => {
        const documentos = await buscarDocumentosDoTenant(
            configuracao.colecao,
            clinicaId,
        );
        const atualizacoes = [];

        for (const documento of documentos) {
          const dados = documento.data() || {};

          if (!registroPertenceAoPaciente({
            configuracao,
            dados,
            pacienteId,
            uidUsuario,
            documentoId: documento.id,
          })) {
            continue;
          }

          const tenantRegistro = resolverTenant(dados);

          if (!tenantRegistro.consistente ||
              tenantRegistro.clinicaId !== clinicaId) {
            throw new HttpsError(
                "failed-precondition",
                `Registro ${configuracao.colecao}/${documento.id} fora ` +
                  "do tenant da paciente.",
            );
          }

          const dadosAtualizacao = montarAtualizacaoRegistroPaciente({
            configuracao,
            dados,
            pacienteId,
            uidUsuario,
            clinicaId,
            uidOperador,
          });
          atualizacoes.push({
            ref: documento.ref,
            dados: dadosAtualizacao,
            dadosCanonicos: {...dados, ...dadosAtualizacao},
            colecao: configuracao.colecao,
            updateTime: documento.updateTime,
          });
        }

        return atualizacoes;
      }),
  );
  const atualizacoes = resultados.flat();

  if (atualizacoes.length > MAX_REGISTROS_POR_VINCULO) {
    throw new HttpsError(
        "resource-exhausted",
        "A paciente possui registros demais para vinculacao atomica. " +
          "Execute o backfill administrativo antes de tentar novamente.",
    );
  }

  return atualizacoes;
}

function montarRemocaoRegistroPaciente({
  configuracao,
  dados,
  pacienteId,
  clinicaId,
  uidOperador,
}) {
  const removerCampo = admin.firestore.FieldValue.delete();
  const atualizacao = {
    ...camposTenant(clinicaId),
    pacienteId,
    vinculoLoginRemovidoEm: admin.firestore.FieldValue.serverTimestamp(),
    vinculoLoginRemovidoPor: uidOperador,
  };

  for (const campo of configuracao.camposId) {
    atualizacao[campo] = pacienteId;
  }
  for (const campo of CAMPOS_UID_PACIENTE) {
    atualizacao[campo] = removerCampo;
  }

  if (configuracao.payload &&
      dados.payload &&
      typeof dados.payload === "object") {
    const payloadAtualizado = {...dados.payload, pacienteId};
    for (const campo of configuracao.camposId) {
      payloadAtualizado[campo] = pacienteId;
    }
    for (const campo of CAMPOS_UID_PACIENTE) {
      delete payloadAtualizado[campo];
    }
    atualizacao.payload = payloadAtualizado;
  }

  return atualizacao;
}

async function prepararRemocoesVinculoPaciente({
  pacienteId,
  uidUsuario,
  clinicaId,
  uidOperador,
}) {
  const resultados = await Promise.all(
      COLECOES_VINCULO_PACIENTE.map(async (configuracao) => {
        const documentos = await buscarDocumentosDoTenant(
            configuracao.colecao,
            clinicaId,
        );
        const remocoes = [];

        for (const documento of documentos) {
          const dados = documento.data() || {};
          const {ids, uids} = identificadoresRegistroPaciente(
              configuracao,
              dados,
          );
          const idCorreto = ids.has(pacienteId);
          const uidCorreto = uids.has(uidUsuario);

          if (!idCorreto && !uidCorreto) continue;

          if (ids.size > 1 ||
              uids.size > 1 ||
              (ids.size > 0 && !idCorreto) ||
              (uids.size > 0 && !uidCorreto)) {
            throw new HttpsError(
                "failed-precondition",
                `Registro ${configuracao.colecao}/${documento.id} com ` +
                  "vinculo divergente durante a exclusao.",
            );
          }

          const tenant = resolverTenant(dados);
          if (!tenant.consistente || tenant.clinicaId !== clinicaId) {
            throw new HttpsError(
                "failed-precondition",
                `Registro ${configuracao.colecao}/${documento.id} fora ` +
                  "do tenant da paciente.",
            );
          }

          if (!uidCorreto) continue;

          remocoes.push({
            ref: documento.ref,
            dados: montarRemocaoRegistroPaciente({
              configuracao,
              dados,
              pacienteId,
              clinicaId,
              uidOperador,
            }),
            updateTime: documento.updateTime,
            colecao: configuracao.colecao,
          });
        }

        return remocoes;
      }),
  );
  const remocoes = resultados.flat();

  if (remocoes.length > MAX_REGISTROS_POR_VINCULO) {
    throw new HttpsError(
        "resource-exhausted",
        "A paciente possui registros demais para exclusao atomica. " +
          "Execute reconciliacao administrativa antes de tentar novamente.",
    );
  }

  return remocoes;
}

function exigirUidCompativel(dados, campos, uidUsuario, recurso) {
  const valores = valoresIdentificadores(dados, campos);

  if (valores.size > 1 ||
      (valores.size === 1 && !valores.has(uidUsuario))) {
    throw new HttpsError(
        "failed-precondition",
        `${recurso} ja esta vinculado a outro login.`,
    );
  }
}

function exigirIdsCompativeis(dados, campos, pacienteId, recurso) {
  const valores = valoresIdentificadores(dados, campos);

  if (valores.size > 1 ||
      (valores.size === 1 && !valores.has(pacienteId))) {
    throw new HttpsError(
        "failed-precondition",
        `${recurso} ja esta vinculado a outra paciente.`,
    );
  }
}

function validarPerfilPacienteParaVinculo({
  snapshot,
  uidUsuario,
  pacienteId,
  clinicaId,
}) {
  if (!snapshot.exists) return;

  const dados = snapshot.data() || {};
  const perfil = resolverPerfilUsuario(dados);
  const tenant = resolverTenant(dados);
  const status = textoSeguro(dados.status).toLowerCase();
  const uidDocumento = textoSeguro(dados.uid);

  if (!perfil.consistente ||
      perfil.perfil !== "gestante" ||
      !tenant.consistente ||
      (tenant.clinicaId && tenant.clinicaId !== clinicaId) ||
      (status && status !== "ativo") ||
      (uidDocumento && uidDocumento !== uidUsuario)) {
    throw new HttpsError(
        "failed-precondition",
        "Perfil de acesso incompatível com a paciente.",
    );
  }

  exigirIdsCompativeis(
      dados,
      CAMPOS_ID_PACIENTE,
      pacienteId,
      "Perfil de acesso",
  );
  exigirUidCompativel(
      dados,
      CAMPOS_UID_PACIENTE,
      uidUsuario,
      "Perfil de acesso",
  );
}

async function exigirUidSemOutraPaciente(uidUsuario, pacienteId) {
  const pacientes = await buscarPacientesPorUid(uidUsuario);

  for (const paciente of pacientes) {
    if (paciente.id !== pacienteId) {
      throw new HttpsError(
          "failed-precondition",
          "O login ja esta vinculado a outra paciente.",
      );
    }
  }
}

function contagensPorColecao(atualizacoes) {
  const contagens = {};

  for (const atualizacao of atualizacoes) {
    contagens[atualizacao.colecao] =
      (contagens[atualizacao.colecao] || 0) + 1;
  }

  return contagens;
}

function adicionarEscritaGuardadaAoBatch(batch, snapshot, dados) {
  if (snapshot.exists) {
    if (!snapshot.updateTime) {
      throw new HttpsError(
          "internal",
          "Snapshot sem versao para escrita concorrente segura.",
      );
    }

    batch.update(
        snapshot.ref,
        dados,
        {lastUpdateTime: snapshot.updateTime},
    );
    return;
  }

  batch.create(snapshot.ref, dados);
}

function conflitoConcorrenteFirestore(error) {
  return [
    "6",
    "9",
    "10",
    "aborted",
    "already-exists",
    "failed-precondition",
  ].includes(String(error && error.code || "").toLowerCase());
}

async function confirmarBatchGuardado(batch) {
  try {
    await batch.commit();
  } catch (error) {
    if (conflitoConcorrenteFirestore(error)) {
      throw new HttpsError(
          "failed-precondition",
          "Os dados foram alterados durante a operação. Revise e tente " +
            "novamente.",
      );
    }

    throw error;
  }
}

async function vincularUidAPaciente({
  contexto,
  uidUsuario,
  pacienteId,
  nomeUsuario,
  convitePendente = false,
  descritorOperacao = null,
}) {
  const uid = exigirIdDocumento(uidUsuario, "uidUsuario");
  const idPaciente = exigirIdDocumento(pacienteId, "pacienteId");

  const db = admin.firestore();
  const pacienteRef = db.collection("gestantes").doc(idPaciente);
  const usuarioRef = db.collection("usuarios").doc(uid);
  const usuarioSaaSRef = db.collection("usuariosSaaS").doc(uid);
  const lockUidRef = db.collection("vinculosAuthPaciente").doc(uid);
  const lockPacienteRef = db.collection("vinculosPacienteAuth").doc(idPaciente);
  const [
    pacienteSnapshot,
    usuarioSnapshot,
    usuarioSaaSSnapshot,
    lockUidSnapshot,
    lockPacienteSnapshot,
    usuarioAuth,
  ] = await Promise.all([
    pacienteRef.get(),
    usuarioRef.get(),
    usuarioSaaSRef.get(),
    lockUidRef.get(),
    lockPacienteRef.get(),
    admin.auth().getUser(uid),
  ]);

  if (!pacienteSnapshot.exists) {
    throw new HttpsError("not-found", "Paciente não encontrado.");
  }

  if (usuarioAuth.disabled ||
      !usuarioAuth.email ||
      (usuarioAuth.customClaims &&
       usuarioAuth.customClaims.superAdmin === true)) {
    throw new HttpsError(
        "failed-precondition",
        "Usuário de autenticação inválido para vínculo de paciente.",
    );
  }

  const paciente = pacienteSnapshot.data() || {};
  const clinicaId = exigirTenant(paciente, "Paciente");
  exigirAcessoAoTenant(contexto, clinicaId);
  await exigirClinicaAtiva(clinicaId);
  const usuarioCanonicoRef = db.doc(canonicalUserPath(clinicaId, uid));
  const pacienteCanonicoRef = db.doc(
      canonicalPatientPath(clinicaId, idPaciente),
  );
  const [usuarioCanonicoSnapshot, pacienteCanonicoSnapshot] =
    await Promise.all([
      usuarioCanonicoRef.get(),
      pacienteCanonicoRef.get(),
    ]);

  exigirIdsCompativeis(
      paciente,
      CAMPOS_ID_PACIENTE,
      idPaciente,
      "Paciente",
  );
  exigirUidCompativel(
      paciente,
      CAMPOS_UID_PACIENTE,
      uid,
      "Paciente",
  );
  validarPerfilPacienteParaVinculo({
    snapshot: usuarioSnapshot,
    uidUsuario: uid,
    pacienteId: idPaciente,
    clinicaId,
  });
  validarPerfilPacienteParaVinculo({
    snapshot: usuarioSaaSSnapshot,
    uidUsuario: uid,
    pacienteId: idPaciente,
    clinicaId,
  });

  for (const lock of [lockUidSnapshot, lockPacienteSnapshot]) {
    if (!lock.exists) continue;

    const dadosLock = lock.data() || {};
    const tenantLock = resolverTenant(dadosLock);

    if (!tenantLock.consistente ||
        tenantLock.clinicaId !== clinicaId ||
        textoSeguro(dadosLock.uidUsuario) !== uid ||
        textoSeguro(dadosLock.pacienteId) !== idPaciente) {
      throw new HttpsError(
          "failed-precondition",
          "O login ou a paciente ja possui outro vinculo registrado.",
      );
    }
  }

  await exigirUidSemOutraPaciente(uid, idPaciente);

  const atualizacoes = await prepararAtualizacoesVinculoPaciente({
    pacienteId: idPaciente,
    uidUsuario: uid,
    clinicaId,
    uidOperador: contexto.uid,
  });
  const destinosCanonicos = atualizacoes.flatMap((atualizacao) => {
    const path = canonicalPatientLinkedRecordPath({
      collection: atualizacao.colecao,
      documentId: atualizacao.ref.id,
      clinicaId,
      pacienteId: idPaciente,
    });

    if (!path) return [];

    return [{
      ref: db.doc(path),
      dados: atualizacao.dadosCanonicos,
      colecao: atualizacao.colecao,
    }];
  });
  const quantidadeOperacoes = countPatientLinkBatchWrites({
    legacyRecordWrites: atualizacoes.length,
    canonicalRecordWrites: destinosCanonicos.length,
    writesLegacyUser: usuarioSaaSSnapshot.exists,
  });

  const escritasJournal = descritorOperacao ? 1 : 0;

  if (quantidadeOperacoes + escritasJournal > MAX_SAFE_BATCH_WRITES) {
    throw new HttpsError(
        "resource-exhausted",
        "A vinculacao excede o limite seguro de escritas atomicas. " +
          "Execute o backfill administrativo antes de tentar novamente.",
    );
  }

  const snapshotsCanonicos = destinosCanonicos.length > 0 ?
    await db.getAll(...destinosCanonicos.map((item) => item.ref)) : [];
  const atualizacoesCanonicas = destinosCanonicos.map(
      (item, indice) => ({
        ...item,
        snapshot: snapshotsCanonicos[indice],
      }),
  );

  const agora = admin.firestore.FieldValue.serverTimestamp();
  const dadosUsuarioAtual = usuarioSnapshot.exists ?
    (usuarioSnapshot.data() || {}) : {};
  const nomeResolvido = textoSeguro(nomeUsuario) ||
    textoSeguro(dadosUsuarioAtual.nome) ||
    textoSeguro(paciente.nomeGestante);
  const dadosUsuario = {
    ...camposTenant(clinicaId),
    ...camposIdentidadePaciente(idPaciente, uid),
    uid,
    nome: nomeResolvido,
    email: textoSeguro(usuarioAuth.email).toLowerCase(),
    tipo: "gestante",
    tipoUsuario: "gestante",
    status: "ativo",
    acessoVinculadoEm: agora,
    acessoVinculadoPor: contexto.uid,
    atualizadoEm: agora,
  };
  const dadosPaciente = {
    ...camposTenant(clinicaId),
    ...camposIdentidadePaciente(idPaciente, uid),
    emailAcesso: textoSeguro(usuarioAuth.email).toLowerCase(),
    acessoCriado: "true",
    acessoVinculadoEm: agora,
    acessoVinculadoPor: contexto.uid,
  };

  if (!usuarioSnapshot.exists) {
    dadosUsuario.criadoEm = agora;
  }

  if (convitePendente) {
    dadosUsuario.conviteSenhaPendente = true;
    dadosUsuario.conviteSenhaSolicitadoEm = agora;
    dadosUsuario.primeiroLogin = false;
    dadosPaciente.conviteSenhaPendente = true;
    dadosPaciente.conviteSenhaSolicitadoEm = agora;
    dadosPaciente.linkSenhaInicial = admin.firestore.FieldValue.delete();
    dadosPaciente.linkSenhaInicialGeradoEm =
      admin.firestore.FieldValue.delete();
    dadosPaciente.linkSenhaInicialExpirado = true;
  }

  const dadosUsuarioCanonico = {...dadosUsuarioAtual, ...dadosUsuario};
  const dadosPacienteCanonico = {...paciente, ...dadosPaciente};
  if (!pacienteCanonicoSnapshot.exists && convitePendente) {
    delete dadosPacienteCanonico.linkSenhaInicial;
    delete dadosPacienteCanonico.linkSenhaInicialGeradoEm;
  }
  const commitOperacao = descritorOperacao ?
    await prepararCommitOperacao(db, descritorOperacao) : null;

  if (commitOperacao && commitOperacao.concluida) {
    return {
      uidUsuario: uid,
      pacienteId: idPaciente,
      clinicaId,
      registrosAtualizados: contagensPorColecao(atualizacoes),
      conviteSenhaPendente: convitePendente,
    };
  }

  const batch = db.batch();

  for (const atualizacao of atualizacoes) {
    batch.update(
        atualizacao.ref,
        atualizacao.dados,
        {lastUpdateTime: atualizacao.updateTime},
    );
  }
  for (const atualizacao of atualizacoesCanonicas) {
    adicionarEscritaGuardadaAoBatch(
        batch,
        atualizacao.snapshot,
        atualizacao.dados,
    );
  }

  adicionarEscritaGuardadaAoBatch(batch, usuarioSnapshot, dadosUsuario);
  adicionarEscritaGuardadaAoBatch(batch, pacienteSnapshot, dadosPaciente);
  adicionarEscritaGuardadaAoBatch(
      batch,
      usuarioCanonicoSnapshot,
      dadosUsuarioCanonico,
  );
  adicionarEscritaGuardadaAoBatch(
      batch,
      pacienteCanonicoSnapshot,
      dadosPacienteCanonico,
  );

  if (usuarioSaaSSnapshot.exists) {
    adicionarEscritaGuardadaAoBatch(
        batch,
        usuarioSaaSSnapshot,
        dadosUsuario,
    );
  }

  const dadosLock = {
    ...camposTenant(clinicaId),
    uidUsuario: uid,
    pacienteId: idPaciente,
    atualizadoEm: agora,
    atualizadoPor: contexto.uid,
  };

  if (lockUidSnapshot.exists) {
    adicionarEscritaGuardadaAoBatch(batch, lockUidSnapshot, dadosLock);
  } else {
    batch.create(lockUidRef, {...dadosLock, criadoEm: agora});
  }

  if (lockPacienteSnapshot.exists) {
    adicionarEscritaGuardadaAoBatch(
        batch,
        lockPacienteSnapshot,
        dadosLock,
    );
  } else {
    batch.create(lockPacienteRef, {...dadosLock, criadoEm: agora});
  }

  const contagens = contagensPorColecao(atualizacoes);
  const logRef = descritorOperacao ?
    db.collection("logsAdministrativos")
        .doc(descritorOperacao.recursos.logId) :
    db.collection("logsAdministrativos").doc();
  const dadosLog = {
    ...camposTenant(clinicaId),
    acao: "vincular_login_paciente",
    usuarioUid: contexto.uid,
    uidVinculado: uid,
    pacienteId: idPaciente,
    registrosAtualizados: contagens,
    convitePendente,
    criadoEm: agora,
  };

  if (descritorOperacao) {
    batch.create(logRef, dadosLog);
    adicionarCommitAoBatch(batch, commitOperacao);
  } else {
    batch.set(logRef, dadosLog);
  }

  await confirmarBatchGuardado(batch);

  return {
    uidUsuario: uid,
    pacienteId: idPaciente,
    clinicaId,
    registrosAtualizados: contagens,
    conviteSenhaPendente: convitePendente,
  };
}

async function prepararDestinoCriacaoUsuario({
  contexto,
  tipoUsuario,
  idVinculo,
}) {
  if (tipoUsuario === "admin") {
    if (contexto.perfil !== "admin" || idVinculo) {
      throw new HttpsError(
          "invalid-argument",
          "Administrador de clinica deve ser criado pelo admin do tenant " +
            "sem idVinculo.",
      );
    }

    return {
      clinicaId: contexto.clinicaId,
      entidadeRef: null,
      campoUid: "",
      uidsAtuais: new Set(),
    };
  }

  const configuracoes = {
    gestante: {
      colecao: "gestantes",
      campoUid: "uidGestante",
      camposUid: ["uidGestante", "uidPaciente"],
      recurso: "Paciente",
    },
    enfermeira: {
      colecao: "enfermeiras",
      campoUid: "uidEnfermeira",
      camposUid: ["uidEnfermeira", "uidProfissional"],
      recurso: "Profissional",
    },
    obstetra: {
      colecao: "obstetras",
      campoUid: "uidObstetra",
      camposUid: ["uidObstetra", "uidProfissional"],
      recurso: "Profissional",
    },
  };
  const configuracao = configuracoes[tipoUsuario];
  const id = exigirIdDocumento(idVinculo, "idVinculo");

  if (!configuracao) {
    throw new HttpsError(
        "invalid-argument",
        "idVinculo e obrigatorio para o tipo de usuario informado.",
    );
  }

  const entidadeRef = admin
      .firestore()
      .collection(configuracao.colecao)
      .doc(id);
  const entidadeSnapshot = await entidadeRef.get();

  if (!entidadeSnapshot.exists) {
    throw new HttpsError(
        "not-found",
        `${configuracao.recurso} não encontrado.`,
    );
  }

  const entidade = entidadeSnapshot.data() || {};
  const clinicaId = exigirTenant(entidade, configuracao.recurso);
  exigirAcessoAoTenant(contexto, clinicaId);
  await exigirClinicaAtiva(clinicaId);

  const uidsAtuais = valoresIdentificadores(
      entidade,
      configuracao.camposUid,
  );

  return {
    clinicaId,
    entidadeRef,
    entidadeSnapshot,
    campoUid: configuracao.campoUid,
    camposUid: configuracao.camposUid,
    idVinculo: id,
    uidsAtuais,
    recurso: configuracao.recurso,
  };
}

async function gravarUsuarioClinicaCriado({
  contexto,
  usuarioAuth,
  nome,
  tipoUsuario,
  destino,
  descritorOperacao,
}) {
  const db = admin.firestore();
  const uid = usuarioAuth.uid;
  const usuarioRef = db.collection("usuarios").doc(uid);
  const usuarioCanonicoRef = db.doc(
      canonicalUserPath(destino.clinicaId, uid),
  );
  const usuarioSnapshot = await usuarioRef.get();

  if (usuarioSnapshot.exists) {
    throw new HttpsError(
        "already-exists",
        "Ja existe um perfil para o usuario criado.",
    );
  }

  let entidadeSnapshot = destino.entidadeSnapshot;

  if (destino.entidadeRef) {
    entidadeSnapshot = await destino.entidadeRef.get();

    if (!entidadeSnapshot.exists) {
      throw new HttpsError(
          "failed-precondition",
          "Registro de vinculo nao existe mais.",
      );
    }

    const entidade = entidadeSnapshot.data() || {};
    const tenantEntidade = resolverTenant(entidade);

    if (!tenantEntidade.consistente ||
        tenantEntidade.clinicaId !== destino.clinicaId) {
      throw new HttpsError(
          "failed-precondition",
          "Registro de vínculo mudou de clínica durante a operação.",
      );
    }

    const uidsAtuais = valoresIdentificadores(
        entidade,
        destino.camposUid,
    );

    if (uidsAtuais.size > 0) {
      throw new HttpsError(
          "failed-precondition",
          "Registro profissional ja possui outro login.",
      );
    }
  }

  const agora = admin.firestore.FieldValue.serverTimestamp();
  const dadosUsuario = {
    ...camposTenant(destino.clinicaId),
    uid,
    nome,
    email: textoSeguro(usuarioAuth.email).toLowerCase(),
    tipo: tipoUsuario,
    tipoUsuario,
    status: "ativo",
    pacienteId: "",
    idGestante: "",
    uidGestante: "",
    idVinculo: destino.idVinculo || "",
    primeiroLogin: false,
    conviteSenhaPendente: true,
    conviteSenhaSolicitadoEm: agora,
    criadoEm: agora,
    criadoPorUid: contexto.uid,
  };
  const commitOperacao = await prepararCommitOperacao(
      db,
      descritorOperacao,
  );

  if (commitOperacao.concluida) {
    return resultadoUsuarioCriado({
      descritorOperacao,
      tipoUsuario,
      destino,
    });
  }

  const batch = db.batch();
  batch.create(usuarioRef, dadosUsuario);
  batch.create(usuarioCanonicoRef, dadosUsuario);

  if (destino.entidadeRef) {
    const dadosEntidade = {
      ...camposTenant(destino.clinicaId),
      [destino.campoUid]: uid,
      uidProfissional: uid,
      acessoVinculadoEm: agora,
      acessoVinculadoPor: contexto.uid,
      conviteSenhaPendente: true,
      conviteSenhaSolicitadoEm: agora,
    };
    batch.update(
        destino.entidadeRef,
        dadosEntidade,
        {lastUpdateTime: entidadeSnapshot.updateTime},
    );

    const lockUidRef = db.collection("vinculosAuthEntidade").doc(uid);
    const lockEntidadeRef = db
        .collection("vinculosEntidadeAuth")
        .doc(`${tipoUsuario}_${destino.idVinculo}`);
    const dadosLock = {
      ...camposTenant(destino.clinicaId),
      uidUsuario: uid,
      tipoUsuario,
      idVinculo: destino.idVinculo,
      criadoEm: agora,
    };
    batch.create(lockUidRef, dadosLock);
    batch.create(lockEntidadeRef, dadosLock);
  }

  const logRef = db.collection("logsAdministrativos")
      .doc(descritorOperacao.recursos.logId);
  batch.create(logRef, {
    ...camposTenant(destino.clinicaId),
    acao: "criar_usuario_clinica",
    usuarioUid: contexto.uid,
    uidCriado: uid,
    tipoUsuario,
    idVinculo: destino.idVinculo || "",
    convitePendente: true,
    criadoEm: agora,
  });
  adicionarCommitAoBatch(batch, commitOperacao);

  await confirmarBatchGuardado(batch);

  return {
    uidUsuario: uid,
    tipoUsuario,
    idVinculo: destino.idVinculo || "",
    clinicaId: destino.clinicaId,
    conviteSenhaPendente: true,
    registrosAtualizados: {},
  };
}

async function rollbackUsuarioAuth(uidUsuario) {
  try {
    await admin.auth().deleteUser(uidUsuario);
    return true;
  } catch (error) {
    logSafeError(
        "Falha critica ao reverter usuario do Firebase Authentication.",
        error,
    );
    return false;
  }
}

function resultadoUsuarioCriado({
  descritorOperacao,
  tipoUsuario,
  destino,
}) {
  const resultado = {
    uidUsuario: descritorOperacao.recursos.authUid,
    tipoUsuario,
    idVinculo: destino.idVinculo || "",
    clinicaId: destino.clinicaId,
    conviteSenhaPendente: true,
    registrosAtualizados: {},
  };

  if (tipoUsuario === "gestante") {
    resultado.pacienteId = destino.idVinculo;
  }

  return resultado;
}

function resultadoClinicaCriada(descritorOperacao) {
  return {
    clinicaId: descritorOperacao.recursos.clinicId,
    adminUid: descritorOperacao.recursos.authUid,
    assinaturaId: descritorOperacao.recursos.subscriptionId,
    statusClinica: "teste",
    statusAssinatura: "ativa",
    primeiroLogin: false,
    conviteSenhaPendente: true,
  };
}

async function operacaoDuravelConcluida(descritorOperacao) {
  const dados = await consultarOperacao(
      admin.firestore(),
      descritorOperacao,
  );
  return dados && dados.estado === OPERATION_STATE.COMMITTED;
}

function erroDuravelParaHttps(error) {
  if (!(error instanceof DurableOperationError)) return null;

  if ([
    "auth-identity-conflict",
    "operation-payload-conflict",
    "operation-requires-reconciliation",
  ].includes(error.code)) {
    return new HttpsError(
        "already-exists",
        "A operação conflita com um cadastro existente.",
    );
  }

  if ([
    "invalid-auth-resource",
    "invalid-operation-input",
    "invalid-operation-kind",
    "invalid-operation-payload",
  ].includes(error.code)) {
    return new HttpsError("invalid-argument", "Dados da operação inválidos.");
  }

  return new HttpsError(
      "internal",
      "Não foi possível validar o estado durável da operação.",
  );
}

function falhaPermanenteDePersistencia(error) {
  if (error instanceof HttpsError) {
    return [
      "already-exists",
      "failed-precondition",
      "invalid-argument",
      "not-found",
      "permission-denied",
      "resource-exhausted",
    ].includes(error.code);
  }

  return ["3", "6", "already-exists", "invalid-argument"]
      .includes(String(error && error.code || ""));
}

async function tentarResolverConcorrencia(descritorOperacao) {
  try {
    return await operacaoDuravelConcluida(descritorOperacao);
  } catch (error) {
    console.error(
        "Falha ao consultar estado da operacao duravel:",
        error && error.code || "erro_desconhecido",
    );
    return false;
  }
}

async function prepararRetentativaFirestore(descritorOperacao) {
  try {
    const estado = await marcarFirestoreParaRetentativa(
        admin.firestore(),
        descritorOperacao,
    );
    return estado === OPERATION_STATE.COMMITTED;
  } catch (error) {
    if (error instanceof DurableOperationError &&
        error.code === "operation-already-committed") {
      return true;
    }

    console.error(
        "Falha ao marcar retentativa da operacao duravel:",
        error && error.code || "erro_desconhecido",
    );
    return tentarResolverConcorrencia(descritorOperacao);
  }
}

async function rollbackDuravelSeguro(descritorOperacao) {
  try {
    const estado = await marcarRollbackNecessario(
        admin.firestore(),
        descritorOperacao,
        "domain_rollback_required",
    );

    if (estado === OPERATION_STATE.COMMITTED) {
      return {concluido: false, operacaoJaConcluida: true};
    }

    const concluido = await reverterUsuarioAuth({
      auth: admin.auth(),
      db: admin.firestore(),
      descritor: descritorOperacao,
    });
    return {concluido, operacaoJaConcluida: false};
  } catch (error) {
    if (error instanceof DurableOperationError &&
        error.code === "operation-already-committed") {
      return {concluido: false, operacaoJaConcluida: true};
    }

    console.error(
        "Falha no rollback da operacao duravel:",
        error && error.code || "erro_desconhecido",
    );
    return {concluido: false, operacaoJaConcluida: false};
  }
}

function exigirTextoCriacao(valor, campo, tamanhoMaximo) {
  const texto = typeof valor === "string" ? textoSeguro(valor) : "";
  const possuiControle = Array.from(texto).some((caractere) => {
    const codigo = caractere.charCodeAt(0);
    return codigo <= 31 || codigo === 127;
  });

  if (!texto || texto.length > tamanhoMaximo || possuiControle) {
    throw new HttpsError(
        "invalid-argument",
        `${campo} inválido.`,
    );
  }

  return texto;
}

function exigirValorAssinaturaSaaS(valor) {
  if (typeof valor !== "number" ||
      !Number.isFinite(valor) ||
      valor < 0 ||
      valor > 1000000000) {
    throw new HttpsError(
        "invalid-argument",
        "valorAssinatura deve ser um numero valido e nao negativo.",
    );
  }

  return Math.round((valor + Number.EPSILON) * 100) / 100;
}

async function gravarClinicaComAdminSaaS({
  contexto,
  usuarioAuth,
  nomeClinica,
  nomeAdmin,
  emailAdmin,
  plano,
  valorAssinatura,
  descritorOperacao,
}) {
  const db = admin.firestore();
  const recursos = descritorOperacao.recursos;
  const clinicaRef = db.collection("clinicas").doc(recursos.clinicId);
  const clinicaId = clinicaRef.id;
  const clinicaSaaSRef = db.collection("clinicasSaaS").doc(clinicaId);
  const usuarioRef = db.collection("usuarios").doc(usuarioAuth.uid);
  const usuarioSaaSRef = db.collection("usuariosSaaS").doc(usuarioAuth.uid);
  const usuarioCanonicoRef = db.doc(
      canonicalUserPath(clinicaId, usuarioAuth.uid),
  );
  const assinaturaRef = db.collection("assinaturasSaaS")
      .doc(recursos.subscriptionId);
  const logRef = db.collection("logsSuperAdmin").doc(recursos.logId);
  const agora = admin.firestore.FieldValue.serverTimestamp();
  const vencimento = admin.firestore.Timestamp.fromMillis(
      Date.now() + (30 * 24 * 60 * 60 * 1000),
  );
  const tenant = camposTenant(clinicaId);
  const dadosClinica = {
    id: clinicaId,
    ...tenant,
    nome: nomeClinica,
    emailAdmin,
    plano,
    status: "teste",
    adminUid: usuarioAuth.uid,
    criadoEm: agora,
    criadoPorUid: contexto.uid,
  };
  const dadosUsuario = {
    id: usuarioAuth.uid,
    uid: usuarioAuth.uid,
    ...tenant,
    nome: nomeAdmin,
    email: emailAdmin,
    tipo: "admin",
    tipoUsuario: "admin",
    status: "ativo",
    pacienteId: "",
    idGestante: "",
    uidGestante: "",
    idVinculo: "",
    primeiroLogin: false,
    conviteSenhaPendente: true,
    conviteSenhaSolicitadoEm: agora,
    authCriado: true,
    criadoViaSuperAdmin: true,
    criadoEm: agora,
    criadoPorUid: contexto.uid,
  };
  const dadosAssinatura = {
    id: assinaturaRef.id,
    ...tenant,
    clinicaNome: nomeClinica,
    adminUid: usuarioAuth.uid,
    emailAdmin,
    plano,
    status: "ativa",
    valor: valorAssinatura,
    vencimento,
    criadoEm: agora,
    criadoPorUid: contexto.uid,
  };
  const dadosLog = {
    id: logRef.id,
    ...tenant,
    acao: "criar_clinica_com_admin_saas_backend",
    usuarioUid: contexto.uid,
    dados: {
      ...tenant,
      clinicaId,
      adminUid: usuarioAuth.uid,
      assinaturaId: assinaturaRef.id,
      nomeClinica,
      nomeAdmin,
      emailAdmin,
      plano,
      valorAssinatura,
      authCriado: true,
      primeiroLogin: false,
      conviteSenhaPendente: true,
    },
    criadoEm: agora,
  };
  const commitOperacao = await prepararCommitOperacao(
      db,
      descritorOperacao,
  );

  if (commitOperacao.concluida) {
    return resultadoClinicaCriada(descritorOperacao);
  }

  const batch = db.batch();

  batch.create(clinicaRef, dadosClinica);
  batch.create(clinicaSaaSRef, dadosClinica);
  batch.create(usuarioRef, dadosUsuario);
  batch.create(usuarioSaaSRef, dadosUsuario);
  batch.create(usuarioCanonicoRef, dadosUsuario);
  batch.create(assinaturaRef, dadosAssinatura);
  batch.create(logRef, dadosLog);
  adicionarCommitAoBatch(batch, commitOperacao);

  await batch.commit();

  return {
    clinicaId,
    adminUid: usuarioAuth.uid,
    assinaturaId: assinaturaRef.id,
    statusClinica: "teste",
    statusAssinatura: "ativa",
    primeiroLogin: false,
    conviteSenhaPendente: true,
  };
}

function somenteDigitos(valor) {
  return String(valor || "").replace(/\D/g, "");
}

function normalizarTelefone(telefone) {
  const digitos = somenteDigitos(telefone);

  if (!digitos) {
    return {
      countryCode: "",
      number: "",
    };
  }

  if (digitos.startsWith("55") && digitos.length > 11) {
    return {
      countryCode: "55",
      number: digitos.slice(2),
    };
  }

  return {
    countryCode: "55",
    number: digitos,
  };
}

function converterNumeroContrato(valor) {
  if (typeof valor === "number") {
    return Number.isFinite(valor) ? valor : 0;
  }

  const texto = String(valor || "").trim();

  if (!texto) {
    return 0;
  }

  const normalizado = texto
      .replace(/\s/g, "")
      .replace("R$", "")
      .replace(/\./g, "")
      .replace(",", ".");

  const numero = Number(normalizado);

  return Number.isFinite(numero) ? numero : 0;
}

function formatarMoedaContrato(valor) {
  const numero = converterNumeroContrato(valor);

  if (!Number.isFinite(numero)) {
    return "R$ 0,00";
  }

  return numero.toLocaleString("pt-BR", {
    style: "currency",
    currency: "BRL",
  });
}

function formatarDataAssinatura(valor) {
  if (!valor) {
    return new Date().toLocaleDateString("pt-BR");
  }

  const data = new Date(valor);

  if (Number.isNaN(data.getTime())) {
    return String(valor);
  }

  return data.toLocaleDateString("pt-BR");
}

function formatarDataHoraDocumento(valor) {
  const data = valor instanceof Date ? valor : new Date(valor);

  if (Number.isNaN(data.getTime())) {
    return "";
  }

  const dia = String(data.getDate()).padStart(2, "0");
  const mes = String(data.getMonth() + 1).padStart(2, "0");
  const ano = String(data.getFullYear());
  const hora = String(data.getHours()).padStart(2, "0");
  const minuto = String(data.getMinutes()).padStart(2, "0");

  return `${dia}/${mes}/${ano} ${hora}:${minuto}`;
}

function normalizarStatusContrato(zapsignStatus) {
  const valor = String(zapsignStatus || "").trim().toLowerCase();

  if (!valor) {
    return "processando";
  }

  if (["signed", "completed", "finalized"].includes(valor)) {
    return "assinado";
  }

  if (["refused", "rejected"].includes(valor)) {
    return "recusado";
  }

  if (["cancelled", "canceled"].includes(valor)) {
    return "cancelado";
  }

  if (valor === "expired") {
    return "expirado";
  }

  if (["pending", "in_progress", "processing"].includes(valor)) {
    return "enviado";
  }

  return valor;
}

async function buscarConfiguracaoZapSign() {
  const ref = admin.firestore().doc(ZAPSIGN_CONFIG_PATH);
  const snapshot = await ref.get();

  if (!snapshot.exists) {
    const configuracaoPadrao = {
      ativo: true,
      lang: "pt-br",
      disableSignerEmails: false,
      brandName: "Natus",
      brandPrimaryColor: "#6F3E46",
      brandLogo: "",
      folderToken: "",
      templateIds: ZAPSIGN_TEMPLATE_IDS_PADRAO,
      placeholdersFixos: {
        razaoSocialNatus: "Natus",
        cnpjNatus: "63.395.279/0001-70",
        enderecoNatus: "",
        representanteLegal: "Maressa Valentim dos Santos Bandeira",
        cpfRepresentante: "103.605.559-00",
        profissionalResponsavel: "",
      },
      atualizadoEm: new Date().toISOString(),
      criadoAutomaticamenteEm: new Date().toISOString(),
    };

    await ref.set(configuracaoPadrao, {merge: true});
    return configuracaoPadrao;
  }

  const dados = snapshot.data() || {};

  return {
    ativo: dados.ativo !== false,
    lang: dados.lang || "pt-br",
    disableSignerEmails: dados.disableSignerEmails === true,
    brandName: dados.brandName || "Natus",
    brandPrimaryColor: dados.brandPrimaryColor || "#6F3E46",
    brandLogo: dados.brandLogo || "",
    folderToken: dados.folderToken || "",
    templateIds: {
      ...ZAPSIGN_TEMPLATE_IDS_PADRAO,
      ...(dados.templateIds || {}),
    },
    placeholdersFixos: dados.placeholdersFixos || {},
  };
}

function montarPayloadContratoDaGestante(idGestante, dados) {
  const templateKey =
    dados.contratoTemplateKey ||
    descobrirTemplateKeyContrato(dados.plano || "", dados.consultorio || "");
  const definicaoPlano = ZAPSIGN_PLANOS_POR_TEMPLATE[templateKey] || {};
  const partesEndereco = [
    dados.enderecoGestante || "",
    dados.numeroGestante || "",
    dados.complementoGestante || "",
    dados.bairroGestante || "",
    dados.cidadeGestante || "",
    dados.estadoGestante || "",
    dados.cepGestante || "",
  ].filter((parte) => String(parte || "").trim());
  const uidsPaciente = valoresIdentificadores(dados, CAMPOS_UID_PACIENTE);
  if (uidsPaciente.size > 1) {
    throw new Error("Paciente com aliases UID divergentes.");
  }
  const uidPaciente = uidsPaciente.size === 1 ? [...uidsPaciente][0] : "";

  return {
    ...camposIdentidadePaciente(idGestante, uidPaciente),
    nomePaciente: dados.nomeGestante || "",
    emailPaciente: dados.emailGestante || "",
    telefonePaciente: dados.telefoneGestante || "",
    cpfPaciente: dados.cpfGestante || "",
    rgPaciente: dados.rgGestante || "",
    enderecoPaciente: partesEndereco.join(", "),
    nomeResponsavel: dados.nomePai || "",
    emailResponsavel: dados.emailPai || "",
    telefoneResponsavel: dados.telefonePai || "",
    cpfResponsavel: dados.cpfPai || "",
    rgResponsavel: dados.rgPai || "",
    enderecoResponsavel: partesEndereco.join(", "),
    dpp: dados.dpp || "",
    planoNome: definicaoPlano.planoNome || dados.plano || "",
    modalidadeNome: definicaoPlano.modalidadeNome ||
      (dados.contratoResumo && dados.contratoResumo.modalidadeNome ?
      dados.contratoResumo.modalidadeNome :
      (dados.consultorio === "Sim" ? "Consultorio" : "Residencial")),
    templateKey,
    cidadeAssinatura: dados.cidadeGestante || "Curitiba",
    dataAssinatura: new Date().toISOString(),
    formaPagamento: dados.formaPagamento || "",
    vencimentoParcelas: dados.vencimentoParcelas || "",
    observacoesContrato: dados.observacoesContrato || "",
    numeroParcelas: Number.parseInt(dados.parcelas || "1", 10) || 1,
    valorTotal: dados.contratoResumo && dados.contratoResumo.valorTotal ?
      dados.contratoResumo.valorTotal :
      dados.valorPlano || 0,
    valorEntrada: dados.contratoResumo && dados.contratoResumo.valorEntrada ?
      dados.contratoResumo.valorEntrada :
      dados.entrada || 0,
    valorSaldo: dados.contratoResumo && dados.contratoResumo.valorSaldo ?
      dados.contratoResumo.valorSaldo :
      0,
    valorParcela: dados.contratoResumo && dados.contratoResumo.valorParcela ?
      dados.contratoResumo.valorParcela :
      dados.valorParcela || 0,
  };
}

function montarCamposDinamicos(payload, configuracao) {
  const fixos = configuracao.placeholdersFixos || {};

  const placeholders = {
    "{{nome_cliente}}": payload.nomePaciente || "",
    "{{cpf_cliente}}": payload.cpfPaciente || "",
    "{{rg_cliente}}": payload.rgPaciente || "",
    "{{endereco_cliente}}": payload.enderecoPaciente || "",
    "{{telefone_cliente}}": payload.telefonePaciente || "",
    "{{email_cliente}}": payload.emailPaciente || "",
    "{{nome_acompanhante}}": payload.nomeResponsavel || "",
    "{{cpf_acompanhante}}": payload.cpfResponsavel || "",
    "{{endereco_acompanhante}}": payload.enderecoResponsavel || "",
    "{{nome_esposa}}": payload.nomePaciente || "",
    "{{rg_esposa}}": payload.rgPaciente || "",
    "{{cpf_esposa}}": payload.cpfPaciente || "",
    "{{nome_esposo}}": payload.nomeResponsavel || "",
    "{{rg_esposo}}": payload.rgResponsavel || "",
    "{{cpf_esposo}}": payload.cpfResponsavel || "",
    "{{endereco_contratantes}}":
      payload.enderecoPaciente || payload.enderecoResponsavel || "",
    "{{data_assinatura}}": formatarDataAssinatura(payload.dataAssinatura),
    "{{cidade_assinatura}}": payload.cidadeAssinatura || "Curitiba",
    "{{plano_nome}}": payload.planoNome || "",
    "{{modalidade_nome}}": payload.modalidadeNome || "",
    "{{valor_total}}": formatarMoedaContrato(payload.valorTotal),
    "{{valor_entrada}}": formatarMoedaContrato(payload.valorEntrada),
    "{{valor_saldo}}": formatarMoedaContrato(payload.valorSaldo),
    "{{numero_parcelas}}": String(payload.numeroParcelas || ""),
    "{{valor_parcela}}": formatarMoedaContrato(payload.valorParcela),
    "{{vencimento_parcelas}}": payload.vencimentoParcelas || "",
    "{{forma_pagamento}}": payload.formaPagamento || "",
    "{{razao_social_natus}}": fixos.razaoSocialNatus || "Natus",
    "{{cnpj_natus}}": fixos.cnpjNatus || "63.395.279/0001-70",
    "{{endereco_natus}}": fixos.enderecoNatus || "",
    "{{representante_legal}}":
      fixos.representanteLegal || "Maressa Valentim dos Santos Bandeira",
    "{{cpf_representante}}": fixos.cpfRepresentante || "103.605.559-00",
    "{{dpp}}": payload.dpp || "",
    "{{observacoes_contrato}}": payload.observacoesContrato || "",
    "{{profissional_responsavel}}": fixos.profissionalResponsavel || "",
  };

  return Object.entries(placeholders).map(([de, para]) => ({
    de,
    para: String(para || ""),
  }));
}

function extrairTokenAssinatura(signatario) {
  return signatario.token ||
    signatario.signer_token ||
    signatario.sign_url_token ||
    "";
}

function extrairLinkAssinatura(signatario) {
  const linkDireto = signatario.sign_url || signatario.signer_url || "";

  if (linkDireto) {
    return linkDireto;
  }

  const token = extrairTokenAssinatura(signatario);
  return token ? `${ZAPSIGN_SIGNER_BASE_URL}/${token}` : "";
}

function mapearSignatariosZapSign(signers) {
  if (!Array.isArray(signers)) {
    return [];
  }

  return signers.map((signer) => ({
    token: extrairTokenAssinatura(signer),
    signUrl: extrairLinkAssinatura(signer),
    nome: signer.name || signer.signer_name || "",
    email: signer.email || "",
    telefone: signer.phone_number || signer.phone || "",
    status: signer.status || "",
    qualificacao: signer.qualification || "",
  }));
}

function montarLinkAssinaturaPrincipal(signers) {
  const signatarios = mapearSignatariosZapSign(signers);

  if (signatarios.length === 0) {
    return {
      signerToken: "",
      signerUrl: "",
    };
  }

  return {
    signerToken: signatarios[0].token || "",
    signerUrl: signatarios[0].signUrl || "",
  };
}

function montarSignatario({
  nome,
  email,
  telefone,
  qualificacao,
  configuracao,
}) {
  const telefoneNormalizado = normalizarTelefone(telefone);
  const signatario = {
    name: String(nome || "").trim(),
    auth_mode: "assinaturaTela",
    qualification: qualificacao || "",
    send_automatic_email:
      configuracao.disableSignerEmails !== true && Boolean(email),
    lock_name: true,
    lock_email: Boolean(email),
    lock_phone: Boolean(telefoneNormalizado.number),
  };

  if (email) {
    signatario.email = String(email || "").trim();
  }

  if (telefoneNormalizado.countryCode && telefoneNormalizado.number) {
    signatario.phone_country = telefoneNormalizado.countryCode;
    signatario.phone_number = telefoneNormalizado.number;
  }

  return signatario;
}

function montarSignatariosContrato(payload, configuracao) {
  const fixos = configuracao.placeholdersFixos || {};
  const signatarios = [];

  if (payload.nomePaciente) {
    signatarios.push(montarSignatario({
      nome: payload.nomePaciente,
      email: payload.emailPaciente,
      telefone: payload.telefonePaciente,
      qualificacao: "Paciente",
      configuracao,
    }));
  }

  if (payload.nomeResponsavel) {
    signatarios.push(montarSignatario({
      nome: payload.nomeResponsavel,
      email: payload.emailResponsavel,
      telefone: payload.telefoneResponsavel,
      qualificacao: "Responsavel",
      configuracao,
    }));
  }

  const nomeRepresentante = String(fixos.representanteLegal || "").trim();
  if (nomeRepresentante) {
    signatarios.push(montarSignatario({
      nome: nomeRepresentante,
      email: fixos.emailRepresentante || "",
      telefone: fixos.telefoneRepresentante || "",
      qualificacao: "Representante legal da clinica",
      configuracao,
    }));
  }

  return signatarios.filter((signatario) => signatario.name);
}

function montarPayloadCriacaoDocumento({
  contratoId,
  payload,
  configuracao,
  templateId,
}) {
  const signatarios = montarSignatariosContrato(payload, configuracao);
  const signatarioPrincipal = signatarios[0] || {};

  const body = {
    template_id: templateId,
    signer_name: signatarioPrincipal.name || payload.nomePaciente || "Paciente",
    data: montarCamposDinamicos(payload, configuracao),
    lang: configuracao.lang || "pt-br",
    disable_signer_emails: configuracao.disableSignerEmails === true,
  };

  if (signatarioPrincipal.email) {
    body.signer_email = signatarioPrincipal.email;
  }

  if (signatarioPrincipal.phone_country && signatarioPrincipal.phone_number) {
    body.signer_phone_country = signatarioPrincipal.phone_country;
    body.signer_phone_number = signatarioPrincipal.phone_number;
  }

  if (configuracao.brandLogo) {
    body.brand_logo = configuracao.brandLogo;
  }

  if (configuracao.brandPrimaryColor) {
    body.brand_primary_color = configuracao.brandPrimaryColor;
  }

  if (configuracao.brandName) {
    body.brand_name = configuracao.brandName;
  }

  if (configuracao.folderToken) {
    body.folder_token = configuracao.folderToken;
  }

  body.name = `${payload.planoNome || "Contrato"} - ${payload.nomePaciente || contratoId}`;

  return body;
}

async function adicionarSignatariosSecundarios({
  zapsignDocumentId,
  signatarios,
  apiToken,
}) {
  if (!zapsignDocumentId || !Array.isArray(signatarios) || signatarios.length <= 1) {
    return [];
  }

  const signatariosAdicionados = [];

  for (const signatario of signatarios.slice(1)) {
    const resposta = await chamarZapSign({
      method: "POST",
      path: `/docs/${zapsignDocumentId}/add-signer/`,
      apiToken,
      body: signatario,
    });

    signatariosAdicionados.push(resposta);
  }

  return signatariosAdicionados;
}

async function atualizarGestanteComContrato(pacienteId, dados, clinicaId) {
  const id = textoSeguro(pacienteId);

  if (!id) {
    throw new HttpsError(
        "failed-precondition",
        "Contrato sem paciente vinculado.",
    );
  }

  const tenantId = exigirTenant(camposTenant(clinicaId), "Paciente");

  await admin.firestore().collection("gestantes").doc(id).set({
    ...dados,
    ...camposTenant(tenantId),
  }, {merge: true});
}

async function atualizarContrato(contratoId, dados, clinicaId) {
  const id = textoSeguro(contratoId);
  const tenantId = exigirTenant(camposTenant(clinicaId), "Contrato");

  if (!id) {
    throw new HttpsError("invalid-argument", "ContratoId nao informado.");
  }

  await admin.firestore().collection("contratos").doc(id).set({
    ...dados,
    ...camposTenant(tenantId),
  }, {merge: true});
}

async function buscarGestantePorId(pacienteId) {
  if (!pacienteId) {
    return {};
  }

  const snapshot = await admin
      .firestore()
      .collection("gestantes")
      .doc(pacienteId)
      .get();

  if (!snapshot.exists) {
    return {};
  }

  return snapshot.data() || {};
}

async function buscarGestanteDaContracao(dados) {
  const idsInformados = valoresIdentificadores(dados, CAMPOS_ID_PACIENTE);
  const uidsInformados = valoresIdentificadores(dados, CAMPOS_UID_PACIENTE);
  if (idsInformados.size > 1 || uidsInformados.size > 1) {
    throw new HttpsError(
        "failed-precondition",
        "Contracao com vinculo de paciente inconsistente.",
    );
  }
  const idInformado = idsInformados.size === 1 ? [...idsInformados][0] : "";
  const uidInformado = uidsInformados.size === 1 ? [...uidsInformados][0] : "";

  if (idInformado) {
    const snapshot = await admin
        .firestore()
        .collection("gestantes")
        .doc(idInformado)
        .get();

    if (!snapshot.exists) {
      throw new HttpsError(
          "failed-precondition",
          "Paciente da contração não encontrado.",
      );
    }

    const gestante = snapshot.data() || {};
    const uidsCadastrados = valoresIdentificadores(
        gestante,
        CAMPOS_UID_PACIENTE,
    );
    if (uidsCadastrados.size > 1) {
      throw new HttpsError(
          "failed-precondition",
          "Paciente com vinculo de login inconsistente.",
      );
    }
    const uidCadastrado = uidsCadastrados.size === 1 ?
      [...uidsCadastrados][0] : "";

    if (uidInformado && uidCadastrado && uidInformado !== uidCadastrado) {
      throw new HttpsError(
          "failed-precondition",
          "Contracao com vinculo de paciente inconsistente.",
      );
    }

    return {
      id: snapshot.id,
      dados: gestante,
    };
  }

  if (!uidInformado) {
    throw new HttpsError(
        "failed-precondition",
        "Contração sem paciente vinculado.",
    );
  }

  const resultados = await buscarPacientesPorUid(uidInformado, 2);

  if (resultados.length !== 1) {
    throw new HttpsError(
        "failed-precondition",
        "Não foi possível resolver o paciente da contração.",
    );
  }

  const snapshot = resultados[0];

  return {
    id: snapshot.id,
    dados: snapshot.data() || {},
  };
}

function montarNomeDocumentoContrato(payload) {
  const planoNome = String(payload.planoNome || "").trim();
  const nomePaciente = String(payload.nomePaciente || "").trim();
  let nome = "Contrato";

  if (planoNome) {
    nome += ` ${planoNome}`;
  }

  if (nomePaciente) {
    nome += ` - ${nomePaciente}`;
  }

  return nome.replace(/\s+/g, " ").trim();
}

function montarArquivoNomeContrato(payload, statusInterno) {
  const base = montarNomeDocumentoContrato(payload);
  return statusInterno === "assinado" ? `${base} assinado` : base;
}

function resolverUrlDocumentoContrato({
  detalheDocumento,
  respostaZapSign,
  signerUrl,
}) {
  return detalheDocumento.signed_file ||
    respostaZapSign.signed_file ||
    signerUrl ||
    "";
}

async function sincronizarDocumentoContrato({
  contratoId,
  pacienteId,
  clinicaId,
  payload,
  statusInterno,
  detalheDocumento,
  respostaZapSign,
  signerUrl,
}) {
  const tenantId = exigirTenant(camposTenant(clinicaId), "Documento");
  const gestante = await buscarGestantePorId(pacienteId);
  const uidGestante = textoSeguro(
      gestante.uidPaciente || gestante.uidGestante || payload.pacienteUid,
  );
  const nomeGestante = String(
      gestante.nomeGestante || payload.nomePaciente || "",
  ).trim();

  if (!nomeGestante) {
    return;
  }

  const arquivoUrl = resolverUrlDocumentoContrato({
    detalheDocumento,
    respostaZapSign,
    signerUrl,
  });

  const agora = new Date();
  const documentoId = `contrato_${contratoId}`;
  const nomeDocumento = montarNomeDocumentoContrato(payload);
  const arquivoNome = montarArquivoNomeContrato(payload, statusInterno);

  await admin.firestore().collection("documentos").doc(documentoId).set({
    nome: nomeDocumento,
    tipo: "Contrato",
    gestante: nomeGestante,
    ...camposIdentidadePaciente(pacienteId, uidGestante),
    arquivoNome,
    arquivoUrl,
    arquivoPrincipalUrl: arquivoUrl,
    zapsignSignerUrl: signerUrl || "",
    zapsignSignedFile:
      detalheDocumento.signed_file || respostaZapSign.signed_file || "",
    zapsignOriginalFile:
      detalheDocumento.original_file || respostaZapSign.original_file || "",
    zapsignDocumentId: detalheDocumento.token || respostaZapSign.token || "",
    contratoId,
    ...camposTenant(tenantId),
    statusContrato: statusInterno,
    origem: "zapsign",
    data: formatarDataHoraDocumento(agora),
    criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function buscarUsuariosOperacionaisPush(clinicaId) {
  const db = admin.firestore();
  const usuariosMap = new Map();
  const tenantId = exigirTenant(camposTenant(clinicaId), "Notificacao");

  const consultas = await Promise.all([
    db.collection("usuarios")
        .where("clinicaId", "==", tenantId)
        .get()
        .catch(() => null),
    db.collection("usuarios")
        .where("adminDonoId", "==", tenantId)
        .get()
        .catch(() => null),
  ]);

  for (const resultado of consultas) {
    if (!resultado) continue;

    for (const doc of resultado.docs) {
      usuariosMap.set(doc.id, {
        id: doc.id,
        ...doc.data(),
      });
    }
  }

  return Array.from(usuariosMap.values()).filter((usuario) => {
    const perfil = resolverPerfilUsuario(usuario);
    const tenantUsuario = resolverTenant(usuario);
    const status = textoSeguro(usuario.status).toLowerCase();

    return perfil.consistente &&
      ["enfermeira", "obstetra", "profissional"].includes(perfil.perfil) &&
      tenantUsuario.consistente &&
      tenantUsuario.clinicaId === tenantId &&
      status === "ativo";
  });
}

function extrairTokensUsuariosPush(usuarios) {
  const maxTokensPerUser = 5;
  const maxRecipients = 500;
  const tokens = [];
  const donosPorToken = new Map();

  for (const usuario of usuarios) {
    if (tokens.length >= maxRecipients) break;
    const tokensUsuario = Array.isArray(usuario.pushTokens) ?
      usuario.pushTokens.slice(-maxTokensPerUser) :
      [];

    for (const token of tokensUsuario) {
      const tokenNormalizado = String(token || "").trim();

      if (tokenNormalizado.length < 20 || tokenNormalizado.length > 4096) {
        continue;
      }

      if (!donosPorToken.has(tokenNormalizado)) {
        if (tokens.length >= maxRecipients) break;
        tokens.push(tokenNormalizado);
        donosPorToken.set(tokenNormalizado, new Set());
      }

      donosPorToken.get(tokenNormalizado).add(usuario.id);
    }
  }

  return {
    tokens,
    donosPorToken,
  };
}

async function limparTokensInvalidosPush(tokensInvalidos, donosPorToken) {
  if (!Array.isArray(tokensInvalidos) || tokensInvalidos.length === 0) {
    return;
  }

  const db = admin.firestore();
  const atualizacoes = [];

  for (const token of tokensInvalidos) {
    const donos = donosPorToken.get(token);
    if (!donos || donos.size === 0) {
      continue;
    }

    for (const uid of donos) {
      atualizacoes.push(
          db.collection("usuarios").doc(uid).set({
            pushTokens: admin.firestore.FieldValue.arrayRemove(token),
            pushAtualizadoEm: new Date().toISOString(),
          }, {merge: true}),
      );
    }
  }

  await Promise.all(atualizacoes);
}

async function enviarPushParaUsuariosOperacionais({
  clinicaId,
  title,
  body,
  data,
}) {
  const usuarios = await buscarUsuariosOperacionaisPush(clinicaId);
  const {tokens, donosPorToken} = extrairTokensUsuariosPush(usuarios);

  if (tokens.length === 0) {
    console.log("Push: nenhum token operacional encontrado.");
    return {
      sucesso: 0,
      falhas: 0,
    };
  }

  const resposta = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title,
      body,
    },
    data,
    android: {
      priority: "high",
      notification: {
        sound: "default",
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
    webpush: {
      headers: {
        Urgency: "high",
      },
      notification: {
        title,
        body,
        icon: "/icons/Icon-192.png",
        badge: "/icons/Icon-192.png",
        requireInteraction: data.tipo === "alerta_contracao",
      },
    },
  });

  const tokensInvalidos = [];

  resposta.responses.forEach((resultado, index) => {
    if (resultado.success) {
      return;
    }

    const code = resultado.error && resultado.error.code ?
      resultado.error.code :
      "";

    logSafeError("Push: falha ao enviar notificacao.", {code});

    if ([
      "messaging/registration-token-not-registered",
      "messaging/invalid-registration-token",
    ].includes(code)) {
      tokensInvalidos.push(tokens[index]);
    }
  });

  await limparTokensInvalidosPush(tokensInvalidos, donosPorToken);

  return {
    sucesso: resposta.successCount,
    falhas: resposta.failureCount,
  };
}

async function registrarNotificacaoCentral({
  clinicaId,
  tipo,
  titulo,
  mensagem,
  gestante,
  intensidade,
  duracao,
  intervalo,
  idGestante,
  destinatariosTipos,
}) {
  const tenantId = exigirTenant(camposTenant(clinicaId), "Notificacao");

  const notificationRef = await admin
      .firestore()
      .collection("notificacoesCentral")
      .add({
        ...camposTenant(tenantId),
        tipo: tipo || "notificacao",
        titulo: titulo || "Notificação",
        mensagem: mensagem || "",
        gestante: gestante || "",
        intensidade: intensidade || "",
        duracao: duracao || "",
        intervalo: intervalo || "",
        idGestante: idGestante || "",
        destinatariosTipos: Array.isArray(destinatariosTipos) ?
          destinatariosTipos :
          ["admin"],
        lidasPor: [],
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        criadoEmIso: new Date().toISOString(),
        atualizadoEm: new Date().toISOString(),
      });

  return notificationRef.id;
}

async function chamarZapSign({
  method,
  path,
  apiToken,
  body,
}) {
  const methodNormalized = String(method || "").toUpperCase();
  const safePath = String(path || "");
  const allowedRequest =
    (methodNormalized === "POST" &&
      safePath === "/models/create-doc/") ||
    (methodNormalized === "GET" &&
      /^\/docs\/[a-zA-Z0-9_-]{1,200}\/$/.test(safePath)) ||
    (methodNormalized === "POST" &&
      /^\/docs\/[a-zA-Z0-9_-]{1,200}\/add-signer\/$/.test(safePath));

  if (!allowedRequest) {
    const pathError = new Error("Endpoint ZapSign nao permitido.");
    pathError.code = "zapsign/invalid-path";
    throw pathError;
  }

  const serializedBody = body ? JSON.stringify(body) : undefined;
  if (serializedBody && Buffer.byteLength(serializedBody, "utf8") > 256000) {
    const bodyError = new Error("Payload ZapSign excede o limite seguro.");
    bodyError.code = "zapsign/payload-too-large";
    throw bodyError;
  }

  const resposta = await fetch(`${ZAPSIGN_API_BASE_URL}${safePath}`, {
    method: methodNormalized,
    headers: {
      Authorization: `Bearer ${apiToken}`,
      "Content-Type": "application/json",
    },
    body: serializedBody,
    signal: AbortSignal.timeout(20000),
  });

  const contentLength = Number(resposta.headers.get("content-length"));
  if (Number.isFinite(contentLength) && contentLength > 2 * 1024 * 1024) {
    const responseSizeError = new Error("Resposta ZapSign excede o limite.");
    responseSizeError.code = "zapsign/response-too-large";
    throw responseSizeError;
  }

  const texto = await resposta.text();
  if (Buffer.byteLength(texto, "utf8") > 2 * 1024 * 1024) {
    const responseSizeError = new Error("Resposta ZapSign excede o limite.");
    responseSizeError.code = "zapsign/response-too-large";
    throw responseSizeError;
  }
  let json;

  try {
    json = texto ? JSON.parse(texto) : {};
  } catch (_) {
    const invalidResponseError = new Error(
        "Resposta ZapSign em formato inválido.",
    );
    invalidResponseError.code = "zapsign/invalid-response";
    throw invalidResponseError;
  }

  if (!resposta.ok) {
    const integrationError = new Error("Falha na integracao ZapSign.");
    integrationError.code = `zapsign/http-${resposta.status}`;
    throw integrationError;
  }

  return json;
}

async function processarGeracaoContrato({
  contratoId,
  payload,
  apiToken,
  clinicaId,
}) {
  const tenantId = exigirTenant(camposTenant(clinicaId), "Contrato");
  const templateKey = payload.templateKey || "";
  const pacienteId = payload.pacienteId || "";
  const configuracao = await buscarConfiguracaoZapSign();
  const signatariosPlanejados = montarSignatariosContrato(payload, configuracao);

  if (configuracao.ativo === false) {
    throw new HttpsError(
        "failed-precondition",
        "A integracao ZapSign esta desativada nas configuracoes.",
    );
  }

  const templateId = (configuracao.templateIds || {})[templateKey] || "";

  if (!templateId) {
    await atualizarContrato(contratoId, {
      status: "aguardando_template",
      zapsignTemplateKey: templateKey,
      payload,
      atualizadoEm: new Date().toISOString(),
    }, tenantId);

    await atualizarGestanteComContrato(pacienteId, {
      contratoStatus: "aguardando_template",
      contratoTemplateKey: templateKey,
      contratoUltimaTentativaEm: new Date().toISOString(),
    }, tenantId);

    throw new HttpsError(
        "failed-precondition",
        `Template da ZapSign ainda nao configurado para ${templateKey}.`,
    );
  }

  if (!apiToken) {
    throw new HttpsError(
        "failed-precondition",
        "Secret ZAPSIGN_API_TOKEN nao configurado.",
    );
  }

  const body = montarPayloadCriacaoDocumento({
    contratoId,
    payload,
    configuracao,
    templateId,
  });

  await atualizarContrato(contratoId, {
    status: "processando",
    zapsignTemplateKey: templateKey,
    zapsignTemplateId: templateId,
    payload,
    requestBody: body,
    atualizadoEm: new Date().toISOString(),
  }, tenantId);

  try {
    const respostaZapSign = await chamarZapSign({
      method: "POST",
      path: "/models/create-doc/",
      apiToken,
      body,
    });

    await adicionarSignatariosSecundarios({
      zapsignDocumentId: respostaZapSign.token || "",
      signatarios: signatariosPlanejados,
      apiToken,
    });

    const detalheDocumento = respostaZapSign.token ?
      await chamarZapSign({
        method: "GET",
        path: `/docs/${respostaZapSign.token}/`,
        apiToken,
      }) :
      respostaZapSign;
    const signatariosFinais = mapearSignatariosZapSign(detalheDocumento.signers);
    const linksAssinatura = montarLinkAssinaturaPrincipal(detalheDocumento.signers);
    const statusInterno = normalizarStatusContrato(detalheDocumento.status);

    await atualizarContrato(contratoId, {
      status: statusInterno,
      zapsignStatus: detalheDocumento.status || respostaZapSign.status || "",
      zapsignDocumentId: detalheDocumento.token || respostaZapSign.token || "",
      zapsignOpenId: String(
          detalheDocumento.open_id || respostaZapSign.open_id || "",
      ),
      zapsignSignerToken: linksAssinatura.signerToken,
      zapsignSignerUrl: linksAssinatura.signerUrl,
      zapsignSigners: signatariosFinais,
      zapsignOriginalFile:
        detalheDocumento.original_file || respostaZapSign.original_file || "",
      zapsignSignedFile:
        detalheDocumento.signed_file || respostaZapSign.signed_file || "",
      respostaZapSign: detalheDocumento,
      atualizadoEm: new Date().toISOString(),
    }, tenantId);

    await atualizarGestanteComContrato(pacienteId, {
      contratoStatus: statusInterno,
      contratoTemplateKey: templateKey,
      contratoId,
      contratoZapSignDocumentId:
        detalheDocumento.token || respostaZapSign.token || "",
      contratoZapSignSignerUrl: linksAssinatura.signerUrl,
      contratoZapSignSigners: signatariosFinais,
      contratoErro: "",
      contratoUltimaTentativaEm: new Date().toISOString(),
    }, tenantId);

    await sincronizarDocumentoContrato({
      contratoId,
      pacienteId,
      clinicaId: tenantId,
      payload,
      statusInterno,
      detalheDocumento,
      respostaZapSign,
      signerUrl: linksAssinatura.signerUrl,
    });

    return {
      sucesso: true,
      contratoId,
      status: statusInterno,
      zapsignStatus: detalheDocumento.status || respostaZapSign.status || "",
      zapsignDocumentId: detalheDocumento.token || respostaZapSign.token || "",
      zapsignSignerUrl: linksAssinatura.signerUrl,
      zapsignSigners: signatariosFinais,
    };
  } catch (error) {
    const errorCode = safeErrorCode(error);
    await atualizarContrato(contratoId, {
      status: "erro",
      erro: "Falha temporaria na integracao de assinatura.",
      erroCodigo: errorCode,
      atualizadoEm: new Date().toISOString(),
    }, tenantId);

    await atualizarGestanteComContrato(pacienteId, {
      contratoStatus: "erro",
      contratoErro: "Falha temporaria na integracao de assinatura.",
      contratoErroCodigo: errorCode,
      contratoUltimaTentativaEm: new Date().toISOString(),
    }, tenantId);

    logSafeError("Erro ao gerar contrato na ZapSign.", error);
    throw new HttpsError(
        "internal",
        "Não foi possível gerar o contrato na ZapSign.",
    );
  }
}

async function prepararContratoParaGestante(idGestante, dados) {
  if (dados.origem === "importacao_xls") {
    return;
  }

  const templateKey =
    dados.contratoTemplateKey ||
    descobrirTemplateKeyContrato(dados.plano || "", dados.consultorio || "");

  if (!templateKey) {
    return;
  }

  let clinicaId;

  try {
    clinicaId = exigirTenant(dados, "Paciente");
    await exigirClinicaAtiva(clinicaId);
  } catch (error) {
    logSafeError(
        "Contrato automático bloqueado por vínculo de clínica inválido.",
        error,
    );
    return;
  }

  if (dados.contratoId) {
    const uidsPaciente = valoresIdentificadores(dados, CAMPOS_UID_PACIENTE);
    if (uidsPaciente.size > 1) {
      logSafeError(
          "Contrato automatico bloqueado por aliases UID divergentes.",
          new Error("Paciente com aliases UID divergentes."),
      );
      return;
    }
    const uidGestante = uidsPaciente.size === 1 ? [...uidsPaciente][0] : "";

    if (!uidGestante) {
      return;
    }

    try {
      const contratoRef = admin
          .firestore()
          .collection("contratos")
          .doc(textoSeguro(dados.contratoId));
      const contratoSnapshot = await contratoRef.get();

      if (!contratoSnapshot.exists) {
        return;
      }

      const contrato = contratoSnapshot.data() || {};
      const tenantContrato = resolverTenant(contrato);
      const pacienteContrato = textoSeguro(
          contrato.pacienteId ||
          (contrato.payload && contrato.payload.pacienteId),
      );

      if (!tenantContrato.consistente ||
          tenantContrato.clinicaId !== clinicaId ||
          pacienteContrato !== idGestante) {
        throw new Error("Contrato existente com vinculo inconsistente.");
      }

      const payloadAtual = contrato.payload &&
        typeof contrato.payload === "object" ? contrato.payload : {};
      await contratoRef.set({
        ...camposTenant(clinicaId),
        ...camposIdentidadePaciente(idGestante, uidGestante),
        payload: {
          ...payloadAtual,
          ...camposIdentidadePaciente(idGestante, uidGestante),
        },
        atualizadoEm: new Date().toISOString(),
      }, {merge: true});

      const documentoRef = admin
          .firestore()
          .collection("documentos")
          .doc(`contrato_${dados.contratoId}`);
      const documentoSnapshot = await documentoRef.get();

      if (documentoSnapshot.exists) {
        await documentoRef.set({
          ...camposTenant(clinicaId),
          ...camposIdentidadePaciente(idGestante, uidGestante),
        }, {merge: true});
      }
    } catch (error) {
      logSafeError(
          "Falha ao sincronizar login no contrato existente.",
          error,
      );
    }

    return;
  }

  const payload = montarPayloadContratoDaGestante(idGestante, {
    ...dados,
    contratoTemplateKey: templateKey,
  });
  const agora = new Date().toISOString();
  const contratoRef = admin.firestore().collection("contratos").doc();

  await contratoRef.set({
    ...camposTenant(clinicaId),
    pacienteId: idGestante,
    pacienteUid: payload.pacienteUid || "",
    uidPaciente: payload.uidPaciente || "",
    uidGestante: payload.uidGestante || "",
    templateKey: payload.templateKey || "",
    status: "pendente",
    zapsignDocumentId: "",
    zapsignSignerUrl: "",
    payload,
    criadoEm: agora,
    atualizadoEm: agora,
    origem: "cadastro_automatico_gestante",
  });

  await atualizarGestanteComContrato(idGestante, {
    contratoGeracaoAutomatica: true,
    contratoId: contratoRef.id,
    contratoStatus: "pendente",
    contratoTemplateKey: templateKey,
    contratoPlanoCodigo: payload.templateKey.split("_")[0] || "",
    contratoModalidadeCodigo: payload.templateKey.split("_")[1] || "",
    contratoUltimaTentativaEm: agora,
  }, clinicaId);

  try {
    const apiToken = zapsignApiToken.value();

    if (!apiToken) {
      await atualizarContrato(contratoRef.id, {
        status: "aguardando_secret",
        atualizadoEm: new Date().toISOString(),
      }, clinicaId);
      return;
    }

    await processarGeracaoContrato({
      contratoId: contratoRef.id,
      payload,
      apiToken,
      clinicaId,
    });
  } catch (error) {
    logSafeError("Erro ao preparar contrato ZapSign.", error);
  }
}

exports.criarUsuarioGestanteAoCadastrar = onDocumentCreated(
    "gestantes/{idGestante}",
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        console.log("Documento não encontrado no evento.");
        return;
      }

      const idGestante = event.params.idGestante;
      const dados = snapshot.data();

      const nome = dados.nomeGestante || "";
      const email = dados.emailGestante || "";
      const uidsPacienteAtuais = valoresIdentificadores(
          dados,
          CAMPOS_UID_PACIENTE,
      );
      const origem = dados.origem || "";

      if (origem === "importacao_xls") {
        console.log("Gestante importada de histórico. Usuário não criado.");
        return;
      }

      let clinicaId;

      try {
        clinicaId = exigirTenant(dados, "Paciente");
        await exigirClinicaAtiva(clinicaId);
      } catch (error) {
        logSafeError(
            "Usuário do paciente não criado: vínculo de clínica inválido.",
            error,
        );
        return;
      }

      if (uidsPacienteAtuais.size > 1) {
        console.error(
            "Paciente com aliases UID divergentes. Usuário não criado.",
        );
        return;
      }

      if (uidsPacienteAtuais.size === 1) {
        console.log("Paciente já possui UID. Usuário não criado.");
        return;
      }

      if (!nome || !email) {
        console.log("Gestante sem nome ou e-mail. Usuário não criado.");
        return;
      }

      let usuario;
      let usuarioNovo = false;

      try {
        usuario = await admin.auth().createUser({
          email: email,
          displayName: nome,
          emailVerified: false,
          disabled: false,
        });
        usuarioNovo = true;
      } catch (error) {
        if (error.code === "auth/email-already-exists") {
          usuario = await admin.auth().getUserByEmail(email);
        } else {
          logSafeError("Erro ao criar usuario.", error);
          return;
        }
      }

      if (!usuarioNovo) {
        const usuarioExistente = await admin
            .firestore()
            .collection("usuarios")
            .doc(usuario.uid)
            .get();
        const dadosExistentes = usuarioExistente.exists ?
          (usuarioExistente.data() || {}) : {};
        const perfilExistente = resolverPerfilUsuario(dadosExistentes);
        const tenantExistente = resolverTenant(dadosExistentes);
        const idsPacienteExistente = valoresIdentificadores(
            dadosExistentes,
            CAMPOS_ID_PACIENTE,
        );
        const pacienteExistente = idsPacienteExistente.size === 1 ?
          [...idsPacienteExistente][0] : "";

        if (!usuarioExistente.exists ||
            !perfilExistente.consistente ||
            perfilExistente.perfil !== "gestante" ||
            !tenantExistente.consistente ||
            tenantExistente.clinicaId !== clinicaId ||
            idsPacienteExistente.size > 1 ||
            pacienteExistente !== idGestante) {
          console.error(
              "Usuario da paciente nao criado: e-mail ja pertence a outro perfil.",
          );
          return;
        }
      }

      try {
        await vincularUidAPaciente({
          contexto: {
            uid: "sistema:criarUsuarioGestanteAoCadastrar",
            perfil: "admin",
            clinicaId,
            dados: {},
          },
          uidUsuario: usuario.uid,
          pacienteId: idGestante,
          nomeUsuario: nome,
          convitePendente: true,
        });
      } catch (error) {
        if (usuarioNovo) {
          const rollbackConcluido = await rollbackUsuarioAuth(usuario.uid);

          if (!rollbackConcluido) {
            console.error(
                "Falha critica: usuario Auth automatico ficou sem vinculo " +
                  "Firestore e exige reconciliacao manual.",
            );
          }
        }

        logSafeError(
            "Erro ao vincular usuario automatico da paciente.",
            error,
        );
        return;
      }

      console.log("Conta da paciente criada com sucesso.");
    },
);

exports.notificarContracaoGestante = onDocumentCreated(
    {
      document: "contracoes/{idContracao}",
      region: "southamerica-east1",
    },
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        console.log("Push contração: documento não encontrado no evento.");
        return;
      }

      const dados = snapshot.data() || {};
      const origemTipoUsuario = normalizarPerfilUsuario(
          dados.origemTipoUsuario || "",
      );

      if (origemTipoUsuario !== "gestante") {
        console.log("Push contracao: origem nao gestante, alerta ignorado.");
        return;
      }

      let paciente;
      let clinicaId;

      try {
        paciente = await buscarGestanteDaContracao(dados);
        clinicaId = exigirTenant(paciente.dados, "Paciente");
        const tenantContracao = resolverTenant(dados);

        if (!tenantContracao.consistente ||
            (tenantContracao.clinicaId &&
             tenantContracao.clinicaId !== clinicaId)) {
          throw new HttpsError(
              "failed-precondition",
              "Contracao com vinculo de clinica inconsistente.",
          );
        }

        await exigirClinicaAtiva(clinicaId);
        await snapshot.ref.set({
          idGestante: paciente.id,
          ...camposTenant(clinicaId),
        }, {merge: true});
      } catch (error) {
        logSafeError(
            "Push clínico bloqueado por vínculo inválido.",
            error,
        );
        return;
      }

      const nomeGestante = textoSeguro(
          paciente.dados.nomeGestante || dados.gestante || dados.nomeGestante,
      );
      const intensidade = String(dados.intensidade || "").trim();
      const duracao = String(dados.duracao || "").trim();
      const intervalo = String(dados.intervalo || "").trim();
      const idGestante = paciente.id;

      const partesCorpo = [
        nomeGestante ? `${nomeGestante} registrou uma nova contração.` :
          "Uma paciente registrou uma nova contração.",
        intensidade ? `Intensidade: ${intensidade}.` : "",
        duracao ? `Duracao: ${duracao}.` : "",
      ].filter(Boolean);
      const mensagem = partesCorpo.join(" ");

      const notificacaoId = await registrarNotificacaoCentral({
        clinicaId,
        tipo: "alerta_contracao",
        titulo: "Alerta de contração",
        mensagem,
        gestante: nomeGestante,
        intensidade,
        duracao,
        intervalo,
        idGestante,
        destinatariosTipos: [
          "admin",
          "enfermeira",
          "obstetra",
          "profissional",
        ],
      });

      const pushPrivado = buildPrivateClinicalPush(notificacaoId);
      await enviarPushParaUsuariosOperacionais({
        clinicaId,
        ...pushPrivado,
      });
    },
);

exports.prepararContratoZapSignAoCadastrar = onDocumentCreated(
    {
      document: "gestantes/{idGestante}",
      region: "us-central1",
      secrets: [zapsignApiToken],
    },
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        return;
      }

      const idGestante = event.params.idGestante;
      const dados = snapshot.data() || {};
      await prepararContratoParaGestante(idGestante, dados);
    },
);

exports.prepararContratoZapSignAoAtualizar = onDocumentUpdated(
    {
      document: "gestantes/{idGestante}",
      region: "us-central1",
      secrets: [zapsignApiToken],
    },
    async (event) => {
      const after = event.data && event.data.after;

      if (!after) {
        return;
      }

      const idGestante = event.params.idGestante;
      const dados = after.data() || {};
      await prepararContratoParaGestante(idGestante, dados);
    },
);

exports.excluirUsuarioAuth = onCall(
    {
      invoker: "public",
      region: "us-central1",
      enforceAppCheck,
    },
    async (request) => {
      const contexto = await exigirContextoUsuario(
          request.auth,
          ["admin", "superAdmin"],
      );
      const uidAdmin = contexto.uid;
      const uidUsuario = textoSeguro(request.data && request.data.uidUsuario);

      if (!uidUsuario) {
        throw new HttpsError(
            "invalid-argument",
            "UID do usuário é obrigatório.",
        );
      }

      if (uidUsuario === uidAdmin) {
        throw new HttpsError(
            "failed-precondition",
            "Você não pode excluir o próprio usuário logado.",
        );
      }

      const db = admin.firestore();
      const usuarioRef = db.collection("usuarios").doc(uidUsuario);
      const usuarioSaaSRef = db.collection("usuariosSaaS").doc(uidUsuario);
      const [usuarioSnapshot, usuarioSaaSSnapshot] = await Promise.all([
        usuarioRef.get(),
        usuarioSaaSRef.get(),
      ]);

      if (!usuarioSnapshot.exists && !usuarioSaaSSnapshot.exists) {
        throw new HttpsError(
            "not-found",
            "Usuário não encontrado.",
        );
      }

      const dadosUsuario = usuarioSnapshot.exists ?
        (usuarioSnapshot.data() || {}) : {};
      const dadosUsuarioSaaS = usuarioSaaSSnapshot.exists ?
        (usuarioSaaSSnapshot.data() || {}) : {};
      const perfilUsuario = resolverPerfilUsuario(
          usuarioSnapshot.exists ? dadosUsuario : dadosUsuarioSaaS,
      );
      const perfilUsuarioSaaS = usuarioSaaSSnapshot.exists ?
        resolverPerfilUsuario(dadosUsuarioSaaS) : perfilUsuario;
      const tenantUsuario = resolverTenant(dadosUsuario);
      const tenantUsuarioSaaS = resolverTenant(dadosUsuarioSaaS);

      if (!perfilUsuario.consistente ||
          !perfilUsuarioSaaS.consistente ||
          perfilUsuario.perfil !== perfilUsuarioSaaS.perfil ||
          !tenantUsuario.consistente ||
          !tenantUsuarioSaaS.consistente ||
          (tenantUsuario.clinicaId && tenantUsuarioSaaS.clinicaId &&
           tenantUsuario.clinicaId !== tenantUsuarioSaaS.clinicaId)) {
        throw new HttpsError(
            "failed-precondition",
            "Usuario com perfil ou vinculo de clinica inconsistente.",
        );
      }

      if (perfilUsuario.perfil === "superAdmin") {
        throw new HttpsError(
            "permission-denied",
            "Exclusao de Super Admin exige um fluxo administrativo externo.",
        );
      }

      const clinicaUsuario = tenantUsuario.clinicaId ||
        tenantUsuarioSaaS.clinicaId;

      if (perfilUsuario.perfil !== "superAdmin" && !clinicaUsuario) {
        throw new HttpsError(
            "failed-precondition",
            "Usuario sem vinculo de clinica valido.",
        );
      }

      if (contexto.perfil === "admin") {
        exigirAcessoAoTenant(contexto, clinicaUsuario);
      }

      await exigirUsuarioNaoTitularClinica({
        db,
        uidUsuario,
        clinicaId: clinicaUsuario,
      });

      const inspecao = await inspecionarVinculosCicloUsuario({
        db,
        uidUsuario,
        clinicaId: clinicaUsuario,
        perfilAtual: perfilUsuario.perfil,
        dadosUsuario: usuarioSnapshot.exists ? dadosUsuario : null,
        dadosUsuarioSaaS: usuarioSaaSSnapshot.exists ?
          dadosUsuarioSaaS : null,
      });
      const pacienteIds = new Set([
        inspecao.identidade.pacienteId,
        ...inspecao.entidades
            .filter((item) => item.configuracao.perfil === "gestante")
            .map((item) => item.documento.id),
      ].filter(Boolean));

      if (pacienteIds.size > 1 ||
          (perfilUsuario.perfil === "gestante" && pacienteIds.size !== 1)) {
        throw new HttpsError(
            "failed-precondition",
            "Perfil de paciente com identificador ausente ou divergente.",
        );
      }

      const pacienteId = pacienteIds.size === 1 ? [...pacienteIds][0] : "";
      const remocoesRegistros = pacienteId ?
        await prepararRemocoesVinculoPaciente({
          pacienteId,
          uidUsuario,
          clinicaId: clinicaUsuario,
          uidOperador: contexto.uid,
        }) : [];
      const quantidadeOperacoes = remocoesRegistros.length +
        inspecao.entidades.length +
        inspecao.locks.length +
        (usuarioSnapshot.exists ? 1 : 0) +
        (usuarioSaaSSnapshot.exists ? 1 : 0) +
        1;

      if (quantidadeOperacoes > 490) {
        throw new HttpsError(
            "resource-exhausted",
            "Muitos registros para exclusao atomica segura.",
        );
      }

      let authJaAusente = false;
      try {
        await admin.auth().deleteUser(uidUsuario);
      } catch (error) {
        if (error.code !== "auth/user-not-found") {
          throw error;
        }
        authJaAusente = true;
      }

      const batch = db.batch();
      const agora = admin.firestore.FieldValue.serverTimestamp();
      const removerCampo = admin.firestore.FieldValue.delete();

      for (const remocao of remocoesRegistros) {
        batch.update(
            remocao.ref,
            remocao.dados,
            {lastUpdateTime: remocao.updateTime},
        );
      }

      for (const item of inspecao.entidades) {
        const atualizacao = {
          acessoCriado: "false",
          acessoRevogadoEm: agora,
          acessoRevogadoPor: contexto.uid,
          conviteSenhaPendente: false,
          conviteSenhaSolicitadoEm: removerCampo,
          emailAcesso: removerCampo,
        };
        for (const campoUid of item.configuracao.camposUid) {
          atualizacao[campoUid] = removerCampo;
        }
        batch.update(
            item.documento.ref,
            atualizacao,
            {lastUpdateTime: item.documento.updateTime},
        );
      }

      for (const lock of inspecao.locks) {
        batch.delete(lock.ref, {lastUpdateTime: lock.updateTime});
      }

      if (usuarioSnapshot.exists) {
        batch.delete(usuarioRef, {
          lastUpdateTime: usuarioSnapshot.updateTime,
        });
      }
      if (usuarioSaaSSnapshot.exists) {
        batch.delete(usuarioSaaSRef, {
          lastUpdateTime: usuarioSaaSSnapshot.updateTime,
        });
      }

      const logRef = db.collection("logsAdministrativos").doc();
      batch.create(logRef, {
        ...camposTenant(clinicaUsuario),
        acao: "desvincular_e_excluir_usuario",
        usuarioUid: contexto.uid,
        uidExcluido: uidUsuario,
        perfilExcluido: perfilUsuario.perfil,
        pacienteId,
        registrosDesvinculados: contagensPorColecao(remocoesRegistros),
        entidadesDesvinculadas: inspecao.entidades.map(
            (item) => item.documento.ref.path,
        ),
        locksRemovidos: inspecao.locks.map((lock) => lock.ref.path),
        authJaAusente,
        criadoEm: agora,
      });

      await batch.commit();

      return {
        sucesso: true,
        entidadesDesvinculadas: inspecao.entidades.length,
        registrosDesvinculados: remocoesRegistros.length,
        locksRemovidos: inspecao.locks.length,
        mensagem: "Usuario desvinculado e excluido com sucesso.",
      };
    },
);

exports.alterarTipoUsuarioClinica = onCall(
    {
      invoker: "public",
      region: "us-central1",
      enforceAppCheck,
    },
    async (request) => {
      const contexto = await exigirContextoUsuario(
          request.auth,
          ["admin", "superAdmin"],
      );
      const entrada = request.data || {};
      const uidUsuario = textoSeguro(entrada.uidUsuario);
      const novoPerfil = normalizarPerfilUsuario(
          entrada.novoTipoUsuario || entrada.tipoUsuario || entrada.tipo,
      );

      if (!uidUsuario) {
        throw new HttpsError(
            "invalid-argument",
            "UID do usuario e obrigatorio.",
        );
      }

      if (!PERFIS_USUARIO_CONHECIDOS.has(novoPerfil) ||
          novoPerfil === "superAdmin") {
        throw new HttpsError(
            "invalid-argument",
            "Tipo de usuario nao permitido.",
        );
      }

      const db = admin.firestore();
      const usuarioRef = db.collection("usuarios").doc(uidUsuario);
      const usuarioSaaSRef = db.collection("usuariosSaaS").doc(uidUsuario);
      const [usuarioSnapshot, usuarioSaaSSnapshot] = await Promise.all([
        usuarioRef.get(),
        usuarioSaaSRef.get(),
      ]);

      if (!usuarioSnapshot.exists) {
        throw new HttpsError("not-found", "Usuário não encontrado.");
      }

      const dadosUsuario = usuarioSnapshot.data() || {};
      const perfilAtual = resolverPerfilUsuario(dadosUsuario);
      const tenantUsuario = resolverTenant(dadosUsuario);
      const dadosSaaS = usuarioSaaSSnapshot.exists ?
        (usuarioSaaSSnapshot.data() || {}) : {};
      const perfilSaaS = usuarioSaaSSnapshot.exists ?
        resolverPerfilUsuario(dadosSaaS) : perfilAtual;
      const tenantSaaS = usuarioSaaSSnapshot.exists ?
        resolverTenant(dadosSaaS) : tenantUsuario;

      if (!perfilAtual.consistente ||
          !perfilSaaS.consistente ||
          perfilAtual.perfil !== perfilSaaS.perfil ||
          perfilAtual.perfil === "superAdmin" ||
          !tenantUsuario.consistente ||
          !tenantSaaS.consistente ||
          !tenantUsuario.clinicaId ||
          tenantUsuario.clinicaId !== tenantSaaS.clinicaId) {
        throw new HttpsError(
            "failed-precondition",
            "Usuario com perfil ou vinculo de clinica inconsistente.",
        );
      }

      exigirAcessoAoTenant(contexto, tenantUsuario.clinicaId);
      await exigirClinicaAtiva(tenantUsuario.clinicaId);

      if (uidUsuario === contexto.uid && novoPerfil !== perfilAtual.perfil) {
        throw new HttpsError(
            "failed-precondition",
            "Voce nao pode alterar o proprio perfil logado.",
        );
      }

      if (novoPerfil === perfilAtual.perfil) {
        return {
          sucesso: true,
          alterado: false,
          uidUsuario,
          tipoUsuario: novoPerfil,
          mensagem: "O usuario ja possui o perfil informado.",
        };
      }

      await exigirUsuarioNaoTitularClinica({
        db,
        uidUsuario,
        clinicaId: tenantUsuario.clinicaId,
      });

      let usuarioAuth;
      try {
        usuarioAuth = await admin.auth().getUser(uidUsuario);
      } catch (error) {
        if (error.code === "auth/user-not-found") {
          throw new HttpsError(
              "failed-precondition",
              "Usuario nao existe mais no Firebase Authentication.",
          );
        }
        throw error;
      }

      if (usuarioAuth.disabled ||
          (usuarioAuth.customClaims &&
           usuarioAuth.customClaims.superAdmin === true)) {
        throw new HttpsError(
            "failed-precondition",
            "Credencial de autenticacao incompativel com a troca de perfil.",
        );
      }

      const inspecao = await inspecionarVinculosCicloUsuario({
        db,
        uidUsuario,
        clinicaId: tenantUsuario.clinicaId,
        perfilAtual: perfilAtual.perfil,
        dadosUsuario,
        dadosUsuarioSaaS: usuarioSaaSSnapshot.exists ? dadosSaaS : null,
      });
      const transicao = avaliarTransicaoPerfil({
        perfilAtual: perfilAtual.perfil,
        novoPerfil,
        possuiVinculo: inspecao.possuiVinculo,
      });

      if (!transicao.permitida) {
        throw new HttpsError(
            "failed-precondition",
            "A troca exige desvincular ou escolher uma entidade em fluxo " +
              `proprio (${transicao.motivo}).`,
        );
      }

      const atualizacao = {
        ...camposTenant(tenantUsuario.clinicaId),
        tipo: novoPerfil,
        tipoUsuario: novoPerfil,
        pacienteId: "",
        gestanteId: "",
        idGestante: "",
        uidPaciente: "",
        pacienteUid: "",
        uidGestante: "",
        gestanteUid: "",
        idVinculo: "",
        atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        atualizadoPor: contexto.uid,
      };
      const usuarioCanonicoRef = db.doc(
          canonicalUserPath(tenantUsuario.clinicaId, uidUsuario),
      );
      const batch = db.batch();
      batch.update(
          usuarioRef,
          atualizacao,
          {lastUpdateTime: usuarioSnapshot.updateTime},
      );
      batch.set(
          usuarioCanonicoRef,
          {...dadosUsuario, ...atualizacao},
          {merge: true},
      );

      if (usuarioSaaSSnapshot.exists) {
        batch.update(
            usuarioSaaSRef,
            atualizacao,
            {lastUpdateTime: usuarioSaaSSnapshot.updateTime},
        );
      }

      const logRef = db.collection("logsAdministrativos").doc();
      batch.create(logRef, {
        ...camposTenant(tenantUsuario.clinicaId),
        acao: "alterar_tipo_usuario_seguro",
        usuarioUid: contexto.uid,
        uidAlterado: uidUsuario,
        perfilAnterior: perfilAtual.perfil,
        perfilNovo: novoPerfil,
        motivoSeguranca: transicao.motivo,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return {
        sucesso: true,
        alterado: true,
        uidUsuario,
        tipoUsuario: novoPerfil,
        mensagem: "Tipo de usuario atualizado com sucesso.",
      };
    },
);

exports.vincularLoginPaciente = onCall(
    {
      invoker: "public",
      region: "us-central1",
      enforceAppCheck,
    },
    async (request) => {
      const contexto = await exigirContextoUsuario(
          request.auth,
          ["admin", "superAdmin"],
      );
      const entrada = request.data || {};
      const resultado = await vincularUidAPaciente({
        contexto,
        uidUsuario: entrada.uidUsuario,
        pacienteId: entrada.pacienteId || entrada.gestanteId,
        nomeUsuario: "",
        convitePendente: false,
      });

      return {
        sucesso: true,
        ...resultado,
        mensagem: "Login vinculado a paciente com sucesso.",
      };
    },
);

exports.criarUsuarioClinica = onCall(
    {
      invoker: "public",
      region: "us-central1",
      enforceAppCheck,
    },
    async (request) => {
      const contexto = await exigirContextoUsuario(
          request.auth,
          ["admin", "superAdmin"],
      );
      await exigirLimiteUso({
        action: "clinic-user-create",
        subjects: [`actor:${contexto.uid}`],
        limit: 60,
        windowSeconds: 60 * 60,
      });
      const entrada = request.data || {};
      const nome = exigirTextoCriacao(
          entrada.nome,
          "nome",
          200,
      );
      const email = exigirTextoCriacao(
          entrada.email,
          "email",
          320,
      ).toLowerCase();
      const tipoUsuario = normalizarPerfilUsuario(entrada.tipo);
      const idVinculo = textoSeguro(entrada.idVinculo);
      const operacaoId = exigirTextoCriacao(
          entrada.operacaoId || entrada.operationId,
          "operacaoId",
          128,
      );

      if (!["admin", "enfermeira", "obstetra", "gestante"]
          .includes(tipoUsuario)) {
        throw new HttpsError(
            "invalid-argument",
            "Tipo de usuario nao permitido.",
        );
      }

      const destino = await prepararDestinoCriacaoUsuario({
        contexto,
        tipoUsuario,
        idVinculo,
      });
      const db = admin.firestore();
      let descritorOperacao;
      const respostaConcluida = () => ({
        sucesso: true,
        ...resultadoUsuarioCriado({
          descritorOperacao,
          tipoUsuario,
          destino,
        }),
        mensagem: "Usuario criado; convite de senha pendente de envio.",
      });

      try {
        descritorOperacao = criarDescritorOperacao({
          tipo: OPERATION_KIND.CREATE_CLINIC_USER,
          atorUid: contexto.uid,
          clinicaId: destino.clinicaId,
          operationIdSolicitado: operacaoId,
          payload: {nome, email, tipoUsuario, idVinculo},
        });
        const reserva = await reservarOperacao(db, descritorOperacao);

        if (reserva.concluida) return respostaConcluida();
      } catch (error) {
        const erroHttps = erroDuravelParaHttps(error);

        if (erroHttps) throw erroHttps;
        console.error(
            "Falha ao reservar criacao duravel de usuario:",
            error && error.code || "erro_desconhecido",
        );
        throw new HttpsError(
            "unavailable",
            "Não foi possível iniciar o cadastro. Tente novamente.",
        );
      }

      if (destino.uidsAtuais.size > 0) {
        const rollback = await rollbackDuravelSeguro(descritorOperacao);

        if (rollback.operacaoJaConcluida) return respostaConcluida();
        throw new HttpsError(
            "failed-precondition",
            `${destino.recurso || "Registro"} ja possui login vinculado.`,
        );
      }

      let usuarioAuth;

      try {
        usuarioAuth = await garantirUsuarioAuth({
          auth: admin.auth(),
          db,
          descritor: descritorOperacao,
          especificacao: {
            uid: descritorOperacao.recursos.authUid,
            email,
            displayName: nome,
            emailVerified: false,
            disabled: false,
          },
        });
      } catch (error) {
        if (await tentarResolverConcorrencia(descritorOperacao)) {
          return respostaConcluida();
        }

        if (error && error.code === "auth/invalid-email") {
          const rollback = await rollbackDuravelSeguro(descritorOperacao);

          if (rollback.operacaoJaConcluida) return respostaConcluida();
          throw new HttpsError("invalid-argument", "E-mail inválido.");
        }

        const erroHttps = erroDuravelParaHttps(error);

        if (erroHttps) throw erroHttps;
        const concluida = await prepararRetentativaFirestore(
            descritorOperacao,
        );

        if (concluida) return respostaConcluida();
        console.error(
            "Falha ao preparar Auth da criacao duravel de usuario:",
            error && error.code || "erro_desconhecido",
        );
        throw new HttpsError(
            "unavailable",
            "Não foi possível concluir o cadastro. Tente novamente.",
        );
      }

      try {
        const resultado = tipoUsuario === "gestante" ?
          await vincularUidAPaciente({
            contexto,
            uidUsuario: usuarioAuth.uid,
            pacienteId: idVinculo,
            nomeUsuario: nome,
            convitePendente: true,
            descritorOperacao,
          }) :
          await gravarUsuarioClinicaCriado({
            contexto,
            usuarioAuth,
            nome,
            tipoUsuario,
            destino,
            descritorOperacao,
          });

        return {
          sucesso: true,
          ...resultado,
          mensagem: "Usuario criado; convite de senha pendente de envio.",
        };
      } catch (error) {
        if (await tentarResolverConcorrencia(descritorOperacao)) {
          return respostaConcluida();
        }

        if (falhaPermanenteDePersistencia(error)) {
          const rollback = await rollbackDuravelSeguro(descritorOperacao);

          if (rollback.operacaoJaConcluida) return respostaConcluida();
          if (!rollback.concluido) {
            throw new HttpsError(
                "internal",
                "Falha ao concluir o cadastro e ao reverter o usuario.",
            );
          }

          if (error instanceof HttpsError) throw error;
          throw new HttpsError(
              "failed-precondition",
              "O cadastro conflita com dados existentes.",
          );
        }

        const concluida = await prepararRetentativaFirestore(
            descritorOperacao,
        );

        if (concluida) return respostaConcluida();
        console.error(
            "Falha transitoria no cadastro duravel de usuario:",
            error && error.code || "erro_desconhecido",
        );
        throw new HttpsError(
            "unavailable",
            "Cadastro ainda não concluído. Tente novamente.",
        );
      }
    },
);

exports.criarClinicaComAdminSaaS = onCall(
    {
      invoker: "public",
      region: "us-central1",
      enforceAppCheck,
    },
    async (request) => {
      const contexto = await exigirContextoUsuario(
          request.auth,
          ["superAdmin"],
      );
      await exigirLimiteUso({
        action: "clinic-create",
        subjects: [`actor:${contexto.uid}`],
        limit: 10,
        windowSeconds: 60 * 60,
      });
      const entrada = request.data || {};
      const nomeClinica = exigirTextoCriacao(
          entrada.nomeClinica,
          "nomeClinica",
          200,
      );
      const nomeAdmin = exigirTextoCriacao(
          entrada.nomeAdmin,
          "nomeAdmin",
          200,
      );
      const emailAdmin = exigirTextoCriacao(
          entrada.emailAdmin,
          "emailAdmin",
          320,
      ).toLowerCase();
      const plano = exigirTextoCriacao(
          entrada.plano,
          "plano",
          120,
      );
      const valorAssinatura = exigirValorAssinaturaSaaS(
          entrada.valorAssinatura,
      );
      const operacaoId = exigirTextoCriacao(
          entrada.operacaoId || entrada.operationId,
          "operacaoId",
          128,
      );
      const db = admin.firestore();
      let descritorOperacao;
      const respostaConcluida = () => ({
        sucesso: true,
        ...resultadoClinicaCriada(descritorOperacao),
        mensagem: "Clinica e administrador criados; convite de senha " +
          "pendente de envio.",
      });

      try {
        descritorOperacao = criarDescritorOperacao({
          tipo: OPERATION_KIND.CREATE_CLINIC_WITH_ADMIN,
          atorUid: contexto.uid,
          operationIdSolicitado: operacaoId,
          payload: {
            nomeClinica,
            nomeAdmin,
            emailAdmin,
            plano,
            valorAssinatura,
          },
        });
        const reserva = await reservarOperacao(db, descritorOperacao);

        if (reserva.concluida) return respostaConcluida();
      } catch (error) {
        const erroHttps = erroDuravelParaHttps(error);

        if (erroHttps) throw erroHttps;
        console.error(
            "Falha ao reservar criacao duravel de clinica:",
            error && error.code || "erro_desconhecido",
        );
        throw new HttpsError(
            "unavailable",
            "Não foi possível iniciar o cadastro. Tente novamente.",
        );
      }

      let usuarioAuth;

      try {
        usuarioAuth = await garantirUsuarioAuth({
          auth: admin.auth(),
          db,
          descritor: descritorOperacao,
          especificacao: {
            uid: descritorOperacao.recursos.authUid,
            email: emailAdmin,
            displayName: nomeAdmin,
            emailVerified: false,
            disabled: false,
          },
        });
      } catch (error) {
        if (await tentarResolverConcorrencia(descritorOperacao)) {
          return respostaConcluida();
        }

        if (error && error.code === "auth/invalid-email") {
          const rollback = await rollbackDuravelSeguro(descritorOperacao);

          if (rollback.operacaoJaConcluida) return respostaConcluida();
          throw new HttpsError("invalid-argument", "E-mail inválido.");
        }

        const erroHttps = erroDuravelParaHttps(error);

        if (erroHttps) throw erroHttps;
        const concluida = await prepararRetentativaFirestore(
            descritorOperacao,
        );

        if (concluida) return respostaConcluida();
        console.error(
            "Falha ao preparar Auth da criacao duravel de clinica:",
            error && error.code || "erro_desconhecido",
        );
        throw new HttpsError(
            "unavailable",
            "Não foi possível concluir o cadastro. Tente novamente.",
        );
      }

      try {
        const resultado = await gravarClinicaComAdminSaaS({
          contexto,
          usuarioAuth,
          nomeClinica,
          nomeAdmin,
          emailAdmin,
          plano,
          valorAssinatura,
          descritorOperacao,
        });

        return {
          sucesso: true,
          ...resultado,
          mensagem: "Clinica e administrador criados; convite de senha " +
            "pendente de envio.",
        };
      } catch (error) {
        if (await tentarResolverConcorrencia(descritorOperacao)) {
          return respostaConcluida();
        }

        if (falhaPermanenteDePersistencia(error)) {
          const rollback = await rollbackDuravelSeguro(descritorOperacao);

          if (rollback.operacaoJaConcluida) return respostaConcluida();
          if (!rollback.concluido) {
            throw new HttpsError(
                "internal",
                "Falha ao concluir o cadastro e ao reverter o admin.",
            );
          }

          if (error instanceof HttpsError) throw error;
          throw new HttpsError(
              "failed-precondition",
              "O cadastro conflita com dados existentes.",
          );
        }

        const concluida = await prepararRetentativaFirestore(
            descritorOperacao,
        );

        if (concluida) return respostaConcluida();
        console.error(
            "Falha transitoria no cadastro duravel de clinica:",
            error && error.code || "erro_desconhecido",
        );
        throw new HttpsError(
            "unavailable",
            "Cadastro ainda não concluído. Tente novamente.",
        );
      }
    },
);

exports.gerarContratoZapSign = onCall(
    {
      invoker: "public",
      region: "us-central1",
      enforceAppCheck,
      secrets: [zapsignApiToken],
    },
    async (request) => {
      const contexto = await exigirContextoUsuario(
          request.auth,
          ["admin", "superAdmin"],
      );
      await exigirLimiteUso({
        action: "zapsign-create",
        subjects: [`actor:${contexto.uid}`],
        limit: 10,
        windowSeconds: 60,
      });
      const entrada = request.data || {};
      const contratoId = textoSeguro(entrada.contratoId);
      const contratoResolvido = await buscarContratoComTenant(contratoId);
      exigirAcessoAoTenant(contexto, contratoResolvido.clinicaId);
      await propagarTenantContrato(contratoResolvido);

      const payloadSalvo = contratoResolvido.contrato.payload &&
        typeof contratoResolvido.contrato.payload === "object" ?
        contratoResolvido.contrato.payload : {};
      const payloadSolicitado = entrada.payload &&
        typeof entrada.payload === "object" ? entrada.payload : {};
      const pacienteSolicitado = textoSeguro(payloadSolicitado.pacienteId);

      if (pacienteSolicitado &&
          pacienteSolicitado !== contratoResolvido.pacienteId) {
        throw new HttpsError(
            "permission-denied",
            "O payload nao pertence ao paciente do contrato.",
        );
      }

      const templateSalvo = textoSeguro(
          contratoResolvido.contrato.templateKey || payloadSalvo.templateKey,
      );
      const templateSolicitado = textoSeguro(payloadSolicitado.templateKey);

      if (templateSalvo && templateSolicitado &&
          templateSalvo !== templateSolicitado) {
        throw new HttpsError(
            "failed-precondition",
            "O template informado diverge do contrato registrado.",
        );
      }

      const payload = {
        ...payloadSalvo,
        ...payloadSolicitado,
        pacienteId: contratoResolvido.pacienteId,
        templateKey: templateSalvo || templateSolicitado,
      };
      const templateKey = payload.templateKey || "";

      if (!templateKey) {
        throw new HttpsError(
            "invalid-argument",
            "Template do contrato nao informado.",
        );
      }

      const apiToken = zapsignApiToken.value();
      return processarGeracaoContrato({
        contratoId,
        payload,
        apiToken,
        clinicaId: contratoResolvido.clinicaId,
      });
    },
);

exports.consultarContratoZapSign = onCall(
    {
      invoker: "public",
      region: "us-central1",
      enforceAppCheck,
      secrets: [zapsignApiToken],
    },
    async (request) => {
      const contexto = await exigirContextoUsuario(
          request.auth,
          ["admin", "superAdmin"],
      );
      await exigirLimiteUso({
        action: "zapsign-consult",
        subjects: [`actor:${contexto.uid}`],
        limit: 30,
        windowSeconds: 60,
      });
      const entrada = request.data || {};
      const contratoId = textoSeguro(entrada.contratoId);
      const contratoResolvido = await buscarContratoComTenant(contratoId);
      exigirAcessoAoTenant(contexto, contratoResolvido.clinicaId);
      await propagarTenantContrato(contratoResolvido);

      const dadosContrato = contratoResolvido.contrato;
      const pacienteId = contratoResolvido.pacienteId;
      const documentoRegistrado = textoSeguro(dadosContrato.zapsignDocumentId);
      const documentoSolicitado = textoSeguro(entrada.zapsignDocumentId);

      if (!documentoRegistrado) {
        throw new HttpsError(
            "failed-precondition",
            "Contrato sem documento ZapSign registrado.",
        );
      }

      if (documentoSolicitado && documentoSolicitado !== documentoRegistrado) {
        throw new HttpsError(
            "permission-denied",
            "O documento ZapSign nao pertence ao contrato informado.",
        );
      }

      const zapsignDocumentId = documentoRegistrado;
      const apiToken = zapsignApiToken.value();

      if (!apiToken) {
        throw new HttpsError(
            "failed-precondition",
            "Secret ZAPSIGN_API_TOKEN nao configurado.",
        );
      }

      try {
        const detalhe = await chamarZapSign({
          method: "GET",
          path: `/docs/${zapsignDocumentId}/`,
          apiToken,
        });

        const linksAssinatura = montarLinkAssinaturaPrincipal(detalhe.signers);
        const signatarios = mapearSignatariosZapSign(detalhe.signers);
        const statusInterno = normalizarStatusContrato(detalhe.status);

        await atualizarContrato(contratoId, {
          status: statusInterno,
          zapsignStatus: detalhe.status || "",
          zapsignDocumentId: detalhe.token || zapsignDocumentId,
          zapsignSignerToken: linksAssinatura.signerToken,
          zapsignSignerUrl: linksAssinatura.signerUrl,
          zapsignSigners: signatarios,
          zapsignOriginalFile: detalhe.original_file || "",
          zapsignSignedFile: detalhe.signed_file || "",
          respostaConsultaZapSign: detalhe,
          atualizadoEm: new Date().toISOString(),
        }, contratoResolvido.clinicaId);

        await atualizarGestanteComContrato(pacienteId, {
          contratoStatus: statusInterno,
          contratoZapSignDocumentId: detalhe.token || zapsignDocumentId,
          contratoZapSignSignerUrl: linksAssinatura.signerUrl,
          contratoZapSignSigners: signatarios,
          contratoZapSignSignedFile: detalhe.signed_file || "",
          contratoErro: "",
          contratoUltimaConsultaEm: new Date().toISOString(),
        }, contratoResolvido.clinicaId);

        await sincronizarDocumentoContrato({
          contratoId,
          pacienteId,
          clinicaId: contratoResolvido.clinicaId,
          payload: dadosContrato.payload || {},
          statusInterno,
          detalheDocumento: detalhe,
          respostaZapSign: detalhe,
          signerUrl: linksAssinatura.signerUrl,
        });

        return {
          sucesso: true,
          contratoId,
          zapsignDocumentId: detalhe.token || zapsignDocumentId,
          status: statusInterno,
          zapsignStatus: detalhe.status || "",
          zapsignSignerUrl: linksAssinatura.signerUrl,
          zapsignSigners: signatarios,
          signedFile: detalhe.signed_file || "",
          originalFile: detalhe.original_file || "",
        };
      } catch (error) {
        const errorCode = safeErrorCode(error);
        await atualizarContrato(contratoId, {
          erroConsulta: "Falha temporaria ao consultar a assinatura.",
          erroConsultaCodigo: errorCode,
          atualizadoEm: new Date().toISOString(),
        }, contratoResolvido.clinicaId);

        logSafeError("Erro ao consultar contrato na ZapSign.", error);
        throw new HttpsError(
            "internal",
            "Não foi possível consultar o contrato na ZapSign.",
        );
      }
    },
);

exports.buscarCoordenadaEndereco = onCall(
    {
      invoker: "public",
      region: "us-central1",
      enforceAppCheck,
      secrets: [googleMapsGeocodingApiKey],
      timeoutSeconds: 15,
    },
    async (request) => {
      const contexto = await exigirContextoUsuario(
          request.auth,
          ["admin", "enfermeira", "obstetra", "profissional"],
      );
      await exigirLimiteUso({
        action: "geocoding",
        subjects: [`actor:${contexto.uid}`],
        limit: 30,
        windowSeconds: 60,
      });

      const endereco = textoSeguro(request.data && request.data.endereco);

      if (endereco.length < 5 || endereco.length > 300) {
        throw new HttpsError(
            "invalid-argument",
            "Informe um endereco valido para geocodificacao.",
        );
      }

      const apiKey = googleMapsGeocodingApiKey.value();

      if (!apiKey) {
        throw new HttpsError(
            "failed-precondition",
            "Integracao de geocodificacao nao configurada.",
        );
      }

      const url = new URL(
          "https://maps.googleapis.com/maps/api/geocode/json",
      );
      url.searchParams.set("address", endereco);
      url.searchParams.set("region", "br");
      url.searchParams.set("key", apiKey);

      let resposta;

      try {
        resposta = await fetch(url, {
          signal: AbortSignal.timeout(10000),
        });
      } catch (_) {
        throw new HttpsError(
            "unavailable",
            "Servico de geocodificacao indisponivel.",
        );
      }

      if (!resposta.ok) {
        throw new HttpsError(
            "unavailable",
            "Servico de geocodificacao indisponivel.",
        );
      }

      const dados = await resposta.json();
      const primeiroResultado = Array.isArray(dados.results) ?
        dados.results[0] : null;
      const localizacao = primeiroResultado &&
        primeiroResultado.geometry &&
        primeiroResultado.geometry.location;
      const latitude = Number(localizacao && localizacao.lat);
      const longitude = Number(localizacao && localizacao.lng);

      if (dados.status !== "OK" ||
          !Number.isFinite(latitude) ||
          !Number.isFinite(longitude)) {
        throw new HttpsError(
            "not-found",
            "Não foi possível localizar o endereço informado.",
        );
      }

      return {latitude, longitude};
    },
);

exports.reenviarLinkTrocaSenhaGestante = onRequest(
    {
      region: "us-central1",
    },
    async (req, res) => {
      const originAllowed = applyRestrictedCors(req, res);

      if (!originAllowed) {
        res.status(403).json({
          sucesso: false,
          mensagem: "Origem nao autorizada.",
        });
        return;
      }

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.set("Allow", "POST, OPTIONS");
        res.status(405).json({
          sucesso: false,
          mensagem: "Método não permitido.",
        });
        return;
      }

      const contentLength = Number(req.headers["content-length"] || 0);
      let parsedBodyLength = 0;
      try {
        parsedBodyLength = Buffer.byteLength(
            JSON.stringify(req.body || {}),
            "utf8",
        );
      } catch (_) {
        parsedBodyLength = 16 * 1024 + 1;
      }
      if ((Number.isFinite(contentLength) && contentLength > 16 * 1024) ||
          parsedBodyLength > 16 * 1024) {
        res.status(413).json({
          sucesso: false,
          mensagem: "Solicitacao excede o limite permitido.",
        });
        return;
      }

      try {
        const decodedToken = await autenticarRedefinicaoSenha(
            req.headers.authorization,
        );
        const resultado = await solicitarRedefinicaoSenhaPacienteCore(
            decodedToken,
            req.body,
        );

        res.status(200).json({
          ...resultado,
          gestanteId: resultado.pacienteId,
          emailGestante: resultado.emailPaciente,
          telefoneGestante: resultado.telefonePaciente,
          nomeGestante: resultado.nomePaciente,
        });
      } catch (error) {
        logSafeError("Erro ao registrar redefinicao de senha.", error);

        const statusHttp = statusHttpParaErro(error);
        const mensagem = statusHttp === 500 ?
          "Erro interno ao registrar a redefinicao de senha." :
          (error.message || "Solicitacao de redefinicao nao autorizada.");

        res.status(statusHttp).json({
          sucesso: false,
          mensagem,
        });
      }
    },
);

exports.solicitarRedefinicaoSenhaPaciente = onCall(
    {
      region: "us-central1",
      invoker: "public",
      enforceAppCheck,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Voce precisa estar logado.",
        );
      }

      const authorizationHeader = request.rawRequest &&
        request.rawRequest.headers ?
        request.rawRequest.headers.authorization : "";
      const decodedToken = await autenticarRedefinicaoSenha(
          authorizationHeader,
          request.auth,
      );

      return solicitarRedefinicaoSenhaPacienteCore(
          decodedToken,
          request.data,
      );
    },
);
