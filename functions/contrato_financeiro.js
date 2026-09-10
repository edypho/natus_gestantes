"use strict";

/**
 * Calcula valores contratuais sem repor descontos como dívida.
 * @param {number} total Total líquido negociado.
 * @param {number} entrada Entrada contratada.
 * @param {number} quantidade Quantidade de parcelas.
 * @return {object} Valores contratuais em centavos.
 */
function calcularFinanceiroContrato(total, entrada, quantidade) {
  if (!Number.isFinite(total) || total < 0 ||
      !Number.isFinite(entrada) || entrada < 0 || entrada > total) {
    throw new Error("Valores financeiros do contrato invalidos.");
  }
  const totalCentavos = Math.round(total * 100);
  const entradaCentavos = Math.round(entrada * 100);
  const saldo = (totalCentavos - entradaCentavos) / 100;
  const parcelas = saldo === 0 ? 0 : Math.max(1, Math.trunc(quantidade) || 1);
  return {
    valorTotal: totalCentavos / 100,
    valorEntrada: entradaCentavos / 100,
    valorSaldo: saldo,
    numeroParcelas: parcelas,
    valorParcela: parcelas ? Math.round(saldo / parcelas * 100) / 100 : 0,
  };
}

module.exports = {calcularFinanceiroContrato};
