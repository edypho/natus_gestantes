import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/core/natus_terminologia.dart';

void main() {
  test('rotula a experiência principal com linguagem clínica genérica', () {
    expect(NatusTermos.rotuloMenu('Gestantes'), 'Pacientes');
    expect(NatusTermos.rotuloMenu('Cadastro'), 'Cadastrar paciente');
    expect(NatusTermos.rotuloMenu('Área da gestante'), 'Meu acompanhamento');
  });

  test('preserva a rota técnica quando não existe tradução visual', () {
    expect(NatusTermos.rotuloMenu('Agenda'), 'Agenda');
    expect(NatusTermos.rotuloMenu('Prontuário'), 'Prontuário');
  });

  test('traduz perfis legados sem mudar seus identificadores', () {
    expect(NatusTermos.rotuloPerfil('gestante'), 'Paciente');
    expect(NatusTermos.rotuloPerfil('enfermeira'), 'Profissional');
    expect(NatusTermos.rotuloPerfil('obstetra'), 'Profissional');
    expect(NatusTermos.rotuloPerfil('admin'), 'Admin da clínica');
  });

  test('traduz status legados apenas para apresentação', () {
    expect(
      NatusTermos.rotuloStatusPaciente('Gestante'),
      'Acompanhamento obstétrico',
    );
    expect(NatusTermos.rotuloStatusPaciente('Puérpera'), 'Pós-parto');
    expect(NatusTermos.rotuloStatusPaciente('Encerrada'), 'Encerrada');
  });
}
