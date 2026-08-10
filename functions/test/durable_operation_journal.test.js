/* eslint-disable require-jsdoc */
"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  DurableOperationError,
  GLOBAL_OPERATION_COLLECTION,
  OPERATION_KIND,
  OPERATION_STATE,
  adicionarCommitAoBatch,
  caminhoJournal,
  consultarOperacao,
  criarDescritorOperacao,
  garantirUsuarioAuth,
  hashPayload,
  marcarFirestoreParaRetentativa,
  marcarRollbackNecessario,
  prepararCommitOperacao,
  reservarOperacao,
  reverterUsuarioAuth,
  serializarCanonico,
} = require("../durable_operation_journal");

function copiar(valor) {
  if (!valor || typeof valor !== "object") return valor;
  if (valor instanceof Date) return new Date(valor.getTime());
  if (Array.isArray(valor)) return valor.map(copiar);
  return Object.fromEntries(
      Object.entries(valor).map(([chave, item]) => [chave, copiar(item)]),
  );
}

class MockDocumentSnapshot {
  constructor(ref, entrada) {
    this.ref = ref;
    this.exists = Boolean(entrada);
    this.updateTime = entrada ? entrada.versao : undefined;
    this._dados = entrada ? copiar(entrada.dados) : undefined;
  }

  data() {
    return copiar(this._dados);
  }
}

class MockDocumentReference {
  constructor(db, path) {
    this._db = db;
    this.path = path;
  }

  async get() {
    return this._db._snapshot(this.path);
  }
}

class MockWrites {
  constructor(db) {
    this.db = db;
    this.writes = [];
  }

  create(ref, dados) {
    this.writes.push({tipo: "create", ref, dados: copiar(dados)});
    return this;
  }

  set(ref, dados, opcoes = {}) {
    this.writes.push({
      tipo: "set",
      ref,
      dados: copiar(dados),
      merge: Boolean(opcoes.merge),
    });
    return this;
  }

  update(ref, dados, precondicao = null) {
    this.writes.push({
      tipo: "update",
      ref,
      dados: copiar(dados),
      precondicao,
    });
    return this;
  }

  _validar() {
    const simulacao = new Map(this.db._documentos);

    for (const escrita of this.writes) {
      const atual = simulacao.get(escrita.ref.path);

      if (escrita.tipo === "create" && atual) {
        const error = new Error("Documento ja existe.");
        error.code = "already-exists";
        throw error;
      }

      if (escrita.tipo === "update" && !atual) {
        const error = new Error("Documento nao existe.");
        error.code = "not-found";
        throw error;
      }

      if (escrita.precondicao &&
          escrita.precondicao.lastUpdateTime !== atual.versao) {
        const error = new Error("Precondicao de versao falhou.");
        error.code = "failed-precondition";
        throw error;
      }

      const dadosAtuais = atual ? atual.dados : {};
      const mesclar = escrita.tipo === "update" || escrita.merge;
      simulacao.set(escrita.ref.path, {
        versao: atual ? atual.versao : 0,
        dados: mesclar ?
          {...copiar(dadosAtuais), ...copiar(escrita.dados)} :
          copiar(escrita.dados),
      });
    }
  }

  _aplicar() {
    this._validar();

    for (const escrita of this.writes) {
      const atual = this.db._documentos.get(escrita.ref.path);
      const dadosAtuais = atual ? atual.dados : {};
      const mesclar = escrita.tipo === "update" || escrita.merge;
      this.db._versao += 1;
      this.db._documentos.set(escrita.ref.path, {
        versao: this.db._versao,
        dados: mesclar ?
          {...copiar(dadosAtuais), ...copiar(escrita.dados)} :
          copiar(escrita.dados),
      });
    }
  }
}

class MockBatch extends MockWrites {
  async commit() {
    this._aplicar();
  }
}

class MockFirestore {
  constructor() {
    this._documentos = new Map();
    this._versao = 0;
  }

  doc(path) {
    return new MockDocumentReference(this, path);
  }

  batch() {
    return new MockBatch(this);
  }

  _snapshot(path) {
    return new MockDocumentSnapshot(
        this.doc(path),
        this._documentos.get(path),
    );
  }

  async runTransaction(callback) {
    const transaction = new MockWrites(this);
    transaction.get = async (ref) => this._snapshot(ref.path);
    const resultado = await callback(transaction);
    transaction._aplicar();
    return resultado;
  }
}

