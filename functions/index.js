const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

const {onRequest} = require("firebase-functions/v2/https");


const {onCall, HttpsError} = require("firebase-functions/v2/https");

admin.initializeApp();

setGlobalOptions({maxInstances: 10});

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

      await admin.firestore().collection("contratos").doc(contratoId).set({
        status: "aguardando_configuracao_zapsign",
        payload: payload,
        atualizadoEm: new Date().toISOString(),
      }, {merge: true});

      throw new HttpsError(
          "failed-precondition",
          "Integracao ZapSign ainda nao configurada. " +
          "Finalize os templates e informe os templateIds.",
      );
    },
);

exports.consultarContratoZapSign = onCall(
    {
      invoker: "private",
      region: "us-central1",
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

      return {
        contratoId: contratoId,
        zapsignDocumentId: zapsignDocumentId,
        status: snapshot.data().status || "pendente",
        mensagem: "Consulta preparada. A chamada real para a ZapSign " +
          "sera implementada apos a configuracao dos templates.",
      };
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
