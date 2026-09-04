import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/exames/exame_arquivo.dart';

void main() {
  const gestante = {
    'id': 'gestante-1',
    'uidGestante': 'uid-1',
    'nomeGestante': 'Júlia da Silva',
  };

  test('exame antigo sem nome é vinculado pelo ID da gestante', () {
    final exame = ExameArquivo.fromExame('exame-1', {
      'idGestante': 'gestante-1',
      'nomeArquivo': 'ultrassom.pdf',
      'url': 'https://arquivos/exame-1',
      'criadoEm': '2026-07-14T10:30:00.000',
    });

    expect(exame.pertenceA(gestante), isTrue);
    expect(exame.nomeGestanteResolvido([gestante]), 'Júlia da Silva');
  });

  test('documento legado do tipo exame é vinculado pelo nome normalizado', () {
    final documento = <String, String>{
      'id': 'documento-1',
      'tipo': 'EXAME',
      'gestante': '  julia da silva ',
      'arquivoNome': 'hemograma.pdf',
      'arquivoUrl': 'https://arquivos/documento-1',
      'data': '14/07/2026 09:15',
    };

    expect(ExameArquivo.documentoEhExame(documento), isTrue);

    final exame = ExameArquivo.fromDocumento(documento);
    expect(exame.pertenceA(gestante), isTrue);
    expect(exame.dataExibicao, '14/07/2026');
  });

  test('não associa exame a outra gestante', () {
    final exame = ExameArquivo.fromExame('exame-2', {
      'idGestante': 'outra-gestante',
      'uidGestante': 'outro-uid',
      'nomeGestante': 'Outra Pessoa',
    });

    expect(exame.pertenceA(gestante), isFalse);
  });

  test('ID divergente não é associado apenas porque o nome é igual', () {
    final exame = ExameArquivo.fromExame('exame-2', {
      'idGestante': 'outra-gestante',
      'nomeGestante': 'Júlia da Silva',
    });

    expect(exame.pertenceA(gestante), isFalse);
  });

  test('agrupa origens diferentes pela identidade canônica do paciente', () {
    final atual = ExameArquivo.fromExame('exame-1', {
      'idGestante': 'gestante-1',
      'nomeArquivo': 'ultrassom.pdf',
      'criadoEm': '2026-07-15T10:00:00.000',
    });
    final legado = ExameArquivo.fromDocumento({
      'id': 'documento-1',
      'tipo': 'Exame',
      'gestante': 'Júlia da Silva',
      'arquivoNome': 'hemograma.pdf',
      'data': '14/07/2026 09:15',
    });

    final grupos = agruparExamesPorPaciente([atual, legado], [gestante]);

    expect(grupos, hasLength(1));
    expect(grupos.single.chavePaciente, 'id:gestante-1');
    expect(grupos.single.nomePaciente, 'Júlia da Silva');
    expect(grupos.single.exames.map((exame) => exame.nomeArquivo), [
      'ultrassom.pdf',
      'hemograma.pdf',
    ]);
  });

  test('mantém pacientes homônimos separados quando há IDs', () {
    const outraGestante = {
      'id': 'gestante-2',
      'uidGestante': 'uid-2',
      'nomeGestante': 'Júlia da Silva',
    };
    final exames = [
      ExameArquivo.fromExame('exame-1', {
        'idGestante': 'gestante-1',
        'nomeGestante': 'Júlia da Silva',
      }),
      ExameArquivo.fromExame('exame-2', {
        'idGestante': 'gestante-2',
        'nomeGestante': 'Júlia da Silva',
      }),
    ];

    final grupos = agruparExamesPorPaciente(exames, [gestante, outraGestante]);

    expect(grupos, hasLength(2));
    expect(grupos.map((grupo) => grupo.chavePaciente).toSet(), {
      'id:gestante-1',
      'id:gestante-2',
    });
  });

  test('remove duplicidade entre coleções usando a URL do arquivo', () {
    final atual = ExameArquivo.fromExame('exame-1', {
      'idGestante': 'gestante-1',
      'url': 'https://arquivos/mesmo-exame',
    });
    final legado = ExameArquivo.fromDocumento({
      'id': 'documento-1',
      'tipo': 'Exame',
      'gestante': 'Júlia da Silva',
      'arquivoUrl': 'https://arquivos/mesmo-exame',
    });

    expect(removerExamesDuplicados([atual, legado]), hasLength(1));
  });
}
