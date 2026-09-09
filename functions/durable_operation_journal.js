/* eslint-disable require-jsdoc */
"use strict";

const crypto = require("node:crypto");

const JOURNAL_SCHEMA_VERSION = 1;
const GLOBAL_OPERATION_COLLECTION = "operacoesSistema";

const OPERATION_KIND = Object.freeze({
  CREATE_CLINIC_USER: "criar_usuario_clinica",
  CREATE_CLINIC_WITH_ADMIN: "criar_clinica_com_admin_saas",
});

const OPERATION_STATE = Object.freeze({
  PENDING_AUTH: "pending_auth",
  AUTH_READY: "auth_ready",
  FIRESTORE_RETRY: "firestore_retry",
  COMMITTED: "committed",
  ROLLBACK_REQUIRED: "rollback_required",
  ROLLED_BACK: "rolled_back",
});

const KNOWN_STATES = new Set(Object.values(OPERATION_STATE));
const RETRYABLE_STATES = new Set([
  OPERATION_STATE.PENDING_AUTH,
  OPERATION_STATE.AUTH_READY,
  OPERATION_STATE.FIRESTORE_RETRY,
  OPERATION_STATE.ROLLED_BACK,
]);

class DurableOperationError extends Error {
  constructor(code, message, retryable = false) {
    super(message);
    this.name = "DurableOperationError";
    this.code = code;
    this.retryable = retryable;
  }
}

function exigirTexto(valor, campo, tamanhoMaximo = 512) {
  if (typeof valor !== "string") {
    throw new DurableOperationError(
        "invalid-operation-input",
        `${campo} deve ser texto.`,
    );
  }

  const texto = valor.trim();
  const possuiControle = Array.from(texto).some((caractere) => {
    const codigo = caractere.charCodeAt(0);
    return codigo <= 31 || codigo === 127;
  });

  if (!texto || texto.length > tamanhoMaximo || possuiControle) {
    throw new DurableOperationError(
        "invalid-operation-input",
        `${campo} invalido.`,
    );
  }

  return texto;
}

function normalizarValorCanonico(valor, caminho = "payload") {
  if (valor === null || typeof valor === "string" ||
      typeof valor === "boolean") {
    return valor;
  }

  if (typeof valor === "number") {
    if (!Number.isFinite(valor)) {
      throw new DurableOperationError(
          "invalid-operation-payload",
          `${caminho} contem numero nao finito.`,
      );
    }

    return Object.is(valor, -0) ? 0 : valor;
  }

  if (Array.isArray(valor)) {
    return valor.map((item, indice) =>
      normalizarValorCanonico(item, `${caminho}[${indice}]`));
  }

  if (valor && typeof valor === "object" &&
      Object.getPrototypeOf(valor) === Object.prototype) {
    const resultado = {};

    for (const chave of Object.keys(valor).sort()) {
      if (valor[chave] === undefined) {
        continue;
      }
      resultado[chave] = normalizarValorCanonico(
          valor[chave],
          `${caminho}.${chave}`,
      );
    }

    return resultado;
  }

  throw new DurableOperationError(
      "invalid-operation-payload",
      `${caminho} contem valor nao serializavel.`,
  );
}

function serializarCanonico(valor) {
  return JSON.stringify(normalizarValorCanonico(valor));
}

function hashCanonico(valor) {
  return crypto
      .createHash("sha256")
      .update(serializarCanonico(valor), "utf8")
      .digest("hex");
}

function hashPayload(payload) {
  return hashCanonico({dominio: "natus-operation-payload-v1", payload});
}

function hashPrivado(dominio, valor) {
  return hashCanonico({dominio, valor});
}

function resolverOperationId({
  tipo,
  atorUid,
  clinicaId = "",
  operationIdSolicitado = "",
  chaveSemantica = "",
}) {
  if (!Object.values(OPERATION_KIND).includes(tipo)) {
    throw new DurableOperationError(
        "invalid-operation-kind",
        "Tipo de operacao nao suportado.",
    );
  }

  const ator = exigirTexto(atorUid, "atorUid", 128);
  const tenant = clinicaId ?
    exigirTexto(clinicaId, "clinicaId", 256) : "";
  const chave = operationIdSolicitado ?
    exigirTexto(operationIdSolicitado, "operationId", 128) :
    exigirTexto(chaveSemantica, "chaveSemantica", 512);
  const digest = hashPrivado("natus-operation-id-v1", {
    tipo,
    ator,
    tenant,
    chave,
  });

  return `op_${digest.slice(0, 48)}`;
}

