/* eslint-disable require-jsdoc */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  FirebaseReadAdapter,
} = require("../audit/firebase_read_adapter");
const {
  analyzeMultiTenantData,
} = require("../audit/multi_tenant_analyzer");
const {
  canonicalDocumentId,
  CANONICAL_DISPOSITIONS,
  ROOT_COLLECTIONS,
  SPECIAL_CANONICAL_COLLECTIONS,
  validateRootCollectionManifest,
} = require("../audit/multi_tenant_manifest");
const {
  findingsToCsv,
  sanitizeReport,
} = require("../audit/multi_tenant_reporter");
const {
  auditExitCode,
  isLoopbackHost,
  parseArguments,
  validateArguments,
} = require("../scripts/audit_multi_tenant");

function document(id, data, collection) {
  return {
    id,
    path: `${collection}/${id}`,
    data,
  };
}

function tenantData(tenantId, extra) {
  return {
    clinicaId: tenantId,
    adminDonoId: tenantId,
    ...(extra || {}),
  };
}

function validFixture() {
  const clinic = tenantData("clinic-a", {
    status: "ativa",
    adminUid: "admin-a",
  });
  const admin = tenantData("clinic-a", {
    uid: "admin-a",
    tipo: "admin",
    tipoUsuario: "admin",
    status: "ativo",
  });
  const patientUser = tenantData("clinic-a", {
    uid: "user-a",
    tipo: "gestante",
    tipoUsuario: "gestante",
    status: "ativo",
    pacienteId: "patient-a",
  });
  const patient = tenantData("clinic-a", {
    pacienteId: "patient-a",
    uidGestante: "user-a",
  });
  const patientLock = tenantData("clinic-a", {
    uidUsuario: "user-a",
    pacienteId: "patient-a",
  });

  return {
    generatedAt: "2026-07-22T12:00:00.000Z",
    source: {projectId: "demo-natus", mode: "emulator"},
    collections: {
      clinicas: [document("clinic-a", clinic, "clinicas")],
      clinicasSaaS: [
        document("clinic-a", {...clinic}, "clinicasSaaS"),
      ],
      usuarios: [
        document("admin-a", admin, "usuarios"),
        document("user-a", patientUser, "usuarios"),
      ],
      gestantes: [document("patient-a", patient, "gestantes")],
      vinculosAuthPaciente: [
        document("user-a", patientLock, "vinculosAuthPaciente"),
      ],
      vinculosPacienteAuth: [
        document("patient-a", patientLock, "vinculosPacienteAuth"),
      ],
    },
    canonicalDocuments: [
      {
        id: "admin-a",
        path: "clinicas/clinic-a/usuarios/admin-a",
        collection: "usuarios",
        ancestorTenantId: "clinic-a",
        data: tenantData("clinic-a", {
          uid: "admin-a",
          tipo: "admin",
          tipoUsuario: "admin",
          status: "ativo",
        }),
      },
      {
        id: "user-a",
        path: "clinicas/clinic-a/usuarios/user-a",
        collection: "usuarios",
        ancestorTenantId: "clinic-a",
        data: tenantData("clinic-a", {
          uid: "user-a",
          tipo: "gestante",
          tipoUsuario: "gestante",
          status: "ativo",
          pacienteId: "patient-a",
        }),
      },
      {
        id: "patient-a",
        path: "clinicas/clinic-a/pacientes/patient-a",
        collection: "pacientes",
        ancestorTenantId: "clinic-a",
        ancestorPatientId: "patient-a",
        data: tenantData("clinic-a", {
          pacienteId: "patient-a",
          uidGestante: "user-a",
        }),
      },
    ],
    authUsers: [
      {uid: "admin-a", disabled: false, superAdmin: false},
      {uid: "user-a", disabled: false, superAdmin: false},
    ],
    rootCollections: [
      "clinicas",
      "clinicasSaaS",
      "gestantes",
      "usuarios",
      "vinculosAuthPaciente",
      "vinculosPacienteAuth",
    ],
    scan: {complete: true, truncatedCollections: []},
  };
}

function addValidClinic(fixture, tenantId) {
  const adminUid = `admin-${tenantId}`;
  const clinic = tenantData(tenantId, {
    status: "ativa",
    adminUid,
  });
  const admin = tenantData(tenantId, {
    uid: adminUid,
    tipo: "admin",
    tipoUsuario: "admin",
    status: "ativo",
  });

  fixture.collections.clinicas.push(
      document(tenantId, clinic, "clinicas"),
  );
  fixture.collections.clinicasSaaS.push(
      document(tenantId, {...clinic}, "clinicasSaaS"),
  );
  fixture.collections.usuarios.push(
      document(adminUid, admin, "usuarios"),
  );
  fixture.authUsers.push({
    uid: adminUid,
    disabled: false,
    superAdmin: false,
  });
  fixture.canonicalDocuments.push({
    id: adminUid,
    path: `clinicas/${tenantId}/usuarios/${adminUid}`,
    collection: "usuarios",
    ancestorTenantId: tenantId,
    data: {...admin},
  });
}

function addValidProfessional(fixture) {
  const professional = tenantData("clinic-a", {
    uid: "professional-a",
    tipo: "profissional",
    tipoUsuario: "profissional",
    status: "ativo",
    idVinculo: "professional-entity-a",
  });
  const entity = tenantData("clinic-a", {
    uidProfissional: "professional-a",
  });
  const lock = tenantData("clinic-a", {
    uidUsuario: "professional-a",
    tipoUsuario: "profissional",
    idVinculo: "professional-entity-a",
  });
  fixture.collections.usuarios.push(
      document("professional-a", professional, "usuarios"),
  );
  fixture.collections.profissionais = [
    document("professional-entity-a", entity, "profissionais"),
  ];
  fixture.collections.vinculosAuthEntidade = [
    document("professional-a", lock, "vinculosAuthEntidade"),
  ];
  fixture.collections.vinculosEntidadeAuth = [
    document(
        "profissional_professional-entity-a",
        {...lock},
        "vinculosEntidadeAuth",
    ),
  ];
  fixture.rootCollections.push(
      "profissionais",
      "vinculosAuthEntidade",
      "vinculosEntidadeAuth",
  );
  fixture.authUsers.push({
    uid: "professional-a",
    disabled: false,
    superAdmin: false,
  });
  fixture.canonicalDocuments.push({
    id: "professional-a",
    path: "clinicas/clinic-a/usuarios/professional-a",
    collection: "usuarios",
    ancestorTenantId: "clinic-a",
    data: {...professional},
  });
}

function findingCodes(report) {
  return new Set(report.findings.map((finding) => finding.code));
}

class FakeDocumentSnapshot {
  constructor(reference, data) {
    this.id = reference.id;
    this.ref = reference;
    this._data = data;
  }

  data() {
    return this._data;
  }
}

class FakeQuery {
  constructor(collection, options) {
    this._collection = collection;
    this._cursor = options && options.cursor || "";
    this._limit = options && options.limit || Number.MAX_SAFE_INTEGER;
  }

