import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:natus_gestantes/services/cep_service.dart';

void main() {
  test('normaliza o CEP e retorna o endereço do ViaCEP', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://viacep.com.br/ws/01001000/json/');
      return http.Response(
        '{"cep":"01001-000","logradouro":"Praça da Sé",'
        '"bairro":"Sé","localidade":"São Paulo","uf":"SP"}',
        200,
      );
    });

    final endereco = await CepService(client: client).buscar('01001-000');

    expect(endereco?.logradouro, 'Praça da Sé');
    expect(endereco?.cidade, 'São Paulo');
    expect(endereco?.estado, 'SP');
  });

  test('usa a BrasilAPI quando o ViaCEP não responde com sucesso', () async {
    final requisicoes = <String>[];
    final client = MockClient((request) async {
      requisicoes.add(request.url.host);
      if (request.url.host == 'viacep.com.br') {
        return http.Response('indisponível', 503);
      }
      return http.Response(
        '{"cep":"30140071","street":"Rua dos Aimorés",'
        '"neighborhood":"Funcionários","city":"Belo Horizonte",'
        '"state":"MG"}',
        200,
      );
    });

    final endereco = await CepService(client: client).buscar('30140-071');

    expect(requisicoes, ['viacep.com.br', 'brasilapi.com.br']);
    expect(endereco?.logradouro, 'Rua dos Aimorés');
    expect(endereco?.bairro, 'Funcionários');
  });

  test('completa pela BrasilAPI uma resposta parcial do ViaCEP', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'viacep.com.br') {
        return http.Response(
          '{"cep":"12345-000","logradouro":"","bairro":"",'
          '"localidade":"Cidade Teste","uf":"SP"}',
          200,
        );
      }
      return http.Response(
        '{"cep":"12345000","street":"Rua Atualizada",'
        '"neighborhood":"Centro","city":"Cidade Teste","state":"SP"}',
        200,
      );
    });

    final endereco = await CepService(client: client).buscar('12345-000');

    expect(endereco?.logradouro, 'Rua Atualizada');
    expect(endereco?.bairro, 'Centro');
    expect(endereco?.cidade, 'Cidade Teste');
  });

  test('não consulta provedores quando o CEP é inválido', () async {
    var consultou = false;
    final client = MockClient((request) async {
      consultou = true;
      return http.Response('{}', 200);
    });

    final endereco = await CepService(client: client).buscar('1234');

    expect(endereco, isNull);
    expect(consultou, isFalse);
  });

  test('retorna nulo quando nenhum provedor encontra o CEP', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'viacep.com.br') {
        return http.Response('{"erro":true}', 200);
      }
      return http.Response('{"message":"Todos os serviços falharam"}', 404);
    });

    final endereco = await CepService(client: client).buscar('99999-999');

    expect(endereco, isNull);
  });
}
