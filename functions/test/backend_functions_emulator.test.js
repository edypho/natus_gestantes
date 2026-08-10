/* eslint-disable require-jsdoc */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const LOOPBACK_EMULATOR = /^(127\.0\.0\.1|localhost):\d+$/;
const RUN_EMULATOR_TESTS =
  process.env.RUN_BACKEND_EMULATOR_TESTS === "1" ||
  (
    LOOPBACK_EMULATOR.test(process.env.FIRESTORE_EMULATOR_HOST || "") &&
    LOOPBACK_EMULATOR.test(
        process.env.FIREBASE_AUTH_EMULATOR_HOST || "",
    )
  );

function tenantData(clinicaId, extra = {}) {
  return {
    clinicaId,
    adminDonoId: clinicaId,
    ...extra,
  };
}

function callableRequest(uid, token, data) {
  return {
    auth: {
      uid,
      token: {
        uid,
        auth_time: Math.ceil(Date.now() / 1000),
        ...token,
      },
    },
    data,
  };
}

async function assertHttpsError(action, expectedCode) {
  await assert.rejects(action, (error) => {
    assert.equal(error && error.code, expectedCode);
    return true;
  });
}

async function withMutationImmediatelyBeforeBatchCommit(
    db,
    mutation,
    action,
) {
  const originalBatch = db.batch;
  let mutationPending = true;

  db.batch = function() {
    const batch = originalBatch.call(db);
    const originalCommit = batch.commit.bind(batch);

    batch.commit = async () => {
      if (mutationPending) {
        mutationPending = false;
        await mutation();
      }
      return originalCommit();
    };
    return batch;
  };

  try {
    return await action();
  } finally {
    db.batch = originalBatch;
  }
}

async function signInWithPassword(fetchImpl, email, password) {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const response = await fetchImpl(
      `http://${host}/identitytoolkit.googleapis.com/` +
        "v1/accounts:signInWithPassword?key=emulator-key",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({email, password, returnSecureToken: true}),
      },
  );
  assert.equal(response.ok, true);
  const data = await response.json();
  assert.ok(data.idToken);
  return data.idToken;
}

