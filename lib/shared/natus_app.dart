import 'package:flutter/material.dart';

/// Design System Natus — paleta oficial da marca:
/// off-white, marsala e dourado.
///
/// Todas as cores e estilos do app nascem aqui. Os nomes das constantes
/// foram preservados (o app inteiro as referencia); apenas os valores e o
/// tema foram refinados.
class NatusApp extends StatelessWidget {
  const NatusApp({super.key, required this.home});

  final Widget home;

  // ── Marsala (cor primária da marca) ─────────────────────────────
  static const Color marsala = Color(0xFF8A4247);
  static const Color marsalaSuave = Color(0xFFA05A5F);
  static const Color vinho = Color(0xFF6B3136);
  static const Color vinhoProfundo = Color(0xFF401A1E);

  // ── Dourado (acento premium) ────────────────────────────────────
  static const Color dourado = Color(0xFFC6A15B);
  static const Color douradoSuave = Color(0xFFC9A45E);
  static const Color douradoEscuro = Color(0xFFA17F3C);
  static const Color douradoClaro = Color(0xFFEAD9B0);

  // ── Neutros quentes (off-white e beges) ─────────────────────────
  static const Color offWhite = Color(0xFFFDFBF6);
  static const Color creme = Color(0xFFF8F3EB);
  static const Color fundo = Color(0xFFF8F3EB);
  static const Color bege = Color(0xFFF0E7D8);
  static const Color begeEscuro = Color(0xFFDDCEB6);

  // ── Apoio ───────────────────────────────────────────────────────
  static const Color rose = Color(0xFFDBA79B);
  static const Color olivaSeco = Color(0xFF8D9A7A);
  static const Color texto = Color(0xFF3D2B2D);
  static const Color textoSuave = Color(0xFF83706F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Natus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: fundo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: marsala,
          brightness: Brightness.light,
          primary: marsala,
          onPrimary: offWhite,
          secondary: dourado,
          onSecondary: vinhoProfundo,
          tertiary: olivaSeco,
          surface: offWhite,
          onSurface: texto,
          error: const Color(0xFFB3413B),
        ),

        // ── Tipografia: títulos com presença, corpo legível ────────
        textTheme: const TextTheme(
          displaySmall: TextStyle(
              fontWeight: FontWeight.w800, color: vinho, letterSpacing: -0.8),
          headlineMedium: TextStyle(
              fontWeight: FontWeight.w800, color: vinho, letterSpacing: -0.5),
          headlineSmall: TextStyle(
              fontWeight: FontWeight.w700, color: vinho, letterSpacing: -0.3),
          titleLarge: TextStyle(
              fontWeight: FontWeight.w700, color: texto, letterSpacing: -0.2),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: texto),
          bodyLarge: TextStyle(color: texto, height: 1.45),
          bodyMedium: TextStyle(color: texto, height: 1.45),
          bodySmall: TextStyle(color: textoSuave, height: 1.4),
          labelLarge:
              TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.1),
        ),

        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: vinho,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: vinho,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            fontFamily: 'Inter',
          ),
        ),

        // ── Cards: superfície limpa com borda dourada sutil ───────
        cardTheme: CardThemeData(
          elevation: 0,
          color: offWhite,
          surfaceTintColor: Colors.transparent,
          shadowColor: vinhoProfundo.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: douradoClaro.withValues(alpha: 0.55)),
          ),
          margin: EdgeInsets.zero,
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: offWhite,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          titleTextStyle: const TextStyle(
            color: vinho,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
          ),
        ),

        // ── Inputs: fundo claro, foco em marsala, toque dourado ────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.82),
          hintStyle: TextStyle(color: textoSuave.withValues(alpha: 0.8)),
          labelStyle: const TextStyle(
              color: textoSuave, fontWeight: FontWeight.w600),
          floatingLabelStyle:
              const TextStyle(color: marsala, fontWeight: FontWeight.w700),
          prefixIconColor: douradoEscuro,
          suffixIconColor: textoSuave,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: begeEscuro.withValues(alpha: 0.8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: begeEscuro.withValues(alpha: 0.8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: marsala, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB3413B)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),

        // ── Botões ─────────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: marsala,
            foregroundColor: offWhite,
            disabledBackgroundColor: begeEscuro,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: marsala,
            foregroundColor: offWhite,
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: marsala,
            side: const BorderSide(color: marsala, width: 1.3),
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: marsala,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),

        // ── Componentes de apoio ───────────────────────────────────
        chipTheme: ChipThemeData(
          backgroundColor: bege,
          selectedColor: douradoClaro,
          labelStyle:
              const TextStyle(color: texto, fontWeight: FontWeight.w600),
          side: BorderSide(color: begeEscuro.withValues(alpha: 0.6)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: marsala,
          foregroundColor: offWhite,
          elevation: 2,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: vinhoProfundo,
          contentTextStyle:
              const TextStyle(color: offWhite, fontWeight: FontWeight.w600),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        dividerTheme: DividerThemeData(
          color: begeEscuro.withValues(alpha: 0.5),
          thickness: 1,
          space: 1,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: douradoEscuro,
          titleTextStyle: TextStyle(
              color: texto,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              fontFamily: 'Inter'),
          subtitleTextStyle: TextStyle(
              color: textoSuave, fontSize: 13, fontFamily: 'Inter'),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: marsala,
          unselectedLabelColor: textoSuave,
          indicatorColor: dourado,
          labelStyle: TextStyle(fontWeight: FontWeight.w700),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: marsala,
          linearTrackColor: bege,
          circularTrackColor: bege,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? marsala : null),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? marsala : null),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? marsala.withValues(alpha: 0.35)
                  : null),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: offWhite,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: vinhoProfundo,
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(color: offWhite, fontSize: 12),
        ),
      ),
      home: home,
    );
  }
}