class MockAuth {
  constructor() {
    this.usuarios = new Map();
    this.createCalls = 0;
    this.deleteCalls = 0;
  }

  async getUser(uid) {
    const usuario = this.usuarios.get(uid);

    if (!usuario) {
      const error = new Error("Usuario nao encontrado.");
      error.code = "auth/user-not-found";
      throw error;
    }

    return copiar(usuario);
  }

  async createUser(especificacao) {
    this.createCalls += 1;

    if (this.usuarios.has(especificacao.uid)) {
      const error = new Error("UID ja existe.");
      error.code = "auth/uid-already-exists";
      throw error;
    }

    const email = String(especificacao.email || "").toLowerCase();
    const emailEmUso = Array.from(this.usuarios.values())
        .some((usuario) => String(usuario.email || "").toLowerCase() === email);

    if (emailEmUso) {
      const error = new Error("E-mail ja existe.");
      error.code = "auth/email-already-exists";
      throw error;
    }

    const usuario = copiar(especificacao);
    this.usuarios.set(usuario.uid, usuario);
    return copiar(usuario);
  }

  async deleteUser(uid) {
    this.deleteCalls += 1;

    if (!this.usuarios.delete(uid)) {
      const error = new Error("Usuario nao encontrado.");
      error.code = "auth/user-not-found";
      throw error;
    }
  }
}

const instante = new Date("2026-07-22T12:00:00.000Z");
const agoraFixo = () => new Date(instante.getTime());

function descritorUsuario(sobrescrever = {}) {
  return criarDescritorOperacao({
    tipo: OPERATION_KIND.CREATE_CLINIC_USER,
    atorUid: "admin-uid-sensivel",
    clinicaId: "clinic-a",
    operationIdSolicitado: "018f1422-d5d9-7aa0-9000-123456789abc",
    chaveSemantica: "",
    payload: {
      nome: "Pessoa Teste",
      email: "pessoa@example.com",
      tipo: "admin",
      idVinculo: "",
    },
    ...sobrescrever,
  });
}

function descritorClinica(sobrescrever = {}) {
  return criarDescritorOperacao({
    tipo: OPERATION_KIND.CREATE_CLINIC_WITH_ADMIN,
    atorUid: "super-admin-uid-sensivel",
    operationIdSolicitado: "018f1422-d5d9-7aa0-9000-abcdefabcdef",
    chaveSemantica: "",
    payload: {
      nomeClinica: "Clinica Teste",
      nomeAdmin: "Pessoa Admin",
      emailAdmin: "admin@example.com",
      plano: "teste",
      valorAssinatura: 100,
    },
    ...sobrescrever,
  });
}

test("serializacao e hash sao estaveis independentemente da ordem", () => {
  assert.equal(
      serializarCanonico({b: 2, a: {d: 4, c: 3}}),
      serializarCanonico({a: {c: 3, d: 4}, b: 2}),
  );
  assert.equal(
      hashPayload({email: "a@example.com", nome: "A"}),
      hashPayload({nome: "A", email: "a@example.com"}),
  );
  assert.notEqual(hashPayload({nome: "A"}), hashPayload({nome: "B"}));
  assert.throws(
      () => hashPayload({valor: Number.POSITIVE_INFINITY}),
      {code: "invalid-operation-payload"},
  );
});

test("IDs, caminhos e recursos sao deterministas e opacos", () => {
  const primeiro = descritorUsuario();
  const segundo = descritorUsuario();
  const clinica = descritorClinica();

  assert.equal(primeiro.operationId, segundo.operationId);
  assert.deepEqual(primeiro.recursos, segundo.recursos);
  assert.match(primeiro.operationId, /^op_[a-f0-9]{48}$/);
  assert.match(primeiro.recursos.authUid, /^usr_[a-f0-9]{40}$/);
  assert.equal(
      caminhoJournal(primeiro),
      `clinicas/clinic-a/${GLOBAL_OPERATION_COLLECTION}/` +
        primeiro.operationId,
  );
  assert.equal(
      caminhoJournal(clinica),
      `${GLOBAL_OPERATION_COLLECTION}/${clinica.operationId}`,
  );

  const representacao = JSON.stringify({primeiro, clinica});
  for (const pii of [
    "pessoa@example.com",
    "Pessoa Teste",
    "admin-uid-sensivel",
    "admin@example.com",
    "Clinica Teste",
  ]) {
    assert.doesNotMatch(representacao, new RegExp(pii, "i"));
  }
});

