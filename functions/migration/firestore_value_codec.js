/* eslint-disable require-jsdoc */
"use strict";

const {GeoPoint, Timestamp} = require("firebase-admin/firestore");

const TYPE_KEY = "__natusFirestoreType";

function encodeFirestoreValue(value) {
  if (value === null || value === undefined || typeof value === "string" ||
      typeof value === "boolean") {
    return value === undefined ? null : value;
  }
  if (typeof value === "number") {
    if (Number.isFinite(value)) return value;
    return {[TYPE_KEY]: "number", value: String(value)};
  }
  if (value instanceof Timestamp) {
    return {
      [TYPE_KEY]: "timestamp",
      seconds: value.seconds,
      nanoseconds: value.nanoseconds,
    };
  }
  if (value instanceof Date) {
    return {[TYPE_KEY]: "date", value: value.toISOString()};
  }
  if (value instanceof GeoPoint) {
    return {
      [TYPE_KEY]: "geopoint",
      latitude: value.latitude,
      longitude: value.longitude,
    };
  }
  if (Buffer.isBuffer(value) || value instanceof Uint8Array) {
    return {
      [TYPE_KEY]: "bytes",
      value: Buffer.from(value).toString("base64"),
    };
  }
  if (value && typeof value.path === "string" &&
      value.firestore && typeof value.get === "function") {
    return {[TYPE_KEY]: "reference", path: value.path};
  }
  if (Array.isArray(value)) return value.map(encodeFirestoreValue);
  if (typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [
      key,
      encodeFirestoreValue(item),
    ]));
  }
  throw new Error(`Tipo Firestore não suportado: ${typeof value}.`);
}

function decodeFirestoreValue(value, firestore) {
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) {
    return value.map((item) => decodeFirestoreValue(item, firestore));
  }
  const type = value[TYPE_KEY];
  if (type === "timestamp") {
    return new Timestamp(value.seconds, value.nanoseconds);
  }
  if (type === "date") return new Date(value.value);
  if (type === "geopoint") {
    return new GeoPoint(value.latitude, value.longitude);
  }
  if (type === "bytes") return Buffer.from(value.value, "base64");
  if (type === "reference") {
    if (!firestore) {
      throw new Error("Firestore é obrigatório para referências.");
    }
    return firestore.doc(value.path);
  }
  if (type === "number") {
    if (value.value === "NaN") return Number.NaN;
    if (value.value === "Infinity") return Number.POSITIVE_INFINITY;
    if (value.value === "-Infinity") return Number.NEGATIVE_INFINITY;
    throw new Error(`Número especial inválido: ${value.value}.`);
  }
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [
    key,
    decodeFirestoreValue(item, firestore),
  ]));
}

module.exports = {
  TYPE_KEY,
  decodeFirestoreValue,
  encodeFirestoreValue,
};
