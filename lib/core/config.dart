import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// 서버 접속 설정.
///
/// 기본값은 **운영 서버**(https://mangoshop.co.kr)입니다.
/// 로컬 XAMPP(`http://localhost/mangoshop`)로 붙으려면 [useLocal] 을 true 로 바꾸세요.
class AppConfig {
  /// 운영 서버 도메인 (Laravel 앱이 도메인 루트에 배포됨)
  static const String prodHost = 'https://mangoshop.co.kr';

  /// 로컬 XAMPP 서브폴더 배포 경로
  static const String localPath = '/mangoshop';

  /// true 로 두면 로컬 XAMPP 로 접속
  static const bool useLocal = false;

  /// 런타임에서 강제로 주소를 덮어쓰고 싶을 때 (실기기 디버깅 등).
  ///
  /// 실기기로 로컬 서버에 붙으려면 PC 의 LAN IP 를 지정:
  ///   AppConfig.overrideHost = 'http://192.168.0.10/mangoshop';
  static String? overrideHost;

  static String get host {
    if (overrideHost != null) return overrideHost!;
    if (!useLocal) return prodHost;

    // ----- 로컬 개발 -----
    // Android 에뮬레이터는 호스트 PC 를 10.0.2.2 로 바라본다.
    if (kIsWeb) return 'http://localhost$localPath';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2$localPath';
    } catch (_) {}
    return 'http://localhost$localPath';
  }

  static String get apiBase => '$host/api/v1';

  static const appName = '망고샵';
  static const appNameEn = 'MANGOSHOP';
  static const appTagline = '수입 과일 도매·소매 오픈마켓';
}
