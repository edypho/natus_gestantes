#!/usr/bin/env node
/* eslint-disable require-jsdoc, max-len */
"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const fsPromises = require("node:fs/promises");
const path = require("node:path");

const {
  applicationDefault,
  deleteApp,
  initializeApp,
} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");

const {
  encodeFirestoreValue,
} = require("../migration/firestore_value_codec");
const {
  activateFirebaseCliApplicationDefault,
} = require("./firebase_cli_credential");

const PRODUCTION_PROJECTS = new Set(["natus-gestantes"]);

function parseArguments(argv) {
  const options = {};
  const values = new Map([
    ["--project", "projectId"],
    ["--confirm-project", "confirmProject"],
    ["--output", "output"],
    ["--storage-bucket", "storageBucket"],
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
    } else if (argument === "--allow-production-read") {
      options.allowProductionRead = true;
    } else if (argument === "--include-auth") {
      options.includeAuth = true;
    } else if (argument === "--include-storage") {
      options.includeStorage = true;
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
    "Cria backup lógico local e somente leitura de Firestore/Auth/Storage.",
    "",
    "  node scripts/backup_firebase.js --project <id> --cloud \\",
    "    --confirm-project <id> --allow-production-read --include-auth \\",
    "    --include-storage --storage-bucket <bucket> --output <diretorio>",
    "  Opcional: --firebase-cli-login --confirm-account <email>",
  ].join("\n");
}

function validateOptions(options) {
  if (options.help) return;
  if (!options.projectId || !options.cloud) {
    throw new Error("--project e --cloud são obrigatórios.");
  }
  if (options.confirmProject !== options.projectId) {
    throw new Error("--confirm-project deve repetir o projeto.");
  }
  if (PRODUCTION_PROJECTS.has(options.projectId) &&
      !options.allowProductionRead) {
    throw new Error("Produção exige --allow-production-read.");
  }
  if (!options.output) throw new Error("--output é obrigatório.");
  if (options.includeStorage && !options.storageBucket) {
    throw new Error("--include-storage exige --storage-bucket.");
  }
  if (options.firebaseCliLogin && !options.confirmAccount) {
    throw new Error("--firebase-cli-login exige --confirm-account.");
  }
  if (process.env.FIRESTORE_EMULATOR_HOST ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST ||
      process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    throw new Error("Remova variáveis de Emulator antes do backup cloud.");
  }
}

async function appendJsonLine(handle, value) {
  await handle.write(`${JSON.stringify(value)}\n`, null, "utf8");
}

async function exportCollection(reference, handle, state) {
  const snapshot = await reference.get();
  const ordered = [...snapshot.docs].sort((left, right) =>
    left.ref.path.localeCompare(right.ref.path));
  for (const document of ordered) {
    await appendJsonLine(handle, {
      path: document.ref.path,
      data: encodeFirestoreValue(document.data() || {}),
      createTime: document.createTime && document.createTime.toDate().toISOString(),
      updateTime: document.updateTime && document.updateTime.toDate().toISOString(),
    });
    state.documents += 1;
    const children = await document.ref.listCollections();
    for (const child of children.sort((left, right) =>
      left.path.localeCompare(right.path))) {
      await exportCollection(child, handle, state);
    }
  }
}

async function exportFirestore(db, outputDirectory) {
  const target = path.join(outputDirectory, "firestore.jsonl");
  const handle = await fsPromises.open(target, "w", 0o600);
  const state = {collections: 0, documents: 0};
  try {
    const collections = await db.listCollections();
    const ordered = [...collections].sort((left, right) =>
      left.path.localeCompare(right.path));
    state.collections = ordered.length;
    for (const collection of ordered) {
      await exportCollection(collection, handle, state);
    }
  } finally {
    await handle.close();
  }
  return state;
}

async function exportAuth(auth, outputDirectory) {
  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users.map((user) => user.toJSON()));
    pageToken = page.pageToken;
  } while (pageToken);
  users.sort((left, right) => left.uid.localeCompare(right.uid));
  await fsPromises.writeFile(
      path.join(outputDirectory, "auth-users.json"),
      `${JSON.stringify(users, null, 2)}\n`,
      {encoding: "utf8", mode: 0o600},
  );
  return {users: users.length};
}

function storageFileName(name) {
  return `${Buffer.from(name, "utf8").toString("base64url")}.bin`;
}

