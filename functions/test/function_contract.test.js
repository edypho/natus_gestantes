"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");

const {
  auditFunctionContract,
  extractBackendExports,
  extractCallableCalls,
  extractDeployedFunctionDetails,
  extractDeployedFunctionNames,
  extractHttpEndpoints,
  stableStringify,
} = require("../audit/function_contract");

const {
  parseArguments,
  resolveDeployedJsonPath,
} = require("../scripts/check_function_contract");

/**
 * Executa a auditoria com fontes pequenas usadas pelos testes.
 * @param {string} backendSource Fonte das Functions.
 * @param {string} appSource Fonte Dart.
 * @param {*=} deployedSnapshot Snapshot implantado opcional.
 * @param {Object=} overrides Opcoes adicionais da auditoria.
 * @return {Object} Relatorio produzido.
 */
function auditFixture(
    backendSource,
    appSource,
    deployedSnapshot,
    overrides = {},
) {
  const input = {
    backendSource,
    backendPath: "functions/index.js",
    appFiles: [{path: "lib/example.dart", source: appSource}],
  };

  if (deployedSnapshot !== undefined) {
    input.deployedSnapshot = deployedSnapshot;
    input.deployedPath = "audit/deployed.json";
  }

  return auditFunctionContract(Object.assign(input, overrides));
}

test("extrai export e callable estatico em multiplas linhas", () => {
  const exportsFound = extractBackendExports(`
exports.buscarPaciente =
  onCall({}, async () => ({}));
`, "functions/index.js");
  const calls = extractCallableCalls(`
final callable = FirebaseFunctions.instance
    .httpsCallable(
      'buscarPaciente',
    );
`, "lib/example.dart");

  assert.equal(exportsFound.length, 1);
  assert.equal(exportsFound[0].functionName, "buscarPaciente");
  assert.equal(exportsFound[0].type, "onCall");
  assert.equal(calls.staticCalls.length, 1);
  assert.equal(calls.staticCalls[0].functionName, "buscarPaciente");
  assert.equal(calls.dynamicCalls.length, 0);
});

test("ignora exports e callables escritos dentro de strings", () => {
  const backendSource = [
    "const exemplo = \"exports.falso = onCall({}, () => null);\";",
    "const template = `exports.outroFalso = onRequest(() => null)`;",
    "// exports.comentado = onCall({}, () => null);",
    "exports.real = onCall({}, () => null);",
  ].join("\n");
  const appSource = [
    "final exemplo = \"functions.httpsCallable('falso')\";",
    "final bloco = '''functions.httpsCallable('outroFalso')''';",
    "// functions.httpsCallable('comentado');",
    "functions.httpsCallable('real');",
  ].join("\n");
  const report = auditFixture(backendSource, appSource);

  assert.deepEqual(report.backendExports.map((item) => item.functionName), [
    "real",
  ]);
  assert.deepEqual(report.callableCalls.map((item) => item.functionName), [
    "real",
  ]);
  assert.equal(report.backendExports[0].line, 4);
  assert.equal(report.callableCalls[0].line, 4);
  assert.equal(report.callableCalls[0].path, "lib/example.dart");
  assert.equal(report.errors.length, 0);
});

test("extrai callable Dart com tipo generico", () => {
  const calls = extractCallableCalls([
    "final callable = FirebaseFunctions.instance",
    "    .httpsCallable<Map<String, Object?>>( ",
    "      'buscarPaciente',",
    "    );",
  ].join("\n"), "lib/generic.dart");

  assert.equal(calls.staticCalls.length, 1);
  assert.equal(calls.staticCalls[0].functionName, "buscarPaciente");
  assert.equal(calls.staticCalls[0].line, 2);
  assert.equal(calls.staticCalls[0].path, "lib/generic.dart");
  assert.equal(calls.dynamicCalls.length, 0);
});

test("callable ausente produz erro", () => {
  const report = auditFixture(
      "exports.outra = onCall({}, () => null);",
      "functions.httpsCallable('inexistente');",
  );

  assert.equal(report.status, "error");
  assert.equal(report.errors.length, 1);
  assert.equal(report.errors[0].code, "missing_callable_export");
  assert.equal(report.errors[0].functionName, "inexistente");
});