  orderBy() {
    return new FakeQuery(this._collection, {
      cursor: this._cursor,
      limit: this._limit,
    });
  }

  startAfter(snapshot) {
    return new FakeQuery(this._collection, {
      cursor: snapshot.id,
      limit: this._limit,
    });
  }

  limit(value) {
    return new FakeQuery(this._collection, {
      cursor: this._cursor,
      limit: value,
    });
  }

  select() {
    return this;
  }

  async get() {
    const docs = this._collection.existingSnapshots()
        .filter((snapshot) => snapshot.id > this._cursor)
        .slice(0, this._limit);
    return {docs, size: docs.length};
  }
}

class FakeCollectionReference {
  constructor(database, path) {
    this._database = database;
    this.path = path;
    this.id = path.split("/").at(-1);
  }

  orderBy() {
    return new FakeQuery(this).orderBy();
  }

  async listDocuments() {
    this._database.listDocumentsCalls.push(this.path);
    return this._database.directDocumentIds(this.path)
        .map((id) => new FakeDocumentReference(
            this._database,
            `${this.path}/${id}`,
        ));
  }

  existingSnapshots() {
    return this._database.directDocumentIds(this.path)
        .map((id) => {
          const reference = new FakeDocumentReference(
              this._database,
              `${this.path}/${id}`,
          );
          const data = this._database.dataAt(reference.path);
          return data === undefined ? null :
            new FakeDocumentSnapshot(reference, data);
        })
        .filter(Boolean);
  }
}

class FakeDocumentReference {
  constructor(database, path) {
    this._database = database;
    this.path = path;
    this.id = path.split("/").at(-1);
  }

  async listCollections() {
    this._database.listCollectionsCalls.push(this.path);
    return this._database.childCollectionIds(this.path)
        .map((id) => new FakeCollectionReference(
            this._database,
            `${this.path}/${id}`,
        ));
  }
}

class FakeFirestore {
  constructor(documents) {
    this._documents = new Map(Object.entries(documents));
    this.listDocumentsCalls = [];
    this.listCollectionsCalls = [];
  }

  collection(path) {
    return new FakeCollectionReference(this, path);
  }

  dataAt(path) {
    return this._documents.get(path);
  }

  directDocumentIds(collectionPath) {
    const collectionParts = collectionPath.split("/");
    const prefix = `${collectionPath}/`;
    const ids = new Set();
    for (const path of this._documents.keys()) {
      if (!path.startsWith(prefix)) continue;
      const parts = path.split("/");
      if (parts.length > collectionParts.length) {
        ids.add(parts[collectionParts.length]);
      }
    }
    return [...ids].sort();
  }

  childCollectionIds(documentPath) {
    const documentParts = documentPath.split("/");
    const prefix = `${documentPath}/`;
    const ids = new Set();
    for (const path of this._documents.keys()) {
      if (!path.startsWith(prefix)) continue;
      const parts = path.split("/");
      if (parts.length > documentParts.length + 1) {
        ids.add(parts[documentParts.length]);
      }
    }
    return [...ids].sort();
  }
}

function orphanCanonicalFirestore() {
  return new FakeFirestore({
    "clinicas/clinic-a": tenantData("clinic-a"),
    "clinicas/clinic-a/pacientes/patient-ghost/exames/exam-a":
      tenantData("clinic-a", {pacienteId: "patient-ghost"}),
    "clinicas/clinic-a/pacientes/patient-ghost/exames/exam-a/trilhas/event-a":
      tenantData("clinic-a", {pacienteId: "patient-ghost"}),
    "clinicas/clinic-ghost/usuarios/user-a": tenantData("clinic-ghost", {
      uid: "user-a",
    }),
    "usuarios/root-user": tenantData("clinic-a", {uid: "root-user"}),
    "usuarios/root-user/auditoria/event-a": tenantData("clinic-a"),
    "usuarios/root-user/auditoria/event-a/detalhes/detail-a":
      tenantData("clinic-a"),
    "planos/plan-ghost/auditoria/event-a": tenantData("clinic-a"),
  });
}

test("baseline aprovado fica pronto para release", () => {
  const report = analyzeMultiTenantData(validFixture());
  const blockers = report.findings.filter((finding) => finding.blocker);
  assert.equal(blockers.length, 0);
  assert.equal(report.summary.releaseReady, true);
  assert.equal(report.complete, true);
});

test("manifest exige disposition canônica explícita", () => {
  const allowed = new Set(CANONICAL_DISPOSITIONS);
  for (const definition of ROOT_COLLECTIONS) {
    assert.ok(allowed.has(definition.canonicalDisposition), definition.name);
    if (definition.canonicalDisposition === "mapped") {
      assert.ok(definition.canonicalCopy, definition.name);
    }
  }
  assert.equal(validateRootCollectionManifest(ROOT_COLLECTIONS), true);
  assert.deepEqual(
      new Set(ROOT_COLLECTIONS
          .filter((definition) =>
            definition.canonicalDisposition === "special")
          .map((definition) => definition.name)),
      new Set(SPECIAL_CANONICAL_COLLECTIONS),
  );
  assert.throws(
      () => validateRootCollectionManifest([{name: "novaColecao"}]),
      /Disposição canônica inválida/,
  );
  assert.throws(
      () => validateRootCollectionManifest([{
        name: "novaColecao",
        canonicalDisposition: "mapped",
      }]),
      /canonicalCopy válido/,
  );
  assert.throws(
      () => validateRootCollectionManifest([{
        name: "novaColecao",
        canonicalDisposition: "special",
      }]),
      /não pode ser special/,
  );
});

test("todas as coleções possuem destino canônico aprovado", () => {
  const unresolved = ROOT_COLLECTIONS.filter((definition) =>
    definition.canonicalDisposition === "unresolved");
  assert.deepEqual(unresolved, []);

  const parcelas = ROOT_COLLECTIONS.find((definition) =>
    definition.name === "parcelas");
  assert.equal(
      canonicalDocumentId(parcelas, "parcela-a"),
      "parcela_parcela-a",
  );
  assert.equal(
      canonicalDocumentId(parcelas, "parcela-a", {quarantine: true}),
      "quarentena_parcelas_parcela-a",
  );
});

test("detecta aliases de tenant ausentes, divergentes e invisíveis", () => {
  const fixture = validFixture();
  fixture.collections.planos = [
    document("plan-a", {clinicaId: "clinic-a"}, "planos"),
    document("plan-b", {
      clinicaId: "clinic-a",
      adminDonoId: "clinic-b",
    }, "planos"),
  ];
  const report = analyzeMultiTenantData(fixture);
  const codes = findingCodes(report);

  assert.ok(codes.has("TENANT_ONE_ALIAS_MISSING"));
  assert.ok(codes.has("TENANT_ALIAS_DIVERGENT"));
  assert.ok(codes.has("HARD_CUTOVER_INVISIBLE"));
  assert.equal(report.collections.planos.hardCutoverInvisible, 2);
});

