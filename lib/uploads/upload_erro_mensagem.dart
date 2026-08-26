String mensagemErroUpload(String codigo) {
  final codigoNormalizado = codigo.trim().toLowerCase().replaceFirst(
    RegExp(r'^storage/'),
    '',
  );

  return switch (codigoNormalizado) {
    'unauthenticated' =>
      'Sua sessão expirou. Entre novamente para enviar o comprovante.',
    'unauthorized' || 'permission-denied' =>
      'Sua conta não tem permissão para enviar este comprovante. '
          'Verifique o vínculo com a clínica e tente novamente.',
    'canceled' || 'cancelled' => 'O envio do comprovante foi cancelado.',
    'quota-exceeded' =>
      'O armazenamento da clínica atingiu o limite disponível.',
    'retry-limit-exceeded' || 'network-request-failed' =>
      'A conexão foi interrompida durante o envio. Verifique a internet e tente novamente.',
    'invalid-checksum' || 'server-file-wrong-size' =>
      'O arquivo chegou incompleto ao servidor. Selecione-o novamente e repita o envio.',
    'bucket-not-found' || 'project-not-found' =>
      'O armazenamento do Natus não está disponível no momento.',
    _ =>
      'Não foi possível enviar o comprovante. Tente novamente em alguns instantes.',
  };
}
