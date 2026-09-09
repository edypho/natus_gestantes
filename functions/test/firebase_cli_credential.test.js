"use strict";
/* eslint-disable require-jsdoc */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {
  activateFirebaseCliApplicationDefault,
  firebaseCredentialFileName,
} = require("../scripts/firebase_cli_credential");

function fixture() {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "natus-cli-auth-"));
  const directory = path.join(home, ".config", "configstore");
  const appData = path.join(home, "appdata");
  fs.mkdirSync(directory, {recursive: true});
  fs.writeFileSync(path.join(directory, "firebase-tools.json"), JSON.stringify({
    user: {email: "operador@example.com"},
    tokens: {refresh_token: "refresh-atual-do-cli"},
  }));
  const credentialDirectory = path.join(appData, "firebase");
  fs.mkdirSync(credentialDirectory, {recursive: true});
  const credentialPath = path.join(
      credentialDirectory,
      firebaseCredentialFileName("operador@example.com"),
  );
  fs.writeFileSync(credentialPath, JSON.stringify({
    client_id: "cliente-teste",
    client_secret: "segredo-publico-teste",
    refresh_token: "refresh-apenas-para-teste",
    type: "authorized_user",
  }));
  return {appData, credentialPath, home};
}

test("credencial do CLI exige conta exata", () => {
  const {appData, credentialPath, home} = fixture();
  const environment = {APPDATA: appData};
  try {
    const activated = activateFirebaseCliApplicationDefault({
      confirmAccount: "operador@example.com",
      environment,
      home,
    });
    assert.equal(activated, credentialPath);
    assert.equal(environment.GOOGLE_APPLICATION_CREDENTIALS, credentialPath);
    const synchronized = JSON.parse(fs.readFileSync(credentialPath, "utf8"));
    assert.equal(synchronized.refresh_token, "refresh-atual-do-cli");
    assert.throws(() => activateFirebaseCliApplicationDefault({
      confirmAccount: "outra@example.com",
      environment,
      home,
    }), /difere/);
  } finally {
    fs.rmSync(home, {recursive: true, force: true});
  }
});

test("credencial do CLI rejeita ADC incompleta", () => {
  const {appData, credentialPath, home} = fixture();
  try {
    fs.writeFileSync(credentialPath, JSON.stringify({type: "authorized_user"}));
    assert.throws(() => activateFirebaseCliApplicationDefault({
      confirmAccount: "operador@example.com",
      environment: {APPDATA: appData},
      home,
    }), /inválida/);
  } finally {
    fs.rmSync(home, {recursive: true, force: true});
  }
});
