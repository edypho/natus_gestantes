/* eslint-disable require-jsdoc */
/* eslint-disable max-len */
/* eslint-disable quote-props */
const {setGlobalOptions} = require("firebase-functions");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const {defineSecret} = require("firebase-functions/params");

const {onRequest} = require("firebase-functions/v2/https");


const {onCall, HttpsError} = require("firebase-functions/v2/https");

const zapsignApiToken = defineSecret("ZAPSIGN_API_TOKEN");
const ZAPSIGN_API_BASE_URL = "https://api.zapsign.com.br/api/v1";
const ZAPSIGN_SIGNER_BASE_URL = "https://app.zapsign.co/verificar";
const ZAPSIGN_CONFIG_PATH = "integracoes/zapsign";
const ZAPSIGN_TEMPLATE_IDS_PADRAO = {
  acolher_consultorio: "2037be9f-e33e-406b-98ad-e2b74b385c9f",
  acolher_residencial: "1953c005-2ca1-450c-a779-d77e8a680ab8",
  presenca_consultorio: "876e29dd-bb1f-4801-b146-d9e2e45cf6ed",
  presenca_residencial: "b7337535-0c05-4038-97f4-8f879d1a4012",
  plenitude_consultorio: "045ebda1-9835-4bd8-810f-7fb1bd2cf411",
  plenitude_residencial: "83503f6b-f179-4a20-afe4-dbdc9ad0f031",
};

const ZAPSIGN_PLANOS_POR_TEMPLATE = {
  acolher_consultorio: {
    planoNome: "Acolher",
    modalidadeNome: "Consultorio",
  },
  acolher_residencial: {
    planoNome: "Acolher",
    modalidadeNome: "Residencial",
  },
  presenca_consultorio: {
    planoNome: "Presenca",
    modalidadeNome: "Consultorio",
  },
  presenca_residencial: {
    planoNome: "Presenca",
    modalidadeNome: "Residencial",
  },
  plenitude_consultorio: {
    planoNome: "Plenitude",
    modalidadeNome: "Consultorio",
  },
  plenitude_residencial: {
    planoNome: "Plenitude",
    modalidadeNome: "Residencial",
  },
};

function normalizarTextoContrato(valor) {
  return String(valor || "")
      .toLowerCase()
      .trim()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "");
}

function descobrirTemplateKeyContrato(plano, consultorio) {
  const planoNormalizado = normalizarTextoContrato(plano);
  const consultorioNormalizado = normalizarTextoContrato(consultorio);

  if (planoNormalizado.includes("acolher") &&
    planoNormalizado.includes("consultorio")) {
    return "acolher_consultorio";
  }

  if (planoNormalizado.includes("acolher") &&
    planoNormalizado.includes("residencial")) {
    return "acolher_residencial";
  }

  if (planoNormalizado.includes("presenca") &&
    planoNormalizado.includes("consultorio")) {
    return "presenca_consultorio";
  }

  if (planoNormalizado.includes("presenca") &&
    planoNormalizado.includes("residencial")) {
    return "presenca_residencial";
  }

  if (planoNormalizado.includes("plenitude") &&
    planoNormalizado.includes("consultorio")) {
    return "plenitude_consultorio";
  }

  if (planoNormalizado.includes("plenitude") &&
    planoNormalizado.includes("residencial")) {
    return "plenitude_residencial";
  }

  if (planoNormalizado.includes("acolher")) {
    return consultorioNormalizado === "sim" ||
      consultorioNormalizado.includes("consultorio") ?
      "acolher_consultorio" :
      "acolher_residencial";
  }

  if (planoNormalizado.includes("presenca")) {
    return consultorioNormalizado === "sim" ||
      consultorioNormalizado.includes("consultorio") ?
      "presenca_consultorio" :
      "presenca_residencial";
  }

  if (planoNormalizado.includes("plenitude")) {
    return consultorioNormalizado === "sim" ||
      consultorioNormalizado.includes("consultorio") ?
      "plenitude_consultorio" :
      "plenitude_residencial";
  }

  return "";
}

admin.initializeApp();

setGlobalOptions({maxInstances: 10});

function somenteDigitos(valor) {
  return String(valor || "").replace(/\D/g, "");
}

function normalizarTelefone(telefone) {
  const digitos = somenteDigitos(telefone);

  if (!digitos) {
    return {
      countryCode: "",
      number: "",
    };
  }

  if (digitos.startsWith("55") && digitos.length > 11) {
    return {
      countryCode: "55",
      number: digitos.slice(2),
    };
  }

  return {
    countryCode: "55",
    number: digitos,
  };
}

function converterNumeroContrato(valor) {
  if (typeof valor === "number") {
    return Number.isFinite(valor) ? valor : 0;
  }

  const texto = String(valor || "").trim();

  if (!texto) {
    return 0;
  }

  const normalizado = texto
      .replace(/\s/g, "")
      .replace("R$", "")
      .replace(/\./g, "")
      .replace(",", ".");

  const numero = Number(normalizado);

  return Number.isFinite(numero) ? numero : 0;
}

function formatarMoedaContrato(valor) {
  const numero = converterNumeroContrato(valor);

  if (!Number.isFinite(numero)) {
    return "R$ 0,00";
  }

  return numero.toLocaleString("pt-BR", {
    style: "currency",
    currency: "BRL",
  });
}

function formatarDataAssinatura(valor) {
  if (!valor) {
    return new Date().toLocaleDateString("pt-BR");
  }

  const data = new Date(valor);

  if (Number.isNaN(data.getTime())) {
    return String(valor);
  }

  return data.toLocaleDateString("pt-BR");
}

function formatarDataHoraDocumento(valor) {
  const data = valor instanceof Date ? valor : new Date(valor);

  if (Number.isNaN(data.getTime())) {
    return "";
  }

  const dia = String(data.getDate()).padStart(2, "0");
  const mes = String(data.getMonth() + 1).padStart(2, "0");
  const ano = String(data.getFullYear());
  const hora = String(data.getHours()).padStart(2, "0");
  const minuto = String(data.getMinutes()).padStart(2, "0");

  return `${dia}/${mes}/${ano} ${hora}:${minuto}`;
}

