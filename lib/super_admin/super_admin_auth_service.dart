import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'super_admin_auth_config.dart';

class SuperAdminAuthService {
  static const String appSecundarioNome = 'superAdminCriacaoUsuarioSaaS';

  Future<UserCredential> criarAdminClinicaAuth({
    required String email,
    required String senhaTemporaria,
  }) async {
    FirebaseApp appSecundario;

    try {
      appSecundario = Firebase.app(appSecundarioNome);
    } catch (_) {
      appSecundario = await Firebase.initializeApp(
        name: appSecundarioNome,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final authSecundario = FirebaseAuth.instanceFor(
      app: appSecundario,
    );

    try {
      final credencial = await authSecundario.createUserWithEmailAndPassword(
        email: email,
        password: senhaTemporaria,
      );

      await authSecundario.signOut();

      return credencial;
    } catch (_) {
      await authSecundario.signOut();
      rethrow;
    }
  }
}
