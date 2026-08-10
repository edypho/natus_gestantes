import 'dart:typed_data';

bool arquivoPossuiAssinaturaPermitida(Uint8List bytes, String mimeType) {
  return switch (mimeType.toLowerCase()) {
    'application/pdf' => _comecaCom(bytes, const [
      0x25,
      0x50,
      0x44,
      0x46,
      0x2D,
    ]),
    'image/jpeg' => _comecaCom(bytes, const [0xFF, 0xD8, 0xFF]),
    'image/png' => _comecaCom(bytes, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]),
    'image/webp' =>
      _textoAscii(bytes, 0, 4) == 'RIFF' && _textoAscii(bytes, 8, 4) == 'WEBP',
    'video/mp4' => _textoAscii(bytes, 4, 4) == 'ftyp',
    _ => false,
  };
}

bool _comecaCom(Uint8List bytes, List<int> assinatura) {
  if (bytes.length < assinatura.length) return false;
  for (var index = 0; index < assinatura.length; index++) {
    if (bytes[index] != assinatura[index]) return false;
  }
  return true;
}

String _textoAscii(Uint8List bytes, int inicio, int tamanho) {
  if (inicio < 0 || tamanho <= 0 || bytes.length < inicio + tamanho) return '';
  return String.fromCharCodes(bytes.sublist(inicio, inicio + tamanho));
}
