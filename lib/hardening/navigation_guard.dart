import 'package:flutter/material.dart';

class NavigationGuard {
  static bool contextoValido(BuildContext? context) {
    return context != null;
  }

  static bool mountedSeguro(bool mounted) {
    return mounted == true;
  }

  static bool rotaValida(String? rota) {
    if (rota == null) {
      return false;
    }

    return rota.trim().isNotEmpty;
  }

  static bool menuValido(List<dynamic>? menus) {
    return menus != null && menus.isNotEmpty;
  }
}
