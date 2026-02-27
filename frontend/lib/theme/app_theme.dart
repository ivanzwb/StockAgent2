import 'package:flutter/material.dart';

/// 应用主题
class AppTheme {
  static const Color primaryColor = Color(0xFFE53935);
  static const Color accentColor = Color(0xFF1E88E5);
  static const Color buyColor = Color(0xFFE53935);
  static const Color sellColor = Color(0xFF43A047);
  static const Color holdColor = Color(0xFFFFA000);
  static const Color bgDark = Color(0xFF1A1A2E);
  static const Color bgCard = Color(0xFF16213E);
  static const Color textPrimary = Color(0xFFECECEC);
  static const Color textSecondary = Color(0xFF9E9E9E);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      surface: bgCard,
    ),
    scaffoldBackgroundColor: bgDark,
    appBarTheme: AppBarTheme(
      backgroundColor: bgDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bgCard,
      indicatorColor: primaryColor.withOpacity(0.2),
    ),
  );

  /// 获取信号对应的颜色
  static Color getSignalColor(String signal) {
    switch (signal.toLowerCase()) {
      case 'buy':
      case '买入':
        return buyColor;
      case 'sell':
      case '卖出':
        return sellColor;
      case 'hold':
      case '观望':
        return holdColor;
      default:
        return textSecondary;
    }
  }

  /// 获取涨跌对应的颜色
  static Color getChangeColor(double change) {
    if (change > 0) return buyColor;
    if (change < 0) return sellColor;
    return textSecondary;
  }
}
