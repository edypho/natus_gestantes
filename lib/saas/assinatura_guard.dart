import 'assinatura_saas.dart';

class AssinaturaGuard {
  static bool podeAcessarSistema(AssinaturaSaaS? assinatura) {
    if (assinatura == null) {
      return true;
    }

    return assinatura.status == StatusAssinaturaSaaS.ativa ||
        assinatura.status == StatusAssinaturaSaaS.teste;
  }

  static bool deveMostrarAlertaVencimento(AssinaturaSaaS? assinatura) {
    if (assinatura == null || assinatura.vencimento == null) {
      return false;
    }

    final dias = assinatura.vencimento!.difference(DateTime.now()).inDays;

    return dias <= 7 && dias >= 0;
  }
}
