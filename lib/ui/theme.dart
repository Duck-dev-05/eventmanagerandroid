import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'flavor.dart';

/// EventPulse design tokens.
///
/// Every color used across the app lives here so screens never hard-code
/// palette values. Private aliases in feature files should reference these.
const Color ink = Color(0xFF16201B);
const Color muted = Color(0xFF6C7B73);
const Color orange = Color(0xFFD96C2D);
const Color orangeDeep = Color(0xFFE8732A);
const Color canvas = Color(0xFFF3F5F2);
const Color line = Color(0xFFE2E8E3);
const Color orangeLight = Color(0xFFFFF1E7);
const Color orangeBorder = Color(0xFFF6D5BE);
const Color avatarTint = Color(0xFFFFE2CE);
const Color fieldFill = Color(0xFFFAFBFA);

// -- Semantic status tokens -------------------------------------------------
const Color error = Color(0xFFB42318);
const Color errorTint = Color(0xFFFFF1F0);
const Color success = Color(0xFF00A66C);
const Color successTint = Color(0xFFE6F9F3);
const Color warning = Color(0xFFE38A00);
const Color warningTint = Color(0xFFFFF8E6);
const Color warningBorder = Color(0xFFFFD97D);
const Color warningInk = Color(0xFF7A5A00);

// -- Dashboard accent palette -----------------------------------------------
const Color rose = Color(0xFFF04462);
const Color roseLight = Color(0xFFFFEEF0);
const Color mintLight = Color(0xFFEAFBF3);
const Color amberLight = Color(0xFFFFF9E9);
const Color blue = Color(0xFF4F73D9);
const Color blueLight = Color(0xFFEEF3FF);

// -- Quiet neutral fills for chips, badges and icon tiles -------------------
const Color softFill = Color(0xFFF5F7F5);
const Color chipFill = Color(0xFFF4F6F3);

// -- Neutral accents used by rows, chevrons and quiet icons -----------------
const Color chevron = Color(0xFFA6B2AB);
const Color iconSoft = Color(0xFF8B9A92);
const Color mutedStrong = Color(0xFF41504A);

/// Shared geometry so panels, inputs and dialogs share one rhythm.
abstract final class AppRadius {
  static const double xs = 10;
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;
}

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;
}

/// 900 keeps the two-pane desktop shell off small tablets in portrait.
const double kWideBreakpoint = 900;
const double kMediumBreakpoint = 600;
const double kPageMaxWidth = 1180;

/// Soft elevation used by cards and panels instead of heavy Material shadows.
const List<BoxShadow> kSoftShadow = [
  BoxShadow(color: Color(0x0A16201B), blurRadius: 18, offset: Offset(0, 4)),
];
const List<BoxShadow> kLiftedShadow = [
  BoxShadow(color: Color(0x1416201B), blurRadius: 30, offset: Offset(0, 10)),
];

/// Runtime design tokens that change between the Android 13 and Android 14+
/// visual generations.
@immutable
class EventPulseUiTokens extends ThemeExtension<EventPulseUiTokens> {
  const EventPulseUiTokens({
    required this.flavor,
    required this.cardColor,
    required this.cardBorder,
    required this.cardRadius,
    required this.cardShadow,
    required this.pageGutter,
    required this.pageGutterWide,
    required this.floatingNavigation,
  });

  final UiFlavor flavor;
  final Color cardColor;
  final Color cardBorder;
  final double cardRadius;
  final List<BoxShadow> cardShadow;
  final double pageGutter;
  final double pageGutterWide;
  final bool floatingNavigation;

  static const classic = EventPulseUiTokens(
    flavor: UiFlavor.classic,
    cardColor: Colors.white,
    cardBorder: line,
    cardRadius: AppRadius.xl,
    cardShadow: kSoftShadow,
    pageGutter: 18,
    pageGutterWide: 28,
    floatingNavigation: true,
  );

  static const expressive = EventPulseUiTokens(
    flavor: UiFlavor.expressive,
    cardColor: Color(0xFFFBF8F4),
    cardBorder: Color(0xFFE7DED3),
    cardRadius: 28,
    cardShadow: <BoxShadow>[],
    pageGutter: 20,
    pageGutterWide: 32,
    floatingNavigation: false,
  );

  static EventPulseUiTokens of(BuildContext context) =>
      Theme.of(context).extension<EventPulseUiTokens>() ?? classic;

