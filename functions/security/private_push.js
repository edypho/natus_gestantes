"use strict";
/* eslint-disable require-jsdoc */

const PRIVATE_PUSH_TITLE = "Nova atualização clínica";
const PRIVATE_PUSH_BODY =
  "Há uma atualização de atendimento. Abra o Natus para visualizar.";

function safeNotificationId(value) {
  const id = String(value || "").trim();
  return /^[a-zA-Z0-9_-]{1,128}$/.test(id) ? id : "";
}

function buildPrivateClinicalPush(notificationId) {
  const safeId = safeNotificationId(notificationId);

  return {
    title: PRIVATE_PUSH_TITLE,
    body: PRIVATE_PUSH_BODY,
    data: {
      tipo: "atualizacao_clinica",
      tag: "atualizacao_clinica",
      ...(safeId ? {notificacaoId: safeId} : {}),
    },
  };
}

module.exports = {
  PRIVATE_PUSH_BODY,
  PRIVATE_PUSH_TITLE,
  buildPrivateClinicalPush,
  safeNotificationId,
};