async function commitClientDocument(fetchImpl, idToken, documentPath) {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  const projectId = process.env.GCLOUD_PROJECT || "demo-natus";
  const url = `http://${host}/v1/projects/${projectId}/databases/` +
    "(default)/documents:commit";
  return fetchImpl(url, {
    method: "POST",
    headers: {
      "authorization": `Bearer ${idToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      writes: [{
        update: {
          name: `projects/${projectId}/databases/(default)/documents/` +
            documentPath,
          fields: {
            clinicaId: {stringValue: "clinic-a"},
            adminDonoId: {stringValue: "clinic-a"},
            status: {stringValue: "teste"},
          },
        },
      }],
    }),
  });
}

test(
    "Functions pendentes preservam tenant e cópias canônicas no Emulator",
    {skip: !RUN_EMULATOR_TESTS, timeout: 30000},
    async () => {
      assert.match(
          process.env.FIRESTORE_EMULATOR_HOST || "",
          /^(127\.0\.0\.1|localhost):\d+$/,
      );
      assert.match(
          process.env.FIREBASE_AUTH_EMULATOR_HOST || "",
          /^(127\.0\.0\.1|localhost):\d+$/,
      );

      process.env.GOOGLE_MAPS_GEOCODING_API_KEY = "emulator-only-key";
      const originalFetch = global.fetch;
      global.fetch = async () => ({
        ok: true,
        async json() {
          return {
            status: "OK",
            results: [{
              geometry: {location: {lat: -25.4284, lng: -49.2733}},
            }],
          };
        },
      });

      const {deleteApp, getApps} = require("firebase-admin/app");
      const {getAuth} = require("firebase-admin/auth");
      const {getFirestore} = require("firebase-admin/firestore");
      const backend = require("../index");
      const db = getFirestore();
      const auth = getAuth();

      try {
        await Promise.all([
          db.collection("clinicas").doc("clinic-a").set(tenantData(
              "clinic-a",
              {id: "clinic-a", nome: "Clínica A", status: "ativa"},
          )),
          db.collection("clinicas").doc("clinic-b").set(tenantData(
              "clinic-b",
              {id: "clinic-b", nome: "Clínica B", status: "ativa"},
          )),
          auth.createUser({
            uid: "admin-a",
            email: "admin-a@example.test",
            displayName: "Admin A",
          }),
          auth.createUser({
            uid: "admin-b",
            email: "admin-b@example.test",
            displayName: "Admin B",
          }),
          auth.createUser({
            uid: "super-root",
            email: "super-root@example.test",
            displayName: "Super Root",
          }),
          auth.createUser({
            uid: "target-a",
            email: "target-a@example.test",
            displayName: "Target A",
          }),
          auth.createUser({
            uid: "target-b",
            email: "target-b@example.test",
            displayName: "Target B",
          }),
          auth.createUser({
            uid: "race-patient-auth",
            email: "race-patient@example.test",
            displayName: "Paciente Concorrente",
          }),
        ]);
        await auth.setCustomUserClaims("super-root", {superAdmin: true});

        const adminA = tenantData("clinic-a", {
          uid: "admin-a",
          nome: "Admin A",
          email: "admin-a@example.test",
          tipo: "admin",
          tipoUsuario: "admin",
          status: "ativo",
        });
        const adminB = tenantData("clinic-b", {
          uid: "admin-b",
          nome: "Admin B",
          email: "admin-b@example.test",
          tipo: "admin",
          tipoUsuario: "admin",
          status: "ativo",
        });
        const superAdmin = {
          uid: "super-root",
          nome: "Super Root",
          email: "super-root@example.test",
          tipo: "superAdmin",
          tipoUsuario: "superAdmin",
          status: "ativo",
        };
        const targetA = tenantData("clinic-a", {
          uid: "target-a",
          nome: "Target A",
          email: "target-a@example.test",
          tipo: "enfermeira",
          tipoUsuario: "enfermeira",
          status: "ativo",
          pacienteId: "",
          idGestante: "",
          uidGestante: "",
          idVinculo: "",
        });
        const targetB = tenantData("clinic-b", {
          uid: "target-b",
          nome: "Target B",
          email: "target-b@example.test",
          tipo: "enfermeira",
          tipoUsuario: "enfermeira",
          status: "ativo",
          pacienteId: "",
          idGestante: "",
          uidGestante: "",
          idVinculo: "",
        });

        await Promise.all([
          db.collection("usuarios").doc("admin-a").set(adminA),
          db.collection("usuarios").doc("admin-b").set(adminB),
          db.collection("usuarios").doc("super-root").set(superAdmin),
          db.collection("usuarios").doc("target-a").set(targetA),
          db.collection("usuariosSaaS").doc("target-a").set(targetA),
          db.collection("usuarios").doc("target-b").set(targetB),
          db.doc("clinicas/clinic-a/usuarios/admin-a").set(adminA),
          db.doc("clinicas/clinic-b/usuarios/admin-b").set(adminB),
          db.doc("clinicas/clinic-a/usuarios/target-a").set(targetA),
          db.doc("clinicas/clinic-b/usuarios/target-b").set(targetB),
          db.doc("gestantes/patient-a").set(tenantData("clinic-a", {
            pacienteId: "patient-a",
            idGestante: "patient-a",
            nomeGestante: "Paciente A",
            emailGestante: "patient-a@example.test",
          })),
          db.doc("gestantes/race-patient").set(tenantData("clinic-a", {
            pacienteId: "race-patient",
            idGestante: "race-patient",
            nomeGestante: "Paciente Concorrente",
            emailGestante: "race-patient@example.test",
          })),
          db.doc("enfermeiras/race-professional").set(tenantData(
              "clinic-a",
              {nome: "Profissional Concorrente"},
          )),
          db.doc("agenda/agenda-patient-a").set(tenantData("clinic-a", {
            pacienteId: "patient-a",
            gestanteId: "patient-a",
          })),
          db.doc("documentos/document-patient-a").set(tenantData(
              "clinic-a",
              {pacienteId: "patient-a", idGestante: "patient-a"},
          )),
          db.doc("exames/exam-patient-a").set(tenantData("clinic-a", {
            pacienteId: "patient-a",
            idGestante: "patient-a",
          })),
          db.doc("contratos/contract-patient-a").set(tenantData(
              "clinic-a",
              {
                pacienteId: "patient-a",
                idGestante: "patient-a",
                payload: {pacienteId: "patient-a"},
              },
          )),
          db.doc("parcelas/installment-patient-a").set(tenantData(
              "clinic-a",
              {pacienteId: "patient-a", gestanteId: "patient-a"},
          )),
        ]);

        await auth.updateUser("admin-a", {password: "SenhaAdmin123!"});
        const adminIdToken = await signInWithPassword(
            originalFetch,
            "admin-a@example.test",
            "SenhaAdmin123!",
        );
        const controleCliente = await commitClientDocument(
            originalFetch,
            adminIdToken,
            "clinicas/clinic-a/operacao/controle-cliente",
        );
        assert.equal(controleCliente.ok, true);
        await db.doc(
            "clinicas/clinic-a/operacao/controle-cliente",
        ).delete();

        const journalIdTeste = `op_${"a".repeat(48)}`;
        for (const path of [
          `clinicas/clinic-a/operacoesSistema/${journalIdTeste}`,
          `clinicas/clinic-a/operacoesSistema/${journalIdTeste}/filhos/teste`,
          `operacoesSistema/${journalIdTeste}`,
        ]) {
          const tentativa = await commitClientDocument(
              originalFetch,
              adminIdToken,
              path,
          );
          assert.equal(tentativa.status, 403, path);
        }

        await assertHttpsError(
            () => backend.alterarTipoUsuarioClinica.run(callableRequest(
                "admin-a",
                {},
                {uidUsuario: "target-b", tipoUsuario: "obstetra"},
            )),
            "permission-denied",
        );

        const alteracao = await backend.alterarTipoUsuarioClinica.run(
            callableRequest(
                "admin-a",
                {},
                {uidUsuario: "target-a", tipoUsuario: "obstetra"},
            ),
        );
        assert.equal(alteracao.sucesso, true);
        assert.equal(alteracao.alterado, true);
        for (const path of [
          "usuarios/target-a",
          "usuariosSaaS/target-a",
          "clinicas/clinic-a/usuarios/target-a",
        ]) {
          const data = (await db.doc(path).get()).data();
          assert.equal(data.tipo, "obstetra", path);
          assert.equal(data.tipoUsuario, "obstetra", path);
          assert.equal(data.clinicaId, "clinic-a", path);
          assert.equal(data.adminDonoId, "clinic-a", path);
        }

        const racePatientRef = db.doc("gestantes/race-patient");
        await assertHttpsError(
            () => withMutationImmediatelyBeforeBatchCommit(
                db,
                () => racePatientRef.update({
                  uidGestante: "external-race-user",
                  uidPaciente: "external-race-user",
                }),
                () => backend.vincularLoginPaciente.run(callableRequest(
                    "admin-a",
                    {},
                    {
                      uidUsuario: "race-patient-auth",
                      pacienteId: "race-patient",
                    },
                )),
            ),
            "failed-precondition",
        );
        const [racePatientAfter, raceUser, raceCanonicalUser, raceUidLock] =
          await Promise.all([
            racePatientRef.get(),
            db.doc("usuarios/race-patient-auth").get(),
            db.doc(
                "clinicas/clinic-a/usuarios/race-patient-auth",
            ).get(),
            db.doc("vinculosAuthPaciente/race-patient-auth").get(),
          ]);
        assert.equal(
            racePatientAfter.data().uidGestante,
            "external-race-user",
        );
        assert.equal(raceUser.exists, false);
        assert.equal(raceCanonicalUser.exists, false);
        assert.equal(raceUidLock.exists, false);

        const raceProfessionalRef = db.doc(
            "enfermeiras/race-professional",
        );
        const raceProfessionalEmail = "race-professional@example.test";
        await assertHttpsError(
            () => withMutationImmediatelyBeforeBatchCommit(
                db,
                () => raceProfessionalRef.update({
                  uidEnfermeira: "external-race-professional",
                  uidProfissional: "external-race-professional",
                }),
                () => backend.criarUsuarioClinica.run(callableRequest(
                    "admin-a",
                    {},
                    {
                      nome: "Profissional Concorrente",
                      email: raceProfessionalEmail,
                      tipo: "enfermeira",
                      idVinculo: "race-professional",
                      operacaoId:
                        "018f1422-d5d9-7aa0-9000-000000000001",
                    },
                )),
            ),
            "failed-precondition",
        );
        const raceProfessionalAfter = await raceProfessionalRef.get();
        assert.equal(
            raceProfessionalAfter.data().uidEnfermeira,
            "external-race-professional",
        );
        await assert.rejects(
            () => auth.getUserByEmail(raceProfessionalEmail),
            (error) => error && error.code === "auth/user-not-found",
        );
        const raceProfiles = await db.collection("usuarios")
            .where("email", "==", raceProfessionalEmail)
            .get();
        assert.equal(raceProfiles.empty, true);

        const payloadNovoUsuario = {
          nome: "Segundo Admin",
          email: "segundo-admin@example.test",
          tipo: "admin",
          idVinculo: "",
          operacaoId: "018f1422-d5d9-7aa0-9000-111111111111",
        };
        await assertHttpsError(
            () => backend.criarUsuarioClinica.run(callableRequest(
                "admin-a",
                {},
                {...payloadNovoUsuario, operacaoId: ""},
            )),
            "invalid-argument",
        );
        const [novoUsuario, novoUsuarioRepetido] = await Promise.all([
          backend.criarUsuarioClinica.run(
              callableRequest("admin-a", {}, payloadNovoUsuario),
          ),
          backend.criarUsuarioClinica.run(
              callableRequest("admin-a", {}, payloadNovoUsuario),
          ),
        ]);
        assert.equal(novoUsuario.sucesso, true);
        assert.equal(novoUsuarioRepetido.sucesso, true);
        assert.equal(
            novoUsuarioRepetido.uidUsuario,
            novoUsuario.uidUsuario,
        );
        const uidNovoUsuario = novoUsuario.uidUsuario;
        const [
          usuarioRaiz,
          usuarioCanonico,
          usuariosMesmoEmail,
          logsMesmoUsuario,
        ] = await Promise.all([
          db.doc(`usuarios/${uidNovoUsuario}`).get(),
          db.doc(`clinicas/clinic-a/usuarios/${uidNovoUsuario}`).get(),
          db.collection("usuarios")
              .where("email", "==", payloadNovoUsuario.email)
              .get(),
          db.collection("logsAdministrativos")
              .where("uidCriado", "==", uidNovoUsuario)
              .get(),
        ]);
        assert.equal(usuarioRaiz.exists, true);
        assert.equal(usuarioCanonico.exists, true);
        assert.equal(usuarioCanonico.data().tipoUsuario, "admin");
        assert.equal(usuariosMesmoEmail.size, 1);
        assert.equal(logsMesmoUsuario.size, 1);
        const usuariosAuthMesmoEmail = (await auth.listUsers()).users
            .filter((usuario) => usuario.email === payloadNovoUsuario.email);
        assert.equal(usuariosAuthMesmoEmail.length, 1);

        const loginPaciente = await backend.criarUsuarioClinica.run(
            callableRequest("admin-a", {}, {
              nome: "Paciente A",
              email: "patient-a@example.test",
              tipo: "gestante",
              idVinculo: "patient-a",
              operacaoId: "018f1422-d5d9-7aa0-9000-222222222222",
            }),
        );
        assert.equal(loginPaciente.sucesso, true);
        const uidPaciente = loginPaciente.uidUsuario;

        await auth.updateUser(uidPaciente, {password: "SenhaForte123!"});
        const pacienteIdToken = await signInWithPassword(
            originalFetch,
            "patient-a@example.test",
            "SenhaForte123!",
        );

        const redefinicao = await backend
            .solicitarRedefinicaoSenhaPaciente.run({
              auth: {uid: uidPaciente, token: {uid: uidPaciente}},
              data: {pacienteId: "patient-a"},
              rawRequest: {
                headers: {authorization: `Bearer ${pacienteIdToken}`},
              },
            });
        assert.equal(redefinicao.sucesso, true);
        assert.equal(redefinicao.pacienteId, "patient-a");
        assert.equal(redefinicao.emailPaciente, "patient-a@example.test");
        const pacienteComRedefinicao = await db.doc(
            "gestantes/patient-a",
        ).get();
        assert.equal(
            pacienteComRedefinicao.data().redefinicaoSenhaPendente,
            true,
        );

        for (const path of [
          `usuarios/${uidPaciente}`,
          `clinicas/clinic-a/usuarios/${uidPaciente}`,
        ]) {
          const data = (await db.doc(path).get()).data();
          assert.equal(data.pacienteId, "patient-a", path);
          assert.equal(data.uidGestante, uidPaciente, path);
          assert.equal(data.tipoUsuario, "gestante", path);
        }

        for (const path of [
          "gestantes/patient-a",
          "clinicas/clinic-a/pacientes/patient-a",
        ]) {
          const data = (await db.doc(path).get()).data();
          assert.equal(data.pacienteId, "patient-a", path);
          assert.equal(data.uidGestante, uidPaciente, path);
          assert.equal(data.clinicaId, "clinic-a", path);
          assert.equal(data.adminDonoId, "clinic-a", path);
        }

        for (const [legacyPath, canonicalPath] of [
          [
            "agenda/agenda-patient-a",
            "clinicas/clinic-a/agenda/agenda-patient-a",
          ],
          [
            "documentos/document-patient-a",
            "clinicas/clinic-a/pacientes/patient-a/documentos/" +
              "document-patient-a",
          ],
          [
            "exames/exam-patient-a",
            "clinicas/clinic-a/pacientes/patient-a/exames/exam-patient-a",
          ],
          [
            "contratos/contract-patient-a",
            "clinicas/clinic-a/pacientes/patient-a/contratos/" +
              "contract-patient-a",
          ],
        ]) {
          const [legacy, canonical] = await Promise.all([
            db.doc(legacyPath).get(),
            db.doc(canonicalPath).get(),
          ]);
          assert.equal(legacy.exists, true, legacyPath);
          assert.equal(canonical.exists, true, canonicalPath);
          assert.equal(legacy.data().uidGestante, uidPaciente, legacyPath);
          assert.equal(
              canonical.data().uidGestante,
              uidPaciente,
              canonicalPath,
          );
        }

        const contratoCanonico = await db.doc(
            "clinicas/clinic-a/pacientes/patient-a/contratos/" +
              "contract-patient-a",
        ).get();
        assert.equal(
            contratoCanonico.data().payload.uidGestante,
            uidPaciente,
        );
        const parcelaLegada = await db.doc(
            "parcelas/installment-patient-a",
        ).get();
        assert.equal(parcelaLegada.data().uidGestante, uidPaciente);

        const payloadNovaClinica = {
          nomeClinica: "Clínica Criada no Emulator",
          nomeAdmin: "Admin da Nova Clínica",
          emailAdmin: "admin-nova-clinica@example.test",
          plano: "Profissional",
          valorAssinatura: 499.9,
          operacaoId: "018f1422-d5d9-7aa0-9000-333333333333",
        };
        await assertHttpsError(
            () => backend.criarClinicaComAdminSaaS.run(callableRequest(
                "super-root",
                {superAdmin: true},
                {...payloadNovaClinica, operacaoId: ""},
            )),
            "invalid-argument",
        );
        const [novaClinica, novaClinicaRepetida] = await Promise.all([
          backend.criarClinicaComAdminSaaS.run(callableRequest(
              "super-root",
              {superAdmin: true},
              payloadNovaClinica,
          )),
          backend.criarClinicaComAdminSaaS.run(callableRequest(
              "super-root",
              {superAdmin: true},
              payloadNovaClinica,
          )),
        ]);
        assert.equal(novaClinica.sucesso, true);
        assert.equal(novaClinicaRepetida.sucesso, true);
        assert.equal(novaClinicaRepetida.clinicaId, novaClinica.clinicaId);
        assert.equal(novaClinicaRepetida.adminUid, novaClinica.adminUid);
        assert.equal(
            novaClinicaRepetida.assinaturaId,
            novaClinica.assinaturaId,
        );
        const clinicaCriada = await db
            .doc(`clinicas/${novaClinica.clinicaId}`)
            .get();
        const adminCanonico = await db.doc(
            `clinicas/${novaClinica.clinicaId}/usuarios/` +
            novaClinica.adminUid,
        ).get();
        assert.equal(clinicaCriada.exists, true);
        assert.equal(adminCanonico.exists, true);
        assert.equal(adminCanonico.data().tipoUsuario, "admin");
        const [
          clinicasMesmoEmail,
          assinaturasMesmoAdmin,
          perfisMesmoEmail,
          logsMesmoAdmin,
        ] = await Promise.all([
          db.collection("clinicas")
              .where(
                  "emailAdmin",
                  "==",
                  "admin-nova-clinica@example.test",
              )
              .get(),
          db.collection("assinaturasSaaS")
              .where("adminUid", "==", novaClinica.adminUid)
              .get(),
          db.collection("usuarios")
              .where("email", "==", payloadNovaClinica.emailAdmin)
              .get(),
          db.collection("logsSuperAdmin")
              .where("dados.adminUid", "==", novaClinica.adminUid)
              .get(),
        ]);
        assert.equal(clinicasMesmoEmail.size, 1);
        assert.equal(assinaturasMesmoAdmin.size, 1);
        assert.equal(perfisMesmoEmail.size, 1);
        assert.equal(logsMesmoAdmin.size, 1);
        const adminsAuthMesmoEmail = (await auth.listUsers()).users
            .filter((usuario) =>
              usuario.email === "admin-nova-clinica@example.test");
        assert.equal(adminsAuthMesmoEmail.length, 1);

        const coordenada = await backend.buscarCoordenadaEndereco.run(
            callableRequest("admin-a", {}, {
              endereco: "Praça Tiradentes, Curitiba, Paraná",
            }),
        );
        assert.deepEqual(coordenada, {
          latitude: -25.4284,
          longitude: -49.2733,
        });
        await assertHttpsError(
            () => backend.buscarCoordenadaEndereco.run({
              auth: null,
              data: {endereco: "Praça Tiradentes, Curitiba, Paraná"},
            }),
            "unauthenticated",
        );
      } finally {
        global.fetch = originalFetch;
        await Promise.all(getApps().map((app) => deleteApp(app)));
      }
    },
);
