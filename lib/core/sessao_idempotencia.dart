import 'dart:math';

/// Mantém o mesmo identificador enquanto uma submissão permanece inalterada.
///
/// Uma correção no formulário muda a assinatura e, portanto, inicia uma nova
/// operação. Uma simples repetição após falha de rede reutiliza o mesmo ID.
class SessaoIdempotencia {
  SessaoIdempotencia({String Function()? gerarId})
    : _gerarId = gerarId ?? gerarUuidV4;

  final String Function() _gerarId;
  String? _ultimaAssinatura;
  String? _ultimoId;

  String idParaAssinatura(String assinatura) {
    if (assinatura != _ultimaAssinatura || _ultimoId == null) {
      _ultimaAssinatura = assinatura;
      _ultimoId = _gerarId();
    }
    return _ultimoId!;
  }

  void reiniciar() {
    _ultimaAssinatura = null;
    _ultimoId = null;
  }
}

/// Gera um UUID v4 sem adicionar uma dependência ao aplicativo.
String gerarUuidV4() {
  final aleatorio = Random.secure();
  final bytes = List<int>.generate(16, (_) => aleatorio.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hexadecimal = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hexadecimal.substring(0, 8)}-'
      '${hexadecimal.substring(8, 12)}-'
      '${hexadecimal.substring(12, 16)}-'
      '${hexadecimal.substring(16, 20)}-'
      '${hexadecimal.substring(20)}';
}
