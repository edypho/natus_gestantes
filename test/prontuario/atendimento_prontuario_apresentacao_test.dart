import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/prontuario/atendimento_prontuario_apresentacao.dart';

void main() {
  group('camposClinicosDoAtendimento', () {
    test('apresenta anamnese com rótulos clínicos e sem metadados', () {
      final campos = camposClinicosDoAtendimento({
        'tipo': 'Anamnese',
        'queixaPrincipal': 'Azia e dor no cóccix',
        'historicoObstetrico': 'G1. Mãe teve parto normal.',
        'aspectosEmocionais': 'Mãe e tia como rede de apoio.',
        'clinicaId': 'clinica-interna',
        'adminDonoId': 'clinica-interna',
        'uidGestante': 'uid-interno',
        'criadoPorUid': 'uid-profissional',
      });

      expect(campos.map((campo) => campo.rotulo), [
        'Queixa principal',
        'Histórico obstétrico',
        'Aspectos emocionais e rede de apoio',
      ]);
      expect(campos.map((campo) => campo.valor), [
        'Azia e dor no cóccix',
        'G1. Mãe teve parto normal.',
        'Mãe e tia como rede de apoio.',
      ]);
      expect(
        campos.any(
          (campo) => const {
            'clinicaId',
            'adminDonoId',
            'uidGestante',
            'criadoPorUid',
          }.contains(campo.chave),
        ),
        isFalse,
      );
    });

    test('omite valores vazios e usa os rótulos do exame físico', () {
      final campos = camposClinicosDoAtendimento({
        'tipo': 'Exame físico',
        'pa': '120/80 mmHg',
        'fc': '  ',
        'bcf': '148 bpm',
        'observacoes': null,
      });

      expect(campos.map((campo) => '${campo.rotulo}: ${campo.valor}'), [
        'Pressão arterial: 120/80 mmHg',
        'Batimentos cardiofetais (BCF): 148 bpm',
      ]);
    });

    test(
      'tipo desconhecido continua restrito aos campos clínicos conhecidos',
      () {
        final campos = camposClinicosDoAtendimento({
          'tipo': 'Registro legado',
          'queixaPrincipal': 'Náusea',
          'observacoes': 'Acompanhamento mantido.',
          'segredoInterno': 'não pode aparecer',
        });

        expect(campos.map((campo) => campo.chave), [
          'queixaPrincipal',
          'observacoes',
        ]);
        expect(
          campos.any((campo) => campo.valor == 'não pode aparecer'),
          isFalse,
        );
      },
    );
  });
}
