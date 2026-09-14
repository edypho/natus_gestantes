import '../dashboard/dashboard_destino_filtros.dart';
import '../gestantes/gestantes_regras.dart';

List<Map<String, String>> ordenarEFiltrarPacientes({
  required Iterable<Map<String, String>> pacientes,
  required String statusSelecionado,
  required String planoSelecionado,
  required String busca,
  FiltroDashboardPacientes? filtroDashboard,
}) {
  final lista = pacientes.toList(growable: false)..sort(_compararPacientes);

  return lista
      .where((paciente) {
        final status = statusGestanteNormalizado(paciente);
        if (statusSelecionado == 'Ativas') {
          if (!gestanteEstaAtiva(paciente)) return false;
        } else if (statusSelecionado != 'Todas' &&
            status != statusSelecionado) {
          return false;
        }

        if (filtroDashboard != null && !filtroDashboard.corresponde(paciente)) {
          return false;
        }

        if (planoSelecionado != 'Todos' &&
            (paciente['plano'] ?? '').trim() != planoSelecionado) {
          return false;
        }

        return gestanteApareceNaBusca(paciente, busca);
      })
      .toList(growable: false);
}

int _compararPacientes(
  Map<String, String> pacienteA,
  Map<String, String> pacienteB,
) {
  final statusA = statusGestanteNormalizado(pacienteA);
  final statusB = statusGestanteNormalizado(pacienteB);
  final porStatus = _prioridadeStatus(
    statusA,
  ).compareTo(_prioridadeStatus(statusB));
  if (porStatus != 0) return porStatus;

  if (statusA == 'Gestante') {
    return diasParaDpp(
      pacienteA['dpp'] ?? '',
    ).compareTo(diasParaDpp(pacienteB['dpp'] ?? ''));
  }

  return (pacienteA['nomeGestante'] ?? '').toLowerCase().compareTo(
    (pacienteB['nomeGestante'] ?? '').toLowerCase(),
  );
}

int _prioridadeStatus(String status) => switch (status) {
  'Gestante' => 1,
  'Puérpera' => 2,
  'Histórico' => 3,
  'Encerrada' => 4,
  _ => 5,
};
