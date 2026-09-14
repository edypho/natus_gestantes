import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> salvarArquivo({
  required String nome,
  required Uint8List bytes,
  required String mimeType,
  required List<String> extensoesPermitidas,
}) async {
  final caminho = await FilePicker.platform.saveFile(
    dialogTitle: 'Salvar arquivo',
    fileName: nome,
    type: FileType.custom,
    allowedExtensions: extensoesPermitidas,
    bytes: bytes,
  );

  return caminho != null;
}