test("reserva nao persiste payload nem identificadores pessoais", async () => {
  const db = new MockFirestore();
  const descritor = descritorUsuario();
  const reserva = await reservarOperacao(db, descritor, agoraFixo);
  const dados = await consultarOperacao(db, descritor);
  const persistido = JSON.stringify(dados);

  assert.equal(reserva.estado, OPERATION_STATE.PENDING_AUTH);
  assert.equal(reserva.concluida, false);
  assert.equal(dados.tentativas, 1);
  assert.equal(dados.payloadHash, descritor.payloadHash);
  assert.doesNotMatch(persistido, /pessoa@example\.com/i);
  assert.doesNotMatch(persistido, /Pessoa Teste/i);
  assert.doesNotMatch(persistido, /admin-uid-sensivel/i);
  assert.equal(Object.hasOwn(dados, "payload"), false);
  assert.equal(Object.hasOwn(dados, "recursos"), false);
});

test("mesmo operationId rejeita payload ou contexto divergente", async () => {
  const db = new MockFirestore();
  const original = descritorUsuario();
  await reservarOperacao(db, original, agoraFixo);

  const divergente = descritorUsuario({
    payload: {
      nome: "Outro nome",
      email: "pessoa@example.com",
      tipo: "admin",
      idVinculo: "",
    },
  });

  await assert.rejects(
      reservarOperacao(db, divergente, agoraFixo),
      {code: "operation-payload-conflict"},
  );

  const outroAtor = descritorUsuario({atorUid: "outro-admin"});
  assert.notEqual(outroAtor.operationId, original.operationId);
});

test("retoma Auth criado antes da atualizacao do journal", async () => {
  const db = new MockFirestore();
  const auth = new MockAuth();
  const descritor = descritorUsuario();
  await reservarOperacao(db, descritor, agoraFixo);

  auth.usuarios.set(descritor.recursos.authUid, {
    uid: descritor.recursos.authUid,
    email: "pessoa@example.com",
    displayName: "Pessoa Teste",
  });
  const usuario = await garantirUsuarioAuth({
    auth,
    db,
    descritor,
    especificacao: {
      uid: descritor.recursos.authUid,
      email: "pessoa@example.com",
      displayName: "Pessoa Teste",
    },
    agora: agoraFixo,
  });

  assert.equal(usuario.uid, descritor.recursos.authUid);
  assert.equal(auth.createCalls, 0);
  assert.equal(
      (await consultarOperacao(db, descritor)).estado,
      OPERATION_STATE.AUTH_READY,
  );
});

test("chamada duplicada nao invalida commit com Auth pronto", async () => {
  const db = new MockFirestore();
  const auth = new MockAuth();
  const descritor = descritorUsuario();
  await reservarOperacao(db, descritor, agoraFixo);
  const especificacao = {
    uid: descritor.recursos.authUid,
    email: "pessoa@example.com",
    displayName: "Pessoa Teste",
  };
  await garantirUsuarioAuth({
    auth,
    db,
    descritor,
    especificacao,
    agora: agoraFixo,
  });
  const commitInicial = await prepararCommitOperacao(db, descritor);
  const tentativasIniciais = (await consultarOperacao(
      db,
      descritor,
  )).tentativas;

  const repeticao = await reservarOperacao(db, descritor, agoraFixo);
  await garantirUsuarioAuth({
    auth,
    db,
    descritor,
    especificacao,
    agora: agoraFixo,
  });
  const commitDepoisDaRepeticao = await prepararCommitOperacao(
      db,
      descritor,
  );

  assert.equal(repeticao.estado, OPERATION_STATE.AUTH_READY);
  assert.equal(
      commitDepoisDaRepeticao.journalUpdateTime,
      commitInicial.journalUpdateTime,
  );
  assert.equal(
      (await consultarOperacao(db, descritor)).tentativas,
      tentativasIniciais,
  );
  assert.equal(auth.createCalls, 1);
});

