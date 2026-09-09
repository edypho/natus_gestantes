"use strict";
/* eslint-disable require-jsdoc */

function safeErrorCode(error) {
  const candidate = String(
      error && (error.code || error.name) || "unknown_error",
  ).trim();
  const normalized = candidate
      .replace(/[^a-zA-Z0-9_./-]/g, "_")
      .slice(0, 80);

  return normalized || "unknown_error";
}

function logSafeError(context, error) {
  console.error(String(context || "Falha interna."), {
    code: safeErrorCode(error),
  });
}

module.exports = {
  logSafeError,
  safeErrorCode,
};
