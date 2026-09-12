/* eslint-disable require-jsdoc */
"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  conflitoDeVinculoRetentavel,
  executarComRetentativaDeVinculo,
} = require("../access_link_retry");

function conflitoConcorrente() {
  const error = new Error(
      "Os dados foram alterados durante a operação. Revise e tente novamente.",
  );
  error.code = "failed-precondition";
  return error;
}

test(
    "repete o vínculo após conflito transitório e respeita as esperas",
    async () => {
      let chamadas = 0;
      const esperas = [];
      const tentativas = [];

      const resultado = await executarComRetentativaDeVinculo(
          async () => {
            chamadas += 1;
            if (chamadas < 3) throw conflitoConcorrente();
            return "vinculado";
          },
          {
            esperasMs: [10, 20, 30],
            esperar: async (ms) => esperas.push(ms),
            aoRetentar: (tentativa) => tentativas.push(tentativa),
          },
      );

      assert.equal(resultado, "vinculado");
      assert.equal(chamadas, 3);
      assert.deepEqual(esperas, [10, 20]);
      assert.deepEqual(tentativas, [2, 3]);
    },
);

test("não repete conflito permanente nem excede o limite", async () => {
  const permanente = Object.assign(new Error("Outro conflito."), {
    code: "failed-precondition",
  });
  assert.equal(conflitoDeVinculoRetentavel(permanente), false);

  let chamadasPermanentes = 0;
  await assert.rejects(
      executarComRetentativaDeVinculo(async () => {
        chamadasPermanentes += 1;
        throw permanente;
      }),
      (error) => error === permanente,
  );
  assert.equal(chamadasPermanentes, 1);

  let chamadasTransitorias = 0;
  await assert.rejects(
      executarComRetentativaDeVinculo(
          async () => {
            chamadasTransitorias += 1;
            throw conflitoConcorrente();
          },
          {esperasMs: [0], esperar: async () => {}},
      ),
      (error) => conflitoDeVinculoRetentavel(error),
  );
  assert.equal(chamadasTransitorias, 2);
});
