import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'log_seguro.dart';

const String _recaptchaEnterpriseSiteKey = String.fromEnvironment(
  'NATUS_RECAPTCHA_ENTERPRISE_SITE_KEY',
);

const bool _webRecaptchaEnterpriseAtivo = bool.fromEnvironment(
  'NATUS_ENABLE_WEB_APP_CHECK',
  defaultValue: false,
);

const bool _androidPlayIntegrityAtivo = bool.fromEnvironment(
  'NATUS_ENABLE_ANDROID_APP_CHECK',
  defaultValue: false,
);

Future<bool> ativarFirebaseAppCheck() async {
  final plataformaNativaSuportada = <TargetPlatform>{
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  }.contains(defaultTargetPlatform);

  if (!kIsWeb && !plataformaNativaSuportada) return false;

  if (kIsWeb && !kDebugMode && !_webRecaptchaEnterpriseAtivo) {
    logInfoSeguro(
      'App Check Web aguardando validacao do provedor no Firebase.',
    );
    return false;
  }

  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !kDebugMode &&
      !_androidPlayIntegrityAtivo) {
    logInfoSeguro(
      'App Check Android aguardando distribuição compatível com Play Integrity.',
    );
    return false;
  }

  final siteKey = _recaptchaEnterpriseSiteKey.trim();
  if (kIsWeb && !kDebugMode && siteKey.isEmpty) {
    logInfoSeguro(
      'App Check Web aguardando a chave publica do reCAPTCHA Enterprise.',
    );
    return false;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: kDebugMode
          ? WebDebugProvider()
          : ReCaptchaEnterpriseProvider(siteKey),
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    return true;
  } catch (erro) {
    logErroSeguro('Não foi possível ativar o App Check.', erro);
    return false;
  }
}