function normalizarStatusContrato(zapsignStatus) {
  const valor = String(zapsignStatus || "").trim().toLowerCase();

  if (!valor) {
    return "processando";
  }

  if (["signed", "completed", "finalized"].includes(valor)) {
    return "assinado";
  }

  if (["refused", "rejected"].includes(valor)) {
    return "recusado";
  }

  if (["cancelled", "canceled"].includes(valor)) {
    return "cancelado";
  }

  if (valor === "expired") {
    return "expirado";
  }

  if (["pending", "in_progress", "processing"].includes(valor)) {
    return "enviado";
  }

  return valor;
}

async function buscarConfiguracaoZapSign() {
  const ref = admin.firestore().doc(ZAPSIGN_CONFIG_PATH);
  const snapshot = await ref.get();

  if (!snapshot.exists) {
    const configuracaoPadrao = {
      ativo: true,
      lang: "pt-br",
      disableSignerEmails: false,
      brandName: "Natus",
      brandPrimaryColor: "#6F3E46",
      brandLogo: "",
      folderToken: "",
      templateIds: ZAPSIGN_TEMPLATE_IDS_PADRAO,
      placeholdersFixos: {
        razaoSocialNatus: "Natus",
        cnpjNatus: "63.395.279/0001-70",
        enderecoNatus: "",
        representanteLegal: "Maressa Valentim dos Santos Bandeira",
        cpfRepresentante: "103.605.559-00",
        profissionalResponsavel: "",
      },
      atualizadoEm: new Date().toISOString(),
      criadoAutomaticamenteEm: new Date().toISOString(),
    };

    await ref.set(configuracaoPadrao, {merge: true});
    return configuracaoPadrao;
  }

  const dados = snapshot.data() || {};

  return {
    ativo: dados.ativo !== false,
    lang: dados.lang || "pt-br",
    disableSignerEmails: dados.disableSignerEmails === true,
    brandName: dados.brandName || "Natus",
    brandPrimaryColor: dados.brandPrimaryColor || "#6F3E46",
    brandLogo: dados.brandLogo || "",
    folderToken: dados.folderToken || "",
    templateIds: {
      ...ZAPSIGN_TEMPLATE_IDS_PADRAO,
      ...(dados.templateIds || {}),
    },
    placeholdersFixos: dados.placeholdersFixos || {},
  };
}

function montarPayloadContratoDaGestante(idGestante, dados) {
  const templateKey =
    dados.contratoTemplateKey ||
    descobrirTemplateKeyContrato(dados.plano || "", dados.consultorio || "");
  const definicaoPlano = ZAPSIGN_PLANOS_POR_TEMPLATE[templateKey] || {};
  const partesEndereco = [
    dados.enderecoGestante || "",
    dados.numeroGestante || "",
    dados.complementoGestante || "",
    dados.bairroGestante || "",
    dados.cidadeGestante || "",
    dados.estadoGestante || "",
    dados.cepGestante || "",
  ].filter((parte) => String(parte || "").trim());

  return {
    pacienteId: idGestante,
    nomePaciente: dados.nomeGestante || "",
    emailPaciente: dados.emailGestante || "",
    telefonePaciente: dados.telefoneGestante || "",
    cpfPaciente: dados.cpfGestante || "",
    rgPaciente: dados.rgGestante || "",
    enderecoPaciente: partesEndereco.join(", "),
    nomeResponsavel: dados.nomePai || "",
    emailResponsavel: dados.emailPai || "",
    telefoneResponsavel: dados.telefonePai || "",
    cpfResponsavel: dados.cpfPai || "",
    rgResponsavel: dados.rgPai || "",
    enderecoResponsavel: partesEndereco.join(", "),
    dpp: dados.dpp || "",
    planoNome: definicaoPlano.planoNome || dados.plano || "",
    modalidadeNome: definicaoPlano.modalidadeNome ||
      (dados.contratoResumo && dados.contratoResumo.modalidadeNome ?
      dados.contratoResumo.modalidadeNome :
      (dados.consultorio === "Sim" ? "Consultorio" : "Residencial")),
    templateKey,
    cidadeAssinatura: dados.cidadeGestante || "Curitiba",
    dataAssinatura: new Date().toISOString(),
    formaPagamento: dados.formaPagamento || "",
    vencimentoParcelas: dados.vencimentoParcelas || "",
    observacoesContrato: dados.observacoesContrato || "",
    numeroParcelas: Number.parseInt(dados.parcelas || "1", 10) || 1,
    valorTotal: dados.contratoResumo && dados.contratoResumo.valorTotal ?
      dados.contratoResumo.valorTotal :
      dados.valorPlano || 0,
    valorEntrada: dados.contratoResumo && dados.contratoResumo.valorEntrada ?
      dados.contratoResumo.valorEntrada :
      dados.entrada || 0,
    valorSaldo: dados.contratoResumo && dados.contratoResumo.valorSaldo ?
      dados.contratoResumo.valorSaldo :
      0,
    valorParcela: dados.contratoResumo && dados.contratoResumo.valorParcela ?
      dados.contratoResumo.valorParcela :
      dados.valorParcela || 0,
  };
}

