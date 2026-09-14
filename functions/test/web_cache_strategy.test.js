"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repositoryRoot = path.resolve(__dirname, "..", "..");

test("web bootstrap omits Flutter's deprecated cache worker", () => {
  const bootstrap = fs.readFileSync(
      path.join(repositoryRoot, "web", "flutter_bootstrap.js"),
      "utf8",
  );

  assert.match(bootstrap, /_flutter\.loader\.load\(\);/);
  assert.doesNotMatch(bootstrap, /serviceWorkerSettings/);
  assert.doesNotMatch(bootstrap, /flutter_service_worker/);
});

test("hosting revalidates bundles and preserves messaging worker", () => {
  const firebase = JSON.parse(fs.readFileSync(
      path.join(repositoryRoot, "firebase.json"),
      "utf8",
  ));
  const headers = new Map(firebase.hosting.headers.map((rule) => [
    rule.source,
    Object.fromEntries(rule.headers.map((header) => [
      header.key.toLowerCase(),
      header.value,
    ])),
  ]));

  assert.equal(
      headers.get("/main.dart.js")["cache-control"],
      "no-cache, must-revalidate",
  );
  assert.equal(
      headers.get("/flutter_bootstrap.js")["cache-control"],
      "no-cache, must-revalidate",
  );
  assert.equal(
      headers.get("/firebase-messaging-sw.js")["cache-control"],
      "no-cache, no-store, must-revalidate",
  );
  assert.equal(
      headers.get("/flutter_service_worker.js")["cache-control"],
      "no-cache, no-store, must-revalidate",
  );
});