test("callable ligada a onRequest produz incompatibilidade", () => {
  const report = auditFixture(
      "exports.endpoint = onRequest({}, () => null);",
      "functions.httpsCallable('endpoint');",
  );

  assert.equal(report.errors.length, 1);
  assert.equal(report.errors[0].code, "callable_type_mismatch");
  assert.equal(report.errors[0].expectedType, "onCall");
  assert.equal(report.errors[0].actualType, "onRequest");
  assert.ok(report.warnings.some((warning) =>
    warning.code === "unused_http_export" &&
      warning.functionName === "endpoint"));
});

test("callable dinamica bloqueia o contrato de forma fail-closed", () => {
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "functions.httpsCallable(nomeDaFuncao);",
  );

  assert.equal(report.status, "error");
  assert.equal(report.dynamicCallableCalls.length, 1);
  const blocker = report.errors.find((error) =>
    error.code === "dynamic_callable_name");
  assert.equal(blocker.severity, "blocker");
  assert.equal(report.warnings.some((warning) =>
    warning.code === "dynamic_callable_name"), false);
});

test("receiver injetado bloqueia quando ha snapshot implantado", () => {
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "functions.httpsCallable('buscar');",
      {result: [{id: "buscar", region: "europe-west1"}]},
  );
  const blocker = report.errors.find((error) =>
    error.code === "callable_region_inconclusive");

  assert.equal(report.status, "error");
  assert.equal(report.callableCalls[0].expectedRegion, null);
  assert.equal(report.callableCalls[0].regionResolution, "inconclusive");
  assert.equal(blocker.severity, "blocker");
  assert.equal(report.warnings.some((warning) =>
    warning.code === "callable_region_inconclusive"), false);
});

test("receiver injetado sem snapshot permanece como warning", () => {
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "functions.httpsCallable('buscar');",
  );

  assert.equal(report.status, "ok");
  assert.equal(report.errors.length, 0);
  assert.ok(report.warnings.some((warning) =>
    warning.code === "callable_region_inconclusive"));
});

test("FirebaseFunctions.instance bloqueia deploy fora de us-central1", () => {
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "FirebaseFunctions.instance.httpsCallable('buscar');",
      {result: [{
        id: "buscar",
        region: "europe-west1",
        callableTrigger: {},
      }]},
  );
  const mismatch = report.errors.find((error) =>
    error.code === "deployed_region_usage_mismatch");

  assert.equal(report.callableCalls[0].expectedRegion, "us-central1");
  assert.equal(report.callableCalls[0].regionResolution, "firebase_default");
  assert.equal(mismatch.expectedRegion, "us-central1");
  assert.equal(mismatch.actualRegion, "europe-west1");
  assert.equal(mismatch.severity, "blocker");
  assert.equal(report.summary.deployedRegionMismatches, 1);
});

test("instanceFor literal aceita deploy na mesma regiao", () => {
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      [
        "FirebaseFunctions.instanceFor(",
        "  region: 'europe-west1',",
        ").httpsCallable('buscar');",
      ].join("\n"),
      {result: [{
        id: "buscar",
        region: "europe-west1",
        callableTrigger: {},
      }]},
  );

  assert.equal(report.callableCalls[0].expectedRegion, "europe-west1");
  assert.equal(
      report.callableCalls[0].regionResolution,
      "instance_for_literal",
  );
  assert.equal(report.errors.length, 0);
  assert.equal(report.summary.deployedRegionMismatches, 0);
});

test("snapshot sem regiao bloqueia callable de regiao conhecida", () => {
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "FirebaseFunctions.instance.httpsCallable('buscar');",
      {result: ["buscar"]},
  );
  const blocker = report.errors.find((error) =>
    error.code === "deployed_region_unknown");

  assert.equal(report.status, "error");
  assert.equal(blocker.expectedRegion, "us-central1");
  assert.equal(blocker.actualRegion, null);
  assert.equal(blocker.severity, "blocker");
  assert.equal(report.summary.deployedRegionMismatches, 0);
  assert.equal(report.summary.deployedRegionUnknown, 1);
  assert.equal(report.summary.deployedCodebaseMismatches, 0);
  assert.equal(
      Object.hasOwn(report.deployedFunctionDetails[0], "region"),
      false,
  );
  assert.equal(
      Object.hasOwn(report.deployedFunctionDetails[0], "codebase"),
      false,
  );
});

