import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/dashboard/dashboard_clinica_resumo.dart';
import 'package:natus_gestantes/dashboard/dashboard_destino_filtros.dart';

void main() {
  final pacientes = <Map<String, String>>[
    {
      'nomeGestante': 'Ana',
      'statusGestante': 'Ativa',
      'especialidadeAcompanhamento': 'Clínica geral',
      'obstetraGestante': 'Dra. Carla',
      'criadoEm': '2026-08-05T10:00:00',
    },
    {
      'nomeGestante': 'Beatriz',
      'statusGestante': 'Gestante',
      'especialidadeAcompanhamento': 'Obstetrícia',
      'obstetraGestante': 'Dra. Beatriz',
      'dpp': '20/08/2026',
      'criadoEm': '2026-08-07T10:00:00',
    },
    {
      'nomeGestante': 'Caio',
      'statusGestante': 'Encerrada',
      'especialidadeAcompanhamento': 'Psicologia',
      'obstetraGestante': 'Dr. Bruno',
      'criadoEm': '2026-07-10T10:00:00',
    },
    {
      'nomeGestante': 'Daniel',
      'statusGestante': 'Ativa',
      'moduloObstetricoAtivo': 'false',
      'criadoEm': '2026-08-09T10:00:00',
    },
  ];

  test('resume a clínica sem misturar especialidades e obstetrícia', () {
    final resumo = DashboardClinicaResumo.calcular(
      pacientes,
      mes: 8,
      ano: 2026,
    );

    expect(resumo.totalPacientes, 4);
    expect(resumo.pacientesAtivos, 3);
    expect(resumo.acompanhamentosEncerrados, 1);
    expect(resumo.cadastrosNoPeriodo, 3);
    expect(resumo.pacientesObstetricia, 1);
    expect(resumo.especialidadesAtivas, 2);
    expect(resumo.pacientesSemEspecialidade, 1);
    expect(resumo.pacientesSemProfissional, 1);
    expect(Map.fromEntries(resumo.pacientesAtivosPorEspecialidade), {
      'Clínica geral': 1,
      'Obstetrícia': 1,
      especialidadeNaoInformadaDashboard: 1,
    });
  });

  test(
    'detecta obstetrícia por dados legados sem classificar paciente geral',
    () {
      expect(
        pacienteTemModuloObstetriciaDashboard({
          'statusGestante': 'Gestante',
          'dpp': '20/09/2026',
        }),
        isTrue,
      );
      expect(
        pacienteTemModuloObstetriciaDashboard({
          'statusGestante': 'Ativa',
          'moduloObstetricoAtivo': 'false',
        }),
        isFalse,
      );
      expect(
        pacienteTemModuloObstetriciaDashboard({
          'statusGestante': 'Gestante',
          'especialidadeAcompanhamento': 'Psicologia',
        }),
        isFalse,
      );
    },
  );

  test('filtros gerais levam aos pacientes correspondentes', () {
    final clinicaGeral = FiltroDashboardPacientes(
      tipo: TipoFiltroDashboardPacientes.especialidade,
      titulo: 'Clínica geral',
      valor: 'Clínica geral',
    );
    final agosto = FiltroDashboardPacientes(
      tipo: TipoFiltroDashboardPacientes.cadastroNoPeriodo,
      titulo: 'Agosto',
      mes: 8,
      ano: 2026,
    );
    const semProfissional = FiltroDashboardPacientes(
      tipo: TipoFiltroDashboardPacientes.semProfissional,
      titulo: 'Sem profissional',
    );

    expect(pacientes.where(clinicaGeral.corresponde).length, 1);
    expect(pacientes.where(agosto.corresponde).length, 3);
    expect(pacientes.where(semProfissional.corresponde).length, 1);
  });

  test('filtros obstétricos recusam registros de outras especialidades', () {
    const risco = FiltroDashboardPacientes(
      tipo: TipoFiltroDashboardPacientes.riscoGestacional,
      titulo: 'Alto risco',
      valor: 'Alto Risco',
    );
    final pacienteGeralComCampoLegado = <String, String>{
      'statusGestante': 'Ativa',
      'especialidadeAcompanhamento': 'Cardiologia',
      'riscoGestacional': 'Alto Risco',
    };

    expect(risco.corresponde(pacienteGeralComCampoLegado), isFalse);
  });
}
