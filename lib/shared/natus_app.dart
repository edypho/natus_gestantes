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
    nome: 'Marsala Natus',
    descricao: 'A identidade oficial da marca',
    escuro: false,
    marsala: Color(0xFF8A4247),
    marsalaSuave: Color(0xFFA05A5F),
    vinho: Color(0xFF6B3136),
    vinhoProfundo: Color(0xFF401A1E),
    dourado: Color(0xFFC6A15B),
    douradoSuave: Color(0xFFC9A45E),
    douradoEscuro: Color(0xFFA17F3C),
    douradoClaro: Color(0xFFEAD9B0),
    offWhite: Color(0xFFFDFBF6),
    creme: Color(0xFFF8F3EB),
    fundo: Color(0xFFF8F3EB),
    bege: Color(0xFFF0E7D8),
    begeEscuro: Color(0xFFDDCEB6),
    rose: Color(0xFFDBA79B),
    olivaSeco: Color(0xFF8D9A7A),
    texto: Color(0xFF3D2B2D),
    textoSuave: Color(0xFF83706F),
    menuTopo: Color(0xFF6F2F48),
    menuMeio: Color(0xFF6B3136),
    menuBase: Color(0xFF401A1E),
  );

  /// ── Verde Oliva: sereno e botânico ───────────────────────────────
  static const NatusPaleta verdeOliva = NatusPaleta(
    chave: 'oliva',
    nome: 'Verde Oliva',
    descricao: 'Sereno, botânico e acolhedor',
    escuro: false,
    marsala: Color(0xFF697447),
    marsalaSuave: Color(0xFF838E60),
    vinho: Color(0xFF4A5430),
    vinhoProfundo: Color(0xFF2C321D),
    dourado: Color(0xFFC6A15B),
    douradoSuave: Color(0xFFC9A45E),
    douradoEscuro: Color(0xFFA17F3C),
    douradoClaro: Color(0xFFEADFB6),
    offWhite: Color(0xFFFCFBF4),
    creme: Color(0xFFF6F4E9),
    fundo: Color(0xFFF6F4E9),
    bege: Color(0xFFECE8D4),
    begeEscuro: Color(0xFFD8D1B4),
    rose: Color(0xFFB9C295),
    olivaSeco: Color(0xFF8D9A7A),
    texto: Color(0xFF2F3424),
    textoSuave: Color(0xFF787D69),
    menuTopo: Color(0xFF5A6638),
    menuMeio: Color(0xFF4A5430),
    menuBase: Color(0xFF2C321D),
  );

  /// ── Azul Petróleo: elegante e clínico ────────────────────────────
  static const NatusPaleta azulPetroleo = NatusPaleta(
    chave: 'petroleo',
    nome: 'Azul Petróleo',
    descricao: 'Elegante, calmo e profissional',
    escuro: false,
    marsala: Color(0xFF1F5F6B),
    marsalaSuave: Color(0xFF3D7883),
    vinho: Color(0xFF154650),
    vinhoProfundo: Color(0xFF0B2B31),
    dourado: Color(0xFFC6A15B),
    douradoSuave: Color(0xFFC9A45E),
    douradoEscuro: Color(0xFFA17F3C),
    douradoClaro: Color(0xFFE6DDBE),
    offWhite: Color(0xFFFAFCFC),
    creme: Color(0xFFF0F5F5),
    fundo: Color(0xFFF0F5F5),
    bege: Color(0xFFE1EAEA),
    begeEscuro: Color(0xFFC5D7D7),
    rose: Color(0xFF9EC3C8),
    olivaSeco: Color(0xFF7A9A96),
    texto: Color(0xFF1F3236),
    textoSuave: Color(0xFF6B8184),
    menuTopo: Color(0xFF1E5560),
    menuMeio: Color(0xFF154650),
    menuBase: Color(0xFF0B2B31),
  );

  /// ── Modo Escuro: marsala noturno ─────────────────────────────────
  /// Superfícies quentes quase-pretas; a identidade marsala/dourado é
  /// clareada para manter contraste. Tokens de "tinta" (vinho, texto)
  /// invertem para claros — o app inteiro acompanha.
  static const NatusPaleta modoEscuro = NatusPaleta(
    chave: 'escuro',
    nome: 'Modo Escuro',
    descricao: 'Marsala noturno, conforto visual',
    escuro: true,
    marsala: Color(0xFFB56A70),
    marsalaSuave: Color(0xFFC5838A),
    vinho: Color(0xFFE0B3B7),
    vinhoProfundo: Color(0xFF52343A),
    dourado: Color(0xFFD3B071),
    douradoSuave: Color(0xFFD6B573),
    douradoEscuro: Color(0xFFB8934E),
    douradoClaro: Color(0xFF3E3323),
    offWhite: Color(0xFF231A1D),
    creme: Color(0xFF2A2023),
    fundo: Color(0xFF171114),
    bege: Color(0xFF362A2D),
    begeEscuro: Color(0xFF4A393D),
    rose: Color(0xFFCC9C93),
    olivaSeco: Color(0xFFA2B18D),
    texto: Color(0xFFF2E7E4),
    textoSuave: Color(0xFFB9A8A6),
    menuTopo: Color(0xFF2C1B1F),
    menuMeio: Color(0xFF241619),
    menuBase: Color(0xFF150D0F),
  );
}

/// Controlador global do tema ativo.
///
/// Trocar a paleta reconstrói o MaterialApp inteiro (ValueListenable),
/// então TODAS as telas que usam `NatusApp.*` acompanham na hora.
class NatusTema {
  NatusTema._();

  static const List<NatusPaleta> paletas = [
    NatusPaleta.marsalaNatus,
    NatusPaleta.verdeOliva,
    NatusPaleta.azulPetroleo,
    NatusPaleta.modoEscuro,
  ];

  static final ValueNotifier<NatusPaleta> atual = ValueNotifier<NatusPaleta>(
    NatusPaleta.marsalaNatus,
  );

  static NatusPaleta get paleta => atual.value;

  static void aplicarPorChave(String chave) {
    final encontrada = paletas.where((p) => p.chave == chave);
    if (encontrada.isNotEmpty && encontrada.first.chave != atual.value.chave) {
      atual.value = encontrada.first;
    }
  }

  static void restaurarPadrao() => aplicarPorChave('marsala');
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
