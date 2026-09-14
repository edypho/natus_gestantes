import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/pacientes/paciente_lista_paginacao.dart';

void main() {
  test('monta somente a primeira página sem descartar a lista original', () {
    final pacientes = List<int>.generate(80, (indice) => indice);

    final visiveis = pacientesVisiveis(pacientes, 30);

    expect(visiveis, hasLength(30));
    expect(pacientes, hasLength(80));
    expect(visiveis.last, 29);
  });

  test('avanço respeita o total e não cria página vazia', () {
    expect(proximoLimitePacientes(30, 80), 60);
    expect(proximoLimitePacientes(60, 80), 80);
    expect(proximoLimitePacientes(80, 80), 80);
    expect(proximoLimitePacientes(0, 0), 0);
  });
}
