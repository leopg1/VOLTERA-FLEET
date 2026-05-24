import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';
import 'voltera_tokens.dart';

/// Singura sursa de ThemeData. Construieste totul din [VolteraTokens] + scale.
class VolteraTheme {
  VolteraTheme._();

  static ThemeData dark() {
    const t = VolteraTokens.dark;

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: VColors.accent500,
        onPrimary: VColors.accentOnDark,
        secondary: VColors.accent500,
        onSecondary: VColors.accentOnDark,
        surface: VColors.ink900,
        onSurface: VColors.textStrong,
        error: VColors.danger500,
        onError: VColors.textStrong,
        surfaceContainerHighest: VColors.ink800,
        outline: VColors.hairlineStrong,
        outlineVariant: VColors.hairline,
      ),
      scaffoldBackgroundColor: t.canvas,
      canvasColor: t.surface,
      dividerColor: t.hairline,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      extensions: const <ThemeExtension<dynamic>>[t],
    );

    final textTheme = base.textTheme
        .copyWith(
          displayLarge: VType.display72,
          displayMedium: VType.display40,
          headlineSmall: VType.title24,
          titleLarge: VType.title18,
          titleMedium: VType.title18,
          bodyLarge: VType.body15,
          bodyMedium: VType.body15,
          bodySmall: VType.body13,
          labelLarge: VType.body13,
          labelMedium: VType.label11,
          labelSmall: VType.label11,
        )
        .apply(
          bodyColor: t.textDefault,
          displayColor: t.textStrong,
        );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: t.canvas,
        foregroundColor: t.textStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: VType.title18,
        iconTheme: IconThemeData(color: t.textDefault, size: 22),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: VRadius.brMd),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          disabledBackgroundColor: t.surfaceHover,
          disabledForegroundColor: t.textDisabled,
          minimumSize: const Size(0, 48),
          textStyle: VType.title18.copyWith(fontSize: 15),
          shape: const RoundedRectangleBorder(borderRadius: VRadius.brSm),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textStrong,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: t.hairlineStrong),
          textStyle: VType.title18.copyWith(fontSize: 15),
          shape: const RoundedRectangleBorder(borderRadius: VRadius.brSm),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          textStyle: VType.body15.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: t.textDefault,
          minimumSize: const Size(40, 40),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceRaised,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: VType.body15.copyWith(color: t.textDisabled),
        labelStyle: VType.body13.copyWith(color: t.textMuted),
        floatingLabelStyle: VType.label11.copyWith(color: t.accent),
        border: const OutlineInputBorder(
          borderRadius: VRadius.brSm,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: VRadius.brSm,
          borderSide: BorderSide(color: t.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: VRadius.brSm,
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: VRadius.brSm,
          borderSide: BorderSide(color: t.danger),
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: t.textStrong,
        iconColor: t.textDefault,
        minVerticalPadding: 14,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: VType.body15.copyWith(color: t.textStrong),
        subtitleTextStyle: VType.body13.copyWith(color: t.textMuted),
      ),
      dividerTheme: DividerThemeData(
        color: t.hairline,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.surfaceRaised,
        circularTrackColor: t.surfaceRaised,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.accent;
          return t.surfaceRaised;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.onAccent;
          return t.textMuted;
        }),
        trackOutlineColor:
            WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.accent;
          return Colors.transparent;
        }),
        side: BorderSide(color: t.hairlineStrong, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: VRadius.brXs),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surfaceRaised,
        contentTextStyle: VType.body13.copyWith(color: t.textStrong),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: VRadius.brSm),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surfaceRaised,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: VRadius.brLg),
        titleTextStyle: VType.title18,
        contentTextStyle: VType.body15,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surfaceRaised,
        modalBackgroundColor: t.surfaceRaised,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: t.hairlineStrong,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: VRadius.brSm,
          border: Border.all(color: t.hairline),
        ),
        textStyle: VType.body13.copyWith(color: t.textStrong),
      ),
    );
  }
}
