"use strict";

const fs = require("node:fs");
const path = require("node:path");

const PRODUCTION_PROJECT_ID = "natus-gestantes";
const MAX_REPORT_AGE_MS = 24 * 60 * 60 * 1000;

/**
 * Localiza o relatório de produção mais recente sem alterar qualquer dado.
 * @param {string} reportsRoot Diretório dos relatórios.
 * @param {string} projectId Projeto Firebase esperado.
 * @return {{path: string, report: Object}|null}
 */
function findLatestReport(reportsRoot, projectId) {
  if (!fs.existsSync(reportsRoot)) return null;

  const candidates = fs.readdirSync(reportsRoot, {withFileTypes: true})
      .filter((entry) => entry.isDirectory())
      .filter((entry) => entry.name.startsWith(`${projectId}_`))
      .sort((a, b) => b.name.localeCompare(a.name));

  for (const candidate of candidates) {
    const reportPath = path.join(reportsRoot, candidate.name, "report.json");
    if (!fs.existsSync(reportPath)) continue;

    const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
    if (report && report.source && report.source.projectId === projectId) {
      return {path: reportPath, report};
    }
  }

  return null;
}

/**
 * Valida os gates que tornam seguro publicar o cliente multi-tenant.
 * @param {Object} report Relatório da auditoria read-only.
 * @param {string} projectId Projeto Firebase esperado.
 * @param {number=} now Momento atual para testes determinísticos.
 * @return {{ready: boolean, errors: string[]}}
 */
function assessReport(report, projectId, now = Date.now()) {
  const errors = [];
  const source = report && report.source ? report.source : {};
  const summary = report && report.summary ? report.summary : {};
  const generatedAt = Date.parse(report && report.generatedAt || "");

  if (source.projectId !== projectId) {
    errors.push("o relatório pertence a outro projeto");
  }
  if (source.mode !== "cloud") {
    errors.push("a auditoria não foi executada em cloud");
  }
  if (source.authIncluded !== true) {
    errors.push("a auditoria do Firebase Auth não foi incluída");
  }
  if (!report || report.complete !== true) {
    errors.push("a varredura não foi concluída");
  }
  if (summary.releaseReady !== true) {
    errors.push("releaseReady não está verde");
  }
  if (!Number.isFinite(generatedAt)) {
    errors.push("a data do relatório é inválida");
  } else if (now - generatedAt > MAX_REPORT_AGE_MS) {
    errors.push("o relatório tem mais de 24 horas");
  } else if (generatedAt > now + 5 * 60 * 1000) {
    errors.push("a data do relatório está no futuro");
  }

  return {ready: errors.length === 0, errors};
}

/**
 * Bloqueia apenas o deploy do projeto de produção.
 * @param {Object=} options Dependências substituíveis em testes.
 * @return {number} Código de saída.
 */
function main(options = {}) {
  const env = options.env || process.env;
  const now = options.now === undefined ? Date.now() : options.now;
  const projectId = env.GCLOUD_PROJECT ||
    env.FIREBASE_PROJECT ||
    PRODUCTION_PROJECT_ID;

  if (projectId !== PRODUCTION_PROJECT_ID) return 0;

  const reportsRoot = options.reportsRoot || path.resolve(
      __dirname,
      "..",
      "audit-reports",
  );
  const latest = findLatestReport(reportsRoot, projectId);

  if (!latest) {
    console.error(
        "Deploy bloqueado: não há auditoria cloud de produção disponível.",
    );
    return 1;
  }

  const assessment = assessReport(latest.report, projectId, now);
  if (!assessment.ready) {
    console.error("Deploy bloqueado pela auditoria multi-tenant:");
    for (const error of assessment.errors) console.error(`- ${error}`);
    console.error(`Relatório: ${latest.path}`);
    return 1;
  }

  console.log("Auditoria multi-tenant aprovada para o deploy solicitado.");
  return 0;
}

if (require.main === module) {
  process.exitCode = main();
}

module.exports = {
  MAX_REPORT_AGE_MS,
  PRODUCTION_PROJECT_ID,
  assessReport,
  findLatestReport,
  main,
};
