import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const String _googleMapsWebApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_WEB_API_KEY',
);

Future<bool>? _carregamento;

Future<bool> carregarGoogleMapsWeb() => _carregamento ??= _carregar();

Future<bool> _carregar() async {
  final apiKey = _googleMapsWebApiKey.trim();
  if (!RegExp(r'^AIza[0-9A-Za-z_-]{30,100}$').hasMatch(apiKey)) return false;

  final existente = web.document.querySelector(
    'script[data-natus-google-maps="true"]',
  );
  if (existente != null) return true;

  final completer = Completer<bool>();
  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script
    ..src = Uri.https('maps.googleapis.com', '/maps/api/js', {
      'key': apiKey,
      'loading': 'async',
      'v': 'weekly',
    }).toString()
    ..async = true
    ..defer = true
    ..dataset['natusGoogleMaps'] = 'true';

  script.addEventListener(
    'load',
    ((web.Event _) => completer.complete(true)).toJS,
    web.AddEventListenerOptions(once: true),
  );
  script.addEventListener(
    'error',
    ((web.Event _) => completer.complete(false)).toJS,
    web.AddEventListenerOptions(once: true),
  );
  web.document.head?.append(script);

  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () => false,
  );
}
