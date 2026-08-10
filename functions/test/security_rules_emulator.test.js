/* eslint-disable require-jsdoc */
/* eslint-disable max-len */
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  after,
  before,
  beforeEach,
} = test;
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  arrayUnion,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
} = require("firebase/firestore");
const {
  getBytes,
  ref,
  uploadBytes,
} = require("firebase/storage");

const PROJECT_ID = process.env.GCLOUD_PROJECT || "demo-natus";
const BUCKET_URL = `gs://${PROJECT_ID}.appspot.com`;
const LOOPBACK = /^(127\.0\.0\.1|localhost):\d+$/;
const RUN_EMULATOR_TESTS =
  LOOPBACK.test(process.env.FIRESTORE_EMULATOR_HOST || "") &&
  LOOPBACK.test(process.env.FIREBASE_STORAGE_EMULATOR_HOST || "");

let testEnvironment;

function emulatorConfig(value, rulesPath) {
  const separator = value.lastIndexOf(":");
  return {
    host: value.slice(0, separator),
    port: Number(value.slice(separator + 1)),
    rules: fs.readFileSync(rulesPath, "utf8"),
  };
}

function tenantData(tenantId, extra = {}) {
  return {
    clinicaId: tenantId,
    adminDonoId: tenantId,
    ...extra,
  };
}

function userData(uid, tenantId, role, extra = {}) {
  return tenantData(tenantId, {
    uid,
    nome: `Usuario ${uid}`,
    status: "ativo",
    tipo: role,
    tipoUsuario: role,
    fotoUrl: "",
    fotoAtualizadaEm: "",
    tema: "",
    pushAtivo: false,
    pushTokens: [],
    pushUltimoToken: "",
    pushPlataforma: "",
    pushAtualizadoEm: "",
    pushPermissao: "",
    pushPermissaoAtualizadaEm: "",
    pushSuportadoNaPlataforma: false,
    ...extra,
  });
}

function context(uid, claims = {}) {
  return testEnvironment.authenticatedContext(uid, claims);
}

async function seedFirestore(adminContext) {
  const db = adminContext.firestore();
  const users = [
    ["admin-a", "clinic-a", "admin", {}],
    ["staff-a", "clinic-a", "profissional", {}],
    ["patient-a", "clinic-a", "paciente", {
      pacienteId: "patient-a-record",
      gestanteId: "patient-a-record",
      idGestante: "patient-a-record",
      uidPaciente: "patient-a",
      pacienteUid: "patient-a",
      uidGestante: "patient-a",
      gestanteUid: "patient-a",
    }],
    ["admin-b", "clinic-b", "admin", {}],
    ["patient-b", "clinic-b", "paciente", {
      pacienteId: "patient-b-record",
      gestanteId: "patient-b-record",
      idGestante: "patient-b-record",
      uidPaciente: "patient-b",
      pacienteUid: "patient-b",
      uidGestante: "patient-b",
      gestanteUid: "patient-b",
    }],
  ];

  await Promise.all([
    setDoc(doc(db, "clinicas/clinic-a"), tenantData("clinic-a", {
      id: "clinic-a",
      nome: "Clinica A",
      status: "ativa",
    })),
    setDoc(doc(db, "clinicas/clinic-b"), tenantData("clinic-b", {
      id: "clinic-b",
      nome: "Clinica B",
      status: "ativa",
    })),
    ...users.map(([uid, tenantId, role, extra]) =>
      setDoc(doc(db, `usuarios/${uid}`), userData(
          uid,
          tenantId,
          role,
          extra,
      )),
    ),
    ...users.map(([uid, tenantId, role, extra]) =>
      setDoc(doc(db, `clinicas/${tenantId}/usuarios/${uid}`), userData(
          uid,
          tenantId,
          role,
          extra,
      )),
    ),
    setDoc(
        doc(db, "clinicas/clinic-a/pacientes/patient-a-record"),
        tenantData("clinic-a", {
          pacienteId: "patient-a-record",
          gestanteId: "patient-a-record",
          uidPaciente: "patient-a",
          uidGestante: "patient-a",
        }),
    ),
    setDoc(
        doc(db, "clinicas/clinic-b/pacientes/patient-b-record"),
        tenantData("clinic-b", {
          pacienteId: "patient-b-record",
          gestanteId: "patient-b-record",
          uidPaciente: "patient-b",
          uidGestante: "patient-b",
        }),
    ),
    setDoc(
        doc(db, "clinicas/clinic-a/pacientes/patient-a-record/exames/exam-a"),
        tenantData("clinic-a", {
          pacienteId: "patient-a-record",
          uidPaciente: "patient-a",
        }),
    ),
    setDoc(
        doc(db, "clinicas/clinic-b/pacientes/patient-b-record/exames/exam-b"),
        tenantData("clinic-b", {
          pacienteId: "patient-b-record",
          uidPaciente: "patient-b",
        }),
    ),
    setDoc(
        doc(db, "clinicas/clinic-a/pacientes/patient-a-record/prontuario/private"),
        tenantData("clinic-a", {
          pacienteId: "patient-a-record",
          uidPaciente: "patient-a",
        }),
    ),
    setDoc(
        doc(db, "clinicas/clinic-a/notificacoes/own-notification"),
        tenantData("clinic-a", {
          destinatariosUids: ["patient-a"],
          lidasPor: [],
          atualizadoEm: "seed",
        }),
    ),
    setDoc(
        doc(db, "clinicas/clinic-a/notificacoes/other-notification"),
        tenantData("clinic-a", {
          destinatariosUids: ["staff-a"],
          lidasPor: [],
          atualizadoEm: "seed",
        }),
    ),
    setDoc(
        doc(db, "notificacoesCentral/legacy-staff-notification"),
        tenantData("clinic-a", {
          destinatariosUids: ["staff-a"],
          lidasPor: [],
          atualizadoEm: "seed",
        }),
    ),
    setDoc(doc(db, "_backendRateLimits/private"), {count: 1}),
    setDoc(doc(db, "operacoesSistema/private"), {state: "reserved"}),
  ]);
}

