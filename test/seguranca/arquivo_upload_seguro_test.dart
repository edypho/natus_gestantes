import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/seguranca/arquivo_upload_seguro.dart';

void main() {
  test('reconhece assinaturas permitidas', () {
    expect(
      arquivoPossuiAssinaturaPermitida(
        Uint8List.fromList('%PDF-1.7'.codeUnits),
        'application/pdf',
      ),
      isTrue,
    );
    expect(
      arquivoPossuiAssinaturaPermitida(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        'image/jpeg',
      ),
      isTrue,
    );
    expect(
      arquivoPossuiAssinaturaPermitida(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        'image/png',
      ),
      isTrue,
    );
    expect(
      arquivoPossuiAssinaturaPermitida(
        Uint8List.fromList('RIFF0000WEBP'.codeUnits),
        'image/webp',
      ),
      isTrue,
    );
    expect(
      arquivoPossuiAssinaturaPermitida(
        Uint8List.fromList([0, 0, 0, 24, ...'ftyp'.codeUnits]),
        'video/mp4',
      ),
      isTrue,
    );
  });

  test('rejeita conteudo executavel renomeado e arquivo truncado', () {
    final executavel = Uint8List.fromList('MZ executable'.codeUnits);
    for (final mime in [
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
      'video/mp4',
    ]) {
      expect(arquivoPossuiAssinaturaPermitida(executavel, mime), isFalse);
    }
    expect(
      arquivoPossuiAssinaturaPermitida(Uint8List(0), 'application/pdf'),
      isFalse,
    );
  });
}