function idRecurso(operationId, rotulo, prefixo) {
  const operacao = exigirTexto(operationId, "operationId", 64);
  const label = exigirTexto(rotulo, "rotulo", 64);
  const prefix = exigirTexto(prefixo, "prefixo", 16);
  const digest = hashPrivado("natus-operation-resource-v1", {
    operacao,
    rotulo: label,
  });

  return `${prefix}_${digest.slice(0, 40)}`;
}

function recursosDeterministicos(tipo, operationId) {
  if (tipo === OPERATION_KIND.CREATE_CLINIC_USER) {
    return Object.freeze({
      authUid: idRecurso(operationId, "auth-user", "usr"),
      logId: idRecurso(operationId, "administrative-log", "log"),
    });
  }

  if (tipo === OPERATION_KIND.CREATE_CLINIC_WITH_ADMIN) {
    return Object.freeze({
      authUid: idRecurso(operationId, "auth-user", "usr"),
      clinicId: idRecurso(operationId, "clinic", "cli"),
      subscriptionId: idRecurso(operationId, "subscription", "sub"),
      logId: idRecurso(operationId, "super-admin-log", "log"),
    });
  }

  throw new DurableOperationError(
      "invalid-operation-kind",
      "Tipo de operacao nao suportado.",
  );
}

function criarDescritorOperacao({
  tipo,
  atorUid,
  clinicaId = "",
  operationIdSolicitado = "",
  chaveSemantica = "",
  payload,
}) {
  const operationId = resolverOperationId({
    tipo,
    atorUid,
    clinicaId,
    operationIdSolicitado,
    chaveSemantica,
  });
  const recursos = recursosDeterministicos(tipo, operationId);

  return Object.freeze({
    tipo,
    operationId,
    clinicaId,
    payloadHash: hashPayload(payload),
    atorHash: hashPrivado("natus-operation-actor-v1", atorUid),
    recursos,
    recursosHash: hashPrivado("natus-operation-resources-v1", recursos),
  });
}

function caminhoJournal(descritor) {
  if (descritor.tipo === OPERATION_KIND.CREATE_CLINIC_USER) {
    const clinicaId = exigirTexto(descritor.clinicaId, "clinicaId", 256);
    return `clinicas/${clinicaId}/${GLOBAL_OPERATION_COLLECTION}/` +
      descritor.operationId;
  }

  if (descritor.tipo === OPERATION_KIND.CREATE_CLINIC_WITH_ADMIN) {
    return `${GLOBAL_OPERATION_COLLECTION}/${descritor.operationId}`;
  }

  throw new DurableOperationError(
      "invalid-operation-kind",
      "Tipo de operacao nao suportado.",
  );
}

function refJournal(db, descritor) {
  return db.doc(caminhoJournal(descritor));
}

function dadosBaseJournal(descritor) {
  return {
    versao: JOURNAL_SCHEMA_VERSION,
    tipo: descritor.tipo,
    payloadHash: descritor.payloadHash,
    atorHash: descritor.atorHash,
    recursosHash: descritor.recursosHash,
  };
}

function validarSnapshotJournal(dados, descritor) {
  const esperado = dadosBaseJournal(descritor);

  for (const campo of Object.keys(esperado)) {
    if (dados[campo] !== esperado[campo]) {
      throw new DurableOperationError(
          "operation-payload-conflict",
          "Operation ID ja utilizado com outro payload ou contexto.",
      );
    }
  }

  if (!KNOWN_STATES.has(dados.estado)) {
    throw new DurableOperationError(
        "invalid-operation-state",
        "Journal possui estado desconhecido e exige reconciliacao.",
    );
  }
}

function agoraPadrao() {
  return new Date();
}

