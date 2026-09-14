import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/seguranca/url_externa_segura.dart';

void main() {
  group('uriHttpsExternaSegura', () {
    test('aceita HTTPS bem formado', () {
      final uri = uriHttpsExternaSegura(
        'https://firebasestorage.googleapis.com/v0/b/teste/o/doc.pdf?token=x',
      );
      expect(uri?.scheme, 'https');
    });

    test('rejeita esquemas ativos, credenciais e porta arbitraria', () {
      expect(uriHttpsExternaSegura('javascript:alert(1)'), isNull);
      expect(uriHttpsExternaSegura('data:text/html,teste'), isNull);
      expect(uriHttpsExternaSegura('file:///etc/passwd'), isNull);
      expect(uriHttpsExternaSegura('https://user:pass@example.com/a'), isNull);
      expect(uriHttpsExternaSegura('https://example.com:8443/a'), isNull);
    });

    test('aplica allowlist de host quando informada', () {
      expect(
        uriHttpsExternaSegura(
          'https://wa.me/5511999999999',
          hostsPermitidos: const {'wa.me'},
        ),
        isNotNull,
      );
      expect(
        uriHttpsExternaSegura(
          'https://evil.example/5511999999999',
          hostsPermitidos: const {'wa.me'},
        ),
        isNull,
      );
    });
  });

  group('uriMidiaNatusSegura', () {
    test('aceita somente o bucket controlado no Firebase Storage', () {
      expect(
        uriMidiaNatusSegura(
          'https://firebasestorage.googleapis.com/v0/b/'
          'natus-gestantes.firebasestorage.app/o/capa.png',
        ),
        isNotNull,
      );
      expect(
        uriMidiaNatusSegura(
          'https://storage.googleapis.com/'
          'natus-gestantes.firebasestorage.app/capa.png',
        ),
        isNotNull,
      );
      expect(
        uriMidiaNatusSegura('https://rastreador.example/capa.png'),
        isNull,
      );
      expect(
        uriMidiaNatusSegura(
          'https://firebasestorage.googleapis.com/v0/b/atacante/o/capa.png',
        ),
        isNull,
      );
      expect(
        uriMidiaNatusSegura(
          'https://storage.googleapis.com/bucket-atacante/capa.png',
        ),
        isNull,
      );
    });
  });

  test('telefone aceita apenas numero internacional ou nacional', () {
    expect(
      uriExternaPermitida(
        Uri(scheme: 'tel', path: '+5511999999999'),
        permitirTelefone: true,
      ),
      isTrue,
    );
    expect(
      uriExternaPermitida(
        Uri.parse('tel:123;phone-context=evil'),
        permitirTelefone: true,
      ),
      isFalse,
    );
  });
}
