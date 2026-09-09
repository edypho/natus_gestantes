String normalizarEmailAcesso(String email) => email.trim().toLowerCase();

({String email, String senha}) credenciaisAcesso({
  required String email,
  required String senha,
}) {
  return (email: normalizarEmailAcesso(email), senha: senha);
}

bool emailAcessoValido(String email) {
  final emailNormalizado = normalizarEmailAcesso(email);
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(emailNormalizado);
}

const mensagemRedefinicaoSenhaSolicitada =
    'Se o e-mail estiver cadastrado, você receberá um link para redefinir a '
    'senha. Confira também a caixa de spam.';

String mensagemErroLogin(String codigo) {
  return switch (codigo) {
    'invalid-email' => 'Informe um e-mail válido.',
    'too-many-requests' =>
      'Muitas tentativas de acesso. Aguarde alguns minutos e tente novamente.',
    'network-request-failed' =>
      'Não foi possível conectar. Verifique sua internet e tente novamente.',
    _ => 'E-mail ou senha inválidos.',
  };
}

String mensagemErroRedefinicaoSenha(String codigo) {
  return switch (codigo) {
    'invalid-email' => 'Informe um e-mail válido.',
    'too-many-requests' =>
      'Muitas solicitações. Aguarde alguns minutos e tente novamente.',
    'network-request-failed' =>
      'Não foi possível conectar. Verifique sua internet e tente novamente.',
    'user-not-found' => mensagemRedefinicaoSenhaSolicitada,
    _ => 'Não foi possível solicitar a redefinição de senha agora.',
  };
}

String mensagemErroEnvioAcessoParaEquipe(String codigo) {
  return switch (codigo) {
    'invalid-email' => 'O cadastro não possui um e-mail válido.',
    'user-not-found' =>
      'Não existe um login vinculado a esse e-mail. Revise o cadastro.',
    'too-many-requests' =>
      'Muitas solicitações. Aguarde alguns minutos e tente novamente.',
    'network-request-failed' =>
      'Não foi possível conectar. Verifique sua internet e tente novamente.',
    _ => 'Não foi possível enviar o e-mail de acesso agora.',
  };
}