async function reservarOperacao(db, descritor, agora = agoraPadrao) {
  const ref = refJournal(db, descritor);
  const resultado = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const instante = agora();

    if (!snapshot.exists) {
      const dados = {
        ...dadosBaseJournal(descritor),
        estado: OPERATION_STATE.PENDING_AUTH,
        tentativas: 1,
        ultimoErroCodigo: "",
        criadoEm: instante,
        atualizadoEm: instante,
      };
      transaction.create(ref, dados);
      return {estado: dados.estado, concluida: false};
    }

    const dados = snapshot.data() || {};
    validarSnapshotJournal(dados, descritor);

    if (dados.estado === OPERATION_STATE.COMMITTED) {
      return {estado: dados.estado, concluida: true};
    }

    if (dados.estado === OPERATION_STATE.ROLLBACK_REQUIRED) {
      throw new DurableOperationError(
          "operation-requires-reconciliation",
          "Operacao bloqueada ate reconciliacao administrativa.",
      );
    }

    if (!RETRYABLE_STATES.has(dados.estado)) {
      throw new DurableOperationError(
          "invalid-operation-state",
          "Operacao nao pode ser retomada no estado atual.",
      );
    }

    // Uma chamada duplicada que encontra o Auth pronto nao deve alterar a
    // versao do journal: um commit de negocio concorrente pode ja ter usado
    // essa versao como precondicao atomica.
    if ([
      OPERATION_STATE.AUTH_READY,
      OPERATION_STATE.FIRESTORE_RETRY,
    ].includes(dados.estado)) {
      return {estado: dados.estado, concluida: false};
    }

    const reiniciar = dados.estado === OPERATION_STATE.ROLLED_BACK;
    const estado = reiniciar ?
      OPERATION_STATE.PENDING_AUTH : dados.estado;
    transaction.update(ref, {
      estado,
      tentativas: Number(dados.tentativas || 0) + 1,
      ultimoErroCodigo: reiniciar ? "" :
        String(dados.ultimoErroCodigo || ""),
      atualizadoEm: instante,
    });
    return {estado, concluida: false};
  });

  return Object.freeze({
    ...descritor,
    journalPath: ref.path,
    estado: resultado.estado,
    concluida: resultado.concluida,
  });
}

async function transicionarOperacao({
  db,
  descritor,
  estadosPermitidos,
  novoEstado,
  ultimoErroCodigo = "",
  agora = agoraPadrao,
}) {
  const ref = refJournal(db, descritor);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);

    if (!snapshot.exists) {
      throw new DurableOperationError(
          "operation-not-reserved",
          "Operacao precisa ser reservada antes da transicao.",
      );
    }

    const dados = snapshot.data() || {};
    validarSnapshotJournal(dados, descritor);

    if (dados.estado === OPERATION_STATE.COMMITTED) {
      throw new DurableOperationError(
          "operation-already-committed",
          "Operacao concluida nao aceita novas transicoes.",
      );
    }

    if (!estadosPermitidos.includes(dados.estado)) {
      throw new DurableOperationError(
          "invalid-operation-transition",
          "Transicao de estado rejeitada pelo journal.",
      );
    }

    if (dados.estado === novoEstado && !ultimoErroCodigo) {
      return novoEstado;
    }

    transaction.update(ref, {
      estado: novoEstado,
      ultimoErroCodigo: sanitizarCodigoErro(ultimoErroCodigo),
      atualizadoEm: agora(),
    });
    return novoEstado;
  });
}

function sanitizarCodigoErro(valor) {
  const texto = String(valor || "").trim();

  if (!texto) return "";
  if (!/^[a-z0-9_-]{1,64}$/.test(texto)) {
    throw new DurableOperationError(
        "invalid-operation-error-code",
        "Codigo de erro do journal invalido.",
    );
  }

  return texto;
}

async function marcarAuthPronto(db, descritor, agora = agoraPadrao) {
  return transicionarOperacao({
    db,
    descritor,
    estadosPermitidos: [
      OPERATION_STATE.PENDING_AUTH,
      OPERATION_STATE.AUTH_READY,
      OPERATION_STATE.FIRESTORE_RETRY,
    ],
    novoEstado: OPERATION_STATE.AUTH_READY,
    agora,
  });
}

async function marcarFirestoreParaRetentativa(
    db,
    descritor,
    codigoErro = "firestore_commit_failed",
    agora = agoraPadrao,
) {
  return transicionarOperacao({
    db,
    descritor,
    estadosPermitidos: [
      OPERATION_STATE.PENDING_AUTH,
      OPERATION_STATE.AUTH_READY,
      OPERATION_STATE.FIRESTORE_RETRY,
    ],
    novoEstado: OPERATION_STATE.FIRESTORE_RETRY,
    ultimoErroCodigo: codigoErro,
    agora,
  });
}

async function marcarRollbackNecessario(
    db,
    descritor,
    codigoErro,
    agora = agoraPadrao,
) {
  return transicionarOperacao({
    db,
    descritor,
    estadosPermitidos: [
      OPERATION_STATE.PENDING_AUTH,
      OPERATION_STATE.AUTH_READY,
      OPERATION_STATE.FIRESTORE_RETRY,
      OPERATION_STATE.ROLLED_BACK,
      OPERATION_STATE.ROLLBACK_REQUIRED,
    ],
    novoEstado: OPERATION_STATE.ROLLBACK_REQUIRED,
    ultimoErroCodigo: codigoErro,
    agora,
  });
}

