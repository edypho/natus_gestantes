import 'dart:convert';

import 'package:http/http.dart' as http;

class EnderecoCep {
  const EnderecoCep({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.estado,
  });

  final String cep;
  final String logradouro;
  final String bairro;
  final String cidade;
  final String estado;

  bool get possuiLogradouro => logradouro.isNotEmpty;

  EnderecoCep combinarCom(EnderecoCep outro) {
    return EnderecoCep(
      cep: cep.isNotEmpty ? cep : outro.cep,
      logradouro: logradouro.isNotEmpty ? logradouro : outro.logradouro,
      bairro: bairro.isNotEmpty ? bairro : outro.bairro,
      cidade: cidade.isNotEmpty ? cidade : outro.cidade,
      estado: estado.isNotEmpty ? estado : outro.estado,
    );
  }
}

class CepService {
  CepService({http.Client? client, this.timeout = const Duration(seconds: 8)})
    : _client = client;

  final http.Client? _client;
  final Duration timeout;

  Future<EnderecoCep?> buscar(String cep) async {
    final cepLimpo = cep.replaceAll(RegExp(r'\D'), '');
    if (cepLimpo.length != 8) return null;

    final client = _client ?? http.Client();
    EnderecoCep? enderecoParcial;

    try {
      for (final consulta in <Future<EnderecoCep?> Function()>[
        () => _consultarViaCep(client, cepLimpo),
        () => _consultarBrasilApi(client, cepLimpo),
      ]) {
        try {
          final endereco = await consulta().timeout(timeout);
          if (endereco == null) continue;

          enderecoParcial = enderecoParcial == null
              ? endereco
              : enderecoParcial.combinarCom(endereco);

          if (enderecoParcial.possuiLogradouro) return enderecoParcial;
        } catch (_) {
          // A próxima fonte é consultada quando esta estiver indisponível.
        }
      }

      return enderecoParcial;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<EnderecoCep?> _consultarViaCep(http.Client client, String cep) async {
    final response = await client.get(
      Uri.https('viacep.com.br', '/ws/$cep/json/'),
    );
    if (response.statusCode != 200) return null;

    final data = _decodificarObjeto(response.body);
    if (data == null || data['erro'] == true || data['erro'] == 'true') {
      return null;
    }

    return EnderecoCep(
      cep: _texto(data['cep'], fallback: cep),
      logradouro: _texto(data['logradouro']),
      bairro: _texto(data['bairro']),
      cidade: _texto(data['localidade']),
      estado: _texto(data['uf']).toUpperCase(),
    );
  }

  Future<EnderecoCep?> _consultarBrasilApi(
    http.Client client,
    String cep,
  ) async {
    final response = await client.get(
      Uri.https('brasilapi.com.br', '/api/cep/v2/$cep'),
    );
    if (response.statusCode != 200) return null;

    final data = _decodificarObjeto(response.body);
    if (data == null) return null;

    return EnderecoCep(
      cep: _texto(data['cep'], fallback: cep),
      logradouro: _texto(data['street']),
      bairro: _texto(data['neighborhood']),
      cidade: _texto(data['city']),
      estado: _texto(data['state']).toUpperCase(),
    );
  }

  Map<String, dynamic>? _decodificarObjeto(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  String _texto(dynamic valor, {String fallback = ''}) {
    final texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? fallback : texto;
  }
}
