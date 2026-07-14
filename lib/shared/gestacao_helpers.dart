int calcularSemanas(String dpp) {
  try {
    final partes = dpp.split('/');
    if (partes.length != 3) return 0;

    final dia = int.parse(partes[0]);
    final mes = int.parse(partes[1]);
    final ano = int.parse(partes[2]);

    final dataDpp = DateTime(ano, mes, dia);
    final hoje = DateTime.now();

    final diasParaDpp = dataDpp.difference(hoje).inDays;
    final diasGestacao = 280 - diasParaDpp;

    final semanas = diasGestacao ~/ 7;

    return semanas.clamp(0, 42);
  } catch (e) {
    return 0;
  }
}

String frutaDaSemana(int semanas) {
  final semana = semanas.clamp(4, 42).toInt();

  const frutasPorSemana = <int, String>{
    4: 'Mirtilo',
    5: 'Framboesa',
    6: 'Framboesa',
    7: 'Uva',
    8: 'Uva',
    9: 'Morango',
    10: 'Morango',
    11: 'Limão',
    12: 'Limão',
    13: 'Pêssego',
    14: 'Pêssego',
    15: 'Abacate',
    16: 'Abacate',
    17: 'Pera',
    18: 'Manga',
    19: 'Manga',
    20: 'Manga',
    21: 'Milho',
    22: 'Milho',
    23: 'Berinjela',
    24: 'Berinjela',
    25: 'Couve-flor',
    26: 'Couve-flor',
    27: 'Repolho',
    28: 'Repolho',
    29: 'Abóbora',
    30: 'Abóbora',
    31: 'Coco',
    32: 'Coco',
    33: 'Abacaxi',
    34: 'Abacaxi',
    35: 'Melão',
    36: 'Melão',
    37: 'Melancia',
    38: 'Melancia',
    39: 'Melancia',
    40: 'Melancia',
    41: 'Melancia',
    42: 'Melancia',
  };

  return frutasPorSemana[semana] ?? 'Morango';
}

String calcularIdadeGestacional(String dppTexto) {
  try {
    final partes = dppTexto.split('/');

    if (partes.length != 3) {
      return 'Informe a DPP';
    }

    final dia = int.parse(partes[0]);
    final mes = int.parse(partes[1]);
    final ano = int.parse(partes[2]);

    final dpp = DateTime(ano, mes, dia);
    final hoje = DateTime.now();

    final diasAteDpp = dpp.difference(hoje).inDays;
    final diasGestacao = 280 - diasAteDpp;

    if (diasGestacao < 0) {
      return 'Antes da gestação';
    }

    final semanas = diasGestacao ~/ 7;
    final dias = diasGestacao % 7;

    return '$semanas semanas e $dias dias';
  } catch (e) {
    return 'Informe a DPP';
  }
}