test("detecta vínculo de paciente divergente e campos exatos de query", () => {
  const fixture = validFixture();
  fixture.collections.exames = [
    document("exam-a", tenantData("clinic-a", {
      pacienteId: "patient-a",
      idGestante: "patient-b",
      uidPaciente: "user-a",
    }), "exames"),
  ];
  const report = analyzeMultiTenantData(fixture);
  const codes = findingCodes(report);

  assert.ok(codes.has("PATIENT_ID_ALIAS_DIVERGENT"));
  assert.ok(codes.has("PATIENT_QUERY_FIELD_MISSING"));
});

test("marca atendimento sem ID estável para quarentena", () => {
  const fixture = validFixture();
  fixture.collections.atendimentos = [
    document("visit-a", tenantData("clinic-a"), "atendimentos"),
  ];
  const report = analyzeMultiTenantData(fixture);
  assert.ok(findingCodes(report).has("PATIENT_NAME_ONLY"));
});

test("detecta UID duplicado entre pacientes", () => {
  const fixture = validFixture();
  fixture.collections.gestantes.push(
      document("patient-b", tenantData("clinic-a", {
        pacienteId: "patient-b",
        uidGestante: "user-a",
      }), "gestantes"),
  );
  const report = analyzeMultiTenantData(fixture);
  assert.ok(findingCodes(report).has("PATIENT_UID_DUPLICATED"));
});

test("detecta divergência entre contrato e payload", () => {
  const fixture = validFixture();
  fixture.collections.contratos = [
    document("contract-a", tenantData("clinic-a", {
      pacienteId: "patient-a",
      payload: {pacienteId: "patient-b"},
    }), "contratos"),
  ];
  const report = analyzeMultiTenantData(fixture);
  assert.ok(findingCodes(report).has("CONTRACT_PAYLOAD_DIVERGENT"));
});

test("auditoria do Auth encontra órfãos e claim divergente", () => {
  const fixture = validFixture();
  fixture.authUsers = [
    {uid: "admin-a", disabled: false, superAdmin: true},
    {uid: "auth-orphan", disabled: false, superAdmin: false},
  ];
  const report = analyzeMultiTenantData(fixture);
  const codes = findingCodes(report);

  assert.ok(codes.has("SUPERADMIN_CLAIM_MISMATCH"));
  assert.ok(codes.has("USER_WITHOUT_AUTH"));
  assert.ok(codes.has("AUTH_WITHOUT_USER_PROFILE"));
  const authWithoutProfile = report.findings.find((item) =>
    item.code === "AUTH_WITHOUT_USER_PROFILE");
  assert.equal(authWithoutProfile.blocker, false);
});

test("conta Auth órfã desativada é preservada sem liberar acesso", () => {
  const fixture = validFixture();
  fixture.authUsers.push({
    uid: "disabled-orphan",
    disabled: true,
    superAdmin: false,
  });
  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "DISABLED_AUTH_WITHOUT_USER_PROFILE");

  assert.ok(finding);
  assert.equal(finding.blocker, false);
  assert.equal(report.summary.releaseReady, true);
});

test("Auth omitido bloqueia a liberação", () => {
  const fixture = validFixture();
  delete fixture.authUsers;

  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "AUTH_AUDIT_SKIPPED");

  assert.ok(finding);
  assert.equal(finding.blocker, true);
  assert.equal(report.summary.releaseReady, false);
});

test("varredura truncada nunca produz falso verde", () => {
  const fixture = validFixture();
  fixture.scan = {
    complete: false,
    truncatedCollections: ["documentos"],
    depthLimitReached: false,
  };
  const report = analyzeMultiTenantData(fixture);

  assert.equal(report.complete, false);
  assert.equal(report.summary.releaseReady, false);
  assert.ok(findingCodes(report).has("AUDIT_INCOMPLETE"));
});

test("alvo vazio bloqueia release e so permite smoke explicito", () => {
  const report = analyzeMultiTenantData({
    generatedAt: "2026-07-22T12:00:00.000Z",
    source: {projectId: "demo-natus", mode: "emulator"},
    collections: {},
    canonicalDocuments: [],
    authUsers: [],
    rootCollections: [],
    scan: {complete: true, truncatedCollections: []},
  });

  assert.equal(report.complete, true);
  assert.equal(report.summary.releaseReady, false);
  assert.ok(findingCodes(report).has("AUDIT_EMPTY"));
  assert.ok(report.findings.filter((finding) => finding.blocker)
      .every((finding) => finding.code === "AUDIT_EMPTY"));
  assert.equal(auditExitCode(report, {allowEmptySmoke: false}), 2);
  assert.equal(auditExitCode(report, {allowEmptySmoke: true}), 0);

  report.findings.push({blocker: true, code: "ANOTHER_BLOCKER"});
  report.summary.blockers += 1;
  assert.equal(auditExitCode(report, {allowEmptySmoke: true}), 2);

  const withoutAuth = analyzeMultiTenantData({
    generatedAt: "2026-07-22T12:00:00.000Z",
    source: {projectId: "demo-natus", mode: "emulator"},
    collections: {},
    canonicalDocuments: [],
    rootCollections: [],
    scan: {complete: true, truncatedCollections: []},
  });
  assert.ok(findingCodes(withoutAuth).has("AUTH_AUDIT_SKIPPED"));
  assert.equal(auditExitCode(withoutAuth, {allowEmptySmoke: true}), 2);
});

test("relatório redige caminhos e IDs por padrão", () => {
  const fixture = validFixture();
  fixture.collections.usuarios[1].data.status = "segredo-pessoal@example.com";
  fixture.collections.planos = [
    document("secret-plan", {clinicaId: "clinic-a"}, "planos"),
  ];
  const raw = analyzeMultiTenantData(fixture);
  const safe = sanitizeReport(raw, {includeIdentifiers: false});
  const serialized = JSON.stringify(safe);

  assert.doesNotMatch(serialized, /planos\/secret-plan/);
  assert.doesNotMatch(serialized, /"clinic-a"/);
  assert.doesNotMatch(serialized, /segredo-pessoal@example\.com/);
  assert.match(serialized, /sha256:/);
  assert.match(findingsToCsv(safe), /"severity","blocker","code"/);
});

test("relatório redige PII aninhada em details", () => {
  const raw = {
    findings: [{
      severity: "critical",
      blocker: true,
      code: "PII_TEST",
      location: {collection: "usuarios", path: "usuarios/private-user"},
      message: "Finding sintético.",
      identifiers: {},
      details: {
        email: "pessoa@example.com",
        nested: {
          cpf: "123.456.789-09",
          telefone: "+55 11 99999-9999",
          observacao: "contato-alternativo@example.com",
        },
        fields: ["email", "cpf"],
      },
    }],
  };

  const safe = sanitizeReport(raw, {includeIdentifiers: false});
  const serialized = JSON.stringify(safe);
  assert.doesNotMatch(serialized, /pessoa@example\.com/);
  assert.doesNotMatch(serialized, /123\.456\.789-09/);
  assert.doesNotMatch(serialized, /99999-9999/);
  assert.doesNotMatch(serialized, /contato-alternativo@example\.com/);
  assert.deepEqual(safe.findings[0].details.fields, ["email", "cpf"]);
  assert.match(serialized, /sha256:/);
});

