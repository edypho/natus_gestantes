"use strict";

const {URL} = require("node:url");

const CALLABLE_TYPE = "onCall";
const HTTP_TYPE = "onRequest";

/**
 * Normaliza separadores para o relatorio ser igual em todos os sistemas.
 * @param {string} filePath Caminho de arquivo.
 * @return {string} Caminho normalizado.
 */
function normalizePath(filePath) {
  return filePath.replace(/\\/g, "/");
}

/**
 * Localiza a linha baseada no indice de um texto.
 * @param {string} source Conteudo analisado.
 * @param {number} index Indice no conteudo.
 * @return {number} Linha iniciada em um.
 */
function lineAt(source, index) {
  let line = 1;
  for (let cursor = 0; cursor < index; cursor += 1) {
    if (source[cursor] === "\n") {
      line += 1;
    }
  }
  return line;
}

/**
 * Compara textos sem depender da configuracao regional do sistema.
 * @param {string} left Primeiro texto.
 * @param {string} right Segundo texto.
 * @return {number} Resultado da comparacao.
 */
function compareText(left, right) {
  if (left < right) {
    return -1;
  }
  if (left > right) {
    return 1;
  }
  return 0;
}

/**
 * Ordena itens localizados de forma deterministica.
 * @param {Object} left Primeiro item.
 * @param {Object} right Segundo item.
 * @return {number} Resultado da comparacao.
 */
function compareLocated(left, right) {
  const pathResult = compareText(left.path || "", right.path || "");
  if (pathResult !== 0) {
    return pathResult;
  }

  const lineResult = (left.line || 0) - (right.line || 0);
  if (lineResult !== 0) {
    return lineResult;
  }

  const leftIdentity = left.functionName || left.code || left.url || "";
  const rightIdentity = right.functionName || right.code || right.url || "";
  return compareText(leftIdentity, rightIdentity);
}

/**
 * Mascara um intervalo sem alterar indices ou quebras de linha.
 * @param {Array<string>} characters Caracteres a modificar.
 * @param {number} start Inicio inclusivo.
 * @param {number} end Fim exclusivo.
 * @return {void}
 */
function maskRange(characters, start, end) {
  for (let index = start; index < end; index += 1) {
    if (characters[index] !== "\n" && characters[index] !== "\r") {
      characters[index] = " ";
    }
  }
}

/**
 * Cria uma visao lexica preservando indices e quebras de linha.
 *
 * Comentarios sao sempre mascarados. Literais podem ser preservados para a
 * busca intencional de URLs ou mascarados para impedir que texto seja tratado
 * como codigo. Strings Dart simples, raw e triplas, alem de templates JS, sao
 * percorridas sem interpretar marcadores de comentario em seu conteudo.
 *
 * @param {string} source Conteudo analisado.
 * @param {boolean} maskStrings Se literais de string devem ser mascarados.
 * @return {string} Conteudo mascarado com o mesmo comprimento da origem.
 */
function lexicalMask(source, maskStrings) {
  const characters = source.split("");
  let cursor = 0;

  while (cursor < source.length) {
    const character = source[cursor];

    if (character === "\"" || character === "'" || character === "`") {
      const rawPrefix = character !== "`" && cursor > 0 &&
        (source[cursor - 1] === "r" || source[cursor - 1] === "R") &&
        (cursor < 2 || !/[A-Za-z0-9_$]/.test(source[cursor - 2]));
      const triple = character !== "`" &&
        source.slice(cursor, cursor + 3) === character.repeat(3);
      const delimiterLength = triple ? 3 : 1;
      const stringStart = rawPrefix ? cursor - 1 : cursor;
      let end = cursor + delimiterLength;

      while (end < source.length) {
        if (!rawPrefix && source[end] === "\\") {
          end = Math.min(source.length, end + 2);
          continue;
        }
        if (source.slice(end, end + delimiterLength) ===
            character.repeat(delimiterLength)) {
          end += delimiterLength;
          break;
        }
        end += 1;
      }

      if (maskStrings) {
        maskRange(characters, stringStart, end);
      }
      cursor = end;
      continue;
    }

    if (source.slice(cursor, cursor + 2) === "//") {
      let end = source.indexOf("\n", cursor + 2);
      if (end === -1) {
        end = source.length;
      }
      maskRange(characters, cursor, end);
      cursor = end;
      continue;
    }

    if (source.slice(cursor, cursor + 2) === "/*") {
      const closing = source.indexOf("*/", cursor + 2);
      const end = closing === -1 ? source.length : closing + 2;
      maskRange(characters, cursor, end);
      cursor = end;
      continue;
    }

    cursor += 1;
  }

  return characters.join("");
}

/**
 * Mascara comentarios preservando indices, linhas e literais de string.
 * @param {string} source Conteudo analisado.
 * @return {string} Conteudo com comentarios substituidos por espacos.
 */
function maskComments(source) {
  return lexicalMask(source, false);
}

/**
 * Mascara comentarios e strings para pesquisar somente tokens de codigo.
 * @param {string} source Conteudo analisado.
 * @return {string} Conteudo de codigo com indices preservados.
 */
function maskNonCode(source) {
  return lexicalMask(source, true);
}

/**
 * Extrai exports atribuídos diretamente pelo entrypoint das Functions.
 * @param {string} source Conteudo do entrypoint.
 * @param {string} filePath Caminho exibido no relatorio.
 * @return {Array<Object>} Exports encontrados.
 */
function extractBackendExports(source, filePath) {
  const searchableSource = maskNonCode(source);
  const pattern = new RegExp(
      "\\b(?:module\\s*\\.\\s*)?exports\\s*\\.\\s*" +
      "([A-Za-z_$][\\w$]*)\\s*=\\s*" +
      "([A-Za-z_$][\\w$]*)\\s*\\(",
      "g",
  );
  const found = [];
  let match = pattern.exec(searchableSource);

  while (match !== null) {
    found.push({
      functionName: match[1],
      type: match[2],
      path: normalizePath(filePath),
      line: lineAt(source, match.index),
    });
    match = pattern.exec(searchableSource);
  }

  return found.sort((left, right) => {
    const nameResult = compareText(
        left.functionName,
        right.functionName,
    );
    return nameResult !== 0 ? nameResult : compareLocated(left, right);
  });
}

