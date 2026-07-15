const Map<int, String> _frutasPorSemana = <int, String>{
  4: 'mirtilo',
  5: 'framboesa',
  6: 'framboesa',
  7: 'uva',
  8: 'uva',
  9: 'morango',
  10: 'morango',
  11: 'limão',
  12: 'limão',
  13: 'pêssego',
  14: 'pêssego',
  15: 'abacate',
  16: 'abacate',
  17: 'manga',
  18: 'manga',
  19: 'manga',
  20: 'manga',
  21: 'milho',
  22: 'milho',
  23: 'berinjela',
  24: 'berinjela',
  25: 'couve-flor',
  26: 'couve-flor',
  27: 'repolho',
  28: 'repolho',
  29: 'abóbora',
  30: 'abóbora',
  31: 'coco',
  32: 'coco',
  33: 'abacaxi',
  34: 'abacaxi',
  35: 'melão',
  36: 'melão',
  37: 'melancia',
  38: 'melancia',
  39: 'melancia',
  40: 'melancia',
  41: 'melancia',
  42: 'melancia',
};

const Map<int, String> _imagensFrutasPorSemana = <int, String>{
  4: 'assets/frutas/mirtilo.png',
  5: 'assets/frutas/framboesa.png',
  6: 'assets/frutas/framboesa.png',
  7: 'assets/frutas/uva.png',
  8: 'assets/frutas/uva.png',
  9: 'assets/frutas/morango.png',
  10: 'assets/frutas/morango.png',
  11: 'assets/frutas/limao.png',
  12: 'assets/frutas/limao.png',
  13: 'assets/frutas/pessego.png',
  14: 'assets/frutas/pessego.png',
  15: 'assets/frutas/abacate.png',
  16: 'assets/frutas/abacate.png',
  17: 'assets/frutas/manga.png',
  18: 'assets/frutas/manga.png',
  19: 'assets/frutas/manga.png',
  20: 'assets/frutas/manga.png',
  21: 'assets/frutas/milho.png',
  22: 'assets/frutas/milho.png',
  23: 'assets/frutas/berinjela.png',
  24: 'assets/frutas/berinjela.png',
  25: 'assets/frutas/couve flor.png',
  26: 'assets/frutas/couve flor.png',
  27: 'assets/frutas/repolho.png',
  28: 'assets/frutas/repolho.png',
  29: 'assets/frutas/abobora.png',
  30: 'assets/frutas/abobora.png',
  31: 'assets/frutas/coco.png',
  32: 'assets/frutas/coco.png',
  33: 'assets/frutas/abacaxi.png',
  34: 'assets/frutas/abacaxi.png',
  35: 'assets/frutas/melao.png',
  36: 'assets/frutas/melao.png',
  37: 'assets/frutas/melancia.png',
  38: 'assets/frutas/melancia.png',
  39: 'assets/frutas/melancia.png',
  40: 'assets/frutas/melancia.png',
  41: 'assets/frutas/melancia.png',
  42: 'assets/frutas/melancia.png',
};

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
  return _frutasPorSemana[semana] ?? 'morango';
}

String imagemFrutaDaSemana(int semanas) {
  final semana = semanas.clamp(4, 42).toInt();
  return _imagensFrutasPorSemana[semana] ?? 'assets/frutas/morango.png';
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
