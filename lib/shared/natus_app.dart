import 'package:flutter/material.dart';

/// Design System Natus — paleta oficial da marca e temas alternativos.
///
/// A partir desta versão as cores são DINÂMICAS: `NatusApp.marsala` etc.
/// continuam existindo com os mesmos nomes (o app inteiro as referencia),
/// mas agora apontam para a paleta ativa em `NatusTema.atual`.
///
/// Temas disponíveis: Marsala Natus (oficial), Verde Oliva, Azul Petróleo
/// e Modo Escuro. A troca acontece em tempo de execução, sem reiniciar.

/// Uma paleta completa do Natus. Os nomes dos campos preservam a
/// semântica original da marca (marsala/vinho = cor primária; dourado =
/// acento premium; off-white/creme/bege = superfícies; texto = tinta).
class NatusPaleta {
  const NatusPaleta({
    required this.chave,
    required this.nome,
    required this.descricao,
    required this.escuro,
    required this.marsala,
    required this.marsalaSuave,
    required this.vinho,
    required this.vinhoProfundo,
    required this.dourado,
    required this.douradoSuave,
    required this.douradoEscuro,
    required this.douradoClaro,
    required this.offWhite,
    required this.creme,
    required this.fundo,
    required this.bege,
    required this.begeEscuro,
    required this.rose,
    required this.olivaSeco,
    required this.texto,
    required this.textoSuave,
    required this.menuTopo,
    required this.menuMeio,
    required this.menuBase,
  });

  final String chave;
  final String nome;
  final String descricao;
  final bool escuro;

  final Color marsala;
  final Color marsalaSuave;
  final Color vinho;
  final Color vinhoProfundo;
  final Color dourado;
  final Color douradoSuave;
  final Color douradoEscuro;
  final Color douradoClaro;
  final Color offWhite;
  final Color creme;
  final Color fundo;
  final Color bege;
  final Color begeEscuro;
  final Color rose;
  final Color olivaSeco;
  final Color texto;
  final Color textoSuave;

  /// Gradiente do menu lateral — superfície escura de marca em TODOS os
  /// temas (inclusive no claro), por isso tem tokens próprios.
  final Color menuTopo;
  final Color menuMeio;
  final Color menuBase;

  /// ── Marsala Natus: a identidade oficial ─────────────────────────
  static const NatusPaleta marsalaNatus = NatusPaleta(
    chave: 'marsala',
    nome: 'Marsala Clássico',
    descricao: 'Marca clássica, com mais respiro e contraste',
    escuro: false,
    marsala: Color(0xFF85434A),
    marsalaSuave: Color(0xFFA76C70),
    vinho: Color(0xFF5E3035),
    vinhoProfundo: Color(0xFF321A1E),
    dourado: Color(0xFFB99A5A),
    douradoSuave: Color(0xFFD3BD86),
    douradoEscuro: Color(0xFF8E713C),
    douradoClaro: Color(0xFFE9DCC0),
    offWhite: Color(0xFFFFFCF7),
    creme: Color(0xFFF7F1E8),
    fundo: Color(0xFFF5EFE6),
    bege: Color(0xFFEDE2D3),
    begeEscuro: Color(0xFFD6C5AD),
    rose: Color(0xFFD9A69D),
    olivaSeco: Color(0xFF7C8664),
    texto: Color(0xFF352728),
    textoSuave: Color(0xFF756765),
    menuTopo: Color(0xFF3F2D31),
    menuMeio: Color(0xFF352327),
    menuBase: Color(0xFF24181B),
  );

