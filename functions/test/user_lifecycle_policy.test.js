"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  avaliarTransicaoPerfil,
} = require("../user_lifecycle_policy");

test("permite no-op independentemente do vinculo", () => {
  assert.equal(avaliarTransicaoPerfil({
    perfilAtual: "gestante",
    novoPerfil: "gestante",
    possuiVinculo: true,
  }).permitida, true);
});

test("rejeita qualquer transicao entre paciente e equipe", () => {
  for (const [perfilAtual, novoPerfil] of [
    ["gestante", "enfermeira"],
    ["obstetra", "gestante"],
    ["gestante", "admin"],
    ["admin", "gestante"],
  ]) {
    assert.equal(avaliarTransicaoPerfil({
      perfilAtual,
      novoPerfil,
      possuiVinculo: true,
    }).permitida, false);
  }
});

test("rejeita transicao entre profissionais quando existe entidade", () => {
  assert.equal(avaliarTransicaoPerfil({
    perfilAtual: "enfermeira",
    novoPerfil: "obstetra",
    possuiVinculo: true,
  }).permitida, false);
});

test("permite transicao de equipe sem entidade comprovada", () => {
  assert.equal(avaliarTransicaoPerfil({
    perfilAtual: "enfermeira",
    novoPerfil: "obstetra",
    possuiVinculo: false,
  }).permitida, true);
  assert.equal(avaliarTransicaoPerfil({
    perfilAtual: "obstetra",
    novoPerfil: "admin",
    possuiVinculo: false,
  }).permitida, true);
});

test("admin nao vira equipe sem escolher uma entidade", () => {
  assert.equal(avaliarTransicaoPerfil({
    perfilAtual: "admin",
    novoPerfil: "enfermeira",
    possuiVinculo: false,
  }).permitida, false);
});