/**
 * Ignora espacos e comentarios antes do primeiro argumento.
 * @param {string} source Conteudo analisado.
 * @param {number} start Posicao inicial.
 * @return {number} Posicao do proximo token.
 */
function skipTrivia(source, start) {
  let cursor = start;

  while (cursor < source.length) {
    if (/\s/.test(source[cursor])) {
      cursor += 1;
      continue;
    }

    if (source.slice(cursor, cursor + 2) === "//") {
      const end = source.indexOf("\n", cursor + 2);
      cursor = end === -1 ? source.length : end + 1;
      continue;
    }

    if (source.slice(cursor, cursor + 2) === "/*") {
      const end = source.indexOf("*/", cursor + 2);
      cursor = end === -1 ? source.length : end + 2;
      continue;
    }

    break;
  }

  return cursor;
}

/**
 * Le uma string Dart simples usada como primeiro argumento da callable.
 * @param {string} source Conteudo analisado.
 * @param {number} start Posicao do argumento.
 * @return {?Object} Literal e posicao final, ou nulo.
 */
function readDartString(source, start) {
  let cursor = start;
  let raw = false;

  if ((source[cursor] === "r" || source[cursor] === "R") &&
      (source[cursor + 1] === "\"" || source[cursor + 1] === "'")) {
    raw = true;
    cursor += 1;
  }

  const quote = source[cursor];
  if (quote !== "\"" && quote !== "'") {
    return null;
  }

  cursor += 1;
  let value = "";

  while (cursor < source.length) {
    const character = source[cursor];

    if (character === quote) {
      return {
        value,
        end: cursor + 1,
        interpolated: false,
      };
    }

    if (!raw && character === "$") {
      return {
        value,
        end: cursor,
        interpolated: true,
      };
    }

    if (!raw && character === "\\") {
      if (cursor + 1 >= source.length) {
        return null;
      }
      value += source[cursor + 1];
      cursor += 2;
      continue;
    }

    if (character === "\n" || character === "\r") {
      return null;
    }

    value += character;
    cursor += 1;
  }

  return null;
}

/**
 * Resume uma expressao dinamica sem poluir o relatorio.
 * @param {string} source Conteudo analisado.
 * @param {number} start Posicao inicial da expressao.
 * @return {string} Trecho normalizado.
 */
function expressionPreview(source, start) {
  const remaining = source.slice(start, start + 160);
  const terminator = remaining.search(/[),;]/);
  const preview = terminator === -1 ?
    remaining :
    remaining.slice(0, terminator);
  return preview.replace(/\s+/g, " ").trim().slice(0, 120);
}

/**
 * Resolve a regiao esperada quando a callable usa a API Firebase diretamente.
 * Receivers injetados permanecem explicitamente inconclusivos porque sua regiao
 * pode ter sido definida fora do arquivo analisado.
 * @param {string} source Conteudo Dart.
 * @param {number} receiverEnd Inicio do acesso a httpsCallable.
 * @return {Object} Regiao esperada e origem da conclusao.
 */
function resolveCallableRegion(source, receiverEnd) {
  const windowStart = Math.max(0, receiverEnd - 600);
  const receiverSource = source.slice(windowStart, receiverEnd);
  const searchableReceiver = maskComments(receiverSource);
  const firebaseStart = searchableReceiver.lastIndexOf("FirebaseFunctions");
  const directReceiverSource = firebaseStart === -1 ? "" :
    receiverSource.slice(firebaseStart);
  const searchableDirectReceiver = firebaseStart === -1 ? "" :
    searchableReceiver.slice(firebaseStart);

  if (/^FirebaseFunctions\s*\.\s*instance\s*$/.test(
      searchableDirectReceiver,
  )) {
    return {
      expectedRegion: "us-central1",
      regionResolution: "firebase_default",
      regionSource: "FirebaseFunctions.instance",
    };
  }

  const instanceForMatch =
    /^FirebaseFunctions\s*\.\s*instanceFor\s*\(([\s\S]*)\)\s*$/.exec(
        searchableDirectReceiver,
    );
  if (instanceForMatch !== null) {
    const argumentsOffset = instanceForMatch.index +
      instanceForMatch[0].indexOf(instanceForMatch[1]);
    const argumentsSource = directReceiverSource.slice(argumentsOffset,
        argumentsOffset + instanceForMatch[1].length);
    const searchableArguments = maskComments(argumentsSource);
    const regionPattern = /\bregion\s*:/g;
    const regionMatch = regionPattern.exec(searchableArguments);

    if (regionMatch !== null) {
      const valueStart = skipTrivia(argumentsSource, regionPattern.lastIndex);
      const literal = readDartString(argumentsSource, valueStart);
      if (literal !== null && !literal.interpolated) {
        const nextToken = skipTrivia(argumentsSource, literal.end);
        const normalizedRegion = normalizeOptionalMetadata(
            literal.value,
            true,
        );
        if ((nextToken === argumentsSource.length ||
            argumentsSource[nextToken] === ",") &&
            normalizedRegion !== null) {
          return {
            expectedRegion: normalizedRegion,
            regionResolution: "instance_for_literal",
            regionSource: "FirebaseFunctions.instanceFor",
          };
        }
      }
    }

    return {
      expectedRegion: null,
      regionResolution: "inconclusive",
      regionSource: "FirebaseFunctions.instanceFor(dynamic region)",
    };
  }

  return {
    expectedRegion: null,
    regionResolution: "inconclusive",
    regionSource: "injected_or_unknown_receiver",
  };
}

/**
 * Extrai chamadas httpsCallable, inclusive quando quebradas em linhas.
 * @param {string} source Conteudo Dart.
 * @param {string} filePath Caminho exibido no relatorio.
 * @return {Object} Chamadas estaticas e dinamicas.
 */
