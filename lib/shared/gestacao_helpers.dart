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
  if (semanas <= 8) return 'Uva 🍇';
  if (semanas <= 10) return 'Morango 🍓';
  if (semanas <= 12) return 'Limão 🍋';
  if (semanas <= 16) return 'Abacate 🥑';
  if (semanas <= 20) return 'Manga 🥭';
  if (semanas <= 24) return 'Milho 🌽';
  if (semanas <= 28) return 'Berinjela 🍆';
  if (semanas <= 32) return 'Coco 🥥';
  if (semanas <= 36) return 'Melão 🍈';

  return 'Melancia 🍉';
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
