String normalizarTelefoneWhatsAppBrasil(String telefone) {
  final somenteDigitos = telefone.replaceAll(RegExp(r'[^0-9]'), '');
  if (somenteDigitos.isEmpty ||
      (somenteDigitos.startsWith('55') && somenteDigitos.length > 11)) {
    return somenteDigitos;
  }
  return '55$somenteDigitos';
}

String mensagemRedefinicaoSenhaPaciente({
  required String nome,
  required String email,
}) {
  return 'Olá, ${nome.trim()}! 🤍\n\n'
      'Enviamos para ${email.trim().toLowerCase()} um e-mail seguro para criar '
      'ou trocar sua senha de acesso ao Portal Natus.\n\n'
      'Confira também a caixa de spam. Por segurança, o link não é enviado '
      'pelo WhatsApp.\n\n'
      'Com carinho,\n'
      'Equipe Natus';
}

Uri uriWhatsAppRedefinicaoSenhaPaciente({
  required String telefone,
  required String nome,
  required String email,
}) {
  final numero = normalizarTelefoneWhatsAppBrasil(telefone);
  return Uri.https('wa.me', '/$numero', {
    'text': mensagemRedefinicaoSenhaPaciente(nome: nome, email: email),
  });
}