test("bloqueia export implantado em codebase divergente", () => {
  const snapshot = {result: [{
    id: "buscar",
    region: "us-central1",
    codebase: "backoffice",
    callableTrigger: {},
  }]};
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "FirebaseFunctions.instance.httpsCallable('buscar');",
      snapshot,
  );
  const mismatch = report.errors.find((error) =>
    error.code === "deployed_codebase_mismatch");

  assert.equal(report.deployedFunctionDetails[0].codebase, "backoffice");
  assert.equal(mismatch.expectedCodebase, "default");
  assert.equal(mismatch.actualCodebase, "backoffice");
  assert.equal(mismatch.severity, "blocker");
  assert.equal(report.summary.deployedCodebaseMismatches, 1);

  const compatible = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "FirebaseFunctions.instance.httpsCallable('buscar');",
      snapshot,
      {localCodebase: "backoffice"},
  );
  assert.equal(compatible.errors.length, 0);
});

test("resolve URL Cloud Run para export onRequest", () => {
  const appSource = [
    "final endpoint = Uri.parse(",
    "  'https://reenviarlink-abc123-uc.a.run.app',",
    ");",
  ].join("\n");
  const report = auditFixture(
      "exports.reenviarLink = onRequest({}, () => null);",
      appSource,
  );

  assert.equal(report.errors.length, 0);
  assert.equal(report.httpEndpoints.length, 1);
  assert.equal(report.httpEndpoints[0].matchedExport, "reenviarLink");
  assert.ok(report.warnings.some((warning) =>
    warning.code === "deployment_bound_http_url"));
  assert.equal(report.warnings.some((warning) =>
    warning.code === "unused_http_export"), false);
  assert.equal(report.summary.unusedHttpExports, 0);
});

test("alerta export onRequest sem consumidor HTTP estatico", () => {
  const report = auditFixture(
      "exports.webhookLegado = onRequest({}, () => null);",
      "",
  );
  const warning = report.warnings.find((item) =>
    item.code === "unused_http_export");

  assert.equal(report.status, "ok");
  assert.equal(report.errors.length, 0);
  assert.equal(report.httpEndpoints.length, 0);
  assert.equal(report.summary.unusedHttpExports, 1);
  assert.equal(warning.functionName, "webhookLegado");
  assert.equal(warning.type, "onRequest");
  assert.equal(warning.path, "functions/index.js");
  assert.equal(warning.line, 1);
});

test("bloqueia endpoint Firebase orfao e ignora URL HTTP comum", () => {
  const firebaseUrl =
    "https://us-central1-demo.cloudfunctions.net/funcaoInexistente";
  const appSource = [
    "final site = 'https://example.com/ajuda';",
    `final endpoint = '${firebaseUrl}';`,
  ].join("\n");
  const report = auditFixture("", appSource, {result: []});
  const blocker = report.errors.find((error) =>
    error.code === "http_export_not_found");

  assert.equal(report.httpEndpoints.length, 1);
  assert.equal(report.httpEndpoints[0].url, firebaseUrl);
  assert.equal(blocker.severity, "blocker");
  assert.equal(blocker.expectedType, "onRequest");
  assert.equal(blocker.path, "lib/example.dart");
  assert.equal(blocker.line, 2);
  assert.equal(report.status, "error");
});

test("extrai URL cloudfunctions.net e detecta tipo incorreto", () => {
  const url = "https://us-central1-demo.cloudfunctions.net/notificar";
  const endpoints = extractHttpEndpoints(
      `final endpoint = '${url}';`,
      "lib/example.dart",
  );
  const report = auditFixture(
      "exports.notificar = onCall({}, () => null);",
      `final endpoint = '${url}';`,
  );

  assert.equal(endpoints.length, 1);
  assert.equal(endpoints[0].targetHint, "notificar");
  assert.equal(report.errors.length, 1);
  assert.equal(report.errors[0].code, "http_type_mismatch");
});

test("aceita formatos de snapshot e normaliza nomes completos", () => {
  const fromArray = extractDeployedFunctionNames([
    {id: "funcaoSimples"},
    "projects/demo/locations/us-central1/functions/funcaoCompleta",
  ]);
  const fromResult = extractDeployedFunctionNames({
    result: [
      {name: "projects/demo/locations/us-central1/functions/outraFuncao"},
      {function: "funcaoSimples"},
    ],
  });

  assert.deepEqual(fromArray, ["funcaoCompleta", "funcaoSimples"]);
  assert.deepEqual(fromResult, ["funcaoSimples", "outraFuncao"]);
});

