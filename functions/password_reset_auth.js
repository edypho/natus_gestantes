"use strict";

/** Erro seguro de autenticacao exposto pelos fluxos de redefinicao. */
class AuthTokenValidationError extends Error {
  /**
   * @param {string} message Mensagem segura para o cliente.
   */
  constructor(message) {
    super(message);
    this.name = "AuthTokenValidationError";
    this.code = "unauthenticated";
  }
}

/**
 * Extrai um ID token de um cabecalho Authorization Bearer.
 * @param {string|string[]|undefined} authorizationHeader Cabecalho recebido.
 * @return {string} Token normalizado ou string vazia.
 */
function extrairTokenBearer(authorizationHeader) {
  const valor = Array.isArray(authorizationHeader) ?
    authorizationHeader[0] : authorizationHeader;
  const cabecalho = String(valor || "").trim();
  const prefixo = "Bearer ";

  if (!cabecalho.startsWith(prefixo)) return "";

  const token = cabecalho.slice(prefixo.length).trim();

  return token && !/\s/.test(token) ? token : "";
}

/**
 * Verifica o ID token e consulta explicitamente o estado de revogacao.
 * @param {object} firebaseAuth Instancia Firebase Auth Admin.
 * @param {string|string[]|undefined} authorizationHeader Cabecalho recebido.
 * @param {string} uidEsperado UID autenticado pelo protocolo callable.
 * @return {Promise<object>} Token Firebase decodificado.
 */
async function verificarIdTokenNaoRevogado(
    firebaseAuth,
    authorizationHeader,
    uidEsperado = "",
) {
  const idToken = extrairTokenBearer(authorizationHeader);

  if (!idToken) {
    throw new AuthTokenValidationError(
        "Token de autenticacao nao informado.",
    );
  }

  let tokenDecodificado;

  try {
    tokenDecodificado = await firebaseAuth.verifyIdToken(idToken, true);
  } catch (_) {
    throw new AuthTokenValidationError(
        "Token de autenticacao invalido ou revogado.",
    );
  }

  const uid = String(tokenDecodificado && tokenDecodificado.uid || "").trim();
  const uidNormalizado = String(uidEsperado || "").trim();

  if (!uid || (uidNormalizado && uid !== uidNormalizado)) {
    throw new AuthTokenValidationError(
        "Token de autenticacao nao corresponde ao usuario da requisicao.",
    );
  }

  return tokenDecodificado;
}

module.exports = {
  AuthTokenValidationError,
  extrairTokenBearer,
  verificarIdTokenNaoRevogado,
};