test("conflito de identidade Auth bloqueia para reconciliacao", async () => {
  const db = new MockFirestore();
  const auth = new MockAuth();
  const descritor = descritorUsuario();
  await reservarOperacao(db, descritor, agoraFixo);

  auth.usuarios.set(descritor.recursos.authUid, {
    uid: descritor.recursos.authUid,
    email: "outra@example.com",
  });

  await assert.rejects(
      garantirUsuarioAuth({
        auth,
        db,
        descritor,
        especificacao: {
          uid: descritor.recursos.authUid,
          email: "pessoa@example.com",
        },
        agora: agoraFixo,
      }),
      {code: "auth-identity-conflict"},
  );
  const dados = await consultarOperacao(db, descritor);
  assert.equal(dados.estado, OPERATION_STATE.ROLLBACK_REQUIRED);
  assert.equal(dados.ultimoErroCodigo, "auth_uid_conflict");
});

test("retomada rejeita identidade renomeada ou desabilitada", async () => {
  for (const usuarioExistente of [
    {
      email: "pessoa@example.com",
      displayName: "Nome adulterado",
      disabled: false,
    },
    {
      email: "pessoa@example.com",
      displayName: "Pessoa Teste",
      disabled: true,
    },
  ]) {
    const db = new MockFirestore();
    const auth = new MockAuth();
    const descritor = descritorUsuario();
    await reservarOperacao(db, descritor, agoraFixo);
    auth.usuarios.set(descritor.recursos.authUid, {
      uid: descritor.recursos.authUid,
      ...usuarioExistente,
    });

    await assert.rejects(
        garantirUsuarioAuth({
          auth,
          db,
          descritor,
          especificacao: {
            uid: descritor.recursos.authUid,
            email: "pessoa@example.com",
            displayName: "Pessoa Teste",
            disabled: false,
          },
          agora: agoraFixo,
        }),
        {code: "auth-identity-conflict"},
    );
    assert.equal(
        (await consultarOperacao(db, descritor)).estado,
        OPERATION_STATE.ROLLBACK_REQUIRED,
    );
  }
});

test("rollback concorrente ao Auth nao deixa usuario orfao", async () => {
  const db = new MockFirestore();
  const auth = new MockAuth();
  const descritor = descritorUsuario();
  await reservarOperacao(db, descritor, agoraFixo);
  const criarOriginal = auth.createUser.bind(auth);
  auth.createUser = async (especificacao) => {
    const usuario = await criarOriginal(especificacao);
    await marcarRollbackNecessario(
        db,
        descritor,
        "domain_rollback_required",
        agoraFixo,
    );
    return usuario;
  };

  await assert.rejects(
      garantirUsuarioAuth({
        auth,
        db,
        descritor,
        especificacao: {
          uid: descritor.recursos.authUid,
          email: "pessoa@example.com",
          displayName: "Pessoa Teste",
          disabled: false,
        },
        agora: agoraFixo,
      }),
      {code: "operation-requires-reconciliation"},
  );
  assert.equal(auth.usuarios.has(descritor.recursos.authUid), false);
  assert.equal(
      (await consultarOperacao(db, descritor)).estado,
      OPERATION_STATE.ROLLED_BACK,
  );
});

test("commit do journal e dados de negocio e atomico", async () => {
  const db = new MockFirestore();
  const auth = new MockAuth();
  const descritor = descritorClinica();
  await reservarOperacao(db, descritor, agoraFixo);
  await garantirUsuarioAuth({
    auth,
    db,
    descritor,
    especificacao: {
      uid: descritor.recursos.authUid,
      email: "admin@example.com",
      displayName: "Pessoa Admin",
    },
    agora: agoraFixo,
  });

  const commit = await prepararCommitOperacao(db, descritor);
  const batch = db.batch();
  const clinicaRef = db.doc(`clinicas/${descritor.recursos.clinicId}`);
  batch.create(clinicaRef, {status: "teste"});
  adicionarCommitAoBatch(batch, commit, agoraFixo);
  await batch.commit();

  assert.equal((await clinicaRef.get()).exists, true);
  const dados = await consultarOperacao(db, descritor);
  assert.equal(dados.estado, OPERATION_STATE.COMMITTED);
  assert.deepEqual(dados.concluidoEm, instante);

  const repeticao = await reservarOperacao(db, descritor, agoraFixo);
  assert.equal(repeticao.concluida, true);
});

