#!/usr/bin/env node
/* eslint-disable require-jsdoc, max-len */
"use strict";

const fs = require("node:fs");
const fsPromises = require("node:fs/promises");
const crypto = require("node:crypto");
const path = require("node:path");

const {
  applicationDefault,
  deleteApp,
  initializeApp,
} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");

const {ROOT_COLLECTIONS} = require("../audit/multi_tenant_manifest");
const {
  applyAuthUpdates,
  applyFirestoreSets,
  preflightCanonicalDestinations,
  readAuthUsers,
  readCollections,
} = require("../migration/firebase_snapshot");
const {
  planMultiTenantBackfill,
} = require("../migration/multi_tenant_backfill");
const {
  activateFirebaseCliApplicationDefault,
} = require("./firebase_cli_credential");

const PRODUCTION_PROJECTS = new Set(["natus-gestantes"]);

function parseArguments(argv) {
  const options = {apply: false, cloud: false};
  const values = new Map([
    ["--project", "projectId"],
    ["--confirm-project", "confirmProject"],
    ["--tenant", "targetTenantId"],
    ["--emulator-host", "emulatorHost"],
    ["--auth-emulator-host", "authEmulatorHost"],
    ["--output", "output"],
    ["--backup-manifest", "backupManifest"],
    ["--confirm-account", "confirmAccount"],
  ]);
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (values.has(argument)) {
      if (index + 1 >= argv.length) throw new Error(`Valor ausente: ${argument}.`);
      options[values.get(argument)] = argv[index + 1];
      index += 1;
    } else if (argument === "--cloud") {
      options.cloud = true;
    } else if (argument === "--apply") {
      options.apply = true;
    } else if (argument === "--allow-production-read") {
      options.allowProductionRead = true;
    } else if (argument === "--allow-production-write") {
      options.allowProductionWrite = true;
    } else if (argument === "--firebase-cli-login") {
      options.firebaseCliLogin = true;
    } else if (argument === "--help" || argument === "-h") {
      options.help = true;
    } else {
      throw new Error(`Opção desconhecida: ${argument}.`);
    }
  }
  return options;
}

function usage() {
  return [
    "Planeja ou aplica o backfill multi-clínica sem remover dados legados.",
    "",
    "Dry-run cloud:",
    "  node scripts/migrate_multi_tenant.js --project <id> --cloud \\",
    "    --confirm-project <id> --allow-production-read --tenant <tenantId>",
    "",
    "Emulator:",
    "  node scripts/migrate_multi_tenant.js --project demo-natus \\",
    "    --emulator-host 127.0.0.1:8080 --auth-emulator-host 127.0.0.1:9099 \\",
    "    --tenant <tenantId> [--apply]",
    "",
    "Produção com --apply exige também --allow-production-write e um backup",
    "completo recente em --backup-manifest. O padrão sempre é dry-run.",
    "Use --firebase-cli-login --confirm-account <email> para reutilizar uma",
    "sessão local válida do Firebase CLI sem gravar credenciais no projeto.",
  ].join("\n");
}

function isLoopback(host) {
  return /^(localhost|127(?:\.\d{1,3}){3}|\[::1\]):\d{1,5}$/.test(
      String(host || ""),
  );
}

function validateOptions(options) {
  if (options.help) return;
  if (!options.projectId || !options.targetTenantId) {
    throw new Error("--project e --tenant são obrigatórios.");
  }
  const modes = Number(options.cloud) + Number(Boolean(options.emulatorHost));
  if (modes !== 1) throw new Error("Escolha cloud ou Emulator.");
  if (options.confirmProject !== options.projectId && options.cloud) {
    throw new Error("--confirm-project deve repetir o projeto cloud.");
  }
  if (options.emulatorHost) {
    if (!isLoopback(options.emulatorHost) ||
        !isLoopback(options.authEmulatorHost)) {
      throw new Error("Os endpoints do Emulator precisam ser locais.");
    }
    if (!String(options.projectId).startsWith("demo-")) {
      throw new Error("O projeto do Emulator precisa começar com demo-.");
    }
    if (options.firebaseCliLogin) {
      throw new Error("--firebase-cli-login só pode ser usado em cloud.");
    }
  }
  if (options.firebaseCliLogin && !options.confirmAccount) {
    throw new Error("--firebase-cli-login exige --confirm-account.");
  }
  if (PRODUCTION_PROJECTS.has(options.projectId) &&
      !options.allowProductionRead) {
    throw new Error("Produção exige --allow-production-read.");
  }
  if (options.apply && PRODUCTION_PROJECTS.has(options.projectId)) {
    if (!options.allowProductionWrite) {
      throw new Error("Escrita em produção exige --allow-production-write.");
    }
    if (!options.backupManifest) {
      throw new Error("Escrita em produção exige --backup-manifest.");
    }
  }
}

