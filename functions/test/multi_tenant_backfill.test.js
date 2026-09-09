/* eslint-disable require-jsdoc */
"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {GeoPoint, Timestamp} = require("firebase-admin/firestore");

const {ROOT_COLLECTIONS} = require("../audit/multi_tenant_manifest");
const {
  decodeFirestoreValue,
  encodeFirestoreValue,
} = require("../migration/firestore_value_codec");
const {
  planMultiTenantBackfill,
} = require("../migration/multi_tenant_backfill");
const {
  validateOptions,
  validateProductionBackup,
} = require("../scripts/migrate_multi_tenant");

function document(collection, id, data) {
  return {id, path: `${collection}/${id}`, data};
}

function emptyCollections() {
  return Object.fromEntries(ROOT_COLLECTIONS.map((definition) => [
    definition.name,
    [],
  ]));
}

function fixture() {
  const collections = emptyCollections();
  collections.clinicasSaaS = [document("clinicasSaaS", "clinic-a", {
    adminDonoId: "clinic-a",
    adminUid: "admin-a",
    nome: "Clínica A",
    status: "ativa",
  })];
  collections.usuarios = [
    document("usuarios", "admin-a", {
      email: "admin@example.test",
      nome: "Admin",
      tipo: "admin",
    }),
    document("usuarios", "patient-user", {
      email: "patient@example.test",
      nome: "Paciente",
      tipo: "gestante",
    }),
  ];
  collections.gestantes = [document("gestantes", "patient-a", {
    emailGestante: "patient@example.test",
    nomeGestante: "Paciente Exemplo",
    uidGestante: "patient-user",
  })];
  collections.parcelas = [
    document("parcelas", "paid-a", {
      gestante: "Paciente Exemplo",
      status: "Pago",
    }),
    document("parcelas", "orphan-a", {
      gestante: "Registro sem paciente",
      status: "Pendente",
    }),
  ];
  return {
    authUsers: [
      {uid: "admin-a", disabled: false, customClaims: {}},
      {uid: "patient-user", disabled: false, customClaims: {}},
      {uid: "orphan-auth", disabled: false, customClaims: {}},
    ],
    collections,
  };
}

test("backfill é aditivo, determinístico e põe órfãos em quarentena", () => {
  const input = fixture();
  const options = {
    generatedAt: "2026-08-10T12:00:00.000Z",
    targetTenantId: "clinic-a",
  };
  const first = planMultiTenantBackfill(input, options);
  const second = planMultiTenantBackfill(input, options);

  assert.deepEqual(first, second);
  assert.equal(first.summary.blockers, 0);
  assert.ok(first.firestoreSets.every((operation) => operation.merge));
  assert.equal(
      first.firestoreSets.some((operation) => operation.delete),
      false,
  );
  assert.ok(first.firestoreSets.some((operation) =>
    operation.path ===
      "clinicas/clinic-a/pacientes/patient-a/financeiro/parcela_paid-a"));
  assert.ok(first.firestoreSets.some((operation) =>
    operation.path ===
      "clinicas/clinic-a/operacao/quarentena_parcelas_orphan-a"));
  assert.ok(first.firestoreSets.some((operation) =>
    operation.path === "vinculosAuthPaciente/patient-user"));
  assert.ok(first.firestoreSets.some((operation) =>
    operation.path === "vinculosPacienteAuth/patient-a"));
  assert.equal(
      first.authUpdates.some((update) => update.uid === "orphan-auth"),
      false,
  );
  assert.ok(first.warnings.some((warning) =>
    warning.code === "UNSCOPED_AUTH_ACCOUNT_PRESERVED"));
});

test("backfill bloqueia tenant divergente em vez de reivindicar o dado", () => {
  const input = fixture();
  input.collections.gestantes[0].data = {
    ...input.collections.gestantes[0].data,
    adminDonoId: "clinic-b",
    clinicaId: "clinic-b",
  };
  const plan = planMultiTenantBackfill(input, {targetTenantId: "clinic-a"});
  assert.ok(plan.blockers.some((blocker) =>
    blocker.code === "PATIENT_USER_TENANT_CONFLICT"));
});

test("CLI nunca aplica em produção sem confirmação e backup", () => {
  assert.throws(() => validateOptions({
    apply: true,
    allowProductionRead: true,
    cloud: true,
    confirmProject: "natus-gestantes",
    projectId: "natus-gestantes",
    targetTenantId: "clinic-a",
  }), /allow-production-write/);
});

test("CLI valida checksums antes de escrever em produção", async () => {
  const prefix = path.join(os.tmpdir(), "natus-backup-test-");
  const directory = fs.mkdtempSync(prefix);
  try {
    const manifestPath = path.join(directory, "backup-manifest.json");
    const firestorePath = path.join(directory, "firestore.jsonl");
    const manifest = {
      complete: true,
      projectId: "natus-gestantes",
      completedAt: new Date().toISOString(),
      components: {firestore: true, auth: true, storage: true},
    };
    fs.writeFileSync(manifestPath, `${JSON.stringify(manifest)}\n`);
    fs.writeFileSync(firestorePath, "{}\n");
    const lines = [manifestPath, firestorePath].map((file) => {
      const hash = crypto.createHash("sha256").update(fs.readFileSync(file))
          .digest("hex");
      return `${hash}  ${path.basename(file)}`;
    });
    fs.writeFileSync(
        path.join(directory, "checksums.sha256"),
        `${lines.join("\n")}\n`,
    );
    const options = {
      apply: true,
      backupManifest: manifestPath,
      projectId: "natus-gestantes",
    };

    await validateProductionBackup(options);
    fs.appendFileSync(firestorePath, "adulterado\n");
    await assert.rejects(
        validateProductionBackup(options),
        /Checksum divergente/,
    );
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
});

test("codec preserva tipos especiais do Firestore", () => {
  const reference = {
    firestore: {},
    get() {},
    path: "colecao/documento",
  };
  const original = {
    bytes: Buffer.from("natus"),
    date: new Date("2026-08-10T12:00:00.000Z"),
    geopoint: new GeoPoint(-23.5, -46.6),
    infinity: Number.POSITIVE_INFINITY,
    nan: Number.NaN,
    reference,
    timestamp: new Timestamp(123, 456),
  };
  const fakeFirestore = {doc: (value) => ({path: value})};
  const decoded = decodeFirestoreValue(
      encodeFirestoreValue(original),
      fakeFirestore,
  );

  assert.deepEqual(decoded.bytes, original.bytes);
  assert.equal(decoded.date.toISOString(), original.date.toISOString());
  assert.equal(decoded.geopoint.latitude, original.geopoint.latitude);
  assert.equal(decoded.geopoint.longitude, original.geopoint.longitude);
  assert.equal(decoded.infinity, Number.POSITIVE_INFINITY);
  assert.equal(Number.isNaN(decoded.nan), true);
  assert.equal(decoded.reference.path, reference.path);
  assert.equal(decoded.timestamp.seconds, original.timestamp.seconds);
  assert.equal(decoded.timestamp.nanoseconds, original.timestamp.nanoseconds);
});
