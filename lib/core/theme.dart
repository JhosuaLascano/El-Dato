import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta tomada de LA DATA: amarillo oro + negro/café oscuro.
class AppColors {
  static const gold = Color(0xFFF2C64B);
  static const goldDeep = Color(0xFFE0A91F);
  static const goldSoft = Color(0x33F2C64B);
  static const bg = Color(0xFF0C0C0A);
  static const surface = Color(0xFF16150F);
  static const surface2 = Color(0xFF1F1D15);
  static const border = Color(0xFF2C2A1E);
  static const brown = Color(0xFF362E1C);
  static const text = Color(0xFFF6F2E7);
  static const muted = Color(0xFF9A9483);
  static const green = Color(0xFF4CC38A);
  static const red = Color(0xFFFF6B5E);

  static const palette = <int>[
    0xFFF2C64B, 0xFFFF9F43, 0xFF4CC38A, 0xFF5B9DFF, 0xFFA78BFA,
    0xFFFF7AB6, 0xFFFF6B5E, 0xFF2DD4BF, 0xFFB5E550, 0xFFC9A27E,
  ];
}

/// Iconos disponibles para módulos (mapa constante => tree-shaking de iconos OK).
const Map<String, IconData> kIcons = {
  'food': Icons.restaurant_rounded,
  'market': Icons.local_grocery_store_rounded,
  'coffee': Icons.local_cafe_rounded,
  'transport': Icons.directions_bus_rounded,
  'car': Icons.directions_car_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'fun': Icons.sports_esports_rounded,
  'music': Icons.music_note_rounded,
  'edu': Icons.school_rounded,
  'home': Icons.home_rounded,
  'bills': Icons.receipt_long_rounded,
  'wifi': Icons.wifi_rounded,
  'phone': Icons.smartphone_rounded,
  'tech': Icons.computer_rounded,
  'health': Icons.favorite_rounded,
  'gym': Icons.fitness_center_rounded,
  'beauty': Icons.spa_rounded,
  'clothes': Icons.checkroom_rounded,
  'shop': Icons.shopping_bag_rounded,
  'gift': Icons.card_giftcard_rounded,
  'pet': Icons.pets_rounded,
  'kids': Icons.child_care_rounded,
  'travel': Icons.flight_rounded,
  'work': Icons.work_rounded,
  'savings': Icons.savings_rounded,
  'other': Icons.category_rounded,
};

IconData iconFor(String key) => kIcons[key] ?? Icons.category_rounded;

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.gold,
    onPrimary: Colors.black,
    secondary: AppColors.gold,
    onSecondary: Colors.black,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.red,
    outline: AppColors.border,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
  );
  final t = base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text);
  return base.copyWith(
    textTheme: t.copyWith(
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: AppColors.bg),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.gold, width: 1.4)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface2,
      contentTextStyle: const TextStyle(color: AppColors.text),
      actionTextColor: AppColors.gold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.surface2,
    ),
    timePickerTheme: const TimePickerThemeData(backgroundColor: AppColors.surface),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface2,
      selectedColor: AppColors.gold,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      checkmarkColor: Colors.black,
    ),
  );
}