async function marcarRollbackConcluido(
    db,
    descritor,
    agora = agoraPadrao,
) {
  return transicionarOperacao({
    db,
    descritor,
    estadosPermitidos: [
      OPERATION_STATE.PENDING_AUTH,
      OPERATION_STATE.AUTH_READY,
      OPERATION_STATE.FIRESTORE_RETRY,
      OPERATION_STATE.ROLLBACK_REQUIRED,
      OPERATION_STATE.ROLLED_BACK,
    ],
    novoEstado: OPERATION_STATE.ROLLED_BACK,
    agora,
  });
}

function codigoAuth(error) {
  return String(error && error.code || "");
}

function authUsuarioNaoEncontrado(error) {
  return codigoAuth(error) === "auth/user-not-found";
}

function authUidEmUso(error) {
  return codigoAuth(error) === "auth/uid-already-exists";
}

async function buscarUsuarioAuth(auth, uid) {
  try {
    return await auth.getUser(uid);
  } catch (error) {
    if (authUsuarioNaoEncontrado(error)) return null;
    throw error;
  }
}

function usuarioAuthCompativel(usuario, especificacao) {
  const emailAtual = String(usuario.email || "").trim().toLowerCase();
  const emailEsperado = String(especificacao.email || "")
      .trim()
      .toLowerCase();
  const nomeCompativel = !Object.hasOwn(especificacao, "displayName") ||
    String(usuario.displayName || "") ===
      String(especificacao.displayName || "");
  const statusCompativel = !Object.hasOwn(especificacao, "disabled") ||
    Boolean(usuario.disabled) === Boolean(especificacao.disabled);
  return usuario.uid === especificacao.uid &&
    emailAtual === emailEsperado &&
    nomeCompativel &&
    statusCompativel;
}

async function garantirUsuarioAuth({
  auth,
  db,
  descritor,
  especificacao,
  validarUsuario = usuarioAuthCompativel,
  agora = agoraPadrao,
}) {
  if (!especificacao ||
      especificacao.uid !== descritor.recursos.authUid) {
    throw new DurableOperationError(
        "invalid-auth-resource",
        "UID do Auth deve ser o recurso deterministico da operacao.",
    );
  }

  const estadoInicial = await consultarOperacao(db, descritor);

  if (!estadoInicial) {
    throw new DurableOperationError(
        "operation-not-reserved",
        "Operacao precisa ser reservada antes do Auth.",
    );
  }

  if (estadoInicial.estado === OPERATION_STATE.COMMITTED) {
    throw new DurableOperationError(
        "operation-already-committed",
        "Operacao ja concluida.",
    );
  }

  if ([
    OPERATION_STATE.ROLLBACK_REQUIRED,
    OPERATION_STATE.ROLLED_BACK,
  ].includes(estadoInicial.estado)) {
    throw new DurableOperationError(
        "operation-requires-reconciliation",
        "Operacao nao pode criar Auth durante rollback.",
    );
  }

  let usuario = await buscarUsuarioAuth(auth, especificacao.uid);

  if (!usuario) {
    try {
      usuario = await auth.createUser(especificacao);
    } catch (error) {
      if (authUidEmUso(error)) {
        usuario = await buscarUsuarioAuth(auth, especificacao.uid);
      } else if (codigoAuth(error) === "auth/email-already-exists") {
        await marcarRollbackNecessario(
            db,
            descritor,
            "auth_email_conflict",
            agora,
        );
        throw new DurableOperationError(
            "auth-identity-conflict",
            "E-mail ja pertence a outra identidade Auth.",
        );
      } else {
        throw error;
      }
    }
  }

  if (!usuario || !validarUsuario(usuario, especificacao)) {
    await marcarRollbackNecessario(
        db,
        descritor,
        "auth_uid_conflict",
        agora,
    );
    throw new DurableOperationError(
        "auth-identity-conflict",
        "UID deterministico pertence a outra identidade Auth.",
    );
  }

  try {
    await marcarAuthPronto(db, descritor, agora);
  } catch (error) {
    const estadoAtual = await consultarOperacao(db, descritor);

    if (estadoAtual && estadoAtual.estado === OPERATION_STATE.COMMITTED) {
      return usuario;
    }

    if (estadoAtual && [
      OPERATION_STATE.ROLLBACK_REQUIRED,
      OPERATION_STATE.ROLLED_BACK,
    ].includes(estadoAtual.estado)) {
      try {
        await reverterUsuarioAuth({
          auth,
          db,
          descritor,
          agora,
        });
      } catch (rollbackError) {
        if (rollbackError instanceof DurableOperationError &&
            rollbackError.code === "operation-already-committed") {
          return usuario;
        }
        throw rollbackError;
      }

      throw new DurableOperationError(
          "operation-requires-reconciliation",
          "Auth descartado porque a operacao entrou em rollback.",
      );
    }

    throw error;
  }

  return usuario;
}