test("snapshot sem trigger bloqueia export local mesmo fora de usages", () => {
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "",
      {result: ["buscar"]},
  );
  const blocker = report.errors.find((error) =>
    error.code === "deployed_trigger_unknown");

  assert.equal(report.status, "error");
  assert.equal(blocker.functionName, "buscar");
  assert.equal(blocker.expectedType, "onCall");
  assert.equal(blocker.actualType, null);
  assert.deepEqual(blocker.usageKinds, []);
  assert.deepEqual(report.deployedFunctions, ["buscar"]);
  assert.equal(report.summary.deployedRegionUnknown, 0);
  assert.equal(report.summary.deployedTriggerUnknown, 1);
});

test("snapshot sem trigger bloqueia callable usada", () => {
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "FirebaseFunctions.instance.httpsCallable('buscar');",
      {result: [{
        id: "buscar",
        region: "us-central1",
        codebase: "default",
      }]},
  );
  const blocker = report.errors.find((error) =>
    error.code === "deployed_trigger_unknown");

  assert.equal(report.status, "error");
  assert.equal(blocker.functionName, "buscar");
  assert.equal(blocker.expectedType, "onCall");
  assert.equal(blocker.actualType, null);
  assert.deepEqual(blocker.usageKinds, ["callable"]);
  assert.equal(report.summary.deployedTriggerUnknown, 1);
});

test("ignora exports, callables e endpoints dentro de comentarios", () => {
  const backendSource = [
    "// exports.falsoLinha = onCall({}, () => null);",
    "/* exports.falsoBloco = onRequest({}, () => null); */",
    "exports.real = onCall({}, () => null);",
    "exports.realHttp = onRequest({}, () => null);",
  ].join("\n");
  const appSource = [
    "// functions.httpsCallable('falsoLinha');",
    "/* functions.httpsCallable('falsoBloco'); */",
    "// https://us-central1-demo.cloudfunctions.net/falsoHttp",
    "functions.httpsCallable('real');",
    "final endpoint = 'https://us-central1-demo.cloudfunctions.net/realHttp';",
  ].join("\n");
  const report = auditFixture(backendSource, appSource);

  assert.deepEqual(report.backendExports.map((item) => item.functionName), [
    "real",
    "realHttp",
  ]);
  assert.deepEqual(report.callableCalls.map((item) => item.functionName), [
    "real",
  ]);
  assert.equal(report.httpEndpoints.length, 1);
  assert.equal(report.httpEndpoints[0].matchedExport, "realHttp");
  assert.equal(report.errors.length, 0);
});

test("snapshot bloqueia callable usada localmente mas nao implantada", () => {
  const report = auditFixture([
    "exports.usada = onCall({}, () => null);",
    "exports.naoUsada = onCall({}, () => null);",
  ].join("\n"), "functions.httpsCallable('usada');", {result: []});
  const blocker = report.errors.find((error) =>
    error.code === "used_export_not_deployed");
  const warning = report.warnings.find((item) =>
    item.code === "local_export_not_deployed");

  assert.equal(blocker.functionName, "usada");
  assert.equal(blocker.severity, "blocker");
  assert.deepEqual(blocker.usageKinds, ["callable"]);
  assert.equal(warning.functionName, "naoUsada");
  assert.equal(report.summary.usedLocalNotDeployed, 1);
  assert.equal(report.summary.localNotDeployed, 2);
});

test("snapshot bloqueia endpoint HTTP usado mas nao implantado", () => {
  const url = "https://us-central1-demo.cloudfunctions.net/webhook";
  const report = auditFixture(
      "exports.webhook = onRequest({}, () => null);",
      `final endpoint = '${url}';`,
      {result: []},
  );
  const blocker = report.errors.find((error) =>
    error.code === "used_export_not_deployed");

  assert.equal(blocker.functionName, "webhook");
  assert.deepEqual(blocker.usageKinds, ["http"]);
  assert.equal(report.warnings.some((warning) =>
    warning.code === "local_export_not_deployed"), false);
});