function montarCamposDinamicos(payload, configuracao) {
  const fixos = configuracao.placeholdersFixos || {};

  const placeholders = {
    "{{nome_cliente}}": payload.nomePaciente || "",
    "{{cpf_cliente}}": payload.cpfPaciente || "",
    "{{rg_cliente}}": payload.rgPaciente || "",
    "{{endereco_cliente}}": payload.enderecoPaciente || "",
    "{{telefone_cliente}}": payload.telefonePaciente || "",
    "{{email_cliente}}": payload.emailPaciente || "",
    "{{nome_acompanhante}}": payload.nomeResponsavel || "",
    "{{cpf_acompanhante}}": payload.cpfResponsavel || "",
    "{{endereco_acompanhante}}": payload.enderecoResponsavel || "",
    "{{nome_esposa}}": payload.nomePaciente || "",
    "{{rg_esposa}}": payload.rgPaciente || "",
    "{{cpf_esposa}}": payload.cpfPaciente || "",
    "{{nome_esposo}}": payload.nomeResponsavel || "",
    "{{rg_esposo}}": payload.rgResponsavel || "",
    "{{cpf_esposo}}": payload.cpfResponsavel || "",
    "{{endereco_contratantes}}":
      payload.enderecoPaciente || payload.enderecoResponsavel || "",
    "{{data_assinatura}}": formatarDataAssinatura(payload.dataAssinatura),
    "{{cidade_assinatura}}": payload.cidadeAssinatura || "Curitiba",
    "{{plano_nome}}": payload.planoNome || "",
    "{{modalidade_nome}}": payload.modalidadeNome || "",
    "{{valor_total}}": formatarMoedaContrato(payload.valorTotal),
    "{{valor_entrada}}": formatarMoedaContrato(payload.valorEntrada),
    "{{valor_saldo}}": formatarMoedaContrato(payload.valorSaldo),
    "{{numero_parcelas}}": String(payload.numeroParcelas || ""),
    "{{valor_parcela}}": formatarMoedaContrato(payload.valorParcela),
    "{{vencimento_parcelas}}": payload.vencimentoParcelas || "",
    "{{forma_pagamento}}": payload.formaPagamento || "",
    "{{razao_social_natus}}": fixos.razaoSocialNatus || "Natus",
    "{{cnpj_natus}}": fixos.cnpjNatus || "63.395.279/0001-70",
    "{{endereco_natus}}": fixos.enderecoNatus || "",
    "{{representante_legal}}":
      fixos.representanteLegal || "Maressa Valentim dos Santos Bandeira",
    "{{cpf_representante}}": fixos.cpfRepresentante || "103.605.559-00",
    "{{dpp}}": payload.dpp || "",
    "{{observacoes_contrato}}": payload.observacoesContrato || "",
    "{{profissional_responsavel}}": fixos.profissionalResponsavel || "",
  };

  return Object.entries(placeholders).map(([de, para]) => ({
    de,
    para: String(para || ""),
  }));
}

function extrairTokenAssinatura(signatario) {
  return signatario.token ||
    signatario.signer_token ||
    signatario.sign_url_token ||
    "";
}

function extrairLinkAssinatura(signatario) {
  const linkDireto = signatario.sign_url || signatario.signer_url || "";

  if (linkDireto) {
    return linkDireto;
  }

  const token = extrairTokenAssinatura(signatario);
  return token ? `${ZAPSIGN_SIGNER_BASE_URL}/${token}` : "";
}

function mapearSignatariosZapSign(signers) {
  if (!Array.isArray(signers)) {
    return [];
  }

  return signers.map((signer) => ({
    token: extrairTokenAssinatura(signer),
    signUrl: extrairLinkAssinatura(signer),
    nome: signer.name || signer.signer_name || "",
    email: signer.email || "",
    telefone: signer.phone_number || signer.phone || "",
    status: signer.status || "",
    qualificacao: signer.qualification || "",
  }));
}

function montarLinkAssinaturaPrincipal(signers) {
  const signatarios = mapearSignatariosZapSign(signers);

  if (signatarios.length === 0) {
    return {
      signerToken: "",
      signerUrl: "",
    };
  }

  return {
    signerToken: signatarios[0].token || "",
    signerUrl: signatarios[0].signUrl || "",
  };
}

function montarSignatario({
  nome,
  email,
  telefone,
  qualificacao,
  configuracao,
}) {
  const telefoneNormalizado = normalizarTelefone(telefone);
  const signatario = {
    name: String(nome || "").trim(),
    auth_mode: "assinaturaTela",
    qualification: qualificacao || "",
    send_automatic_email:
      configuracao.disableSignerEmails !== true && Boolean(email),
    lock_name: true,
    lock_email: Boolean(email),
    lock_phone: Boolean(telefoneNormalizado.number),
  };

  if (email) {
    signatario.email = String(email || "").trim();
  }

  if (telefoneNormalizado.countryCode && telefoneNormalizado.number) {
    signatario.phone_country = telefoneNormalizado.countryCode;
    signatario.phone_number = telefoneNormalizado.number;
  }

  return signatario;
}

function montarSignatariosContrato(payload, configuracao) {
  const fixos = configuracao.placeholdersFixos || {};
  const signatarios = [];

  if (payload.nomePaciente) {
    signatarios.push(montarSignatario({
      nome: payload.nomePaciente,
      email: payload.emailPaciente,
      telefone: payload.telefonePaciente,
      qualificacao: "Paciente",
      configuracao,
    }));
  }

  if (payload.nomeResponsavel) {
    signatarios.push(montarSignatario({
      nome: payload.nomeResponsavel,
      email: payload.emailResponsavel,
      telefone: payload.telefoneResponsavel,
      qualificacao: "Responsavel",
      configuracao,
    }));
  }

  const nomeRepresentante = String(fixos.representanteLegal || "").trim();
  if (nomeRepresentante) {
    signatarios.push(montarSignatario({
      nome: nomeRepresentante,
      email: fixos.emailRepresentante || "",
      telefone: fixos.telefoneRepresentante || "",
      qualificacao: "Representante legal da clinica",
      configuracao,
    }));
  }

  return signatarios.filter((signatario) => signatario.name);
}

