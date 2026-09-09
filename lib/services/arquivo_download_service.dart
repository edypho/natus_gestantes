import 'dart:typed_data';

import 'arquivo_download_service_stub.dart'
    if (dart.library.io) 'arquivo_download_service_io.dart'
    if (dart.library.js_interop) 'arquivo_download_service_web.dart'
    as plataforma;

Future<bool> salvarArquivo({
  required String nome,
  required Uint8List bytes,
  required String mimeType,
  required List<String> extensoesPermitidas,
}) {
  return plataforma.salvarArquivo(
    nome: nome,
    bytes: bytes,
    mimeType: mimeType,
    extensoesPermitidas: extensoesPermitidas,
  );
}