async function listBackupFiles(directory) {
  const files = [];
  for (const entry of await fsPromises.readdir(directory, {withFileTypes: true})) {
    const absolute = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) {
      throw new Error("O backup não pode conter links simbólicos.");
    }
    if (entry.isDirectory()) files.push(...await listBackupFiles(absolute));
    else if (entry.isFile()) files.push(absolute);
  }
  return files;
}

async function sha256(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const input = fs.createReadStream(filePath);
    input.on("error", reject);
    input.on("data", (chunk) => hash.update(chunk));
    input.on("end", () => resolve(hash.digest("hex")));
  });
}

async function verifyBackupChecksums(manifestPath) {
  const backupRoot = path.dirname(manifestPath);
  const checksumPath = path.join(backupRoot, "checksums.sha256");
  if (!fs.existsSync(checksumPath)) {
    throw new Error("O backup não possui checksums.sha256.");
  }

  const entries = new Map();
  const lines = (await fsPromises.readFile(checksumPath, "utf8"))
      .split(/\r?\n/)
      .filter(Boolean);
  for (const line of lines) {
    const match = /^([a-fA-F0-9]{64}) {2}([^\\]+)$/.exec(line);
    if (!match) throw new Error("checksums.sha256 possui formato inválido.");
    const relative = match[2].replaceAll("/", path.sep);
    const absolute = path.resolve(backupRoot, relative);
    const rootPrefix = `${path.resolve(backupRoot)}${path.sep}`;
    if (!absolute.startsWith(rootPrefix) || absolute === checksumPath) {
      throw new Error("checksums.sha256 referencia caminho inválido.");
    }
    const normalized = path.relative(backupRoot, absolute).replaceAll("\\", "/");
    if (entries.has(normalized)) {
      throw new Error("checksums.sha256 possui arquivo duplicado.");
    }
    entries.set(normalized, match[1].toLowerCase());
  }

  const actualFiles = (await listBackupFiles(backupRoot))
      .filter((file) => path.resolve(file) !== path.resolve(checksumPath))
      .map((file) => path.relative(backupRoot, file).replaceAll("\\", "/"))
      .sort();
  const expectedFiles = [...entries.keys()].sort();
  if (JSON.stringify(actualFiles) !== JSON.stringify(expectedFiles)) {
    throw new Error("A lista de arquivos do backup diverge dos checksums.");
  }
  for (const relative of expectedFiles) {
    const actual = await sha256(path.join(backupRoot, ...relative.split("/")));
    if (actual !== entries.get(relative)) {
      throw new Error(`Checksum divergente no backup: ${relative}.`);
    }
  }
}

async function validateProductionBackup(options) {
  if (!options.apply || !PRODUCTION_PROJECTS.has(options.projectId)) return;
  const manifestPath = path.resolve(options.backupManifest);
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  if (manifest.complete !== true || manifest.projectId !== options.projectId) {
    throw new Error("O backup não está completo ou pertence a outro projeto.");
  }
  const age = Date.now() - Date.parse(manifest.completedAt || "");
  if (!Number.isFinite(age) || age < 0 || age > 24 * 60 * 60 * 1000) {
    throw new Error("O backup de produção precisa ter menos de 24 horas.");
  }
  if (!manifest.components || !manifest.components.firestore ||
      !manifest.components.auth || !manifest.components.storage) {
    throw new Error("O backup precisa cobrir Firestore, Auth e Storage.");
  }
  await verifyBackupChecksums(manifestPath);
}

