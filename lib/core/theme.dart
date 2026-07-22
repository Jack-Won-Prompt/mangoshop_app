import 'package:flutter/material.dart';

/// 망고샵 브랜드 테마 — 망고 옐로우/오렌지 + 리프 그린의 신선식품 톤.
///
/// [navy]/[red] 는 초기 골격에서 이어받은 이름이라 화면 코드가 광범위하게
/// 참조한다. 값만 망고 팔레트로 교체해 호출부를 건드리지 않는다.
/// 신규 코드는 의미가 드러나는 별칭([brand]/[accent]/[leaf] …)을 사용할 것.
class AppColors {
  // ----- 망고 브랜드 팔레트 (공식 로고 자산에서 추출) -----
  /// 메인 브랜드 — 워드마크 오렌지 (logo_horizontal 의 '망고샵' 색)
  static const brand = Color(0xFFF85800);
  static const brandDark = Color(0xFFC24400);

  /// 포인트 — 망고 과육 옐로우 (심볼 그라디언트 상단)
  static const accent = Color(0xFFFCB104);
  static const accentSoft = Color(0xFFFFF6E3);

  /// 신선/원산지 — 심볼 잎사귀 그린
  static const leaf = Color(0xFF288028);
  static const leafSoft = Color(0xFFEAF5EA);

  /// 콜드체인 — 쿨 블루
  static const cool = Color(0xFF2779D9);
  static const coolSoft = Color(0xFFEAF2FD);

  /// 도매 전용 강조 — 딥 플럼
  static const wholesale = Color(0xFF9333EA);
  static const wholesaleSoft = Color(0xFFF6EDFE);

  // ----- 레거시 별칭 (기존 화면 코드 호환) -----
  /// primary 계열 (구 navy) → 망고 오렌지
  static const navy = brand;
  static const navyDark = brandDark;

  /// 세일/할인 강조 (구 red) → 선명한 토마토 레드
  static const red = Color(0xFFE23B2E);
  static const redSoft = Color(0xFFFFF0EE);

  // ----- 뉴트럴 -----
  static const ink = Color(0xFF1C1917);
  static const sub = Color(0xFF78716C);
  static const line = Color(0xFFEBE6E1);
  static const bg = Color(0xFFFAF8F5);
  static const card = Colors.white;
  static const chip = Color(0xFFF5F1EB);
  static const success = Color(0xFF059669);
  static const warn = Color(0xFFD97706);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.navy,
        secondary: AppColors.red,
        surface: AppColors.card,
        error: AppColors.red,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
        fontFamily: 'Roboto',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.chip,
        selectedColor: AppColors.navy,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide.none,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.navy),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.6),
        ),
        hintStyle: const TextStyle(color: AppColors.sub),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.navy,
        unselectedItemColor: AppColors.sub,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
