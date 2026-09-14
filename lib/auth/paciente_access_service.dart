import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../saas/tenant_access_scope.dart';

class PacienteAccessFailure implements Exception {
  const PacienteAccessFailure(this.message);

  final String message;
}

class PacienteAccessResult {
  const PacienteAccessResult({
    required this.email,
    required this.nome,
    required this.telefone,
    required this.acessoCriado,
  });

  final String email;
  final String nome;
  final String telefone;
  final bool acessoCriado;
}

class PacienteAccessService {
  PacienteAccessService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
    required TenantAccessScope escopoTenant,
  }) : _firestore = firestore,
       _auth = auth,
       _functions = functions,
       _escopoTenant = escopoTenant;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final TenantAccessScope _escopoTenant;

  Future<PacienteAccessResult> enviar(String pacienteId) async {
    final id = pacienteId.trim();
    if (id.isEmpty) {
      throw const PacienteAccessFailure('ID do paciente não encontrado.');
    }

    final snapshot = await _firestore.collection('gestantes').doc(id).get();
    if (!snapshot.exists) {
      throw const PacienteAccessFailure('Paciente não encontrado no Firebase.');
    }

    final dados = snapshot.data() ?? <String, dynamic>{};
    if (!_escopoTenant.pertenceAoTenant(dados)) {
      throw const PacienteAccessFailure(
        'Cadastro fora da clínica autenticada.',
      );
    }

    final nome = dados['nomeGestante']?.toString().trim() ?? '';
    final telefone = dados['telefoneGestante']?.toString().trim() ?? '';
    final email = dados['emailGestante']?.toString().trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      throw const PacienteAccessFailure('E-mail do paciente não informado.');
    }
    if (_auth.currentUser == null) {
      throw const PacienteAccessFailure(
        'Usuário não autenticado. Faça login novamente.',
      );
    }

    final uidsVinculados = <String>{
      dados['uidPaciente']?.toString().trim() ?? '',
      dados['pacienteUid']?.toString().trim() ?? '',
      dados['uidGestante']?.toString().trim() ?? '',
    }..remove('');
    final acessoCriado = uidsVinculados.isEmpty;

    if (acessoCriado) {
      final respostaCriacao = await _functions
          .httpsCallable('criarUsuarioClinica')
          .call(<String, dynamic>{
            'nome': nome,
            'email': email,
            'tipo': 'gestante',
            'idVinculo': id,
            'operacaoId': 'recuperar_acesso_$id',
          });
      final dadosCriacao = Map<String, dynamic>.from(
        respostaCriacao.data as Map,
      );
      if (dadosCriacao['sucesso'] != true) {
        throw const PacienteAccessFailure(
          'Não foi possível criar o acesso do paciente.',
        );
      }
    }

    final resposta = await _functions
        .httpsCallable('solicitarRedefinicaoSenhaPaciente')
        .call(<String, dynamic>{'pacienteId': id});
    final dadosResposta = Map<String, dynamic>.from(resposta.data as Map);
    if (dadosResposta['sucesso'] != true) {
      throw PacienteAccessFailure(
        dadosResposta['mensagem']?.toString() ??
            'Não foi possível solicitar a redefinição de senha.',
      );
    }

    final emailValidado =
        dadosResposta['emailPaciente']?.toString().trim().toLowerCase() ?? '';
    if (emailValidado.isEmpty) {
      throw const PacienteAccessFailure(
        'O cadastro não possui um e-mail válido.',
      );
    }

    await _auth.sendPasswordResetEmail(email: emailValidado);
    return PacienteAccessResult(
      email: emailValidado,
      nome: dadosResposta['nomePaciente']?.toString().trim() ?? nome,
      telefone:
          dadosResposta['telefonePaciente']?.toString().trim() ?? telefone,
      acessoCriado: acessoCriado,
    );
  }
}