function extractCallableCalls(source, filePath) {
  const searchableSource = maskNonCode(source);
  const pattern = /\.\s*httpsCallable\b/g;
  const staticCalls = [];
  const dynamicCalls = [];
  let match = pattern.exec(searchableSource);

  while (match !== null) {
    let openParenthesis = skipTrivia(source, pattern.lastIndex);

    if (searchableSource[openParenthesis] === "<") {
      let genericDepth = 0;
      let genericCursor = openParenthesis;

      while (genericCursor < searchableSource.length) {
        const token = searchableSource[genericCursor];
        if (token === "<") {
          genericDepth += 1;
        } else if (token === ">") {
          genericDepth -= 1;
          if (genericDepth === 0) {
            genericCursor += 1;
            break;
          }
        }
        genericCursor += 1;
      }

      if (genericDepth !== 0) {
        match = pattern.exec(searchableSource);
        continue;
      }
      openParenthesis = skipTrivia(source, genericCursor);
    }

    if (searchableSource[openParenthesis] !== "(") {
      match = pattern.exec(searchableSource);
      continue;
    }

    const argumentStart = skipTrivia(source, openParenthesis + 1);
    const literal = readDartString(source, argumentStart);
    let isStatic = literal !== null && !literal.interpolated;

    if (isStatic) {
      const nextToken = skipTrivia(source, literal.end);
      isStatic = source[nextToken] === ")" || source[nextToken] === ",";
    }

    const location = {
      path: normalizePath(filePath),
      line: lineAt(source, match.index),
    };
    const region = resolveCallableRegion(source, match.index);

    if (isStatic) {
      staticCalls.push({
        functionName: literal.value,
        path: location.path,
        line: location.line,
        expectedRegion: region.expectedRegion,
        regionResolution: region.regionResolution,
        regionSource: region.regionSource,
      });
    } else {
      dynamicCalls.push({
        expression: expressionPreview(source, argumentStart),
        path: location.path,
        line: location.line,
      });
    }

    match = pattern.exec(searchableSource);
  }

  return {
    staticCalls: staticCalls.sort(compareLocated),
    dynamicCalls: dynamicCalls.sort(compareLocated),
  };
}

/**
 * Remove pontuacao que nao pertence a uma URL encontrada no codigo.
 * @param {string} value URL bruta.
 * @return {string} URL limpa.
 */
function cleanUrl(value) {
  return value.replace(/[.,;]+$/g, "");
}

/**
 * Extrai endpoints Firebase HTTP declarados diretamente no app.
 * @param {string} source Conteudo Dart.
 * @param {string} filePath Caminho exibido no relatorio.
 * @return {Array<Object>} Endpoints encontrados.
 */
