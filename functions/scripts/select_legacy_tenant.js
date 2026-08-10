#!/usr/bin/env node
/* eslint-disable require-jsdoc */
"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");

function parseArguments(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (["--input", "--output"].includes(argument)) {
      if (index + 1 >= argv.length) {
        throw new Error(`Valor ausente: ${argument}.`);
      }
      options[argument.slice(2)] = argv[index + 1];
      index += 1;
    } else {
      throw new Error(`Opção desconhecida: ${argument}.`);
    }
  }
  return options;
}

function text(value) {
  return String(value === undefined || value === null ? "" : value).trim();
}

function hash(value) {
  return crypto.createHash("sha256").update(value).digest("hex").slice(0, 12);
}

async function run(options) {
  if (!options.input || !options.output) {
    throw new Error("--input e --output são obrigatórios.");
  }
  const input = path.resolve(options.input);
  const records = (await fs.readFile(
      path.join(input, "firestore.jsonl"),
      "utf8",
  )).split(/\r?\n/).filter(Boolean).map(JSON.parse);
  const clinics = new Set(records
      .filter((record) => record.path.split("/").length === 2 &&
        record.path.startsWith("clinicasSaaS/"))
      .map((record) => record.path.split("/")[1]));
  const supportedCollections = new Set([
    "agenda",
    "enfermeiras",
    "gestantes",
    "obstetras",
    "parcelas",
    "usuarios",
  ]);
  const support = new Map([...clinics].map((clinic) => [clinic, 0]));
  for (const record of records) {
    const parts = record.path.split("/");
    if (parts.length !== 2 || !supportedCollections.has(parts[0])) continue;
    const tenant = text(record.data.clinicaId || record.data.adminDonoId);
    if (support.has(tenant)) support.set(tenant, support.get(tenant) + 1);
  }
  const ordered = [...support.entries()].sort((left, right) =>
    right[1] - left[1] || left[0].localeCompare(right[0]));
  if (ordered.length === 0 || ordered[0][1] === 0) {
    throw new Error("Nenhuma clínica possui evidência de dados legados.");
  }
  if (ordered.length > 1 && ordered[0][1] <= ordered[1][1] * 2) {
    throw new Error("A clínica principal é ambígua; escolha manualmente.");
  }
  await fs.mkdir(path.dirname(path.resolve(options.output)), {recursive: true});
  await fs.writeFile(path.resolve(options.output), `${ordered[0][0]}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
  process.stdout.write(`${JSON.stringify({
    selectedTenantHash: hash(ordered[0][0]),
    selectedSupport: ordered[0][1],
    runnerUpSupport: ordered[1] ? ordered[1][1] : 0,
  }, null, 2)}\n`);
}

if (require.main === module) {
  const options = parseArguments(process.argv.slice(2));
  run(options).catch((error) => {
    process.stderr.write(`${error.stack || error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = {parseArguments};
