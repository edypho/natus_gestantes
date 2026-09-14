import 'dart:typed_data';

Future<bool> salvarArquivo({
  required String nome,
  required Uint8List bytes,
  required String mimeType,
  required List<String> extensoesPermitidas,
}) {
  throw UnsupportedError('Plataforma sem suporte para salvar arquivos.');
}