function extractHttpEndpoints(source, filePath) {
  const searchableSource = maskComments(source);
  const pattern = /https?:\/\/[^\s"'<>\\)]+/g;
  const endpoints = [];
  let match = pattern.exec(searchableSource);

  while (match !== null) {
    const value = cleanUrl(match[0]);
    let parsed;

    try {
      parsed = new URL(value);
    } catch (error) {
      match = pattern.exec(searchableSource);
      continue;
    }

    const hostname = parsed.hostname.toLowerCase();
    let platform = null;
    let targetHint = null;

    if (hostname.endsWith(".cloudfunctions.net")) {
      platform = "cloud_functions";
      targetHint = parsed.pathname.split("/").filter(Boolean)[0] || null;
    } else if (hostname.endsWith(".a.run.app")) {
      platform = "cloud_run";
      targetHint = hostname.slice(0, -".a.run.app".length);
    }

    if (platform !== null) {
      endpoints.push({
        url: value,
        platform,
        targetHint,
        path: normalizePath(filePath),
        line: lineAt(source, match.index),
      });
    }

    match = pattern.exec(searchableSource);
  }

  return endpoints.sort(compareLocated);
}

/**
 * Resolve o export associado a uma URL HTTP conhecida.
 * @param {Object} endpoint Endpoint extraido.
 * @param {Array<Object>} backendExports Exports locais.
 * @return {?Object} Export correspondente.
 */
function resolveHttpExport(endpoint, backendExports) {
  if (endpoint.platform === "cloud_functions") {
    for (const candidate of backendExports) {
      if (candidate.functionName === endpoint.targetHint) {
        return candidate;
      }
    }
    return null;
  }

  const hostService = endpoint.targetHint || "";
  const candidates = backendExports.filter((candidate) => {
    const normalized = candidate.functionName.toLowerCase();
    return hostService === normalized ||
      hostService.startsWith(`${normalized}-`);
  });

  candidates.sort((left, right) => {
    const lengthResult = right.functionName.length - left.functionName.length;
    return lengthResult !== 0 ? lengthResult :
      compareText(left.functionName, right.functionName);
  });
  return candidates[0] || null;
}

/**
 * Cria um achado de forma uniforme.
 * @param {string} code Codigo estavel.
 * @param {string} message Mensagem humana.
 * @param {Object} details Campos adicionais.
 * @return {Object} Achado do relatorio.
 */
function finding(code, message, details) {
  return Object.assign({code, message}, details);
}

/**
 * Converte um identificador implantado em nome simples de funcao.
 * @param {string} value Identificador simples ou nome completo Firebase.
 * @return {string} Nome simples da funcao.
 */
function normalizeDeployedFunctionName(value) {
  const normalized = value.trim().replace(/\/+$/g, "");
  if (normalized.length === 0) {
    throw new TypeError("Nome de funcao implantada vazio.");
  }

  const segments = normalized.split("/").filter(Boolean);
  return segments[segments.length - 1];
}

/**
 * Retorna as entradas aceitas de um snapshot do Firebase CLI.
 * @param {*} snapshot JSON lido do arquivo informado pelo usuario.
 * @return {Array<*>} Entradas implantadas.
 */
function deployedSnapshotEntries(snapshot) {
  if (Array.isArray(snapshot)) {
    return snapshot;
  }
  if (snapshot !== null && typeof snapshot === "object" &&
      Array.isArray(snapshot.result)) {
    return snapshot.result;
  }
  throw new TypeError(
      "Snapshot implantado deve ser um array ou conter result como array.",
  );
}

/**
 * Normaliza metadata textual opcional sem inventar um valor ausente.
 * @param {*} value Valor bruto.
 * @param {boolean=} lowerCase Se o valor deve ser normalizado em minusculas.
 * @return {?string} Valor conhecido ou nulo.
 */
function normalizeOptionalMetadata(value, lowerCase = false) {
  if (typeof value !== "string" || value.trim() === "") {
    return null;
  }
  const normalized = value.trim();
  return lowerCase ? normalized.toLowerCase() : normalized;
}

/**
 * Le a regiao de uma entrada do Firebase CLI ou de seu resource name.
 * @param {*} entry Entrada do snapshot.
 * @param {string} rawName Nome usado para identificar a funcao.
 * @return {?Object} Valor e campo de origem.
 */
function deployedRegion(entry, rawName) {
  if (entry !== null && typeof entry === "object") {
    const candidates = [
      [entry.region, "region"],
      [entry.location, "location"],
      [entry.locationId, "locationId"],
    ];
    for (const [value, source] of candidates) {
      const normalized = normalizeOptionalMetadata(value, true);
      if (normalized !== null) {
        return {value: normalized, source};
      }
    }
  }

  const resourceNames = [rawName];
  if (entry !== null && typeof entry === "object") {
    resourceNames.push(entry.name, entry.function, entry.functionName);
  }
  for (const resourceName of resourceNames) {
    if (typeof resourceName !== "string") {
      continue;
    }
    const match = /\/locations\/([^/]+)\/functions\//i.exec(resourceName);
    if (match !== null) {
      return {
        value: match[1].trim().toLowerCase(),
        source: "resource_name",
      };
    }
  }
  return null;
}

/**
 * Le o codebase nos formatos expostos pelo Firebase CLI.
 * @param {*} entry Entrada do snapshot.
 * @return {?Object} Valor e campo de origem.
 */
function deployedCodebase(entry) {
  if (entry === null || typeof entry !== "object") {
    return null;
  }

  const direct = normalizeOptionalMetadata(entry.codebase);
  if (direct !== null) {
    return {value: direct, source: "codebase"};
  }

  if (entry.labels !== null && typeof entry.labels === "object") {
    const labelNames = [
      "firebase-functions-codebase",
      "deployment-codebase",
    ];
    for (const labelName of labelNames) {
      const value = normalizeOptionalMetadata(entry.labels[labelName]);
      if (value !== null) {
        return {value, source: `labels.${labelName}`};
      }
    }
  }
  return null;
}

/**
 * Une entradas duplicadas sem descartar metadata conhecida ou divergente.
 * @param {Object} previous Detalhe ja registrado.
 * @param {Object} current Nova entrada do mesmo nome.
 * @return {Object} Detalhe consolidado.
 */
function mergeDeployedDetails(previous, current) {
  const merged = Object.assign({}, previous);
  if (merged.triggerType === null && current.triggerType !== null) {
    merged.triggerType = current.triggerType;
    merged.triggerKind = current.triggerKind;
    merged.triggerSource = current.triggerSource;
    if (current.eventType) {
      merged.eventType = current.eventType;
    }
  }

  for (const [field, pluralField, sourceField] of [
    ["region", "regions", "regionSource"],
    ["codebase", "codebases", "codebaseSource"],
  ]) {
    const values = new Set(previous[pluralField] || []);
    if (previous[field] !== undefined) {
      values.add(previous[field]);
    }
    if (current[field] !== undefined) {
      values.add(current[field]);
    }
    for (const value of current[pluralField] || []) {
      values.add(value);
    }

    const sortedValues = Array.from(values).sort(compareText);
    if (merged[field] === undefined && current[field] !== undefined) {
      merged[field] = current[field];
      merged[sourceField] = current[sourceField];
    }
    if (sortedValues.length > 1) {
      merged[pluralField] = sortedValues;
    }
  }
  return merged;
}

/**
 * Classifica o construtor local ou tipo normalizado de trigger.
 * @param {string} type Tipo do trigger.
 * @return {?string} Familia comparavel do trigger.
 */
function triggerKind(type) {
  if (type === "onCall") {
    return "callable";
  }
  if (type === "onRequest") {
    return "http";
  }
  if (type === "onSchedule") {
    return "schedule";
  }
  if (type === "onTaskDispatched") {
    return "task_queue";
  }
  if (/^before[A-Z]/.test(type)) {
    return "blocking";
  }
  if (/^on[A-Z]/.test(type)) {
    return "event";
  }
  return null;
}

/**
 * Normaliza um rotulo de trigger fornecido pelo snapshot.
 * @param {string} value Rotulo bruto.
 * @param {string} source Campo de origem.
 * @return {?Object} Trigger normalizado.
 */
function normalizeTriggerLabel(value, source) {
  const compact = value.trim().replace(/[\s_.-]/g, "").toLowerCase();
  const aliases = new Map([
    ["callable", {type: "onCall", kind: "callable"}],
    ["callabletrigger", {type: "onCall", kind: "callable"}],
    ["oncall", {type: "onCall", kind: "callable"}],
    ["http", {type: "onRequest", kind: "http"}],
    ["https", {type: "onRequest", kind: "http"}],
    ["httptrigger", {type: "onRequest", kind: "http"}],
    ["httpstrigger", {type: "onRequest", kind: "http"}],
    ["onrequest", {type: "onRequest", kind: "http"}],
    ["event", {type: "event", kind: "event"}],
    ["eventtrigger", {type: "event", kind: "event"}],
    ["schedule", {type: "onSchedule", kind: "schedule"}],
    ["scheduletrigger", {type: "onSchedule", kind: "schedule"}],
    ["onschedule", {type: "onSchedule", kind: "schedule"}],
    ["taskqueue", {type: "onTaskDispatched", kind: "task_queue"}],
    ["taskqueuetrigger", {
      type: "onTaskDispatched",
      kind: "task_queue",
    }],
    ["ontaskdispatched", {
      type: "onTaskDispatched",
      kind: "task_queue",
    }],
    ["blocking", {type: "blocking", kind: "blocking"}],
    ["blockingtrigger", {type: "blocking", kind: "blocking"}],
  ]);
  const alias = aliases.get(compact);

  if (alias) {
    return Object.assign({source}, alias);
  }

  const kind = triggerKind(value);
  if (kind !== null) {
    return {type: value, kind, source};
  }

  const eventType = value.trim().toLowerCase();
  if (eventType.includes("firestore") ||
      eventType.includes("firebase.database") ||
      eventType.includes("google.cloud.storage") ||
      eventType.includes("google.cloud.pubsub") ||
      eventType.includes("google.firebase")) {
    return {type: "event", kind: "event", source, eventType: value.trim()};
  }
  return null;
}

/**
 * Le metadata de trigger nos formatos comuns do Firebase CLI.
 * @param {*} entry Entrada do snapshot.
 * @return {?Object} Trigger normalizado, quando fornecido.
 */
function deployedTrigger(entry) {
  if (entry === null || typeof entry !== "object") {
    return null;
  }

  const containers = [];
  if (entry.trigger !== null && typeof entry.trigger === "object") {
    containers.push({value: entry.trigger, source: "trigger"});
  }
  containers.push({value: entry, source: "entry"});
  const triggerFields = [
    ["callableTrigger", "onCall"],
    ["httpsTrigger", "onRequest"],
    ["httpTrigger", "onRequest"],
    ["eventTrigger", "event"],
    ["scheduleTrigger", "onSchedule"],
    ["taskQueueTrigger", "onTaskDispatched"],
    ["blockingTrigger", "blocking"],
  ];

  for (const container of containers) {
    for (const [field, type] of triggerFields) {
      if (Object.prototype.hasOwnProperty.call(container.value, field)) {
        const descriptor = normalizeTriggerLabel(
            type,
            `${container.source}.${field}`,
        );
        const fieldValue = container.value[field];
        if (fieldValue !== null && typeof fieldValue === "object" &&
            typeof fieldValue.eventType === "string") {
          descriptor.eventType = fieldValue.eventType;
        }
        return descriptor;
      }
    }
  }

  const labels = [
    [entry.trigger, "trigger"],
    [entry.triggerType, "triggerType"],
    [entry.trigger && entry.trigger.type, "trigger.type"],
    [entry.trigger && entry.trigger.triggerType, "trigger.triggerType"],
  ];
  for (const [value, source] of labels) {
    if (typeof value === "string") {
      const descriptor = normalizeTriggerLabel(value, source);
      if (descriptor !== null) {
        if (entry.trigger !== null && typeof entry.trigger === "object" &&
            typeof entry.trigger.eventType === "string") {
          descriptor.eventType = entry.trigger.eventType;
        }
        return descriptor;
      }
    }
  }

  return null;
}

/**
 * Extrai metadata de um snapshot do comando firebase functions:list --json.
 * @param {*} snapshot JSON lido do arquivo informado pelo usuario.
 * @return {Array<Object>} Funcoes unicas com trigger normalizado.
 */
function extractDeployedFunctionDetails(snapshot) {
  const entries = deployedSnapshotEntries(snapshot);
  const detailsByName = new Map();
  const supportedFields = ["id", "name", "function", "functionName"];

  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index];
    let rawName = typeof entry === "string" ? entry : null;

    if (rawName === null && entry !== null && typeof entry === "object") {
      for (const field of supportedFields) {
        if (typeof entry[field] === "string" && entry[field].trim() !== "") {
          rawName = entry[field];
          break;
        }
      }
    }

    if (rawName === null) {
      throw new TypeError(
          `Entrada implantada ${index} nao possui um nome reconhecido.`,
      );
    }

    const functionName = normalizeDeployedFunctionName(rawName);
    const trigger = deployedTrigger(entry);
    const region = deployedRegion(entry, rawName);
    const codebase = deployedCodebase(entry);
    const detail = {
      functionName,
      triggerType: trigger ? trigger.type : null,
      triggerKind: trigger ? trigger.kind : null,
      triggerSource: trigger ? trigger.source : null,
    };
    if (trigger && trigger.eventType) {
      detail.eventType = trigger.eventType;
    }
    if (region !== null) {
      detail.region = region.value;
      detail.regionSource = region.source;
    }
    if (codebase !== null) {
      detail.codebase = codebase.value;
      detail.codebaseSource = codebase.source;
    }

    const previous = detailsByName.get(functionName);
    if (!previous) {
      detailsByName.set(functionName, detail);
    } else {
      detailsByName.set(
          functionName,
          mergeDeployedDetails(previous, detail),
      );
    }
  }

  return Array.from(detailsByName.values()).sort((left, right) =>
    compareText(left.functionName, right.functionName));
}