function montarPayloadCriacaoDocumento({
  contratoId,
  payload,
  configuracao,
  templateId,
}) {
  const signatarios = montarSignatariosContrato(payload, configuracao);
  const signatarioPrincipal = signatarios[0] || {};

  const body = {
    template_id: templateId,
    signer_name: signatarioPrincipal.name || payload.nomePaciente || "Paciente",
    data: montarCamposDinamicos(payload, configuracao),
    lang: configuracao.lang || "pt-br",
    disable_signer_emails: configuracao.disableSignerEmails === true,
  };

  if (signatarioPrincipal.email) {
    body.signer_email = signatarioPrincipal.email;
  }

  if (signatarioPrincipal.phone_country && signatarioPrincipal.phone_number) {
    body.signer_phone_country = signatarioPrincipal.phone_country;
    body.signer_phone_number = signatarioPrincipal.phone_number;
  }

  if (configuracao.brandLogo) {
    body.brand_logo = configuracao.brandLogo;
  }

  if (configuracao.brandPrimaryColor) {
    body.brand_primary_color = configuracao.brandPrimaryColor;
  }

  if (configuracao.brandName) {
    body.brand_name = configuracao.brandName;
  }

  if (configuracao.folderToken) {
    body.folder_token = configuracao.folderToken;
  }

  body.name = `${payload.planoNome || "Contrato"} - ${payload.nomePaciente || contratoId}`;

  return body;
}

async function adicionarSignatariosSecundarios({
  zapsignDocumentId,
  signatarios,
  apiToken,
}) {
  if (!zapsignDocumentId || !Array.isArray(signatarios) || signatarios.length <= 1) {
    return [];
  }

  const signatariosAdicionados = [];

  for (const signatario of signatarios.slice(1)) {
    const resposta = await chamarZapSign({
      method: "POST",
      path: `/docs/${zapsignDocumentId}/add-signer/`,
      apiToken,
      body: signatario,
    });

    signatariosAdicionados.push(resposta);
  }

  return signatariosAdicionados;
}

async function atualizarGestanteComContrato(pacienteId, dados) {
  if (!pacienteId) {
    return;
  }

  await admin.firestore().collection("gestantes").doc(pacienteId).set(dados, {
    merge: true,
  });
}

async function atualizarContrato(contratoId, dados) {
  await admin.firestore().collection("contratos").doc(contratoId).set(dados, {
    merge: true,
  });
}

async function buscarGestantePorId(pacienteId) {
  if (!pacienteId) {
    return {};
  }

  const snapshot = await admin
      .firestore()
      .collection("gestantes")
      .doc(pacienteId)
      .get();

  if (!snapshot.exists) {
    return {};
  }

  return snapshot.data() || {};
}

function montarNomeDocumentoContrato(payload) {
  const planoNome = String(payload.planoNome || "").trim();
  const nomePaciente = String(payload.nomePaciente || "").trim();
  let nome = "Contrato";

  if (planoNome) {
    nome += ` ${planoNome}`;
  }

  if (nomePaciente) {
    nome += ` - ${nomePaciente}`;
  }

  return nome.replace(/\s+/g, " ").trim();
}

function montarArquivoNomeContrato(payload, statusInterno) {
  const base = montarNomeDocumentoContrato(payload);
  return statusInterno === "assinado" ? `${base} assinado` : base;
}

function resolverUrlDocumentoContrato({
  detalheDocumento,
  respostaZapSign,
  signerUrl,
}) {
  return detalheDocumento.signed_file ||
    respostaZapSign.signed_file ||
    signerUrl ||
    "";
}

