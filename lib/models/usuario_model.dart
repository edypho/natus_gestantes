class UsuarioModel {
  final String uid;
  final String nome;
  final String email;
  final String tipoUsuario;
  final String adminDonoId;

  const UsuarioModel({
    required this.uid,
    required this.nome,
    required this.email,
    required this.tipoUsuario,
    required this.adminDonoId,
  });

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      uid: map['uid']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      tipoUsuario: map['tipoUsuario']?.toString() ?? '',
      adminDonoId: map['adminDonoId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nome': nome,
      'email': email,
      'tipoUsuario': tipoUsuario,
      'adminDonoId': adminDonoId,
    };
  }
}
