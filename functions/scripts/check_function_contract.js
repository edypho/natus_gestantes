"use strict";

const fs = require("node:fs");
const path = require("node:path");

const {
  auditFunctionContract,
  stableStringify,
} = require("../audit/function_contract");

/**
 * Compara textos sem depender da configuracao regional do sistema.
 * @param {string} left Primeiro texto.
 * @param {string} right Segundo texto.
 * @return {number} Resultado da comparacao.
 */
function compareText(left, right) {
  if (left < right) {
    return -1;
  }
  if (left > right) {
    return 1;
  }
  return 0;
}

/**
 * Normaliza caminhos para a saida ser estavel entre sistemas.
 * @param {string} filePath Caminho de arquivo.
 * @return {string} Caminho normalizado.
 */
function normalizePath(filePath) {
  return filePath.replace(/\\/g, "/");
}

/**
 * Lista arquivos Dart em ordem deterministica, sem seguir links simbolicos.
 * @param {string} directory Diretorio atual.
 * @param {string} repositoryRoot Raiz usada nos caminhos relativos.
 * @return {Array<Object>} Fontes Dart encontradas.
 */
function readDartFiles(directory, repositoryRoot) {
  const files = [];
  const entries = fs.readdirSync(directory, {withFileTypes: true})
      .sort((left, right) => compareText(left.name, right.name));

  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      files.push(...readDartFiles(entryPath, repositoryRoot));
      continue;
    }

    if (!entry.isFile() || path.extname(entry.name) !== ".dart") {
      continue;
    }

    files.push({
      path: normalizePath(path.relative(repositoryRoot, entryPath)),
      source: fs.readFileSync(entryPath, "utf8"),
    });
  }

  return files;
}

/**
 * Interpreta os argumentos aceitos pelo checker.
 * @param {Array<string>} args Argumentos sem node e nome do script.
 * @return {Object} Opcoes normalizadas.
 */
function parseArguments(args) {
  let deployedJsonPath = null;

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];

    if (argument === "--deployed-json") {
      if (deployedJsonPath !== null) {
        throw new TypeError("--deployed-json foi informado mais de uma vez.");
      }
      if (index + 1 >= args.length || args[index + 1].startsWith("--")) {
        throw new TypeError("--deployed-json exige o caminho de um arquivo.");
      }
      deployedJsonPath = args[index + 1];
      index += 1;
      continue;
    }

    if (argument.startsWith("--deployed-json=")) {
      if (deployedJsonPath !== null) {
        throw new TypeError("--deployed-json foi informado mais de uma vez.");
      }
      deployedJsonPath = argument.slice("--deployed-json=".length);
      if (deployedJsonPath === "") {
        throw new TypeError("--deployed-json exige o caminho de um arquivo.");
      }
      continue;
    }

    throw new TypeError(`Argumento desconhecido: ${argument}.`);
  }

  return {deployedJsonPath};
}

/**
 * Resolve o snapshot tanto a partir do cwd do npm quanto da raiz do projeto.
 * @param {string} requestedPath Caminho informado no CLI.
 * @param {string} repositoryRoot Raiz do repositorio.
 * @param {string} currentDirectory Diretorio atual do processo.
 * @return {string} Caminho absoluto escolhido.
 */
function resolveDeployedJsonPath(
    requestedPath,
    repositoryRoot,
    currentDirectory = process.cwd(),
) {
  if (path.isAbsolute(requestedPath)) return requestedPath;

  const candidates = [
    path.resolve(currentDirectory, requestedPath),
    path.resolve(repositoryRoot, requestedPath),
    path.resolve(repositoryRoot, "functions", requestedPath),
  ];
  return candidates.find((candidate) => fs.existsSync(candidate)) ||
    candidates[0];
}

/**
 * Executa a auditoria local e escreve somente JSON em stdout.
 * @param {Array<string>} args Argumentos do CLI.
 * @return {void}
 */
function main(args = []) {
  const repositoryRoot = path.resolve(__dirname, "..", "..");
  const backendFile = path.join(repositoryRoot, "functions", "index.js");
  const appDirectory = path.join(repositoryRoot, "lib");
  const options = parseArguments(args);
  const auditInput = {
    backendSource: fs.readFileSync(backendFile, "utf8"),
    backendPath: "functions/index.js",
    appFiles: readDartFiles(appDirectory, repositoryRoot),
  };

  if (options.deployedJsonPath !== null) {
    const deployedFile = resolveDeployedJsonPath(
        options.deployedJsonPath,
        repositoryRoot,
    );
    const deployedJson = fs.readFileSync(deployedFile, "utf8")
        .replace(/^\uFEFF/, "");
    auditInput.deployedSnapshot = JSON.parse(deployedJson);
    auditInput.deployedPath = normalizePath(
        path.relative(repositoryRoot, deployedFile),
    );
  }

  const report = auditFunctionContract(auditInput);

  process.stdout.write(`${stableStringify(report)}\n`);
  process.exitCode = report.errors.length > 0 ? 1 : 0;
}

if (require.main === module) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    const failure = {
      schemaVersion: 1,
      status: "error",
      summary: {errors: 1, warnings: 0},
      errors: [{
        code: "checker_failure",
        message: error instanceof Error ? error.message : String(error),
      }],
      warnings: [],
    };
    process.stdout.write(`${stableStringify(failure)}\n`);
    process.exitCode = 1;
  }
}

module.exports = {
  main,
  parseArguments,
  readDartFiles,
  resolveDeployedJsonPath,
};
