import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase_globals.dart';

typedef PushForegroundHandler = void Function(RemoteMessage message);

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  static const String _configPath = 'integracoes/push';
  static const List<String> _tiposSuportados = <String>[
    'admin',
    'superAdmin',
    'enfermeira',
    'obstetra',
    'gestante',
  ];

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String _uidInicializado = '';

  static bool get plataformaSuportada {
    if (kIsWeb) return true;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  bool _tipoSuportado(String tipoUsuario) {
    return _tiposSuportados.contains(tipoUsuario);
  }

  Future<void> inicializarParaUsuario({
    required String tipoUsuario,
    required String nomeUsuario,
    PushForegroundHandler? onForegroundMessage,
  }) async {
    if (!plataformaSuportada || !_tipoSuportado(tipoUsuario)) {
      return;
    }

    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    final configuradoMesmoUsuario = _uidInicializado == usuario.uid;

    if (!configuradoMesmoUsuario) {
      final permissao = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      await _salvarEstadoPermissao(
        uid: usuario.uid,
        tipoUsuario: tipoUsuario,
        nomeUsuario: nomeUsuario,
        status: permissao.authorizationStatus.name,
      );

      if (permissao.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push: permissao negada para ${usuario.uid}.');
        return;
      }

      final token = await _obterToken();
      if (token != null && token.isNotEmpty) {
        await _registrarToken(
          uid: usuario.uid,
          tipoUsuario: tipoUsuario,
          nomeUsuario: nomeUsuario,
          token: token,
        );
      }
    }

    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage?.call(message);
    });

    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
        .listen((novoToken) async {
          final usuarioAtual = FirebaseAuth.instance.currentUser;
          if (usuarioAtual == null || novoToken.trim().isEmpty) return;

          await _registrarToken(
            uid: usuarioAtual.uid,
            tipoUsuario: tipoUsuario,
            nomeUsuario: nomeUsuario,
            token: novoToken,
          );
        });

    _uidInicializado = usuario.uid;
  }

  Future<String?> _obterToken() async {
    try {
      if (kIsWeb) {
        final vapidPublicKey = await _buscarVapidPublicKey();
        if (vapidPublicKey.isEmpty) {
          debugPrint('Push: vapidPublicKey nao configurada em $_configPath.');
          return null;
        }

        return FirebaseMessaging.instance.getToken(vapidKey: vapidPublicKey);
      }

      return FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Push: erro ao obter token FCM: $e');
      return null;
    }
  }

  Future<String> _buscarVapidPublicKey() async {
    try {
      final snapshot = await firestore.doc(_configPath).get();
      final dados = snapshot.data();
      return (dados?['vapidPublicKey'] ?? '').toString().trim();
    } catch (e) {
      debugPrint('Push: erro ao buscar vapidPublicKey: $e');
      return '';
    }
  }

  Future<void> _salvarEstadoPermissao({
    required String uid,
    required String tipoUsuario,
    required String nomeUsuario,
    required String status,
  }) async {
    await firestore.collection('usuarios').doc(uid).set({
      'uid': uid,
      'nome': nomeUsuario,
      'tipo': tipoUsuario,
      'tipoUsuario': tipoUsuario,
      'pushPermissao': status,
      'pushSuportadoNaPlataforma': plataformaSuportada,
      'pushPermissaoAtualizadaEm': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> _registrarToken({
    required String uid,
    required String tipoUsuario,
    required String nomeUsuario,
    required String token,
  }) async {
    final agora = DateTime.now().toIso8601String();

    await firestore.collection('usuarios').doc(uid).set({
      'uid': uid,
      'nome': nomeUsuario,
      'tipo': tipoUsuario,
      'tipoUsuario': tipoUsuario,
      'pushAtivo': true,
      'pushTokens': FieldValue.arrayUnion(<String>[token]),
      'pushUltimoToken': token,
      'pushPlataforma': _nomePlataformaAtual(),
      'pushAtualizadoEm': agora,
      'pushPermissao': 'autorizado',
    }, SetOptions(merge: true));
  }

  String _nomePlataformaAtual() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.windows:
        return 'windows';
    }
  }
}
