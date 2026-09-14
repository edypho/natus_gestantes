import '../kpis/kpis_calculos.dart';
import 'dashboard_clinica_resumo.dart';

class DashboardDadosCalculados {
  const DashboardDadosCalculados({
    required this.versao,
    required this.mes,
    required this.ano,
    required this.pacientesObstetricia,
    required this.resumo,
    required this.pacientesPorPlano,
    required this.recebidoMes,
    required this.aReceberMes,
    required this.atrasadoMes,
    required this.parcelasAtrasadas,
    required this.percentualInadimplencia,
    required this.pacientesProximosDpp,
    required this.amamentacao,
    required this.crescimentoNascimentos,
    required this.nascimentosPorMes,
    required this.viaNascimento,
    required this.riscoGestacional,
    required this.diabetesGestacional,
    required this.maternidades,
    required this.gestantesNoPeriodo,
    required this.puerperasNoPeriodo,
    required this.encerradosNoPeriodo,
    required this.nascimentosNoPeriodo,
    required this.nascimentosNoAno,
  });

  final int versao;
  final int mes;
  final int ano;
  final List<Map<String, String>> pacientesObstetricia;
  final DashboardClinicaResumo resumo;
  final List<MapEntry<String, int>> pacientesPorPlano;
  final double recebidoMes;
  final double aReceberMes;
  final double atrasadoMes;
  final int parcelasAtrasadas;
  final double percentualInadimplencia;
  final int pacientesProximosDpp;
  final Map<String, int> amamentacao;
  final CrescimentoNascimentosKpis crescimentoNascimentos;
  final Map<int, Map<int, int>> nascimentosPorMes;
  final Map<String, int> viaNascimento;
  final Map<String, int> riscoGestacional;
  final Map<String, int> diabetesGestacional;
  final List<MapEntry<String, int>> maternidades;
  final int gestantesNoPeriodo;
  final int puerperasNoPeriodo;
  final int encerradosNoPeriodo;
  final int nascimentosNoPeriodo;
  final int nascimentosNoAno;
}
