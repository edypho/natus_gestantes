import '../core/natus_especialidades.dart';
import '../gestantes/gestantes_regras.dart' as regras;

const String especialidadeNaoInformadaDashboard = 'Sem especialidade informada';

class DashboardClinicaResumo {
  const DashboardClinicaResumo({
    required this.totalPacientes,
    required this.pacientesAtivos,
    required this.acompanhamentosEncerrados,
    required this.cadastrosNoPeriodo,
    required this.pacientesSemEspecialidade,
    required this.pacientesSemProfissional,
    required this.pacientesObstetricia,
    required this.pacientesAtivosPorEspecialidade,
    required this.pacientesAtivosPorProfissional,
  });

  final int totalPacientes;
  final int pacientesAtivos;
  final int acompanhamentosEncerrados;
  final int cadastrosNoPeriodo;
  final int pacientesSemEspecialidade;
  final int pacientesSemProfissional;
  final int pacientesObstetricia;
  final List<MapEntry<String, int>> pacientesAtivosPorEspecialidade;
  final List<MapEntry<String, int>> pacientesAtivosPorProfissional;

  int get especialidadesAtivas => pacientesAtivosPorEspecialidade
      .where((item) => item.key != especialidadeNaoInformadaDashboard)
      .length;

  bool get possuiModuloObstetricia => pacientesObstetricia > 0;

  factory DashboardClinicaResumo.calcular(
    Iterable<Map<String, String>> pacientes, {
    required int mes,
    required int ano,
  }) {
    final lista = pacientes.toList(growable: false);
    final ativos = lista
        .where(regras.gestanteEstaAtiva)
        .toList(growable: false);
    final porEspecialidade = <String, int>{};
    final porProfissional = <String, int>{};

    for (final paciente in ativos) {
      final especialidade = especialidadePacienteDashboard(paciente);
      porEspecialidade[especialidade] =
          (porEspecialidade[especialidade] ?? 0) + 1;

      final profissional = profissionalResponsavelDashboard(paciente);
      if (profissional.isNotEmpty) {
        porProfissional[profissional] =
            (porProfissional[profissional] ?? 0) + 1;
      }
    }

    return DashboardClinicaResumo(
      totalPacientes: lista.length,
      pacientesAtivos: ativos.length,
      acompanhamentosEncerrados: lista.length - ativos.length,
      cadastrosNoPeriodo: lista.where((paciente) {
        final data = dataCadastroPacienteDashboard(paciente);
        return data != null && data.month == mes && data.year == ano;
      }).length,
      pacientesSemEspecialidade: ativos
          .where(
            (paciente) =>
                especialidadePacienteDashboard(paciente) ==
                especialidadeNaoInformadaDashboard,
          )
          .length,
      pacientesSemProfissional: ativos
          .where(
            (paciente) => profissionalResponsavelDashboard(paciente).isEmpty,
          )
          .length,
      pacientesObstetricia: lista
          .where(pacienteTemModuloObstetriciaDashboard)
          .length,
      pacientesAtivosPorEspecialidade: _ordenarContagens(porEspecialidade),
      pacientesAtivosPorProfissional: _ordenarContagens(
        porProfissional,
      ).take(5).toList(growable: false),
    );
  }
}

List<MapEntry<String, int>> _ordenarContagens(Map<String, int> dados) {
  final itens = dados.entries.toList();
  itens.sort((a, b) {
    final porQuantidade = b.value.compareTo(a.value);
    if (porQuantidade != 0) return porQuantidade;
    return a.key.toLowerCase().compareTo(b.key.toLowerCase());
  });
  return itens;
}

String especialidadePacienteDashboard(Map<String, String> paciente) {
  final especialidade =
      (paciente['especialidadeAcompanhamento'] ??
              paciente['tipoCadastroPaciente'] ??
              '')
          .trim();

  if (especialidade.isNotEmpty) return especialidade;
  if (pacienteTemModuloObstetriciaDashboard(paciente)) {
    return NatusEspecialidades.obstetricia;
  }

  return especialidadeNaoInformadaDashboard;
}

bool pacienteTemModuloObstetriciaDashboard(Map<String, String> paciente) {
  final especialidade =
      (paciente['especialidadeAcompanhamento'] ??
              paciente['tipoCadastroPaciente'] ??
              '')
          .trim();
  if (especialidade.isNotEmpty) {
    return NatusEspecialidades.ehObstetricia(especialidade);
  }

  final modulo = (paciente['moduloObstetricoAtivo'] ?? '').trim().toLowerCase();
  if (const {'true', 'sim', '1'}.contains(modulo)) return true;
  if (const {'false', 'não', 'nao', '0'}.contains(modulo)) return false;

  if ((paciente['dpp'] ?? '').trim().isNotEmpty) return true;

  final status = (paciente['statusGestante'] ?? '').trim().toLowerCase();
  return status.contains('gestante') ||
      status.contains('puérpera') ||
      status.contains('puerpera');
}

String profissionalResponsavelDashboard(Map<String, String> paciente) {
  for (final campo in const [
    'profissionalResponsavel',
    'nomeProfissional',
    'obstetraGestante',
    'enfermeiraGestante',
  ]) {
    final valor = (paciente[campo] ?? '').trim();
    if (valor.isNotEmpty && valor.toLowerCase() != 'selecione') return valor;
  }
  return '';
}

DateTime? dataCadastroPacienteDashboard(Map<String, String> paciente) {
  for (final campo in const [
    'criadoEm',
    'dataCadastro',
    'cadastradoEm',
    'createdAt',
  ]) {
    final data = regras.converterDataDashboard(paciente[campo]);
    if (data != null) return data;
  }
  return null;
}