test("relatório só preserva nomes de coleção manifestados", () => {
  const raw = {
    findings: [{
      severity: "critical",
      blocker: true,
      code: "UNKNOWN_COLLECTION",
      location: {
        collection: "pessoa@example.com",
        path: "pessoa@example.com/document-a",
      },
      message: "Coleção desconhecida.",
      identifiers: {},
      details: {},
    }],
  };

  const safe = sanitizeReport(raw, {includeIdentifiers: false});
  assert.doesNotMatch(JSON.stringify(safe), /pessoa@example\.com/);
  assert.match(safe.findings[0].location.collection, /^sha256:/);

  const operational = sanitizeReport(raw, {includeIdentifiers: true});
  assert.equal(
      operational.findings[0].location.collection,
      "pessoa@example.com",
  );
});

test("CSV neutraliza fórmulas com todos os prefixos e whitespace", () => {
  const formulas = [
    "=SUM(1,1)",
    "+cmd|' /C calc'!A0",
    "-2+3",
    "@SUM(1,1)",
    "   =HYPERLINK(\"https://example.invalid\")",
    "\t+1",
  ];
  const csv = findingsToCsv({
    findings: formulas.map((message, index) => ({
      severity: "warning",
      blocker: false,
      code: `CSV_${index}`,
      location: {collection: "audit", path: `audit/${index}`},
      message,
      identifiers: {},
      details: {},
    })),
  });

  for (const formula of formulas) {
    const escaped = formula.replace(/"/g, "\"\"");
    assert.ok(csv.includes(`"'${escaped}"`), formula);
  }
});

test("CLI exige alvo explícito e dupla confirmação para produção", () => {
  assert.throws(() => validateArguments(parseArguments([
    "--cloud",
  ]), {}), /--project/);

  const production = parseArguments([
    "--project", "natus-gestantes",
    "--cloud",
    "--confirm-project", "natus-gestantes",
  ]);
  assert.throws(() => validateArguments(production, {}),
      /allow-production-read/);

  const confirmed = parseArguments([
    "--project", "natus-gestantes",
    "--cloud",
    "--confirm-project", "natus-gestantes",
    "--allow-production-read",
  ]);
  assert.doesNotThrow(() => validateArguments(confirmed, {}));
});

test("CLI aplica e valida limite seguro de referencias", () => {
  const defaults = parseArguments([
    "--project", "demo-natus",
    "--emulator-host", "127.0.0.1:8080",
  ]);
  assert.equal(defaults.maxReferences, 10000);
  assert.doesNotThrow(() => validateArguments(defaults, {}));

  const explicit = parseArguments([
    "--project", "demo-natus",
    "--emulator-host", "127.0.0.1:8080",
    "--max-references", "75",
  ]);
  assert.equal(explicit.maxReferences, 75);
  assert.doesNotThrow(() => validateArguments(explicit, {}));

  for (const invalid of ["0", "1000001"]) {
    const options = parseArguments([
      "--project", "demo-natus",
      "--emulator-host", "127.0.0.1:8080",
      "--max-references", invalid,
    ]);
    assert.throws(
        () => validateArguments(options, {}),
        /--max-references deve estar entre 1 e 1000000/,
    );
  }
});

test("Emulator aceita apenas endpoint loopback", () => {
  assert.equal(isLoopbackHost("127.0.0.1:8080"), true);
  assert.equal(isLoopbackHost("localhost:8080"), true);
  assert.equal(isLoopbackHost("10.0.0.8:8080"), false);

  const remote = parseArguments([
    "--project", "demo-natus",
    "--emulator-host", "10.0.0.8:8080",
  ]);
  assert.throws(() => validateArguments(remote, {}), /precisa ser local/);
});

test("allow-empty-smoke e exclusivo do Emulator", () => {
  const emulator = parseArguments([
    "--project", "demo-natus",
    "--emulator-host", "127.0.0.1:8080",
    "--allow-empty-smoke",
  ]);
  assert.doesNotThrow(() => validateArguments(emulator, {}));

  const cloud = parseArguments([
    "--project", "projeto-homolog",
    "--cloud",
    "--confirm-project", "projeto-homolog",
    "--allow-empty-smoke",
  ]);
  assert.throws(
      () => validateArguments(cloud, {}),
      /allow-empty-smoke so pode ser usado no modo Emulator/,
  );
});

test("adapter Firebase expõe somente operações de inventário", () => {
  const methods = Object.getOwnPropertyNames(FirebaseReadAdapter.prototype);
  for (const forbidden of ["set", "update", "delete", "add", "batch"] ) {
    assert.equal(methods.includes(forbidden), false);
  }
  assert.ok(methods.includes("scanRootCollection"));
  assert.ok(methods.includes("scanCanonicalHierarchy"));
  assert.ok(methods.includes("scanLegacySubcollections"));
});

test("adapter percorre pais canonicos orfaos", async () => {
  const adapter = new FirebaseReadAdapter({
    db: orphanCanonicalFirestore(),
    pageSize: 2,
    maxDepth: 8,
  });
  const clinics = await adapter.scanRootCollection("clinicas");
  const canonical = await adapter.scanCanonicalHierarchy(clinics.snapshots);
  const state = adapter.scanState;

  assert.deepEqual(
      clinics.documents.map((item) => item.path),
      ["clinicas/clinic-a"],
  );
  assert.equal(
      canonical.some((item) =>
        item.path === "clinicas/clinic-ghost" ||
        item.path.endsWith("pacientes/patient-ghost")),
      false,
  );
  assert.ok(canonical.some((item) => item.path.endsWith("exames/exam-a")));
  assert.ok(canonical.some((item) => item.path.endsWith("usuarios/user-a")));
  assert.deepEqual(
      state.missingCanonicalParents.map((item) => item.path),
      [
        "clinicas/clinic-a/pacientes/patient-ghost",
        "clinicas/clinic-ghost",
      ],
  );
  assert.ok(state.unknownCanonicalCollections.includes(
      "clinicas/clinic-a/pacientes/patient-ghost/exames/exam-a/" +
      "trilhas",
  ));
  assert.equal(state.documentsRead, 4);
  assert.equal(state.complete, true);

  const fixture = validFixture();
  fixture.missingCanonicalParents = state.missingCanonicalParents;
  fixture.unknownCanonicalCollections = state.unknownCanonicalCollections;
  const report = analyzeMultiTenantData(fixture);
  const codes = findingCodes(report);
  assert.ok(codes.has("CANONICAL_CLINIC_PARENT_MISSING"));
  assert.ok(codes.has("CANONICAL_PATIENT_PARENT_MISSING"));
  assert.ok(codes.has("UNKNOWN_CANONICAL_COLLECTION"));
  assert.equal(report.summary.releaseReady, false);
  const safeReport = sanitizeReport(report, {includeIdentifiers: false});
  assert.doesNotMatch(JSON.stringify(safeReport), /clinic-ghost/);
  assert.doesNotMatch(JSON.stringify(safeReport), /patient-ghost/);
});

