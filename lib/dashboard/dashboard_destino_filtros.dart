import '../gestantes/gestantes_regras.dart' as gregras;
import '../gestantes/indicadores_gestacionais.dart' as indicadores;
import '../gestantes/maternidades_regras.dart' as maternidades;

enum TipoFiltroDashboardPacientes {
  dppProxima,
  statusNoPeriodo,
  encerradasOuHistoricoNoPeriodo,
  riscoGestacional,
  diabetesGestacional,
  nascimentoNoPeriodo,
  nascimentoNoAno,
  viaNascimento,
  obstetra,
  maternidade,
}

class FiltroDashboardPacientes {
  const FiltroDashboardPacientes({
    required this.tipo,
    required this.titulo,
    this.valor,
    this.mes,
    this.ano,
  });

  final TipoFiltroDashboardPacientes tipo;
  final String titulo;
  final String? valor;
  final int? mes;
  final int? ano;

  bool corresponde(Map<String, String> paciente) {
    switch (tipo) {
      case TipoFiltroDashboardPacientes.dppProxima:
        final status = paciente['statusGestante'] ?? 'Gestante';
        return status == 'Gestante' &&
            gregras.diasParaDpp(paciente['dpp'] ?? '') <= 14;

      case TipoFiltroDashboardPacientes.statusNoPeriodo:
        return (paciente['statusGestante'] ?? 'Gestante') == valor &&
            _dppNoPeriodo(paciente);

      case TipoFiltroDashboardPacientes.encerradasOuHistoricoNoPeriodo:
        final status = (paciente['statusGestante'] ?? 'Gestante').trim();
        return (status == 'Encerrada' ||
                status == 'Historico' ||
                status == 'Histórico') &&
            _dppNoPeriodo(paciente);

      case TipoFiltroDashboardPacientes.riscoGestacional:
        return gregras.gestanteEstaAtiva(paciente) &&
            indicadores.normalizarRiscoGestacional(
                  paciente['riscoGestacional'],
                ) ==
                valor;

      case TipoFiltroDashboardPacientes.diabetesGestacional:
        return gregras.gestanteEstaAtiva(paciente) &&
            indicadores.normalizarDiabetesGestacional(
                  paciente['diabetesGestacional'],
                ) ==
                valor;

      case TipoFiltroDashboardPacientes.nascimentoNoPeriodo:
        final data = _dataNascimento(paciente);
        return data != null && data.month == mes && data.year == ano;

      case TipoFiltroDashboardPacientes.nascimentoNoAno:
        final data = _dataNascimento(paciente);
        return data != null && data.year == ano;

      case TipoFiltroDashboardPacientes.viaNascimento:
        return _normalizarViaNascimento(paciente['viaNascimento']) == valor;

      case TipoFiltroDashboardPacientes.obstetra:
        return gregras.gestantePertenceAoObstetra(paciente, valor ?? '');

      case TipoFiltroDashboardPacientes.maternidade:
        final maternidadePaciente = maternidades.normalizarMaternidade(
          paciente['hospitalGestante'],
        );
        final maternidadeFiltro = maternidades.normalizarMaternidade(valor);
        return maternidadePaciente != null &&
            maternidadeFiltro != null &&
            maternidadePaciente.chave == maternidadeFiltro.chave;
    }
  }

  bool _dppNoPeriodo(Map<String, String> paciente) {
    final data = gregras.converterDataDashboard(
      gregras.primeiraDataPreenchida(paciente, [
        'dpp',
        'DPP',
        'dataDpp',
        'dataDPP',
      ]),
    );

    return data != null && data.month == mes && data.year == ano;
  }

  DateTime? _dataNascimento(Map<String, String> paciente) {
    return gregras.converterDataDashboard(
      gregras.primeiraDataPreenchida(paciente, [
        'dataNascimentoBebe',
        'dataNascimento',
      ]),
    );
  }
}

String normalizarViaNascimentoDashboard(String? valor) {
  return _normalizarViaNascimento(valor);
}

String _normalizarViaNascimento(String? valor) {
  final via = (valor ?? '').trim().toLowerCase();

  if (via.isEmpty || via == 'nao informado' || via == 'não informado') {
    return 'Não informado';
  }

  if (via.contains('ces')) return 'Cesárea';
  if (via.contains('casa') || via.contains('domicil')) return 'Domiciliar';
  if (via.contains('normal') ||
      via.contains('vaginal') ||
      via.contains('vagianl') ||
      via.contains('vagina') ||
      via.contains('parto')) {
    return 'Normal';
  }

  return 'Não informado';
}