async function seedStorage(adminContext) {
  const storage = adminContext.storage(BUCKET_URL);
  const pdf = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37]);

  await Promise.all([
    uploadBytes(
        ref(
            storage,
            "clinicas/clinic-a/pacientes/patient-a-record/documentos/own.pdf",
        ),
        pdf,
        {
          contentType: "application/pdf",
          customMetadata: {
            clinicaId: "clinic-a",
            adminDonoId: "clinic-a",
            pacienteId: "patient-a-record",
            enviadoPorUid: "admin-a",
          },
        },
    ),
    uploadBytes(
        ref(
            storage,
            "clinicas/clinic-b/pacientes/patient-b-record/documentos/other.pdf",
        ),
        pdf,
        {
          contentType: "application/pdf",
          customMetadata: {
            clinicaId: "clinic-b",
            adminDonoId: "clinic-b",
            pacienteId: "patient-b-record",
            enviadoPorUid: "admin-b",
          },
        },
    ),
  ]);
}

before(async () => {
  if (!RUN_EMULATOR_TESTS) return;

  const repoRoot = path.resolve(__dirname, "../..");
  testEnvironment = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: emulatorConfig(
        process.env.FIRESTORE_EMULATOR_HOST,
        path.join(repoRoot, "firebase/security/firestore.rules"),
    ),
    storage: emulatorConfig(
        process.env.FIREBASE_STORAGE_EMULATOR_HOST,
        path.join(repoRoot, "firebase/security/storage.rules"),
    ),
  });
});

beforeEach(async () => {
  if (!testEnvironment) return;
  await Promise.all([
    testEnvironment.clearFirestore(),
    testEnvironment.clearStorage(),
  ]);
  await testEnvironment.withSecurityRulesDisabled(async (adminContext) => {
    await seedFirestore(adminContext);
    await seedStorage(adminContext);
  });
});

after(async () => {
  if (testEnvironment) await testEnvironment.cleanup();
});

test("nega leitura e escrita anonimas em dados clinicos", {
  skip: !RUN_EMULATOR_TESTS,
}, async () => {
  const db = testEnvironment.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(db, "usuarios/admin-a")));
  await assertFails(getDoc(doc(
      db,
      "clinicas/clinic-a/pacientes/patient-a-record",
  )));
  await assertFails(setDoc(doc(db, "usuarios/intruder"), {
    uid: "intruder",
    tipo: "superAdmin",
    status: "ativo",
  }));
});

