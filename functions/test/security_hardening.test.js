"use strict";
/* eslint-disable require-jsdoc */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  configuredAllowedOrigins,
  DEFAULT_ALLOWED_ORIGINS,
  applyRestrictedCors,
  normalizeAllowedOrigin,
} = require("../security/http_cors");
const {
  PRIVATE_PUSH_BODY,
  PRIVATE_PUSH_TITLE,
  buildPrivateClinicalPush,
} = require("../security/private_push");
const {
  RateLimitExceededError,
  nextRateLimitState,
  rateLimitDocumentId,
} = require("../security/rate_limiter");
const {safeErrorCode} = require("../security/safe_logging");

function responseRecorder() {
  const headers = new Map();
  return {
    headers,
    set(name, value) {
      headers.set(String(name).toLowerCase(), String(value));
    },
  };
}

test("CORS reflete somente origens oficiais explicitamente permitidas", () => {
  const origin = "https://natus-gestantes.web.app";
  const response = responseRecorder();
  const allowed = applyRestrictedCors(
      {headers: {origin}},
      response,
      DEFAULT_ALLOWED_ORIGINS,
  );

  assert.equal(allowed, true);
  assert.equal(response.headers.get("access-control-allow-origin"), origin);
  assert.notEqual(response.headers.get("access-control-allow-origin"), "*");
  assert.equal(response.headers.get("cache-control"), "no-store");
});

test("CORS rejeita origem arbitraria e aceita cliente nativo", () => {
  const rejectedResponse = responseRecorder();
  assert.equal(applyRestrictedCors(
      {headers: {origin: "https://evil.example"}},
      rejectedResponse,
      DEFAULT_ALLOWED_ORIGINS,
  ), false);
  assert.equal(
      rejectedResponse.headers.has("access-control-allow-origin"),
      false,
  );

  const nativeResponse = responseRecorder();
  assert.equal(applyRestrictedCors(
      {headers: {}},
      nativeResponse,
      DEFAULT_ALLOWED_ORIGINS,
  ), true);
});

test("CORS rejeita sufixo enganoso, null e configuracao malformada", () => {
  for (const origin of [
    "https://natus-gestantes.web.app.evil.example",
    "null",
    "*",
    "https://user:pass@natus-gestantes.web.app",
    "https://natus-gestantes.web.app/caminho",
    "https://natus-gestantes.web.app\nX-Injetado: sim",
  ]) {
    const response = responseRecorder();
    assert.equal(applyRestrictedCors(
        {headers: {origin}},
        response,
        DEFAULT_ALLOWED_ORIGINS,
    ), false);
    assert.equal(response.headers.has("access-control-allow-origin"), false);
  }

  const configured = configuredAllowedOrigins({
    NATUS_ALLOWED_WEB_ORIGINS: [
      "https://app.natus.example",
      "http://app.natus.example",
      "*",
      "https://app.natus.example/path",
    ].join(","),
  });
  assert.equal(configured.has("https://app.natus.example"), true);
  assert.equal(configured.has("http://app.natus.example"), false);
  assert.equal(configured.has("*"), false);
  assert.equal(normalizeAllowedOrigin("http://localhost:5000"),
      "http://localhost:5000");
});

test("push clinico nao carrega dados de paciente ou atendimento", () => {
  const payload = buildPrivateClinicalPush("notificacao_123");
  const serialized = JSON.stringify(payload);

  assert.equal(payload.title, PRIVATE_PUSH_TITLE);
  assert.equal(payload.body, PRIVATE_PUSH_BODY);
  assert.deepEqual(payload.data, {
    tipo: "atualizacao_clinica",
    tag: "atualizacao_clinica",
    notificacaoId: "notificacao_123",
  });
  for (const forbidden of [
    "gestante",
    "paciente",
    "intensidade",
    "duracao",
    "clinicaId",
    "contracaoId",
  ]) {
    assert.equal(serialized.includes(forbidden), false);
  }
});

test("rate limiter incrementa, reinicia janela e bloqueia excesso", () => {
  const first = nextRateLimitState({
    current: null,
    nowMillis: 1000,
    limit: 2,
    windowMillis: 60000,
  });
  assert.equal(first.count, 1);
  assert.equal(first.windowStartedAtMillis, 1000);

  const second = nextRateLimitState({
    current: first,
    nowMillis: 2000,
    limit: 2,
    windowMillis: 60000,
  });
  assert.equal(second.count, 2);

  assert.throws(() => nextRateLimitState({
    current: second,
    nowMillis: 3000,
    limit: 2,
    windowMillis: 60000,
  }), RateLimitExceededError);

  const reset = nextRateLimitState({
    current: second,
    nowMillis: 62000,
    limit: 2,
    windowMillis: 60000,
  });
  assert.equal(reset.count, 1);
  assert.equal(reset.windowStartedAtMillis, 62000);
});

test("chave do rate limiter e deterministica e nao expoe o sujeito", () => {
  const subject = "actor:uid-pessoal-123";
  const first = rateLimitDocumentId("geocoding", subject);
  const second = rateLimitDocumentId("geocoding", subject);

  assert.equal(first, second);
  assert.match(first, /^[a-f0-9]{64}$/);
  assert.equal(first.includes("uid-pessoal"), false);
  assert.throws(
      () => rateLimitDocumentId("a".repeat(81), subject),
      /safe length/,
  );
  assert.throws(
      () => rateLimitDocumentId("geocoding", "x".repeat(513)),
      /safe length/,
  );
});

test("codigo de erro seguro remove texto e caracteres de injecao", () => {
  assert.equal(
      safeErrorCode({code: "auth/user-not-found\nemail@example.com"}),
      "auth/user-not-found_email_example.com",
  );
  assert.equal(safeErrorCode(new Error("segredo")), "Error");
});

test("fonte nao reintroduz CORS aberto nem log de e-mail da paciente", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "index.js"),
      "utf8",
  );

  assert.equal(source.includes("Access-Control-Allow-Origin\", \"*\""), false);
  assert.equal(
      source.includes("criada com sucesso:\", email"),
      false,
  );

  const callableOptions = Array.from(source.matchAll(
      /exports\.[A-Za-z0-9_]+\s*=\s*onCall\(\s*\{([\s\S]*?)\}\s*,/g,
  ));
  assert.equal(callableOptions.length, 10);
  for (const callable of callableOptions) {
    assert.match(callable[1], /\benforceAppCheck\s*,/);
  }
});
