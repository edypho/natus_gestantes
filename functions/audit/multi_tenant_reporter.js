/* eslint-disable require-jsdoc */
"use strict";

const crypto = require("node:crypto");

const {
  CANONICAL_CLINIC_COLLECTIONS,
  CANONICAL_PATIENT_COLLECTIONS,
  GLOBAL_ROOT_COLLECTIONS,
  ROOT_COLLECTIONS,
} = require("./multi_tenant_manifest");

const SAFE_COLLECTION_NAMES = new Set([
  ...ROOT_COLLECTIONS.map((definition) => definition.name),
  ...GLOBAL_ROOT_COLLECTIONS,
  ...CANONICAL_CLINIC_COLLECTIONS,
  ...CANONICAL_PATIENT_COLLECTIONS,
  "__audit__",
  "__canonical__",
  "__legacy__",
  "__manifest__",
  "firebaseAuth",
]);

const SENSITIVE_DETAIL_KEY = new RegExp(
    "path|tenant|clinica|patient|paciente|document|uid|" +
    "\\bid\\b|status|role|tipo|value|e-?mail|nome|name|cpf|cnpj|" +
    "telefone|phone|celular|endereco|address|logradouro|cep|" +
    "nascimento|birth|token|secret|payload",
    "i",
);
const SENSITIVE_DETAIL_VALUE = new RegExp(
    "(?:[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@" +
    "[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?" +
    "(?:\\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+)|" +
    "(?:\\b\\d{3}\\.?\\d{3}\\.?\\d{3}-?\\d{2}\\b)",
    "i",
);

function fingerprint(value) {
  if (!value) return "";
  return `sha256:${crypto.createHash("sha256")
      .update(String(value))
      .digest("hex")
      .slice(0, 16)}`;
}

function redactIdentifierValue(value) {
  if (Array.isArray(value)) return value.map(redactIdentifierValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, nested]) => [
      key,
      redactIdentifierValue(nested),
    ]));
  }
  if (typeof value === "string") return fingerprint(value);
  return value;
}

function redactSensitiveDetails(value, key) {
  if (Array.isArray(value)) {
    if (/fields?$/i.test(key || "")) return value;
    return value.map((item) => redactSensitiveDetails(item, key));
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(
        Object.entries(value).map(([nestedKey, nested]) => [
          nestedKey,
          redactSensitiveDetails(nested, nestedKey),
        ]),
    );
  }
  if (typeof value === "string" &&
      (SENSITIVE_DETAIL_KEY.test(key || "") ||
       SENSITIVE_DETAIL_VALUE.test(value))) {
    return fingerprint(value);
  }
  return value;
}

function sanitizeCollectionName(value) {
  const name = String(value || "");
  if (!name || SAFE_COLLECTION_NAMES.has(name)) return name;
  return fingerprint(name);
}

function sanitizeReport(report, options) {
  const includeIdentifiers = Boolean(options && options.includeIdentifiers);
  if (includeIdentifiers) return JSON.parse(JSON.stringify(report));

  return {
    ...report,
    findings: report.findings.map((finding) => ({
      ...finding,
      location: {
        ...finding.location,
        collection: sanitizeCollectionName(finding.location.collection),
        path: fingerprint(finding.location.path),
      },
      identifiers: redactIdentifierValue(finding.identifiers),
      details: redactSensitiveDetails(finding.details, "details"),
    })),
  };
}

function csvCell(value) {
  const text = value === undefined || value === null ? "" : String(value);
  const safeText = /^\s*[=+\-@]/u.test(text) ? `'${text}` : text;
  return `"${safeText.replace(/"/g, "\"\"")}"`;
}

function findingsToCsv(report) {
  const headers = [
    "severity",
    "blocker",
    "code",
    "collection",
    "document",
    "message",
    "identifiers",
    "details",
  ];
  const rows = [headers.map(csvCell).join(",")];

  for (const finding of report.findings) {
    rows.push([
      finding.severity,
      finding.blocker,
      finding.code,
      finding.location.collection,
      finding.location.path,
      finding.message,
      JSON.stringify(finding.identifiers),
      JSON.stringify(finding.details),
    ].map(csvCell).join(","));
  }

  return `${rows.join("\n")}\n`;
}

function findingsToJsonLines(report) {
  if (report.findings.length === 0) return "";
  return `${report.findings.map((finding) => JSON.stringify(finding))
      .join("\n")}\n`;
}

module.exports = {
  findingsToCsv,
  findingsToJsonLines,
  fingerprint,
  sanitizeReport,
};
