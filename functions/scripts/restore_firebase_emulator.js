#!/usr/bin/env node
/* eslint-disable require-jsdoc, max-len */
"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const fsPromises = require("node:fs/promises");
const path = require("node:path");

const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");

const {
  decodeFirestoreValue,
} = require("../migration/firestore_value_codec");

function parseArguments(argv) {
  const options = {restoreStorage: false};
  const values = new Map([
    ["--project", "projectId"],
    ["--input", "input"],
    ["--firestore-emulator-host", "firestoreHost"],
    ["--auth-emulator-host", "authHost"],
    ["--storage-emulator-host", "storageHost"],
    ["--storage-bucket", "storageBucket"],
  ]);
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (values.has(argument)) {
      if (index + 1 >= argv.length) throw new Error(`Valor ausente: ${argument}.`);
      options[values.get(argument)] = argv[index + 1];
      index += 1;
    } else if (argument === "--restore-storage") {
      options.restoreStorage = true;
    } else if (argument === "--help" || argument === "-h") {
      options.help = true;
    } else {
      throw new Error(`Opção desconhecida: ${argument}.`);
    }
  }
  return options;
}

function isLoopback(host) {
  return /^(localhost|127(?:\.\d{1,3}){3}|\[::1\]):\d{1,5}$/.test(
      String(host || ""),
  );
}

function validateOptions(options) {
  if (options.help) return;
  if (!options.projectId || !String(options.projectId).startsWith("demo-")) {
    throw new Error("A restauração só aceita projetos demo-* do Emulator.");
  }
  if (!options.input || !isLoopback(options.firestoreHost) ||
      !isLoopback(options.authHost)) {
    throw new Error("Informe backup e hosts locais de Firestore/Auth.");
  }
  if (options.restoreStorage &&
      (!isLoopback(options.storageHost) || !options.storageBucket)) {
    throw new Error("Storage exige host local e bucket.");
  }
}

function usage() {
  return [
    "Restaura um backup Natus somente no Firebase Emulator.",
    "",
    "  node scripts/restore_firebase_emulator.js --project demo-natus \\",
    "    --input <backup> --firestore-emulator-host 127.0.0.1:8080 \\",
    "    --auth-emulator-host 127.0.0.1:9099",
  ].join("\n");
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

async function verifyChecksums(inputDirectory) {
  const checksumPath = path.join(inputDirectory, "checksums.sha256");
  const lines = (await fsPromises.readFile(checksumPath, "utf8"))
      .split(/\r?\n/)
      .filter(Boolean);
  for (const line of lines) {
    const match = line.match(/^([a-f0-9]{64}) {2}(.+)$/);
    if (!match) throw new Error("Linha de checksum inválida.");
    const filePath = path.resolve(inputDirectory, match[2]);
    if (!filePath.startsWith(`${path.resolve(inputDirectory)}${path.sep}`)) {
      throw new Error("Checksum aponta para fora do backup.");
    }
    if (await sha256(filePath) !== match[1]) {
      throw new Error(`Checksum inválido: ${match[2]}.`);
    }
  }
  return lines.length;
}

async function restoreFirestore(db, inputDirectory) {
  const content = await fsPromises.readFile(
      path.join(inputDirectory, "firestore.jsonl"),
      "utf8",
  );
  const records = content.split(/\r?\n/).filter(Boolean).map(JSON.parse);
  let batch = db.batch();
  let pending = 0;
  for (const record of records) {
    batch.set(
        db.doc(record.path),
        decodeFirestoreValue(record.data, db),
        {merge: false},
    );
    pending += 1;
    if (pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return records.length;
}

function createUserProperties(user) {
  const properties = {
    uid: user.uid,
    disabled: user.disabled === true,
    emailVerified: user.emailVerified === true,
  };
  if (user.email) properties.email = user.email;
  if (user.displayName) properties.displayName = user.displayName;
  if (user.phoneNumber) properties.phoneNumber = user.phoneNumber;
  if (user.photoURL) properties.photoURL = user.photoURL;
  return properties;
}

async function restoreAuth(auth, inputDirectory) {
  const users = JSON.parse(await fsPromises.readFile(
      path.join(inputDirectory, "auth-users.json"),
      "utf8",
  ));
  for (const user of users) {
    await auth.createUser(createUserProperties(user));
    if (user.customClaims && Object.keys(user.customClaims).length > 0) {
      await auth.setCustomUserClaims(user.uid, user.customClaims);
    }
  }
  return users.length;
}

async function restoreStorage(bucket, inputDirectory) {
  const manifest = (await fsPromises.readFile(
      path.join(inputDirectory, "storage-manifest.jsonl"),
      "utf8",
  )).split(/\r?\n/).filter(Boolean).map(JSON.parse);
  for (const object of manifest) {
    const source = path.join(
        inputDirectory,
        "storage",
        "objects",
        object.localName,
    );
    await bucket.upload(source, {
      destination: object.name,
      resumable: false,
      metadata: {
        contentType: object.contentType || undefined,
        cacheControl: object.cacheControl || undefined,
        contentDisposition: object.contentDisposition || undefined,
        metadata: object.metadata || {},
      },
    });
  }
  return manifest.length;
}

async function run(options) {
  const inputDirectory = path.resolve(options.input);
  const manifest = JSON.parse(await fsPromises.readFile(
      path.join(inputDirectory, "backup-manifest.json"),
      "utf8",
  ));
  if (manifest.complete !== true) throw new Error("Backup incompleto.");
  const checkedFiles = await verifyChecksums(inputDirectory);

  process.env.FIRESTORE_EMULATOR_HOST = options.firestoreHost;
  process.env.FIREBASE_AUTH_EMULATOR_HOST = options.authHost;
  if (options.restoreStorage) {
    process.env.FIREBASE_STORAGE_EMULATOR_HOST = options.storageHost;
  }
  const app = initializeApp({
    projectId: options.projectId,
    storageBucket: options.storageBucket,
  }, `natus-restore-${process.pid}-${Date.now()}`);
  try {
    const firestoreDocuments = await restoreFirestore(
        getFirestore(app),
        inputDirectory,
    );
    const authUsers = await restoreAuth(getAuth(app), inputDirectory);
    const storageObjects = options.restoreStorage ? await restoreStorage(
        getStorage(app).bucket(),
        inputDirectory,
    ) : 0;
    process.stdout.write(`${JSON.stringify({
      authUsers,
      checkedFiles,
      firestoreDocuments,
      storageObjects,
    }, null, 2)}\n`);
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
  validateOptions,
  verifyChecksums,
};
