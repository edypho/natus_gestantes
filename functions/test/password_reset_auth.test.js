"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  AuthTokenValidationError,
  extrairTokenBearer,
  verificarIdTokenNaoRevogado,
} = require("../password_reset_auth");

test("extrai somente token Bearer bem formado", () => {
  assert.equal(extrairTokenBearer("Bearer token-valido"), "token-valido");
  assert.equal(extrairTokenBearer(["Bearer primeiro", "Bearer segundo"]),
      "primeiro");
  assert.equal(extrairTokenBearer("Basic credencial"), "");
  assert.equal(extrairTokenBearer("Bearer token com espaco"), "");
  assert.equal(extrairTokenBearer(undefined), "");
});

test(
    "valida o ID token com checkRevoked explicitamente habilitado",
    async () => {
      const chamadas = [];
      const firebaseAuth = {
        async verifyIdToken(token, checkRevoked) {
          chamadas.push({token, checkRevoked});
          return {uid: "usuario-1", admin: true};
        },
      };

      const resultado = await verificarIdTokenNaoRevogado(
          firebaseAuth,
          "Bearer jwt-assinado",
          "usuario-1",
      );

      assert.equal(resultado.uid, "usuario-1");
      assert.deepEqual(chamadas, [{
        token: "jwt-assinado",
        checkRevoked: true,
      }]);
    },
);

test("rejeita token revogado sem propagar detalhes internos", async () => {
  const firebaseAuth = {
    async verifyIdToken() {
      const error = new Error("detalhe sensivel");
      error.code = "auth/id-token-revoked";
      throw error;
    },
  };

  await assert.rejects(
      verificarIdTokenNaoRevogado(firebaseAuth, "Bearer revogado"),
      (error) => {
        assert.ok(error instanceof AuthTokenValidationError);
        assert.equal(error.code, "unauthenticated");
        assert.match(error.message, /invalido ou revogado/);
        assert.doesNotMatch(error.message, /detalhe sensivel/);
        return true;
      },
  );
});

test("rejeita token ausente e UID divergente", async () => {
  let verificacoes = 0;
  const firebaseAuth = {
    async verifyIdToken() {
      verificacoes += 1;
      return {uid: "usuario-diferente"};
    },
  };

  await assert.rejects(
      verificarIdTokenNaoRevogado(firebaseAuth, ""),
      {code: "unauthenticated"},
  );
  assert.equal(verificacoes, 0);

  await assert.rejects(
      verificarIdTokenNaoRevogado(
          firebaseAuth,
          "Bearer token-valido",
          "usuario-esperado",
      ),
      {code: "unauthenticated"},
  );
  assert.equal(verificacoes, 1);
});

test("callable regional e HTTP legado compartilham o mesmo nucleo", () => {
  const functionsRoot = path.resolve(__dirname, "..");
  const projectRoot = path.resolve(functionsRoot, "..");
  const backend = fs.readFileSync(
      path.join(functionsRoot, "index.js"),
      "utf8",
  );
  const flutter = fs.readFileSync(
      path.join(projectRoot, "lib", "main.dart"),
      "utf8",
  );

  assert.match(
      backend,
      /exports\.reenviarLinkTrocaSenhaGestante\s*=\s*onRequest\(/,
  );
  assert.match(
      backend,
      new RegExp(
          "exports\\.solicitarRedefinicaoSenhaPaciente\\s*=\\s*" +
          "onCall\\([\\s\\S]*?region:\\s*\"us-central1\"",
      ),
  );
  assert.equal(
      (backend.match(/solicitarRedefinicaoSenhaPacienteCore\(/g) || []).length,
      3,
  );
  assert.match(
      flutter,
      new RegExp(
          "FirebaseFunctions\\.instanceFor\\([\\s\\S]*?" +
          "region:\\s*'us-central1'[\\s\\S]*?\\.httpsCallable" +
          "\\('solicitarRedefinicaoSenhaPaciente'\\)",
      ),
  );
  assert.doesNotMatch(
      flutter,
      /reenviarlinktrocasenhagestante-[a-z0-9-]+\.a\.run\.app/i,
  );
});