/**
 * Extrai nomes de um snapshot do comando firebase functions:list --json.
 * @param {*} snapshot JSON lido do arquivo informado pelo usuario.
 * @return {Array<string>} Nomes unicos e ordenados.
 */
function extractDeployedFunctionNames(snapshot) {
  return extractDeployedFunctionDetails(snapshot)
      .map((detail) => detail.functionName);
}

/**
 * Compara um trigger exigido pelo codigo com o trigger implantado conhecido.
 * @param {string} expectedType Construtor local ou tipo exigido pelo uso.
 * @param {Object} deployedDetail Metadata implantada.
 * @return {boolean} Verdadeiro quando compativeis ou inconclusivos.
 */
function triggersAreCompatible(expectedType, deployedDetail) {
  if (deployedDetail.triggerKind === null) {
    return true;
  }

  const expectedKind = triggerKind(expectedType);
  if (expectedKind === null) {
    return true;
  }
  if (expectedKind !== deployedDetail.triggerKind) {
    return false;
  }

  const deployedType = deployedDetail.triggerType;
  if ((expectedKind === "event" || expectedKind === "blocking") &&
      deployedType !== "event" && deployedType !== "blocking" &&
      triggerKind(deployedType) !== null) {
    return expectedType === deployedType;
  }
  return true;
}