  /// ── Verde Oliva: sereno e botânico ───────────────────────────────
  static const NatusPaleta verdeOliva = NatusPaleta(
    chave: 'oliva',
    nome: 'Oliva Premium',
    descricao: 'Sereno, clínico e acolhedor',
    escuro: false,
    marsala: Color(0xFF6F7A58),
    marsalaSuave: Color(0xFF8D9672),
    vinho: Color(0xFF3F4934),
    vinhoProfundo: Color(0xFF252D20),
    dourado: Color(0xFFB99A5A),
    douradoSuave: Color(0xFFD5C08A),
    douradoEscuro: Color(0xFF8E713C),
    douradoClaro: Color(0xFFE8DFC4),
    offWhite: Color(0xFFFFFCF6),
    creme: Color(0xFFF7F3E8),
    fundo: Color(0xFFF4EFE4),
    bege: Color(0xFFECE5D4),
    begeEscuro: Color(0xFFD3C8AD),
    rose: Color(0xFFD2B2A3),
    olivaSeco: Color(0xFF87906E),
    texto: Color(0xFF303327),
    textoSuave: Color(0xFF737466),
    menuTopo: Color(0xFF515C43),
    menuMeio: Color(0xFF3E4934),
    menuBase: Color(0xFF252D20),
  );

  /// ── Azul Petróleo: elegante e clínico ────────────────────────────
  static const NatusPaleta azulPetroleo = NatusPaleta(
    chave: 'petroleo',
    nome: 'Petróleo Clínico',
    descricao: 'Profissional, tecnológico e calmo',
    escuro: false,
    marsala: Color(0xFF245F68),
    marsalaSuave: Color(0xFF4B7E86),
    vinho: Color(0xFF183F47),
    vinhoProfundo: Color(0xFF0D252B),
    dourado: Color(0xFFB99A5A),
    douradoSuave: Color(0xFFD2BF8A),
    douradoEscuro: Color(0xFF8E713C),
    douradoClaro: Color(0xFFE5DDC5),
    offWhite: Color(0xFFFBFDFD),
    creme: Color(0xFFF0F5F4),
    fundo: Color(0xFFEEF4F3),
    bege: Color(0xFFE1EBE9),
    begeEscuro: Color(0xFFC3D5D2),
    rose: Color(0xFFB8CDD0),
    olivaSeco: Color(0xFF7C9690),
    texto: Color(0xFF203236),
    textoSuave: Color(0xFF6A7F82),
    menuTopo: Color(0xFF255964),
    menuMeio: Color(0xFF173F48),
    menuBase: Color(0xFF0C252B),
  );

  /// ── Modo Escuro: marsala noturno ─────────────────────────────────
  /// Superfícies quentes quase-pretas; a identidade marsala/dourado é
  /// clareada para manter contraste. Tokens de "tinta" (vinho, texto)
  /// invertem para claros — o app inteiro acompanha.
  static const NatusPaleta modoEscuro = NatusPaleta(
    chave: 'escuro',
    nome: 'Modo Escuro',
    descricao: 'Noturno, discreto e confortável',
    escuro: true,
    marsala: Color(0xFF9FAE83),
    marsalaSuave: Color(0xFFB4C095),
    vinho: Color(0xFFE5E0D1),
    vinhoProfundo: Color(0xFF30362B),
    dourado: Color(0xFFD0B06A),
    douradoSuave: Color(0xFFD8C184),
    douradoEscuro: Color(0xFFB39250),
    douradoClaro: Color(0xFF3D392D),
    offWhite: Color(0xFF211F1B),
    creme: Color(0xFF292620),
    fundo: Color(0xFF151411),
    bege: Color(0xFF343126),
    begeEscuro: Color(0xFF4A4536),
    rose: Color(0xFFC79F92),
    olivaSeco: Color(0xFFA7B38B),
    texto: Color(0xFFF2EDE3),
    textoSuave: Color(0xFFBDB5A7),
    menuTopo: Color(0xFF25291F),
    menuMeio: Color(0xFF1F231B),
    menuBase: Color(0xFF11130F),
  );
}

/// Controlador global do tema ativo.
///
/// Trocar a paleta reconstrói o MaterialApp inteiro (ValueListenable),
/// então TODAS as telas que usam `NatusApp.*` acompanham na hora.
class NatusTema {
  NatusTema._();

  static const List<NatusPaleta> paletas = [
    NatusPaleta.verdeOliva,
    NatusPaleta.azulPetroleo,
    NatusPaleta.marsalaNatus,
    NatusPaleta.modoEscuro,
  ];