test("limites canonicos falham de forma fechada", async () => {
  const limited = new FirebaseReadAdapter({
    db: orphanCanonicalFirestore(),
    pageSize: 10,
    maxDocuments: 2,
    maxDepth: 8,
  });
  const limitedClinics = await limited.scanRootCollection("clinicas");
  await limited.scanCanonicalHierarchy(limitedClinics.snapshots);
  assert.equal(limited.scanState.limitReached, true);
  assert.equal(limited.scanState.complete, false);

  const shallow = new FirebaseReadAdapter({
    db: orphanCanonicalFirestore(),
    pageSize: 10,
    maxDepth: 1,
  });
  const shallowClinics = await shallow.scanRootCollection("clinicas");
  await shallow.scanCanonicalHierarchy(shallowClinics.snapshots);
  assert.equal(shallow.scanState.depthLimitReached, true);
  assert.equal(shallow.scanState.complete, false);
  assert.ok(shallow.scanState.missingCanonicalParents.some((item) =>
    item.path.endsWith("pacientes/patient-ghost")));
});

test("limite de referencias interrompe o percurso canonico", async () => {
  const db = orphanCanonicalFirestore();
  const adapter = new FirebaseReadAdapter({
    db,
    pageSize: 10,
    maxReferences: 1,
    maxDepth: 8,
  });
  const clinics = await adapter.scanRootCollection("clinicas");
  const canonical = await adapter.scanCanonicalHierarchy(clinics.snapshots);
  const state = adapter.scanState;

  assert.equal(state.referencesVisited, 1);
  assert.equal(state.referencesListed, 2);
  assert.equal(state.referenceLimitReached, true);
  assert.equal(state.complete, false);
  assert.deepEqual(canonical, []);
  assert.deepEqual(db.listDocumentsCalls, ["clinicas"]);
  assert.deepEqual(db.listCollectionsCalls, ["clinicas/clinic-a"]);

  const fixture = validFixture();
  fixture.scan = {
    complete: state.complete,
    truncatedCollections: [],
    referenceLimitReached: state.referenceLimitReached,
  };
  const report = analyzeMultiTenantData(fixture);
  assert.ok(findingCodes(report).has("AUDIT_INCOMPLETE"));
});

test("adapter inventaria subcolecoes legadas orfas", async () => {
  const adapter = new FirebaseReadAdapter({
    db: orphanCanonicalFirestore(),
    pageSize: 10,
    maxDepth: 8,
  });
  const users = await adapter.scanRootCollection("usuarios");
  const plans = await adapter.scanRootCollection("planos");
  await adapter.scanLegacySubcollections({
    usuarios: users.snapshots,
    planos: plans.snapshots,
  });

  const paths = adapter.scanState.unknownLegacySubcollections;
  assert.ok(paths.includes("usuarios/root-user/auditoria"));
  assert.ok(paths.includes(
      "usuarios/root-user/auditoria/event-a/detalhes",
  ));
  assert.ok(paths.includes("planos/plan-ghost/auditoria"));
  assert.equal(plans.documents.length, 0);

  const fixture = validFixture();
  fixture.unknownLegacySubcollections = paths;
  const report = analyzeMultiTenantData(fixture);
  assert.ok(findingCodes(report).has("UNKNOWN_LEGACY_SUBCOLLECTION"));
  assert.equal(report.summary.releaseReady, false);
  const safeReport = sanitizeReport(report, {includeIdentifiers: false});
  assert.doesNotMatch(JSON.stringify(safeReport), /plan-ghost/);

  const shallow = new FirebaseReadAdapter({
    db: orphanCanonicalFirestore(),
    pageSize: 10,
    maxDepth: 1,
  });
  await shallow.scanLegacySubcollections({});
  assert.equal(shallow.scanState.depthLimitReached, true);
  assert.equal(shallow.scanState.complete, false);
});

test("limite de referencias interrompe o percurso legado", async () => {
  const db = orphanCanonicalFirestore();
  const adapter = new FirebaseReadAdapter({
    db,
    pageSize: 10,
    maxReferences: 1,
    maxDepth: 8,
  });
  await adapter.scanLegacySubcollections({});
  const state = adapter.scanState;

  assert.equal(state.referencesVisited, 1);
  assert.equal(state.referencesListed, 1);
  assert.equal(state.referenceLimitReached, true);
  assert.equal(state.complete, false);
  assert.equal(db.listDocumentsCalls.at(-1), "planos");
  assert.ok(!db.listDocumentsCalls.includes(
      "planos/plan-ghost/auditoria",
  ));
  assert.deepEqual(db.listCollectionsCalls, ["planos/plan-ghost"]);
  assert.deepEqual(
      state.unknownLegacySubcollections,
      ["planos/plan-ghost/auditoria"],
  );
});

test("tenant ausente em usuario sempre bloqueia a liberacao", () => {
  const fixture = validFixture();
  delete fixture.collections.usuarios[1].data.clinicaId;
  delete fixture.collections.usuarios[1].data.adminDonoId;

  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "TENANT_BOTH_MISSING" &&
    item.location.path === "usuarios/user-a");

  assert.ok(finding);
  assert.equal(finding.blocker, true);
  assert.equal(report.summary.releaseReady, false);
});

test("colecao raiz desconhecida bloqueia a liberacao", () => {
  const fixture = validFixture();
  fixture.rootCollections.push("colecaoNaoMapeada");

  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "UNKNOWN_COLLECTION");

  assert.ok(finding);
  assert.equal(finding.blocker, true);
  assert.equal(report.summary.releaseReady, false);
});

test("colecao tecnica de rate limit e reconhecida pelo auditor", () => {
  const fixture = validFixture();
  fixture.rootCollections.push("_backendRateLimits");

  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "UNKNOWN_COLLECTION" &&
    item.location.collection === "_backendRateLimits");

  assert.equal(finding, undefined);
});

test("subcolecao canonica desconhecida bloqueia a liberacao", () => {
  const fixture = validFixture();
  fixture.unknownCanonicalCollections = [
    "clinicas/clinic-a/estruturaNaoMapeada",
  ];

  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "UNKNOWN_CANONICAL_COLLECTION");

  assert.ok(finding);
  assert.equal(finding.blocker, true);
  assert.equal(report.summary.releaseReady, false);
});

test(
    "journal canonico tecnico nao exige aliases, mas filhos seguem bloqueados",
    () => {
      const fixture = validFixture();
      const journalId = `op_${"a".repeat(48)}`;
      const journalPath = `clinicas/clinic-a/operacoesSistema/${journalId}`;
      const childPath = `${journalPath}/filhos`;
      fixture.canonicalDocuments.push({
        id: journalId,
        path: journalPath,
        collection: "operacoesSistema",
        ancestorTenantId: "clinic-a",
        data: {
          versao: 1,
          tipo: "create_clinic_user",
          payloadHash: "payload-hash",
          atorHash: "actor-hash",
          recursosHash: "resources-hash",
          estado: "committed",
        },
      });
      fixture.unknownCanonicalCollections = [childPath];

      const report = analyzeMultiTenantData(fixture);
      assert.equal(report.findings.some((finding) =>
        finding.location.path === journalPath), false);
      assert.ok(report.findings.some((finding) =>
        finding.code === "UNKNOWN_CANONICAL_COLLECTION" &&
    finding.location.path === childPath));
    },
);

