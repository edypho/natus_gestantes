#!/usr/bin/env node
/* eslint-disable require-jsdoc, max-len */
"use strict";

const fs = require("node:fs/promises");
const path = require("node:path");

const {
  applicationDefault,
  deleteApp,
  initializeApp,
} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");

const {
  FirebaseReadAdapter,
} = require("../audit/firebase_read_adapter");
const {
  analyzeMultiTenantData,
} = require("../audit/multi_tenant_analyzer");
const {ROOT_COLLECTIONS} = require("../audit/multi_tenant_manifest");
const {
  findingsToCsv,
  findingsToJsonLines,
  sanitizeReport,
} = require("../audit/multi_tenant_reporter");
const {
  activateFirebaseCliApplicationDefault,
} = require("./firebase_cli_credential");

const PRODUCTION_PROJECTS = new Set(["natus-gestantes"]);
const MAX_REFERENCES_UPPER_BOUND = 1000000;

function usage() {
  return [
    "Auditoria read-only de isolamento multi-clínica.",
    "",
    "Emulator:",
    "  node scripts/audit_multi_tenant.js --project demo-natus " +
      "--emulator-host 127.0.0.1:8080",
    "",
    "Cloud (exige credencial IAM somente leitura):",
    "  node scripts/audit_multi_tenant.js --project projeto-homolog " +
      "--cloud --confirm-project projeto-homolog",
    "",
    "Produção exige também:",
    "  --allow-production-read --confirm-project natus-gestantes",
    "",
    "Opções:",
    "  --include-auth              Audita UID/status/custom claim do Auth",
    "  --auth-emulator-host <host> Endpoint local do Auth Emulator",
    "  --allow-empty-smoke         Exit 0 para smoke vazio só no Emulator",
    "  --include-identifiers       Mantém IDs no relatório local",
    "  --output <diretório>        Destino dos relatórios",
    "  --page-size <1..1000>       Página de leitura (padrão: 500)",
    "  --max-documents <n>         Documentos consultados; 0 = sem teto",
    "  --max-references <1..1000000> Referências (padrão: 10000)",
    "  --max-depth <1..20>         Profundidade canônica (padrão: 8)",
    "  --firebase-cli-login        Reutiliza a sessão local do Firebase CLI",
    "  --confirm-account <email>   Confirma a conta do Firebase CLI",
    "  --help                      Exibe esta ajuda",
  ].join("\n");
}

function parseArguments(argv) {
  const parsed = {
    cloud: false,
    includeAuth: false,
    includeIdentifiers: false,
    allowProductionRead: false,
    allowEmptySmoke: false,
    pageSize: 500,
    maxDocuments: 0,
    maxReferences: 10000,
    maxDepth: 8,
  };
  const valueOptions = new Map([
    ["--project", "projectId"],
    ["--confirm-project", "confirmProject"],
    ["--emulator-host", "emulatorHost"],
    ["--auth-emulator-host", "authEmulatorHost"],
    ["--output", "output"],
    ["--page-size", "pageSize"],
    ["--max-documents", "maxDocuments"],
    ["--max-references", "maxReferences"],
    ["--max-depth", "maxDepth"],
    ["--confirm-account", "confirmAccount"],
  ]);

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (valueOptions.has(argument)) {
      if (index + 1 >= argv.length) {
        throw new Error(`Valor ausente para ${argument}.`);
      }
      parsed[valueOptions.get(argument)] = argv[index + 1];
      index += 1;
    } else if (argument === "--cloud") {
      parsed.cloud = true;
    } else if (argument === "--include-auth") {
      parsed.includeAuth = true;
    } else if (argument === "--include-identifiers") {
      parsed.includeIdentifiers = true;
    } else if (argument === "--allow-production-read") {
      parsed.allowProductionRead = true;
    } else if (argument === "--allow-empty-smoke") {
      parsed.allowEmptySmoke = true;
    } else if (argument === "--firebase-cli-login") {
      parsed.firebaseCliLogin = true;
    } else if (argument === "--help" || argument === "-h") {
      parsed.help = true;
    } else {
      throw new Error(`Opção desconhecida: ${argument}`);
    }
  }

  for (const field of [
    "pageSize",
    "maxDocuments",
    "maxReferences",
    "maxDepth",
  ]) {
    const numeric = Number(parsed[field]);
    if (!Number.isSafeInteger(numeric) || numeric < 0) {
      throw new Error(`Valor numérico inválido em ${field}.`);
    }
    parsed[field] = numeric;
  }

  return parsed;
}

function isLoopbackHost(host) {
  return /^(localhost|127(?:\.\d{1,3}){3}|\[::1\]):\d{1,5}$/.test(
      String(host || ""),
  );
}

