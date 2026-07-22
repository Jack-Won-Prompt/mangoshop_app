import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api.dart';
import 'core/push_service.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const ProviderScope(child: MangoShopApp()));
}

String _platformName() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'android',
  };
}

class MangoShopApp extends ConsumerStatefulWidget {
  const MangoShopApp({super.key});

  @override
  ConsumerState<MangoShopApp> createState() => _MangoShopAppState();
}

class _MangoShopAppState extends ConsumerState<MangoShopApp> {
  @override
  void initState() {
    super.initState();

    // 토큰 등록 콜백 — 로그인 상태에서만 서버에 연결
    final api = ref.read(apiProvider);
    PushService.instance.onToken = (token) async {
      if (ref.read(authProvider).isLoggedIn) {
        await api.post('/push/register', data: {'token': token, 'platform': _platformName()});
      }
    };

    // 프레임 이후 FCM 초기화 (Firebase 미설정 시 자동 skip)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushService.instance.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 로그인되면 FCM 토큰을 서버에 등록
    ref.listen(authProvider, (prev, next) async {
      final was = prev?.isLoggedIn ?? false;
      if (next.isLoggedIn && !was) {
        // 로그인 → 토큰 등록
        PushService.instance.syncToken();
      } else if (!next.isLoggedIn && was) {
        // 로그아웃 → 토큰 해제 (공개 라우트라 인증 불필요)
        final token = await PushService.instance.currentToken();
        if (token != null) {
          try {
            await ref.read(apiProvider).post('/push/unregister', data: {'token': token});
          } catch (_) {}
        }
      }
    });

    return MaterialApp.router(
      title: '망고샵',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
        child: child!,
      ),
    );
  }
}