  @override
  EventPulseUiTokens copyWith({
    UiFlavor? flavor,
    Color? cardColor,
    Color? cardBorder,
    double? cardRadius,
    List<BoxShadow>? cardShadow,
    double? pageGutter,
    double? pageGutterWide,
    bool? floatingNavigation,
  }) {
    return EventPulseUiTokens(
      flavor: flavor ?? this.flavor,
      cardColor: cardColor ?? this.cardColor,
      cardBorder: cardBorder ?? this.cardBorder,
      cardRadius: cardRadius ?? this.cardRadius,
      cardShadow: cardShadow ?? this.cardShadow,
      pageGutter: pageGutter ?? this.pageGutter,
      pageGutterWide: pageGutterWide ?? this.pageGutterWide,
      floatingNavigation: floatingNavigation ?? this.floatingNavigation,
    );
  }

  @override
  EventPulseUiTokens lerp(EventPulseUiTokens? other, double t) {
    if (other == null) return this;
    return EventPulseUiTokens(
      flavor: t < 0.5 ? flavor : other.flavor,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
      pageGutter: pageGutter + (other.pageGutter - pageGutter) * t,
      pageGutterWide:
          pageGutterWide + (other.pageGutterWide - pageGutterWide) * t,
      floatingNavigation: t < 0.5
          ? floatingNavigation
          : other.floatingNavigation,
    );
  }
}

const List<String> kMonthShorts = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

const List<String> kMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> kWeekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Builds the shared [ThemeData] used by the whole app.
ThemeData _buildClassicTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: orange, surface: canvas)
      .copyWith(
        primary: orange,
        onPrimary: Colors.white,
        primaryContainer: orangeLight,
        onPrimaryContainer: const Color(0xFF6E2E08),
        secondary: ink,
        onSecondary: Colors.white,
        secondaryContainer: softFill,
        onSecondaryContainer: ink,
        tertiary: success,
        onTertiary: Colors.white,
        surface: canvas,
        onSurface: ink,
        onSurfaceVariant: muted,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: fieldFill,
        surfaceContainer: softFill,
        surfaceContainerHigh: chipFill,
        surfaceContainerHighest: line,
        outline: line,
        outlineVariant: line,
        error: error,
        onError: Colors.white,
        errorContainer: errorTint,
        onErrorContainer: error,
        inverseSurface: ink,
        onInverseSurface: Colors.white,
      );

  final base = ThemeData.light().textTheme.apply(
    fontFamily: 'Roboto',
    bodyColor: ink,
    displayColor: ink,
  );
  final textTheme = base.copyWith(
    displaySmall: base.displaySmall?.copyWith(
      fontSize: 34,
      height: 1.1,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.1,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.9,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 26,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 15.5, height: 1.5),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
    bodySmall: base.bodySmall?.copyWith(fontSize: 12.5, height: 1.4),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    fontFamily: 'Roboto',
    textTheme: textTheme,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 60,
      titleSpacing: 16,
      iconTheme: IconThemeData(color: mutedStrong, size: 22),
      actionsIconTheme: IconThemeData(color: mutedStrong, size: 22),
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      prefixIconColor: iconSoft,
      suffixIconColor: iconSoft,
      hintStyle: const TextStyle(color: chevron, fontSize: 13.5),
      helperStyle: const TextStyle(color: muted, fontSize: 11.5),
      errorStyle: const TextStyle(
        color: error,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(color: muted, fontSize: 13.5),
      floatingLabelStyle: const TextStyle(
        color: orange,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: line),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      minVerticalPadding: 10,
      iconColor: iconSoft,
      titleTextStyle: const TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: const TextStyle(
        color: muted,
        fontSize: 12.5,
        height: 1.35,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shadowColor: const Color(0x2616201B),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      titleTextStyle: textTheme.headlineSmall?.copyWith(fontSize: 20),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: muted),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shadowColor: const Color(0x1F16201B),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      textStyle: const TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: line),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: const TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: line),
        ),
      ),
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(10),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: line),
          ),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: orangeLight,
      secondarySelectedColor: orangeLight,
      disabledColor: softFill,
      side: const BorderSide(color: line),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        color: mutedStrong,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: orange,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      showCheckmark: false,
      checkmarkColor: orange,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? orange : line,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? orange : null,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: chevron, width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? orange : chevron,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13.5,
        height: 1.4,
      ),
      actionTextColor: const Color(0xFFFFB27D),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Color(0x6616201B),
      showDragHandle: true,
      dragHandleColor: line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: orange,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: orange,
      linearTrackColor: orangeLight,
      circularTrackColor: orangeLight,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStateProperty.all(const Color(0x3316201B)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: orangeLight,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? orange : muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          letterSpacing: 0.1,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? ink : muted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: orangeLight,
      useIndicator: true,
      selectedIconTheme: const IconThemeData(color: orange, size: 22),
      unselectedIconTheme: const IconThemeData(color: muted, size: 22),
      selectedLabelTextStyle: const TextStyle(
        color: ink,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        backgroundColor: orange,
        foregroundColor: Colors.white,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        foregroundColor: ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: line),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        foregroundColor: orange,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: mutedStrong,
        highlightColor: softFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: orange,
      foregroundColor: Colors.white,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: orange,
      collapsedIconColor: iconSoft,
      textColor: ink,
      collapsedTextColor: ink,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    bannerTheme: MaterialBannerThemeData(
      backgroundColor: warningTint,
      surfaceTintColor: Colors.transparent,
      contentTextStyle: const TextStyle(
        color: warningInk,
        fontSize: 13,
        height: 1.4,
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
    ),
  );
}