function defaultOutput(projectId) {
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  return path.resolve(__dirname, "..", "migration-reports", `${projectId}_${stamp}`);
}

async function createContext(options) {
  const appOptions = {projectId: options.projectId};
  if (options.emulatorHost) {
    process.env.FIRESTORE_EMULATOR_HOST = options.emulatorHost;
    process.env.FIREBASE_AUTH_EMULATOR_HOST = options.authEmulatorHost;
  } else {
    if (process.env.FIRESTORE_EMULATOR_HOST ||
        process.env.FIREBASE_AUTH_EMULATOR_HOST) {
      throw new Error("Remova variáveis de Emulator antes do modo cloud.");
    }
    if (options.firebaseCliLogin) {
      activateFirebaseCliApplicationDefault({
        confirmAccount: options.confirmAccount,
      });
    }
    appOptions.credential = applicationDefault();
  }
  const app = initializeApp(
      appOptions,
      `natus-migration-${process.pid}-${Date.now()}`,
  );
  return {app, auth: getAuth(app), db: getFirestore(app)};
}

function publicPlan(plan) {
  const byBlocker = {};
  const byWarning = {};
  for (const blocker of plan.blockers) {
    byBlocker[blocker.code] = (byBlocker[blocker.code] || 0) + 1;
  }
  for (const warning of plan.warnings) {
    byWarning[warning.code] = (byWarning[warning.code] || 0) + 1;
  }
  return {
    schemaVersion: plan.schemaVersion,
    migrationVersion: plan.migrationVersion,
    generatedAt: plan.generatedAt,
    targetTenantId: "[redacted]",
    summary: plan.summary,
    blockersByCode: byBlocker,
    warningsByCode: byWarning,
  };
}

async function run(options) {
  const output = path.resolve(options.output || defaultOutput(options.projectId));
  await fsPromises.mkdir(output, {recursive: true});
  const context = await createContext(options);
  try {
    const [collections, authUsers] = await Promise.all([
      readCollections(context.db, ROOT_COLLECTIONS),
      readAuthUsers(context.auth),
    ]);
    const plan = planMultiTenantBackfill(
        {authUsers, collections},
        {targetTenantId: options.targetTenantId},
    );
    await Promise.all([
      fsPromises.writeFile(
          path.join(output, "private-plan.json"),
          `${JSON.stringify(plan, null, 2)}\n`,
          {encoding: "utf8", mode: 0o600},
      ),
      fsPromises.writeFile(
          path.join(output, "summary.json"),
          `${JSON.stringify(publicPlan(plan), null, 2)}\n`,
          "utf8",
      ),
    ]);

    process.stdout.write(`${JSON.stringify(publicPlan(plan), null, 2)}\n`);
    process.stdout.write(`Relatório privado local: ${output}\n`);
    if (plan.blockers.length > 0) {
      process.exitCode = 2;
      return;
    }
    if (!options.apply) {
      process.stdout.write("Dry-run concluído; nenhuma escrita foi executada.\n");
      return;
    }

    const destinationConflicts = await preflightCanonicalDestinations(
        context.db,
        plan.firestoreSets,
    );
    if (destinationConflicts.length > 0) {
      throw new Error(
          `Preflight encontrou ${destinationConflicts.length} conflitos canônicos.`,
      );
    }
    await applyFirestoreSets(context.db, plan.firestoreSets);
    await applyAuthUpdates(context.auth, plan.authUpdates);
    await fsPromises.writeFile(
        path.join(output, "apply-result.json"),
        `${JSON.stringify({
          appliedAt: new Date().toISOString(),
          firestoreSets: plan.firestoreSets.length,
          authUpdates: plan.authUpdates.length,
          status: "complete",
        }, null, 2)}\n`,
        "utf8",
    );
    process.stdout.write("Backfill aplicado com sucesso.\n");
  } finally {
    await deleteApp(context.app);
  }
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }
  validateOptions(options);
  await validateProductionBackup(options);
  await run(options);
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`${error.stack || error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = {
  parseArguments,
  publicPlan,
  validateOptions,
  validateProductionBackup,
  verifyBackupChecksums,
};
