"use strict";
/* eslint-disable require-jsdoc */

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  canonicalUploadMetadataValid,
  canonicalUploadShouldBeInspected,
  uploadContentMatchesMime,
  validateCanonicalUpload,
} = require("../security/upload_content_validator");

test("validador reconhece assinaturas aceitas e rejeita MIME forjado", () => {
  assert.equal(uploadContentMatchesMime(
      Buffer.from("%PDF-1.7"),
      "application/pdf",
  ), true);
  assert.equal(uploadContentMatchesMime(
      Buffer.from("MZ executable"),
      "application/pdf",
  ), false);
  assert.equal(uploadContentMatchesMime(
      Buffer.from("<svg onload=alert(1) />"),
      "image/svg+xml",
  ), false);
  assert.equal(uploadContentMatchesMime(
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      "image/png",
  ), true);
  assert.equal(uploadContentMatchesMime(
      Buffer.from([0, 0, 0, 24, ...Buffer.from("ftypheic")]),
      "image/heic",
  ), true);
  assert.equal(uploadContentMatchesMime(
      Buffer.from([0, 0, 0, 24, ...Buffer.from("ftypheic")]),
      "video/mp4",
  ), false);
});

test("inspeciona somente objetos da hierarquia canonica", () => {
  assert.equal(canonicalUploadShouldBeInspected({
    name: "clinicas/clinic-a/biblioteca/material.pdf",
    size: "100",
  }), true);
  assert.equal(canonicalUploadShouldBeInspected({
    name: "biblioteca/legado.pdf",
    size: "100",
  }), false);
  assert.equal(canonicalUploadShouldBeInspected({
    name: "clinicas/clinic-a/vazio.pdf",
    size: "0",
  }), true);
});

test("metadados canonicos vinculam tenant, paciente, autor e tamanho", () => {
  const valid = {
    name: "clinicas/clinic-a/pacientes/patient-a/documentos/record.pdf",
    size: "100",
    contentType: "application/pdf",
    metadata: {
      clinicaId: "clinic-a",
      adminDonoId: "clinic-a",
      pacienteId: "patient-a",
      enviadoPorUid: "user-a",
    },
  };
  assert.equal(canonicalUploadMetadataValid(valid), true);
  assert.equal(canonicalUploadMetadataValid({
    ...valid,
    metadata: {...valid.metadata, clinicaId: "clinic-b"},
  }), false);
  assert.equal(canonicalUploadMetadataValid({...valid, size: "0"}), false);
  const receipt = {
    ...valid,
    name: "clinicas/clinic-a/financeiro/pacientes/patient-a/" +
      "comprovantes/receipt.heic",
    contentType: "image/heic",
  };
  assert.equal(canonicalUploadMetadataValid(receipt), true);
  assert.equal(canonicalUploadMetadataValid({
    ...receipt,
    metadata: {...receipt.metadata, pacienteId: "patient-b"},
  }), false);
});

test("remove geracao invalida sem expor nome ou conteudo", async () => {
  const calls = [];
  const file = {
    async download(options) {
      calls.push(["download", options]);
      return [Buffer.from("MZ executable")];
    },
    async delete(options) {
      calls.push(["delete", options]);
    },
  };
  const storage = {
    bucket(bucketName) {
      calls.push(["bucket", bucketName]);
      return {
        file(fileName) {
          calls.push(["file", fileName]);
          return file;
        },
      };
    },
  };

  const result = await validateCanonicalUpload({
    objectData: {
      bucket: "demo.appspot.com",
      name: "clinicas/clinic-a/documentos/forged.pdf",
      size: "12",
      generation: "42",
      contentType: "application/pdf",
      metadata: {
        clinicaId: "clinic-a",
        adminDonoId: "clinic-a",
        enviadoPorUid: "user-a",
      },
    },
    storage,
  });

  assert.deepEqual(result, {inspected: true, deleted: true});
  assert.deepEqual(calls.at(-1), ["delete", {
    ifGenerationMatch: 42,
    ignoreNotFound: true,
  }]);
});
