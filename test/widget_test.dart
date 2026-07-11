import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/main.dart';

void main() {
  group('normalizarTipoUsuarioNatus', () {
    test('normaliza variações de superadmin', () {
      expect(normalizarTipoUsuarioNatus('superadmin'), 'superAdmin');
      expect(normalizarTipoUsuarioNatus('super_admin'), 'superAdmin');
      expect(normalizarTipoUsuarioNatus('SUPERADMIN'), 'superAdmin');
    });

    test('mantém tipos conhecidos', () {
      expect(normalizarTipoUsuarioNatus('admin'), 'admin');
      expect(normalizarTipoUsuarioNatus('enfermeira'), 'enfermeira');
      expect(normalizarTipoUsuarioNatus('gestante'), 'gestante');
      expect(normalizarTipoUsuarioNatus('obstetra'), 'obstetra');
      expect(normalizarTipoUsuarioNatus('OBSTETRA'), 'obstetra');
    });

    test('profissional da clínica: enfermeira e obstetra', () {
      expect(tipoEhProfissionalClinica('enfermeira'), isTrue);
      expect(tipoEhProfissionalClinica('obstetra'), isTrue);
      expect(tipoEhProfissionalClinica('Obstetra '), isTrue);
      expect(tipoEhProfissionalClinica('admin'), isFalse);
      expect(tipoEhProfissionalClinica('gestante'), isFalse);
    });

    test('nulo ou vazio vira gestante', () {
      expect(normalizarTipoUsuarioNatus(null), 'gestante');
      expect(normalizarTipoUsuarioNatus(''), 'gestante');
      expect(normalizarTipoUsuarioNatus('   '), 'gestante');
    });

    test('valores desconhecidos são preservados', () {
      expect(normalizarTipoUsuarioNatus('fisioterapeuta'), 'fisioterapeuta');
    });
  });
}
