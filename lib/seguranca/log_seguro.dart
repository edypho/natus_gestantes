import 'package:flutter/foundation.dart';

/// Registra apenas contexto operacional em builds de desenvolvimento.
///
/// O objeto de erro nunca é serializado, evitando que mensagens de SDKs
/// revelem e-mail, caminho de documento, token, URL assinada ou dados clínicos.
void logErroSeguro(String contexto, [Object? erro]) {
  if (!kDebugMode) return;
  final tipoErro = erro == null ? '' : ' [${erro.runtimeType}]';
  debugPrint('$contexto$tipoErro');
}

void logInfoSeguro(String mensagem) {
  if (!kDebugMode) return;
  debugPrint(mensagem);
}
