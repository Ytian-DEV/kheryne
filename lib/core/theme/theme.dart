import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';
import 'typography.dart';

export 'colors.dart';
export 'theme_ext.dart';
export 'tokens.dart';
export 'typography.dart';

abstract final class KheryneTheme {
  static ThemeData light() => _build(Brightness.light, KheryneColors.light);
  static ThemeData dark() => _build(Brightness.dark, KheryneColors.dark);

  static ThemeData _build(Brightness b, KheryneColors c) {
    final type = KType.of(c.text, c.textSecondary);
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.container,
      onPrimaryContainer: c.primaryStrong,
      secondary: c.accent,
      onSecondary: c.onStatus,
      tertiary: c.userBox,
      onTertiary: c.onStatus,
      error: c.error,
      onError: c.onStatus,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.background,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: c.container,
      outline: c.separator,
      outlineVariant: c.separator,
      shadow: c.canvas,
      scrim: c.scrim,
      inverseSurface: c.text,
      onInverseSurface: c.background,
      inversePrimary: c.primaryStrong,
    );

    final textTheme = TextTheme(
      displaySmall: type.largeTitle,
      headlineMedium: type.title1,
      headlineSmall: type.title2,
      titleLarge: type.title2,
      titleMedium: type.headline,
      titleSmall: type.subhead,
      bodyLarge: type.bodyStyle,
      bodyMedium: type.callout,
      bodySmall: type.caption,
      labelLarge: type.headline,
      labelMedium: type.captionStrong,
      labelSmall: type.micro,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: KType.body,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.separator,
      splashFactory: InkRipple.splashFactory,
      splashColor: c.primary.withValues(alpha: 0.08),
      highlightColor: c.primary.withValues(alpha: 0.05),
      hoverColor: c.text.withValues(alpha: 0.04),
      focusColor: c.primary.withValues(alpha: 0.12),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [c, type],
      dividerTheme: DividerThemeData(color: c.separator, thickness: KSize.hairline, space: KSize.hairline),
      iconTheme: IconThemeData(color: c.text, size: KSize.iconLg),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: type.headline,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: type.caption.copyWith(color: c.background),
        decoration: BoxDecoration(color: c.text, borderRadius: KRadius.smAll),
        waitDuration: const Duration(milliseconds: 500),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: type.callout.copyWith(color: c.background),
        actionTextColor: c.container,
        shape: const RoundedRectangleBorder(borderRadius: KRadius.cardAll),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: KRadius.sheetTop),
        showDragHandle: false,
        elevation: 0,
        modalBarrierColor: c.scrim,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: KRadius.sheetAll),
        titleTextStyle: type.headline,
        contentTextStyle: type.callout,
        barrierColor: c.scrim,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: type.callout,
        shape: RoundedRectangleBorder(
            borderRadius: KRadius.cardAll, side: BorderSide(color: c.separator)),
        elevation: 6,
        shadowColor: c.canvas.withValues(alpha: 0.4),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.container,
        thumbColor: c.surface,
        overlayColor: c.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.surface),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : c.separator),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primary.withValues(alpha: 0.25),
        selectionHandleColor: c.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: true,
        hintStyle: type.callout.copyWith(color: c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: KSpace.s12),
        border: OutlineInputBorder(borderRadius: KRadius.cardAll, borderSide: BorderSide(color: c.separator)),
        enabledBorder: OutlineInputBorder(borderRadius: KRadius.cardAll, borderSide: BorderSide(color: c.separator)),
        focusedBorder: OutlineInputBorder(borderRadius: KRadius.cardAll, borderSide: BorderSide(color: c.primary, width: 1.5)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(c.textSecondary.withValues(alpha: 0.4)),
        radius: const Radius.circular(KRadius.full),
        thickness: WidgetStateProperty.all(6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.container,
        circularTrackColor: c.container,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