async function prepararCommitOperacao(db, descritor) {
  const ref = refJournal(db, descritor);
  const snapshot = await ref.get();

  if (!snapshot.exists) {
    throw new DurableOperationError(
        "operation-not-reserved",
        "Operacao precisa ser reservada antes do commit.",
    );
  }

  const dados = snapshot.data() || {};
  validarSnapshotJournal(dados, descritor);

  if (dados.estado === OPERATION_STATE.COMMITTED) {
    return Object.freeze({
      ...descritor,
      journalPath: ref.path,
      journalRef: ref,
      estado: dados.estado,
      concluida: true,
      journalUpdateTime: snapshot.updateTime,
    });
  }

  if (![OPERATION_STATE.AUTH_READY, OPERATION_STATE.FIRESTORE_RETRY]
      .includes(dados.estado)) {
    throw new DurableOperationError(
        "operation-not-ready-to-commit",
        "Auth precisa estar pronto antes do commit Firestore.",
    );
  }

  return Object.freeze({
    ...descritor,
    journalPath: ref.path,
    journalRef: ref,
    estado: dados.estado,
    concluida: false,
    journalUpdateTime: snapshot.updateTime,
  });
}

function adicionarCommitAoBatch(batch, commit, agora = agoraPadrao) {
  if (commit.concluida) {
    throw new DurableOperationError(
        "operation-already-committed",
        "Operacao concluida nao deve gerar outro batch.",
    );
  }

  if (!commit.journalUpdateTime) {
    throw new DurableOperationError(
        "operation-missing-precondition",
        "Commit do journal exige precondicao de versao.",
    );
  }

  if (!commit.journalRef) {
    throw new DurableOperationError(
        "operation-missing-reference",
        "Commit do journal exige uma referencia Firestore.",
    );
  }

  batch.update(
      commit.journalRef,
      {
        estado: OPERATION_STATE.COMMITTED,
        ultimoErroCodigo: "",
        concluidoEm: agora(),
        atualizadoEm: agora(),
      },
      {lastUpdateTime: commit.journalUpdateTime},
  );
}

async function consultarOperacao(db, descritor) {
  const snapshot = await refJournal(db, descritor).get();

  if (!snapshot.exists) return null;
  const dados = snapshot.data() || {};
  validarSnapshotJournal(dados, descritor);
  return Object.freeze({...dados});
}

async function reverterUsuarioAuth({
  auth,
  db,
  descritor,
  agora = agoraPadrao,
}) {
  // A transicao transacional invalida qualquer batch de commit preparado por
  // outra invocacao. Assim um rollback nunca remove o Auth de uma operacao que
  // ja foi concluida ou que conclua concorrentemente.
  await marcarRollbackNecessario(
      db,
      descritor,
      "auth_rollback_started",
      agora,
  );

  try {
    await auth.deleteUser(descritor.recursos.authUid);
  } catch (error) {
    if (!authUsuarioNaoEncontrado(error)) {
      await marcarRollbackNecessario(
          db,
          descritor,
          "auth_rollback_failed",
          agora,
      );
      return false;
    }
  }

  await marcarRollbackConcluido(db, descritor, agora);
  return true;
}

module.exports = {
  DurableOperationError,
  GLOBAL_OPERATION_COLLECTION,
  JOURNAL_SCHEMA_VERSION,
  OPERATION_KIND,
  OPERATION_STATE,
  adicionarCommitAoBatch,
  caminhoJournal,
  consultarOperacao,
  criarDescritorOperacao,
  garantirUsuarioAuth,
  hashPayload,
  marcarFirestoreParaRetentativa,
  marcarRollbackConcluido,
  marcarRollbackNecessario,
  prepararCommitOperacao,
  recursosDeterministicos,
  reservarOperacao,
  resolverOperationId,
  reverterUsuarioAuth,
  serializarCanonico,
  usuarioAuthCompativel,
};
