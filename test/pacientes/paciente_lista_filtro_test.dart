import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/pacientes/paciente_lista_filtro.dart';

void main() {
  final pacientes = <Map<String, String>>[
    {
      'nomeGestante': 'Carla',
      'statusGestante': 'Encerrada',
      'plano': 'Presença',
    },
    {
      'nomeGestante': 'Bianca',
      'statusGestante': 'Gestante',
      'plano': 'Plenitude',
      'dpp': '20/12/2030',
    },
    {
      'nomeGestante': 'Ana',
      'statusGestante': 'Gestante',
      'plano': 'Presença',
      'dpp': '10/12/2030',
    },
  ];

  test('ordena por status e DPP sem alterar a lista recebida', () {
    final resultado = ordenarEFiltrarPacientes(
      pacientes: pacientes,
      statusSelecionado: 'Todas',
      planoSelecionado: 'Todos',
      busca: '',
    );

    expect(resultado.map((item) => item['nomeGestante']), [
      'Ana',
      'Bianca',
      'Carla',
    ]);
    expect(pacientes.first['nomeGestante'], 'Carla');
  });

  test('combina status, plano e busca', () {
    final resultado = ordenarEFiltrarPacientes(
      pacientes: pacientes,
      statusSelecionado: 'Ativas',
      planoSelecionado: 'Presença',
      busca: 'ana',
    );

    expect(resultado.single['nomeGestante'], 'Ana');
  });
}