test("agenda com UID e sem pacienteId nunca passa em verde", () => {
  const fixture = validFixture();
  const agenda = tenantData("clinic-a", {gestanteUid: "admin-a"});
  fixture.collections.agenda = [
    document("slot-a", agenda, "agenda"),
  ];
  fixture.canonicalDocuments.push({
    id: "slot-a",
    path: "clinicas/clinic-a/agenda/slot-a",
    collection: "agenda",
    ancestorTenantId: "clinic-a",
    data: {...agenda},
  });

  const report = analyzeMultiTenantData(fixture);
  assert.ok(findingCodes(report).has("PATIENT_UID_WITHOUT_PATIENT_ID"));
  assert.equal(report.summary.releaseReady, false);
});

test("status desconhecido de usuario bloqueia a liberacao", () => {
  const fixture = validFixture();
  fixture.collections.usuarios[0].data.status = "misterio";
  fixture.canonicalDocuments[0].data.status = "misterio";

  const report = analyzeMultiTenantData(fixture);
  assert.ok(findingCodes(report).has("USER_STATUS_INVALID"));
  assert.equal(report.summary.releaseReady, false);
});

test("perfil profissional exige UID reciproco na entidade", () => {
  const fixture = validFixture();
  const nurse = tenantData("clinic-a", {
    uid: "nurse-a",
    tipo: "enfermeira",
    tipoUsuario: "enfermeira",
    status: "ativo",
    idVinculo: "nurse-entity-a",
  });
  fixture.collections.usuarios.push(
      document("nurse-a", nurse, "usuarios"),
  );
  fixture.collections.enfermeiras = [
    document(
        "nurse-entity-a",
        tenantData("clinic-a"),
        "enfermeiras",
    ),
  ];
  fixture.canonicalDocuments.push({
    id: "nurse-a",
    path: "clinicas/clinic-a/usuarios/nurse-a",
    collection: "usuarios",
    ancestorTenantId: "clinic-a",
    data: {...nurse},
  });

  const report = analyzeMultiTenantData(fixture);
  assert.ok(findingCodes(report).has("STAFF_ENTITY_LINK_DIVERGENT"));
  assert.equal(report.summary.releaseReady, false);
});

test("lock reverso sem tenant e bloqueador", () => {
  const fixture = validFixture();
  const reverse = fixture.collections.vinculosPacienteAuth[0];
  delete reverse.data.clinicaId;
  delete reverse.data.adminDonoId;

  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "TENANT_BOTH_MISSING" &&
    item.location.path === "vinculosPacienteAuth/patient-a");

  assert.ok(finding);
  assert.equal(finding.blocker, true);
  assert.equal(report.summary.releaseReady, false);
});

test("locks de paciente com tenants validos mas diferentes bloqueiam", () => {
  const fixture = validFixture();
  addValidClinic(fixture, "clinic-b");
  fixture.collections.vinculosPacienteAuth[0].data = tenantData("clinic-b", {
    uidUsuario: "user-a",
    pacienteId: "patient-a",
  });

  const report = analyzeMultiTenantData(fixture);
  const directFinding = report.findings.find((item) =>
    item.code === "LOCK_DIVERGENT" &&
    item.location.path === "vinculosAuthPaciente/user-a");
  const reverseFinding = report.findings.find((item) =>
    item.code === "LOCK_DIVERGENT" &&
    item.location.path === "vinculosPacienteAuth/patient-a");

  assert.ok(directFinding);
  assert.ok(directFinding.details.fields.includes("reverseLockTenant"));
  assert.ok(reverseFinding);
  assert.ok(reverseFinding.details.fields.includes("directLockTenant"));
  assert.ok(reverseFinding.details.fields.includes("patientTenant"));
  assert.ok(reverseFinding.details.fields.includes("userTenant"));
  assert.equal(report.summary.releaseReady, false);
});

test("lock de paciente valida perfil, pacienteId e UID recíproco", () => {
  const fixture = validFixture();
  const invalidLock = tenantData("clinic-a", {
    uidUsuario: "admin-a",
    pacienteId: "patient-a",
  });
  fixture.collections.vinculosAuthPaciente = [
    document("admin-a", invalidLock, "vinculosAuthPaciente"),
  ];
  fixture.collections.vinculosPacienteAuth = [
    document("patient-a", {...invalidLock}, "vinculosPacienteAuth"),
  ];

  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "LOCK_DIVERGENT" &&
    item.location.path === "vinculosAuthPaciente/admin-a");
  assert.ok(finding);
  assert.ok(finding.details.fields.includes("userRole"));
  assert.ok(finding.details.fields.includes("userPacienteId"));
  assert.ok(finding.details.fields.includes("patientUid"));
});

test("locks profissionais com tenants validos mas diferentes bloqueiam", () => {
  const fixture = validFixture();
  addValidClinic(fixture, "clinic-b");
  const professional = tenantData("clinic-a", {
    uid: "professional-a",
    tipo: "profissional",
    tipoUsuario: "profissional",
    status: "ativo",
    idVinculo: "professional-entity-a",
  });
  const entity = tenantData("clinic-a", {
    uidProfissional: "professional-a",
  });
  const directLock = tenantData("clinic-a", {
    uidUsuario: "professional-a",
    tipoUsuario: "profissional",
    idVinculo: "professional-entity-a",
  });
  const reverseLock = tenantData("clinic-b", {
    uidUsuario: "professional-a",
    tipoUsuario: "profissional",
    idVinculo: "professional-entity-a",
  });
  fixture.collections.usuarios.push(
      document("professional-a", professional, "usuarios"),
  );
  fixture.collections.profissionais = [
    document("professional-entity-a", entity, "profissionais"),
  ];
  fixture.collections.vinculosAuthEntidade = [
    document("professional-a", directLock, "vinculosAuthEntidade"),
  ];
  fixture.collections.vinculosEntidadeAuth = [
    document(
        "profissional_professional-entity-a",
        reverseLock,
        "vinculosEntidadeAuth",
    ),
  ];
  fixture.rootCollections.push(
      "profissionais",
      "vinculosAuthEntidade",
      "vinculosEntidadeAuth",
  );
  fixture.canonicalDocuments.push({
    id: "professional-a",
    path: "clinicas/clinic-a/usuarios/professional-a",
    collection: "usuarios",
    ancestorTenantId: "clinic-a",
    data: {...professional},
  });

  const report = analyzeMultiTenantData(fixture);
  const directFinding = report.findings.find((item) =>
    item.code === "LOCK_DIVERGENT" &&
    item.location.path === "vinculosAuthEntidade/professional-a");
  const reverseFinding = report.findings.find((item) =>
    item.code === "LOCK_DIVERGENT" &&
    item.location.path ===
      "vinculosEntidadeAuth/profissional_professional-entity-a");

  assert.ok(directFinding);
  assert.ok(directFinding.details.fields.includes("reverseLockTenant"));
  assert.ok(reverseFinding);
  assert.ok(reverseFinding.details.fields.includes("directLockTenant"));
  assert.ok(reverseFinding.details.fields.includes("entityTenant"));
  assert.ok(reverseFinding.details.fields.includes("userTenant"));
  assert.equal(report.summary.releaseReady, false);
});