/**
 * Retorna todos os valores conhecidos de uma metadata implantada.
 * @param {Object} detail Detalhe implantado.
 * @param {string} field Campo singular.
 * @param {string} pluralField Campo usado quando ha entradas divergentes.
 * @return {Array<string>} Valores conhecidos e unicos.
 */
function deployedMetadataValues(detail, field, pluralField) {
  const values = new Set(detail[pluralField] || []);
  if (detail[field] !== undefined && detail[field] !== null) {
    values.add(detail[field]);
  }
  return Array.from(values).sort(compareText);
}

/**
 * Verifica a regiao apenas quando app e snapshot fornecem metadata conclusiva.
 * @param {?string} expectedRegion Regiao resolvida no app.
 * @param {Object} deployedDetail Metadata implantada.
 * @return {boolean} Verdadeiro somente quando a regiao e comprovadamente igual.
 */
function regionsAreCompatible(expectedRegion, deployedDetail) {
  if (typeof expectedRegion !== "string" || expectedRegion.trim() === "") {
    return true;
  }
  const deployedRegions = deployedMetadataValues(
      deployedDetail,
      "region",
      "regions",
  );
  return deployedRegions.length > 0 &&
    deployedRegions.includes(expectedRegion.toLowerCase());
}

/**
 * Audita o contrato entre o app e o entrypoint local das Functions.
 * @param {Object} input Fontes e caminhos a analisar.
 * @return {Object} Relatorio estruturado.
 */
