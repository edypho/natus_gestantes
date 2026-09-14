"use strict";
/* eslint-disable require-jsdoc */

const DEFAULT_ALLOWED_ORIGINS = new Set([
  "https://natus-gestantes.web.app",
  "https://natus-gestantes.firebaseapp.com",
]);

function normalizeAllowedOrigin(value) {
  const origin = String(value || "").trim();
  if (!origin || origin === "null" || origin === "*" ||
      Array.from(origin).some((character) => {
        const code = character.charCodeAt(0);
        return code <= 31 || code === 127;
      })) {
    return null;
  }

  let url;
  try {
    url = new URL(origin);
  } catch (_) {
    return null;
  }

  const localDevelopment = url.protocol === "http:" &&
    ["127.0.0.1", "localhost", "::1"].includes(url.hostname);
  if ((url.protocol !== "https:" && !localDevelopment) ||
      url.username || url.password ||
      url.pathname !== "/" || url.search || url.hash) {
    return null;
  }

  return url.origin;
}

function configuredAllowedOrigins(environment = process.env) {
  const configured = String(
      environment.NATUS_ALLOWED_WEB_ORIGINS || "",
  ).split(",");
  const origins = new Set(DEFAULT_ALLOWED_ORIGINS);

  for (const rawOrigin of configured) {
    const origin = normalizeAllowedOrigin(rawOrigin);
    if (origin) origins.add(origin);
  }

  return origins;
}

function applyRestrictedCors(req, res, allowedOrigins = null) {
  const origins = allowedOrigins || configuredAllowedOrigins();
  const origin = String(req && req.headers && req.headers.origin || "").trim();

  res.set("Vary", "Origin");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Max-Age", "600");
  res.set("Cache-Control", "no-store");
  res.set("X-Content-Type-Options", "nosniff");

  // Apps nativos e chamadas servidor-servidor normalmente não enviam Origin.
  if (!origin) return true;
  const normalizedOrigin = normalizeAllowedOrigin(origin);
  if (!normalizedOrigin || normalizedOrigin !== origin ||
      !origins.has(normalizedOrigin)) return false;

  res.set("Access-Control-Allow-Origin", normalizedOrigin);
  return true;
}

module.exports = {
  DEFAULT_ALLOWED_ORIGINS,
  applyRestrictedCors,
  configuredAllowedOrigins,
  normalizeAllowedOrigin,
};