  static final ValueNotifier<NatusPaleta> atual = ValueNotifier<NatusPaleta>(
    NatusPaleta.verdeOliva,
  );

  static NatusPaleta get paleta => atual.value;

  static void aplicarPorChave(String chave) {
    final encontrada = paletas.where((p) => p.chave == chave);
    if (encontrada.isNotEmpty && encontrada.first.chave != atual.value.chave) {
      atual.value = encontrada.first;
    }
  }

  static void restaurarPadrao() => aplicarPorChave('oliva');
}

/// Raiz do app + tokens de cor da marca.
///
/// Os nomes das constantes históricas foram preservados como getters:
/// `NatusApp.marsala`, `NatusApp.vinho`, etc. — agora dinâmicos.
class NatusApp extends StatelessWidget {
  const NatusApp({super.key, required this.home});

  final Widget home;

  // Conteudo sobre as superficies profundas da marca. Estas cores sao
  // estaveis entre paletas para preservar o contraste da logo e do menu.
  static const Color sobreMarca = Color(0xFFFFF8F2);
  static const Color sobreMarcaSuave = Color(0xFFEAD9B0);

  // ── Tokens dinâmicos (apontam para a paleta ativa) ───────────────
  static Color get marsala => NatusTema.paleta.marsala;
  static Color get marsalaSuave => NatusTema.paleta.marsalaSuave;
  static Color get vinho => NatusTema.paleta.vinho;
  static Color get vinhoProfundo => NatusTema.paleta.vinhoProfundo;
  static Color get dourado => NatusTema.paleta.dourado;
  static Color get douradoSuave => NatusTema.paleta.douradoSuave;
  static Color get douradoEscuro => NatusTema.paleta.douradoEscuro;
  static Color get douradoClaro => NatusTema.paleta.douradoClaro;
  static Color get offWhite => NatusTema.paleta.offWhite;
  static Color get creme => NatusTema.paleta.creme;
  static Color get fundo => NatusTema.paleta.fundo;
  static Color get bege => NatusTema.paleta.bege;
  static Color get begeEscuro => NatusTema.paleta.begeEscuro;
  static Color get rose => NatusTema.paleta.rose;
  static Color get olivaSeco => NatusTema.paleta.olivaSeco;
  static Color get texto => NatusTema.paleta.texto;
  static Color get textoSuave => NatusTema.paleta.textoSuave;
  static Color get menuTopo => NatusTema.paleta.menuTopo;
  static Color get menuMeio => NatusTema.paleta.menuMeio;
  static Color get menuBase => NatusTema.paleta.menuBase;

  // Estados possuem significado proprio e nao reutilizam cores decorativas.
  static Color get sucesso =>
      escuro ? const Color(0xFFA8BE99) : const Color(0xFF58734F);
  static Color get alerta =>
      escuro ? const Color(0xFFE7B86A) : const Color(0xFFA86724);
  static Color get erro =>
      escuro ? const Color(0xFFE08A84) : const Color(0xFFB3413B);
  static Color get informacao =>
      escuro ? const Color(0xFF8DB9CA) : const Color(0xFF35697A);

  /// Se o tema ativo é escuro. Útil em telas fora de [temaDe] que
  /// precisam inverter cor de texto/ícone sobre superfícies coloridas
  /// (ex.: `NatusApp.escuro ? NatusApp.fundo : NatusApp.offWhite`).
  static bool get escuro => NatusTema.paleta.escuro;

  /// Tema Material derivado da paleta ativa.
  static ThemeData temaDe(NatusPaleta p) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: p.escuro ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: p.fundo,

      // ── Toque estilo iOS: sem onda de ripple, feedback por opacidade ──
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      colorScheme: ColorScheme.fromSeed(
        seedColor: p.marsala,
        brightness: p.escuro ? Brightness.dark : Brightness.light,
        primary: p.marsala,
        onPrimary: p.escuro ? p.fundo : p.offWhite,
        secondary: p.dourado,
        onSecondary: p.escuro ? p.fundo : p.vinhoProfundo,
        tertiary: p.olivaSeco,
        surface: p.offWhite,
        onSurface: p.texto,
        error: p.escuro ? const Color(0xFFE08A84) : const Color(0xFFB3413B),
      ),