async function sincronizarDocumentoContrato({
  contratoId,
  pacienteId,
  payload,
  statusInterno,
  detalheDocumento,
  respostaZapSign,
  signerUrl,
}) {
  const gestante = await buscarGestantePorId(pacienteId);
  const nomeGestante = String(
      gestante.nomeGestante || payload.nomePaciente || "",
  ).trim();

  if (!nomeGestante) {
    return;
  }

  const arquivoUrl = resolverUrlDocumentoContrato({
    detalheDocumento,
    respostaZapSign,
    signerUrl,
  });

  const agora = new Date();
  const documentoId = `contrato_${contratoId}`;
  const nomeDocumento = montarNomeDocumentoContrato(payload);
  const arquivoNome = montarArquivoNomeContrato(payload, statusInterno);

  await admin.firestore().collection("documentos").doc(documentoId).set({
    nome: nomeDocumento,
    tipo: "Contrato",
    gestante: nomeGestante,
    gestanteId: pacienteId,
    arquivoNome,
    arquivoUrl,
    arquivoPrincipalUrl: arquivoUrl,
    zapsignSignerUrl: signerUrl || "",
    zapsignSignedFile:
      detalheDocumento.signed_file || respostaZapSign.signed_file || "",
    zapsignOriginalFile:
      detalheDocumento.original_file || respostaZapSign.original_file || "",
    zapsignDocumentId: detalheDocumento.token || respostaZapSign.token || "",
    contratoId,
    statusContrato: statusInterno,
    origem: "zapsign",
    data: formatarDataHoraDocumento(agora),
    criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

function normalizarTipoUsuarioPush(valor) {
  return String(valor || "").trim().toLowerCase();
}

async function buscarUsuariosOperacionaisPush() {
  const db = admin.firestore();
  const usuariosMap = new Map();

  const consultas = await Promise.all([
    db.collection("usuarios")
        .where("tipo", "in", ["enfermeira", "obstetra"])
        .get()
        .catch(() => null),
    db.collection("usuarios")
        .where("tipoUsuario", "in", ["enfermeira", "obstetra"])
        .get()
        .catch(() => null),
  ]);

  for (const resultado of consultas) {
    if (!resultado) continue;

    for (const doc of resultado.docs) {
      usuariosMap.set(doc.id, {
        id: doc.id,
        ...doc.data(),
      });
    }
  }

  return Array.from(usuariosMap.values()).filter((usuario) => {
    const tipo = normalizarTipoUsuarioPush(
        usuario.tipo || usuario.tipoUsuario || "",
    );
    return tipo === "enfermeira" || tipo === "obstetra";
  });
}

function extrairTokensUsuariosPush(usuarios) {
  const tokens = [];
  const donosPorToken = new Map();

  for (const usuario of usuarios) {
    const tokensUsuario = Array.isArray(usuario.pushTokens) ?
      usuario.pushTokens :
      [];

    for (const token of tokensUsuario) {
      const tokenNormalizado = String(token || "").trim();

      if (!tokenNormalizado) {
        continue;
      }

      if (!donosPorToken.has(tokenNormalizado)) {
        tokens.push(tokenNormalizado);
        donosPorToken.set(tokenNormalizado, new Set());
      }

      donosPorToken.get(tokenNormalizado).add(usuario.id);
    }
  }

  return {
    tokens,
    donosPorToken,
  };
}

async function limparTokensInvalidosPush(tokensInvalidos, donosPorToken) {
  if (!Array.isArray(tokensInvalidos) || tokensInvalidos.length === 0) {
    return;
  }

  const db = admin.firestore();
  const atualizacoes = [];

  for (const token of tokensInvalidos) {
    const donos = donosPorToken.get(token);
    if (!donos || donos.size === 0) {
      continue;
    }

    for (const uid of donos) {
      atualizacoes.push(
          db.collection("usuarios").doc(uid).set({
            pushTokens: admin.firestore.FieldValue.arrayRemove(token),
            pushAtualizadoEm: new Date().toISOString(),
          }, {merge: true}),
      );
    }
  }

  await Promise.all(atualizacoes);
}

async function enviarPushParaUsuariosOperacionais({
  title,
  body,
  data,
}) {
  const usuarios = await buscarUsuariosOperacionaisPush();
  const {tokens, donosPorToken} = extrairTokensUsuariosPush(usuarios);

  if (tokens.length === 0) {
    console.log("Push: nenhum token operacional encontrado.");
    return {
      sucesso: 0,
      falhas: 0,
    };
  }

  const resposta = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title,
      body,
    },
    data,
    android: {
      priority: "high",
      notification: {
        sound: "default",
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
    webpush: {
      headers: {
        Urgency: "high",
      },
      notification: {
        title,
        body,
        icon: "/icons/Icon-192.png",
        badge: "/icons/Icon-192.png",
        requireInteraction: data.tipo === "alerta_contracao",
      },
    },
  });

  const tokensInvalidos = [];

  resposta.responses.forEach((resultado, index) => {
    if (resultado.success) {
      return;
    }

    const code = resultado.error && resultado.error.code ?
      resultado.error.code :
      "";

    console.error("Push: falha ao enviar notificação:", code, resultado.error);

    if ([
      "messaging/registration-token-not-registered",
      "messaging/invalid-registration-token",
    ].includes(code)) {
      tokensInvalidos.push(tokens[index]);
    }
  });

  await limparTokensInvalidosPush(tokensInvalidos, donosPorToken);

  return {
    sucesso: resposta.successCount,
    falhas: resposta.failureCount,
  };
}

async function registrarNotificacaoCentral({
  tipo,
  titulo,
  mensagem,
  gestante,
  intensidade,
  duracao,
  intervalo,
  idGestante,
  destinatariosTipos,
}) {
  await admin.firestore().collection("notificacoesCentral").add({
    tipo: tipo || "notificacao",
    titulo: titulo || "Notificação",
    mensagem: mensagem || "",
    gestante: gestante || "",
    intensidade: intensidade || "",
    duracao: duracao || "",
    intervalo: intervalo || "",
    idGestante: idGestante || "",
    destinatariosTipos: Array.isArray(destinatariosTipos) ?
      destinatariosTipos :
      ["admin"],
    lidasPor: [],
    criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    criadoEmIso: new Date().toISOString(),
    atualizadoEm: new Date().toISOString(),
  });
}

async function chamarZapSign({
  method,
  path,
  apiToken,
  body,
}) {
  const resposta = await fetch(`${ZAPSIGN_API_BASE_URL}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${apiToken}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const texto = await resposta.text();
  let json;

  try {
    json = texto ? JSON.parse(texto) : {};
  } catch (error) {
    json = {raw: texto};
  }

  if (!resposta.ok) {
    throw new Error(
        `ZapSign ${resposta.status}: ${
          json.detail || json.message || json.error || texto || "erro desconhecido"
        }`,
    );
  }

  return json;
}

async function processarGeracaoContrato({
  contratoId,
  payload,
  apiToken,
}) {
  const templateKey = payload.templateKey || "";
  const pacienteId = payload.pacienteId || "";
  const configuracao = await buscarConfiguracaoZapSign();
  const signatariosPlanejados = montarSignatariosContrato(payload, configuracao);

  if (configuracao.ativo === false) {
    throw new HttpsError(
        "failed-precondition",
        "A integracao ZapSign esta desativada nas configuracoes.",
    );
  }

  const templateId = (configuracao.templateIds || {})[templateKey] || "";

  if (!templateId) {
    await atualizarContrato(contratoId, {
      status: "aguardando_template",
      zapsignTemplateKey: templateKey,
      payload,
      atualizadoEm: new Date().toISOString(),
    });

    await atualizarGestanteComContrato(pacienteId, {
      contratoStatus: "aguardando_template",
      contratoTemplateKey: templateKey,
      contratoUltimaTentativaEm: new Date().toISOString(),
    });

    throw new HttpsError(
        "failed-precondition",
        `Template da ZapSign ainda nao configurado para ${templateKey}.`,
    );
  }

  if (!apiToken) {
    throw new HttpsError(
        "failed-precondition",
        "Secret ZAPSIGN_API_TOKEN nao configurado.",
    );
  }

  const body = montarPayloadCriacaoDocumento({
    contratoId,
    payload,
    configuracao,
    templateId,
  });

  await atualizarContrato(contratoId, {
    status: "processando",
    zapsignTemplateKey: templateKey,
    zapsignTemplateId: templateId,
    payload,
    requestBody: body,
    atualizadoEm: new Date().toISOString(),
  });

  try {
    const respostaZapSign = await chamarZapSign({
      method: "POST",
      path: "/models/create-doc/",
      apiToken,
      body,
    });

    await adicionarSignatariosSecundarios({
      zapsignDocumentId: respostaZapSign.token || "",
      signatarios: signatariosPlanejados,
      apiToken,
    });

    const detalheDocumento = respostaZapSign.token ?
      await chamarZapSign({
        method: "GET",
        path: `/docs/${respostaZapSign.token}/`,
        apiToken,
      }) :
      respostaZapSign;
    const signatariosFinais = mapearSignatariosZapSign(detalheDocumento.signers);
    const linksAssinatura = montarLinkAssinaturaPrincipal(detalheDocumento.signers);
    const statusInterno = normalizarStatusContrato(detalheDocumento.status);

    await atualizarContrato(contratoId, {
      status: statusInterno,
      zapsignStatus: detalheDocumento.status || respostaZapSign.status || "",
      zapsignDocumentId: detalheDocumento.token || respostaZapSign.token || "",
      zapsignOpenId: String(
          detalheDocumento.open_id || respostaZapSign.open_id || "",
      ),
      zapsignSignerToken: linksAssinatura.signerToken,
      zapsignSignerUrl: linksAssinatura.signerUrl,
      zapsignSigners: signatariosFinais,
      zapsignOriginalFile:
        detalheDocumento.original_file || respostaZapSign.original_file || "",
      zapsignSignedFile:
        detalheDocumento.signed_file || respostaZapSign.signed_file || "",
      respostaZapSign: detalheDocumento,
      atualizadoEm: new Date().toISOString(),
    });

    await atualizarGestanteComContrato(pacienteId, {
      contratoStatus: statusInterno,
      contratoTemplateKey: templateKey,
      contratoId,
      contratoZapSignDocumentId:
        detalheDocumento.token || respostaZapSign.token || "",
      contratoZapSignSignerUrl: linksAssinatura.signerUrl,
      contratoZapSignSigners: signatariosFinais,
      contratoErro: "",
      contratoUltimaTentativaEm: new Date().toISOString(),
    });

    await sincronizarDocumentoContrato({
      contratoId,
      pacienteId,
      payload,
      statusInterno,
      detalheDocumento,
      respostaZapSign,
      signerUrl: linksAssinatura.signerUrl,
    });

    return {
      sucesso: true,
      contratoId,
      status: statusInterno,
      zapsignStatus: detalheDocumento.status || respostaZapSign.status || "",
      zapsignDocumentId: detalheDocumento.token || respostaZapSign.token || "",
      zapsignSignerUrl: linksAssinatura.signerUrl,
      zapsignSigners: signatariosFinais,
    };
  } catch (error) {
    await atualizarContrato(contratoId, {
      status: "erro",
      erro: error.message || String(error),
      atualizadoEm: new Date().toISOString(),
    });

    await atualizarGestanteComContrato(pacienteId, {
      contratoStatus: "erro",
      contratoErro: error.message || String(error),
      contratoUltimaTentativaEm: new Date().toISOString(),
    });

    throw new HttpsError(
        "internal",
        error.message || "Erro ao gerar contrato na ZapSign.",
    );
  }
}

async function prepararContratoParaGestante(idGestante, dados) {
  if (dados.origem === "importacao_xls") {
    return;
  }

  const templateKey =
    dados.contratoTemplateKey ||
    descobrirTemplateKeyContrato(dados.plano || "", dados.consultorio || "");

  if (!templateKey) {
    return;
  }

  if (dados.contratoId) {
    return;
  }

  const payload = montarPayloadContratoDaGestante(idGestante, {
    ...dados,
    contratoTemplateKey: templateKey,
  });
  const agora = new Date().toISOString();
  const contratoRef = admin.firestore().collection("contratos").doc();

  await contratoRef.set({
    pacienteId: idGestante,
    templateKey: payload.templateKey || "",
    status: "pendente",
    zapsignDocumentId: "",
    zapsignSignerUrl: "",
    payload,
    criadoEm: agora,
    atualizadoEm: agora,
    origem: "cadastro_automatico_gestante",
  });

  await atualizarGestanteComContrato(idGestante, {
    contratoGeracaoAutomatica: true,
    contratoId: contratoRef.id,
    contratoStatus: "pendente",
    contratoTemplateKey: templateKey,
    contratoPlanoCodigo: payload.templateKey.split("_")[0] || "",
    contratoModalidadeCodigo: payload.templateKey.split("_")[1] || "",
    contratoUltimaTentativaEm: agora,
  });

  try {
    const apiToken = zapsignApiToken.value();

    if (!apiToken) {
      await atualizarContrato(contratoRef.id, {
        status: "aguardando_secret",
        atualizadoEm: new Date().toISOString(),
      });
      return;
    }

    await processarGeracaoContrato({
      contratoId: contratoRef.id,
      payload,
      apiToken,
    });
  } catch (error) {
    console.error("Erro ao preparar contrato ZapSign:", error);
  }
}

exports.criarUsuarioGestanteAoCadastrar = onDocumentCreated(
    "gestantes/{idGestante}",
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        console.log("Documento não encontrado no evento.");
        return;
      }

      const idGestante = event.params.idGestante;
      const dados = snapshot.data();

      const nome = dados.nomeGestante || "";
      const email = dados.emailGestante || "";
      const uidGestanteAtual = dados.uidGestante || "";
      const origem = dados.origem || "";

      if (origem === "importacao_xls") {
        console.log("Gestante importada de histórico. Usuário não criado.");
        return;
      }

      if (uidGestanteAtual) {
        console.log("Gestante já possui uidGestante. Usuário não criado.");
        return;
      }

      if (!nome || !email) {
        console.log("Gestante sem nome ou e-mail. Usuário não criado.");
        return;
      }

      let usuario;

      try {
        usuario = await admin.auth().createUser({
          email: email,
          displayName: nome,
          emailVerified: false,
          disabled: false,
        });
      } catch (error) {
        if (error.code === "auth/email-already-exists") {
          usuario = await admin.auth().getUserByEmail(email);
        } else {
          console.error("Erro ao criar usuário:", error);
          return;
        }
      }

      await admin.firestore().collection("usuarios").doc(usuario.uid).set({
        nome: nome,
        email: email,
        tipo: "gestante",
        uidGestante: usuario.uid,
        idGestante: idGestante,
        criadoEm: new Date().toISOString(),
      });

      const linkSenha = await admin.auth().generatePasswordResetLink(email);

      await admin.firestore().collection("gestantes").doc(idGestante).update({
        uidGestante: usuario.uid,
        emailGestante: email,
        acessoCriado: "true",
        linkSenhaInicial: linkSenha,
      });

      console.log("Usuária gestante criada com sucesso:", email);
    },
);

exports.notificarContracaoGestante = onDocumentCreated(
    "contracoes/{idContracao}",
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        console.log("Push contracao: documento nao encontrado no evento.");
        return;
      }

      const dados = snapshot.data() || {};
      const origemTipoUsuario = normalizarTipoUsuarioPush(
          dados.origemTipoUsuario || "",
      );

      if (origemTipoUsuario !== "gestante") {
        console.log("Push contracao: origem nao gestante, alerta ignorado.");
        return;
      }

      const nomeGestante = String(dados.gestante || dados.nomeGestante || "")
          .trim();
      const intensidade = String(dados.intensidade || "").trim();
      const duracao = String(dados.duracao || "").trim();
      const intervalo = String(dados.intervalo || "").trim();
      const idGestante = String(dados.idGestante || "").trim();

      const partesCorpo = [
        nomeGestante ? `${nomeGestante} registrou uma nova contração.` :
          "Uma paciente registrou uma nova contração.",
        intensidade ? `Intensidade: ${intensidade}.` : "",
        duracao ? `Duracao: ${duracao}.` : "",
      ].filter(Boolean);
      const mensagem = partesCorpo.join(" ");

      await registrarNotificacaoCentral({
        tipo: "alerta_contracao",
        titulo: "Alerta de contração",
        mensagem,
        gestante: nomeGestante,
        intensidade,
        duracao,
        intervalo,
        idGestante,
        destinatariosTipos: ["admin", "enfermeira", "obstetra"],
      });

      await enviarPushParaUsuariosOperacionais({
        title: "Alerta de contração",
        body: mensagem,
        data: {
          tipo: "alerta_contracao",
          tag: `contracao_${event.params.idContracao}`,
          contracaoId: event.params.idContracao,
          gestante: nomeGestante,
          intensidade,
          duracao,
          intervalo,
          idGestante,
        },
      });
    },
);

exports.prepararContratoZapSignAoCadastrar = onDocumentCreated(
    {
      document: "gestantes/{idGestante}",
      region: "us-central1",
      secrets: [zapsignApiToken],
    },
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        return;
      }

      const idGestante = event.params.idGestante;
      const dados = snapshot.data() || {};
      await prepararContratoParaGestante(idGestante, dados);
    },
);

exports.prepararContratoZapSignAoAtualizar = onDocumentUpdated(
    {
      document: "gestantes/{idGestante}",
      region: "us-central1",
      secrets: [zapsignApiToken],
    },
    async (event) => {
      const after = event.data && event.data.after;

      if (!after) {
        return;
      }

      const idGestante = event.params.idGestante;
      const dados = after.data() || {};
      await prepararContratoParaGestante(idGestante, dados);
    },
);

exports.excluirUsuarioAuth = onCall(
    {
      invoker: "private",
    },
    async (request) => {
      const uidAdmin = request.auth && request.auth.uid;

      if (!uidAdmin) {
        throw new HttpsError(
            "unauthenticated",
            "Você precisa estar logado.",
        );
      }

      const dadosAdmin = await admin
          .firestore()
          .collection("usuarios")
          .doc(uidAdmin)
          .get();

      if (!dadosAdmin.exists || dadosAdmin.data().tipo !== "admin") {
        throw new HttpsError(
            "permission-denied",
            "Apenas administradores podem excluir usuários.",
        );
      }

      const uidUsuario = request.data.uidUsuario;

      if (!uidUsuario) {
        throw new HttpsError(
            "invalid-argument",
            "UID do usuário é obrigatório.",
        );
      }

      if (uidUsuario === uidAdmin) {
        throw new HttpsError(
            "failed-precondition",
            "Você não pode excluir o próprio usuário logado.",
        );
      }

      await admin.auth().deleteUser(uidUsuario);

      await admin.firestore().collection("usuarios").doc(uidUsuario).delete();

      return {
        sucesso: true,
        mensagem: "Usuário excluído com sucesso.",
      };
    },
);

exports.gerarContratoZapSign = onCall(
    {
      invoker: "private",
      region: "us-central1",
      secrets: [zapsignApiToken],
    },
    async (request) => {
      const uidUsuario = request.auth && request.auth.uid;

      if (!uidUsuario) {
        throw new HttpsError(
            "unauthenticated",
            "Voce precisa estar logado para gerar contratos.",
        );
      }

      const contratoId = request.data.contratoId || "";
      const payload = request.data.payload || {};
      const templateKey = payload.templateKey || "";
      if (!contratoId) {
        throw new HttpsError(
            "invalid-argument",
            "ContratoId nao informado.",
        );
      }

      if (!templateKey) {
        throw new HttpsError(
            "invalid-argument",
            "Template do contrato nao informado.",
        );
      }

      const apiToken = zapsignApiToken.value();
      return processarGeracaoContrato({
        contratoId,
        payload,
        apiToken,
      });
    },
);

exports.consultarContratoZapSign = onCall(
    {
      invoker: "private",
      region: "us-central1",
      secrets: [zapsignApiToken],
    },
    async (request) => {
      const uidUsuario = request.auth && request.auth.uid;

      if (!uidUsuario) {
        throw new HttpsError(
            "unauthenticated",
            "Voce precisa estar logado para consultar contratos.",
        );
      }

      const contratoId = request.data.contratoId || "";
      const zapsignDocumentId = request.data.zapsignDocumentId || "";

      if (!contratoId || !zapsignDocumentId) {
        throw new HttpsError(
            "invalid-argument",
            "ContratoId e zapsignDocumentId sao obrigatorios.",
        );
      }

      const snapshot = await admin
          .firestore()
          .collection("contratos")
          .doc(contratoId)
          .get();

      if (!snapshot.exists) {
        throw new HttpsError(
            "not-found",
            "Contrato nao encontrado.",
        );
      }

      const dadosContrato = snapshot.data() || {};
      const pacienteId = dadosContrato.pacienteId || "";
      const apiToken = zapsignApiToken.value();

      if (!apiToken) {
        throw new HttpsError(
            "failed-precondition",
            "Secret ZAPSIGN_API_TOKEN nao configurado.",
        );
      }

      try {
        const detalhe = await chamarZapSign({
          method: "GET",
          path: `/docs/${zapsignDocumentId}/`,
          apiToken,
        });

        const linksAssinatura = montarLinkAssinaturaPrincipal(detalhe.signers);
        const signatarios = mapearSignatariosZapSign(detalhe.signers);
        const statusInterno = normalizarStatusContrato(detalhe.status);

        await atualizarContrato(contratoId, {
          status: statusInterno,
          zapsignStatus: detalhe.status || "",
          zapsignDocumentId: detalhe.token || zapsignDocumentId,
          zapsignSignerToken: linksAssinatura.signerToken,
          zapsignSignerUrl: linksAssinatura.signerUrl,
          zapsignSigners: signatarios,
          zapsignOriginalFile: detalhe.original_file || "",
          zapsignSignedFile: detalhe.signed_file || "",
          respostaConsultaZapSign: detalhe,
          atualizadoEm: new Date().toISOString(),
        });

        await atualizarGestanteComContrato(pacienteId, {
          contratoStatus: statusInterno,
          contratoZapSignDocumentId: detalhe.token || zapsignDocumentId,
          contratoZapSignSignerUrl: linksAssinatura.signerUrl,
          contratoZapSignSigners: signatarios,
          contratoZapSignSignedFile: detalhe.signed_file || "",
          contratoErro: "",
          contratoUltimaConsultaEm: new Date().toISOString(),
        });

        await sincronizarDocumentoContrato({
          contratoId,
          pacienteId,
          payload: dadosContrato.payload || {},
          statusInterno,
          detalheDocumento: detalhe,
          respostaZapSign: detalhe,
          signerUrl: linksAssinatura.signerUrl,
        });

        return {
          sucesso: true,
          contratoId,
          zapsignDocumentId: detalhe.token || zapsignDocumentId,
          status: statusInterno,
          zapsignStatus: detalhe.status || "",
          zapsignSignerUrl: linksAssinatura.signerUrl,
          zapsignSigners: signatarios,
          signedFile: detalhe.signed_file || "",
          originalFile: detalhe.original_file || "",
        };
      } catch (error) {
        await atualizarContrato(contratoId, {
          erroConsulta: error.message || String(error),
          atualizadoEm: new Date().toISOString(),
        });

        throw new HttpsError(
            "internal",
            error.message || "Erro ao consultar contrato na ZapSign.",
        );
      }
    },
);

exports.reenviarLinkTrocaSenhaGestante = onRequest(
    {
      region: "us-central1",
      invoker: "public",
    },
    async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set(
          "Access-Control-Allow-Headers",
          "Content-Type, Authorization",
      );
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).json({
          sucesso: false,
          mensagem: "Método não permitido.",
        });
        return;
      }

      try {
        const authHeader = req.headers.authorization || "";

        if (!authHeader.startsWith("Bearer ")) {
          res.status(401).json({
            sucesso: false,
            mensagem: "Token de autenticação não informado.",
          });
          return;
        }

        const idToken = authHeader.split("Bearer ")[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);

        if (!decodedToken || !decodedToken.uid) {
          res.status(401).json({
            sucesso: false,
            mensagem: "Usuário não autenticado.",
          });
          return;
        }

        const emailGestante = req.body.emailGestante;
        const gestanteId = req.body.gestanteId;
        const telefoneGestante = req.body.telefoneGestante || "";
        const nomeGestante = req.body.nomeGestante || "";

        if (!emailGestante) {
          res.status(400).json({
            sucesso: false,
            mensagem: "E-mail da gestante não informado.",
          });
          return;
        }

        const emailNormalizado = String(emailGestante)
            .trim()
            .toLowerCase();

        await admin.auth().getUserByEmail(emailNormalizado);

        const linkNovo = await admin.auth().generatePasswordResetLink(
            emailNormalizado,
            {
              url: "https://natus-gestantes.web.app",
              handleCodeInApp: false,
            },
        );

        if (gestanteId) {
          await admin.firestore()
              .collection("gestantes")
              .doc(gestanteId)
              .update({
                linkSenhaInicial: linkNovo,
                linkSenhaInicialGeradoEm: new Date().toISOString(),
                linkSenhaInicialExpirado: false,
              });
        }

        res.status(200).json({
          sucesso: true,
          link: linkNovo,
          emailGestante: emailNormalizado,
          telefoneGestante: telefoneGestante,
          nomeGestante: nomeGestante,
        });
      } catch (error) {
        console.error("Erro ao gerar novo link de acesso:", error);

        if (error.code === "auth/user-not-found") {
          res.status(404).json({
            sucesso: false,
            mensagem: "Gestante não existe no Firebase Authentication.",
          });
          return;
        }

        res.status(500).json({
          sucesso: false,
          mensagem: error.message || "Erro ao gerar novo link de acesso.",
        });
      }
    },
);