async function exportStorage(bucket, outputDirectory) {
  const objectDirectory = path.join(outputDirectory, "storage", "objects");
  await fsPromises.mkdir(objectDirectory, {recursive: true});
  const manifestPath = path.join(outputDirectory, "storage-manifest.jsonl");
  const manifest = await fsPromises.open(manifestPath, "w", 0o600);
  let objects = 0;
  let bytes = 0;
  try {
    const [files] = await bucket.getFiles({autoPaginate: true});
    files.sort((left, right) => left.name.localeCompare(right.name));
    for (const file of files) {
      const localName = storageFileName(file.name);
      const destination = path.join(objectDirectory, localName);
      await file.download({destination});
      const size = Number(file.metadata.size || 0);
      await appendJsonLine(manifest, {
        name: file.name,
        localName,
        size,
        generation: file.metadata.generation || "",
        md5Hash: file.metadata.md5Hash || "",
        contentType: file.metadata.contentType || "",
        cacheControl: file.metadata.cacheControl || "",
        contentDisposition: file.metadata.contentDisposition || "",
        metadata: file.metadata.metadata || {},
      });
      objects += 1;
      bytes += size;
    }
  } finally {
    await manifest.close();
  }
  return {bucket: bucket.name, bytes, objects};
}

async function listFiles(directory) {
  const output = [];
  for (const entry of await fsPromises.readdir(directory, {withFileTypes: true})) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) output.push(...await listFiles(absolute));
    else output.push(absolute);
  }
  return output;
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

async function writeChecksums(outputDirectory) {
  const files = (await listFiles(outputDirectory))
      .filter((file) => path.basename(file) !== "checksums.sha256")
      .sort();
  const lines = [];
  for (const file of files) {
    const relative = path.relative(outputDirectory, file).replaceAll("\\", "/");
    lines.push(`${await sha256(file)}  ${relative}`);
  }
  await fsPromises.writeFile(
      path.join(outputDirectory, "checksums.sha256"),
      `${lines.join("\n")}\n`,
      {encoding: "utf8", mode: 0o600},
  );
  return {files: files.length};
}

async function run(options) {
  const outputDirectory = path.resolve(options.output);
  if (fs.existsSync(outputDirectory) &&
      (await fsPromises.readdir(outputDirectory)).length > 0) {
    throw new Error("O diretório de backup precisa estar vazio.");
  }
  await fsPromises.mkdir(outputDirectory, {recursive: true});
  const startedAt = new Date().toISOString();
  const manifestPath = path.join(outputDirectory, "backup-manifest.json");
  const manifest = {
    schemaVersion: "1.0.0",
    projectId: options.projectId,
    startedAt,
    completedAt: "",
    complete: false,
    components: {auth: false, firestore: false, storage: false},
    counts: {},
  };
  await fsPromises.writeFile(
      manifestPath,
      `${JSON.stringify(manifest, null, 2)}\n`,
      {encoding: "utf8", mode: 0o600},
  );

  if (options.firebaseCliLogin) {
    activateFirebaseCliApplicationDefault({
      confirmAccount: options.confirmAccount,
    });
  }
  const app = initializeApp({
    projectId: options.projectId,
    storageBucket: options.storageBucket,
    credential: applicationDefault(),
  }, `natus-backup-${process.pid}-${Date.now()}`);
  try {
    manifest.counts.firestore = await exportFirestore(
        getFirestore(app),
        outputDirectory,
    );
    manifest.components.firestore = true;
    if (options.includeAuth) {
      manifest.counts.auth = await exportAuth(getAuth(app), outputDirectory);
      manifest.components.auth = true;
    }
    if (options.includeStorage) {
      manifest.counts.storage = await exportStorage(
          getStorage(app).bucket(),
          outputDirectory,
      );
      manifest.components.storage = true;
    }
    manifest.completedAt = new Date().toISOString();
    manifest.complete = manifest.components.firestore &&
      (!options.includeAuth || manifest.components.auth) &&
      (!options.includeStorage || manifest.components.storage);
    await fsPromises.writeFile(
        manifestPath,
        `${JSON.stringify(manifest, null, 2)}\n`,
        {encoding: "utf8", mode: 0o600},
    );
    manifest.counts.checksums = await writeChecksums(outputDirectory);
    process.stdout.write(`${JSON.stringify(manifest, null, 2)}\n`);
  } finally {
    await deleteApp(app);
  }
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }
  validateOptions(options);
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
  storageFileName,
  validateOptions,
};