function validateArguments(options, environment) {
  if (options.help) return;
  if (!options.projectId || !String(options.projectId).trim()) {
    throw new Error("--project é obrigatório; o alvo padrão nunca é usado.");
  }
  options.projectId = String(options.projectId).trim();

  const modes = Number(options.cloud) + Number(Boolean(options.emulatorHost));
  if (modes !== 1) {
    throw new Error("Escolha exatamente um modo: --cloud ou --emulator-host.");
  }
  if (options.pageSize < 1 || options.pageSize > 1000) {
    throw new Error("--page-size deve estar entre 1 e 1000.");
  }
  if (options.maxDepth < 1 || options.maxDepth > 20) {
    throw new Error("--max-depth deve estar entre 1 e 20.");
  }
  if (options.maxReferences < 1 ||
      options.maxReferences > MAX_REFERENCES_UPPER_BOUND) {
    throw new Error(
        "--max-references deve estar entre 1 e 1000000.",
    );
  }

  if (options.emulatorHost) {
    if (!isLoopbackHost(options.emulatorHost)) {
      throw new Error("O host do Emulator precisa ser local e incluir a porta.");
    }
    if (options.cloud) {
      throw new Error("Emulator e cloud são mutuamente exclusivos.");
    }
    if (options.authEmulatorHost && !options.includeAuth) {
      throw new Error("--auth-emulator-host exige --include-auth.");
    }
    if (options.includeAuth && !options.authEmulatorHost) {
      throw new Error(
          "--include-auth no Emulator exige --auth-emulator-host explicito.",
      );
    }
    if (options.authEmulatorHost &&
        !isLoopbackHost(options.authEmulatorHost)) {
      throw new Error(
          "O host do Auth Emulator precisa ser local e incluir a porta.",
      );
    }
    if (options.firebaseCliLogin) {
      throw new Error("--firebase-cli-login só pode ser usado em cloud.");
    }
    return;
  }

  if (options.authEmulatorHost) {
    throw new Error("--auth-emulator-host so pode ser usado no modo Emulator.");
  }
  if (options.allowEmptySmoke) {
    throw new Error("--allow-empty-smoke so pode ser usado no modo Emulator.");
  }
  if (environment.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
        "FIRESTORE_EMULATOR_HOST está definido; remova-o antes do modo cloud.",
    );
  }
  if (environment.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error(
        "FIREBASE_AUTH_EMULATOR_HOST esta definido; remova-o antes do modo cloud.",
    );
  }
  if (options.confirmProject !== options.projectId) {
    throw new Error("--confirm-project deve repetir exatamente o projeto cloud.");
  }
  if (PRODUCTION_PROJECTS.has(options.projectId) &&
      !options.allowProductionRead) {
    throw new Error(
        "Produção bloqueada: informe --allow-production-read explicitamente.",
    );
  }
  if (options.firebaseCliLogin && !options.confirmAccount) {
    throw new Error("--firebase-cli-login exige --confirm-account.");
  }
}

function safeProjectName(projectId) {
  return String(projectId).replace(/[^a-zA-Z0-9_-]/g, "_");
}

function defaultOutputDirectory(projectId, generatedAt) {
  const stamp = generatedAt.replace(/[:.]/g, "-");
  return path.resolve(
      __dirname,
      "..",
      "audit-reports",
      `${safeProjectName(projectId)}_${stamp}`,
  );
}

async function writeReports(report, outputDirectory) {
  await fs.mkdir(outputDirectory, {recursive: true});
  await Promise.all([
    fs.writeFile(
        path.join(outputDirectory, "report.json"),
        `${JSON.stringify(report, null, 2)}\n`,
        "utf8",
    ),
    fs.writeFile(
        path.join(outputDirectory, "findings.csv"),
        findingsToCsv(report),
        "utf8",
    ),
    fs.writeFile(
        path.join(outputDirectory, "findings.jsonl"),
        findingsToJsonLines(report),
        "utf8",
    ),
  ]);
}

async function createFirebaseContext(options) {
  const appOptions = {projectId: options.projectId};
  if (options.emulatorHost) {
    process.env.FIRESTORE_EMULATOR_HOST = options.emulatorHost;
    if (options.includeAuth) {
      process.env.FIREBASE_AUTH_EMULATOR_HOST = options.authEmulatorHost;
    }
  } else {
    if (options.firebaseCliLogin) {
      activateFirebaseCliApplicationDefault({
        confirmAccount: options.confirmAccount,
      });
    }
    appOptions.credential = applicationDefault();
  }

  const app = initializeApp(
      appOptions,
      `natus-audit-${process.pid}-${Date.now()}`,
  );
  return {
    app,
    db: getFirestore(app),
    auth: options.includeAuth ? getAuth(app) : null,
  };
}

