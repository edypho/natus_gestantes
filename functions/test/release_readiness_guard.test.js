"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  MAX_REPORT_AGE_MS,
  assessReport,
  main,
} = require("../scripts/verify_hosting_release_readiness");

const projectId = "natus-gestantes";
const now = Date.parse("2026-08-10T18:00:00.000Z");

/**
 * Cria um relatório verde para variar apenas o cenário sob teste.
 * @param {Object=} overrides Campos sobrescritos no relatório.
 * @return {Object} Relatório sintético.
 */
function validReport(overrides = {}) {
  return {
    generatedAt: new Date(now - 60000).toISOString(),
    source: {
      projectId,
      mode: "cloud",
      authIncluded: true,
    },
    complete: true,
    summary: {releaseReady: true},
    ...overrides,
  };
}

test("aceita somente auditoria cloud completa, recente e verde", () => {
  assert.deepEqual(assessReport(validReport(), projectId, now), {
    ready: true,
    errors: [],
  });
});

test("bloqueia relatório com cutover multi-tenant ainda inseguro", () => {
  const result = assessReport(
      validReport({summary: {releaseReady: false}}),
      projectId,
      now,
  );

  assert.equal(result.ready, false);
  assert.match(result.errors.join(" "), /releaseReady/);
});

test("bloqueia relatório antigo mesmo que tenha ficado verde", () => {
  const result = assessReport(
      validReport({
        generatedAt: new Date(now - MAX_REPORT_AGE_MS - 1).toISOString(),
      }),
      projectId,
      now,
  );

  assert.equal(result.ready, false);
  assert.match(result.errors.join(" "), /24 horas/);
});

test("não bloqueia projeto de homologação", () => {
  const exitCode = main({
    env: {GCLOUD_PROJECT: "demo-natus"},
    reportsRoot: "diretorio-inexistente",
    now,
  });

  assert.equal(exitCode, 0);
});
