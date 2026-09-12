/* eslint-disable require-jsdoc */
"use strict";

function mensagemDeConcorrencia(error) {
  return String(error && error.message || "").startsWith(
      "Os dados foram alterados durante a operação.",
  );
}

function conflitoDeVinculoRetentavel(error) {
  return Boolean(error) &&
    error.code === "failed-precondition" &&
    mensagemDeConcorrencia(error);
}

async function executarComRetentativaDeVinculo(
    operacao,
    {
      esperasMs = [100, 250, 500],
      esperar = (milissegundos) => new Promise(
          (resolve) => setTimeout(resolve, milissegundos),
      ),
      aoRetentar = () => {},
    } = {},
) {
  for (let tentativa = 0; ; tentativa += 1) {
    try {
      return await operacao();
    } catch (error) {
      if (!conflitoDeVinculoRetentavel(error) ||
          tentativa >= esperasMs.length) {
        throw error;
      }

      aoRetentar(tentativa + 2);
      await esperar(esperasMs[tentativa]);
    }
  }
}

module.exports = {
  conflitoDeVinculoRetentavel,
  executarComRetentativaDeVinculo,
};
