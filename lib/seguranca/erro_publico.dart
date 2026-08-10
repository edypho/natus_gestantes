import 'package:cloud_functions/cloud_functions.dart';

String mensagemErroFunctionsSeguro(
  FirebaseFunctionsException erro, {
  required String fallback,
}) {
  return switch (erro.code) {
    'unauthenticated' => 'Sua sessão expirou. Entre novamente.',
    'permission-denied' => 'Você não possui permissão para esta operação.',
    'invalid-argument' => 'Revise os dados informados e tente novamente.',
    'already-exists' => 'Já existe um cadastro com esses dados.',
    'failed-precondition' =>
      'A operação não pode ser concluída no estado atual.',
    'not-found' => 'O registro solicitado não foi encontrado.',
    'resource-exhausted' =>
      'Muitas solicitações em pouco tempo. Aguarde e tente novamente.',
    'unavailable' => 'Serviço temporariamente indisponível. Tente novamente.',
    _ => fallback,
  };
}
