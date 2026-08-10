import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/gestantes/gestantes_regras.dart';

void main() {
  group('normalizarNomeProfissional', () {
    test('remove pronomes de tratamento e normaliza espaços', () {
      expect(normalizarNomeProfissional('Dr. Lucas  Almeida'), 'lucas almeida');
      expect(
        normalizarNomeProfissional('DRA. Fernanda Costa'),
        'fernanda costa',
      );
      expect(normalizarNomeProfissional('  doutor João '), 'joão');
      expect(normalizarNomeProfissional('Lucas Almeida'), 'lucas almeida');
    });
  });

  group('gestantePertenceAoObstetra', () {
    final g = {'obstetraGestante': 'Dr. Lucas Almeida'};

    test('casa com e sem pronome, ignorando caixa', () {
      expect(gestantePertenceAoObstetra(g, 'Lucas Almeida'), isTrue);
      expect(gestantePertenceAoObstetra(g, 'dr. lucas almeida'), isTrue);
      expect(gestantePertenceAoObstetra(g, 'Dra. Fernanda Costa'), isFalse);
    });

    test('nome vazio ou campo ausente não casa', () {
      expect(gestantePertenceAoObstetra(g, ''), isFalse);
      expect(gestantePertenceAoObstetra({}, 'Lucas Almeida'), isFalse);
    });
  });

  group('filtrarGestantesPorPerfil', () {
    final gestantes = [
      {'nomeGestante': 'Maria', 'obstetraGestante': 'Dr. Lucas Almeida'},
      {'nomeGestante': 'Ana', 'obstetraGestante': 'Dra. Fernanda Costa'},
      {'nomeGestante': 'Julia', 'obstetraGestante': ''},
    ];

    test('obstetra vê apenas a própria carteira', () {
      final visiveis = filtrarGestantesPorPerfil(
        gestantes,
        tipoUsuario: 'obstetra',
        nomeUsuario: 'Lucas Almeida',
      );
      expect(visiveis.length, 1);
      expect(visiveis.first['nomeGestante'], 'Maria');
    });

    test('admin e enfermeira veem tudo', () {
      for (final tipo in ['admin', 'enfermeira', 'superAdmin']) {
        expect(
          filtrarGestantesPorPerfil(
            gestantes,
            tipoUsuario: tipo,
            nomeUsuario: 'Lucas Almeida',
          ).length,
          3,
        );
      }
    });

    test('obstetra sem nome não vê ninguém (fecha por segurança)', () {
      expect(
        filtrarGestantesPorPerfil(
          gestantes,
          tipoUsuario: 'obstetra',
          nomeUsuario: '',
        ).length,
        0,
      );
    });
  });
}