function auditExitCode(report, options) {
  if (!report.complete) return 2;
  if (report.summary.blockers === 0) return 0;
  if (!options.allowEmptySmoke) return 2;

  const blockers = report.findings.filter((finding) => finding.blocker);
  const allowedSmokeBlockers = new Set([
    "AUDIT_EMPTY",
    "CANONICAL_DESTINATION_POLICY_UNDEFINED",
  ]);
  const emptySmokeOnly = blockers.some((finding) =>
    finding.code === "AUDIT_EMPTY") && blockers.every((finding) =>
    allowedSmokeBlockers.has(finding.code));
  return emptySmokeOnly ? 0 : 2;
}

async function runAudit(options) {
  const generatedAt = new Date().toISOString();
  const mode = options.emulatorHost ? "emulator" : "cloud";
  const outputDirectory = path.resolve(
      options.output || defaultOutputDirectory(options.projectId, generatedAt),
  );

  process.stdout.write([
    "Natus — auditoria estritamente read-only",
    `Projeto: ${options.projectId}`,
    `Modo: ${mode}`,
    `Auth: ${options.includeAuth ? "incluído" : "não incluído"}`,
    "Nenhuma operação set/update/delete/add/batch é executada.",
    "",
  ].join("\n"));

  const context = await createFirebaseContext(options);
  try {
    const adapter = new FirebaseReadAdapter({
      db: context.db,
      auth: context.auth,
      pageSize: options.pageSize,
      maxDocuments: options.maxDocuments,
      maxReferences: options.maxReferences,
      maxDepth: options.maxDepth,
    });
    const rootCollections = await adapter.listRootCollections();
    const collections = {};
    const rootSnapshots = {};
    const truncatedCollections = [];
    let clinicSnapshots = [];

    for (const definition of ROOT_COLLECTIONS) {
      if (adapter.scanState.limitReached) {
        collections[definition.name] = [];
        truncatedCollections.push(definition.name);
        continue;
      }
      const result = await adapter.scanRootCollection(definition.name);
      collections[definition.name] = result.documents;
      rootSnapshots[definition.name] = result.snapshots;
      if (definition.name === "clinicas") clinicSnapshots = result.snapshots;
      if (adapter.scanState.limitReached) {
        truncatedCollections.push(definition.name);
      }
    }

    if (!adapter.scanState.limitReached &&
        !adapter.scanState.referenceLimitReached) {
      await adapter.scanLegacySubcollections(rootSnapshots);
    }
    const traversalStopped = adapter.scanState.limitReached ||
      adapter.scanState.referenceLimitReached;
    const canonicalDocuments = traversalStopped ? [] :
      await adapter.scanCanonicalHierarchy(clinicSnapshots);
    const authUsers = options.includeAuth ?
      await adapter.listAuthenticationUsers() : undefined;
    const state = adapter.scanState;
    const complete = state.complete && truncatedCollections.length === 0;
    const rawReport = analyzeMultiTenantData({
      generatedAt,
      source: {
        projectId: options.projectId,
        mode,
        emulatorHost: options.emulatorHost || "",
        authEmulatorHost: options.authEmulatorHost || "",
        authIncluded: options.includeAuth,
        identifiersIncluded: options.includeIdentifiers,
      },
      collections,
      canonicalDocuments,
      authUsers,
      rootCollections,
      unknownCanonicalCollections: state.unknownCanonicalCollections,
      unknownLegacySubcollections: state.unknownLegacySubcollections,
      missingCanonicalParents: state.missingCanonicalParents,
      scan: {
        complete,
        documentsRead: state.documentsRead,
        referencesListed: state.referencesListed,
        referencesVisited: state.referencesVisited,
        referenceLimitReached: state.referenceLimitReached,
        truncatedCollections,
        depthLimitReached: state.depthLimitReached,
      },
    });
    const report = sanitizeReport(rawReport, {
      includeIdentifiers: options.includeIdentifiers,
    });
    await writeReports(report, outputDirectory);

    process.stdout.write([
      `Documentos raiz: ${report.summary.scannedRootDocuments}`,
      `Documentos canônicos: ${report.summary.scannedCanonicalDocuments}`,
      `Referências percorridas: ${state.referencesVisited}`,
      `Achados: ${report.summary.totalFindings}`,
      `Bloqueadores: ${report.summary.blockers}`,
      `Relatório: ${outputDirectory}`,
      "",
    ].join("\n"));

    return auditExitCode(report, options);
  } finally {
    await deleteApp(context.app);
  }
}

async function main(argv) {
  try {
    const options = parseArguments(argv);
    validateArguments(options, process.env);
    if (options.help) {
      process.stdout.write(`${usage()}\n`);
      return 0;
    }
    return await runAudit(options);
  } catch (error) {
    process.stderr.write(`Auditoria abortada: ${error.message}\n`);
    return 1;
  }
}

if (require.main === module) {
  main(process.argv.slice(2)).then((exitCode) => {
    process.exitCode = exitCode;
  });
}

module.exports = {
  auditExitCode,
  isLoopbackHost,
  main,
  parseArguments,
  runAudit,
  validateArguments,
};