test("bloqueia leitura cruzada e prontuario para paciente", {
  skip: !RUN_EMULATOR_TESTS,
}, async () => {
  const patientDb = context("patient-a").firestore();
  const adminDb = context("admin-a").firestore();

  await assertSucceeds(getDoc(doc(
      patientDb,
      "clinicas/clinic-a/pacientes/patient-a-record/exames/exam-a",
  )));
  await assertFails(getDoc(doc(
      patientDb,
      "clinicas/clinic-a/pacientes/patient-a-record/prontuario/private",
  )));
  await assertFails(getDoc(doc(
      patientDb,
      "clinicas/clinic-b/pacientes/patient-b-record/exames/exam-b",
  )));
  await assertFails(getDoc(doc(
      adminDb,
      "clinicas/clinic-b/pacientes/patient-b-record/exames/exam-b",
  )));
});

test("impede autoescalada e valores abusivos no perfil", {
  skip: !RUN_EMULATOR_TESTS,
}, async () => {
  const patientDb = context("patient-a").firestore();
  const ownUser = doc(patientDb, "usuarios/patient-a");

  await assertSucceeds(updateDoc(ownUser, {tema: "escuro"}));
  await assertFails(updateDoc(ownUser, {
    tipo: "admin",
    tipoUsuario: "admin",
  }));
  await assertFails(updateDoc(ownUser, {
    clinicaId: "clinic-b",
    adminDonoId: "clinic-b",
  }));
  await assertFails(updateDoc(ownUser, {
    pushTokens: ["1", "2", "3", "4", "5", "6"],
  }));
  await assertFails(updateDoc(ownUser, {
    fotoUrl: "https://firebasestorage.googleapis.com/v0/b/attacker/o/pixel.png",
  }));
  await assertSucceeds(updateDoc(ownUser, {
    fotoUrl: "https://firebasestorage.googleapis.com/v0/b/" +
      "natus-gestantes.firebasestorage.app/o/clinicas%2Fclinic-a%2F" +
      "usuarios%2Fpatient-a%2Fperfil%2Favatar.png?alt=media&token=test",
  }));
});

test("admin nao injeta perfil arbitrario no diretorio canonico", {
  skip: !RUN_EMULATOR_TESTS,
}, async () => {
  const adminDb = context("admin-a").firestore();

  await assertFails(updateDoc(
      doc(adminDb, "clinicas/clinic-a/usuarios/staff-a"),
      {
        tipo: "superAdmin",
        tipoUsuario: "superAdmin",
        status: "root",
        permissaoInjetada: true,
      },
  ));
});

test("recibo de notificacao altera apenas o proprio usuario", {
  skip: !RUN_EMULATOR_TESTS,
}, async () => {
  const patientDb = context("patient-a").firestore();

  await assertSucceeds(updateDoc(
      doc(patientDb, "clinicas/clinic-a/notificacoes/own-notification"),
      {
        lidasPor: arrayUnion("patient-a"),
        atualizadoEm: "patient-a-read",
      },
  ));
  await assertFails(updateDoc(
      doc(patientDb, "clinicas/clinic-a/notificacoes/other-notification"),
      {
        lidasPor: arrayUnion("patient-a"),
        atualizadoEm: "unauthorized-read",
      },
  ));
  await assertFails(updateDoc(
      doc(patientDb, "clinicas/clinic-a/notificacoes/own-notification"),
      {
        lidasPor: ["patient-a", "patient-b"],
        atualizadoEm: "forged-read",
      },
  ));
});

test("notificacao legada aceita recibo apenas da equipe autorizada", {
  skip: !RUN_EMULATOR_TESTS,
}, async () => {
  const patientDb = context("patient-a").firestore();
  const staffDb = context("staff-a").firestore();
  const notificationPath = "notificacoesCentral/legacy-staff-notification";

  await assertFails(updateDoc(doc(patientDb, notificationPath), {
    lidasPor: arrayUnion("patient-a"),
    atualizadoEm: "forged-patient-read",
  }));
  await assertSucceeds(updateDoc(doc(staffDb, notificationPath), {
    lidasPor: arrayUnion("staff-a"),
    atualizadoEm: "staff-read",
  }));
});