test("lock profissional valida role, idVinculo e UID da entidade", () => {
  const cases = [
    {
      field: "userRole",
      mutate(fixture) {
        const user = fixture.collections.usuarios.find((item) =>
          item.id === "professional-a");
        user.data.tipo = "admin";
        user.data.tipoUsuario = "admin";
      },
    },
    {
      field: "userIdVinculo",
      mutate(fixture) {
        const user = fixture.collections.usuarios.find((item) =>
          item.id === "professional-a");
        user.data.idVinculo = "another-entity";
      },
    },
    {
      field: "entityUid",
      mutate(fixture) {
        fixture.collections.profissionais[0].data.uidProfissional = "admin-a";
      },
    },
  ];

  for (const scenario of cases) {
    const fixture = validFixture();
    addValidProfessional(fixture);
    scenario.mutate(fixture);
    const report = analyzeMultiTenantData(fixture);
    const finding = report.findings.find((item) =>
      item.code === "LOCK_DIVERGENT" &&
      item.location.path === "vinculosAuthEntidade/professional-a" &&
      item.details.fields.includes(scenario.field));
    assert.ok(finding, scenario.field);
  }
});

test("documento canonico valida UID contra paciente e usuario", () => {
  const fixture = validFixture();
  fixture.canonicalDocuments.push({
    id: "exam-canonical-a",
    path: "clinicas/clinic-a/pacientes/patient-a/exames/exam-canonical-a",
    collection: "exames",
    ancestorTenantId: "clinic-a",
    ancestorPatientId: "patient-a",
    data: tenantData("clinic-a", {
      pacienteId: "patient-a",
      uidGestante: "admin-a",
    }),
  });

  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "PATIENT_ID_UID_CROSS_LINK" &&
    item.location.path.endsWith("exames/exam-canonical-a"));

  assert.ok(finding);
  assert.equal(finding.blocker, true);
});

test("registro operacional legado exige copia canonica", () => {
  const fixture = validFixture();
  fixture.collections.exames = [
    document("exam-a", tenantData("clinic-a", {
      pacienteId: "patient-a",
      idGestante: "patient-a",
      uidGestante: "user-a",
    }), "exames"),
  ];

  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "CANONICAL_COPY_MISSING" &&
    item.location.path === "exames/exam-a");

  assert.ok(finding);
  assert.equal(
      finding.details.expectedPath,
      "clinicas/clinic-a/pacientes/patient-a/exames/exam-a",
  );
  assert.equal(finding.blocker, true);
});

test("cópia mapeada compara aliases exatos, portal e payload", () => {
  const fixture = validFixture();
  fixture.collections.exames = [
    document("exam-a", tenantData("clinic-a", {
      pacienteId: "patient-a",
      idGestante: "patient-a",
      uidGestante: "user-a",
      resultadoClinico: "não comparar",
    }), "exames"),
  ];
  fixture.collections.contratos = [
    document("contract-a", tenantData("clinic-a", {
      pacienteId: "patient-a",
      pacienteUid: "user-a",
      payload: {
        pacienteId: "patient-a",
        uidPaciente: "user-a",
        valorFinanceiro: 100,
      },
    }), "contratos"),
  ];
  fixture.canonicalDocuments.push(
      {
        id: "exam-a",
        path: "clinicas/clinic-a/pacientes/patient-a/exames/exam-a",
        collection: "exames",
        ancestorTenantId: "clinic-a",
        ancestorPatientId: "patient-a",
        data: tenantData("clinic-a", {
          pacienteId: "patient-a",
          idGestante: "patient-b",
          uidGestante: "user-a",
          resultadoClinico: "valor diferente e fora do escopo",
        }),
      },
      {
        id: "contract-a",
        path: "clinicas/clinic-a/pacientes/patient-a/contratos/contract-a",
        collection: "contratos",
        ancestorTenantId: "clinic-a",
        ancestorPatientId: "patient-a",
        data: tenantData("clinic-a", {
          pacienteId: "patient-a",
          pacienteUid: "user-a",
          payload: {
            pacienteId: "patient-a",
            uidPaciente: "admin-a",
            valorFinanceiro: 999,
          },
        }),
      },
  );

  const report = analyzeMultiTenantData(fixture);
  const exam = report.findings.find((finding) =>
    finding.code === "CANONICAL_COPY_DIVERGENT" &&
    finding.location.path === "exames/exam-a");
  const contract = report.findings.find((finding) =>
    finding.code === "CANONICAL_COPY_DIVERGENT" &&
    finding.location.path === "contratos/contract-a");

  assert.ok(exam);
  assert.ok(exam.details.fields.includes("idGestante"));
  assert.equal(exam.details.fields.includes("resultadoClinico"), false);
  assert.ok(contract);
  assert.ok(contract.details.fields.includes("payload.uidPaciente"));
  assert.equal(
      contract.details.fields.includes("payload.valorFinanceiro"),
      false,
  );
});

test("cópia mapeada ignora conteúdo fora dos campos selecionados", () => {
  const fixture = validFixture();
  fixture.collections.exames = [
    document("exam-a", tenantData("clinic-a", {
      pacienteId: "patient-a",
      idGestante: "patient-a",
      uidGestante: "user-a",
      resultadoClinico: "legado",
      valorFinanceiro: 10,
    }), "exames"),
  ];
  fixture.canonicalDocuments.push({
    id: "exam-a",
    path: "clinicas/clinic-a/pacientes/patient-a/exames/exam-a",
    collection: "exames",
    ancestorTenantId: "clinic-a",
    ancestorPatientId: "patient-a",
    data: tenantData("clinic-a", {
      pacienteId: "patient-a",
      idGestante: "patient-a",
      uidGestante: "user-a",
      resultadoClinico: "canônico",
      valorFinanceiro: 999,
    }),
  });

  const report = analyzeMultiTenantData(fixture);
  assert.equal(report.findings.some((finding) =>
    finding.code === "CANONICAL_COPY_DIVERGENT" &&
    finding.location.path === "exames/exam-a"), false);
});

