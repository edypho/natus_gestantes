"use strict";
/* eslint-disable require-jsdoc */

const CANONICAL_UPLOAD_PREFIX = "clinicas/";
const INSPECTION_BYTES = 16;
const MEBIBYTE = 1024 * 1024;

function startsWithBytes(bytes, signature) {
  if (!Buffer.isBuffer(bytes) || bytes.length < signature.length) return false;
  return signature.every((value, index) => bytes[index] === value);
}

function asciiAt(bytes, offset, length) {
  if (!Buffer.isBuffer(bytes) || bytes.length < offset + length) return "";
  return bytes.subarray(offset, offset + length).toString("ascii");
}

function uploadContentMatchesMime(bytes, contentType) {
  switch (String(contentType || "").toLowerCase()) {
    case "application/pdf":
      return startsWithBytes(bytes, [0x25, 0x50, 0x44, 0x46, 0x2d]);
    case "image/jpeg":
      return startsWithBytes(bytes, [0xff, 0xd8, 0xff]);
    case "image/png":
      return startsWithBytes(bytes, [
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
      ]);
    case "image/webp":
      return asciiAt(bytes, 0, 4) === "RIFF" &&
        asciiAt(bytes, 8, 4) === "WEBP";
    case "video/mp4":
      return asciiAt(bytes, 4, 4) === "ftyp";
    default:
      return false;
  }
}

function canonicalUploadShouldBeInspected(objectData) {
  const name = String(objectData && objectData.name || "");
  return name.startsWith(CANONICAL_UPLOAD_PREFIX) &&
    name.length > CANONICAL_UPLOAD_PREFIX.length;
}

function canonicalUploadMetadataValid(objectData) {
  const parts = String(objectData && objectData.name || "").split("/");
  const metadata = objectData && objectData.metadata || {};
  const tenantId = parts[1] || "";
  const uploaderUid = String(metadata.enviadoPorUid || "");
  const size = Number(objectData && objectData.size);
  const contentType = String(objectData && objectData.contentType || "")
      .toLowerCase();
  const profileUpload = parts[2] === "usuarios" && parts[4] === "perfil";
  const sizeLimit = profileUpload ? 10 * MEBIBYTE :
    (contentType === "video/mp4" ? 250 * MEBIBYTE : 25 * MEBIBYTE);

  if (!tenantId || tenantId.length > 1500 ||
      String(metadata.clinicaId || "") !== tenantId ||
      String(metadata.adminDonoId || "") !== tenantId ||
      !uploaderUid || uploaderUid.length > 128 ||
      !Number.isSafeInteger(size) || size <= 0 || size >= sizeLimit) {
    return false;
  }

  if (parts[2] === "pacientes") {
    const patientId = parts[3] || "";
    return patientId && String(metadata.pacienteId || "") === patientId;
  }

  return true;
}

async function validateCanonicalUpload({objectData, storage}) {
  if (!canonicalUploadShouldBeInspected(objectData)) {
    return {inspected: false, deleted: false};
  }

  const bucket = storage.bucket(objectData.bucket);
  const file = bucket.file(objectData.name);
  let valid = canonicalUploadMetadataValid(objectData);
  if (valid) {
    const [bytes] = await file.download({
      start: 0,
      end: INSPECTION_BYTES - 1,
      validation: false,
    });
    valid = uploadContentMatchesMime(bytes, objectData.contentType);
  }

  if (valid) return {inspected: true, deleted: false};

  await file.delete({
    ifGenerationMatch: Number(objectData.generation),
    ignoreNotFound: true,
  });
  return {inspected: true, deleted: true};
}

module.exports = {
  canonicalUploadMetadataValid,
  canonicalUploadShouldBeInspected,
  uploadContentMatchesMime,
  validateCanonicalUpload,
};