      // ── Tipografia: títulos com presença, corpo legível ────────
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontWeight: FontWeight.w800,
          color: p.vinho,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: p.vinho,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          color: p.vinho,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: p.texto,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: p.texto),
        bodyLarge: TextStyle(color: p.texto, height: 1.45),
        bodyMedium: TextStyle(color: p.texto, height: 1.45),
        bodySmall: TextStyle(color: p.textoSuave, height: 1.4),
        labelLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: p.vinho,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: p.vinho,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          fontFamily: 'Inter',
        ),
      ),

      // ── Cards: superfície limpa, sombra suave e difusa (estilo iOS) ──
      cardTheme: CardThemeData(
        elevation: 3,
        color: p.offWhite,
        surfaceTintColor: Colors.transparent,
        shadowColor: p.vinhoProfundo.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: p.douradoClaro.withValues(alpha: 0.55)),
        ),
        margin: EdgeInsets.zero,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.offWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: TextStyle(
          color: p.vinho,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          fontFamily: 'Inter',
        ),
      ),

      // ── Sheets: cantos superiores arredondados + alça, estilo iOS ──
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.offWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: p.vinhoProfundo.withValues(alpha: 0.10),
        showDragHandle: true,
        dragHandleColor: p.douradoClaro.withValues(alpha: 0.8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),

      // ── Inputs: fundo claro, foco na cor primária ──────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.escuro ? p.creme : Colors.white.withValues(alpha: 0.82),
        hintStyle: TextStyle(color: p.textoSuave.withValues(alpha: 0.8)),
        labelStyle: TextStyle(color: p.textoSuave, fontWeight: FontWeight.w600),
        floatingLabelStyle: TextStyle(
          color: p.marsala,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: p.douradoEscuro,
        suffixIconColor: p.textoSuave,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.begeEscuro.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.begeEscuro.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.marsala, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: p.escuro ? const Color(0xFFE08A84) : const Color(0xFFB3413B),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),

      // ── Botões ─────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.marsala,
          foregroundColor: p.escuro ? p.fundo : p.offWhite,
          disabledBackgroundColor: p.begeEscuro,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.marsala,
          foregroundColor: p.escuro ? p.fundo : p.offWhite,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.marsala,
          side: BorderSide(color: p.marsala, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.marsala,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // ── Componentes de apoio ───────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: p.bege,
        selectedColor: p.douradoClaro,
        labelStyle: TextStyle(color: p.texto, fontWeight: FontWeight.w600),
        side: BorderSide(color: p.begeEscuro.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.marsala,
        foregroundColor: p.escuro ? p.fundo : p.offWhite,
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.escuro ? p.bege : p.vinhoProfundo,
        contentTextStyle: TextStyle(
          color: p.escuro ? p.texto : p.offWhite,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: p.begeEscuro.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.douradoEscuro,
        titleTextStyle: TextStyle(
          color: p.texto,
          fontWeight: FontWeight.w600,
          fontSize: 15,
          fontFamily: 'Inter',
        ),
        subtitleTextStyle: TextStyle(
          color: p.textoSuave,
          fontSize: 13,
          fontFamily: 'Inter',
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.marsala,
        unselectedLabelColor: p.textoSuave,
        indicatorColor: p.dourado,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.marsala,
        linearTrackColor: p.bege,
        circularTrackColor: p.bege,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.marsala : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.marsala : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.marsala.withValues(alpha: 0.35)
              : null,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.offWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.escuro ? p.bege : p.vinhoProfundo,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(
          color: p.escuro ? p.texto : p.offWhite,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NatusPaleta>(
      valueListenable: NatusTema.atual,
      builder: (context, paleta, _) {
        return MaterialApp(
          title: 'Natus',
          debugShowCheckedModeBanner: false,
          theme: temaDe(paleta),
          home: home,
        );
      },
    );
  }
}