/// Builds the shared theme for the requested Android visual generation.
ThemeData buildEventPulseTheme({UiFlavor flavor = UiFlavor.classic}) {
  final classic = _buildClassicTheme();
  if (flavor == UiFlavor.classic) {
    return classic.copyWith(extensions: const [EventPulseUiTokens.classic]);
  }

  const surface = Color(0xFFF1ECE5);
  const card = Color(0xFFFBF8F4);
  const cardBorder = Color(0xFFE7DED3);
  const field = Color(0xFFF7F2EC);
  final scheme = classic.colorScheme.copyWith(
    surface: surface,
    surfaceContainerLowest: card,
    surfaceContainerLow: field,
    surfaceContainer: const Color(0xFFF4EFE8),
    surfaceContainerHigh: const Color(0xFFEDE6DC),
    surfaceContainerHighest: const Color(0xFFE5DCD0),
    outline: cardBorder,
    outlineVariant: cardBorder,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: cardBorder),
  );
  const buttonShape = WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder());

  return classic.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    visualDensity: VisualDensity.comfortable,
    appBarTheme: classic.appBarTheme.copyWith(
      backgroundColor: card,
      toolbarHeight: 64,
    ),
    inputDecorationTheme: classic.inputDecorationTheme.copyWith(
      fillColor: field,
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: orange, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
    ),
    cardTheme: const CardThemeData(
      color: card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        side: BorderSide(color: cardBorder),
      ),
    ),
    dialogTheme: classic.dialogTheme.copyWith(
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        side: BorderSide(color: cardBorder),
      ),
    ),
    popupMenuTheme: classic.popupMenuTheme.copyWith(
      color: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: cardBorder),
      ),
    ),
    bottomSheetTheme: classic.bottomSheetTheme.copyWith(
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    navigationBarTheme: classic.navigationBarTheme.copyWith(
      height: 72,
      backgroundColor: card,
      indicatorShape: const StadiumBorder(),
    ),
    navigationRailTheme: classic.navigationRailTheme.copyWith(
      backgroundColor: card,
      indicatorShape: const StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: classic.filledButtonTheme.style?.copyWith(shape: buttonShape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: classic.elevatedButtonTheme.style?.copyWith(shape: buttonShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: classic.outlinedButtonTheme.style?.copyWith(
        shape: buttonShape,
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(BorderSide(color: cardBorder)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: classic.textButtonTheme.style?.copyWith(shape: buttonShape),
    ),
    floatingActionButtonTheme: classic.floatingActionButtonTheme.copyWith(
      shape: const CircleBorder(),
    ),
    extensions: const [EventPulseUiTokens.expressive],
  );
}

/// Maps backend/network failures to a friendly, consistent message.
String appErrorText(Object error) {
  if (error is HttpException) return error.message;
  if (error is TimeoutException) {
    return 'The EventPulse server took too long to respond. Please try again.';
  }
  return 'Could not connect to EventPulse. Check your internet connection and try again.';
}

/// Two-letter initials for avatars, matching the brand avatar style.
String userInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final parts = words.take(2).map((word) => word[0].toUpperCase()).join();
  return parts.isEmpty ? 'E' : parts;
}

String monthShort(int month) => kMonthShorts[month - 1];

String monthName(int month) => kMonthNames[month - 1];

String weekdayName(int weekday) => kWeekdayNames[weekday - 1];

/// "Jan 5, 2026" style compact date used in lists and side panels.
String shortDate(DateTime date) =>
    '${monthShort(date.month)[0]}${monthShort(date.month).substring(1).toLowerCase()} '
    '${date.day}, ${date.year}';

/// "Friday, January 5, 2026" style long date used in forms and headings.
String longDate(DateTime date) =>
    '${weekdayName(date.weekday)}, ${monthName(date.month)} ${date.day}, ${date.year}';
