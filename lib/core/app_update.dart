import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

/// 업데이트 필요 수준
enum UpdateLevel {
  none, // 최신
  optional, // 새 버전 있음(선택) — 배너 안내
  forced, // 최소 지원 미만(필수) — 사용 차단 후 업데이트 유도
}

class AppUpdate {
  final UpdateLevel level;
  final String currentVersion; // 현재 설치 버전(versionName)
  final String? latestVersion; // 서버가 알린 최신 버전
  final String? storeUrl;
  final String? message;

  const AppUpdate({
    required this.level,
    required this.currentVersion,
    this.latestVersion,
    this.storeUrl,
    this.message,
  });

  static const none = AppUpdate(level: UpdateLevel.none, currentVersion: '');

  bool get needsUpdate => level != UpdateLevel.none;

  /// 스토어로 이동. 실패해도 조용히 무시(앱이 죽지 않도록).
  Future<void> openStore() async {
    final url = storeUrl;
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);

/// 현재 앱 패키지 정보 (버전명 + 빌드번호). 1회 로드 후 캐시.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

/// 서버 버전 정책과 현재 앱 버전을 비교해 업데이트 수준을 판정한다.
///
/// 비교는 **빌드번호(versionCode)** 정수로 한다(버전명 파싱보다 견고).
/// 네트워크 실패·필드 누락 등 어떤 예외에서도 [AppUpdate.none] 을 반환해
/// 앱이 잘못 차단되는 일이 없도록 한다.
final appUpdateProvider = FutureProvider.autoDispose<AppUpdate>((ref) async {
  try {
    if (kIsWeb) return AppUpdate.none;

    final info = await ref.watch(packageInfoProvider.future);
    final currentBuild = _int(info.buildNumber);
    final currentVersion = info.version;

    final res = await ref.read(apiProvider).get('/settings');
    final app = (res is Map ? res['app'] : null);
    if (app is! Map) return AppUpdate(level: UpdateLevel.none, currentVersion: currentVersion);

    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      _ => 'android',
    };
    final p = app[platform];
    if (p is! Map) return AppUpdate(level: UpdateLevel.none, currentVersion: currentVersion);

    final latestBuild = _int(p['latest_build']);
    final minBuild = _int(p['min_build']);
    final storeUrl = p['store_url']?.toString();
    final latestVersion = p['latest_version']?.toString();
    final message = app['update_message']?.toString();

    final level = switch (currentBuild) {
      _ when minBuild > 0 && currentBuild < minBuild => UpdateLevel.forced,
      _ when latestBuild > 0 && currentBuild < latestBuild => UpdateLevel.optional,
      _ => UpdateLevel.none,
    };

    return AppUpdate(
      level: level,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      storeUrl: storeUrl,
      message: message,
    );
  } catch (_) {
    // 어떤 오류에서도 앱을 막지 않는다
    return AppUpdate.none;
  }
});