test("colecoes tecnicas permanecem exclusivas do backend", {
  skip: !RUN_EMULATOR_TESTS,
}, async () => {
  const adminDb = context("admin-a").firestore();

  await assertFails(getDoc(doc(adminDb, "_backendRateLimits/private")));
  await assertFails(setDoc(doc(adminDb, "_backendRateLimits/forged"), {
    count: 0,
  }));
  await assertFails(getDoc(doc(adminDb, "operacoesSistema/private")));
});

test("admin grava paciente e financeiro no mesmo lote sem cruzar tenant", {
  skip: !RUN_EMULATOR_TESTS,
}, async () => {
  const adminDb = context("admin-a").firestore();
  const patientId = "new-patient-a";
  const batch = writeBatch(adminDb);

  batch.set(doc(adminDb, `gestantes/${patientId}`), tenantData("clinic-a", {
    pacienteId: patientId,
    gestanteId: patientId,
    idGestante: patientId,
    nomeGestante: "Paciente nova",
    criadoPorUid: "admin-a",
  }));
  batch.set(doc(adminDb, "parcelas/new-patient-a-1"), tenantData("clinic-a", {
    pacienteId: patientId,
    gestanteId: patientId,
    idGestante: patientId,
    tipo: "parcela",
    valor: "R$ 100,00",
    status: "Pendente",
    criadoPorUid: "admin-a",
  }));
  await assertSucceeds(batch.commit());

  const crossTenantBatch = writeBatch(adminDb);
  crossTenantBatch.set(
      doc(adminDb, "gestantes/forged-patient-b"),
      tenantData("clinic-b", {
        pacienteId: "forged-patient-b",
        gestanteId: "forged-patient-b",
        idGestante: "forged-patient-b",
        nomeGestante: "Paciente forjada",
        criadoPorUid: "admin-a",
      }),
  );
  await assertFails(crossTenantBatch.commit());
});

test("Storage exige autenticacao, tenant e metadados canonicos", {
  skip: !RUN_EMULATOR_TESTS,
}, async () => {
  const ownPath =
    "clinicas/clinic-a/pacientes/patient-a-record/documentos/own.pdf";
  const otherPath =
    "clinicas/clinic-b/pacientes/patient-b-record/documentos/other.pdf";
  const anonymousStorage = testEnvironment
      .unauthenticatedContext()
      .storage(BUCKET_URL);
  const patientStorage = context("patient-a").storage(BUCKET_URL);

  await assertFails(getBytes(ref(anonymousStorage, ownPath), 32));
  await assertSucceeds(getBytes(ref(patientStorage, ownPath), 32));
  await assertFails(getBytes(ref(patientStorage, otherPath), 32));

  const pdf = new Uint8Array([0x25, 0x50, 0x44, 0x46]);
  await assertSucceeds(uploadBytes(
      ref(
          patientStorage,
          "clinicas/clinic-a/pacientes/patient-a-record/documentos/valid.pdf",
      ),
      pdf,
      {
        contentType: "application/pdf",
        customMetadata: {
          clinicaId: "clinic-a",
          adminDonoId: "clinic-a",
          pacienteId: "patient-a-record",
          enviadoPorUid: "patient-a",
        },
      },
  ));
  await assertFails(uploadBytes(
      ref(
          patientStorage,
          "clinicas/clinic-a/pacientes/patient-a-record/documentos/bad.pdf",
      ),
      pdf,
      {
        contentType: "application/pdf",
        customMetadata: {
          clinicaId: "clinic-b",
          adminDonoId: "clinic-b",
          pacienteId: "patient-a-record",
          enviadoPorUid: "patient-a",
        },
      },
  ));
  await assertFails(uploadBytes(
      ref(
          patientStorage,
          "clinicas/clinic-a/pacientes/patient-a-record/documentos/bad.html",
      ),
      new TextEncoder().encode("<script>alert(1)</script>"),
      {
        contentType: "text/html",
        customMetadata: {
          clinicaId: "clinic-a",
          adminDonoId: "clinic-a",
          pacienteId: "patient-a-record",
          enviadoPorUid: "patient-a",
        },
      },
  ));
});