test("preserva trigger implantado e bloqueia incompatibilidade com uso", () => {
  const snapshot = {result: [{
    id: "buscar",
    trigger: {httpsTrigger: {}},
  }]};
  const details = extractDeployedFunctionDetails(snapshot);
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "functions.httpsCallable('buscar');",
      snapshot,
  );
  const mismatch = report.errors.find((error) =>
    error.code === "deployed_trigger_usage_mismatch");

  assert.deepEqual(details, [{
    functionName: "buscar",
    triggerType: "onRequest",
    triggerKind: "http",
    triggerSource: "trigger.httpsTrigger",
  }]);
  assert.equal(mismatch.functionName, "buscar");
  assert.equal(mismatch.expectedType, "onCall");
  assert.equal(mismatch.actualType, "onRequest");
  assert.equal(report.summary.deployedTriggerMismatches, 1);
});

test("compara trigger implantado com export local mesmo sem uso no app", () => {
  const report = auditFixture(
      "exports.webhook = onRequest({}, () => null);",
      "",
      {result: [{id: "webhook", trigger: {callableTrigger: {}}}]},
  );
  const mismatch = report.errors.find((error) =>
    error.code === "deployed_trigger_mismatch");

  assert.equal(mismatch.functionName, "webhook");
  assert.equal(mismatch.expectedType, "onRequest");
  assert.equal(mismatch.actualType, "onCall");
});

test("aceita trigger callable compativel informado no snapshot", () => {
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "FirebaseFunctions.instance.httpsCallable('buscar');",
      {result: [{
        id: "buscar",
        region: "us-central1",
        trigger: {type: "callable"},
      }]},
  );

  assert.equal(report.errors.length, 0);
  assert.equal(report.deployedFunctionDetails[0].triggerType, "onCall");
  assert.equal(report.deployedFunctionDetails[0].triggerKind, "callable");
});

test("snapshot bloqueia funcao implantada ausente localmente", () => {
  const report = auditFixture([
    "exports.compartilhada = onDocumentCreated('a/{id}', () => null);",
    "exports.somenteLocal = onDocumentCreated('b/{id}', () => null);",
  ].join("\n"), "", {
    result: [
      {id: "compartilhada"},
      {name: "projects/demo/locations/us/functions/somenteRemota"},
    ],
  });
  const blocker = report.errors.find((error) =>
    error.code === "deployed_function_missing_locally");
  const localWarning = report.warnings.find((warning) =>
    warning.code === "local_export_not_deployed");

  assert.equal(report.status, "error");
  assert.equal(blocker.functionName, "somenteRemota");
  assert.equal(blocker.severity, "blocker");
  assert.equal(localWarning.functionName, "somenteLocal");
  assert.equal(report.summary.deployedFunctions, 2);
  assert.equal(report.summary.deployedMissingLocally, 1);
  assert.equal(report.summary.localNotDeployed, 1);
});

test("sem snapshot preserva o formato e os criterios locais", () => {
  const report = auditFixture(
      "exports.buscar = onCall({}, () => null);",
      "functions.httpsCallable('buscar');",
  );

  assert.equal(report.status, "ok");
  assert.equal(Object.hasOwn(report, "deployedFunctions"), false);
  assert.equal(Object.hasOwn(report.summary, "deployedFunctions"), false);
});

test("CLI aceita caminho de snapshot nas duas formas", () => {
  assert.deepEqual(parseArguments([
    "--deployed-json",
    "audit/deployed.json",
  ]), {deployedJsonPath: "audit/deployed.json"});
  assert.deepEqual(parseArguments([
    "--deployed-json=audit/deployed.json",
  ]), {deployedJsonPath: "audit/deployed.json"});
  assert.throws(
      () => parseArguments(["--deployed-json"]),
      /exige o caminho/,
  );
});

test("CLI resolve caminho documentado mesmo quando npm altera o cwd", () => {
  const repositoryRoot = path.resolve(__dirname, "..", "..");
  const npmWorkingDirectory = path.join(repositoryRoot, "functions");
  const resolved = resolveDeployedJsonPath(
      "functions/package.json",
      repositoryRoot,
      npmWorkingDirectory,
  );

  assert.equal(
      resolved,
      path.join(repositoryRoot, "functions", "package.json"),
  );
});

test("JSON permanece deterministico independentemente das chaves", () => {
  const first = stableStringify({zeta: 1, alfa: {dois: 2, um: 1}});
  const second = stableStringify({alfa: {um: 1, dois: 2}, zeta: 1});

  assert.equal(first, second);
  assert.equal(first, [
    "{",
    "  \"alfa\": {",
    "    \"dois\": 2,",
    "    \"um\": 1",
    "  },",
    "  \"zeta\": 1",
    "}",
  ].join("\n"));
});
