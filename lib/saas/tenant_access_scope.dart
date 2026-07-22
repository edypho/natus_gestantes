import 'contexto_saas.dart';

class TenantScopeException implements Exception {
  const TenantScopeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Escopo de acesso imutável calculado a partir do usuário autenticado.
///
/// Usuários comuns sempre recebem uma clínica. A ausência ou divergência de
/// vínculo é tratada como erro, nunca como autorização global.
class TenantAccessScope {
  const TenantAccessScope._({
    required this.uidUsuario,
    required this.perfil,
    required this.clinicaId,
    required this.pacienteId,
    required this.acessoGlobal,
  });

  factory TenantAccessScope.fromContexto(ContextoSaaS contexto) {
    final uid = contexto.uidUsuario.trim();
    if (uid.isEmpty) {
      throw const TenantScopeException('Usuário autenticado sem UID.');
    }

    const perfisConhecidos = <String>{
      'admin',
      'enfermeira',
      'obstetra',
      'profissional',
      'gestante',
      'superAdmin',
    };

    if (!perfisConhecidos.contains(contexto.perfil)) {
      throw const TenantScopeException('Perfil de usuário não reconhecido.');
    }

    final perfilSuperAdmin = contexto.perfil == 'superAdmin';
    if (perfilSuperAdmin != contexto.superAdmin) {
      throw const TenantScopeException(
        'Credencial de Super Admin inconsistente.',
      );
    }

    if (perfilSuperAdmin) {
      return TenantAccessScope._(
        uidUsuario: uid,
        perfil: contexto.perfil,
        clinicaId: '',
        pacienteId: '',
        acessoGlobal: true,
      );
    }

    if (!contexto.vinculoClinicaConsistente) {
      throw const TenantScopeException(
        'Os vínculos de clínica do usuário são divergentes.',
      );
    }

    final clinica = contexto.adminDonoId.trim().isNotEmpty
        ? contexto.adminDonoId.trim()
        : contexto.clinicaId.trim();

    if (clinica.isEmpty) {
      throw const TenantScopeException(
        'Usuário sem clínica vinculada. O acesso foi bloqueado.',
      );
    }

    final pacienteId = contexto.pacienteId.trim();
    if (contexto.perfil == 'gestante' && !contexto.vinculoPacienteConsistente) {
      throw const TenantScopeException(
        'Os identificadores do paciente são divergentes. O acesso foi bloqueado.',
      );
    }
    if (contexto.perfil == 'gestante' && pacienteId.isEmpty) {
      throw const TenantScopeException(
        'Paciente sem cadastro vinculado. O acesso foi bloqueado.',
      );
    }

    return TenantAccessScope._(
      uidUsuario: uid,
      perfil: contexto.perfil,
      clinicaId: clinica,
      pacienteId: pacienteId,
      acessoGlobal: false,
    );
  }

  final String uidUsuario;
  final String perfil;
  final String clinicaId;
  final String pacienteId;
  final bool acessoGlobal;

  bool get ehPaciente => perfil == 'gestante';

  bool pertenceAoTenant(Map<String, dynamic> dados) {
    if (acessoGlobal) return true;

    final admin = (dados['adminDonoId'] ?? '').toString().trim();
    final clinica = (dados['clinicaId'] ?? '').toString().trim();
    if (admin.isNotEmpty && clinica.isNotEmpty && admin != clinica) {
      return false;
    }
    final tenantRegistro = admin.isNotEmpty ? admin : clinica;

    return tenantRegistro.isNotEmpty && tenantRegistro == clinicaId;
  }

  Map<String, dynamic> aplicarEmDados(
    Map<String, dynamic> dados, {
    String? clinicaAlvo,
  }) {
    final tenant = acessoGlobal ? (clinicaAlvo ?? '').trim() : clinicaId;

    if (tenant.isEmpty) {
      throw const TenantScopeException(
        'A gravação exige uma clínica de destino.',
      );
    }

    return <String, dynamic>{
      ...dados,
      'clinicaId': tenant,
      'adminDonoId': tenant,
    };
  }

  Map<String, String> aplicarEmTextos(
    Map<String, String> dados, {
    String? clinicaAlvo,
  }) {
    final tenant = acessoGlobal ? (clinicaAlvo ?? '').trim() : clinicaId;

    if (tenant.isEmpty) {
      throw const TenantScopeException(
        'A gravação exige uma clínica de destino.',
      );
    }

    return <String, String>{
      ...dados,
      'clinicaId': tenant,
      'adminDonoId': tenant,
    };
  }

  /// Remove campos de propriedade que nunca podem ser alterados pelo cliente.
  ///
  /// O tenant é definido apenas na criação. Em uma atualização, reenviá-lo
  /// permitiria que um documento fosse movido (ou reivindicado) por outra
  /// clínica antes de as regras de segurança validarem a propriedade existente.
  Map<String, dynamic> protegerAtualizacao(Map<String, dynamic> dados) {
    return <String, dynamic>{...dados}
      ..remove('clinicaId')
      ..remove('adminDonoId')
      ..remove('criadoPorUid');
  }

  Map<String, String> protegerAtualizacaoTexto(Map<String, String> dados) {
    return <String, String>{...dados}
      ..remove('clinicaId')
      ..remove('adminDonoId')
      ..remove('criadoPorUid');
  }

  String caminhoStorage(String caminhoRelativo) {
    if (acessoGlobal || clinicaId.isEmpty) {
      throw const TenantScopeException(
        'O upload exige uma clínica de destino.',
      );
    }

    final partes = caminhoRelativo
        .replaceAll('\\', '/')
        .split('/')
        .where((parte) => parte.trim().isNotEmpty)
        .map((parte) => parte.trim())
        .toList();

    if (partes.any((parte) => parte == '.' || parte == '..')) {
      throw const TenantScopeException('Caminho de upload inválido.');
    }

    final relativo = partes.join('/');

    if (relativo.isEmpty) {
      throw const TenantScopeException('Caminho de upload inválido.');
    }

    return 'clinicas/$clinicaId/$relativo';
  }
}
