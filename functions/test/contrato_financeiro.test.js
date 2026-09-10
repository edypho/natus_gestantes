"use strict";
const assert = require("node:assert/strict");
const test = require("node:test");
const {calcularFinanceiroContrato} = require("../contrato_financeiro");

test("desconto nao retorna como saldo no pagamento a vista", () => {
  assert.deepEqual(calcularFinanceiroContrato(3800, 3800, 1), {
    valorTotal: 3800, valorEntrada: 3800, valorSaldo: 0,
    numeroParcelas: 0, valorParcela: 0,
  });
});
test("parcelamento usa o total negociado", () => {
  assert.equal(calcularFinanceiroContrato(3500, 1000, 5).valorParcela, 500);
});
test("saldo fecha em centavos e rejeita entrada excedente", () => {
  assert.equal(calcularFinanceiroContrato(100.1, 100.1, 7).valorSaldo, 0);
  assert.throws(() => calcularFinanceiroContrato(3800, 4000, 1));
  assert.throws(() => calcularFinanceiroContrato(NaN, 0, 1));
});
