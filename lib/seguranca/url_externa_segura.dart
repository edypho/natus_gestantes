const int _tamanhoMaximoUrlExterna = 2048;
const Set<String> _hostsMidiaNatusPermitidos = {
  'firebasestorage.googleapis.com',
  'storage.googleapis.com',
};
const String _bucketMidiaNatus = 'natus-gestantes.firebasestorage.app';

Uri? uriHttpsExternaSegura(String valor, {Set<String>? hostsPermitidos}) {
  final texto = valor.trim();
  if (texto.isEmpty || texto.length > _tamanhoMaximoUrlExterna) return null;
  if (texto.runes.any((code) => code < 32 || code == 127)) return null;

  final uri = Uri.tryParse(texto);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }

  final host = uri.host.toLowerCase();
  if (hostsPermitidos != null &&
      !hostsPermitidos.map((item) => item.toLowerCase()).contains(host)) {
    return null;
  }

  return uri;
}

Uri? uriMidiaNatusSegura(String valor) {
  final uri = uriHttpsExternaSegura(
    valor,
    hostsPermitidos: _hostsMidiaNatusPermitidos,
  );
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  if (host == 'firebasestorage.googleapis.com') {
    return uri.path.startsWith('/v0/b/$_bucketMidiaNatus/o/') ? uri : null;
  }

  return uri.path.startsWith('/$_bucketMidiaNatus/') ? uri : null;
}

bool uriExternaPermitida(
  Uri uri, {
  bool permitirTelefone = false,
  Set<String>? hostsHttpsPermitidos,
}) {
  if (uri.scheme.toLowerCase() == 'https') {
    return uriHttpsExternaSegura(
          uri.toString(),
          hostsPermitidos: hostsHttpsPermitidos,
        ) !=
        null;
  }

  if (!permitirTelefone || uri.scheme.toLowerCase() != 'tel') return false;
  if (uri.hasAuthority || uri.hasQuery || uri.hasFragment) return false;
  return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(uri.path);
}