test("cópia canônica de profissional compara idVinculo e aliases UID", () => {
  const fixture = validFixture();
  const professional = tenantData("clinic-a", {
    uid: "professional-a",
    uidProfissional: "professional-a",
    tipo: "profissional",
    tipoUsuario: "profissional",
    status: "ativo",
    idVinculo: "entity-a",
  });
  fixture.collections.usuarios.push(
      document("professional-a", professional, "usuarios"),
  );
  fixture.authUsers.push({
    uid: "professional-a",
    disabled: false,
    superAdmin: false,
  });
  fixture.canonicalDocuments.push({
    id: "professional-a",
    path: "clinicas/clinic-a/usuarios/professional-a",
    collection: "usuarios",
    ancestorTenantId: "clinic-a",
    data: tenantData("clinic-a", {
      ...professional,
      idVinculo: "entity-b",
      uidProfissional: "different-uid",
    }),
  });

  const report = analyzeMultiTenantData(fixture);
  const finding = report.findings.find((item) =>
    item.code === "CANONICAL_COPY_DIVERGENT" &&
    item.location.path === "usuarios/professional-a");
  assert.ok(finding);
  assert.ok(finding.details.fields.includes("idVinculo"));
  assert.ok(finding.details.fields.includes("uidProfissional"));
});

test("usuário e paciente apenas canônicos bloqueiam o bootstrap", () => {
  const fixture = validFixture();
  fixture.canonicalDocuments.push(
      {
        id: "canonical-only-user",
        path: "clinicas/clinic-a/usuarios/canonical-only-user",
        collection: "usuarios",
        ancestorTenantId: "clinic-a",
        data: tenantData("clinic-a", {
          uid: "canonical-only-user",
          tipo: "profissional",
          tipoUsuario: "profissional",
          status: "ativo",
          idVinculo: "entity-only",
        }),
      },
      {
        id: "canonical-only-patient",
        path: "clinicas/clinic-a/pacientes/canonical-only-patient",
        collection: "pacientes",
        ancestorTenantId: "clinic-a",
        ancestorPatientId: "canonical-only-patient",
        data: tenantData("clinic-a", {
          pacienteId: "canonical-only-patient",
        }),
      },
  );

  const report = analyzeMultiTenantData(fixture);
  const codes = findingCodes(report);
  assert.ok(codes.has("CANONICAL_USER_WITHOUT_ROOT_PROFILE"));
  assert.ok(codes.has("CANONICAL_PATIENT_WITHOUT_ROOT_ENTITY"));
  const reverse = report.findings.filter((finding) =>
    finding.code === "CANONICAL_COPY_WITHOUT_LEGACY_SOURCE");
  assert.deepEqual(
      new Set(reverse.map((finding) => finding.location.path)),
      new Set([
        "clinicas/clinic-a/usuarios/canonical-only-user",
        "clinicas/clinic-a/pacientes/canonical-only-patient",
      ]),
  );
});

test("reverse check cobre só os pares canônicos aprovados", () => {
  const fixture = validFixture();
  fixture.canonicalDocuments.push(
      {
        id: "exam-without-source",
        path: "clinicas/clinic-a/pacientes/patient-a/exames/" +
          "exam-without-source",
        collection: "exames",
        ancestorTenantId: "clinic-a",
        ancestorPatientId: "patient-a",
        data: tenantData("clinic-a", {
          pacienteId: "patient-a",
          idGestante: "patient-a",
          uidGestante: "user-a",
        }),
      },
      {
        id: "patient-agenda-without-approved-source",
        path: "clinicas/clinic-a/pacientes/patient-a/agenda/" +
          "patient-agenda-without-approved-source",
        collection: "agenda",
        ancestorTenantId: "clinic-a",
        ancestorPatientId: "patient-a",
        data: tenantData("clinic-a", {
          pacienteId: "patient-a",
          gestanteUid: "user-a",
        }),
      },
      {
        id: "operation-without-source",
        path: "clinicas/clinic-a/operacao/operation-without-source",
        collection: "operacao",
        ancestorTenantId: "clinic-a",
        data: tenantData("clinic-a"),
      },
  );

  const report = analyzeMultiTenantData(fixture);
  const reversePaths = report.findings
      .filter((finding) =>
        finding.code === "CANONICAL_COPY_WITHOUT_LEGACY_SOURCE")
      .map((finding) => finding.location.path);
  assert.ok(reversePaths.includes(
      "clinicas/clinic-a/pacientes/patient-a/exames/exam-without-source",
  ));
  assert.equal(reversePaths.some((path) =>
    path.includes("patient-agenda-without-approved-source")), false);
  assert.equal(reversePaths.some((path) =>
    path.includes("operation-without-source")), false);
});

test("colecoes mapeadas exigem copia no destino aprovado", () => {
  const fixture = validFixture();
  const collections = ["parcelas"];
  const record = tenantData("clinic-a", {
    pacienteId: "patient-a",
    gestanteId: "patient-a",
    idGestante: "patient-a",
    uidGestante: "user-a",
  });
  for (const collection of collections) {
    fixture.collections[collection] = [
      document(`${collection}-a`, {...record}, collection),
    ];
  }
  fixture.rootCollections.push(...collections);

  const report = analyzeMultiTenantData(fixture);
  const findings = report.findings.filter((item) =>
    item.code === "CANONICAL_COPY_MISSING" &&
      item.location.collection === "parcelas");

  assert.equal(findings.length, collections.length);
  assert.deepEqual(
      new Set(findings.map((finding) => finding.location.collection)),
      new Set(collections),
  );
  for (const finding of findings) {
    assert.equal(finding.blocker, true);
    assert.equal(
        finding.details.expectedPath,
        "clinicas/clinic-a/pacientes/patient-a/financeiro/" +
          "parcela_parcelas-a",
    );
  }
  assert.equal(report.summary.releaseReady, false);
});

test("metadado de varredura ausente falha de forma fechada", () => {
  const fixture = validFixture();
  delete fixture.scan;

  const report = analyzeMultiTenantData(fixture);
  assert.equal(report.complete, false);
  assert.equal(report.summary.releaseReady, false);
  assert.ok(findingCodes(report).has("AUDIT_INCOMPLETE"));
});

test("Auth no Emulator exige endpoint local explicito", () => {
  const missing = parseArguments([
    "--project", "demo-natus",
    "--emulator-host", "127.0.0.1:8080",
    "--include-auth",
  ]);
  assert.throws(
      () => validateArguments(missing, {}),
      /--auth-emulator-host/,
  );

  const remote = parseArguments([
    "--project", "demo-natus",
    "--emulator-host", "127.0.0.1:8080",
    "--include-auth",
    "--auth-emulator-host", "10.0.0.8:9099",
  ]);
  assert.throws(() => validateArguments(remote, {}), /precisa ser local/);

  const local = parseArguments([
    "--project", "demo-natus",
    "--emulator-host", "127.0.0.1:8080",
    "--include-auth",
    "--auth-emulator-host", "127.0.0.1:9099",
  ]);
  assert.doesNotThrow(() => validateArguments(local, {}));
});

test("modo cloud rejeita variavel herdada do Auth Emulator", () => {
  const cloud = parseArguments([
    "--project", "projeto-homolog",
    "--cloud",
    "--confirm-project", "projeto-homolog",
    "--include-auth",
  ]);
  assert.throws(
      () => validateArguments(cloud, {
        FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099",
      }),
      /FIREBASE_AUTH_EMULATOR_HOST/,
  );
});
