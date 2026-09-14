"use strict";
/* eslint-disable require-jsdoc */

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

function candidateConfigPaths(environment = process.env, home = os.homedir()) {
  const candidates = [];
  if (environment.NATUS_FIREBASE_CLI_CONFIG) {
    candidates.push(path.resolve(environment.NATUS_FIREBASE_CLI_CONFIG));
  }
  if (environment.XDG_CONFIG_HOME) {
    candidates.push(path.join(
        environment.XDG_CONFIG_HOME,
        "configstore",
        "firebase-tools.json",
    ));
  }
  candidates.push(path.join(
      home,
      ".config",
      "configstore",
      "firebase-tools.json",
  ));
  if (environment.APPDATA) {
    candidates.push(path.join(
        environment.APPDATA,
        "configstore",
        "firebase-tools.json",
    ));
  }
  return [...new Set(candidates)];
}

function firebaseCredentialFileName(email) {
  return `${email.replace("@", "_").replace(".", "_")}` +
    "_application_default_credentials.json";
}

function activateFirebaseCliApplicationDefault({
  confirmAccount,
  environment = process.env,
  home = os.homedir(),
} = {}) {
  const expectedAccount = String(confirmAccount || "").trim().toLowerCase();
  if (!expectedAccount) {
    throw new Error("--firebase-cli-login exige --confirm-account.");
  }
  const configPath = candidateConfigPaths(environment, home)
      .find((candidate) => fs.existsSync(candidate));
  if (!configPath) {
    throw new Error("Sessão do Firebase CLI não encontrada.");
  }

  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const actualAccount = String(config.user && config.user.email || "")
      .trim()
      .toLowerCase();
  if (actualAccount !== expectedAccount) {
    throw new Error("A conta do Firebase CLI difere de --confirm-account.");
  }
  const appData = String(environment.APPDATA || "").trim();
  if (!appData) {
    throw new Error("APPDATA não está disponível para localizar a credencial.");
  }
  const credentialPath = path.join(
      appData,
      "firebase",
      firebaseCredentialFileName(actualAccount),
  );
  if (!fs.existsSync(credentialPath)) {
    throw new Error(
        "Credencial de aplicação do Firebase CLI não encontrada; execute um " +
        "Emulator autenticado ou configure Application Default Credentials.",
    );
  }
  const credential = JSON.parse(fs.readFileSync(credentialPath, "utf8"));
  if (credential.type !== "authorized_user" ||
      !String(credential.client_id || "") ||
      !String(credential.client_secret || "") ||
      !String(credential.refresh_token || "")) {
    throw new Error("A credencial de aplicação do Firebase CLI é inválida.");
  }
  const cliRefreshToken = String(
      config.tokens && config.tokens.refresh_token || "",
  );
  if (!cliRefreshToken) {
    throw new Error("A sessão do Firebase CLI não possui refresh token.");
  }
  if (credential.refresh_token !== cliRefreshToken) {
    credential.refresh_token = cliRefreshToken;
    fs.writeFileSync(
        credentialPath,
        `${JSON.stringify(credential, null, 2)}\n`,
        {encoding: "utf8", mode: 0o600},
    );
  }
  environment.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
  return credentialPath;
}

module.exports = {
  activateFirebaseCliApplicationDefault,
  candidateConfigPaths,
  firebaseCredentialFileName,
};
