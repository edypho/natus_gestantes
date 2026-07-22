/// Normalização dos tipos de usuário do Natus.
String normalizarTipoUsuarioNatus(String? tipo) {
  final valor = (tipo ?? '').trim();

  if (valor.isEmpty) return 'gestante';

  final lower = valor.toLowerCase();

  if (lower == 'superadmin' || lower == 'super_admin') {
    return 'superAdmin';
  }

  if (lower == 'admin') return 'admin';
  if (lower == 'enfermeira') return 'enfermeira';
  if (lower == 'obstetra') return 'obstetra';
  if (lower == 'profissional') return 'profissional';
  if (lower == 'gestante' || lower == 'paciente') return 'gestante';

  return valor;
}

/// Profissionais da clínica compartilham as mesmas telas e permissões
/// operacionais (enfermeira e obstetra).
bool tipoEhProfissionalClinica(String tipo) {
  final t = tipo.trim().toLowerCase();
  return t == 'enfermeira' || t == 'obstetra' || t == 'profissional';
}
