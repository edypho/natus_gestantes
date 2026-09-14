import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> salvarArquivo({
  required String nome,
  required Uint8List bytes,
  required String mimeType,
  required List<String> extensoesPermitidas,
}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = nome
    ..style.display = 'none';

  web.document.body?.children.add(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);

  return true;
}
