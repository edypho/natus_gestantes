import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/core/sessao_idempotencia.dart';

void main() {
  test('repetição da mesma submissão reutiliza o identificador', () {
    var contador = 0;
    final sessao = SessaoIdempotencia(gerarId: () => 'id-${++contador}');

    expect(sessao.idParaAssinatura('payload-a'), 'id-1');
    expect(sessao.idParaAssinatura('payload-a'), 'id-1');
    expect(contador, 1);
  });

  test('submissão corrigida recebe um identificador novo', () {
    var contador = 0;
    final sessao = SessaoIdempotencia(gerarId: () => 'id-${++contador}');

    expect(sessao.idParaAssinatura('payload-a'), 'id-1');
    expect(sessao.idParaAssinatura('payload-b'), 'id-2');
    sessao.reiniciar();
    expect(sessao.idParaAssinatura('payload-b'), 'id-3');
  });

  test('gerador produz UUID v4 válido e não repetido', () {
    final primeiro = gerarUuidV4();
    final segundo = gerarUuidV4();
    final formato = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
      r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(primeiro, matches(formato));
    expect(segundo, matches(formato));
    expect(segundo, isNot(primeiro));
  });
}
