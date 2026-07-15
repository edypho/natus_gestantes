/* eslint-disable require-jsdoc */
/* eslint-disable max-len */
/* eslint-disable quote-props */
const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
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
  const templateKey = dados.contratoTemplateKey || "";
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
    cpfResponsavel: dados.cpfPai || "",
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

function montarLinkAssinatura(signers) {
  if (!Array.isArray(signers) || signers.length === 0) {
    return {
      signerToken: "",
      signerUrl: "",
    };
  }

  const signerPrincipal = signers[0] || {};
  const signerToken =
    signerPrincipal.token ||
    signerPrincipal.signer_token ||
    signerPrincipal.sign_url_token ||
    "";

  if (!signerToken) {
    return {
      signerToken: "",
      signerUrl: "",
    };
  }

  return {
    signerToken,
    signerUrl: `${ZAPSIGN_SIGNER_BASE_URL}/${signerToken}`,
  };
}

function montarPayloadCriacaoDocumento({
  contratoId,
  payload,
  configuracao,
  templateId,
}) {
  const telefone = normalizarTelefone(payload.telefonePaciente);

  const body = {
    template_id: templateId,
    signer_name: payload.nomePaciente || "Paciente",
    data: montarCamposDinamicos(payload, configuracao),
    lang: configuracao.lang || "pt-br",
    disable_signer_emails: configuracao.disableSignerEmails === true,
  };

  if (payload.emailPaciente) {
    body.signer_email = payload.emailPaciente;
  }

  if (telefone.countryCode && telefone.number) {
    body.signer_phone_country = telefone.countryCode;
    body.signer_phone_number = telefone.number;
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

    const linksAssinatura = montarLinkAssinatura(respostaZapSign.signers);
    const statusInterno = normalizarStatusContrato(respostaZapSign.status);

    await atualizarContrato(contratoId, {
      status: statusInterno,
      zapsignStatus: respostaZapSign.status || "",
      zapsignDocumentId: respostaZapSign.token || "",
      zapsignOpenId: String(respostaZapSign.open_id || ""),
      zapsignSignerToken: linksAssinatura.signerToken,
      zapsignSignerUrl: linksAssinatura.signerUrl,
      zapsignOriginalFile: respostaZapSign.original_file || "",
      zapsignSignedFile: respostaZapSign.signed_file || "",
      respostaZapSign,
      atualizadoEm: new Date().toISOString(),
    });

    await atualizarGestanteComContrato(pacienteId, {
      contratoStatus: statusInterno,
      contratoTemplateKey: templateKey,
      contratoId,
      contratoZapSignDocumentId: respostaZapSign.token || "",
      contratoZapSignSignerUrl: linksAssinatura.signerUrl,
      contratoUltimaTentativaEm: new Date().toISOString(),
    });

    return {
      sucesso: true,
      contratoId,
      status: statusInterno,
      zapsignStatus: respostaZapSign.status || "",
      zapsignDocumentId: respostaZapSign.token || "",
      zapsignSignerUrl: linksAssinatura.signerUrl,
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

      if (dados.origem === "importacao_xls") {
        return;
      }

      if (!dados.contratoTemplateKey) {
        return;
      }

      if (dados.contratoId) {
        return;
      }

      const payload = montarPayloadContratoDaGestante(idGestante, dados);
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
        contratoId: contratoRef.id,
        contratoStatus: "pendente",
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

        const linksAssinatura = montarLinkAssinatura(detalhe.signers);
        const statusInterno = normalizarStatusContrato(detalhe.status);

        await atualizarContrato(contratoId, {
          status: statusInterno,
          zapsignStatus: detalhe.status || "",
          zapsignDocumentId: detalhe.token || zapsignDocumentId,
          zapsignSignerToken: linksAssinatura.signerToken,
          zapsignSignerUrl: linksAssinatura.signerUrl,
          zapsignOriginalFile: detalhe.original_file || "",
          zapsignSignedFile: detalhe.signed_file || "",
          respostaConsultaZapSign: detalhe,
          atualizadoEm: new Date().toISOString(),
        });

        await atualizarGestanteComContrato(pacienteId, {
          contratoStatus: statusInterno,
          contratoZapSignDocumentId: detalhe.token || zapsignDocumentId,
          contratoZapSignSignerUrl: linksAssinatura.signerUrl,
          contratoZapSignSignedFile: detalhe.signed_file || "",
          contratoUltimaConsultaEm: new Date().toISOString(),
        });

        return {
          sucesso: true,
          contratoId,
          zapsignDocumentId: detalhe.token || zapsignDocumentId,
          status: statusInterno,
          zapsignStatus: detalhe.status || "",
          zapsignSignerUrl: linksAssinatura.signerUrl,
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
