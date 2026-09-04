# Integracao ZapSign

Esta integracao foi preparada para:

- gerar contrato automaticamente a partir de template DOCX da ZapSign
- salvar status e links no Firestore
- manter a API key fora do Flutter e fora do codigo-fonte

## Segredo obrigatorio

Nao grave a API key no codigo.

Configure o segredo no Firebase Secret Manager:

```bash
firebase functions:secrets:set ZAPSIGN_API_TOKEN
```

Depois informe o valor da chave no prompt do Firebase CLI.

## Configuracao no Firestore

Criar ou editar o documento:

`integracoes/zapsign`

Exemplo de estrutura:

```json
{
  "ativo": true,
  "lang": "pt-br",
  "disableSignerEmails": false,
  "brandName": "Natus",
  "brandPrimaryColor": "#6F3E46",
  "brandLogo": "",
  "folderToken": "",
  "modeloContratualVersao": "2026-09-consultorio-v3",
  "templateIds": {
    "presenca_consultorio": "",
    "plenitude_consultorio": ""
  },
  "placeholdersFixos": {
    "razaoSocialNatus": "Natus",
    "cnpjNatus": "63.395.279/0001-70",
    "enderecoNatus": "",
    "representanteLegal": "Maressa Valentim dos Santos Bandeira",
    "cpfRepresentante": "103.605.559-00",
    "profissionalResponsavel": ""
  }
}
```

## Fluxo implementado

1. O app identifica o `templateKey` pelo plano e modalidade.
2. O backend recebe `contratoId` e `payload`.
3. A function busca o `templateId` correspondente em `integracoes/zapsign`.
4. A function chama `POST /api/v1/models/create-doc/`.
5. O retorno da ZapSign e salvo em `contratos`.
6. A ficha da paciente recebe status, token e link de assinatura.

Os únicos modelos contratuais ativos são:

- `presenca_consultorio`: R$ 4.000,00
- `plenitude_consultorio`: R$ 5.000,00

E-mail e telefone válidos da paciente são obrigatórios. Eles são enviados à
ZapSign como dados bloqueados do signatário; o e-mail automático de assinatura
fica habilitado quando `disableSignerEmails` não for `true`.

O botão do aplicativo usa `reemitirContratoZapSign`: se o contrato ainda não
possuir documento ZapSign, a solicitação existente é tentada novamente. Se já
possuir documento, uma nova emissão é criada e vinculada à anterior, que
permanece no histórico.

## Endpoints usados

- Criacao por template:
  `POST https://api.zapsign.com.br/api/v1/models/create-doc/`
- Consulta de documento:
  `GET https://api.zapsign.com.br/api/v1/docs/{doc_token}/`

Documentacao oficial usada:

- https://docs.zapsign.com.br/english/documentos/criar-documento-via-modelo
- https://docs.zapsign.com.br/english/documentos/detalhar-documento
- https://firebase.google.com/docs/functions/config-env