function auditFunctionContract(input) {
  const localCodebase = input.localCodebase === undefined ?
    "default" : normalizeOptionalMetadata(input.localCodebase);
  if (localCodebase === null) {
    throw new TypeError("localCodebase deve ser um texto nao vazio.");
  }
  const backendExports = extractBackendExports(
      input.backendSource,
      input.backendPath,
  );
  const hasDeployedSnapshot = Object.prototype.hasOwnProperty.call(
      input,
      "deployedSnapshot",
  );
  const deployedFunctionDetails = hasDeployedSnapshot ?
    extractDeployedFunctionDetails(input.deployedSnapshot) :
    null;
  const deployedFunctions = deployedFunctionDetails === null ? null :
    deployedFunctionDetails.map((detail) => detail.functionName);
  const callableCalls = [];
  const dynamicCallableCalls = [];
  const httpEndpoints = [];

  for (const appFile of input.appFiles) {
    const callables = extractCallableCalls(appFile.source, appFile.path);
    callableCalls.push(...callables.staticCalls);
    dynamicCallableCalls.push(...callables.dynamicCalls);
    httpEndpoints.push(...extractHttpEndpoints(appFile.source, appFile.path));
  }

  callableCalls.sort(compareLocated);
  dynamicCallableCalls.sort(compareLocated);
  httpEndpoints.sort(compareLocated);

  const errors = [];
  const warnings = [];
  const exportsByName = new Map();
  const staticallyUsedCallables = new Set();
  const staticallyUsedHttpExports = new Set();
  const usagesByFunction = new Map();

  /**
   * Registra um uso estatico que exige disponibilidade no deploy.
   * @param {string} functionName Nome do export.
   * @param {Object} usage Uso encontrado no app.
   * @return {void}
   */
  function registerUsage(functionName, usage) {
    const usages = usagesByFunction.get(functionName) || [];
    usages.push(usage);
    usagesByFunction.set(functionName, usages);
  }

  for (const backendExport of backendExports) {
    if (exportsByName.has(backendExport.functionName)) {
      warnings.push(finding(
          "duplicate_export",
          `Export local duplicado: ${backendExport.functionName}.`,
          backendExport,
      ));
      continue;
    }
    exportsByName.set(backendExport.functionName, backendExport);
  }

  for (const call of callableCalls) {
    registerUsage(call.functionName, Object.assign({
      expectedType: CALLABLE_TYPE,
      usageKind: "callable",
    }, call));
    if (call.regionResolution === "inconclusive") {
      const target = hasDeployedSnapshot ? errors : warnings;
      target.push(finding(
          "callable_region_inconclusive",
          hasDeployedSnapshot ?
            "Regiao da callable inconclusiva diante do snapshot implantado." :
            "Regiao da callable inconclusiva; o receiver foi injetado, " +
              "desconhecido ou usa uma regiao dinamica.",
          hasDeployedSnapshot ?
            Object.assign({severity: "blocker"}, call) : call,
      ));
    }
    const backendExport = exportsByName.get(call.functionName);

    if (!backendExport) {
      errors.push(finding(
          "missing_callable_export",
          `Callable sem export local: ${call.functionName}.`,
          Object.assign({
            expectedType: CALLABLE_TYPE,
            actualType: null,
          }, call),
      ));
      continue;
    }

    if (backendExport.type !== CALLABLE_TYPE) {
      errors.push(finding(
          "callable_type_mismatch",
          `A chamada ${call.functionName} exige um export onCall.`,
          Object.assign({
            expectedType: CALLABLE_TYPE,
            actualType: backendExport.type,
            exportPath: backendExport.path,
            exportLine: backendExport.line,
          }, call),
      ));
      continue;
    }

    staticallyUsedCallables.add(call.functionName);
  }

  for (const call of dynamicCallableCalls) {
    errors.push(finding(
        "dynamic_callable_name",
        "Nome de callable dinamico; contrato estatico nao pode ser validado.",
        Object.assign({severity: "blocker"}, call),
    ));
  }

  const deployedExportHints = deployedFunctions === null ? [] :
    deployedFunctions.map((functionName) => ({functionName}));
  const resolvedHttpEndpoints = httpEndpoints.map((endpoint) => {
    const backendExport = resolveHttpExport(endpoint, backendExports);
    const deployedExport = resolveHttpExport(endpoint, deployedExportHints);
    const resolved = Object.assign({}, endpoint, {
      matchedExport: backendExport ? backendExport.functionName : null,
    });
    if (deployedFunctions !== null) {
      resolved.matchedDeployedFunction = deployedExport ?
        deployedExport.functionName : null;
    }

    const usedFunctionName = backendExport ? backendExport.functionName :
      (deployedExport ? deployedExport.functionName : null);
    if (usedFunctionName !== null) {
      registerUsage(usedFunctionName, Object.assign({
        functionName: usedFunctionName,
        expectedType: HTTP_TYPE,
        usageKind: "http",
      }, endpoint));
    }

    if (!backendExport) {
      if (!deployedExport) {
        errors.push(finding(
            "http_export_not_found",
            "Endpoint Firebase HTTP sem export local ou implantado " +
              "identificavel.",
            Object.assign({
              severity: "blocker",
              expectedType: HTTP_TYPE,
              actualType: null,
            }, endpoint),
        ));
      } else {
        warnings.push(finding(
            "http_export_not_found",
            "Endpoint HTTP sem export local identificavel.",
            endpoint,
        ));
      }
      return resolved;
    }

    if (backendExport.type !== HTTP_TYPE) {
      errors.push(finding(
          "http_type_mismatch",
          `A URL de ${backendExport.functionName} exige um export onRequest.`,
          Object.assign({
            functionName: backendExport.functionName,
            expectedType: HTTP_TYPE,
            actualType: backendExport.type,
            exportPath: backendExport.path,
            exportLine: backendExport.line,
          }, endpoint),
      ));
    } else {
      staticallyUsedHttpExports.add(backendExport.functionName);
    }

    warnings.push(finding(
        "deployment_bound_http_url",
        "URL HTTP esta vinculada a um projeto ou deploy especifico.",
        Object.assign({
          functionName: backendExport.functionName,
        }, endpoint),
    ));
    return resolved;
  });

  for (const backendExport of backendExports) {
    if (backendExport.type === CALLABLE_TYPE &&
        !staticallyUsedCallables.has(backendExport.functionName)) {
      warnings.push(finding(
          "unused_callable_export",
          `Sem chamada estatica no app: ${backendExport.functionName}.`,
          backendExport,
      ));
    } else if (backendExport.type === HTTP_TYPE &&
        !staticallyUsedHttpExports.has(backendExport.functionName)) {
      warnings.push(finding(
          "unused_http_export",
          "Export onRequest sem consumidor HTTP estatico identificado " +
            `no app: ${backendExport.functionName}.`,
          backendExport,
      ));
    }
  }

  if (deployedFunctions !== null) {
    const deployedSet = new Set(deployedFunctions);
    const deployedByName = new Map(deployedFunctionDetails.map((detail) =>
      [detail.functionName, detail]));
    const deployedPath = normalizePath(
        input.deployedPath || "deployed-functions.json",
    );

    for (const functionName of deployedFunctions) {
      if (!exportsByName.has(functionName)) {
        errors.push(finding(
            "deployed_function_missing_locally",
            `Funcao implantada sem export local: ${functionName}.`,
            {
              severity: "blocker",
              functionName,
              path: deployedPath,
              line: 0,
            },
        ));
      }
    }

    for (const backendExport of backendExports) {
      if (!deployedSet.has(backendExport.functionName)) {
        const usages = usagesByFunction.get(backendExport.functionName) || [];
        if (usages.length > 0) {
          const firstUsage = usages.slice().sort(compareLocated)[0];
          errors.push(finding(
              "used_export_not_deployed",
              "Export usado pelo app ainda nao esta implantado: " +
                `${backendExport.functionName}.`,
              Object.assign({
                severity: "blocker",
                functionName: backendExport.functionName,
                exportPath: backendExport.path,
                exportLine: backendExport.line,
                usageKinds: Array.from(new Set(usages.map((usage) =>
                  usage.usageKind))).sort(compareText),
              }, firstUsage),
          ));
        } else {
          warnings.push(finding(
              "local_export_not_deployed",
              "Export local ainda nao implantado: " +
                `${backendExport.functionName}.`,
              backendExport,
          ));
        }
      }
    }

    for (const [functionName, deployedDetail] of deployedByName) {
      const usages = usagesByFunction.get(functionName) || [];
      const backendExport = exportsByName.get(functionName);
      const comparedTypes = new Set();
      const comparedRegions = new Set();
      const triggerUnknown = deployedDetail.triggerKind === null;
      let usageMismatch = false;

      if (backendExport) {
        const deployedCodebases = deployedMetadataValues(
            deployedDetail,
            "codebase",
            "codebases",
        );
        const divergentCodebases = deployedCodebases.filter((codebase) =>
          codebase !== localCodebase);
        if (divergentCodebases.length > 0) {
          errors.push(finding(
              "deployed_codebase_mismatch",
              `O export local ${functionName} pertence ao codebase ` +
                `${localCodebase}, mas o deploy informa ` +
                `${divergentCodebases.join(", ")}.`,
              Object.assign({
                severity: "blocker",
                functionName,
                expectedCodebase: localCodebase,
                actualCodebase: divergentCodebases.length === 1 ?
                  divergentCodebases[0] : divergentCodebases,
                deployedCodebases,
                deployedCodebaseSource: deployedDetail.codebaseSource || null,
                deployedPath,
              }, backendExport),
          ));
        }

        if (triggerUnknown) {
          const firstUsage = usages.slice().sort(compareLocated)[0];
          const location = firstUsage || backendExport;
          errors.push(finding(
              "deployed_trigger_unknown",
              `O snapshot nao informa o trigger implantado de ` +
                `${functionName}.`,
              Object.assign({
                severity: "blocker",
                functionName,
                expectedType: firstUsage ?
                  firstUsage.expectedType : backendExport.type,
                actualType: null,
                deployedTriggerKind: null,
                deployedTriggerSource: null,
                deployedPath,
                exportPath: backendExport.path,
                exportLine: backendExport.line,
                usageKinds: Array.from(new Set(usages.map((usage) =>
                  usage.usageKind))).sort(compareText),
              }, location),
          ));
        }
      }

      for (const usage of usages.slice().sort(compareLocated)) {
        if (typeof usage.expectedRegion === "string" &&
            !comparedRegions.has(usage.expectedRegion)) {
          comparedRegions.add(usage.expectedRegion);
          const deployedRegions = deployedMetadataValues(
              deployedDetail,
              "region",
              "regions",
          );
          if (deployedRegions.length === 0) {
            errors.push(finding(
                "deployed_region_unknown",
                `O snapshot nao informa a regiao implantada de ` +
                  `${functionName}.`,
                Object.assign({
                  severity: "blocker",
                  functionName,
                  expectedRegion: usage.expectedRegion,
                  actualRegion: null,
                  deployedRegions,
                  deployedRegionSource: null,
                  deployedPath,
                }, usage),
            ));
          } else if (!regionsAreCompatible(
              usage.expectedRegion,
              deployedDetail,
          )) {
            errors.push(finding(
                "deployed_region_usage_mismatch",
                `O uso de ${functionName} exige a regiao ` +
                  `${usage.expectedRegion}, mas o deploy informa ` +
                  `${deployedRegions.join(", ")}.`,
                Object.assign({
                  severity: "blocker",
                  functionName,
                  expectedRegion: usage.expectedRegion,
                  actualRegion: deployedRegions.length === 1 ?
                    deployedRegions[0] : deployedRegions,
                  deployedRegions,
                  deployedRegionSource: deployedDetail.regionSource || null,
                  deployedPath,
                }, usage),
            ));
          }
        }

        if (comparedTypes.has(usage.expectedType)) {
          continue;
        }
        comparedTypes.add(usage.expectedType);
        if (triggerUnknown ||
            triggersAreCompatible(usage.expectedType, deployedDetail)) {
          continue;
        }
        usageMismatch = true;
        errors.push(finding(
            "deployed_trigger_usage_mismatch",
            `O uso de ${functionName} exige ${usage.expectedType}, ` +
              `mas o deploy informa ${deployedDetail.triggerType}.`,
            Object.assign({
              severity: "blocker",
              functionName,
              expectedType: usage.expectedType,
              actualType: deployedDetail.triggerType,
              deployedTriggerKind: deployedDetail.triggerKind,
              deployedTriggerSource: deployedDetail.triggerSource,
              deployedPath,
            }, usage),
        ));
      }

      if (!triggerUnknown && !usageMismatch && backendExport &&
          !triggersAreCompatible(backendExport.type, deployedDetail)) {
        errors.push(finding(
            "deployed_trigger_mismatch",
            `O export local ${functionName} usa ${backendExport.type}, ` +
              `mas o deploy informa ${deployedDetail.triggerType}.`,
            Object.assign({
              severity: "blocker",
              expectedType: backendExport.type,
              actualType: deployedDetail.triggerType,
              deployedTriggerKind: deployedDetail.triggerKind,
              deployedTriggerSource: deployedDetail.triggerSource,
              deployedPath,
            }, backendExport),
        ));
      }
    }
  }

  errors.sort(compareLocated);
  warnings.sort(compareLocated);

  const summary = {
    backendExports: backendExports.length,
    callableCalls: callableCalls.length,
    dynamicCallableCalls: dynamicCallableCalls.length,
    httpEndpoints: httpEndpoints.length,
    unusedHttpExports: warnings.filter((warning) =>
      warning.code === "unused_http_export").length,
    errors: errors.length,
    warnings: warnings.length,
  };
  const report = {
    schemaVersion: 1,
    status: errors.length === 0 ? "ok" : "error",
    summary,
    backendExports,
    callableCalls,
    dynamicCallableCalls,
    httpEndpoints: resolvedHttpEndpoints,
    errors,
    warnings,
  };

  if (deployedFunctions !== null) {
    report.deployedFunctions = deployedFunctions;
    report.deployedFunctionDetails = deployedFunctionDetails;
    summary.deployedFunctions = deployedFunctions.length;
    summary.deployedMissingLocally = errors.filter((error) =>
      error.code === "deployed_function_missing_locally").length;
    summary.usedLocalNotDeployed = errors.filter((error) =>
      error.code === "used_export_not_deployed").length;
    summary.localNotDeployed = backendExports.filter((backendExport) =>
      !deployedFunctions.includes(backendExport.functionName)).length;
    summary.deployedTriggerMismatches = errors.filter((error) =>
      error.code === "deployed_trigger_mismatch" ||
      error.code === "deployed_trigger_usage_mismatch").length;
    summary.deployedTriggerUnknown = errors.filter((error) =>
      error.code === "deployed_trigger_unknown").length;
    summary.deployedRegionMismatches = errors.filter((error) =>
      error.code === "deployed_region_usage_mismatch").length;
    summary.deployedRegionUnknown = errors.filter((error) =>
      error.code === "deployed_region_unknown").length;
    summary.deployedCodebaseMismatches = errors.filter((error) =>
      error.code === "deployed_codebase_mismatch").length;
  }

  return report;
}

/**
 * Ordena chaves de objetos recursivamente.
 * @param {*} value Valor a normalizar.
 * @return {*} Valor com chaves ordenadas.
 */
function sortObjectKeys(value) {
  if (Array.isArray(value)) {
    return value.map(sortObjectKeys);
  }

  if (value === null || typeof value !== "object") {
    return value;
  }

  const sorted = {};
  for (const key of Object.keys(value).sort(compareText)) {
    sorted[key] = sortObjectKeys(value[key]);
  }
  return sorted;
}

/**
 * Serializa JSON com ordem estavel e indentacao legivel.
 * @param {*} value Valor a serializar.
 * @return {string} JSON deterministico.
 */
function stableStringify(value) {
  return JSON.stringify(sortObjectKeys(value), null, 2);
}

module.exports = {
  auditFunctionContract,
  extractBackendExports,
  extractCallableCalls,
  extractDeployedFunctionDetails,
  extractDeployedFunctionNames,
  extractHttpEndpoints,
  stableStringify,
};
