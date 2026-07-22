/// Compatibilidade temporária para código legado.
///
/// A criação de usuários no cliente foi desativada. Novas clínicas e seus
/// administradores devem ser criados exclusivamente pela Cloud Function
/// autenticada `criarClinicaComAdminSaaS`.
@Deprecated('Use SuperAdminRepository.criarClinicaComAdmin.')
class SuperAdminAuthService {
  @Deprecated('A criação direta no Firebase Auth foi desativada.')
  Future<Never> criarAdminClinicaAuth({
    required String email,
    required String senhaTemporaria,
  }) async {
    throw UnsupportedError(
      'Criação direta de usuário desativada. Use o backend autenticado.',
    );
  }
}