test(
    "precondicao obsoleta aborta batch inteiro e permite retomar",
    async () => {
      const db = new MockFirestore();
      const auth = new MockAuth();
      const descritor = descritorUsuario();
      await reservarOperacao(db, descritor, agoraFixo);
      await garantirUsuarioAuth({
        auth,
        db,
        descritor,
        especificacao: {
          uid: descritor.recursos.authUid,
          email: "pessoa@example.com",
        },
        agora: agoraFixo,
      });

      const commitObsoleto = await prepararCommitOperacao(db, descritor);
      await marcarFirestoreParaRetentativa(
          db,
          descritor,
          "firestore_commit_failed",
          agoraFixo,
      );
      const usuarioRef = db.doc(`usuarios/${descritor.recursos.authUid}`);
      const batchObsoleto = db.batch();
      batchObsoleto.create(usuarioRef, {status: "ativo"});
      adicionarCommitAoBatch(batchObsoleto, commitObsoleto, agoraFixo);

      await assert.rejects(
          batchObsoleto.commit(),
          {code: "failed-precondition"},
      );
      assert.equal((await usuarioRef.get()).exists, false);

      const retomada = await reservarOperacao(db, descritor, agoraFixo);
      assert.equal(retomada.estado, OPERATION_STATE.FIRESTORE_RETRY);
      const commitAtual = await prepararCommitOperacao(db, descritor);
      const batchAtual = db.batch();
      batchAtual.create(usuarioRef, {status: "ativo"});
      adicionarCommitAoBatch(batchAtual, commitAtual, agoraFixo);
      await batchAtual.commit();
      assert.equal((await usuarioRef.get()).exists, true);
    },
);

test(
    "rollback remove somente UID deterministico e operacao reinicia",
    async () => {
      const db = new MockFirestore();
      const auth = new MockAuth();
      const descritor = descritorUsuario();
      await reservarOperacao(db, descritor, agoraFixo);
      await garantirUsuarioAuth({
        auth,
        db,
        descritor,
        especificacao: {
          uid: descritor.recursos.authUid,
          email: "pessoa@example.com",
        },
        agora: agoraFixo,
      });
      await marcarRollbackNecessario(
          db,
          descritor,
          "domain_validation_failed",
          agoraFixo,
      );

      assert.equal(await reverterUsuarioAuth({
        auth,
        db,
        descritor,
        agora: agoraFixo,
      }), true);
      assert.equal(auth.deleteCalls, 1);
      assert.equal(
          (await consultarOperacao(db, descritor)).estado,
          OPERATION_STATE.ROLLED_BACK,
      );

      const retomada = await reservarOperacao(db, descritor, agoraFixo);
      assert.equal(retomada.estado, OPERATION_STATE.PENDING_AUTH);
      assert.equal((await consultarOperacao(db, descritor)).tentativas, 2);
    },
);

test("operationId de fallback usa chave semantica sem expo-la", () => {
  const descritor = criarDescritorOperacao({
    tipo: OPERATION_KIND.CREATE_CLINIC_USER,
    atorUid: "admin-a",
    clinicaId: "clinic-a",
    chaveSemantica: "pessoa@example.com",
    payload: {email: "pessoa@example.com"},
  });

  assert.match(descritor.operationId, /^op_[a-f0-9]{48}$/);
  assert.doesNotMatch(descritor.operationId, /pessoa|example/i);
});

test("erros do journal nao carregam dados pessoais", async () => {
  const db = new MockFirestore();
  const descritor = descritorUsuario();
  await reservarOperacao(db, descritor, agoraFixo);
  await marcarRollbackNecessario(
      db,
      descritor,
      "manual_reconciliation",
      agoraFixo,
  );

  await assert.rejects(
      reservarOperacao(db, descritor, agoraFixo),
      (error) => {
        assert.ok(error instanceof DurableOperationError);
        assert.equal(error.code, "operation-requires-reconciliation");
        assert.doesNotMatch(error.message, /pessoa|example|admin-uid/i);
        return true;
      },
  );
});

test("operacao committed nao pode apagar identidade Auth", async () => {
  const db = new MockFirestore();
  const auth = new MockAuth();
  const descritor = descritorUsuario();
  await reservarOperacao(db, descritor, agoraFixo);
  await garantirUsuarioAuth({
    auth,
    db,
    descritor,
    especificacao: {
      uid: descritor.recursos.authUid,
      email: "pessoa@example.com",
    },
    agora: agoraFixo,
  });
  const commit = await prepararCommitOperacao(db, descritor);
  const batch = db.batch();
  adicionarCommitAoBatch(batch, commit, agoraFixo);
  await batch.commit();

  await assert.rejects(
      reverterUsuarioAuth({auth, db, descritor, agora: agoraFixo}),
      {code: "operation-already-committed"},
  );
  assert.equal(auth.usuarios.has(descritor.recursos.authUid), true);
});
